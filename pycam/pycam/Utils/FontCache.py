"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>

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

import pycam.Importers.CXFImporter
import pycam.Utils.log


DEFAULT_NAMES = ("normal", "default", "standard")


log = pycam.Utils.log.get_logger()


class FontCache:
    """ The FontCache gradually loads fonts. This is more efficient than an
    immediate initialization of all fonts for the DXF importer.
    Use "get_font" for loading (incrementally) fonts until the requested font
    name was found.
    The functions "get_names" and "len()" trigger an immediate initialization
    of all available fonts.
    """

    def __init__(self, font_dir=None, core=None):
        self.font_dir = font_dir
        self.fonts = {}
        self.core = core
        self._unused_font_files = list(self._get_font_files())

    def is_loading_complete(self):
        return len(self._unused_font_files) == 0

    def _get_font_files(self):
        if self.font_dir is None:
            return []
        log.info("Font directory: %s", self.font_dir)
        result = []
        files = os.listdir(self.font_dir)
        for fname in files:
            filename = os.path.join(self.font_dir, fname)
            if filename.lower().endswith(".cxf") and os.path.isfile(filename):
                result.append(filename)
        result.sort()
        return result

    def __len__(self):
        self._load_all_files()
        return len(self.fonts)

    def _get_font_without_loading(self, name):
        for font_name in self.fonts:
            if font_name.lower() == name.lower():
                return self.fonts[font_name]
        return None

    def get_font_names(self):
        self._load_all_files()
        return self.fonts.keys()

    def get_font(self, name):
        font = self._get_font_without_loading(name)
        while not font and not self.is_loading_complete():
            self._load_next_file()
            font = self._get_font_without_loading(name)
        if font:
            return font
        else:
            # no font with that name is available
            for other_name in DEFAULT_NAMES:
                font = self._get_font_without_loading(other_name)
                if font:
                    return font
            if self.fonts:
                # return the first (random) font in the dictionary
                return self.fonts.values()[0]

    def _load_all_files(self):
        if self.core:
            progress = self.core.get("progress")
            progress.set_multiple(len(self._unused_font_files), "Loading font")
        else:
            progress = None
        while not self.is_loading_complete():
            self._load_next_file(progress=progress)
            if progress:
                progress.update_multiple()
        if progress:
            progress.finish()

    def _load_next_file(self, progress=None):
        if self.is_loading_complete():
            return
        filename = self._unused_font_files.pop(0)
        if progress:
            callback = progress.update
            progress.update(text="Loading font file %s" % os.path.basename(filename))
        else:
            callback = None
        charset = pycam.Importers.CXFImporter.import_font(filename, callback=callback)
        if charset is not None:
            for name in charset.get_names():
                self.fonts[name] = charset
