"""
Copyright 2008-2010 Lode Leroy
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

import math
import uuid

from pycam.Geometry import epsilon, INFINITE, TransformableContainer, IDGenerator, Box3D, Point3D
from pycam.Geometry.Matrix import TRANSFORMATIONS
from pycam.Geometry.Line import Line
from pycam.Geometry.Plane import Plane
from pycam.Geometry.Polygon import Polygon
from pycam.Geometry.PointUtils import pcross, pdist, pmul, pnorm, pnormalized, psub
from pycam.Geometry.Triangle import Triangle
from pycam.Geometry.TriangleKdtree import TriangleKdtree
from pycam.Toolpath import Bounds
from pycam.Utils import ProgressCounter
import pycam.Utils.log
log = pycam.Utils.log.get_logger()


def get_combined_bounds(models):
    low = [None, None, None]
    high = [None, None, None]
    for model in models:
        if (low[0] is None) or ((model.minx is not None) and (model.minx < low[0])):
            low[0] = model.minx
        if (low[1] is None) or ((model.miny is not None) and (model.miny < low[1])):
            low[1] = model.miny
        if (low[2] is None) or ((model.minz is not None) and (model.minz < low[2])):
            low[2] = model.minz
        if (high[0] is None) or ((model.maxx is not None) and (model.maxx > high[0])):
            high[0] = model.maxx
        if (high[1] is None) or ((model.maxy is not None) and (model.maxy > high[1])):
            high[1] = model.maxy
        if (high[2] is None) or ((model.maxz is not None) and (model.maxz > high[2])):
            high[2] = model.maxz
    if None in low or None in high:
        return None
    else:
        return Box3D(Point3D(*low), Point3D(*high))


def get_combined_model(models):
    # remove all "None" models
    models = [model for model in models if model is not None]
    if not models:
        return None
    result = models.pop(0).copy()
    while models:
        result += models.pop(0)
    return result


class BaseModel(IDGenerator, TransformableContainer):

    def __init__(self):
        super().__init__()
        self._item_groups = []
        self.name = "model%d" % self.id
        self.minx = None
        self.miny = None
        self.minz = None
        self.maxx = None
        self.maxy = None
        self.maxz = None
        # derived classes should override this
        self._export_function = None

    def __add__(self, other_model):
        """ combine two models """
        result = self.copy()
        for item in next(other_model):
            result.append(item.copy())
        return result

    def __len__(self):
        """ Return the number of available items in the model.
        This is mainly useful for evaluating an empty model as False.
        """
        return sum([len(igroup) for igroup in self._item_groups])

    def __next__(self):
        for item_group in self._item_groups:
            for item in item_group:
                if isinstance(item, list):
                    for subitem in item:
                        yield subitem
                else:
                    yield item

    def get_children_count(self):
        result = 0
        for item_group in self._item_groups:
            for item in item_group:
                if hasattr(item, "get_children_count"):
                    result += item.get_children_count()
                else:
                    try:
                        result += len(item)
                    except TypeError:
                        result += 1
        return result

    def is_export_supported(self):
        return self._export_function is not None

    def export(self, **kwargs):
        if self.is_export_supported():
            return self._export_function(self, **kwargs)
        else:
            raise NotImplementedError(("This type of model (%s) does not support the 'export' "
                                       "function.") % str(type(self)))

    def _update_limits(self, item):
        # Ignore items without limit attributes (e.g. the normal of a
        # ContourModel).
        if hasattr(item, "minx"):
            if self.minx is None:
                self.minx = item.minx
                self.miny = item.miny
                self.minz = item.minz
                self.maxx = item.maxx
                self.maxy = item.maxy
                self.maxz = item.maxz
            else:
                self.minx = min(self.minx, item.minx)
                self.miny = min(self.miny, item.miny)
                self.minz = min(self.minz, item.minz)
                self.maxx = max(self.maxx, item.maxx)
                self.maxy = max(self.maxy, item.maxy)
                self.maxz = max(self.maxz, item.maxz)

    def append(self, item):
        self._update_limits(item)

    def extend(self, items):
        for item in items:
            self.append(item)

    def subdivide(self, depth):
        model = self.__class__()
        for item in next(self):
            for s in item.subdivide(depth):
                model.append(s)
        return model

    def reset_cache(self):
        self.minx = None
        self.miny = None
        self.minz = None
        self.maxx = None
        self.maxy = None
        self.maxz = None
        for item in next(self):
            self._update_limits(item)

    def _get_progress_callback(self, update_callback):
        if update_callback:
            return ProgressCounter(self.get_children_count(),
                                   update_callback=update_callback).increment
        else:
            return None

    def transform_by_template(self, direction="normal", callback=None):
        if direction in TRANSFORMATIONS.keys():
            self.transform_by_matrix(TRANSFORMATIONS[direction],
                                     callback=self._get_progress_callback(callback))

    def shift(self, shift_x, shift_y, shift_z, callback=None):
        matrix = ((1, 0, 0, shift_x), (0, 1, 0, shift_y), (0, 0, 1, shift_z))
        self.transform_by_matrix(matrix, callback=self._get_progress_callback(callback))

    def scale(self, scale_x, scale_y=None, scale_z=None, callback=None):
        if scale_y is None:
            scale_y = scale_x
        if scale_z is None:
            scale_z = scale_x
        matrix = ((scale_x, 0, 0, 0), (0, scale_y, 0, 0), (0, 0, scale_z, 0))
        self.transform_by_matrix(matrix, callback=self._get_progress_callback(callback))

    def _shift_to_origin(self, position, callback=None):
        if position != Point3D(0, 0, 0):
            self.shift(*(pmul(position, -1)), callback=callback)

    def _shift_origin_to(self, position, callback=None):
        if position != Point3D(0, 0, 0):
            self.shift(*position, callback=callback)

    def rotate(self, center, axis_vector, angle, callback=None):
        # shift the model to the rotation center
        self._shift_to_origin(center, callback=callback)
        # rotate the model
        matrix = pycam.Geometry.Matrix.get_rotation_matrix_axis_angle(axis_vector, angle,
                                                                      use_radians=False)
        self.transform_by_matrix(matrix, callback=callback)
        # shift the model back to its original position
        self._shift_origin_to(center, callback=callback)

    def get_bounds(self):
        return Bounds(Bounds.TYPE_CUSTOM, Box3D(Point3D(self.minx, self.miny, self.minz),
                                                Point3D(self.maxx, self.maxy, self.maxz)))


class Model(BaseModel):

    def __init__(self, use_kdtree=True):
        import pycam.Exporters.STLExporter
        super().__init__()
        self._triangles = []
        self._item_groups.append(self._triangles)
        self._export_function = pycam.Exporters.STLExporter.STLExporter
        # marker for state of kdtree and uuid
        self._dirty = True
        # enable/disable kdtree
        self._use_kdtree = use_kdtree
        self._t_kdtree = None
        self.__uuid = None

    def __len__(self):
        """ Return the number of available items in the model.
        This is mainly useful for evaluating an empty model as False.
        """
        return len(self._triangles)

    def __iter__(self):
        yield from self._triangles

    def copy(self):
        result = self.__class__(use_kdtree=self._use_kdtree)
        for triangle in self.triangles():
            result.append(triangle.copy())
        return result

    @property
    def uuid(self):
        if (self.__uuid is None) or self._dirty:
            self._update_caches()
        return self.__uuid

    def append(self, item):
        super().append(item)
        if isinstance(item, Triangle):
            self._triangles.append(item)
            # we assume, that the kdtree needs to be rebuilt again
            self._dirty = True

    def reset_cache(self):
        super().reset_cache()
        # the triangle kdtree needs to be reset after transforming the model
        self._update_caches()

    def _update_caches(self):
        if self._use_kdtree:
            self._t_kdtree = TriangleKdtree(self.triangles())
        self.__uuid = str(uuid.uuid4())
        # the kdtree is up-to-date again
        self._dirty = False

    def triangles(self, minx=-INFINITE, miny=-INFINITE, minz=-INFINITE, maxx=+INFINITE,
                  maxy=+INFINITE, maxz=+INFINITE):
        if (minx == miny == minz == -INFINITE) and (maxx == maxy == maxz == +INFINITE):
            return self._triangles
        if self._use_kdtree:
            # update the kdtree, if new triangles were added meanwhile
            if self._dirty:
                self._update_caches()
            return self._t_kdtree.search(minx, maxx, miny, maxy)
        return self._triangles

    def get_waterline_contour(self, plane, callback=None):
        collision_lines = []
        progress_max = 2 * len(self._triangles)
        counter = 0
        for t in self._triangles:
            if callback and callback(percent=100.0 * counter / progress_max):
                return
            collision_line = plane.intersect_triangle(t, counter_clockwise=True)
            if collision_line is not None:
                collision_lines.append(collision_line)
            else:
                counter += 1
            counter += 1
        # combine these lines into polygons
        contour = ContourModel(plane=plane)
        for line in collision_lines:
            if callback and callback(percent=100.0 * counter / progress_max):
                return
            contour.append(line)
            counter += 1
        log.debug("Waterline: %f - %d - %s", plane.p[2], len(contour.get_polygons()),
                  [len(p.get_lines()) for p in contour.get_polygons()])
        return contour


class ContourModel(BaseModel):

    def __init__(self, plane=None):
        import pycam.Exporters.SVGExporter
        super().__init__()
        self.name = "contourmodel%d" % self.id
        if plane is None:
            # the default plane points upwards along the z axis
            plane = Plane((0, 0, 0), (0, 0, 1, 'v'))
        self._plane = plane
        self._line_groups = []
        self._item_groups.append(self._line_groups)
        # there is always just one plane
        self._plane_groups = [self._plane]
        self._item_groups.append(self._plane_groups)
        self._export_function = pycam.Exporters.SVGExporter.SVGExporterContourModel

    def __len__(self):
        """ Return the number of available items in the model.
        This is mainly useful for evaluating an empty model as False.
        """
        return len(self._line_groups)

    def __iter__(self):
        yield from self.get_polygons()

    def copy(self):
        result = self.__class__(plane=self._plane.copy())
        for polygon in self.get_polygons():
            result.append(polygon.copy())
        return result

    def _merge_polygon_if_possible(self, other_polygon, allow_reverse=False):
        """ Check if the given 'other_polygon' can be connected to another
        polygon of the the current model. Both polygons are merged if possible.
        This function should be called after any "append" event, if the lines to
        be added are given in a random order (e.g. by the "waterline" function).
        """
        if other_polygon.is_closed:
            return
        connectors = []
        connectors.append(other_polygon.get_points()[0])
        connectors.append(other_polygon.get_points()[-1])
        # filter all polygons that can be combined with 'other_polygon'
        connectables = []
        for lg in self._line_groups:
            if lg is other_polygon:
                continue
            for connector in connectors:
                if lg.is_connectable(connector):
                    connectables.append(lg)
                    break
        # merge 'other_polygon' with all other connectable polygons
        for polygon in connectables:
            # check again, if the polygon is still connectable
            for connector in connectors:
                if polygon.is_connectable(connector):
                    break
            else:
                # skip this polygon
                continue
            if other_polygon.get_points()[-1] == polygon.get_points()[0]:
                for line in polygon.get_lines():
                    if other_polygon.is_closed:
                        return
                    other_polygon.append(line)
                self._line_groups.remove(polygon)
            elif other_polygon.get_points()[0] == polygon.get_points()[-1]:
                lines = polygon.get_lines()
                lines.reverse()
                for line in lines:
                    if other_polygon.is_closed:
                        return
                    other_polygon.append(line)
                self._line_groups.remove(polygon)
            elif allow_reverse:
                if other_polygon.get_points()[-1] == polygon.get_points()[-1]:
                    polygon.reverse_direction()
                    for line in polygon.get_lines():
                        if other_polygon.is_closed:
                            return
                        other_polygon.append(line)
                    self._line_groups.remove(polygon)
                elif other_polygon.get_points()[0] == polygon.get_points()[0]:
                    polygon.reverse_direction()
                    lines = polygon.get_lines()
                    lines.reverse()
                    for line in lines:
                        if other_polygon.is_closed:
                            return
                        other_polygon.append(line)
                    self._line_groups.remove(polygon)
                else:
                    pass
            else:
                pass
            if other_polygon.is_closed:
                # we are finished
                return

    def append(self, item, unify_overlaps=False, allow_reverse=False):
        super().append(item)
        if isinstance(item, Line):
            item_list = [item]
            if allow_reverse:
                item_list.append(Line(item.p2, item.p1))
            found = False
            # Going back from the end to start. The last line_group always has
            # the highest chance of being suitable for the next line.
            line_group_indexes = range(len(self._line_groups) - 1, -1, -1)
            for line_group_index in line_group_indexes:
                line_group = self._line_groups[line_group_index]
                for candidate in item_list:
                    if line_group.is_connectable(candidate):
                        line_group.append(candidate)
                        self._merge_polygon_if_possible(line_group, allow_reverse=allow_reverse)
                        found = True
                        break
                if found:
                    break
            else:
                # add a single line as part of a new group
                new_line_group = Polygon(plane=self._plane)
                new_line_group.append(item)
                self._line_groups.append(new_line_group)
        elif isinstance(item, Polygon):
            if not unify_overlaps or (len(self._line_groups) == 0):
                self._line_groups.append(item)
                for subitem in next(item):
                    self._update_limits(subitem)
            else:
                # go through all polygons and check if they can be combined
                is_outer = item.is_outer()
                new_queue = [item]
                processed_polygons = []
                queue = self.get_polygons()
                while len(queue) > 0:
                    polygon = queue.pop()
                    if polygon.is_outer() != is_outer:
                        processed_polygons.append(polygon)
                    else:
                        processed = []
                        while len(new_queue) > 0:
                            new = new_queue.pop()
                            if new.is_polygon_inside(polygon):
                                # "polygon" is obsoleted by "new"
                                processed.extend(new_queue)
                                break
                            elif polygon.is_polygon_inside(new):
                                # "new" is obsoleted by "polygon"
                                continue
                            elif not new.is_overlap(polygon):
                                processed.append(new)
                                continue
                            else:
                                union = polygon.union(new)
                                if union:
                                    for p in union:
                                        if p.is_outer() == is_outer:
                                            new_queue.append(p)
                                        else:
                                            processed_polygons.append(p)
                                else:
                                    processed.append(new)
                                break
                        else:
                            processed_polygons.append(polygon)
                        new_queue = processed
                while len(self._line_groups) > 0:
                    self._line_groups.pop()
                log.info("Processed polygons: %s", [len(p.get_lines())
                                                    for p in processed_polygons])
                log.info("New queue: %s", [len(p.get_lines()) for p in new_queue])
                for processed_polygon in processed_polygons + new_queue:
                    self._line_groups.append(processed_polygon)
                # TODO: this is quite expensive - can we do it differently?
                self.reset_cache()
        else:
            # ignore any non-supported items (they are probably handled by a
            # parent class)
            pass

    def get_polygons(self, z=None, ignore_below=True):
        if z is None:
            return self._line_groups
        elif ignore_below:
            return [group for group in self._line_groups if group.minz == z]
        else:
            return [group for group in self._line_groups if group.minz <= z]

    def revise_directions(self, callback=None):
        """ Go through all open polygons and try to merge them regardless of
        their direction. Afterwards all closed polygons are analyzed regarding
        their inside/outside relationships.
        Beware: never use this function if the direction of lines may not
        change.
        """
        number_of_initial_closed_polygons = len([poly for poly in self.get_polygons()
                                                 if poly.is_closed])
        open_polygons = [poly for poly in self.get_polygons() if not poly.is_closed]
        if callback:
            progress_callback = pycam.Utils.ProgressCounter(
                2 * number_of_initial_closed_polygons + len(open_polygons), callback).increment
        else:
            progress_callback = None
        # try to connect all open polygons
        for poly in open_polygons:
            self._line_groups.remove(poly)
        poly_open_before = len(open_polygons)
        for poly in open_polygons:
            for line in poly.get_lines():
                self.append(line, allow_reverse=True)
            if progress_callback and progress_callback():
                return
        poly_open_after = len([poly for poly in self.get_polygons() if not poly.is_closed])
        if poly_open_before != poly_open_after:
            log.info("Reduced the number of open polygons from %d down to %d",
                     poly_open_before, poly_open_after)
        else:
            log.debug("No combineable open polygons found")
        # auto-detect directions of closed polygons: inside and outside
        finished = []
        remaining_polys = [poly for poly in self.get_polygons() if poly.is_closed]
        if progress_callback:
            # shift the counter back by the number of new closed polygons
            progress_callback(2 * (number_of_initial_closed_polygons - len(remaining_polys)))
        remaining_polys.sort(key=lambda poly: abs(poly.get_area()))
        while remaining_polys:
            # pick the largest polygon
            current = remaining_polys.pop()
            # start with the smallest finished polygon
            for comp, is_outer in finished:
                if comp.is_polygon_inside(current):
                    finished.insert(0, (current, not is_outer))
                    break
            else:
                # no enclosing polygon was found
                finished.insert(0, (current, True))
            if progress_callback and progress_callback():
                return
        # Adjust the directions of all polygons according to the result
        # of the previous analysis.
        change_counter = 0
        for polygon, is_outer in finished:
            if polygon.is_outer() != is_outer:
                polygon.reverse_direction()
                change_counter += 1
            if progress_callback and progress_callback():
                self.reset_cache()
                return
        log.info("The winding of %d polygon(s) was fixed.", change_counter)
        self.reset_cache()

    def reverse_directions(self, callback=None):
        if callback:
            progress_callback = pycam.Utils.ProgressCounter(len(self.get_polygons()),
                                                            callback).increment
        else:
            progress_callback = None
        for polygon in self._line_groups:
            polygon.reverse_direction()
            if progress_callback and progress_callback():
                self.reset_cache()
                return
        self.reset_cache()

    def get_reversed(self):
        result = ContourModel(plane=self._plane)
        for poly in self.get_polygons():
            result.append(poly.get_reversed())
        return result

    def get_cropped_model_by_bounds(self, bounds):
        low, high = bounds.get_absolute_limits()
        return self.get_cropped_model(low[0], high[0], low[1], high[1], low[2], high[2])

    def get_cropped_model(self, minx, maxx, miny, maxy, minz, maxz):
        new_line_groups = []
        for group in self._line_groups:
            new_groups = group.get_cropped_polygons(minx, maxx, miny, maxy, minz, maxz)
            if new_groups is not None:
                new_line_groups.extend(new_groups)
        if len(new_line_groups) > 0:
            result = ContourModel(plane=self._plane)
            for group in new_line_groups:
                result.append(group)
            return result
        else:
            return None

    def get_offset_model(self, offset, callback=None):
        result = ContourModel(plane=self._plane)
        for group in self.get_polygons():
            new_groups = group.get_offset_polygons(offset, callback=callback)
            result.extend(new_groups)
            if callback and callback():
                return None
        return result

    def extrude(self, stepping=None, func=None, callback=None):
        """ do a spherical extrusion of a 2D model.
        This is mainly useful for extruding text in a visually pleasant way ...
        """
        outer_polygons = [(poly, []) for poly in self._line_groups if poly.is_outer()]
        for poly in self._line_groups:
            # ignore open polygons
            if not poly.is_closed:
                continue
            if poly.is_outer():
                continue
            for outer_poly, children in outer_polygons:
                if outer_poly == poly:
                    break
                if outer_poly.is_polygon_inside(poly):
                    children.append(poly)
                    break
        model = Model()
        for poly, children in outer_polygons:
            if callback and callback():
                return None
            group = PolygonGroup(poly, children, callback=callback)
            new_model = group.extrude(func=func, stepping=stepping)
            if new_model:
                model += new_model
        return model

    def get_flat_projection(self, plane):
        result = ContourModel(plane)
        for polygon in self.get_polygons():
            new_polygon = polygon.get_plane_projection(plane)
            if new_polygon:
                result.append(new_polygon)
        return result or None


class PolygonGroup:
    """ A PolygonGroup consists of one outer and maybe multiple inner polygons.
    It is mainly used for 3D extrusion of polygons.
    """

    def __init__(self, outer, inner_list, callback=None):
        self.outer = outer
        self.inner = inner_list
        self.callback = callback
        self.lines = outer.get_lines()
        self.z_level = self.lines[0].p1[2]
        for poly in inner_list:
            self.lines.extend(poly.get_lines())

    def extrude(self, func=None, stepping=None):
        if stepping is None:
            stepping = min(self.outer.maxx - self.outer.minx,
                           self.outer.maxy - self.outer.miny) / 80
        grid = []
        for line in self._get_grid_matrix(stepping=stepping):
            line_points = []
            for x, y in line:
                z = self.calculate_point_height(x, y, func)
                line_points.append((x, y, z))
            if self.callback and self.callback():
                return None
            grid.append(line_points)
        # calculate the triangles within the grid
        triangle_optimizer = TriangleOptimizer(callback=self.callback)
        for line in range(len(grid) - 1):
            for row in range(len(grid[0]) - 1):
                coords = []
                coords.append(grid[line][row])
                coords.append(grid[line][row + 1])
                coords.append(grid[line + 1][row + 1])
                coords.append(grid[line + 1][row])
                items = self._fill_grid_positions(coords)
                for item in items:
                    triangle_optimizer.append(item)
                    # create the backside plane
                    backside_points = []
                    for p in item.get_points():
                        backside_points.insert(0, (p[0], p[1], self.z_level))
                    triangle_optimizer.append(Triangle(*backside_points))
            if self.callback and self.callback():
                return None
        triangle_optimizer.optimize()
        model = Model()
        for triangle in triangle_optimizer.get_triangles():
            model.append(triangle)
        return model

    def _get_closest_line_collision(self, probe_line):
        min_dist = None
        min_cp = None
        for line in self.lines:
            cp, dist = probe_line.get_intersection(line)
            if cp and ((min_dist is None) or (dist < min_dist)):
                min_dist = dist
                min_cp = cp
        if min_dist > 0:
            return min_cp
        else:
            return None

    def _fill_grid_positions(self, coords):
        """ Try to find suitable alternatives, if any of the corners of this
        square grid is not valid.
        The current strategy: find the points of intersection with the contour
        on all incomplete edges of the square.
        The _good_ strategy would be: crop the square by using all related
        lines of the contour.
        """
        def get_line(i1, i2):
            a = list(coords[i1 % 4])
            b = list(coords[i2 % 4])
            # the contour points of the model will always be at level zero
            a[2] = self.z_level
            b[2] = self.z_level
            return Line(a, b)

        valid_indices = [index for index, p in enumerate(coords) if p[2] is not None]
        none_indices = [index for index, p in enumerate(coords) if p[2] is None]
        valid_count = len(valid_indices)
        final_points = []
        if valid_count == 0:
            final_points.extend([None, None, None, None])
        elif valid_count == 1:
            fan_points = []
            for index in range(4):
                if index in none_indices:
                    probe_line = get_line(valid_indices[0], index)
                    cp = self._get_closest_line_collision(probe_line)
                    if cp:
                        fan_points.append(cp)
                    final_points.append(cp)
                else:
                    final_points.append(coords[index])
            # check if the three fan_points are in line
            if len(fan_points) == 3:
                fan_points.sort()
                if Line(fan_points[0], fan_points[2]).is_point_inside(fan_points[1]):
                    final_points.remove(fan_points[1])
        elif valid_count == 2:
            if sum(valid_indices) % 2 == 0:
                # the points are on opposite corners
                # The strategy below is not really good, but this special case
                # is hardly possible, anyway.
                for index in range(4):
                    if index in valid_indices:
                        final_points.append(coords[index])
                    else:
                        probe_line = get_line(index - 1, index)
                        cp = self._get_closest_line_collision(probe_line)
                        final_points.append(cp)
            else:
                for index in range(4):
                    if index in valid_indices:
                        final_points.append(coords[index])
                    else:
                        if ((index + 1) % 4) in valid_indices:
                            other_index = index + 1
                        else:
                            other_index = index - 1
                        probe_line = get_line(other_index, index)
                        cp = self._get_closest_line_collision(probe_line)
                        final_points.append(cp)
        elif valid_count == 3:
            for index in range(4):
                if index in valid_indices:
                    final_points.append(coords[index])
                else:
                    # add two points
                    for other_index in (index - 1, index + 1):
                        probe_line = get_line(other_index, index)
                        cp = self._get_closest_line_collision(probe_line)
                        final_points.append(cp)
        else:
            final_points.extend(coords)
        valid_points = []
        for p in final_points:
            if (p is not None) and (p not in valid_points):
                valid_points.append(p)
        if len(valid_points) < 3:
            result = []
        elif len(valid_points) == 3:
            result = [Triangle(*valid_points)]
        else:
            # create a simple star-like fan of triangles - not perfect, but ok
            result = []
            start = valid_points.pop(0)
            while len(valid_points) > 1:
                p2, p3 = valid_points[0:2]
                result.append(Triangle(start, p2, p3))
                valid_points.pop(0)
        return result

    def _get_grid_matrix(self, stepping):
        x_dim = self.outer.maxx - self.outer.minx
        y_dim = self.outer.maxy - self.outer.miny
        x_points_num = int(max(4, math.ceil(x_dim / stepping)))
        y_points_num = int(max(4, math.ceil(y_dim / stepping)))
        x_step = x_dim / (x_points_num - 1)
        y_step = y_dim / (y_points_num - 1)
        grid = []
        for x_index in range(x_points_num):
            line = []
            for y_index in range(y_points_num):
                x_value = self.outer.minx + x_index * x_step
                y_value = self.outer.miny + y_index * y_step
                line.append((x_value, y_value))
            grid.append(line)
        return grid

    def calculate_point_height(self, x, y, func):
        point = (x, y, self.outer.minz)
        if not self.outer.is_point_inside(point):
            return None
        for poly in self.inner:
            if poly.is_point_inside(point):
                return None
        point = (x, y, self.outer.minz)
        line_distances = []
        for line in self.lines:
            cross_product = pcross(line.dir, psub(point, line.p1))
            if cross_product[2] > 0:
                close_points = []
                close_point = line.closest_point(point)
                if not line.is_point_inside(close_point):
                    close_points.append(line.p1)
                    close_points.append(line.p2)
                else:
                    close_points.append(close_point)
                for p in close_points:
                    direction = psub(point, p)
                    dist = pnorm(direction)
                    line_distances.append(dist)
            elif cross_product[2] == 0:
                # the point is on the line
                line_distances.append(0.0)
                # no other line can get closer than this
                break
            else:
                # the point is in the left of this line
                pass
        line_distances.sort()
        return self.z_level + func(line_distances[0])


class TriangleOptimizer:

    def __init__(self, callback=None):
        self.groups = {}
        self.callback = callback

    def append(self, triangle):
        # use a simple tuple instead of an object as the dict's key
        normal = triangle.normal
        if normal not in self.groups:
            self.groups[normal] = []
        self.groups[normal].append(triangle)

    def optimize(self):
        for group in self.groups.values():
            finished_triangles = []
            rect_pool = []
            triangles = list(group)
            while triangles:
                if self.callback and self.callback():
                    return
                current = triangles.pop(0)
                for t in triangles:
                    combined = Rectangle.combine_triangles(current, t)
                    if combined:
                        triangles.remove(t)
                        rect_pool.append(combined)
                        break
                else:
                    finished_triangles.append(current)
            finished_rectangles = []
            while rect_pool:
                if self.callback and self.callback():
                    return
                current = rect_pool.pop(0)
                for r in rect_pool:
                    combined = Rectangle.combine_rectangles(current, r)
                    if combined:
                        rect_pool.remove(r)
                        rect_pool.append(combined)
                        break
                else:
                    finished_rectangles.append(current)
            while group:
                group.pop()
            for rect in finished_rectangles:
                group.extend(rect.get_triangles())
            group.extend(finished_triangles)

    def get_triangles(self):
        result = []
        for group in self.groups.values():
            result.extend(group)
        return result


class Rectangle(IDGenerator, TransformableContainer):

    def __init__(self, p1, p2, p3, p4, normal=None):
        super().__init__()
        if normal:
            orders = ((p1, p2, p3, p4), (p1, p2, p4, p3), (p1, p3, p2, p4), (p1, p3, p4, p2),
                      (p1, p4, p2, p3), (p1, p4, p3, p2))
            for order in orders:
                if abs(pdist(order[0], order[2]) - pdist(order[1], order[3])) < epsilon:
                    t1 = Triangle(order[0], order[1], order[2])
                    t2 = Triangle(order[2], order[3], order[0])
                    if t1.normal == t2.normal == normal:
                        self.p1, self.p2, self.p3, self.p4 = order
                        break
            else:
                raise ValueError("Invalid vertices for given normal: %s, %s, %s, %s, %s"
                                 % (p1, p2, p3, p4, normal))
        else:
            self.p1 = p1
            self.p2 = p2
            self.p3 = p3
            self.p4 = p4
        self.reset_cache()

    def reset_cache(self):
        self.maxx = max([p[0] for p in self.get_points()])
        self.minx = max([p[0] for p in self.get_points()])
        self.maxy = max([p[1] for p in self.get_points()])
        self.miny = max([p[1] for p in self.get_points()])
        self.maxz = max([p[2] for p in self.get_points()])
        self.minz = max([p[2] for p in self.get_points()])
        self.normal = pnormalized(Triangle(self.p1, self.p2, self.p3).normal)

    def get_points(self):
        return (self.p1, self.p2, self.p3, self.p4)

    def __next__(self):
        yield "p1"
        yield "p2"
        yield "p3"
        yield "p4"

    def __repr__(self):
        return "Rectangle%d<%s,%s,%s,%s>" % (self.id, self.p1, self.p2, self.p3, self.p4)

    def get_triangles(self):
        return (Triangle(self.p1, self.p2, self.p3),
                Triangle(self.p3, self.p4, self.p1))

    @staticmethod
    def combine_triangles(t1, t2):
        unique_vertices = []
        shared_vertices = []
        for point in t1.get_points():
            for point2 in t2.get_points():
                if point == point2:
                    shared_vertices.append(point)
                    break
            else:
                unique_vertices.append(point)
        if len(shared_vertices) != 2:
            return None
        for point in t2.get_points():
            for point2 in shared_vertices:
                if point == point2:
                    break
            else:
                unique_vertices.append(point)
        if len(unique_vertices) != 2:
            log.error("Invalid number of vertices: %s", unique_vertices)
            return None
        if abs(pdist(unique_vertices[0], unique_vertices[1])
               - pdist(shared_vertices[0], shared_vertices[1])) < epsilon:
            try:
                return Rectangle(unique_vertices[0], unique_vertices[1], shared_vertices[0],
                                 shared_vertices[1], normal=t1.normal)
            except ValueError:
                log.warn("Triangles not combined: %s, %s", unique_vertices, shared_vertices)
                return None
        else:
            return None

    @staticmethod
    def combine_rectangles(r1, r2):
        shared_vertices = []
        shared_vertices2 = []
        for point in r1.get_points():
            for point2 in r2.get_points():
                if point == point2:
                    shared_vertices.append(point)
                    shared_vertices2.append(point2)
                    break
        if len(shared_vertices) != 2:
            return None
        # check if the two points form an edge (and not a diagonal line)
        corners = []
        for rectangle, vertices in ((r1, shared_vertices), (r2, shared_vertices2)):
            # turn the tuple into a list (".index" was introduced in Python 2.6)
            i1 = list(rectangle.get_points()).index(vertices[0])
            i2 = list(rectangle.get_points()).index(vertices[1])
            if i1 + i2 % 2 == 0:
                # shared vertices are at opposite corners
                return None
            # collect all non-shared vertices
            corners.extend([p for p in rectangle.get_points() if p not in vertices])
        if len(corners) != 4:
            log.error("Unexpected corner count: %s / %s / %s", r1, r2, corners)
            return None
        try:
            return Rectangle(corners[0], corners[1], corners[2], corners[3], normal=r1.normal)
        except ValueError:
            log.error("No valid rectangle found: %s", corners)
            return None
