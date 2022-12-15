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

from pycam.Geometry import INFINITE
from pycam.Geometry.Path import Path
from pycam.Utils.iterators import Iterator, CyclicIterator


DEBUG_POLYGONEXTRACTOR = False
DEBUG_POLYGONEXTRACTOR2 = False
DEBUG_POLYGONEXTRACTOR3 = False


class PolygonExtractor:
    CONTOUR = 1
    MONOTONE = 2

    def __init__(self, policy=MONOTONE):
        self.policy = policy
        self.hor_path_list = None
        self.ver_path_list = None
        self.merge_path_list = None

    def new_direction(self, direction):
        self.current_dir = direction
        self.all_path_list = []
        self.curr_path_list = []
        self.prev_line = []
        self.curr_line = []

        if DEBUG_POLYGONEXTRACTOR3:
            from pycam.Exporters.SVGExporter import SVGExporter
            self.svg = SVGExporter("test-%d.svg" % direction)
            if direction == 0:
                self.svg.fill("red")
            else:
                self.svg.fill("blue")
        if (self.policy == PolygonExtractor.CONTOUR) and (direction == 1) \
                and self.hor_path_list:
            self.last_x = -INFINITE
            self.delta_x = 0
            self.convert_hor_path_list()
        if DEBUG_POLYGONEXTRACTOR3:
            self.cont = SVGExporter("test-2.svg")
            self.cont.fill("green")

    def end_direction(self):
        if self.policy == PolygonExtractor.CONTOUR and self.hor_path_list:
            self.process_virtual_hor_scanline(INFINITE)

        self.new_scanline()
        self.end_scanline()

        if DEBUG_POLYGONEXTRACTOR3:
            self.svg.close()

        if self.policy == PolygonExtractor.CONTOUR and self.hor_path_list:
            for path in self.all_path_list:
                if DEBUG_POLYGONEXTRACTOR2:
                    print("points=", path.points)
                i = 0
                while i < len(path.points)-1:
                    if path.points[i][0] > path.points[i+1][0]:
                        if DEBUG_POLYGONEXTRACTOR2:
                            print("drop point %d:" % path.points[i].id)
                        path.points = path.points[:i] + path.points[i+1:]
                        if i > 0:
                            i -= 1
                    else:
                        i += 1

        if DEBUG_POLYGONEXTRACTOR:
            print("%d paths" % len(self.all_path_list))
            for path in self.all_path_list:
                print("%d:" % path.id),
                print("%d ->" % path.top_join.id)
                for point in path.points:
                    print("%d(%g,%g)" % (point.id, point[0], point[1]),)
                print("->%d" % path.bot_join.id)

        path_list = []
        while len(self.all_path_list) > 0:
            p0 = self.all_path_list[0]
            for path in self.all_path_list:
                if path.id < p0.id:
                    p0 = path

            if DEBUG_POLYGONEXTRACTOR:
                print("linking %d" % p0.id)
            self.all_path_list.remove(p0)

            p1 = p0.bot_join
            while True:
                if DEBUG_POLYGONEXTRACTOR:
                    print("splice %d into %d" % (p1.id, p0.id))
                self.all_path_list.remove(p1)
                p1.reverse()
                p0.points += p1.points
                if p1.top_join == p0:
                    break

                p2 = p1.top_join
                if DEBUG_POLYGONEXTRACTOR:
                    print("splicing %d into %d" % (p2.id, p0.id))
                self.all_path_list.remove(p2)
                p0.points += p2.points
                p1 = p2.bot_join

            path_list.append(p0)

        if DEBUG_POLYGONEXTRACTOR:
            print("%d paths" % len(path_list))
            for path in path_list:
                print("path %d(w=%d): " % (path.id, path.winding)),
                for point in path.points:
                    print("%d(%g,%g)" % (point.id, point[0], point[1])),
                print()

        if self.current_dir == 0:
            self.hor_path_list = path_list
        elif self.current_dir == 1:
            if (self.policy == PolygonExtractor.CONTOUR) and self.hor_path_list and path_list:
                self.merge_path_list = path_list
            else:
                self.ver_path_list = path_list

        if DEBUG_POLYGONEXTRACTOR3:
            from pycam.Exporters.SVGExporter import SVGExporter
            self.svg = SVGExporter("test-3.svg")
            for path in path_list:
                prev = None
                if len(path.points) <= 1:
                    continue
                for p in path.points:
                    if p.dir == 0:
                        self.svg.fill("red")
                    else:
                        self.svg.fill("blue")
                    self.svg.add_dot(p[0], p[1])
                    self.svg.add_text(p[0], p[1], str(p.id))
                    if prev:
                        self.svg.add_line(p[0], p[1], prev[0], prev[1])
                    prev = p
                p = path.points[0]
                self.svg.add_line(p[0], p[1], prev[0], prev[1])

            self.svg.close()
            self.cont.close()

    def finish(self):
        pass

    def new_scanline(self):
        self.curr_line = []

    def append(self, p):
        if DEBUG_POLYGONEXTRACTOR3:
            p.dir = self.current_dir
            self.svg.add_dot(p[0], p[1])
            self.svg.add_text(p[0], p[1], str(p.id))
        self.curr_line.append(p)

    def end_scanline(self):
        if self.current_dir == 0:
            self.process_hor_scanline(self.curr_line)
        elif self.current_dir == 1:
            if self.policy == PolygonExtractor.CONTOUR and self.hor_path_list:
                next_x = -INFINITE
                if len(self.curr_line) > 0:
                    next_x = self.curr_line[0][0]
                    self.delta_x = next_x - self.last_x
                    self.last_x = next_x
                else:
                    next_x = self.last_x + self.delta_x
                if next_x > -INFINITE:
                    self.process_virtual_hor_scanline(next_x)
            if DEBUG_POLYGONEXTRACTOR2:
                print("scanline =", self.curr_line)
            self.process_ver_scanline(self.curr_line)

    def process_hor_scanline(self, scanline):
        if DEBUG_POLYGONEXTRACTOR:
            last = 0
            inside = False
            s = ""
            for point in scanline:
                next_x = point[0]
                if inside:
                    s += "*" * int(next_x - last)
                else:
                    s += " " * int(next_x - last)
                last = next_x
                inside = not inside
            print(s)

        if DEBUG_POLYGONEXTRACTOR:
            print("active paths: "),
            for path in self.curr_path_list:
                print("%d(%g,%g)" % (path.id, path.points[-1][0], path.points[-1][1])),
            print()

            print("prev points: "),
            for point in self.prev_line:
                print("(%g,%g)" % (point[0], point[1])),
            print()

            print("active points: "),
            for point in scanline:
                print("%d(%g,%g)" % (point.id, point[0], point[1])),
            print()

        prev_point = Iterator(self.prev_line)
        curr_point = Iterator(scanline)
        curr_path = Iterator(self.curr_path_list)

        winding = 0
        while (prev_point.remains() > 0) or (curr_point.remains() > 0):
            if DEBUG_POLYGONEXTRACTOR:
                print("num_prev=%d, num_curr=%d" % (prev_point.remains(), curr_point.remains()))
            if (prev_point.remains() == 0) and (curr_point.remains() >= 2):
                c0 = next(curr_point)
                c1 = next(curr_point)
                # new path starts
                p0 = Path()
                p0.winding = winding + 1
                if DEBUG_POLYGONEXTRACTOR:
                    print("new path %d(%g,%g)" % (p0.id, c0[0], c0[1]))
                p0.append(c0)
                self.curr_path_list.append(p0)
                p1 = Path()
                p1.winding = winding
                if DEBUG_POLYGONEXTRACTOR:
                    print("new path %d(%g,%g)" % (p1.id, c1[0], c1[1]))
                p1.append(c1)
                self.curr_path_list.append(p1)
                p0.top_join = p1
                p1.top_join = p0
                continue

            if (prev_point.remains() >= 2) and (curr_point.remains() == 0):
                # old path ends
                p0 = curr_path.take_next()
                if DEBUG_POLYGONEXTRACTOR:
                    print("end path %d" % p0.id)
                self.all_path_list.append(p0)
                next(prev_point)
                p1 = curr_path.take_next()
                if DEBUG_POLYGONEXTRACTOR:
                    print("end path %d" % p1.id)
                self.all_path_list.append(p1)
                next(prev_point)
                p0.bot_join = p1
                p1.bot_join = p0
                continue

            if (prev_point.remains() >= 2) and (curr_point.remains() >= 2):
                p0 = prev_point.peek(0)
                p1 = prev_point.peek(1)
                c0 = curr_point.peek(0)
                c1 = curr_point.peek(1)

                if DEBUG_POLYGONEXTRACTOR:
                    print("overlap test: p0=%g p1=%g" % (p0[0], p1[0]))
                    print("overlap test: c0=%g c1=%g" % (c0[0], c1[0]))

                if c1[0] < p0[0]:
                    # new segment is completely to the left
                    # new path starts
                    s0 = Path()
                    if DEBUG_POLYGONEXTRACTOR:
                        print("new path %d(%g,%g) w=%d" % (s0.id, c0[0], c0[0], winding + 1))
                    s0.append(c0)
                    curr_path.insert(s0)
                    s1 = Path()
                    s0.winding = winding + 1
                    s1.winding = winding
                    if DEBUG_POLYGONEXTRACTOR:
                        print("new path %d(%g,%g) w=%d" % (s1.id, c1[0], c1[1], winding))
                    s1.append(c1)
                    curr_path.insert(s1)
                    next(curr_point)
                    next(curr_point)
                    s0.top_join = s1
                    s1.top_join = s0
                elif c0[0] > p1[0]:
                    # new segment is completely to the right
                    # old path ends
                    s0 = curr_path.take_next()
                    if DEBUG_POLYGONEXTRACTOR:
                        print("end path %d" % s0.id)
                    self.all_path_list.append(s0)
                    next(prev_point)
                    s1 = curr_path.take_next()
                    if DEBUG_POLYGONEXTRACTOR:
                        print("end path %d" % s1.id)
                    self.all_path_list.append(s1)
                    next(prev_point)
                    s0.bot_join = s1
                    s1.bot_join = s0
                    winding = s1.winding
                else:
                    # new segment is overlapping
                    left_path = next(curr_path)
                    right_path = curr_path.peek()
                    left_point = c0
                    right_point = c1
                    winding = left_path.winding
                    next(curr_point)
                    next(prev_point)

                    overlap_p = True
                    overlap_c = True
                    while overlap_c or overlap_p:
                        overlap_p = False
                        overlap_c = False
                        # check for path joins
                        if prev_point.remains() >= 2:
                            p2 = prev_point.peek(1)
                            if DEBUG_POLYGONEXTRACTOR:
                                print("join test: p0=%g p1=%g p2=%g" % (p0[0], p1[0], p2[0]))
                                print("join test: c0=%g c1=%g" % (c0[0], c1[0]))
                            if p2[0] <= c1[0]:
                                overlap_p = True
                                if self.policy == PolygonExtractor.CONTOUR:
                                    s0 = curr_path.take_next()
                                    s1 = curr_path.take_next()
                                    if curr_path.remains() >= 1:
                                        right_path = curr_path.peek()
                                    self.all_path_list.append(s0)
                                    self.all_path_list.append(s1)
                                    if DEBUG_POLYGONEXTRACTOR:
                                        print("path %d joins %d" % (s0.id, s1.id))
                                    s0.bot_join = s1
                                    s1.bot_join = s0
                                elif self.policy == PolygonExtractor.MONOTONE:
                                    s0 = curr_path.take_next()
                                    left_path.bot_join = s0
                                    s0.bot_join = left_path
                                    if DEBUG_POLYGONEXTRACTOR:
                                        print("path %d joins %d" % (left_path.id, s0.id))
                                    curr_path.remove(left_path)
                                    self.all_path_list.append(left_path)
                                    self.all_path_list.append(s0)
                                    s1 = next(curr_path)
                                    left_path = s1
                                    right_path = curr_path.peek()
                                next(prev_point)
                                next(prev_point)
                                winding = s1.winding
                                p0 = p2
                                if prev_point.remains() >= 1:
                                    p1 = prev_point.peek(0)
                            else:
                                overlap_p = False

                        # check for path splits
                        if curr_point.remains() >= 2:
                            c2 = curr_point.peek(1)
                            if DEBUG_POLYGONEXTRACTOR:
                                print("split test: p0=%g p1=%g" % (p0[0], p1[0]))
                                print("split test: c0=%g c1=%g c2=%g" % (c0[0], c1[0], c2[0]))
                            if c2[0] <= p1[0]:
                                overlap_c = True
                                s0 = Path()
                                s1 = Path()
                                s0.winding = winding + 1
                                s1.winding = winding
                                s0.top_join = s1
                                s1.top_join = s0
                                if DEBUG_POLYGONEXTRACTOR:
                                    print("region split into %d and %d (w=%d)"
                                          % (s0.id, s1.id, winding + 1))
                                next(curr_point)
                                c0 = next(curr_point)
                                if self.policy == PolygonExtractor.CONTOUR:
                                    s0.append(c1)
                                    curr_path.insert(s0)
                                    s1.append(c2)
                                    curr_path.insert(s1)
                                elif self.policy == PolygonExtractor.MONOTONE:
                                    s0.append(left_point)
                                    s1.append(c1)
                                    curr_path.insert_before(s0)
                                    curr_path.insert_before(s1)
                                    left_point = c2
                                if curr_point.remains() >= 1:
                                    c1 = curr_point.peek(0)
                                    right_point = c1
                            else:
                                overlap_c = False

                    if DEBUG_POLYGONEXTRACTOR:
                        print("add to path %d(%g,%g)"
                              % (left_path.id, left_point[0], left_point[1]))
                    left_path.append(left_point)
                    right_path.append(right_point)
                    if right_path == curr_path.peek():
                        next(curr_path)
                    if DEBUG_POLYGONEXTRACTOR:
                        print("add to path %d(%g,%g)"
                              % (right_path.id, right_point[0], right_point[1]))
                    winding = right_path.winding
                    next(prev_point)
                    next(curr_point)

        if DEBUG_POLYGONEXTRACTOR:
            output = "active paths: "
            for path in self.curr_path_list:
                output += "%d(%g,%g,w=%d)" % (path.id, path.points[-1][0], path.points[-1][1],
                                              path.winding)
            print(output)

        self.prev_line = scanline

    def process_ver_scanline(self, scanline):
        if DEBUG_POLYGONEXTRACTOR3:
            prev = None
            for p in scanline:
                if p.dir == 0:
                    self.cont.fill("red")
                else:
                    self.cont.fill("blue")
                self.cont.add_dot(p[0], p[1])
                self.cont.fill("black")
                self.cont.add_text(p[0], p[1], str(p.id))
                if prev:
                    self.cont.add_line(prev[0], prev[1], p[0], p[1])
                prev = p

        if DEBUG_POLYGONEXTRACTOR:
            last = 0
            inside = False
            s = ""
            for point in scanline:
                next_y = point[1]
                if inside:
                    s += "*" * int(next_y - last)
                else:
                    s += " " * int(next_y - last)
                last = next_y
                inside = not inside
            print(s)

        if DEBUG_POLYGONEXTRACTOR:
            print("active paths: "),
            for path in self.curr_path_list:
                print("%d(%g,%g)" % (path.id, path.points[-1][0], path.points[-1][1])),
            print()

            print("prev points: "),
            for point in self.prev_line:
                print("(%g,%g)" % (point[0], point[1])),
            print()

            print("active points: "),
            for point in scanline:
                print("%d(%g,%g)" % (point.id, point[0], point[1])),
            print()

        prev_point = Iterator(self.prev_line)
        curr_point = Iterator(scanline)
        curr_path = Iterator(self.curr_path_list)

        winding = 0
        while (prev_point.remains() > 0) or (curr_point.remains() > 0):
            if DEBUG_POLYGONEXTRACTOR:
                print("num_prev=%d, num_curr=%d" % (prev_point.remains(), curr_point.remains()))
            if (prev_point.remains() == 0) and (curr_point.remains() >= 2):
                c0 = next(curr_point)
                c1 = next(curr_point)
                # new path starts
                p0 = Path()
                p0.winding = winding + 1
                if DEBUG_POLYGONEXTRACTOR:
                    print("new path %d(%g,%g)" % (p0.id, c0[0], c0[1]))
                p0.append(c0)
                self.curr_path_list.append(p0)
                p1 = Path()
                p1.winding = winding
                if DEBUG_POLYGONEXTRACTOR:
                    print("new path %d(%g,%g)" % (p1.id, c1[0], c1[1]))
                p1.append(c1)
                self.curr_path_list.append(p1)
                p0.top_join = p1
                p1.top_join = p0
                continue

            if (prev_point.remains() >= 2) and (curr_point.remains() == 0):
                # old path ends
                p0 = curr_path.take_next()
                if DEBUG_POLYGONEXTRACTOR:
                    print("end path %d" % p0.id)
                self.all_path_list.append(p0)
                next(prev_point)
                p1 = curr_path.take_next()
                if DEBUG_POLYGONEXTRACTOR:
                    print("end path %d" % p1.id)
                self.all_path_list.append(p1)
                next(prev_point)
                p0.bot_join = p1
                p1.bot_join = p0
                continue

            if (prev_point.remains() >= 2) and (curr_point.remains() >= 2):
                p0 = prev_point.peek(0)
                p1 = prev_point.peek(1)
                c0 = curr_point.peek(0)
                c1 = curr_point.peek(1)

                if DEBUG_POLYGONEXTRACTOR:
                    print("overlap test: p0=%g p1=%g" % (p0[0], p1[0]))
                    print("overlap test: c0=%g c1=%g" % (c0[0], c1[0]))

                if c1[1] < p0[1]:
                    # new segment is completely to the left
                    # new path starts
                    s0 = Path()
                    if DEBUG_POLYGONEXTRACTOR:
                        print("new path %d(%g,%g) w=%d" % (s0.id, c0[0], c0[1], winding + 1))
                    s0.append(c0)
                    curr_path.insert(s0)
                    s1 = Path()
                    s0.winding = winding + 1
                    s1.winding = winding
                    if DEBUG_POLYGONEXTRACTOR:
                        print("new path %d(%g,%g) w=%d" % (s1.id, c1[0], c1[1], winding))
                    s1.append(c1)
                    curr_path.insert(s1)
                    next(curr_point)
                    next(curr_point)
                    s0.top_join = s1
                    s1.top_join = s0
                elif c0[1] > p1[1]:
                    # new segment is completely to the right
                    # old path ends
                    s0 = curr_path.take_next()
                    if DEBUG_POLYGONEXTRACTOR:
                        print("end path %d" % s0.id)
                    self.all_path_list.append(s0)
                    next(prev_point)
                    s1 = curr_path.take_next()
                    if DEBUG_POLYGONEXTRACTOR:
                        print("end path %d" % s1.id)
                    self.all_path_list.append(s1)
                    next(prev_point)
                    s0.bot_join = s1
                    s1.bot_join = s0
                    winding = s1.winding
                else:
                    # new segment is overlapping
                    left_path = next(curr_path)
                    right_path = curr_path.peek()
                    left_point = c0
                    right_point = c1
                    winding = left_path.winding
                    next(curr_point)
                    next(prev_point)

                    overlap_p = True
                    overlap_c = True
                    while overlap_c or overlap_p:
                        overlap_p = False
                        overlap_c = False
                        # check for path joins
                        if prev_point.remains() >= 2:
                            p2 = prev_point.peek(1)
                            if DEBUG_POLYGONEXTRACTOR:
                                print("join test: p0=%g p1=%g p2=%g" % (p0[0], p1[0], p2[0]))
                                print("join test: c0=%g c1=%g" % (c0[0], c1[0]))
                            if p2[1] <= c1[1]:
                                overlap_p = True
                                if self.policy == PolygonExtractor.CONTOUR:
                                    s0 = curr_path.take_next()
                                    s1 = curr_path.take_next()
                                    if curr_path.remains() >= 1:
                                        right_path = curr_path.peek()
                                    self.all_path_list.append(s0)
                                    self.all_path_list.append(s1)
                                    if DEBUG_POLYGONEXTRACTOR:
                                        print("path %d joins %d" % (s0.id, s1.id))
                                    s0.bot_join = s1
                                    s1.bot_join = s0
                                elif self.policy == PolygonExtractor.MONOTONE:
                                    s0 = curr_path.take_next()
                                    left_path.bot_join = s0
                                    s0.bot_join = left_path
                                    if DEBUG_POLYGONEXTRACTOR:
                                        print("path %d joins %d" % (left_path.id, s0.id))
                                    curr_path.remove(left_path)
                                    self.all_path_list.append(left_path)
                                    self.all_path_list.append(s0)
                                    s1 = next(curr_path)
                                    left_path = s1
                                    right_path = curr_path.peek()
                                next(prev_point)
                                next(prev_point)
                                winding = s1.winding
                                p0 = p2
                                if prev_point.remains() >= 1:
                                    p1 = prev_point.peek(0)
                            else:
                                overlap_p = False

                        # check for path splits
                        if curr_point.remains() >= 2:
                            c2 = curr_point.peek(1)
                            if DEBUG_POLYGONEXTRACTOR:
                                print("split test: p0=%g p1=%g" % (p0[0], p1[0]))
                                print("split test: c0=%g c1=%g c2=%g" % (c0[0], c1[0], c2[0]))
                            if c2[1] <= p1[1]:
                                overlap_c = True
                                s0 = Path()
                                s1 = Path()
                                s0.winding = winding + 1
                                s1.winding = winding
                                s0.top_join = s1
                                s1.top_join = s0
                                if DEBUG_POLYGONEXTRACTOR:
                                    print("region split into %d and %d (w=%d)"
                                          % (s0.id, s1.id, winding + 1))
                                next(curr_point)
                                c0 = next(curr_point)
                                if self.policy == PolygonExtractor.CONTOUR:
                                    s0.append(c1)
                                    curr_path.insert(s0)
                                    s1.append(c2)
                                    curr_path.insert(s1)
                                elif self.policy == PolygonExtractor.MONOTONE:
                                    s0.append(left_point)
                                    s1.append(c1)
                                    curr_path.insert_before(s0)
                                    curr_path.insert_before(s1)
                                    left_point = c2
                                if curr_point.remains() >= 1:
                                    c1 = curr_point.peek(0)
                                    right_point = c1
                            else:
                                overlap_c = False

                    if DEBUG_POLYGONEXTRACTOR:
                        print("add to path %d(%g,%g)"
                              % (left_path.id, left_point[0], left_point[1]))
                    left_path.append(left_point)
                    right_path.append(right_point)
                    if right_path == curr_path.peek():
                        next(curr_path)
                    if DEBUG_POLYGONEXTRACTOR:
                        print("add to path %d(%g,%g)"
                              % (right_path.id, right_point[0], right_point[1]))
                    winding = right_path.winding
                    next(prev_point)
                    next(curr_point)

        if DEBUG_POLYGONEXTRACTOR:
            output = "active paths: "
            for path in self.curr_path_list:
                output += "%d(%g,%g,w=%d)" % (path.id, path.points[-1][0], path.points[-1][1],
                                              path.winding)
            print(output)

        self.prev_line = scanline

    def convert_hor_path_list(self):
        if DEBUG_POLYGONEXTRACTOR2:
            print("converting hor paths")
        hor_path_list = []
        for s in self.hor_path_list:
            allsame = True
            miny = s.points[0][1]
            maxy = s.points[0][1]
            for p in s.points:
                if not p[0] == s.points[0][0]:
                    allsame = False
                if p[1] < miny:
                    miny = p[1]
                if p[1] > maxy:
                    maxy = p[1]
            if allsame:
                if DEBUG_POLYGONEXTRACTOR2:
                    print("all same !")
                s0 = Path()
                for p in s.points:
                    if p[1] == miny:
                        s0.append(p)
                hor_path_list.append(s0)
                s1 = Path()
                for p in s.points:
                    if p[1] == maxy:
                        s1.append(p)
                hor_path_list.append(s1)
                continue
            prev = s.points[-1]
            p_iter = CyclicIterator(s.points)
            p = s.points[0]
            next_p = next(p_iter)
            while not ((prev[0] >= p[0]) and (next_p[0] > p[0])):
                p = next_p
                next_p = next(p_iter)
            count = 0
            while count < len(s.points):
                s0 = Path()
                while next_p[0] >= p[0]:
                    s0.append(p)
                    p = next_p
                    next_p = next(p_iter)
                    count += 1
                s0.append(p)
                while (len(s0.points) > 1) \
                        and (s0.points[0][0] == s0.points[1][0]):
                    s0.points = s0.points[1:]
                while (len(s0.points) > 1) \
                        and (s0.points[-2][0] == s0.points[-1][0]):
                    s0.points = s0.points[0:-1]

                hor_path_list.append(s0)
                s1 = Path()
                while next_p[0] <= p[0]:
                    s1.append(p)
                    p = next_p
                    next_p = next(p_iter)
                    count += 1
                s1.append(p)
                s1.reverse()
                while (len(s1.points) > 1) \
                        and (s1.points[0][0] == s1.points[1][0]):
                    s1.points = s1.points[1:]
                while (len(s1.points) > 1) \
                        and (s1.points[-2][0] == s1.points[-1][0]):
                    s1.points = s1.points[:-1]
                hor_path_list.append(s1)
        hor_path_list.sort(key=lambda p: p.points[0][0])
        if DEBUG_POLYGONEXTRACTOR2:
            print("ver_hor_path_list = ", hor_path_list)
            for s in hor_path_list:
                print("s%d =" % s.id),
                for point in s.points:
                    print(point.id),
                print()
        self.ver_hor_path_list = hor_path_list

        self.act_hor_path_list = []

    def process_virtual_hor_scanline(self, next_x):

        _next_x = next_x

        while next_x <= _next_x:
            next_x = INFINITE

            if self.ver_hor_path_list \
                    and (self.ver_hor_path_list[0].points[0][0] < next_x):
                next_x = self.ver_hor_path_list[0].points[0][0]

            if self.act_hor_path_list \
                    and (self.act_hor_path_list[0].points[0][0] < next_x):
                next_x = self.act_hor_path_list[0].points[0][0]

            if next_x >= _next_x:
                return

            if DEBUG_POLYGONEXTRACTOR2:
                print("ver_hor_path_list =", self.ver_hor_path_list)
                print("act_hor_path_list =", self.act_hor_path_list)
                print("next_x =", next_x)

            if self.ver_hor_path_list \
                    and (self.ver_hor_path_list[0].points[0][0] <= next_x):
                while self.ver_hor_path_list \
                        and (self.ver_hor_path_list[0].points[0][0] <= next_x):
                    self.act_hor_path_list.append(self.ver_hor_path_list[0])
                    self.ver_hor_path_list = self.ver_hor_path_list[1:]
                self.act_hor_path_list.sort(key=lambda p: p.points[0][0])

            scanline = []
            i = 0
            while i < len(self.act_hor_path_list):
                s = self.act_hor_path_list[i]
                if DEBUG_POLYGONEXTRACTOR2:
                    print("s =", s)
                scanline.append(s.points[0])
                if s.points[0][0] <= next_x:
                    if len(s.points) <= 1:
                        if DEBUG_POLYGONEXTRACTOR2:
                            print("remove list")
                        self.act_hor_path_list.pop(i)
                        continue
                    else:
                        if DEBUG_POLYGONEXTRACTOR2:
                            print("remove point", s.points[0])
                        s.points.pop(0)
                i += 1
            self.act_hor_path_list.sort(key=lambda p: p.points[0][0])
            if not scanline:
                return

            scanline.sort(key=lambda l: l[1])
            if DEBUG_POLYGONEXTRACTOR2:
                print("scanline' =", scanline)
                print("ver_hor_path_list =", self.ver_hor_path_list)
                print("act_hor_path_list =", self.act_hor_path_list)
            self.process_ver_scanline(scanline)
