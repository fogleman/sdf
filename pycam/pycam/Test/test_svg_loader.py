"""
Copyright 2018 Lars Kruse <devel@sumpfralle.de>

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

import os

from pycam.Importers.SVGDirectImporter import import_model
import pycam.Test


BASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.path.pardir, os.path.pardir)
SAMPLES_DIR = os.path.realpath(os.path.join(BASE_DIR, "samples"))


class TestSVGLoader(pycam.Test.PycamTestCase):

    @staticmethod
    def _get_svg_filenames(path):
        for dirpath, dirnames, filenames in os.walk(path):
            yield from (os.path.join(dirpath, filename) for filename in filenames
                        if filename.lower().endswith(".svg"))

    def test_load_sample_svg_files(self):
        test_count = 0
        for svg_filename in self._get_svg_filenames(SAMPLES_DIR):
            model = import_model(svg_filename)
            self.assertGreater(len(model), 0,
                               "Too few imported polygons from {}".format(svg_filename))
            test_count += 1
        self.assertEqual(test_count, 8)

    def test_polygon_import(self):
        model = import_model(os.path.join(SAMPLES_DIR, "polygons.svg"))
        self.assertEqual(len(model), 3)
