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

import pycam.Geometry.PointUtils as pu
import pycam.Test


ROOT_2 = math.sqrt(2)
ROOT_3 = math.sqrt(3)


"""
TODO: the following tests are missing for the PointUtils module:
    ptransform_by_matrix
    pmul
    pdiv
    padd
    psub
    pdot
    pcross
    pis_inside
    ptransform_by_matrix
"""


class UnaryOperations(pycam.Test.PycamTestCase):

    def test_pnorm(self):
        def norm_test(vector, result):
            self.assertAlmostEqual(pu.pnorm(vector), result)
            self.assertAlmostEqual(pu.pnormsq(vector), result**2)
        norm_test((1.0, 0.0, 0.0), 1)
        norm_test((1, 0, 0), 1)
        norm_test((0, 1, 0), 1)
        norm_test((0, 0, 1), 1)
        norm_test((1, 0, 0), 1)
        norm_test((0, -1, 0), 1)
        norm_test((0, 0, -1), 1)
        norm_test((0, 0, 0), 0)
        norm_test((0, 7, 0), 7)
        norm_test((1, 2, -3), math.sqrt(14))
        norm_test((1, 1, -1), ROOT_3)
        norm_test((1, -1, 0), ROOT_2)

    def test_normalized(self):
        norm_test = lambda vector, result: \
                self.assert_vector_equal(pu.pnormalized(vector), result)
        norm_test((1.0, 0.0, 0.0), (1, 0, 0))
        norm_test((1, 0, 0), (1, 0, 0))
        norm_test((0, 1, 0), (0, 1, 0))
        norm_test((0, 0, 1), (0, 0, 1))
        norm_test((-1, 0, 0), (-1, 0, 0))
        norm_test((0, -1, 0), (0, -1, 0))
        norm_test((0, 0, -1), (0, 0, -1))
        norm_test((0, -7, 0), (0, -1, 0))
        norm_test((1, -1, 0), (1/ROOT_2, -1/ROOT_2, 0))
        norm_test((1, 1, -1), (1/ROOT_3, 1/ROOT_3, -1/ROOT_3))
        norm_test((3, -4, 2), (0.55708601453, -0.7427813527, 0.37139067635))
        # normalized zero-length vector returns None
        self.assertIsNone(pu.pnormalized((0, 0, 0)))


class BinaryOperations(pycam.Test.PycamTestCase):

    def test_dist(self):
        def dist_test(a, b, result, axes=None):
            self.assertAlmostEqual(pu.pdist(a, b, axes=axes), result)
            self.assertAlmostEqual(pu.pdist_sq(a, b, axes=axes), result**2)
        dist_test((1, 0, 0), (0, 0, 0), 1)
        dist_test((0, 2, 0), (0, 0, 0), 2)
        dist_test((0, 0, -3), (0, 0, 1), 4)
        dist_test((7, 1, -3), (-2, 1, 0), 9, axes=(0, ))
        dist_test((7, 1, -3), (-2, 1, 0), 0, axes=(1, ))
        dist_test((7, 1, -3), (-2, 1, 0), 3, axes=(2, ))
        dist_test((7, 1, -3), (-2, 1, 0), math.sqrt(9**2 + 3**2))
        dist_test((7, 1, -3), (-2, 1, 0), 9, axes=(0, 1))
        dist_test((7, 1, -3), (-2, 1, 0), math.sqrt(9**2 + 3**2), axes=(0, 2))
        dist_test((7, 1, -3), (-2, 1, 0), 3, axes=(1, 2))
        dist_test((7, 1, -3), (-2, 1, 0), math.sqrt(9**2 + 3**2), axes=(0, 1, 2))
        dist_test((0, 0, 0), (0, 0, 0), 0)
        dist_test((-7.2, 1.3, 32), (-7.2, 1.3, 32), 0)
        dist_test((-7.2, 1.3, 32), (-7.2, 1.1, 32), 0.2)

    def test_near(self):
        is_near = lambda a, b, axes=None: self.assertTrue(pu.pnear(a, b, axes=axes))
        is_far = lambda a, b, axes=None: self.assertFalse(pu.pnear(a, b, axes=axes))
        is_near((0, 0, 1), (0, 0, 1.0))
        is_near((4.0, -2.0, 1), (4, -2, 1.0))
        is_far((12, 3, -3), (12, 3, 3))
        is_far((4, -2, 1), (4, -2, -1.0001))
        is_near((4, -2, 1), (4, -2, -1.0001), axes=(0, 1))
        is_far((4, -2, 1), (4, -2, -1.0001), axes=(1, 2))
        is_far((4, -2, 1), (4, -2, -1.0001), axes=(2, ))

    def test_cmp(self):
        is_greater = lambda a, b, axes=None: self.assertEqual(pu.pcmp(a, b, axes=axes), 1)
        is_equal = lambda a, b, axes=None: self.assertEqual(pu.pcmp(a, b, axes=axes), 0)
        is_less = lambda a, b, axes=None: self.assertEqual(pu.pcmp(a, b, axes=axes), -1)
        is_equal((0, 0, 1), (0, 0, 1.0))
        is_greater((4.001, -2.0, 1), (4, -2, 1.0))
        is_greater((4, -2, 1), (4, -3, 1))
        is_greater((4, -2, 1), (4, -2, -1))
        is_less((4, -2, -1.1), (4, -2, -1))


if __name__ == "__main__":
    pycam.Test.main()
