"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>
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

from pycam.Geometry import epsilon, number, sqrt


def pnorm(a):
    return sqrt(pdot(a, a))


def pnormsq(a):
    return pdot(a, a)


def pdist(a, b, axes=None):
    return sqrt(pdist_sq(a, b, axes=axes))


def pdist_sq(a, b, axes=None):
    if axes is None:
        axes = (0, 1, 2)
    return sum([(a[index] - b[index]) ** 2 for index in axes])


def pnear(a, b, axes=None):
    return pcmp(a, b, axes=axes) == 0


def pcmp(a, b, axes=None):
    """ Two points are equal if all dimensions are identical.
    Otherwise the result is based on the individual x/y/z comparisons.
    """
    if axes is None:
        axes = (0, 1, 2)
    for axis in axes:
        if abs(a[axis] - b[axis]) > epsilon:
            return -1 if a[axis] < b[axis] else (0 if a[axis] == b[axis] else 1)
    # both points are at the same position
    return 0


def ptransform_by_matrix(a, matrix):
    if len(a) > 3:
        return (a[0] * matrix[0][0] + a[1] * matrix[0][1] + a[2] * matrix[0][2],
                a[0] * matrix[1][0] + a[1] * matrix[1][1] + a[2] * matrix[1][2],
                a[0] * matrix[2][0] + a[1] * matrix[2][1] + a[2] * matrix[2][2]) + a[3:]
    else:
        # accept 3x4 matrices as well as 3x3 matrices
        offsets = []
        for column in matrix:
            if len(column) < 4:
                offsets.append(0)
            else:
                offsets.append(column[3])
        return (a[0] * matrix[0][0] + a[1] * matrix[0][1] + a[2] * matrix[0][2] + offsets[0],
                a[0] * matrix[1][0] + a[1] * matrix[1][1] + a[2] * matrix[1][2] + offsets[1],
                a[0] * matrix[2][0] + a[1] * matrix[2][1] + a[2] * matrix[2][2] + offsets[2])


def pmul(a, c):
    c = number(c)
    return (a[0] * c, a[1] * c, a[2] * c)


def pdiv(a, c):
    c = number(c)
    return (a[0] / c, a[1] / c, a[2] / c)


def padd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def psub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def pdot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def pcross(a, b):
    return (a[1] * b[2] - b[1] * a[2], b[0] * a[2] - a[0] * b[2], a[0] * b[1] - b[0] * a[1])


def pnormalized(a):
    n = pnorm(a)
    if n == 0:
        return None
    else:
        return (a[0] / n, a[1] / n, a[2] / n) + a[3:]


def pis_inside(a, minx=None, maxx=None, miny=None, maxy=None, minz=None, maxz=None):
    return ((minx is None) or (minx - epsilon <= a[0])) \
            and ((maxx is None) or (a[0] <= maxx + epsilon)) \
            and ((miny is None) or (miny - epsilon <= a[1])) \
            and ((maxy is None) or (a[1] <= maxy + epsilon)) \
            and ((minz is None) or (minz - epsilon <= a[2])) \
            and ((maxz is None) or (a[2] <= maxz + epsilon))


def points_in_line(a, b, c):
    """ test if three points are in line """
    v1 = psub(a, b)
    v2 = psub(a, c)
    # The evaluation below is equivalent to the following test:
    #     pcross(v1, v2) == (0, 0, 0)
    # (but with efficient "early return" in case of failure)
    return ((v1[1] * v2[2] == v1[2] * v2[1])
            and (v1[0] * v2[2] == v1[2] * v2[0])
            and (v1[0] * v2[1] == v1[1] * v2[0]))
