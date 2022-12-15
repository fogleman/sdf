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

import math

import pycam.Test
from pycam.Geometry.Triangle import Triangle
from pycam.Cutters.CylindricalCutter import CylindricalCutter
from pycam.Cutters.SphericalCutter import SphericalCutter


class CylindricalCutterCollisions(pycam.Test.PycamTestCase):
    """Cylindrical cutter collisions"""

    def _drop(self, radius, triangle):
        return CylindricalCutter(radius, location=(0, 0, 0)).drop(triangle)

    def test_drop(self):
        "Drop"
        # flat triangle
        flat_triangle = Triangle((-2, 2, 3), (2, 0, 3), (-2, -2, 3))
        self.assert_vector_equal(self._drop(3, flat_triangle), (0, 0, 3))
        # skewed triangle
        skewed_triangle = Triangle((-2, 2, 1), (2, 0, 3), (-2, -2, 1))
        self.assert_vector_equal(self._drop(1, skewed_triangle), (0, 0, 2.5))
        self.assert_vector_equal(self._drop(1.5, skewed_triangle), (0, 0, 2.75))
        self.assert_vector_equal(self._drop(1.9, skewed_triangle), (0, 0, 2.95))
#       self.assert_vector_equal(self._drop(2.0, skewed_triangle), (0, 0, 3))
#       self.assert_vector_equal(self._drop(2.1, skewed_triangle), (0, 0, 3))
#       self.assert_vector_equal(self._drop(3, skewed_triangle), (0, 0, 3))


class SphericalCutterCollisions(pycam.Test.PycamTestCase):
    """Spherical cutter collisions"""

    def _drop(self, radius, triangle):
        return SphericalCutter(radius, location=(0, 0, 0)).drop(triangle)

    def test_drop(self):
        "Drop"
        # flat triangle
        flat_triangle = Triangle((-2, 2, 3), (2, 0, 3), (-2, -2, 3))
        self.assert_vector_equal(self._drop(3, flat_triangle), (0, 0, 3))
        """
        Vertical shifting based on angle of skewed triangle:
            radius * (1/math.cos(math.pi/4) - 1)
            30 degree -> radius * 0.15470053837925146
            45 degree -> radius * 0.4142135623730949
            60 degree -> radius * 1.0
        """
        # skewed triangle
        factors = {30: (1.0 / math.cos(math.pi / 6) - 1),
                   45: (1.0 / math.cos(math.pi / 4) - 1),
                   60: (1.0 / math.cos(math.pi / 3) - 1)}
        triangles = {}
        triangles[30] = Triangle((-2, 2, 2), (2, 0, 4), (-2, -2, 2))
        triangles[45] = Triangle((-2, 2, 1), (2, 0, 5), (-2, -2, 1))
        triangles[60] = Triangle((-2, 2, -1), (2, 0, 7), (-2, -2, -1))

        def test_skew(radius, degree):
            return self.assert_vector_equal(self._drop(radius, triangles[degree]),
                                            (0, 0, 3 + factors[degree] * radius))
        test_skew(0.1, 45)
#       test_skew(0.1, 30)
#       test_skew(0.1, 60)
        test_skew(1, 45)
#       test_skew(1, 30)
#       test_skew(1, 60)
        test_skew(1.9, 45)
#       test_skew(1.9, 30)
#       test_skew(1.9, 60)
        test_skew(2.0, 45)
#       test_skew(2.0, 30)
#       test_skew(2.0, 60)
        test_skew(2.1, 45)
#       test_skew(2.1, 30)
#       test_skew(2.1, 60)
#       test_skew(3, 45)
#       test_skew(3, 30)
#       test_skew(3, 60)


if __name__ == "__main__":
    pycam.Test.main()
