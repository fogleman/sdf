"""
Copyright 2008-2010 Lode Leroy
Copyright 2010-2011 Lars Kruse <devel@sumpfralle.de>

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

import uuid

from pycam.Geometry import number, INFINITE, epsilon
from pycam.Geometry import IDGenerator
from pycam.Geometry.intersection import intersect_cylinder_point, intersect_cylinder_line
from pycam.Geometry.PointUtils import padd, pdot, psub


class BaseCutter(IDGenerator):

    vertical = (0, 0, -1)

    def __init__(self, radius, location=None, height=None):
        super().__init__()
        if location is None:
            location = (0, 0, 0)
        if height is None:
            height = 10
        radius = number(radius)
        self.height = number(height)
        self.radius = radius
        self.radiussq = radius ** 2
        self.required_distance = 0
        self.distance_radius = self.radius
        self.distance_radiussq = self.distance_radius ** 2
        self.shape = {}
        self.location = location
        self.moveto(self.location)
        self.uuid = None
        self.update_uuid()

    def get_minx(self, start=None):
        if start is None:
            start = self.location
        return start[0] - self.distance_radius

    def get_maxx(self, start=None):
        if start is None:
            start = self.location
        return start[0] + self.distance_radius

    def get_miny(self, start=None):
        if start is None:
            start = self.location
        return start[1] - self.distance_radius

    def get_maxy(self, start=None):
        if start is None:
            start = self.location
        return start[1] + self.distance_radius

    def update_uuid(self):
        self.uuid = uuid.uuid4()

    def __repr__(self):
        return "BaseCutter"

    def __lt__(self, other):
        """ Compare Cutters by shape and size (ignoring the location)
        This function should be overridden by subclasses, if they describe
        cutters with a shape depending on more than just the radius.
        See the ToroidalCutter for an example.
        """
        return self.radius < other.radius

    def set_required_distance(self, value):
        if value >= 0:
            self.required_distance = number(value)
            self.distance_radius = self.radius + self.get_required_distance()
            self.distance_radiussq = self.distance_radius * self.distance_radius
            self.update_uuid()

    def get_required_distance(self):
        return self.required_distance

    def moveto(self, location):
        # "moveto" is used for collision detection calculation.
        self.location = location
        for shape, set_pos_func in self.shape.values():
            set_pos_func(location[0], location[1], location[2])

    def intersect(self, direction, triangle, start=None):
        raise NotImplementedError("Inherited class of BaseCutter does not implement the required "
                                  "function 'intersect'.")

    def drop(self, triangle, start=None):
        if start is None:
            start = self.location
        # check bounding box collision
        if self.get_minx(start) > triangle.maxx + epsilon:
            return None
        if self.get_maxx(start) < triangle.minx - epsilon:
            return None
        if self.get_miny(start) > triangle.maxy + epsilon:
            return None
        if self.get_maxy(start) < triangle.miny - epsilon:
            return None

        # check bounding circle collision
        c = triangle.middle
        if ((c[0] - start[0]) ** 2 + (c[1] - start[1]) ** 2
                > (self.distance_radiussq
                   + 2 * self.distance_radius * triangle.radius + triangle.radiussq) + epsilon):
            return None

        return self.intersect(BaseCutter.vertical, triangle, start=start)[0]

    def intersect_circle_triangle(self, direction, triangle, start=None):
        (cl, ccp, cp, d) = self.intersect_circle_plane(direction, triangle, start=start)
        if cp and triangle.is_point_inside(cp):
            return (cl, d, cp)
        return (None, INFINITE, None)

    def intersect_circle_vertex(self, direction, point, start=None):
        (cl, ccp, cp, l) = self.intersect_circle_point(direction, point, start=start)
        return (cl, l, cp)

    def intersect_circle_edge(self, direction, edge, start=None):
        (cl, ccp, cp, l) = self.intersect_circle_line(direction, edge, start=start)
        if cp:
            # check if the contact point is between the endpoints
            m = pdot(psub(cp, edge.p1), edge.dir)
            if (m < -epsilon) or (m > edge.len + epsilon):
                return (None, INFINITE, cp)
        return (cl, l, cp)

    def intersect_cylinder_point(self, direction, point, start=None):
        if start is None:
            start = self.location
        (ccp, cp, l) = intersect_cylinder_point(padd(psub(start, self.location), self.center),
                                                self.axis, self.distance_radius,
                                                self.distance_radiussq, direction, point)
        # offset intersection
        if ccp:
            cl = padd(start, psub(cp, ccp))
            return (cl, ccp, cp, l)
        return (None, None, None, INFINITE)

    def intersect_cylinder_vertex(self, direction, point, start=None):
        if start is None:
            start = self.location
        (cl, ccp, cp, l) = self.intersect_cylinder_point(direction, point, start=start)
        if ccp and ccp[2] < padd(psub(start, self.location), self.center)[2]:
            return (None, INFINITE, None)
        return (cl, l, cp)

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
        if start is None:
            start = self.location
        (cl, ccp, cp, l) = self.intersect_cylinder_line(direction, edge, start=start)
        if not ccp:
            return (None, INFINITE, None)
        m = pdot(psub(cp, edge.p1), edge.dir)
        if (m < -epsilon) or (m > edge.len + epsilon):
            return (None, INFINITE, None)
        if ccp[2] < padd(psub(start, self.location), self.center)[2]:
            return (None, INFINITE, None)
        return (cl, l, cp)
