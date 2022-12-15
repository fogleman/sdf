"""
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


class BasePathProcessor:

    def __init__(self):
        self.paths = []

    def new_direction(self, direction):
        pass

    def end_direction(self):
        pass

    def finish(self):
        pass

    def sort_layered(self, upper_first=True):
        if upper_first:
            def compare_height(path1, path2):
                return path1.points[0][2] < path2.points[0][2]
        else:
            def compare_height(path1, path2):
                return path1.points[0][2] > path2.points[0][2]
        finished = False
        while not finished:
            index = 0
            finished = True
            while index < len(self.paths) - 1:
                current_path = self.paths[index]
                next_path = self.paths[index + 1]
                if compare_height(current_path, next_path):
                    del self.paths[index]
                    self.paths.insert(index + 1, current_path)
                    finished = False
                index += 1
