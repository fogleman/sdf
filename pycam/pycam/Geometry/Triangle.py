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

from pycam.Geometry.PointUtils import padd, pcross, pdist, pdist_sq, pdiv, pdot, pmul, pnorm, \
        pnormalized, psub
from pycam.Geometry.Plane import Plane
from pycam.Geometry.Line import Line
from pycam.Geometry import TransformableContainer, IDGenerator
import pycam.Utils.log


try:
    import OpenGL.GL as GL
    import OpenGL.GLU as GLU
    import OpenGL.GLUT as GLUT
    from OpenGL.GLUT.fonts import GLUT_STROKE_ROMAN
    GL_enabled = True
except ImportError:
    GL_enabled = False


class Triangle(IDGenerator, TransformableContainer):

    __slots__ = ["id", "p1", "p2", "p3", "normal", "minx", "maxx", "miny", "maxy", "minz", "maxz",
                 "e1", "e2", "e3", "normal", "center", "radius", "radiussq", "middle"]

    def __init__(self, p1=None, p2=None, p3=None, n=None):
        # points are expected to be in ClockWise order
        super().__init__()
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        self.normal = n
        self.reset_cache()

    def reset_cache(self):
        self.minx = min(self.p1[0], self.p2[0], self.p3[0])
        self.miny = min(self.p1[1], self.p2[1], self.p3[1])
        self.minz = min(self.p1[2], self.p2[2], self.p3[2])
        self.maxx = max(self.p1[0], self.p2[0], self.p3[0])
        self.maxy = max(self.p1[1], self.p2[1], self.p3[1])
        self.maxz = max(self.p1[2], self.p2[2], self.p3[2])
        self.e1 = Line(self.p1, self.p2)
        self.e2 = Line(self.p2, self.p3)
        self.e3 = Line(self.p3, self.p1)
        # calculate normal, if p1-p2-pe are in clockwise order
        if self.normal is None:
            self.normal = pnormalized(pcross(psub(self.p3, self.p1), psub(self.p2, self.p1)))
        if not len(self.normal) > 3:
            self.normal = (self.normal[0], self.normal[1], self.normal[2], 'v')
        self.center = pdiv(padd(padd(self.p1, self.p2), self.p3), 3)
        self.plane = Plane(self.center, self.normal)
        # calculate circumcircle (resulting in radius and middle)
        denom = pnorm(pcross(psub(self.p2, self.p1), psub(self.p3, self.p2)))
        self.radius = (pdist(self.p2, self.p1) * pdist(self.p3, self.p2)
                       * pdist(self.p3, self.p1)) / (2 * denom)
        self.radiussq = self.radius ** 2
        denom2 = 2 * denom * denom
        alpha = pdist_sq(self.p3, self.p2) * pdot(psub(self.p1, self.p2),
                                                  psub(self.p1, self.p3)) / denom2
        beta = pdist_sq(self.p1, self.p3) * pdot(psub(self.p2, self.p1),
                                                 psub(self.p2, self.p3)) / denom2
        gamma = pdist_sq(self.p1, self.p2) * pdot(psub(self.p3, self.p1),
                                                  psub(self.p3, self.p2)) / denom2
        self.middle = (self.p1[0] * alpha + self.p2[0] * beta + self.p3[0] * gamma,
                       self.p1[1] * alpha + self.p2[1] * beta + self.p3[1] * gamma,
                       self.p1[2] * alpha + self.p2[2] * beta + self.p3[2] * gamma)

    def __repr__(self):
        return "Triangle%d<%s,%s,%s>" % (self.id, self.p1, self.p2, self.p3)

    def copy(self):
        return self.__class__(self.p1, self.p2, self.p3, self.normal)

    def __next__(self):
        yield "p1"
        yield "p2"
        yield "p3"
        yield "normal"

    def get_points(self):
        return (self.p1, self.p2, self.p3)

    def get_children_count(self):
        # tree points per triangle
        return 7

    def to_opengl(self, color=None, show_directions=False):
        if not GL_enabled:
            return
        if color is not None:
            GL.glColor4f(*color)
        GL.glBegin(GL.GL_TRIANGLES)
        # use normals to improve lighting (contributed by imyrek)
        normal_t = self.normal
        GL.glNormal3f(normal_t[0], normal_t[1], normal_t[2])
        # The triangle's points are in clockwise order, but GL expects
        # counter-clockwise sorting.
        GL.glVertex3f(self.p1[0], self.p1[1], self.p1[2])
        GL.glVertex3f(self.p3[0], self.p3[1], self.p3[2])
        GL.glVertex3f(self.p2[0], self.p2[1], self.p2[2])
        GL.glEnd()
        if show_directions:
            # display surface normals
            n = self.normal
            c = self.center
            d = 0.5
            GL.glBegin(GL.GL_LINES)
            GL.glVertex3f(c[0], c[1], c[2])
            GL.glVertex3f(c[0]+n[0]*d, c[1]+n[1]*d, c[2]+n[2]*d)
            GL.glEnd()
        if False:
            # display bounding sphere
            GL.glPushMatrix()
            middle = self.middle
            GL.glTranslate(middle[0], middle[1], middle[2])
            if not hasattr(self, "_sphere"):
                self._sphere = GLU.gluNewQuadric()
            GLU.gluSphere(self._sphere, self.radius, 10, 10)
            GL.glPopMatrix()
        if pycam.Utils.log.is_debug():
            # draw triangle id on triangle face
            GL.glPushMatrix()
            c = self.center
            GL.glTranslate(c[0], c[1], c[2])
            p12 = pmul(padd(self.p1, self.p2), 0.5)
            p3_12 = pnormalized(psub(self.p3, p12))
            p2_1 = pnormalized(psub(self.p1, self.p2))
            pn = pcross(p2_1, p3_12)
            GL.glMultMatrixf((p2_1[0], p2_1[1], p2_1[2], 0, p3_12[0], p3_12[1], p3_12[2], 0, pn[0],
                              pn[1], pn[2], 0, 0, 0, 0, 1))
            n = pmul(self.normal, 0.01)
            GL.glTranslatef(n[0], n[1], n[2])
            maxdim = max((self.maxx - self.minx), (self.maxy - self.miny), (self.maxz - self.minz))
            factor = 0.001
            GL.glScalef(factor * maxdim, factor * maxdim, factor * maxdim)
            w = 0
            id_string = "%s." % str(self.id)
            for ch in id_string:
                w += GLUT.glutStrokeWidth(GLUT_STROKE_ROMAN, ord(ch))
            GL.glTranslate(-w/2, 0, 0)
            for ch in id_string:
                GLUT.glutStrokeCharacter(GLUT_STROKE_ROMAN, ord(ch))
            GL.glPopMatrix()
        if False:
            # draw point id on triangle face
            c = self.center
            p12 = pmul(padd(self.p1, self.p2), 0.5)
            p3_12 = pnormalized(psub(self.p3, p12))
            p2_1 = pnormalized(psub(self.p1, self.p2))
            pn = pcross(p2_1, p3_12)
            n = pmul(self.normal, 0.01)
            for p in (self.p1, self.p2, self.p3):
                GL.glPushMatrix()
                pp = psub(p, pmul(psub(p, c), 0.3))
                GL.glTranslate(pp[0], pp[1], pp[2])
                GL.glMultMatrixf((p2_1[0], p2_1[1], p2_1[2], 0, p3_12[0], p3_12[1], p3_12[2], 0,
                                  pn[0], pn[1], pn[2], 0, 0, 0, 0, 1))
                GL.glTranslatef(n[0], n[1], n[2])
                GL.glScalef(0.001, 0.001, 0.001)
                w = 0
                for ch in str(p.id):
                    w += GLUT.glutStrokeWidth(GLUT_STROKE_ROMAN, ord(ch))
                    GL.glTranslate(-w/2, 0, 0)
                for ch in str(p.id):
                    GLUT.glutStrokeCharacter(GLUT_STROKE_ROMAN, ord(ch))
                GL.glPopMatrix()

    def is_point_inside(self, p):
        # http://www.blackpawn.com/texts/pointinpoly/default.html
        # Compute vectors
        v0 = psub(self.p3, self.p1)
        v1 = psub(self.p2, self.p1)
        v2 = psub(p, self.p1)
        # Compute dot products
        dot00 = pdot(v0, v0)
        dot01 = pdot(v0, v1)
        dot02 = pdot(v0, v2)
        dot11 = pdot(v1, v1)
        dot12 = pdot(v1, v2)
        # Compute barycentric coordinates
        denom = dot00 * dot11 - dot01 * dot01
        if denom == 0:
            return False
        inv_denom = 1.0 / denom
        # Originally, "u" and "v" are multiplied with "1/denom".
        # We don't do this to avoid division by zero (for triangles that are
        # "almost" invalid).
        u = (dot11 * dot02 - dot01 * dot12) * inv_denom
        v = (dot00 * dot12 - dot01 * dot02) * inv_denom
        # Check if point is in triangle
        return (u > 0) and (v > 0) and (u + v < 1)

    def subdivide(self, depth):
        sub = []
        if depth == 0:
            sub.append(self)
        else:
            p4 = pdiv(padd(self.p1, self.p2), 2)
            p5 = pdiv(padd(self.p2, self.p3), 2)
            p6 = pdiv(padd(self.p3, self.p1), 2)
            sub += Triangle(self.p1, p4, p6).subdivide(depth - 1)
            sub += Triangle(p6, p5, self.p3).subdivide(depth - 1)
            sub += Triangle(p6, p4, p5).subdivide(depth - 1)
            sub += Triangle(p4, self.p2, p5).subdivide(depth - 1)
        return sub

    def get_area(self):
        cross = pcross(psub(self.p2, self.p1), psub(self.p3, self.p1))
        return pnorm(cross) / 2
