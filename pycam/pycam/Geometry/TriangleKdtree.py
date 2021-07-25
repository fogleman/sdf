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

from pycam.Geometry.kdtree import Kdtree, Node

overlaptest = True


def search_kdtree_2d(tree, minx, maxx, miny, maxy):
    if tree.bucket:
        triangles = []
        for n in tree.nodes:
            if not overlaptest:
                triangles.append(n.obj)
            else:
                if not ((n.bound[0] > maxx) or
                        (n.bound[1] < minx) or
                        (n.bound[2] > maxy) or
                        (n.bound[3] < miny)):
                    triangles.append(n.obj)
        return triangles
    else:
        if tree.cutdim == 0:
            if maxx < tree.minval:
                return []
            elif maxx < tree.cutval:
                return search_kdtree_2d(tree.lo, minx, maxx, miny, maxy)
            else:
                return (search_kdtree_2d(tree.lo, minx, maxx, miny, maxy)
                        + search_kdtree_2d(tree.hi, minx, maxx, miny, maxy))
        elif tree.cutdim == 1:
            if minx > tree.maxval:
                return []
            elif minx > tree.cutval:
                return search_kdtree_2d(tree.hi, minx, maxx, miny, maxy)
            else:
                return (search_kdtree_2d(tree.lo, minx, maxx, miny, maxy)
                        + search_kdtree_2d(tree.hi, minx, maxx, miny, maxy))
        elif tree.cutdim == 2:
            if maxy < tree.minval:
                return []
            elif maxy < tree.cutval:
                return search_kdtree_2d(tree.lo, minx, maxx, miny, maxy)
            else:
                return (search_kdtree_2d(tree.lo, minx, maxx, miny, maxy)
                        + search_kdtree_2d(tree.hi, minx, maxx, miny, maxy))
        elif tree.cutdim == 3:
            if miny > tree.maxval:
                return []
            elif miny > tree.cutval:
                return search_kdtree_2d(tree.hi, minx, maxx, miny, maxy)
            else:
                return (search_kdtree_2d(tree.lo, minx, maxx, miny, maxy)
                        + search_kdtree_2d(tree.hi, minx, maxx, miny, maxy))


class TriangleKdtree(Kdtree):

    __slots__ = []

    def __init__(self, triangles, cutoff=3, cutoff_distance=1.0):
        nodes = []
        for t in triangles:
            n = Node(t, (min(t.p1[0], t.p2[0], t.p3[0]),
                         max(t.p1[0], t.p2[0], t.p3[0]),
                         min(t.p1[1], t.p2[1], t.p3[1]),
                         max(t.p1[1], t.p2[1], t.p3[1])))
            nodes.append(n)
        super().__init__(nodes, cutoff, cutoff_distance)

    def search(self, minx, maxx, miny, maxy):
        return search_kdtree_2d(self, minx, maxx, miny, maxy)
