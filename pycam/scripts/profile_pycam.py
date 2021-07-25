import cProfile
from os.path import join
import pstats
import sys
from time import time

from pycam.Cutters.CylindricalCutter import CylindricalCutter
from pycam.Geometry import Box3D, Point3D
from pycam.Gui.Console import ConsoleProgressBar
from pycam.Importers.STLImporter import import_model
from pycam.PathGenerators.DropCutter import DropCutter
from pycam.PathProcessors.PathAccumulator import PathAccumulator
from pycam.Toolpath import Bounds
from pycam.Toolpath.MotionGrid import get_fixed_grid
from pycam.Utils.locations import get_data_file_location

# Disable multi processing
from pycam.Utils import threading
threading.__multiprocessing = False

""" Profile PyCAM doing several operations, print out the top 10
(sorted by actual local runtime) methods.
"""

model = import_model(get_data_file_location(join('samples', 'pycam-textbox.stl')))


def run_dropcutter():
    """ Run DropCutter on standard PyCAM sample plaque """
    progress_bar = ConsoleProgressBar(sys.stdout)

    overlap = .6
    layer_distance = 1
    tool = CylindricalCutter(10)
    path_generator = DropCutter(PathAccumulator())
    bounds = Bounds(Bounds.TYPE_CUSTOM, Box3D(Point3D(model.minx-5, model.miny-5, model.minz),
                                              Point3D(model.maxx+5, model.maxy+5, model.maxz)))

    low, high = bounds.get_absolute_limits()
    line_distance = 2 * tool.radius * (1.0 - overlap)

    motion_grid = get_fixed_grid((low, high), layer_distance,
                                 line_distance, tool.radius / 4.0)
    path_generator.GenerateToolPath(tool, [model], motion_grid, minz=low[2], maxz=high[2],
                                    draw_callback=progress_bar.update)


if __name__ == '__main__':
    print(model.minx, model.miny, model.maxx, model.maxy)
    start_time = time()
    cProfile.run('run_dropcutter()', 'dropcutter.pyprof')
    run_time = time() - start_time
    print('\nDropcutter took %f seconds' % run_time)
    p = pstats.Stats('dropcutter.pyprof')
    print('Top ten time-consuming functions:')
    p.sort_stats('time').print_stats(10)
