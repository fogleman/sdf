"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>
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

from collections import namedtuple

from pycam.Geometry import IDGenerator

"""
The points of a path are only used for describing coordinates. Thus we don't really need complete
"Point" instances that consume a lot of memory.
Since python 2.6 the "namedtuple" factory is available.
This reduces the memory consumption of a toolpath down to 1/3.
"""
tuple_point = namedtuple("TuplePoint", "x y z")


def get_point_object(point):
    return tuple_point(point[0], point[1], point[2])


class Path(IDGenerator):

    def __init__(self):
        super().__init__()
        self.top_join = None
        self.bot_join = None
        self.winding = 0
        self.points = []

    def __repr__(self):
        text = ""
        text += "path %d: " % self.id
        first = True
        for point in self.points:
            if first:
                first = False
            else:
                text += "-"
            text += "%d(%g,%g,%g)" % (id(point), point[0], point[1], point[2])
        return text

    def insert(self, index, point):
        self.points.insert(index, get_point_object(point))

    def append(self, point):
        self.points.append(get_point_object(point))

    def reverse(self):
        self.points.reverse()
