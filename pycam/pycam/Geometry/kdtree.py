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

try:
    import OpenGL.GL as GL
    GL_enabled = True
except ImportError:
    GL_enabled = False

from pycam.Geometry import IDGenerator


class Node:

    __slots__ = ["obj", "bound"]

    def __init__(self, obj, bound):
        self.obj = obj
        self.bound = bound

    def __repr__(self):
        s = ""
        for bound in self.bound:
            s += "%g : " % bound
        return s


def find_max_spread(nodes):
    minval = []
    maxval = []
    n = nodes[0]
    numdim = len(n.bound)
    for b in n.bound:
        minval.append(b)
        maxval.append(b)
    for n in nodes:
        for j in range(0, numdim):
            minval[j] = min(minval[j], n.bound[j])
            maxval[j] = max(maxval[j], n.bound[j])
    maxspreaddim = 0
    maxspread = maxval[0]-minval[0]
    for i in range(1, numdim):
        spread = maxval[i]-minval[i]
        if spread > maxspread:
            maxspread = spread
            maxspreaddim = i
    return (maxspreaddim, maxspread)


class Kdtree(IDGenerator):

    __slots__ = ["bucket", "dim", "cutoff", "cutoff_distance", "nodes", "cutdim", "minval",
                 "maxval", "cutval", "hi", "lo"]

    def __init__(self, nodes, cutoff, cutoff_distance):
        super().__init__()
        self.bucket = False
        if nodes and len(nodes) > 0:
            self.dim = len(nodes[0].bound)
        else:
            self.dim = 0
        self.cutoff = cutoff
        self.cutoff_distance = cutoff_distance

        if len(nodes) <= self.cutoff:
            self.bucket = True
            self.nodes = nodes
        else:
            (cutdim, spread) = find_max_spread(nodes)
            if spread <= self.cutoff_distance:
                self.bucket = True
                self.nodes = nodes
            else:
                self.bucket = False
                self.cutdim = cutdim
                nodes.sort(key=lambda item: item.bound[cutdim])
                median = len(nodes) // 2
                self.minval = nodes[0].bound[cutdim]
                self.maxval = nodes[-1].bound[cutdim]
                self.cutval = nodes[median].bound[cutdim]
                self.lo = Kdtree(nodes[0:median], cutoff, cutoff_distance)
                self.hi = Kdtree(nodes[median:], cutoff, cutoff_distance)

    def __repr__(self):
        if self.bucket:
            if True:
                return "(#%d)" % len(self.nodes)
            else:
                s = "("
                for n in self.nodes:
                    if len(s) > 1:
                        s += ", %s)" % str(n.p.id)
                return s
        else:
            return "(%s,%d:%g,%s)" % (self.lo, self.cutdim, self.cutval, self.hi)

    def to_opengl(self, minx, maxx, miny, maxy, minz, maxz):
        if not GL_enabled:
            return
        if self.bucket:
            GL.glBegin(GL.GL_LINES)
            GL.glVertex3d(minx, miny, minz)
            GL.glVertex3d(minx, miny, maxz)
            GL.glVertex3d(minx, maxy, minz)
            GL.glVertex3d(minx, maxy, maxz)
            GL.glVertex3d(maxx, miny, minz)
            GL.glVertex3d(maxx, miny, maxz)
            GL.glVertex3d(maxx, maxy, minz)
            GL.glVertex3d(maxx, maxy, maxz)

            GL.glVertex3d(minx, miny, minz)
            GL.glVertex3d(maxx, miny, minz)
            GL.glVertex3d(minx, maxy, minz)
            GL.glVertex3d(maxx, maxy, minz)
            GL.glVertex3d(minx, miny, maxz)
            GL.glVertex3d(maxx, miny, maxz)
            GL.glVertex3d(minx, maxy, maxz)
            GL.glVertex3d(maxx, maxy, maxz)

            GL.glVertex3d(minx, miny, minz)
            GL.glVertex3d(minx, maxy, minz)
            GL.glVertex3d(maxx, miny, minz)
            GL.glVertex3d(maxx, maxy, minz)
            GL.glVertex3d(minx, miny, maxz)
            GL.glVertex3d(minx, maxy, maxz)
            GL.glVertex3d(maxx, miny, maxz)
            GL.glVertex3d(maxx, maxy, maxz)
            GL.glEnd()
        elif self.dim == 6:
            if self.cutdim == 0 or self.cutdim == 2:
                self.lo.to_opengl(minx, self.cutval, miny, maxy, minz, maxz)
                self.hi.to_opengl(self.cutval, maxx, miny, maxy, minz, maxz)
            elif self.cutdim == 1 or self.cutdim == 3:
                self.lo.to_opengl(minx, maxx, miny, self.cutval, minz, maxz)
                self.hi.to_opengl(minx, maxx, self.cutval, maxy, minz, maxz)
            elif self.cutdim == 4 or self.cutdim == 5:
                self.lo.to_opengl(minx, maxx, miny, maxx, minz, self.cutval)
                self.hi.to_opengl(minx, maxx, miny, maxy, self.cutval, maxz)
        elif self.dim == 4:
            if self.cutdim == 0 or self.cutdim == 2:
                self.lo.to_opengl(minx, self.cutval, miny, maxy, minz, maxz)
                self.hi.to_opengl(self.cutval, maxx, miny, maxy, minz, maxz)
            elif self.cutdim == 1 or self.cutdim == 3:
                self.lo.to_opengl(minx, maxx, miny, self.cutval, minz, maxz)
                self.hi.to_opengl(minx, maxx, self.cutval, maxy, minz, maxz)
        elif self.dim == 3:
            if self.cutdim == 0:
                self.lo.to_opengl(minx, self.cutval, miny, maxy, minz, maxz)
                self.hi.to_opengl(self.cutval, maxx, miny, maxy, minz, maxz)
            elif self.cutdim == 1:
                self.lo.to_opengl(minx, maxx, miny, self.cutval, minz, maxz)
                self.hi.to_opengl(minx, maxx, self.cutval, maxy, minz, maxz)
            elif self.cutdim == 2:
                self.lo.to_opengl(minx, maxx, miny, maxy, minz, self.cutval)
                self.hi.to_opengl(minx, maxx, miny, maxy, self.cutval, maxz)

    def dist(self, n1, n2):
        dist = 0
        for i in range(len(n1.bound)):
            d = n1.bound[i] - n2.bound[i]
            dist += d*d
        return dist

    def nearest_neighbor(self, node, dist=None):
        if dist is None:
            dist = self.dist
        if self.bucket:
            if len(self.nodes) == 0:
                return (None, 0)
            best = self.nodes[0]
            bestdist = dist(node, best)
            for n in self.nodes:
                d = dist(n, node)
                if d < bestdist:
                    best = n
                    bestdist = d
            return (best, bestdist)
        else:
            if node.bound[self.cutdim] <= self.cutval:
                (best, bestdist) = self.lo.nearest_neighbor(node, dist)
                if bestdist > self.cutval - best.bound[self.cutdim]:
                    (best2, bestdist2) = self.hi.nearest_neighbor(node, dist)
                    if bestdist2 < bestdist:
                        return (best2, bestdist2)
                return (best, bestdist)
            else:
                (best, bestdist) = self.hi.nearest_neighbor(node, dist)
                if bestdist > best.bound[self.cutdim] - self.cutval:
                    (best2, bestdist2) = self.lo.nearest_neighbor(node, dist)
                    if bestdist2 < bestdist:
                        return (best2, bestdist2)
                return (best, bestdist)

    def insert(self, node):
        if self.dim == 0:
            self.dim = len(node.bound)

        if self.bucket:
            self.nodes.append(node)
            if len(self.nodes) > self.cutoff:
                self.bucket = False
                (cutdim, spread) = find_max_spread(self.nodes)
                self.cutdim = cutdim
                self.nodes.sort(key=lambda node: node.bound[cutdim])
                median = len(self.nodes) // 2
                self.minval = self.nodes[0].bound[cutdim]
                self.maxval = self.nodes[-1].bound[cutdim]
                self.cutval = self.nodes[median].bound[cutdim]
                self.lo = Kdtree(self.nodes[0:median], self.cutoff, self.cutoff_distance)
                self.hi = Kdtree(self.nodes[median:], self.cutoff, self.cutoff_distance)
        else:
            if node.bound[self.cutdim] <= self.cutval:
                self.lo.insert(node)
            else:
                self.hi.insert(node)
