#!/usr/bin/env python3
"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>
Copyright 2010 Arthur Magill

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

import glob
import os.path
from setuptools import setup, find_packages

from pycam import VERSION

BASE_DIR = os.path.realpath(os.path.abspath(os.path.dirname(__file__)))


setup(
    name="pycam",
    version=VERSION,
    license="GPL v3",
    description="Open Source CAM - Toolpath Generation for 3-Axis CNC machining",
    author="Lars Kruse",
    author_email="devel@sumpfralle.de",
    provides=["pycam"],
    requires=["PyOpenGL", "PyYAML"],
    url="http://pycam.sourceforge.net/",
    download_url="http://sourceforge.net/projects/pycam/files",
    keywords=["3-axis", "cnc", "cam", "toolpath", "machining", "g-code"],
    long_description="""IMPORTANT NOTE: Please read the list of requirements:
http://pycam.sourceforge.net/requirements
Basically you will need Python3, GTK and OpenGL.

Windows: select Python 3.X in the following dialog.
""",
    # full list of classifiers at:
    #   http://pypi.python.org/pypi?:action=list_classifiers
    classifiers=[
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Development Status :: 4 - Beta",
        "License :: OSI Approved :: GNU General Public License (GPL)",
        "Topic :: Scientific/Engineering",
        "Environment :: Win32 (MS Windows)",
        "Environment :: X11 Applications :: GTK",
        "Intended Audience :: Manufacturing",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: POSIX",
    ],
    packages=find_packages(exclude=["pycam.Test"]),
    entry_points={
        "gui_scripts": [
            "pycam = pycam.run_gui:main_func",
        ],
        "console_scripts": [
            "pycam-cli = pycam.run_cli:main_func",
        ],
    },
    data_files=[
        ("share/pycam/doc", ["COPYING.TXT",
                             "INSTALL.md",
                             "LICENSE.TXT",
                             "README.md",
                             "Changelog",
                             "release_info.txt"]),
        ("share/pycam/ui", glob.glob(os.path.join("share", "ui", "*"))),
        ("share/pycam/fonts", glob.glob(os.path.join("share", "fonts", "*"))),
        ("share/pycam", [os.path.join("share", "pycam.ico"),
                         os.path.join("share", "misc", "DXF.gpl")]),
        ("share/pycam/samples", glob.glob(os.path.join("samples", "*"))),
    ],
)

# vim: tabstop=4 expandtab shiftwidth=4 softtabstop=4
