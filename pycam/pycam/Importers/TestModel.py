"""
Copyright 2008-2009 Lode Leroy

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

from pycam.Geometry.Triangle import Triangle
from pycam.Geometry.Line import Line
from pycam.Geometry.Model import Model


def get_test_model():
    points = []
    points.append((-2, 1, 4))
    points.append((2, 1, 4))
    points.append((0, -2, 4))
    points.append((-5, 2, 2))
    points.append((-1, 3, 2))
    points.append((5, 2, 2))
    points.append((4, -1, 2))
    points.append((2, -4, 2))
    points.append((-2, -4, 2))
    points.append((-3, -2, 2))

    lines = []
    lines.append(Line(points[0], points[1]))
    lines.append(Line(points[1], points[2]))
    lines.append(Line(points[2], points[0]))
    lines.append(Line(points[0], points[3]))
    lines.append(Line(points[3], points[4]))
    lines.append(Line(points[4], points[0]))
    lines.append(Line(points[4], points[1]))
    lines.append(Line(points[4], points[5]))
    lines.append(Line(points[5], points[1]))
    lines.append(Line(points[5], points[6]))
    lines.append(Line(points[6], points[1]))
    lines.append(Line(points[6], points[2]))
    lines.append(Line(points[6], points[7]))
    lines.append(Line(points[7], points[2]))
    lines.append(Line(points[7], points[8]))
    lines.append(Line(points[8], points[2]))
    lines.append(Line(points[8], points[9]))
    lines.append(Line(points[9], points[2]))
    lines.append(Line(points[9], points[0]))
    lines.append(Line(points[9], points[3]))

    model = Model()
    for p1, p2, p3, l1, l2, l3 in ((0, 1, 2, 0, 1, 2),
                                   (0, 3, 4, 3, 4, 5),
                                   (0, 4, 1, 5, 6, 0),
                                   (1, 4, 5, 6, 7, 8),
                                   (1, 5, 6, 8, 9, 10),
                                   (1, 6, 2, 10, 11, 1),
                                   (2, 6, 7, 11, 12, 13),
                                   (2, 7, 8, 13, 14, 15),
                                   (2, 8, 9, 15, 16, 17),
                                   (2, 9, 0, 17, 18, 2),
                                   (0, 9, 3, 18, 19, 3)):
        model.append(Triangle(points[p1], points[p2], points[p3]))
    return model
