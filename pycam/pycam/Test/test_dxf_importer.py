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

from pycam.Importers.DXFImporter import import_model
import pycam.Test


ASSETS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")

DXF_TEST_FILES = {"bezier_lines.dxf"}


class TestDXFImporter(pycam.Test.PycamTestCase):
    """ Checks ability to open some sample .dxf files correctly """

    def test_load_dxf_files(self):
        for test_filename in DXF_TEST_FILES:
            full_filename = os.path.join(ASSETS_PATH, test_filename)
            model = import_model(full_filename)
            assert model
