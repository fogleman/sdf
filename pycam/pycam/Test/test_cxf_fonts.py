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

import pycam.Test
import pycam.Utils.FontCache


FONT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         os.path.pardir, os.path.pardir, "share", "fonts")


class TestCXFImporter(pycam.Test.PycamTestCase):
    """
    Checks ability to open all included .cxf font files correctly
    """

    def test_load_ascii_file(self):
        cache = pycam.Utils.FontCache.FontCache(FONT_PATH)
        # the number of fonts is lower by one, but "Standard" and "Normal" are aliases
        assert len(cache) == 35
