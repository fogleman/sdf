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



take a look at the related blog posting describing this algorithm:
  http://fab.senselab.org/node/43
"""

from pycam.Geometry import ceil, epsilon, sqrt
from pycam.Geometry.Line import Line
from pycam.Geometry.Plane import Plane
from pycam.Geometry.PointUtils import padd, pcross, pdot, pmul, pnorm, pnormalized, psub
from pycam.PathGenerators import get_free_paths_triangles
from pycam.Utils import ProgressCounter
from pycam.Utils.threading import run_in_parallel
import pycam.Utils.log

_DEBUG_DISABLE_COLLISION_CHECK = False
_DEBUG_DISABLE_EXTEND_LINES = False
_DEBUG_DISBALE_WATERLINE_SHIFT = False


log = pycam.Utils.log.get_logger()


# We need to use a global function here - otherwise it does not work with
# the multiprocessing Pool.
def _process_one_triangle(extra_args):
    model, cutter, up_vector, triangle, z = extra_args
    result = []
    # ignore triangles below the z level
    if triangle.maxz < z:
        # Case 1a
        return result, None
    # ignore triangles pointing upwards or downwards
    if pnorm(pcross(triangle.normal, up_vector)) == 0:
        # Case 1b
        return result, None
    edge_collisions = get_collision_waterline_of_triangle(model, cutter, up_vector, triangle, z)
    if edge_collisions is None:
        # don't try to use this edge again
        return result, [id(triangle)]
    elif len(edge_collisions) == 0:
        return result, None
    else:
        for cutter_location, edge in edge_collisions:
            shifted_edge = get_shifted_waterline(up_vector, edge, cutter_location)
            if shifted_edge is not None:
                if _DEBUG_DISBALE_WATERLINE_SHIFT:
                    result.append((edge, edge))
                else:
                    result.append((edge, shifted_edge))
        return result, None


class CollisionPaths:

    def __init__(self):
        self.waterlines = []
        self.shifted_lines = []

    def __str__(self):
        lines = []
        for index, t in enumerate(self.triangles):
            lines.append("%d - %s" % (index, t))
            if not self.left[index]:
                left_index = None
            else:
                left_index = []
                for left in self.left[index]:
                    left_index.append(self.triangles.index(left))
            if not self.right[index]:
                right_index = None
            else:
                right_index = []
                for right in self.right[index]:
                    right_index.append(self.triangles.index(right))
            lines.append("\t%s / %s" % (left_index, right_index))
            lines.append("\t%s" % str(self.waterlines[index]))
            lines.append("\t%s" % str(self.shifted_lines[index]))
        return "\n".join(lines)

    def add(self, waterline, shifted_line):
        if waterline in self.waterlines:
            # ignore this triangle
            return
        self.waterlines.append(waterline)
        self.shifted_lines.append(shifted_line)

    def _get_groups(self):
        if len(self.waterlines) == 0:
            return []
        queue = range(len(self.waterlines))
        current_group = [0]
        queue.pop(0)
        groups = [current_group]
        while queue:
            for index in queue:
                index_wl = self.waterlines[index]
                if index_wl.p2 == self.waterlines[current_group[0]].p1:
                    current_group.insert(0, index)
                    queue.remove(index)
                    break
                elif index_wl.p1 == self.waterlines[current_group[-1]].p2:
                    current_group.append(index)
                    queue.remove(index)
                    break
                else:
                    pass
            else:
                # no new members added to this group - start a new one
                current_group = [queue[0]]
                queue.pop(0)
                groups.append(current_group)
        return groups

    def extend_shifted_lines(self):
        # TODO: improve the code below to handle "holes" properly (neighbours
        # that disappear due to a negative collision distance - use the example
        # "SampleScene.stl" as a reference)
        def get_right_neighbour(group, ref):
            group_len = len(group)
            # limit the search for a neighbour for non-closed groups
            if self.waterlines[group[0]].p1 == self.waterlines[group[-1]].p2:
                index_range = range(ref + 1, ref + group_len)
            else:
                index_range = range(ref + 1, group_len)
            for index in index_range:
                line_id = group[index % group_len]
                if self.shifted_lines[line_id] is not None:
                    return line_id
            return None
        groups = self._get_groups()
        for group in groups:
            index = 0
            while index < len(group):
                current = group[index]
                current_shifted = self.shifted_lines[current]
                if current_shifted is None:
                    index += 1
                    continue
                neighbour = get_right_neighbour(group, index)
                if neighbour is None:
                    # no right neighbour available
                    break
                neighbour_shifted = self.shifted_lines[neighbour]
                if current_shifted.p2 == neighbour_shifted.p1:
                    index += 1
                    continue
                cp, dist = current_shifted.get_intersection(neighbour_shifted, infinite_lines=True)
                cp2, dist2 = neighbour_shifted.get_intersection(current_shifted,
                                                                infinite_lines=True)
                # TODO: add an arc (composed of lines) for a soft corner (not
                # required, but nicer)
                if dist < epsilon:
                    self.shifted_lines[current] = None
                    index -= 1
                elif dist2 > 1 - epsilon:
                    self.shifted_lines[neighbour] = None
                else:
                    self.shifted_lines[current] = Line(current_shifted.p1, cp)
                    self.shifted_lines[neighbour] = Line(cp, neighbour_shifted.p2)
                    index += 1

    def get_shifted_lines(self):
        result = []
        groups = self._get_groups()
        for group in groups:
            for index in group:
                if self.shifted_lines[index] is not None:
                    result.append(self.shifted_lines[index])
        return result


class ContourFollow:

    def __init__(self, path_processor):
        self.pa = path_processor
        self._up_vector = (0, 0, 1, 'v')
        self._processed_triangles = []

    def _get_free_paths(self, cutter, models, p1, p2):
        return get_free_paths_triangles(models, cutter, p1, p2)

    def generate_toolpath(self, cutter, models, minx, maxx, miny, maxy, minz, maxz, dz,
                          draw_callback=None):
        # reset the list of processed triangles
        self._processed_triangles = []
        # calculate the number of steps
        # Sometimes there is a floating point accuracy issue: make sure
        # that only one layer is drawn, if maxz and minz are almost the same.
        if abs(maxz - minz) < epsilon:
            diff_z = 0
        else:
            diff_z = abs(maxz - minz)
        num_of_layers = 1 + ceil(diff_z / dz)
        z_step = diff_z / max(1, (num_of_layers - 1))

        # only the first model is used for the contour-follow algorithm
        # TODO: should we combine all models?
        num_of_triangles = len(models[0].triangles(minx=minx, miny=miny, maxx=maxx, maxy=maxy))
        progress_counter = ProgressCounter(2 * num_of_layers * num_of_triangles, draw_callback)

        current_layer = 0

        z_steps = [(maxz - i * z_step) for i in range(num_of_layers)]

        # collision handling function
        for z in z_steps:
            # update the progress bar and check, if we should cancel the process
            if draw_callback:
                if draw_callback(text=("ContourFollow: processing layer %d/%d"
                                       % (current_layer + 1, num_of_layers))):
                    # cancel immediately
                    break
            self.pa.new_direction(0)
            self.generate_toolpath_slice(cutter, models[0], minx, maxx, miny, maxy, z,
                                         draw_callback, progress_counter, num_of_triangles)
            self.pa.end_direction()
            self.pa.finish()
            current_layer += 1
        return self.pa.paths

    def generate_toolpath_slice(self, cutter, model, minx, maxx, miny, maxy, z, draw_callback=None,
                                progress_counter=None, num_of_triangles=None):
        shifted_lines = self.get_potential_contour_lines(cutter, model, minx, maxx, miny, maxy, z,
                                                         progress_counter=progress_counter)
        if num_of_triangles is None:
            num_of_triangles = len(shifted_lines)
        last_position = None
        self.pa.new_scanline()
        for line in shifted_lines:
            if _DEBUG_DISABLE_COLLISION_CHECK:
                points = (line.p1, line.p2)
            else:
                points = self._get_free_paths(line.p1, line.p2)
            if points:
                if (last_position is not None) and (last_position != points[0]):
                    self.pa.end_scanline()
                    self.pa.new_scanline()
                for p in points:
                    self.pa.append(p)
                last_position = points[-1]
                if draw_callback:
                    draw_callback(tool_position=last_position, toolpath=self.pa.paths)
            # update the progress counter
            if progress_counter is not None:
                if progress_counter.increment():
                    # quit requested
                    break
        # The progress counter jumps up by the number of non directly processed
        # triangles.
        if progress_counter is not None:
            progress_counter.increment(num_of_triangles - len(shifted_lines))
        self.pa.end_scanline()
        return self.pa.paths

    def get_potential_contour_lines(self, cutter, model, minx, maxx, miny, maxy, z,
                                    progress_counter=None):
        # use only the first model for the contour
        follow_model = model
        waterline_triangles = CollisionPaths()
        triangles = follow_model.triangles(minx=minx, miny=miny, maxx=maxx, maxy=maxy)
        args = [(follow_model, cutter, self._up_vector, t, z)
                for t in triangles if id(t) not in self._processed_triangles]
        results_iter = run_in_parallel(_process_one_triangle, args, unordered=True,
                                       callback=progress_counter.update)
        for result, ignore_triangle_id_list in results_iter:
            if ignore_triangle_id_list:
                self._processed_triangles.extend(ignore_triangle_id_list)
            for edge, shifted_edge in result:
                waterline_triangles.add(edge, shifted_edge)
            if (progress_counter is not None) and (progress_counter.increment()):
                # quit requested
                break
        if not _DEBUG_DISABLE_EXTEND_LINES:
            waterline_triangles.extend_shifted_lines()
        result = []
        for line in waterline_triangles.get_shifted_lines():
            cropped_line = line.get_cropped_line(minx, maxx, miny, maxy, z, z)
            if cropped_line is not None:
                result.append(cropped_line)
        return result


def get_collision_waterline_of_triangle(model, cutter, up_vector, triangle, z):
    # TODO: there are problems with "material allowance > 0"
    plane = Plane((0, 0, z), up_vector)
    if triangle.minz >= z:
        # no point of the triangle is below z
        # try all edges
        # Case (4)
        proj_points = []
        for p in triangle.get_points():
            proj_p = plane.get_point_projection(p)
            if proj_p not in proj_points:
                proj_points.append(proj_p)
        if len(proj_points) == 3:
            edges = []
            for index in range(3):
                edge = Line(proj_points[index - 1], proj_points[index])
                # the edge should be clockwise around the model
                if pdot(pcross(edge.dir, triangle.normal), up_vector) < 0:
                    edge = Line(edge.p2, edge.p1)
                edges.append((edge, proj_points[index - 2]))
            outer_edges = []
            for edge, other_point in edges:
                # pick only edges, where the other point is on the right side
                if pdot(pcross(psub(other_point, edge.p1), edge.dir), up_vector) > 0:
                    outer_edges.append(edge)
            if len(outer_edges) == 0:
                # the points seem to be an one line
                # pick the longest edge
                long_edge = edges[0][0]
                for edge, other_point in edges[1:]:
                    if edge.len > long_edge.len:
                        long_edge = edge
                outer_edges = [long_edge]
        else:
            edge = Line(proj_points[0], proj_points[1])
            if pdot(pcross(edge.dir, triangle.normal), up_vector) < 0:
                edge = Line(edge.p2, edge.p1)
            outer_edges = [edge]
    else:
        # some parts of the triangle are above and some below the cutter level
        # Cases (2a), (2b), (3a) and (3b)
        points_above = [plane.get_point_projection(p) for p in triangle.get_points() if p[2] > z]
        waterline = plane.intersect_triangle(triangle)
        if waterline is None:
            if len(points_above) == 0:
                # the highest point of the triangle is at z
                outer_edges = []
            else:
                if abs(triangle.minz - z) < epsilon:
                    # This is just an accuracy issue (see the
                    # "triangle.minz >= z" statement above).
                    outer_edges = []
                elif not [p for p in triangle.get_points() if p[2] > z + epsilon]:
                    # same as above: fix for inaccurate floating calculations
                    outer_edges = []
                else:
                    # this should not happen
                    raise ValueError(("Could not find a waterline, but there are points above z "
                                      "level (%f): %s / %s") % (z, triangle, points_above))
        else:
            # remove points that are not part of the waterline
            points_above = [p for p in points_above if (p != waterline.p1) and (p != waterline.p2)]
            if len(points_above) == 0:
                # part of case (2a)
                outer_edges = [waterline]
            elif len(points_above) == 1:
                other_point = points_above[0]
                dot = pdot(pcross(psub(other_point, waterline.p1), waterline.dir), up_vector)
                if dot > 0:
                    # Case (2b)
                    outer_edges = [waterline]
                elif dot < 0:
                    # Case (3b)
                    edges = []
                    edges.append(Line(waterline.p1, other_point))
                    edges.append(Line(waterline.p2, other_point))
                    outer_edges = []
                    for edge in edges:
                        if pdot(pcross(edge.dir, triangle.normal), up_vector) < 0:
                            outer_edges.append(Line(edge.p2, edge.p1))
                        else:
                            outer_edges.append(edge)
                else:
                    # the three points are on one line
                    # part of case (2a)
                    edges = []
                    edges.append(waterline)
                    edges.append(Line(waterline.p1, other_point))
                    edges.append(Line(waterline.p2, other_point))
                    edges.sort(key=lambda x: x.len)
                    edge = edges[-1]
                    if pdot(pcross(edge.dir, triangle.normal), up_vector) < 0:
                        outer_edges = [Line(edge.p2, edge.p1)]
                    else:
                        outer_edges = [edge]
            else:
                # two points above
                other_point = points_above[0]
                dot = pdot(pcross(psub(other_point, waterline.p1), waterline.dir), up_vector)
                if dot > 0:
                    # Case (2b)
                    # the other two points are on the right side
                    outer_edges = [waterline]
                elif dot < 0:
                    # Case (3a)
                    edge = Line(points_above[0], points_above[1])
                    if pdot(pcross(edge.dir, triangle.normal), up_vector) < 0:
                        outer_edges = [Line(edge.p2, edge.p1)]
                    else:
                        outer_edges = [edge]
                else:
                    edges = []
                    # pick the longest combination of two of these points
                    # part of case (2a)
                    # TODO: maybe we should use the waterline instead?
                    # (otherweise the line could be too long and thus
                    # connections to the adjacent waterlines are not discovered?
                    # Test this with an appropriate test model.)
                    points = [waterline.p1, waterline.p2] + points_above
                    for p1 in points:
                        for p2 in points:
                            if p1 is not p2:
                                edges.append(Line(p1, p2))
                    edges.sort(key=lambda x: x.len)
                    edge = edges[-1]
                    if pdot(pcross(edge.dir, triangle.normal), up_vector) < 0:
                        outer_edges = [Line(edge.p2, edge.p1)]
                    else:
                        outer_edges = [edge]
    # calculate the maximum diagonal length within the model
    x_dim = abs(model.maxx - model.minx)
    y_dim = abs(model.maxy - model.miny)
    z_dim = abs(model.maxz - model.minz)
    max_length = sqrt(x_dim ** 2 + y_dim ** 2 + z_dim ** 2)
    result = []
    for edge in outer_edges:
        direction = pnormalized(pcross(up_vector, edge.dir))
        if direction is None:
            continue
        direction = pmul(direction, max_length)
        edge_dir = psub(edge.p2, edge.p1)
        # TODO: Adapt the number of potential starting positions to the length
        # of the line. Don't use 0.0 and 1.0 - this could result in ambiguous
        # collisions with triangles sharing these vertices.
        for factor in (0.5, epsilon, 1.0 - epsilon, 0.25, 0.75):
            start = padd(edge.p1, pmul(edge_dir, factor))
            # We need to use the triangle collision algorithm here - because we
            # need the point of collision in the triangle.
            collisions = get_free_paths_triangles([model], cutter, start, padd(start, direction),
                                                  return_triangles=True)
            for index, coll in enumerate(collisions):
                if ((index % 2 == 0) and (coll[1] is not None)
                        and (coll[2] is not None)
                        and (pdot(psub(coll[0], start), direction) > 0)):
                    cl, hit_t, cp = coll
                    break
            else:
                log.debug("Failed to detect any collision: %s / %s -> %s", edge, start, direction)
                continue
            proj_cp = plane.get_point_projection(cp)
            # e.g. the Spherical Cutter often does not collide exactly above
            # the potential collision line.
            # TODO: maybe an "is cp inside of the triangle" check would be good?
            if (triangle is hit_t) or (edge.is_point_inside(proj_cp)):
                result.append((cl, edge))
                # continue with the next outer_edge
                break
    # Don't check triangles again that are completely above the z level and
    # did not return any collisions.
    if not result and (triangle.minz > z):
        # None indicates that the triangle needs no further evaluation
        return None
    return result


def get_shifted_waterline(up_vector, waterline, cutter_location):
    # Project the waterline and the cutter location down to the slice plane.
    # This is necessary for calculating the horizontal distance between the
    # cutter and the triangle waterline.
    plane = Plane(cutter_location, up_vector)
    wl_proj = plane.get_line_projection(waterline)
    if wl_proj.len < epsilon:
        return None
    offset = wl_proj.dist_to_point(cutter_location)
    if offset < epsilon:
        return wl_proj
    # shift both ends of the waterline towards the cutter location
    shift = psub(cutter_location, wl_proj.closest_point(cutter_location))
    # increase the shift width slightly to avoid "touch" collisions
    shift = pmul(shift, 1.0 + epsilon)
    shifted_waterline = Line(padd(wl_proj.p1, shift), padd(wl_proj.p2, shift))
    return shifted_waterline
