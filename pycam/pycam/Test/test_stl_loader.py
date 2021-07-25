"""
Copyright 2018 Ruslan Panasiuk <ruslan.panasiuk@gmail.com>

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

import pycam.Test
from pycam.Importers.STLImporter import import_model

cwd = os.path.dirname(os.path.abspath(__file__))

ASSETS_DIR = 'assets'


def path_to_asset(asset_name):
    """
    Returns abs path for given `asset_name`
    :param asset_name: file name of the asset from 'Tests/assets'
    :returns: str - abs path to asset
    """
    return os.path.join(cwd, ASSETS_DIR, asset_name)


class TestSTLLoader(pycam.Test.PycamTestCase):
    """
    Checks ability to load binary .stl files correctly
    """

    def test_load_ascii_file(self):
        model = import_model(path_to_asset('cube_ascii.stl'))
        self.assertEqual(len(model), 12)

    def test_load_binary_file(self):
        model = import_model(path_to_asset('cube_binary.stl'))
        self.assertEqual(len(model), 12)
