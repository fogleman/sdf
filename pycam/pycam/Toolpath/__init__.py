"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>

This file is part of PyCAM.

PyCAM is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PyCAM is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PyCAM.  If not, see <http://www.gnu.org/licenses/>.
"""

from enum import Enum
from itertools import groupby
import math
import os

try:
    import numpy
    from OpenGL.arrays import vbo
except ImportError:
    # both modules are required for visualization, only
    pass

from pycam.Geometry import epsilon, number, Box3D, DimensionalObject, Point3D
from pycam.Geometry.PointUtils import padd, pcross, pdist, pmul, pnorm, pnormalized, psub
import pycam.Utils.log


_log = pycam.Utils.log.get_logger()


MOVE_STRAIGHT, MOVE_STRAIGHT_RAPID, MOVE_ARC, MOVE_SAFETY, MACHINE_SETTING, COMMENT = range(6)
MOVES_LIST = (MOVE_STRAIGHT, MOVE_STRAIGHT_RAPID, MOVE_ARC)


class ToolpathPathMode(Enum):
    CORNER_STYLE_EXACT_PATH = "exact_path"
    CORNER_STYLE_EXACT_STOP = "exact stop"
    CORNER_STYLE_OPTIMIZE_SPEED = "optimize_speed"
    CORNER_STYLE_OPTIMIZE_TOLERANCE = "optimize_tolerance"


def _check_colinearity(p1, p2, p3):
    v1 = pnormalized(psub(p2, p1))
    v2 = pnormalized(psub(p3, p2))
    # compare if the normalized distances between p1-p2 and p2-p3 are equal
    return v1 == v2


def simplify_toolpath(path):
    """ remove multiple points in a line from a toolpath

    If A, B, C and D are on a straight line, then B and C will be removed.
    This reduces memory consumption and avoids a severe slow-down of the machine
    when moving along very small steps.
    The toolpath is simplified _in_place_.
    @value path: a single separate segment of a toolpath
    @type path: list of points
    """
    index = 1
    # stay compatible with pycam.Geometry.Path objects
    if hasattr(path, "points"):
        path = path.points
    while index < len(path) - 1:
        if _check_colinearity(path[index-1], path[index], path[index+1]):
            path.pop(index)
            # don't increase the counter - otherwise we skip one point
        else:
            index += 1


class Toolpath(DimensionalObject):

    def __init__(self, toolpath_path=None, toolpath_filters=None, tool=None, **kwargs):
        super().__init__(**kwargs)
        if toolpath_path is None:
            toolpath_path = []
        if toolpath_filters is None:
            toolpath_filters = []
        self.filters = toolpath_filters
        self.path = toolpath_path
        self.tool = tool
        self.clear_cache()

    def __get_path(self):
        return self.__path

    def __set_path(self, new_path):
        # use a read-only tuple instead of a list
        # (otherwise we can't detect changes)
        self.__path = tuple(new_path)
        self.clear_cache()

    def __get_filters(self):
        return self.__filters

    def __set_filters(self, new_filters):
        # use a read-only tuple instead of a list
        # (otherwise we can't detect changes)
        self.__filters = tuple(new_filters)
        self.clear_cache()

    # use a property in order to trigger "clear_cache" whenever the path changes
    path = property(__get_path, __set_path)
    filters = property(__get_filters, __set_filters)

    def copy(self):
        return type(self)(toolpath_path=self.path, toolpath_filters=self.filters, tool=self.tool)

    def clear_cache(self):
        self.opengl_safety_height = None
        self._cache_basic_moves = None
        self._cache_visual_filters_string = None
        self._cache_visual_filters = None
        self._cache_machine_distance_and_time = None
        self._minx = None
        self._maxx = None
        self._miny = None
        self._maxy = None
        self._minz = None
        self._maxz = None

    def __hash__(self):
        return hash((self.__path, self.__filters))

    def _get_limit_generic(self, idx, func):
        values = [step.position[idx] for step in self.path if step.action in MOVES_LIST]
        return func(values)

    @property
    def minx(self):
        if self._minx is None:
            self._minx = self._get_limit_generic(0, min)
        return self._minx

    @property
    def maxx(self):
        if self._maxx is None:
            self._maxx = self._get_limit_generic(0, max)
        return self._maxx

    @property
    def miny(self):
        if self._miny is None:
            self._miny = self._get_limit_generic(1, min)
        return self._miny

    @property
    def maxy(self):
        if self._maxy is None:
            self._maxy = self._get_limit_generic(1, max)
        return self._maxy

    @property
    def minz(self):
        if self._minz is None:
            self._minz = self._get_limit_generic(2, min)
        return self._minz

    @property
    def maxz(self):
        if self._maxz is None:
            self._maxz = self._get_limit_generic(2, max)
        return self._maxz

    def get_meta_data(self):
        meta = self.toolpath_settings.get_string()
        start_marker = self.toolpath_settings.META_MARKER_START
        end_marker = self.toolpath_settings.META_MARKER_END
        return os.linesep.join((start_marker, meta, end_marker))

    def get_moves(self, max_time=None):
        moves = self.get_basic_moves()
        if max_time is None:
            return moves
        else:
            # late import due to dependency cycle
            import pycam.Toolpath.Filters
            return moves | pycam.Toolpath.Filters.TimeLimit(max_time)

    def _rotate_point(self, rp, sp, v, angle):
        vx = v[0]
        vy = v[1]
        vz = v[2]
        x = ((sp[0] * (vy ** 2 + vz ** 2)
              - vx * (sp[1] * vy
                      + sp[2] * vz
                      - vx * rp[0]
                      - vy * rp[1]
                      - vz * rp[2])) * (1 - math.cos(angle))
             + rp[0] * math.cos(angle)
             + (-sp[2] * vy + sp[1] * vz - vz * rp[1] + vy * rp[2]) * math.sin(angle))
        y = ((sp[1] * (vx ** 2 + vz ** 2)
              - vy * (sp[0] * vx
                      + sp[2] * vz
                      - vx * rp[0]
                      - vy * rp[1]
                      - vz * rp[2])) * (1 - math.cos(angle))
             + rp[1] * math.cos(angle)
             + (sp[2] * vx - sp[0] * vz + vz * rp[0] - vx * rp[2]) * math.sin(angle))
        z = ((sp[2] * (vx ** 2 + vy ** 2)
              - vz * (sp[0] * vx
                      + sp[1] * vy
                      - vx * rp[0]
                      - vy * rp[1]
                      - vz * rp[2])) * (1 - math.cos(angle))
             + rp[2] * math.cos(angle)
             + (-sp[1] * vx + sp[0] * vy - vy * rp[0] + vx * rp[1]) * math.sin(angle))
        return (x, y, z)

    def draw_direction_cone_mesh(self, p1, p2, position=0.5, precision=12, size=0.1):
        distance = psub(p2, p1)
        length = pnorm(distance)
        direction = pnormalized(distance)
        if direction is None or length < 0.5:
            # zero-length line
            return []
        cone_length = length * size
        cone_radius = cone_length / 3.0
        bottom = padd(p1, pmul(psub(p2, p1), position - size / 2))
        top = padd(p1, pmul(psub(p2, p1), position + size / 2))
        # generate a a line perpendicular to this line, cross product is good at this
        cross = pcross(direction, (0, 0, -1))
        conepoints = []
        if pnorm(cross) != 0:
            # The line direction is not in line with the z axis.
            conep1 = padd(bottom, pmul(cross, cone_radius))
            conepoints = [self._rotate_point(conep1, bottom, direction, x)
                          for x in numpy.linspace(0, 2 * math.pi, precision)]
        else:
            # Z axis
            # just add cone radius to the x axis and rotate the point
            conep1 = (bottom[0] + cone_radius, bottom[1], bottom[2])
            conepoints = [self._rotate_point(conep1, p1, direction, x)
                          for x in numpy.linspace(0, 2*math.pi, precision)]
        triangles = [(top, conepoints[idx], conepoints[idx + 1])
                     for idx in range(len(conepoints) - 1)]
        return triangles

    def get_moves_for_opengl(self, safety_height):
        if self.opengl_safety_height != safety_height:
            self.make_moves_for_opengl(safety_height)
            self.make_vbo_for_moves()
        return (self.opengl_coords, self.opengl_indices)

    # separate vertex coordinates from line definitions and convert to indices
    def make_vbo_for_moves(self):
        index = 0
        output = []
        store_vertices = {}
        vertices = []
        for path in self.opengl_lines:
            indices = []
            triangles = []
            triangle_indices = []
            # compress the lines into a centeral array containing all the vertices
            # generate a matching index for each line
            for idx in range(len(path[0]) - 1):
                point = path[0][idx]
                if point not in store_vertices:
                    store_vertices[point] = index
                    vertices.insert(index, point)
                    index += 1
                indices.append(store_vertices[point])
                point2 = path[0][idx + 1]
                if point2 not in store_vertices:
                    store_vertices[point2] = index
                    vertices.insert(index, point2)
                    index += 1
                triangles.extend(self.draw_direction_cone_mesh(path[0][idx], path[0][idx + 1]))
                for t in triangles:
                    for p in t:
                        if p not in store_vertices:
                            store_vertices[p] = index
                            vertices.insert(index, p)
                            index += 1
                        triangle_indices.append(store_vertices[p])
            triangle_indices = numpy.array(triangle_indices, dtype=numpy.int32)
            indices.append(store_vertices[path[0][-1]])
            # this list comprehension removes consecutive duplicate points.
            indices = numpy.array([x[0] for x in groupby(indices)], dtype=numpy.int32)
            output.append((indices, triangle_indices, path[1]))
        vertices = numpy.array(vertices, dtype=numpy.float32)
        self.opengl_coords = vbo.VBO(vertices)
        self.opengl_indices = output

    def make_moves_for_opengl(self, safety_height):
        # convert moves into lines for display with opengl
        working_path = []
        outpaths = []
        for path in self.path:
            if not path:
                continue

            if len(outpaths) != 0:
                lastp = outpaths[-1][0][-1]
                working_path.append((path[0][0], path[0][1], safety_height))
                if ((abs(lastp[0] - path[0][0]) > epsilon)
                        or (abs(lastp[1] - path[0][1]) > epsilon)):
                    if ((abs(lastp[2] - path[0][2]) > epsilon)
                            or (pdist(lastp, path[0]) > self._max_safe_distance + epsilon)):
                        outpaths.append((tuple([x[0] for x in groupby(working_path)]), True))
            else:
                working_path.append((0, 0, 0))
                working_path.append((path[0][0], path[0][1], safety_height))
                outpaths.append((working_path, True))

            # add this move to last move if last move was not rapid
            if not outpaths[-1][1]:
                outpaths[-1] = (outpaths[-1][0] + tuple(path), False)
            else:
                # last move was rapid, so add last point of rapid to beginning of path
                outpaths.append((tuple([x[0] for x in groupby((outpaths[-1][0][-1],)
                                                              + tuple(path))]), False))
            working_path = []
            working_path.append(path[-1])
            working_path.append((path[-1][0], path[-1][1], safety_height))
        outpaths.append((tuple([x[0] for x in groupby(working_path)]), True))
        self.opengl_safety_height = safety_height
        self.opengl_lines = outpaths

    def get_machine_time(self, safety_height=0.0):
        """ calculate an estimation of the time required for processing the
        toolpath with the machine

        @rtype: float
        @returns: the machine time used for processing the toolpath in minutes
        """
        return self.get_machine_move_distance_and_time()[1]

    def get_machine_move_distance_and_time(self):
        if self._cache_machine_distance_and_time is None:
            min_feedrate = 1
            length = 0
            duration = 0
            feedrate = min_feedrate
            current_position = None
            # go through all points of the path
            for step in self.get_basic_moves():
                if (step.action == MACHINE_SETTING) and (step.key == "feedrate"):
                    feedrate = step.value
                elif step.action in MOVES_LIST:
                    if current_position is not None:
                        distance = pdist(step.position, current_position)
                        duration += distance / max(feedrate, min_feedrate)
                        length += distance
                    current_position = step.position
            self._cache_machine_distance_and_time = length, duration
        return self._cache_machine_distance_and_time

    def get_basic_moves(self, filters=None, reset_cache=False):
        if filters is None:
            # implicitly assume that we use the default (latest) filters if nothing is given
            filters = self._cache_visual_filters or []
        if reset_cache or not self._cache_basic_moves or \
                (str(filters) != self._cache_visual_filters_string):
            # late import due to dependency cycle
            import pycam.Toolpath.Filters
            all_filters = tuple(self.filters) + tuple(filters)
            self._cache_basic_moves = pycam.Toolpath.Filters.get_filtered_moves(self.path,
                                                                                all_filters)
            self._cache_visual_filters_string = str(filters)
            self._cache_visual_filters = filters
            _log.debug("Applying toolpath filters: %s",
                       ", ".join([str(fil) for fil in all_filters]))
            _log.debug("Toolpath step changes: %d (before) -> %d (after)",
                       len(self.path), len(self._cache_basic_moves))
        return self._cache_basic_moves


class Bounds:

    TYPE_RELATIVE_MARGIN = 0
    TYPE_FIXED_MARGIN = 1
    TYPE_CUSTOM = 2

    def __init__(self, bounds_type=None, box=None, reference=None):
        """ create a new Bounds instance

        @value bounds_type: any of TYPE_RELATIVE_MARGIN | TYPE_FIXED_MARGIN |
            TYPE_CUSTOM
        @type bounds_type: int
        @value bounds_low: the lower margin of the boundary compared to the
            reference object (for TYPE_RELATIVE_MARGIN | TYPE_FIXED_MARGIN) or
            the specific boundary values (for TYPE_CUSTOM). Only the lower
            values of the three axes (x, y and z) are given.
        @type bounds_low: (tuple|list) of float
        @value bounds_high: see 'bounds_low'
        @type bounds_high: (tuple|list) of float
        @value reference: optional default reference Bounds instance
        @type reference: Bounds
        """
        self.name = "No name"
        self.set_type(bounds_type)
        if box is None:
            box = Box3D(Point3D(0, 0, 0), Point3D(0, 0, 0))
        self.set_bounds(box)
        self.reference = reference

    def __repr__(self):
        bounds_type_labels = ("relative", "fixed", "custom")
        return "Bounds(%s, %s, %s)" % (bounds_type_labels[self.bounds_type],
                                       self.bounds_low, self.bounds_high)

    def set_type(self, bounds_type):
        # complain if an unknown bounds_type value was given
        if bounds_type not in (Bounds.TYPE_RELATIVE_MARGIN, Bounds.TYPE_FIXED_MARGIN,
                               Bounds.TYPE_CUSTOM):
            raise ValueError("failed to create an instance of pycam.Toolpath.Bounds due to an "
                             "invalid value of 'bounds_type': %s" % repr(bounds_type))
        else:
            self.bounds_type = bounds_type

    def get_bounds(self):
        return Box3D(Point3D(*self.bounds_low), Point3D(*self.bounds_high))

    def set_bounds(self, box):
        self.bounds_low = box.lower
        self.bounds_high = box.upper

    def get_absolute_limits(self, reference=None):
        """ calculate the current absolute limits of the Bounds instance

        @value reference: a reference object described by a tuple (or list) of
            three item. These three values describe only the lower boundary of
            this object (for the x, y and z axes). Each item must be a float
            value. This argument is ignored for the boundary type "TYPE_CUSTOM".
        @type reference: (tuple|list) of float
        @returns: a tuple of two lists containing the low and high limits
        @rvalue: tuple(list)
        """
        # use the default reference if none was given
        if reference is None:
            reference = self.reference
        # check if a reference is given (if necessary)
        if self.bounds_type \
                in (Bounds.TYPE_RELATIVE_MARGIN, Bounds.TYPE_FIXED_MARGIN):
            if reference is None:
                raise ValueError("any non-custom boundary definition requires a reference "
                                 "object for calculating absolute limits")
            else:
                ref_low, ref_high = reference.get_absolute_limits()
        low = [None] * 3
        high = [None] * 3
        # calculate the absolute limits
        if self.bounds_type == Bounds.TYPE_RELATIVE_MARGIN:
            for index in range(3):
                dim_width = ref_high[index] - ref_low[index]
                low[index] = ref_low[index] - self.bounds_low[index] * dim_width
                high[index] = ref_high[index] + self.bounds_high[index] * dim_width
        elif self.bounds_type == Bounds.TYPE_FIXED_MARGIN:
            for index in range(3):
                low[index] = ref_low[index] - self.bounds_low[index]
                high[index] = ref_high[index] + self.bounds_high[index]
        elif self.bounds_type == Bounds.TYPE_CUSTOM:
            for index in range(3):
                low[index] = number(self.bounds_low[index])
                high[index] = number(self.bounds_high[index])
        else:
            # this should not happen
            raise NotImplementedError("the function 'get_absolute_limits' is currently not "
                                      "implemented for the bounds_type '%s'"
                                      % str(self.bounds_type))
        return Box3D(Point3D(low), Point3D(high))
