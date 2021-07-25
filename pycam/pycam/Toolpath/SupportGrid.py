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

from pycam.Geometry import number
from pycam.Geometry.Model import Model
from pycam.Geometry.Plane import Plane
from pycam.Geometry.PointUtils import padd, pcross, pdot, pdist, pdiv, pmul, pnormalized, psub
from pycam.Geometry.Triangle import Triangle
from pycam.Geometry.utils import get_angle_pi, get_bisector


def _get_triangles_for_face(pts):
    t1 = Triangle(pts[0], pts[1], pts[2])
    t2 = Triangle(pts[2], pts[3], pts[0])
    return (t1, t2)


def _add_cuboid_to_model(model, start, direction, height, width):
    up = pmul((0, 0, 1, 'v'), height)
    ortho_dir = pnormalized(pcross(direction, up))
    start1 = padd(start, pmul(ortho_dir, -width/2))
    start2 = padd(start1, up)
    start3 = padd(start2, pmul(ortho_dir, width))
    start4 = psub(start3, up)
    end1 = padd(start1, direction)
    end2 = padd(start2, direction)
    end3 = padd(start3, direction)
    end4 = padd(start4, direction)
    faces = ((start1, start2, start3, start4), (start1, end1, end2, start2),
             (start2, end2, end3, start3), (start3, end3, end4, start4),
             (start4, end4, end1, start1), (end4, end3, end2, end1))
    for face in faces:
        t1, t2 = _get_triangles_for_face(face)
        model.append(t1)
        model.append(t2)


def _add_aligned_cuboid_to_model(minx, maxx, miny, maxy, minz, maxz):
    points = ((minx, miny, minz), (maxx, miny, minz), (maxx, maxy, minz), (minx, maxy, minz),
              (minx, miny, maxz), (maxx, miny, maxz), (maxx, maxy, maxz), (minx, maxy, maxz))
    triangles = []
    # lower face
    triangles.extend(_get_triangles_for_face((points[0], points[1], points[2], points[3])))
    # upper face
    triangles.extend(_get_triangles_for_face((points[7], points[6], points[5], points[4])))
    # front face
    triangles.extend(_get_triangles_for_face((points[0], points[4], points[5], points[1])))
    # back face
    triangles.extend(_get_triangles_for_face((points[2], points[6], points[7], points[3])))
    # right face
    triangles.extend(_get_triangles_for_face((points[1], points[5], points[6], points[2])))
    # left face
    triangles.extend(_get_triangles_for_face((points[3], points[7], points[4], points[0])))
    # add all triangles to the model
    model = Model()
    for t in triangles:
        model.append(t)
    return model


def get_support_grid_locations(minx, maxx, miny, maxy, dist_x, dist_y, offset_x=0.0, offset_y=0.0,
                               adjustments_x=None, adjustments_y=None):
    """ calculate positions of a orthogonal grid of support bridges

    @param minx: minimum x value of the target area
    @param maxx: maximum x value of the target area
    @param miny: minimum y value of the target area
    @param maxy: maximum y value of the target area
    @param dist_x: distance between two lines parallel to the y axis
    @param dist_y: distance between two lines parallel to the x axis
    @param adjustments_x: iterable of offsets to be added to each x position
    @param adjustments_y: iterable of offsets to be added to each y position
    """
    def get_lines(center, dist, min_value, max_value):
        """ generate a list of positions starting from the middle going up and
        and down
        """
        if dist > 0:
            lines = [center]
            current = center
            while current - dist > min_value:
                current -= dist
                lines.insert(0, current)
            current = center
            while current + dist < max_value:
                current += dist
                lines.append(current)
        else:
            lines = []
        # remove lines that are out of range (e.g. due to a huge offset)
        lines = [line for line in lines if min_value < line < max_value]
        return lines

    # convert all inputs to the type defined in "number"
    dist_x = number(dist_x)
    dist_y = number(dist_y)
    offset_x = number(offset_x)
    offset_y = number(offset_y)
    center_x = (maxx + minx) / 2 + offset_x
    center_y = (maxy + miny) / 2 + offset_y
    lines_x = get_lines(center_x, dist_x, minx, maxx)
    lines_y = get_lines(center_y, dist_y, miny, maxy)
    # apply as many offsets from adjustments_x and adjustments_y as available
    for value_list, adjustments in ((lines_x, adjustments_x), (lines_y, adjustments_y)):
        if adjustments:
            for index, (current_value, adjustment) in enumerate(zip(value_list, adjustments)):
                value_list[index] = current_value + number(adjustment)
    return lines_x, lines_y


def get_support_grid(minx, maxx, miny, maxy, z_plane, dist_x, dist_y, thickness, height, length,
                     offset_x=0.0, offset_y=0.0, adjustments_x=None, adjustments_y=None):
    lines_x, lines_y = get_support_grid_locations(minx, maxx, miny, maxy, dist_x, dist_y, offset_x,
                                                  offset_y, adjustments_x, adjustments_y)
    # create all x grid lines
    grid_model = Model()
    # convert all inputs to "number"
    thickness = number(thickness)
    height = number(height)
    # helper variables
    thick_half = thickness / 2
    for line_x in lines_x:
        # we make the grid slightly longer (by thickness) than necessary
        grid_model += _add_aligned_cuboid_to_model(
            line_x - thick_half, line_x + thick_half, miny - length,
            maxy + length, z_plane, z_plane + height)
    for line_y in lines_y:
        # we make the grid slightly longer (by thickness) than necessary
        grid_model += _add_aligned_cuboid_to_model(
            minx - length, maxx + length, line_y - thick_half,
            line_y + thick_half, z_plane, z_plane + height)
    return grid_model


def get_support_distributed(model, z_plane, average_distance, min_bridges_per_polygon, thickness,
                            height, length, bounds=None, start_at_corners=False):
    if (average_distance == 0) or (length == 0) or (thickness == 0) or (height == 0):
        return
    result = Model()
    if not hasattr(model, "get_polygons"):
        model = model.get_waterline_contour(Plane((0, 0, max(model.minz, z_plane)),
                                                  (0, 0, 1, 'v')))
    if model:
        model = model.get_flat_projection(Plane((0, 0, z_plane), (0, 0, 1, 'v')))
    if model and bounds:
        model = model.get_cropped_model_by_bounds(bounds)
    if model:
        polygons = model.get_polygons()
    else:
        return None
    # minimum required distance between two bridge start points
    avoid_distance = 1.5 * (abs(length) + thickness)
    if start_at_corners:
        bridge_calculator = _get_corner_bridges
    else:
        bridge_calculator = _get_edge_bridges
    for polygon in polygons:
        # no grid for _small_ inner polygons
        # TODO: calculate a reasonable factor (see below)
        if polygon.is_closed and (not polygon.is_outer()) \
                and (abs(polygon.get_area()) < 25000 * thickness ** 2):
            continue
        bridges = bridge_calculator(polygon, z_plane, min_bridges_per_polygon, average_distance,
                                    avoid_distance)
        for pos, direction in bridges:
            _add_cuboid_to_model(result, pos, pmul(direction, length), height, thickness)
    return result


class _BridgeCorner:

    # currently we only use the xy plane
    up_vector = (0, 0, 1, 'v')

    def __init__(self, barycenter, location, p1, p2, p3):
        self.location = location
        self.position = p2
        self.direction = pnormalized(get_bisector(p1, p2, p3, self.up_vector))
        preferred_direction = pnormalized(psub(p2, barycenter))
        # direction_factor: 0..1 (bigger -> better)
        direction_factor = (pdot(preferred_direction, self.direction) + 1) / 2
        angle = get_angle_pi(p1, p2, p3, self.up_vector, pi_factor=True)
        # angle_factor: 0..1 (bigger -> better)
        if angle > 0.5:
            # use only angles > 90 degree
            angle_factor = angle / 2.0
        else:
            angle_factor = 0
        # priority: 0..1 (bigger -> better)
        self.priority = angle_factor * direction_factor

    def get_position_priority(self, other_location, average_distance):
        return self.priority / (1 + self.get_distance(other_location) / average_distance)

    def get_distance(self, other_location):
        return min(abs(other_location - self.location), abs(1 + other_location - self.location))

    def __str__(self):
        return "%s (%s) - %s" % (self.position, self.location, self.priority)


def _get_corner_bridges(polygon, z_plane, min_bridges, average_distance, avoid_distance):
    """ try to place support bridges at corners of a polygon
    Priorities:
        - bigger corner angles are preferred
        - directions pointing away from the center of the polygon are preferred
    """
    center = polygon.get_barycenter()
    if center is None:
        # polygon is open or zero-sized
        return []
    points = polygon.get_points()
    poly_lengths = polygon.get_lengths()
    outline = sum(poly_lengths)
    rel_avoid_distance = avoid_distance / outline
    corner_positions = []
    length_sum = 0
    for l in poly_lengths:
        corner_positions.append(length_sum / outline)
        length_sum += l
    num_of_bridges = int(max(min_bridges, round(outline / average_distance)))
    rel_average_distance = 1.0 / num_of_bridges
    corners = []
    for index in range(len(polygon.get_points())):
        p1 = points[(index - 1) % len(points)]
        p2 = points[index % len(points)]
        p3 = points[(index + 1) % len(points)]
        corner = _BridgeCorner(center, corner_positions[index], p1, p2, p3)
        if corner.priority > 0:
            # ignore sharp corners
            corners.append(corner)
    bridge_corners = []
    for index in range(num_of_bridges):
        preferred_position = index * rel_average_distance
        suitable_corners = []
        for corner in corners:
            if corner.get_distance(preferred_position) < rel_average_distance:
                # check if the corner is too close to neighbouring corners
                if (not bridge_corners
                        or ((bridge_corners[-1].get_distance(corner.location)
                             >= rel_avoid_distance)
                            and (bridge_corners[0].get_distance(corner.location)
                                 >= rel_avoid_distance))):
                    suitable_corners.append(corner)
        get_priority = lambda corner: corner.get_position_priority(preferred_position,
                                                                   rel_average_distance)
        suitable_corners.sort(key=get_priority, reverse=True)
        if suitable_corners:
            bridge_corners.append(suitable_corners[0])
            corners.remove(suitable_corners[0])
    return [(c.position, c.direction) for c in bridge_corners]


def _get_edge_bridges(polygon, z_plane, min_bridges, average_distance, avoid_distance):
    def is_near_list(point_list, point, distance):
        for p in point_list:
            if pdist(p, point) <= distance:
                return True
        return False
    lines = polygon.get_lines()
    poly_lengths = polygon.get_lengths()
    num_of_bridges = max(min_bridges, int(round(sum(poly_lengths) / average_distance)))
    real_average_distance = sum(poly_lengths) / num_of_bridges
    max_line_index = poly_lengths.index(max(poly_lengths))
    positions = []
    current_line_index = max_line_index
    distance_processed = poly_lengths[current_line_index] / 2
    positions.append(current_line_index)
    while len(positions) < num_of_bridges:
        current_line_index += 1
        current_line_index %= len(poly_lengths)
        # skip lines that are not at least twice as long as the grid width
        while (distance_processed + poly_lengths[current_line_index] < real_average_distance):
            distance_processed += poly_lengths[current_line_index]
            current_line_index += 1
            current_line_index %= len(poly_lengths)
        positions.append(current_line_index)
        distance_processed += poly_lengths[current_line_index]
        distance_processed %= real_average_distance
    result = []
    bridge_positions = []
    for line_index in positions:
        position = polygon.get_middle_of_line(line_index)
        # skip bridges that are close to another existing bridge
        if is_near_list(bridge_positions, position, avoid_distance):
            line = polygon.get_lines()[line_index]
            # calculate two alternative points on the same line
            position1 = pdiv(padd(position, line.p1), 2)
            position2 = pdiv(padd(position, line.p2), 2)
            if is_near_list(bridge_positions, position1, avoid_distance):
                if is_near_list(bridge_positions, position2, avoid_distance):
                    # no valid alternative - we skip this bridge
                    continue
                else:
                    # position2 is OK
                    position = position2
            else:
                # position1 is OK
                position = position1
        # append the original position (ignoring z_plane)
        bridge_positions.append(position)
        # move the point to z_plane
        position = (position[0], position[1], z_plane)
        bridge_dir = pnormalized(pcross(lines[line_index].dir, polygon.plane.n))
        result.append((position, bridge_dir))
    return result
