"""
Copyright 2008-2010 Lode Leroy

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


from pycam.Geometry import INFINITE, sqrt, epsilon
from pycam.Geometry.Plane import Plane
from pycam.Geometry.Line import Line
from pycam.Geometry.PointUtils import padd, pcross, pdiv, pdot, pmul, pnorm, pnormalized, \
        pnormsq, psub
from pycam.Utils.polynomials import poly4_roots


def intersect_cylinder_point(center, axis, radius, radiussq, direction, point):
    # take a plane along direction and axis
    n = pnormalized(pcross(direction, axis))
    # distance of the point to this plane
    d = pdot(n, point) - pdot(n, center)
    if abs(d) > radius - epsilon:
        return (None, None, INFINITE)
    # ccl is on cylinder
    d2 = sqrt(radiussq - d * d)
    ccl = padd(padd(center, pmul(n, d)), pmul(direction, d2))
    # take plane through ccl and axis
    plane = Plane(ccl, direction)
    # intersect point with plane
    (ccp, l) = plane.intersect_point(direction, point)
    return (ccp, point, -l)


def intersect_cylinder_line(center, axis, radius, radiussq, direction, edge):
    d = edge.dir
    # take a plane through the line and along the cylinder axis (1)
    n = pcross(d, axis)
    if pnorm(n) == 0:
        # no contact point, but should check here if cylinder *always*
        # intersects line...
        return (None, None, INFINITE)
    n = pnormalized(n)
    # the contact line between the cylinder and this plane (1)
    # is where the surface normal is perpendicular to the plane
    # so line := ccl + \lambda * axis
    if pdot(n, direction) < 0:
        ccl = psub(center, pmul(n, radius))
    else:
        ccl = padd(center, pmul(n, radius))
    # now extrude the contact line along the direction, this is a plane (2)
    n2 = pcross(direction, axis)
    if pnorm(n2) == 0:
        # no contact point, but should check here if cylinder *always*
        # intersects line...
        return (None, None, INFINITE)
    n2 = pnormalized(n2)
    plane1 = Plane(ccl, n2)
    # intersect this plane with the line, this gives us the contact point
    (cp, l) = plane1.intersect_point(d, edge.p1)
    if not cp:
        return (None, None, INFINITE)
    # now take a plane through the contact line and perpendicular to the
    # direction (3)
    plane2 = Plane(ccl, direction)
    # the intersection of this plane (3) with the line through the contact point
    # gives us the cutter contact point
    (ccp, l) = plane2.intersect_point(direction, cp)
    cp = padd(ccp, pmul(direction, -l))
    return (ccp, cp, -l)


def intersect_circle_plane(center, radius, direction, triangle):
    # let n be the normal to the plane
    n = triangle.normal
    if pdot(n, direction) == 0:
        return (None, None, INFINITE)
    # project onto z=0
    n2 = (n[0], n[1], 0)
    if pnorm(n2) == 0:
        (cp, d) = triangle.plane.intersect_point(direction, center)
        ccp = psub(cp, pmul(direction, d))
        return (ccp, cp, d)
    n2 = pnormalized(n2)
    # the cutter contact point is on the circle, where the surface normal is n
    ccp = padd(center, pmul(n2, -radius))
    # intersect the plane with a line through the contact point
    (cp, d) = triangle.plane.intersect_point(direction, ccp)
    return (ccp, cp, d)


def intersect_circle_point(center, axis, radius, radiussq, direction, point):
    # take a plane through the base
    plane = Plane(center, axis)
    # intersect with line gives ccp
    (ccp, l) = plane.intersect_point(direction, point)
    # check if inside circle
    if ccp and (pnormsq(psub(center, ccp)) < radiussq - epsilon):
        return (ccp, point, -l)
    return (None, None, INFINITE)


def intersect_circle_line(center, axis, radius, radiussq, direction, edge):
    # make a plane by sliding the line along the direction (1)
    d = edge.dir
    if pdot(d, axis) == 0:
        if pdot(direction, axis) == 0:
            return (None, None, INFINITE)
        plane = Plane(center, axis)
        (p1, l) = plane.intersect_point(direction, edge.p1)
        (p2, l) = plane.intersect_point(direction, edge.p2)
        pc = Line(p1, p2).closest_point(center)
        d_sq = pnormsq(psub(pc, center))
        if d_sq >= radiussq:
            return (None, None, INFINITE)
        a = sqrt(radiussq - d_sq)
        d1 = pdot(psub(p1, pc), d)
        d2 = pdot(psub(p2, pc), d)
        ccp = None
        cp = None
        if abs(d1) < a - epsilon:
            ccp = p1
            cp = psub(p1, pmul(direction, l))
        elif abs(d2) < a - epsilon:
            ccp = p2
            cp = psub(p2, pmul(direction, l))
        elif ((d1 < -a + epsilon) and (d2 > a - epsilon)) \
                or ((d2 < -a + epsilon) and (d1 > a - epsilon)):
            ccp = pc
            cp = psub(pc, pmul(direction, l))
        return (ccp, cp, -l)
    n = pcross(d, direction)
    if pnorm(n) == 0:
        # no contact point, but should check here if circle *always* intersects
        # line...
        return (None, None, INFINITE)
    n = pnormalized(n)
    # take a plane through the base
    plane = Plane(center, axis)
    # intersect base with line
    (lp, l) = plane.intersect_point(d, edge.p1)
    if not lp:
        return (None, None, INFINITE)
    # intersection of 2 planes: lp + \lambda v
    v = pcross(axis, n)
    if pnorm(v) == 0:
        return (None, None, INFINITE)
    v = pnormalized(v)
    # take plane through intersection line and parallel to axis
    n2 = pcross(v, axis)
    if pnorm(n2) == 0:
        return (None, None, INFINITE)
    n2 = pnormalized(n2)
    # distance from center to this plane
    dist = pdot(n2, center) - pdot(n2, lp)
    distsq = dist * dist
    if distsq > radiussq - epsilon:
        return (None, None, INFINITE)
    # must be on circle
    dist2 = sqrt(radiussq - distsq)
    if pdot(d, axis) < 0:
        dist2 = -dist2
    ccp = psub(center, psub(pmul(n2, dist), pmul(v, dist2)))
    plane = Plane(edge.p1, pcross(pcross(d, direction), d))
    (cp, l) = plane.intersect_point(direction, ccp)
    return (ccp, cp, l)


def intersect_sphere_plane(center, radius, direction, triangle):
    # let n be the normal to the plane
    n = triangle.normal
    if pdot(n, direction) == 0:
        return (None, None, INFINITE)
    # the cutter contact point is on the sphere, where the surface normal is n
    if pdot(n, direction) < 0:
        ccp = psub(center, pmul(n, radius))
    else:
        ccp = padd(center, pmul(n, radius))
    # intersect the plane with a line through the contact point
    (cp, d) = triangle.plane.intersect_point(direction, ccp)
    return (ccp, cp, d)


def intersect_sphere_point(center, radius, radiussq, direction, point):
    # line equation
    # (1) x = p_0 + \lambda * d
    # sphere equation
    # (2) (x-x_0)^2 = R^2
    # (1) in (2) gives a quadratic in \lambda
    p0_x0 = psub(center, point)
    a = pnormsq(direction)
    b = 2 * pdot(p0_x0, direction)
    c = pnormsq(p0_x0) - radiussq
    d = b * b - 4 * a * c
    if d < 0:
        return (None, None, INFINITE)
    if a < 0:
        dist = (-b + sqrt(d)) / (2 * a)
    else:
        dist = (-b - sqrt(d)) / (2 * a)
    # cutter contact point
    ccp = padd(point, pmul(direction, -dist))
    return (ccp, point, dist)


def intersect_sphere_line(center, radius, radiussq, direction, edge):
    # make a plane by sliding the line along the direction (1)
    d = edge.dir
    n = pcross(d, direction)
    if pnorm(n) == 0:
        # no contact point, but should check here if sphere *always* intersects
        # line...
        return (None, None, INFINITE)
    n = pnormalized(n)

    # calculate the distance from the sphere center to the plane
    dist = - pdot(center, n) + pdot(edge.p1, n)
    if abs(dist) > radius - epsilon:
        return (None, None, INFINITE)
    # this gives us the intersection circle on the sphere

    # now take a plane through the edge and perpendicular to the direction (2)
    # find the center on the circle closest to this plane

    # which means the other component is perpendicular to this plane (2)
    n2 = pnormalized(pcross(n, d))

    # the contact point is on a big circle through the sphere...
    dist2 = sqrt(radiussq - dist * dist)

    # ... and it's on the plane (1)
    ccp = padd(center, padd(pmul(n, dist), pmul(n2, dist2)))

    # now intersect a line through this point with the plane (2)
    plane = Plane(edge.p1, n2)
    (cp, l) = plane.intersect_point(direction, ccp)
    return (ccp, cp, l)


def intersect_torus_plane(center, axis, majorradius, minorradius, direction, triangle):
    # take normal to the plane
    n = triangle.normal
    if pdot(n, direction) == 0:
        return (None, None, INFINITE)
    if pdot(n, axis) == 1:
        return (None, None, INFINITE)
    # find place on torus where surface normal is n
    b = pmul(n, -1)
    z = axis
    a = psub(b, pmul(z, pdot(z, b)))
    a_sq = pnormsq(a)
    if a_sq <= 0:
        return (None, None, INFINITE)
    a = pdiv(a, sqrt(a_sq))
    ccp = padd(padd(center, pmul(a, majorradius)), pmul(b, minorradius))
    # find intersection with plane
    (cp, l) = triangle.plane.intersect_point(direction, ccp)
    return (ccp, cp, l)


def intersect_torus_point(center, axis, majorradius, minorradius, majorradiussq, minorradiussq,
                          direction, point):
    dist = 0
    if (direction[0] == 0) and (direction[1] == 0):
        # drop
        minlsq = (majorradius - minorradius) ** 2
        maxlsq = (majorradius + minorradius) ** 2
        l_sq = (point[0]-center[0]) ** 2 + (point[1] - center[1]) ** 2
        if (l_sq < minlsq + epsilon) or (l_sq > maxlsq - epsilon):
            return (None, None, INFINITE)
        l_len = sqrt(l_sq)
        z_sq = minorradiussq - (majorradius - l_len) ** 2
        if z_sq < 0:
            return (None, None, INFINITE)
        z = sqrt(z_sq)
        ccp = (point[0], point[1], center[2] - z)
        dist = ccp[2] - point[2]
    elif direction[2] == 0:
        # push
        z = point[2] - center[2]
        if abs(z) > minorradius - epsilon:
            return (None, None, INFINITE)
        l_len = majorradius + sqrt(minorradiussq - z * z)
        n = pcross(axis, direction)
        d = pdot(n, point) - pdot(n, center)
        if abs(d) > l_len - epsilon:
            return (None, None, INFINITE)
        a = sqrt(l_len * l_len - d * d)
        ccp = padd(padd(center, pmul(n, d)), pmul(direction, a))
        ccp = (ccp[0], ccp[1], point[2])
        dist = pdot(psub(point, ccp), direction)
    else:
        # general case
        x = psub(point, center)
        v = pmul(direction, -1)
        x_x = pdot(x, x)
        x_v = pdot(x, v)
        x1 = (x[0], x[1], 0)
        v1 = (v[0], v[1], 0)
        x1_x1 = pdot(x1, x1)
        x1_v1 = pdot(x1, v1)
        v1_v1 = pdot(v1, v1)
        r2_major = majorradiussq
        r2_minor = minorradiussq
        a = 1.0
        b = 4 * x_v
        c = 2 * (x_x + 2 * x_v ** 2 + (r2_major - r2_minor) - 2 * r2_major * v1_v1)
        d = 4 * (x_x * x_v + x_v * (r2_major - r2_minor) - 2 * r2_major * x1_v1)
        e = ((x_x) ** 2 + 2 * x_x * (r2_major - r2_minor) + (r2_major - r2_minor) ** 2
             - 4 * r2_major * x1_x1)
        r = poly4_roots(a, b, c, d, e)
        if not r:
            return (None, None, INFINITE)
        else:
            l_len = min(r)
        ccp = padd(point, pmul(direction, -l_len))
        dist = l_len
    return (ccp, point, dist)
