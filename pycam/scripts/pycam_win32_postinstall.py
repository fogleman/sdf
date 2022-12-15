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

import distutils.sysconfig
import os
import sys

try:
    logfile = os.path.join(distutils.sysconfig.PREFIX, "pycam-wininst-postinstall.log", "a")
except OSError:
    logfile = None
if logfile:
    sys.stdout = logfile
    sys.stderr = logfile

# There are some additional builtin functions available in the context of this script:
#   https://docs.python.org/3/distutils/builtdist.html#the-postinstallation-script
# We use the following functions:
#   create_shortcut
#   directory_created
#   file_created
#   get_special_folder_path

LINK_EXTENSION = ".lnk"

try:
    START_MENU_BASEDIR = get_special_folder_path("CSIDL_COMMON_PROGRAMS")
except OSError:
    START_MENU_BASEDIR = get_special_folder_path("CSIDL_PROGRAMS")  # noqa: F821
except NameError:
    START_MENU_BASEDIR = "C:\\"
START_MENU_SUBDIR = os.path.join(START_MENU_BASEDIR, "PyCAM")

# create a start menu item for pycam
PYTHON_EXE = os.path.join(distutils.sysconfig.EXEC_PREFIX, "pythonw.exe")
# surround the start script with quotes to avoid space-issues
START_SCRIPT = '"%s"' % os.path.join(distutils.sysconfig.EXEC_PREFIX, "Scripts", "pycam-loader.py")

SHARE_DIR = os.path.join(distutils.sysconfig.PREFIX, "share", "pycam")

PYTHON_DOC_DIR = os.path.join(SHARE_DIR, "doc")

ICON_FILE = os.path.join(SHARE_DIR, "pycam.ico")

# add some more doc files
DOC_FILES = [("LICENSE.TXT", "License")]
WEB_LINKS = [
    (r"http://pycam.sourceforge.net/", "Project's Website"),
    (r"http://sourceforge.net/tracker/?group_id=237831&atid=1104176", "Report a Bug"),
    (r"http://sourceforge.net/projects/pycam/forums", "Forum Discussions"),
    (r"http://sourceforge.net/apps/mediawiki/pycam/index.php?title=User_Manual", "User Manual")]

MENU_ITEMS = map(lambda v: (os.path.join(PYTHON_DOC_DIR, v[0]), v[1]), DOC_FILES)
MENU_ITEMS.extend(WEB_LINKS)

action = sys.argv[1]


if action == "-install":
    if not os.path.exists(START_MENU_SUBDIR):
        os.mkdir(START_MENU_SUBDIR)
    directory_created(START_MENU_SUBDIR)  # noqa: F821
    for menu_item in MENU_ITEMS:
        target, description = menu_item
        filename = os.path.join(START_MENU_SUBDIR, description) + LINK_EXTENSION
        create_shortcut(target, description, filename)  # noqa: F821
        file_created(filename)  # noqa: F821
    filename = os.path.join(START_MENU_SUBDIR, "Run PyCAM") + LINK_EXTENSION
    create_shortcut(PYTHON_EXE, "Run PyCAM", filename, START_SCRIPT, "", ICON_FILE)  # noqa: F821
    file_created(filename)  # noqa: F821
elif action == "-remove":
    pass
else:
    pass
