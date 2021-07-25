"""
Copyright 2010-2018 Lars Kruse <devel@sumpfralle.de>

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

import contextlib
import os
import sys
import tempfile

import pycam.Utils
import pycam.Utils.log


APP_NAME = "pycam"
DATA_DIR_ENVIRON_KEY = "PYCAM_DATA_DIR"
FONT_DIR_ENVIRON_KEY = "PYCAM_FONT_DIR"

# this directory represents the base of the development tree
PROJECT_BASE_DIR = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)),
                                                 os.pardir, os.pardir))
# necessary for "pyinstaller"
if "_MEIPASS2" in os.environ:
    PROJECT_BASE_DIR = os.path.normpath(os.environ["_MEIPASS2"])

# lookup list of directories for UI files, fonts, ...
DATA_BASE_DIRS = [os.path.join(PROJECT_BASE_DIR, "share"),
                  os.path.join(PROJECT_BASE_DIR, "share", APP_NAME),
                  os.path.join(sys.prefix, "local", "share", APP_NAME),
                  os.path.join(sys.prefix, "share", APP_NAME), '.']
FONTS_SUBDIR = "fonts"
UI_SUBDIR = "ui"

# respect an override via environment settings
if DATA_DIR_ENVIRON_KEY in os.environ:
    DATA_BASE_DIRS.insert(0, os.path.normpath(os.environ[DATA_DIR_ENVIRON_KEY]))
if FONT_DIR_ENVIRON_KEY in os.environ:
    FONT_DIR_OVERRIDE = os.path.normpath(os.environ[FONT_DIR_ENVIRON_KEY])
else:
    FONT_DIR_OVERRIDE = None
FONT_DIRS_FALLBACK = ["/usr/share/librecad/fonts", "/usr/share/qcad/fonts"]


log = pycam.Utils.log.get_logger()


def get_ui_file_location(filename, silent=False):
    return get_data_file_location(os.path.join(UI_SUBDIR, filename), silent=silent)


def get_data_file_location(filename, silent=False, priority_directories=None):
    if priority_directories is None:
        scan_dirs = DATA_BASE_DIRS
    else:
        scan_dirs = tuple(priority_directories) + tuple(DATA_BASE_DIRS)
    for base_dir in scan_dirs:
        test_path = os.path.join(base_dir, filename)
        if os.path.exists(test_path):
            return test_path
    if not silent:
        log.error("Failed to locate a resource file (%s) in %s! "
                  "You can extend the search path by setting the environment variable '%s'.",
                  filename, DATA_BASE_DIRS, str(DATA_DIR_ENVIRON_KEY))
    return None


def get_font_dir():
    if FONT_DIR_OVERRIDE:
        if os.path.isdir(FONT_DIR_OVERRIDE):
            return FONT_DIR_OVERRIDE
        else:
            log.warn("You specified a font dir that does not exist (%s). I will ignore it.",
                     FONT_DIR_OVERRIDE)
    font_dir = get_data_file_location(FONTS_SUBDIR, silent=True)
    if font_dir is not None:
        return font_dir
    else:
        log.warn("Failed to locate the fonts directory '%s' below '%s'. Falling back to '%s'.",
                 FONTS_SUBDIR, DATA_BASE_DIRS, ":".join(FONT_DIRS_FALLBACK))
        for font_dir_fallback in FONT_DIRS_FALLBACK:
            if os.path.isdir(font_dir_fallback):
                return font_dir_fallback
        log.warn("None of the fallback font directories (%s) exist. No fonts will be available.",
                 ":".join(FONT_DIRS_FALLBACK))
        return None


def get_external_program_location(key):
    extensions = ["", ".exe"]
    potential_names = ["%s%s" % (key, ext) for ext in extensions]
    windows_program_directories = {'inkscape': ['Inkscape'], 'pstoedit': ['pstoedit']}
    # check the windows path via win32api
    try:
        import win32api
        location = win32api.FindExecutable(key)[1]
        if location:
            return location
    except Exception:
        # Wildcard (non-system exiting) exception to match "ImportError" and
        # "pywintypes.error" (for "not found").
        pass
    # go through the PATH environment variable
    if "PATH" in os.environ:
        path_env = os.environ["PATH"]
        for one_dir in path_env.split(os.pathsep):
            for basename in potential_names:
                location = os.path.join(one_dir, basename)
                if os.path.isfile(location):
                    return location
    # do a manual scan in the programs directory (only for windows)
    program_dirs = ["C:\\Program Files", "C:\\Programme"]
    try:
        from win32com.shell import shellcon, shell
        # The frozen application somehow does not provide this setting.
        program_dirs.insert(0, shell.SHGetFolderPath(0, shellcon.CSIDL_PROGRAM_FILES, 0, 0))
    except ImportError:
        # no other options for non-windows systems
        pass
    # scan the program directory
    for program_dir in program_dirs:
        for sub_dir in windows_program_directories[key]:
            for basename in potential_names:
                location = os.path.join(program_dir, sub_dir, basename)
                if os.path.isfile(location):
                    return location
    # nothing found
    return None


def get_all_program_locations(core):
    # TODO: this should move to a plugin
    # import all external program locations into a dict
    program_locations = {}
    prefix = "external_program_"
    for key in core:
        if key.startswith(prefix) and core[key]:
            program_locations[key[len(prefix):]] = core[key]
    return program_locations


@contextlib.contextmanager
def open_file_context(filename, mode, is_text):
    if isinstance(filename, pycam.Utils.URIHandler):
        filename = filename.get_path()
    if filename is None:
        raise OSError("missing filename")
    if mode == "r":
        opened_file = open(filename, "r")
    elif mode == "w":
        handle, temp_filename = tempfile.mkstemp(prefix=os.path.basename(filename) + ".",
                                                 dir=os.path.dirname(filename), text=is_text)
        opened_file = os.fdopen(handle, mode=mode)
    else:
        raise ValueError("Invalid 'mode' given: {}".format(mode))
    try:
        yield opened_file
    finally:
        opened_file.close()
    if mode == "w":
        os.rename(temp_filename, filename)


@contextlib.contextmanager
def create_named_temporary_file(suffix=None):
    file_handle, filename = tempfile.mkstemp(suffix=".dxf")
    os.close(file_handle)
    try:
        yield filename
    finally:
        if os.path.isfile(filename):
            try:
                os.remove(filename)
            except OSError as exc:
                log.warn("Failed to remove temporary file (%s): %s", filename, exc)
