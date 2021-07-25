#!/usr/bin/env python3
"""

Copyright 2017 Lars Kruse <devel@sumpfralle.de>

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

import argparse
import logging
import os
import sys

try:
    from pycam import VERSION
except ImportError:
    # running locally (without a proper PYTHONPATH) requires manual intervention
    sys.path.insert(0, os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)),
                                                     os.pardir)))
    from pycam import VERSION

import pycam.errors
from pycam.Flow.parser import parse_yaml
import pycam.Utils
import pycam.Utils.log
import pycam.workspace.data_models


_log = pycam.Utils.log.get_logger()

LOG_LEVELS = {"debug": logging.DEBUG,
              "info": logging.INFO,
              "warning": logging.WARNING,
              "error": logging.ERROR, }


def get_args():
    parser = argparse.ArgumentParser(prog="PyCAM", description="scriptable PyCAM processing flow",
                                     epilog="PyCAM website: https://github.com/SebKuzminsky/pycam")
    parser.add_argument("--log-level", choices=LOG_LEVELS.keys(), default="warning",
                        help="choose the verbosity of log messages")
    parser.add_argument("sources", metavar="FLOW_SPEC", type=argparse.FileType('r'), nargs="+",
                        help="processing flow description files in yaml format")
    parser.add_argument("--version", action="version", version="%(prog)s {}".format(VERSION))
    return parser.parse_args()


def main_func():
    args = get_args()
    _log.setLevel(LOG_LEVELS[args.log_level])
    for fname in args.sources:
        try:
            parse_yaml(fname)
        except pycam.errors.PycamBaseException as exc:
            print("Flow description parse failure ({}): {}".format(fname, exc), file=sys.stderr)
            sys.exit(1)
    pycam.Utils.set_application_key("pycam-cli")
    for export in pycam.workspace.data_models.Export.get_collection():
        export.run_export()


if __name__ == "__main__":
    main_func()
