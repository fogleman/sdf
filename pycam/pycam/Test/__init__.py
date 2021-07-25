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


import unittest


class PycamTestCase(unittest.TestCase):

    def _compare_vectors(self, v1, v2, max_deviance=0.000001):
        """ compare two vectors and return 'None' in case of success or an error message """
        # provide readable error messages
        result_difference = "%s != %s" % (v1, v2)
        result_equal = None
        if v1 == v2:
            return result_equal
        if v1 is None or v2 is None:
            return False
        for index in range(3):
            if max_deviance < abs(v1[index] - v2[index]):
                return result_difference
        return result_equal

    def assert_vector_equal(self, v1, v2, msg=None):
        self.assertIsNone(self._compare_vectors(v1, v2), msg=msg)

    def assert_vector_not_equal(self, v1, v2, msg=None):
        self.assertIsNotNone(self._compare_vectors(v1, v2), msg=msg)

    def assert_collision_equal(self, collision1, collision2, msg=None):
        ccp1, cp1, d1 = collision1
        ccp2, cp2, d2 = collision2
        self.assert_vector_equal(ccp1, ccp2, msg=("Collisions differ ({} != {}) due to ccp"
                                                  .format(collision1, collision2)))
        self.assert_vector_equal(cp1, cp2, msg=("Collisions differ ({} != {}) due to cp"
                                                .format(collision1, collision2)))
        self.assertAlmostEqual(d1, d2, msg=("Collisions differ ({} != {}) due to distance"
                                            .format(collision1, collision2)))


main = unittest.main
