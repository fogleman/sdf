"""
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

from pycam.Geometry import epsilon, INFINITE, TransformableContainer, IDGenerator
from pycam.Geometry.PointUtils import padd, pcross, pdot, pmul, pnorm, pnormalized

# "Line" is imported later to avoid circular imports
# from pycam.Geometry.Line import Line


class Plane(IDGenerator, TransformableContainer):

    __slots__ = ["id", "p", "n"]

    def __init__(self, point, normal=None):
        super().__init__()
        if normal is None:
            normal = (0, 0, 1, 'v')
        self.p = point
        self.n = normal
        if not len(self.n) > 3:
            self.n = (self.n[0], self.n[1], self.n[2], 'v')

    def __repr__(self):
        return "Plane<%s,%s>" % (self.p, self.n)

    def __lt__(self, other):
        return (self.p, self.n) < (other.p, other.n)

    def copy(self):
        return self.__class__(self.p, self.n)

    def __next__(self):
        yield "p"
        yield "n"

    def get_children_count(self):
        # a plane always consists of two points
        return 2

    def reset_cache(self):
        # we need to prevent the "normal" from growing
        norm = pnormalized(self.n)
        if norm:
            self.n = norm

    def intersect_point(self, direction, point):
        if (direction is not None) and (pnorm(direction) != 1):
            # calculations will go wrong, if the direction is not a unit vector
            direction = pnormalized(direction)
        if direction is None:
            return (None, INFINITE)
        denom = pdot(self.n, direction)
        if denom == 0:
            return (None, INFINITE)
        l_len = -(pdot(self.n, point) - pdot(self.n, self.p)) / denom
        cp = padd(point, pmul(direction, l_len))
        return (cp, l_len)

    def intersect_triangle(self, triangle, counter_clockwise=False):
        """ Returns the line of intersection of a triangle with a plane.
        "None" is returned, if:
            - the triangle does not intersect with the plane
            - all vertices of the triangle are on the plane
        The line always runs clockwise through the triangle.
        """
        # don't import Line in the header -> circular import
        from pycam.Geometry.Line import Line
        collisions = []
        for edge, point in ((triangle.e1, triangle.p1),
                            (triangle.e2, triangle.p2),
                            (triangle.e3, triangle.p3)):
            cp, l_len = self.intersect_point(edge.dir, point)
            # filter all real collisions
            # We don't want to count vertices double -> thus we only accept
            # a distance that is lower than the length of the edge.
            if (cp is not None) and (-epsilon < l_len < edge.len - epsilon):
                collisions.append(cp)
            elif (cp is None) and (pdot(self.n, edge.dir) == 0):
                cp, dist = self.intersect_point(self.n, point)
                if abs(dist) < epsilon:
                    # the edge is on the plane
                    collisions.append(point)
        if len(collisions) == 3:
            # All points of the triangle are on the plane.
            # We don't return a waterline, as there should be another non-flat
            # triangle with the same waterline.
            return None
        if len(collisions) == 2:
            collision_line = Line(collisions[0], collisions[1])
            # no further calculation, if the line is zero-sized
            if collision_line.len == 0:
                return collision_line
            cross = pcross(self.n, collision_line.dir)
            if (pdot(cross, triangle.normal) < 0) == bool(not counter_clockwise):
                # anti-clockwise direction -> revert the direction of the line
                collision_line = Line(collision_line.p2, collision_line.p1)
            return collision_line
        elif len(collisions) == 1:
            # only one point is on the plane
            # This waterline (with zero length) should be of no use.
            return None
        else:
            return None

    def get_point_projection(self, point):
        return self.intersect_point(self.n, point)[0]

    def get_line_projection(self, line):
        # don't import Line in the header -> circular import
        from pycam.Geometry.Line import Line
        proj_p1 = self.get_point_projection(line.p1)
        proj_p2 = self.get_point_projection(line.p2)
        return Line(proj_p1, proj_p2)
