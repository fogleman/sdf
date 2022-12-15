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

from pycam.Geometry import sqrt


# see BRL-CAD/src/libbn/poly.c
EPSILON = 1e-4
SMALL = 1e-4
INV_2 = 0.5
INV_3 = 1.0 / 3.0
INV_4 = 0.25
INV_27 = 1.0 / 27.0
SQRT3 = sqrt(3.0)
PI_DIV_3 = math.pi / 3.0


def near_zero(x, epsilon=EPSILON):
    return abs(x) < epsilon


def cuberoot(x):
    if x >= 0:
        return pow(x, INV_3)
    else:
        return -pow(-x, INV_3)


def poly1_roots(a, b):
    if near_zero(a):
        return None
    else:
        return (-b / a, )


def poly2_roots(a, b, c):
    d = b * b - 4 * a * c
    if d < 0:
        return None
    if near_zero(a):
        return poly1_roots(b, c)
    if d == 0:
        return (-b / (2 * a), )
    q = sqrt(d)
    if a < 0:
        return ((-b + q) / (2 * a), (-b - q) / (2 * a))
    else:
        return ((-b - q) / (2 * a), (-b + q) / (2 * a))


def poly3_roots(a, b, c, d):
    if near_zero(a):
        return poly2_roots(b, c, d)
    c1 = b / a
    c2 = c / a
    c3 = d / a

    c1_3 = c1 * INV_3
    a = c2 - c1 * c1_3
    b = (2 * c1 * c1 * c1 - 9 * c1 * c2 + 27 * c3) * INV_27
    delta = a * a
    delta = b * b * INV_4 + delta * a * INV_27
    if delta > 0:
        r_delta = sqrt(delta)
        v_major_p3 = -INV_2 * b + r_delta
        v_minor_p3 = -INV_2 * b - r_delta
        v_major = cuberoot(v_major_p3)
        v_minor = cuberoot(v_minor_p3)
        return (v_major + v_minor - c1_3, )
    elif delta == 0:
        b_2 = -b * INV_2
        s = cuberoot(b_2)
        return (2 * s - c1_3, -s - c1_3, -s - c1_3, )
    else:
        if a > 0:
            fact = 0
            phi = 0
            cs_phi = 1.0
            sn_phi_s3 = 0.0
        else:
            a *= -INV_3
            fact = sqrt(a)
            f = -b * INV_2 / (a * fact)
            if f >= 1.0:
                phi = 0
                cs_phi = 1.0
                sn_phi_s3 = 0.0
            elif f <= -1.0:
                phi = PI_DIV_3
                cs_phi = math.cos(phi)
                sn_phi_s3 = math.sin(phi) * SQRT3
            else:
                phi = math.acos(f) * INV_3
                cs_phi = math.cos(phi)
                sn_phi_s3 = math.sin(phi) * SQRT3
        r1 = 2 * fact * cs_phi
        r2 = fact * (sn_phi_s3 - cs_phi)
        r3 = fact * (-sn_phi_s3 - cs_phi)
        return (r1 - c1_3, r2 - c1_3, r3 - c1_3)


def poly4_roots(a, b, c, d, e):
    if a == 0:
        return poly3_roots(b, c, d, e)
    c1 = float(b) / a
    c2 = float(c) / a
    c3 = float(d) / a
    c4 = float(e) / a
    roots3 = poly3_roots(1.0, -c2, c3 * c1 - 4 * c4, -c3 * c3 - c4 * c1 * c1 + 4 * c4 * c2)
    if not roots3:
        return None
    if len(roots3) == 1:
        u = roots3[0]
    else:
        u = max(roots3[0], roots3[1], roots3[2])
    p = c1 * c1 * INV_4 + u - c2
    u *= INV_2
    q = u * u - c4
    if p < 0:
        if p < -SMALL:
            return None
        p = 0
    else:
        p = sqrt(p)
    if q < 0:
        if q < -SMALL:
            return None
        q = 0
    else:
        q = sqrt(q)

    quad1 = [1.0, c1 * INV_2 - p, 0]
    quad2 = [1.0, c1 * INV_2 + p, 0]

    q1 = u - q
    q2 = u + q
    p = quad1[1] * q2 + quad2[1] * q1 - c3
    if near_zero(p):
        quad1[2] = q1
        quad2[2] = q2
    else:
        q = quad1[1] * q1 + quad2[1] * q2 - c3
        if near_zero(q):
            quad1[2] = q2
            quad2[2] = q1
        else:
            return None
    roots1 = poly2_roots(quad1[0], quad1[1], quad1[2])
    roots2 = poly2_roots(quad2[0], quad2[1], quad2[2])
    if roots1 and roots2:
        return roots1 + roots2
    elif roots1:
        return roots1
    elif roots2:
        return roots2
    else:
        return None


def test_poly1(a, b):
    roots = poly1_roots(a, b)
    print(a, "*x+", b, "=0 ", roots)
    if roots:
        for r in roots:
            f = a * r + b
            if not near_zero(f):
                print("ERROR:"),
            print("    f(%f)=%f" % (r, f))


def test_poly2(a, b, c):
    roots = poly2_roots(a, b, c)
    print(a, "*x^2+", b, "*x+", c, "=0 ", roots)
    if roots:
        for r in roots:
            f = a * r * r + b * r + c
            if not near_zero(f):
                print("ERROR:"),
            print("    f(%f)=%f" % (r, f))


def test_poly3(a, b, c, d):
    roots = poly3_roots(a, b, c, d)
    print(a, "*x^3+", b, "*x^2+", c, "*x+", d, "=0 ", roots)
    if roots:
        for r in roots:
            f = a * r * r * r + b * r * r + c * r + d
            if not near_zero(f):
                print("ERROR:"),
            print("    f(%f)=%f" % (r, f))


def test_poly4(a, b, c, d, e):
    roots = poly4_roots(a, b, c, d, e)
    print("f(x)=%g*x**4%+g*x**3%+g*x**2%+g*x%+g" % (a, b, c, d, e))
    print("roots:", roots)
    if roots:
        for r in roots:
            f = a * r * r * r * r + b * r * r * r + c * r * r + d * r + e
            if not near_zero(f, epsilon=SMALL):
                print("ERROR:"),
            print("    f(%f)=%f" % (r, f))
    return roots


if __name__ == "__main__":
    test_poly1(1, 2)

    test_poly2(1, 2, 0)
    test_poly2(1, 2, 1)
    test_poly2(1, 2, 2)

    test_poly3(1, 0, 0, 0)
    test_poly3(1, 0, 0, -1)
    test_poly3(1, -1, 0, 0)
    test_poly3(1, 0, -2, 0)
    test_poly3(1, 0, -2, 1)

    test_poly4(1, 0, 0, 0, 0)
    test_poly4(1, 0, 0, 0, -1)
    test_poly4(1, 0, -2, 0, 1)
    test_poly4(1, -10, 35, -50, +24)
    test_poly4(1, 0, 6, -60, 36)
    test_poly4(1, -25, 235.895, -995.565, 1585.25)
