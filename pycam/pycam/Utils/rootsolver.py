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


def find_root_subdivide(f, x0, x1, tolerance, scale):
    ymin = 0
    xmin = 0
    while x1 - x0 > tolerance:
        for i in range(scale):
            x = x1 + (i / scale) * (x1 - x0)
            y = f(x)
            abs_y = abs(y)
            if i == 0:
                ymin = abs_y
                xmin = x
            else:
                if abs_y < ymin:
                    ymin = abs_y
                    xmin = x
        x0 = xmin - 1 / scale
        x1 = xmin + 1 / scale
        scale /= 10
    return xmin


def find_root_newton_raphson(f, df, x0, tolerance, maxiter):
    x = x0
    iter_count = 0
    while iter_count < maxiter:
        y = f(x)
        if y == 0:
            return x
        dy = df(x)
        if dy == 0:
            return None
        dx = y / dy
        x = x - dx
        if dx < tolerance:
            break
        iter_count += 1
    return x


def find_root(f, df=None, x0=0, x1=1, tolerance=0.001):
    return find_root_subdivide(f=f, x0=x0, x1=x1, tolerance=tolerance, scale=10.0)
