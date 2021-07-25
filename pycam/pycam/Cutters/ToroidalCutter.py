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

from pycam.Geometry import INFINITE, number, epsilon
from pycam.Cutters.BaseCutter import BaseCutter
from pycam.Geometry.intersection import intersect_torus_plane, intersect_torus_point, \
        intersect_circle_plane, intersect_circle_point, intersect_cylinder_point, \
        intersect_cylinder_line, intersect_circle_line
from pycam.Geometry.PointUtils import padd, pdot, pmul, psub


try:
    import OpenGL.GL as GL
    import OpenGL.GLU as GLU
    import OpenGL.GLUT as GLUT
    GL_enabled = True
except ImportError:
    GL_enabled = False


class ToroidalCutter(BaseCutter):

    def __init__(self, radius, minorradius, **kwargs):
        minorradius = number(minorradius)
        self.minorradius = minorradius
        # we need "minorradius" for "moveto" - thus set it before parent's init
        BaseCutter.__init__(self, radius, **kwargs)
        self.majorradius = self.radius - minorradius
        self.axis = (0, 0, 1)
        self.majorradiussq = self.majorradius ** 2
        self.minorradiussq = self.minorradius ** 2
        self.distance_majorradius = self.majorradius + self.get_required_distance()
        self.distance_minorradius = self.minorradius + self.get_required_distance()
        self.distance_majorradiussq = self.distance_majorradius ** 2
        self.distance_minorradiussq = self.distance_minorradius ** 2

    def set_required_distance(self, value):
        """ trigger the update of "self.distance_major/minorradius" """
        BaseCutter.set_required_distance(self, value)
        if value >= 0:
            self.distance_majorradius = self.majorradius + self.get_required_distance()
            self.distance_minorradius = self.minorradius + self.get_required_distance()
            self.distance_majorradiussq = self.distance_majorradius ** 2
            self.distance_minorradiussq = self.distance_minorradius ** 2

    def __repr__(self):
        return "ToroidalCutter<%s,%f,R=%f,r=%f>" % (self.location, self.radius, self.majorradius,
                                                    self.minorradius)

    def __lt__(self, other):
        """ Compare Cutters by shape and size (ignoring the location) """
        return ((self.radius, self.majorradius, self.minorradius)
                < (other.radius, other.majorradius, other.minorradius))

    def to_opengl(self):
        if not GL_enabled:
            return
        GL.glPushMatrix()
        GL.glTranslate(self.center[0], self.center[1], self.center[2])
        GLUT.glutSolidTorus(self.minorradius, self.majorradius, 10, 20)
        if not hasattr(self, "_cylinder"):
            self._cylinder = GLU.gluNewQuadric()
        GLU.gluCylinder(self._cylinder, self.radius, self.radius, self.height, 10, 20)
        GL.glPopMatrix()
        GL.glPushMatrix()
        GL.glTranslate(self.location[0], self.location[1], self.location[2])
        if not hasattr(self, "_disk"):
            self._disk = GLU.gluNewQuadric()
        GLU.gluDisk(self._disk, 0, self.majorradius, 20, 10)
        GL.glPopMatrix()

    def moveto(self, location, **kwargs):
        BaseCutter.moveto(self, location, **kwargs)
        self.center = (location[0], location[1], location[2]+self.minorradius)

    def intersect_torus_plane(self, direction, triangle, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_torus_plane(padd(psub(start, self.location), self.center),
                                             self.axis, self.distance_majorradius,
                                             self.distance_minorradius, direction, triangle)
        if cp:
            cl = padd(cp, psub(start, ccp))
            return (cl, ccp, cp, l)
        return (None, None, None, INFINITE)

    def intersect_torus_triangle(self, direction, triangle, start=None):
        (cl, ccp, cp, d) = self.intersect_torus_plane(direction, triangle, start=start)
        if cp and triangle.is_point_inside(cp):
            return (cl, d, cp)
        return (None, INFINITE, None)

    def intersect_torus_point(self, direction, point, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_torus_point(padd(psub(start, self.location), self.center),
                                             self.axis,
                                             self.distance_majorradius,
                                             self.distance_minorradius,
                                             self.distance_majorradiussq,
                                             self.distance_minorradiussq,
                                             direction,
                                             point)
        if ccp:
            cl = padd(point, psub(start, ccp))
            return (cl, ccp, point, l)
        return (None, None, None, INFINITE)

    def intersect_torus_vertex(self, direction, point, start=None):
        (cl, ccp, cp, l) = self.intersect_torus_point(direction, point, start=start)
        return (cl, l, cp)

    def intersect_torus_edge(self, direction, edge, start=None):
        # TODO: calculate "optimal" scale:
        #  max(dir.dot(axis)/minor,dir.dot(dir.cross(axis).normalized())/major)
        # "When in doubt, use brute force." Ken Thompson
        min_m = 0
        min_l = INFINITE
        min_cl = None
        scale = int(edge.len / self.distance_minorradius * 2)
        scale = max(3, scale)
        for i in range(scale + 1):
            m = float(i) / scale
            p = edge.point_with_length_multiply(m)
            (cl, ccp, cp, l) = self.intersect_torus_point(direction, p, start=start)
            if not cl:
                continue
            if l < min_l:
                min_m = m
                min_l = l
                min_cl = cl
                min_cp = cp
        if min_l == INFINITE:
            return (None, INFINITE, None)
        scale2 = 10
        for i in range(1, scale2 + 1):
            m = min_m + ((float(i) / (scale2)) * 2 - 1)/scale
            if (m < -epsilon) or (m > 1 + epsilon):
                continue
            p = edge.point_with_length_multiply(m)
            (cl, ccp, cp, l) = self.intersect_torus_point(direction, p, start=start)
            if not cl:
                continue
            if l < min_l:
                min_l = l
                min_cl = cl
                min_cp = cp
        return (min_cl, min_l, min_cp)

    def intersect_cylinder_point(self, direction, point, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_cylinder_point(padd(psub(start, self.location), self.center),
                                                self.axis, self.distance_radius,
                                                self.distance_radiussq, direction, point)
        # offset intersection
        if ccp:
            cl = padd(start, pmul(direction, l))
            return (cl, ccp, cp, l)
        return (None, None, None, INFINITE)

    def intersect_cylinder_line(self, direction, edge, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_cylinder_line(padd(psub(start, self.location), self.center),
                                               self.axis, self.distance_radius,
                                               self.distance_radiussq, direction, edge)
        # offset intersection
        if ccp:
            cl = padd(start, psub(cp, ccp))
            return (cl, ccp, cp, l)
        return (None, None, None, INFINITE)

    def intersect_cylinder_edge(self, direction, edge, start=None):
        (cl, ccp, cp, l) = self.intersect_cylinder_line(direction, edge, start=start)
        if ccp and ccp[2] < self.center[2]:
            return (None, INFINITE, None)
        if ccp:
            m = pdot(psub(cp, edge.p1), edge.dir)
            if (m < -epsilon) or (m > edge.len + epsilon):
                return (None, INFINITE, None)
        return (cl, l, cp)

    def intersect_circle_plane(self, direction, triangle, start=None):
        if start is None:
            start = self.location
        ccp, cp, l_len = intersect_circle_plane(start, self.distance_majorradius, direction,
                                                triangle)
        # offset intersection
        if ccp:
            cl = psub(cp, psub(ccp, start))
            return (cl, ccp, cp, l_len)
        return (None, None, None, INFINITE)

    def intersect_circle_point(self, direction, point, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l_len) = intersect_circle_point(start, self.axis, self.distance_majorradius,
                                                  self.distance_majorradiussq, direction, point)
        if ccp:
            cl = psub(cp, psub(ccp, start))
            return (cl, ccp, point, l_len)
        return (None, None, None, INFINITE)

    def intersect_circle_line(self, direction, edge, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l_len) = intersect_circle_line(start, self.axis, self.distance_majorradius,
                                                 self.distance_majorradiussq, direction, edge)
        if ccp:
            cl = psub(cp, psub(ccp, start))
            return (cl, ccp, cp, l_len)
        return (None, None, None, INFINITE)

    def intersect(self, direction, triangle, start=None):
        (cl_t, d_t, cp_t) = self.intersect_torus_triangle(direction, triangle, start=start)
        d = INFINITE
        cl = None
        cp = None
        if d_t < d:
            d = d_t
            cl = cl_t
            cp = cp_t
        (cl_e1, d_e1, cp_e1) = self.intersect_torus_edge(direction, triangle.e1, start=start)
        (cl_e2, d_e2, cp_e2) = self.intersect_torus_edge(direction, triangle.e2, start=start)
        (cl_e3, d_e3, cp_e3) = self.intersect_torus_edge(direction, triangle.e3, start=start)
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
        (cl_p1, d_p1, cp_p1) = self.intersect_torus_vertex(direction, triangle.p1, start=start)
        (cl_p2, d_p2, cp_p2) = self.intersect_torus_vertex(direction, triangle.p2, start=start)
        (cl_p3, d_p3, cp_p3) = self.intersect_torus_vertex(direction, triangle.p3, start=start)
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
        (cl_t, d_t, cp_t) = self.intersect_circle_triangle(direction, triangle, start=start)
        if d_t < d:
            d = d_t
            cl = cl_t
            cp = cp_t
        (cl_p1, d_p1, cp_p1) = self.intersect_circle_vertex(direction, triangle.p1, start=start)
        (cl_p2, d_p2, cp_p2) = self.intersect_circle_vertex(direction, triangle.p2, start=start)
        (cl_p3, d_p3, cp_p3) = self.intersect_circle_vertex(direction, triangle.p3, start=start)
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
        (cl_e1, d_e1, cp_e1) = self.intersect_circle_edge(direction, triangle.e1, start=start)
        (cl_e2, d_e2, cp_e2) = self.intersect_circle_edge(direction, triangle.e2, start=start)
        (cl_e3, d_e3, cp_e3) = self.intersect_circle_edge(direction, triangle.e3, start=start)
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
        if direction[0] != 0 or direction[1] != 0:
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
