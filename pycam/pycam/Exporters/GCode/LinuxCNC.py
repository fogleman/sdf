"""
Copyright 2012 Lars Kruse <devel@sumpfralle.de>

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
import pycam.Exporters.GCode
from pycam.Toolpath import ToolpathPathMode
from pycam.workspace import LengthUnit


DEFAULT_HEADER = (("G40", "disable tool radius compensation"),
                  ("G49", "disable tool length compensation"),
                  ("G80", "cancel modal motion"),
                  ("G54", "select coordinate system 1"),
                  ("G90", "disable incremental moves"))

DEFAULT_DIGITS = 6


def _render_number(number):
    if int(number) == number:
        return "%d" % number
    else:
        return ("%%.%df" % DEFAULT_DIGITS) % number


class LinuxCNC(pycam.Exporters.GCode.BaseGenerator):

    def add_header(self):
        for command, comment in DEFAULT_HEADER:
            self.add_command(command, comment=comment)

    def add_footer(self):
        self.add_command("M2", "end program")

    def add_comment(self, comment):
        self.add_command("; %s" % comment)

    def add_command(self, command, comment=None):
        self.destination.write(command)
        if comment:
            self.destination.write("\t")
            self.add_comment(comment)
        else:
            self.destination.write(os.linesep)

    def add_move(self, coordinates, is_rapid=False):
        components = []
        # the cached value may be:
        #   True: the last move was G0
        #   False: the last move was G1
        #   None: some non-move happened before
        if self._get_cache("rapid_move", None) != is_rapid:
            components.append("G0" if is_rapid else "G1")
        else:
            # improve gcode style
            components.append(" ")
        axes = [axis for axis in "XYZABCUVW"]
        previous = self._get_cache("position", [None] * len(coordinates))
        for (axis, value, last) in zip(axes, coordinates, previous):
            if (last is None) or (last != value):
                components.append("%s%.6f" % (axis, value))
        command = " ".join(components)
        if command.strip():
            self.add_command(command)

    def command_feedrate(self, feedrate):
        self.add_command("F%s" % _render_number(feedrate), "set feedrate")

    def command_select_tool(self, tool_id):
        self.add_command("T%d M6" % tool_id, "select tool")

    def command_spindle_speed(self, speed):
        self.add_command("S%s" % _render_number(speed), "set spindle speed")

    def command_spindle_enabled(self, state):
        if state:
            self.add_command("M3", "start spindle")
        else:
            self.add_command("M5", "stop spindle")

    def command_delay(self, seconds):
        # "seconds" may be floats or integers
        self.add_command("G04 P{}".format(seconds), "wait for {} seconds".format(seconds))

    def command_unit(self, unit):
        if unit == LengthUnit.METRIC_MM:
            self.add_command("G21", "metric")
        elif unit == LengthUnit.IMPERIAL_INCH:
            self.add_command("G20", "imperial")
        else:
            assert False, "Invalid unit requested: {}".format(unit)

    def command_corner_style(self, extra_args):
        path_mode, motion_tolerance, naive_tolerance = extra_args
        if path_mode == ToolpathPathMode.CORNER_STYLE_EXACT_PATH:
            self.add_command("G61", "exact path mode")
        elif path_mode == ToolpathPathMode.CORNER_STYLE_EXACT_STOP:
            self.add_command("G61.1", "exact stop mode")
        elif path_mode == ToolpathPathMode.CORNER_STYLE_OPTIMIZE_SPEED:
            self.add_command("G64", "continuous mode with maximum speed")
        elif path_mode == ToolpathPathMode.CORNER_STYLE_OPTIMIZE_TOLERANCE:
            if not naive_tolerance:
                self.add_command("G64 P%f" % motion_tolerance, "continuous mode with tolerance")
            else:
                self.add_command("G64 P%f Q%f" % (motion_tolerance, naive_tolerance),
                                 "continuous mode with tolerance and cleanup")
        else:
            assert False, "Invalid corner style requested: {}".format(path_mode)
