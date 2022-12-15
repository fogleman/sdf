"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>
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

from pycam.PathGenerators import get_free_paths_triangles
import pycam.PathProcessors.ContourCutter
from pycam.Utils.threading import run_in_parallel
from pycam.Utils import ProgressCounter
import pycam.Utils.log
from pycam.Toolpath.Steps import MoveStraight, MoveSafety


log = pycam.Utils.log.get_logger()


# We need to use a global function here - otherwise it does not work with
# the multiprocessing Pool.
def _process_one_line(extra_args):
    p1, p2, models, cutter = extra_args
    points = get_free_paths_triangles(models, cutter, p1, p2)
    return points


class PushCutter:

    def __init__(self, waterlines=False):
        log.debug("Starting PushCutter")
        self.waterlines = waterlines

    def generate_toolpath(self, cutter, models, motion_grid, minz=None, maxz=None,
                          draw_callback=None):
        # Transfer the grid (a generator) into a list of lists and count the items.
        grid = []
        num_of_grid_positions = 0
        for layer in motion_grid:
            lines = []
            for line in layer:
                # convert the generator to a list
                lines.append(list(line))
            num_of_grid_positions += len(lines)
            grid.append(lines)

        num_of_layers = len(grid)

        progress_counter = ProgressCounter(num_of_grid_positions, draw_callback)

        current_layer = 0
        if self.waterlines:
            self.pa = pycam.PathProcessors.ContourCutter.ContourCutter()
        else:
            path = []
        for layer_grid in grid:
            # update the progress bar and check, if we should cancel the process
            if draw_callback and draw_callback(text=("PushCutter: processing layer %d/%d"
                                                     % (current_layer + 1, num_of_layers))):
                # cancel immediately
                break

            if self.waterlines:
                self.pa.new_direction(0)
            result = self.generate_toolpath_slice(cutter, models, layer_grid, draw_callback,
                                                  progress_counter)
            if self.waterlines:
                self.pa.end_direction()
                self.pa.finish()
            else:
                path.extend(result)

            current_layer += 1

        if self.waterlines:
            # TODO: this is complicated and hacky :(
            # we don't use parallelism (for the sake of simplicity)
            result = []
            # turn the waterline points into cutting segments
            for path in self.pa.paths:
                pairs = []
                for index in range(len(path.points) - 1):
                    pairs.append((path.points[index], path.points[index + 1]))
                if len(models) > 1:
                    # We assume that the first model is used for the waterline and all
                    # other models are obstacles (e.g. a support grid).
                    other_models = models[1:]
                    for p1, p2 in pairs:
                        free_points = get_free_paths_triangles(other_models, cutter, p1, p2)
                        for index in range(len(free_points) // 2):
                            result.append(MoveStraight(free_points[2 * index]))
                            result.append(MoveStraight(free_points[2 * index + 1]))
                            result.append(MoveSafety())
                else:
                    for p1, p2 in pairs:
                        result.append(MoveStraight(p1))
                        result.append(MoveStraight(p2))
                        result.append(MoveSafety())
            return result
        else:
            return path

    def generate_toolpath_slice(self, cutter, models, layer_grid, draw_callback=None,
                                progress_counter=None):
        path = []
        # the ContourCutter pathprocessor does not work with combined models
        if self.waterlines:
            models = models[:1]
        else:
            models = models
        args = []
        for line in layer_grid:
            p1, p2 = line
            args.append((p1, p2, models, cutter))
        for points in run_in_parallel(_process_one_line, args, callback=progress_counter.update):
            if points:
                if self.waterlines:
                    self.pa.new_scanline()
                    for point in points:
                        self.pa.append(point)
                else:
                    for index in range(len(points) // 2):
                        path.append(MoveStraight(points[2 * index]))
                        path.append(MoveStraight(points[2 * index + 1]))
                        path.append(MoveSafety())
                if self.waterlines:
                    if draw_callback:
                        draw_callback(tool_position=points[-1])
                    self.pa.end_scanline()
                else:
                    if draw_callback:
                        draw_callback(tool_position=points[-1], toolpath=path)
            # update the progress counter
            if progress_counter and progress_counter.increment():
                # quit requested
                break

        if not self.waterlines:
            return path
