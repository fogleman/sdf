"""
Copyright 2008-2010 Lode Leroy
Copyright 2010 Lars Kruse <devel@sumpfralle.de>

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

from pycam.Geometry import INFINITE, epsilon
from pycam.Cutters.BaseCutter import BaseCutter
from pycam.Geometry.intersection import intersect_sphere_plane, intersect_sphere_point, \
        intersect_sphere_line
from pycam.Geometry.PointUtils import padd, pdot, pmul, pnormsq, psub


try:
    import OpenGL.GL as GL
    import OpenGL.GLU as GLU
    GL_enabled = True
except ImportError:
    GL_enabled = False


class SphericalCutter(BaseCutter):

    def __init__(self, radius, **kwargs):
        BaseCutter.__init__(self, radius, **kwargs)
        self.axis = (0, 0, 1, 'v')

    def __repr__(self):
        return "SphericalCutter<%s,%s>" % (self.location, self.radius)

    def to_opengl(self):
        if not GL_enabled:
            return
        GL.glPushMatrix()
        GL.glTranslate(self.center[0], self.center[1], self.center[2])
        if not hasattr(self, "_sphere"):
            self._sphere = GLU.gluNewQuadric()
        GLU.gluSphere(self._sphere, self.radius, 10, 10)
        if not hasattr(self, "_cylinder"):
            self._cylinder = GLU.gluNewQuadric()
        GLU.gluCylinder(self._cylinder, self.radius, self.radius, self.height, 10, 10)
        GL.glPopMatrix()

    def moveto(self, location, **kwargs):
        BaseCutter.moveto(self, location, **kwargs)
        self.center = (location[0], location[1], location[2] + self.radius)

    def intersect_sphere_plane(self, direction, triangle, start=None):
        if start is None:
            start = self.location
        (ccp, cp, d) = intersect_sphere_plane(padd(psub(start, self.location), self.center),
                                              self.distance_radius, direction, triangle)
        # offset intersection
        if ccp:
            cl = padd(cp, psub(start, ccp))
            return (cl, ccp, cp, d)
        return (None, None, None, INFINITE)

    def intersect_sphere_triangle(self, direction, triangle, start=None):
        (cl, ccp, cp, d) = self.intersect_sphere_plane(direction, triangle, start=start)
        if cp and triangle.is_point_inside(cp):
            return (cl, d, cp)
        return (None, INFINITE, None)

    def intersect_sphere_point(self, direction, point, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_sphere_point(padd(psub(start, self.location), self.center),
                                              self.distance_radius, self.distance_radiussq,
                                              direction, point)
        # offset intersection
        cl = None
        if cp:
            cl = padd(start, pmul(direction, l))
        return (cl, ccp, cp, l)

    def intersect_sphere_vertex(self, direction, point, start=None):
        (cl, ccp, cp, l) = self.intersect_sphere_point(direction, point, start=start)
        return (cl, l, cp)

    def intersect_sphere_line(self, direction, edge, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_sphere_line(padd(psub(start, self.location), self.center),
                                             self.distance_radius, self.distance_radiussq,
                                             direction, edge)
        # offset intersection
        if ccp:
            cl = psub(cp, psub(ccp, start))
            return (cl, ccp, cp, l)
        return (None, None, None, INFINITE)

    def intersect_sphere_edge(self, direction, edge, start=None):
        (cl, ccp, cp, l) = self.intersect_sphere_line(direction, edge, start=start)
        if cp:
            # check if the contact point is between the endpoints
            d = psub(edge.p2, edge.p1)
            m = pdot(psub(cp, edge.p1), d)
            if (m < -epsilon) or (m > pnormsq(d) + epsilon):
                return (None, INFINITE, None)
        return (cl, l, cp)

    def intersect_point(self, direction, point, start=None):
        # TODO: probably obsolete?
        return self.intersect_sphere_point(direction, point, start=start)

    def intersect(self, direction, triangle, start=None):
        (cl_t, d_t, cp_t) = self.intersect_sphere_triangle(direction, triangle, start=start)
        d = INFINITE
        cl = None
        cp = None
        if d_t < d:
            d = d_t
            cl = cl_t
            cp = cp_t
        if cl and (direction[0] == 0) and (direction[1] == 0):
            return (cl, d, cp)
        (cl_e1, d_e1, cp_e1) = self.intersect_sphere_edge(direction, triangle.e1, start=start)
        (cl_e2, d_e2, cp_e2) = self.intersect_sphere_edge(direction, triangle.e2, start=start)
        (cl_e3, d_e3, cp_e3) = self.intersect_sphere_edge(direction, triangle.e3, start=start)
        if d_e1 < d:
            d = d_e1
            cl = cl_e1
            cp = cp_e1
        if d_e2 < d:
            d = d_e2
            cl = cl_e2
            cp = cp_e2
        if d_e3 < d:
            d = d_e3
            cl = cl_e3
            cp = cp_e3
        (cl_p1, d_p1, cp_p1) = self.intersect_sphere_vertex(direction, triangle.p1, start=start)
        (cl_p2, d_p2, cp_p2) = self.intersect_sphere_vertex(direction, triangle.p2, start=start)
        (cl_p3, d_p3, cp_p3) = self.intersect_sphere_vertex(direction, triangle.p3, start=start)
        if d_p1 < d:
            d = d_p1
            cl = cl_p1
            cp = cp_p1
        if d_p2 < d:
            d = d_p2
            cl = cl_p2
            cp = cp_p2
        if d_p3 < d:
            d = d_p3
            cl = cl_p3
            cp = cp_p3
        if cl and (direction[0] == 0) and (direction[1] == 0):
            return (cl, d, cp)
        if (direction[0] != 0) or (direction[1] != 0):
            (cl_p1, d_p1, cp_p1) = self.intersect_cylinder_vertex(direction, triangle.p1,
                                                                  start=start)
            (cl_p2, d_p2, cp_p2) = self.intersect_cylinder_vertex(direction, triangle.p2,
                                                                  start=start)
            (cl_p3, d_p3, cp_p3) = self.intersect_cylinder_vertex(direction, triangle.p3,
                                                                  start=start)
            if d_p1 < d:
                d = d_p1
                cl = cl_p1
                cp = cp_p1
            if d_p2 < d:
                d = d_p2
                cl = cl_p2
                cp = cp_p2
            if d_p3 < d:
                d = d_p3
                cl = cl_p3
                cp = cp_p3
            cl_e1, d_e1, cp_e1 = self.intersect_cylinder_edge(direction, triangle.e1, start=start)
            cl_e2, d_e2, cp_e2 = self.intersect_cylinder_edge(direction, triangle.e2, start=start)
            cl_e3, d_e3, cp_e3 = self.intersect_cylinder_edge(direction, triangle.e3, start=start)
            if d_e1 < d:
                d = d_e1
                cl = cl_e1
                cp = cp_e1
            if d_e2 < d:
                d = d_e2
                cl = cl_e2
                cp = cp_e2
            if d_e3 < d:
                d = d_e3
                cl = cl_e3
                cp = cp_e3
        return (cl, d, cp)
