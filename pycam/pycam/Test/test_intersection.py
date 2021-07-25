"""
Copyright 2013 Lars Kruse <devel@sumpfralle.de>

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


from pycam.Geometry import INFINITE
import pycam.Geometry.intersection
from pycam.Geometry.Line import Line
from pycam.Geometry.Triangle import Triangle
import pycam.Test
import pytest


class CircleIntersections(pycam.Test.PycamTestCase):
    """Circle collisions"""

    def setUp(self):
        self._circle = {"center": (2, 1, 10), "axis": (0, 0, 1), "radius": 3}

    @pytest.mark.skipif(True, reason="this test has never worked")
    def test_line(self):
        """Circle->Line collisions"""
        func = pycam.Geometry.intersection.intersect_circle_line
        func_args = [self._circle["center"], self._circle["axis"], self._circle["radius"],
                     self._circle["radius"] ** 2]
        # additional arguments: direction, edge
        """
        edge = Line((-1, -1, 4), (5, 5, 4))
        coll = func(*(func_args + [(0, 0, -1)] + [edge]))
        # The collision point seems to be the middle of the line.
        # This is technically not necessary, but the current algorithm does it this way.
        self.assert_collision_equal(((1.5, 1.5, 10), (1.5, 1.5, 4), 6), coll)
        """
        """
        # line dips into circle
        edge = Line((4, 1, 3), (10, 1, 5))
        coll = func(*(func_args + [(0, 0, -1)] + [edge]))
        #self.assert_collision_equal(((-1, 1, 10), (-1, 1, 2), 8), coll)
        self.assert_collision_equal(((5, 1, 10), (5, 1, 3.3333333333), 6.666666666), coll)
        # horizontally skewed line
        edge = Line((2, 1, 3), (8, 1, 5))
        coll = func(*(func_args + [(0, 0, -1)] + [edge]))
        #self.assert_collision_equal(((-1, 1, 10), (-1, 1, 2), 8), coll)
        self.assert_collision_equal(((5, 1, 10), (5, 1, 4), 6), coll)
        """
        # line touches circle
        edge = Line((10, 10, 4), (5, 1, 4))
        coll = func(*(func_args + [(0, 0, -1)] + [edge]))
        self.assert_collision_equal(((5, 1, 10), (5, 1, 4), 6), coll)
        # no collision
        edge = Line((10, 10, 4), (5.001, 1, 4))
        coll = func(*(func_args + [(0, 0, -1)] + [edge]))
        self.assert_collision_equal((None, None, INFINITE), coll)

    def test_plane(self):
        """Circle->Plane collisions"""
        func = pycam.Geometry.intersection.intersect_circle_plane
        func_args = [self._circle["center"], self._circle["radius"]]
        # additional arguments: direction, triangle
        triangle = Triangle((0, 5, 3), (5, 0, 3), (0, 0, 3))
        coll = func(*(func_args + [(0, 0, -1)] + [triangle]))
        self.assert_collision_equal(((2, 1, 10), (2, 1, 3), 7), coll)
        # slightly skewed
        triangle = Triangle((2, 5, 3), (2, 0, 3), (-4, 1, 6))
        coll = func(*(func_args + [(0, 0, -1)] + [triangle]))
        self.assert_collision_equal(((-1, 1, 10), (-1, 1, 4.5), 5.5), coll)
        # skewed and shifted
        triangle = Triangle((14, 5, -3), (14, 0, -3), (8, 1, 0))
        coll = func(*(func_args + [(0, 0, -1)] + [triangle]))
        self.assert_collision_equal(((-1, 1, 10), (-1, 1, 4.5), 5.5), coll)
        # vertical triangle
        triangle = Triangle((14, 5, -3), (14, 0, -3), (14, 1, -6))
        coll = func(*(func_args + [(0, 0, -1)] + [triangle]))
        self.assert_collision_equal((None, None, INFINITE), coll)

    @pytest.mark.skipif(True, reason="this test has never worked")
    def test_point(self):
        """Circle->Point collisions"""
        func = pycam.Geometry.intersection.intersect_circle_point
        func_args = [self._circle["center"],
                     self._circle["axis"],
                     self._circle["radius"],
                     self._circle["radius"] ** 2]
        # additional arguments: direction, point
        coll = func(*(func_args + [(0, 0, -1)] + [(0, 0, 0)]))
        self.assert_collision_equal(((0, 0, 10), (0, 0, 0), 10), coll)
        # the same, but upwards
        coll = func(*(func_args + [(0, 0, 1)] + [(0, 0, 0)]))
        self.assert_collision_equal(((0, 0, 10), (0, 0, 0), -10), coll)
        # barely touching the point
        coll = func(*(func_args + [(0, 0, -1)] + [(5, 1, 2)]))
        self.assert_collision_equal(((5, 1, 10), (5, 1, 2), 8), coll)
        # not touching the point
        coll = func(*(func_args + [(0, 0, -1)] + [(5.001, 1, 2)]))
        self.assert_collision_equal((None, None, INFINITE), coll)
        # point is already inside of the circle
        coll = func(*(func_args + [(0, 0, -1)] + [(2, 1, 10)]))
        self.assert_collision_equal(((2, 1, 10), (2, 1, 10), 0), coll)


if __name__ == "__main__":
    pycam.Test.main()
