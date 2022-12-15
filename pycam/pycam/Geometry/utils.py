"""
Copyright 2008 Lode Leroy

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

from pycam.Geometry import ceil, epsilon
import pycam.Geometry.Matrix as Matrix
from pycam.Geometry.Line import Line
from pycam.Geometry.PointUtils import padd, pcross, pdist, pdot, pmul, pnormalized, psub


def get_bisector(p1, p2, p3, up_vector):
    """ Calculate the bisector between p1, p2 and p3, whereas p2 is the origin
    of the angle.
    """
    d1 = pnormalized(psub(p2, p1))
    d2 = pnormalized(psub(p2, p3))
    bisector_dir = pnormalized(padd(d1, d2))
    if bisector_dir is None:
        # the two vectors pointed to opposite directions
        bisector_dir = pnormalized(pcross(d1, up_vector))
    else:
        skel_up_vector = pcross(bisector_dir, psub(p2, p1))
        if pdot(up_vector, skel_up_vector) < 0:
            # reverse the skeleton vector to point outwards
            bisector_dir = pmul(bisector_dir, -1)
    return bisector_dir


def get_angle_pi(p1, p2, p3, up_vector, pi_factor=False):
    """ calculate the angle between three points
    Visualization:
            p3
           /
          /
         /\
        /  \
      p2--------p1
    The result is in a range between 0 and 2*PI.
    """
    d1 = pnormalized(psub(p2, p1))
    d2 = pnormalized(psub(p2, p3))
    if (d1 is None) or (d2 is None):
        return 2 * math.pi
    angle = math.acos(pdot(d1, d2))
    # check the direction of the points (clockwise/anti)
    # The code is taken from Polygon.get_area
    value = [0, 0, 0]
    for (pa, pb) in ((p1, p2), (p2, p3), (p3, p1)):
        value[0] += pa[1] * pb[2] - pa[2] * pb[1]
        value[1] += pa[2] * pb[0] - pa[0] * pb[2]
        value[2] += pa[0] * pb[1] - pa[1] * pb[0]
    area = up_vector[0] * value[0] + up_vector[1] * value[1] + up_vector[2] * value[2]
    if area > 0:
        # The points are in anti-clockwise order. Thus the angle is greater
        # than 180 degree.
        angle = 2 * math.pi - angle
    if pi_factor:
        # the result is in the range of 0..2
        return angle / math.pi
    else:
        return angle


def get_points_of_arc(center, radius, start_degree, end_degree, plane=None, cords=32):
    """ return the points for an approximated arc

    The arc is interpreted as a full circle, if the difference between the start and end angle is
    is a multiple of 360 degrees.

    @param center: center of the circle
    @type center: pycam.Geometry.Point.Point
    @param radius: radius of the arc
    @type radius: float
    @param start_degree: angle of the start (in degree)
    @type start_degree: float
    @param end_degree: angle of the end (in degree)
    @type end_degree: float
    @param plane: the plane of the circle (default: xy-plane)
    @type plane: pycam.Geometry.Plane.Plane
    @param cords: number of lines for a full circle
    @type cords: int
    @return: a list of points approximating the arc
    @rtype: list(pycam.Geometry.Point.Point)
    """
    # TODO: implement 3D arc and respect "plane"
    start_radians = math.pi * start_degree / 180
    end_radians = math.pi * end_degree / 180
    angle_diff = end_radians - start_radians
    while angle_diff < 0:
        angle_diff += 2 * math.pi
        if angle_diff == 0:
            # Do not get stuck at zero, if we started from a negative multiple of 2 * PI.
            angle_diff = 2 * math.pi
    while angle_diff > 2 * math.pi:
        angle_diff -= 2 * math.pi
    if angle_diff == 0:
        return []
    num_of_segments = ceil(angle_diff / (2 * math.pi) * cords)
    angle_segment = angle_diff / num_of_segments
    points = []

    def get_angle_point(angle):
        return (center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), 0)

    points.append(get_angle_point(start_radians))
    for index in range(num_of_segments):
        points.append(get_angle_point(start_radians + angle_segment * (index + 1)))
    return points


def get_bezier_lines(points_with_bulge, segments=32):
    # TODO: add a recursive algorithm for more than two points
    if len(points_with_bulge) != 2:
        return []
    else:
        result_points = []
        p1, bulge1 = points_with_bulge[0]
        p2, bulge2 = points_with_bulge[1]
        if not bulge1 and not bulge2:
            # straight line
            return [Line(p1, p2)]
        straight_dir = pnormalized(psub(p2, p1))
        bulge1 = math.atan(bulge1)
        rot_matrix = Matrix.get_rotation_matrix_axis_angle((0, 0, 1), -2 * bulge1,
                                                           use_radians=True)
        dir1_mat = Matrix.multiply_vector_matrix((straight_dir[0], straight_dir[1],
                                                  straight_dir[2]), rot_matrix)
        dir1 = (dir1_mat[0], dir1_mat[1], dir1_mat[2], 'v')
        if bulge2 is None:
            bulge2 = bulge1
        else:
            bulge2 = math.atan(bulge2)
        rot_matrix = Matrix.get_rotation_matrix_axis_angle((0, 0, 1), 2 * bulge2,
                                                           use_radians=True)
        dir2_mat = Matrix.multiply_vector_matrix((straight_dir[0], straight_dir[1],
                                                  straight_dir[2]), rot_matrix)
        dir2 = (dir2_mat[0], dir2_mat[1], dir2_mat[2], 'v')
        # interpretation of bulge1 and bulge2:
        # /// taken from http://paulbourke.net/dataformats/dxf/dxf10.html ///
        # The bulge is the tangent of 1/4 the included angle for an arc
        # segment, made negative if the arc goes clockwise from the start
        # point to the end point; a bulge of 0 indicates a straight segment,
        # and a bulge of 1 is a semicircle.
        alpha = 2 * (abs(bulge1) + abs(bulge2))
        dist = pdist(p2, p1)
        # calculate the radius of the circumcircle - avoiding divide-by-zero
        if (abs(alpha) < epsilon) or (abs(math.pi - alpha) < epsilon):
            radius = dist / 2.0
        else:
            # see http://en.wikipedia.org/wiki/Law_of_sines
            radius = abs(dist / math.sin(alpha / 2.0)) / 2.0
        # The calculation of "factor" is based on random guessing - but it
        # seems to work well.
        factor = 4 * radius * math.tan(alpha / 4.0)
        dir1 = pmul(dir1, factor)
        dir2 = pmul(dir2, factor)
        for index in range(segments + 1):
            # t: 0..1
            t = float(index) / segments
            # see: http://en.wikipedia.org/wiki/Cubic_Hermite_spline
            p = padd(pmul(p1, 2 * t ** 3 - 3 * t ** 2 + 1),
                     padd(pmul(dir1, t ** 3 - 2 * t ** 2 + t),
                          padd(pmul(p2, -2 * t ** 3 + 3 * t ** 2), pmul(dir2, t ** 3 - t ** 2))))
            result_points.append(p)
        # create lines
        result = []
        for index in range(len(result_points) - 1):
            result.append(Line(result_points[index], result_points[index + 1]))
        return result
