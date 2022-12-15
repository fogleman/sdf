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

from pycam.Geometry.PolygonExtractor import PolygonExtractor
from pycam.Geometry.PointUtils import pdot, psub
import pycam.PathProcessors
from pycam.Toolpath import simplify_toolpath


class ContourCutter(pycam.PathProcessors.BasePathProcessor):
    def __init__(self):
        super().__init__()
        self.curr_path = None
        self.scanline = None
        self.polygon_extractor = None
        self.points = []
        self.__forward = (1, 1, 0)

    def append(self, point):
        # Sort the points in positive x/y direction - otherwise the
        # PolygonExtractor breaks.
        if self.points and (pdot(psub(point, self.points[0]), self.__forward) < 0):
            self.points.insert(0, point)
        else:
            self.points.append(point)

    def new_direction(self, direction):
        if self.polygon_extractor is None:
            self.polygon_extractor = PolygonExtractor(PolygonExtractor.CONTOUR)

        self.polygon_extractor.new_direction(direction)

    def end_direction(self):
        self.polygon_extractor.end_direction()

    def new_scanline(self):
        self.polygon_extractor.new_scanline()
        self.points = []

    def end_scanline(self):
        for i in range(1, len(self.points) - 1):
            self.polygon_extractor.append(self.points[i])
        self.polygon_extractor.end_scanline()

    def finish(self):
        self.polygon_extractor.finish()
        if self.polygon_extractor.merge_path_list:
            paths = self.polygon_extractor.merge_path_list
        elif self.polygon_extractor.hor_path_list:
            paths = self.polygon_extractor.hor_path_list
        else:
            paths = self.polygon_extractor.ver_path_list
        if paths:
            for path in paths:
                path.append(path.points[0])
                simplify_toolpath(path)
        if paths:
            self.paths.extend(paths)
            self.sort_layered()
        self.polygon_extractor = None
