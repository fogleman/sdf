"""
Copyright 2010-2011 Lars Kruse <devel@sumpfralle.de>
Copyright 2008-2009 Lode Leroy

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

import decimal
import os


DEFAULT_HEADER = ("G40 (disable tool radius compensation)",
                  "G49 (disable tool length compensation)",
                  "G80 (cancel modal motion)",
                  "G54 (select coordinate system 1)",
                  "G90 (disable incremental moves)")

MAX_DIGITS = 12


def _get_num_of_significant_digits(number):
    """ Determine the number of significant digits of a float number. """
    # use only positive numbers
    number = abs(number)
    max_diff = 0.1 ** MAX_DIGITS
    if number <= max_diff:
        # input value is smaller than the smallest usable number
        return MAX_DIGITS
    elif number >= 1:
        # no negative number of significant digits
        return 0
    else:
        for digit in range(1, MAX_DIGITS):
            shifted = number * (10 ** digit)
            if shifted - int(shifted) < max_diff:
                return digit
        return MAX_DIGITS


def _get_num_converter(step_width):
    """ Return a float-to-decimal conversion function with a prevision suitable
    for the given step width.
    """
    digits = _get_num_of_significant_digits(step_width)
    format_string = "%%.%df" % digits
    conv_func = lambda number: decimal.Decimal(format_string % number)
    return conv_func, format_string


class GCodeGenerator:

    NUM_OF_AXES = 3

    def __init__(self, destination, metric_units=True, safety_height=0.0,
                 toggle_spindle_status=False, spindle_delay=3, header=None, comment=None,
                 minimum_steps=None, touch_off_on_startup=False, touch_off_on_tool_change=False,
                 touch_off_position=None, touch_off_rapid_move=0, touch_off_slow_move=1,
                 touch_off_slow_feedrate=20, touch_off_height=0, touch_off_pause_execution=False):
        if hasattr(destination, "write"):
            # assume that "destination" is something like a StringIO instance
            # or an open file
            self.destination = destination
            # don't close the stream if we did not open it on our own
            self._close_stream_on_exit = False
        else:
            # open the file by its name
            self.destination = open(destination, "w")
            self._close_stream_on_exit = True
        self.safety_height = safety_height
        self.toggle_spindle_status = toggle_spindle_status
        self.spindle_delay = spindle_delay
        self.comment = comment
        # define all axes steps and the corresponding formatters
        self._axes_formatter = []
        if not minimum_steps:
            # default: minimum steps for all axes = 0.0001
            minimum_steps = [0.0001]
        for i in range(self.NUM_OF_AXES):
            if i < len(minimum_steps):
                step_width = minimum_steps[i]
            else:
                step_width = minimum_steps[-1]
            conv, format_string = _get_num_converter(step_width)
            self._axes_formatter.append((conv(step_width), conv, format_string))
        self._finished = False
        if comment:
            self.add_comment(comment)
        if header is None:
            self.append(DEFAULT_HEADER)
        else:
            self.append(header)
        if metric_units:
            self.append("G21 (metric)")
        else:
            self.append("G20 (imperial)")
        self.last_position = [None, None, None]
        self.last_rapid = None
        self.last_tool_id = None
        self.last_feedrate = 100
        if touch_off_on_startup or touch_off_on_tool_change:
            self.store_touch_off_position(touch_off_position)
        self.touch_off_on_startup = touch_off_on_startup
        self.touch_off_on_tool_change = touch_off_on_tool_change
        self.touch_off_rapid_move = touch_off_rapid_move
        self.touch_off_slow_move = touch_off_slow_move
        self.touch_off_slow_feedrate = touch_off_slow_feedrate
        self.touch_off_pause_execution = touch_off_pause_execution
        self.touch_off_height = touch_off_height
        self._on_startup = True

    def run_touch_off(self, new_tool_id=None, force_height=None):
        # either "new_tool_id" or "force_height" should be specified
        self.append("")
        self.append("(Start of touch off operation)")
        self.append("G90 (disable incremental moves)")
        self.append("G49 (disable tool offset compensation)")
        self.append("G53 G0 Z#5163 (go to touch off position: z)")
        self.append("G28 (go to final touch off position)")
        self.append("G91 (enter incremental mode)")
        self.append("F%f (reduce feed rate during touch off)" % self.touch_off_slow_feedrate)
        if self.touch_off_pause_execution:
            self.append("(msg,Pausing before tool change)")
            self.append("M0 (pause before touch off)")
        # measure the current tool length
        if self.touch_off_rapid_move > 0:
            self.append("G0 Z-%f (go down rapidly)" % self.touch_off_rapid_move)
        self.append("G38.2 Z-%f (do the touch off)" % self.touch_off_slow_move)
        if force_height is not None:
            self.append("G92 Z%f" % force_height)
        self.append("G28 (go up again)")
        if new_tool_id is not None:
            # compensate the length of the new tool
            self.append("#100=#5063 (store current tool length compensation)")
            self.append("T%d M6" % new_tool_id)
            if self.touch_off_rapid_move > 0:
                self.append("G0 Z-%f (go down rapidly)" % self.touch_off_rapid_move)
            self.append("G38.2 Z-%f (do the touch off)" % self.touch_off_slow_move)
            self.append("G28 (go up again)")
            # compensate the tool length difference
            self.append("G43.1 Z[#5063-#100] (compensate the new tool length)")
        self.append("F%f (restore feed rate)" % self.last_feedrate)
        self.append("G90 (disable incremental mode)")
        # Move up to a safe height. This is either "safety height" or the touch
        # off start location. The highest value of these two is used.
        if self.touch_off_on_startup and self.touch_off_height is not None:
            touch_off_safety_height = self.touch_off_height + \
                    self.touch_off_slow_move + self.touch_off_rapid_move
            final_height = max(touch_off_safety_height, self.safety_height)
            self.append("G0 Z%.3f" % final_height)
        else:
            # We assume, that the touch off start position is _above_ the
            # top of the material. This is documented.
            # A proper ("safer") implementation would compare "safety_height"
            # with the touch off start location. But this requires "O"-Codes
            # which are only usable for LinuxCNC (probably).
            self.append("G53 G0 Z#5163 (go to touch off position: z)")
        if self.touch_off_pause_execution:
            self.append("(msg,Pausing after tool change)")
            self.append("M0 (pause after touch off)")
        self.append("(End of touch off operation)")
        self.append("")

    def store_touch_off_position(self, position):
        if position is None:
            self.append("G28.1 (store current position for touch off)")
        else:
            self.append("#5161=%f (touch off position: x)" % position[0])
            self.append("#5162=%f (touch off position: y)" % position[1])
            self.append("#5163=%f (touch off position: z)" % position[2])

    def set_speed(self, feedrate=None, spindle_speed=None):
        if feedrate is not None:
            self.append("F%.5f" % feedrate)
            self.last_feedrate = feedrate
        if spindle_speed is not None:
            self.append("S%.5f" % spindle_speed)

    def set_path_mode(self, mode, motion_tolerance=None, naive_cam_tolerance=None):
        result = ""
        # TODO: implement real path modes (see CORNER_STYLE in pycam.Plugins.ToolpathExport)
        PATH_MODES = {"exact_path": None, "exact_stop": None, "continuous": None}
        if mode == PATH_MODES["exact_path"]:
            result = "G61 (exact path mode)"
        elif mode == PATH_MODES["exact_stop"]:
            result = "G61.1 (exact stop mode)"
        elif mode == PATH_MODES["continuous"]:
            if motion_tolerance is None:
                result = "G64 (continuous mode with maximum speed)"
            elif naive_cam_tolerance is None:
                result = "G64 P%f (continuous mode with tolerance)" % motion_tolerance
            else:
                result = ("G64 P%f Q%f (continuous mode with tolerance and cleanup)"
                          % (motion_tolerance, naive_cam_tolerance))
        else:
            raise ValueError("GCodeGenerator: invalid path mode (%s)" % str(mode))
        self.append(result)

    def add_moves(self, moves, tool_id=None, comment=None):
        if comment is not None:
            self.add_comment(comment)
        skip_safety_height_move = False
        if tool_id is not None:
            if self.last_tool_id == tool_id:
                # nothing to be done
                pass
            elif self.touch_off_on_tool_change and (self.last_tool_id is not None):
                self.run_touch_off(new_tool_id=tool_id)
                skip_safety_height_move = True
            else:
                self.append("T%d M6" % tool_id)
                if self._on_startup and self.touch_off_on_startup:
                    self.run_touch_off(force_height=self.touch_off_height)
                    skip_safety_height_move = True
                    self._on_startup = False
            self.last_tool_id = tool_id
        # move straight up to safety height
        if not skip_safety_height_move:
            self.add_move_to_safety()
        self.set_spindle_status(True)
        for pos, rapid in moves:
            self.add_move(pos, rapid=rapid)
        # go back to safety height
        self.add_move_to_safety()
        self.set_spindle_status(False)
        # make sure that all sections are independent of each other
        self.last_position = [None, None, None]
        self.last_rapid = None

    def set_spindle_status(self, status):
        if self.toggle_spindle_status:
            if status:
                self.append("M3 (start spindle)")
            else:
                self.append("M5 (stop spindle)")
            self.append("G04 P%d (wait for %d seconds)" % (self.spindle_delay, self.spindle_delay))

    def add_move_to_safety(self):
        new_pos = [None, None, self.safety_height]
        self.add_move(new_pos, rapid=True)

    def add_move(self, position, rapid=False):
        """ add the GCode for a machine move to 'position'. Use rapid (G0) or normal (G01) speed.

        @value position: the new position
        @type position: Point or list(float)
        @value rapid: is this a rapid move?
        @type rapid: bool
        """
        new_pos = []
        for index, attr in enumerate("xyz"):
            conv = self._axes_formatter[index][1]
            if hasattr(position, attr):
                value = getattr(position, attr)
            else:
                value = position[index]
            if value is None:
                new_pos.append(None)
            else:
                new_pos.append(conv(value))
        # check if there was a significant move
        no_diff = True
        for index, current_new_axis in enumerate(new_pos):
            if current_new_axis is None:
                continue
            if self.last_position[index] is None:
                no_diff = False
                break
            diff = abs(current_new_axis - self.last_position[index])
            if diff >= self._axes_formatter[index][0]:
                no_diff = False
                break
        if no_diff:
            # we can safely skip this move
            return
        # compose the position string
        pos_string = []
        for index, axis_spec in enumerate("XYZ"):
            if new_pos[index] is None:
                continue
            if not self.last_position or \
                    (new_pos[index] != self.last_position[index]):
                pos_string.append(axis_spec + self._axes_formatter[index][2] % new_pos[index])
                self.last_position[index] = new_pos[index]
        if rapid == self.last_rapid:
            prefix = ""
        elif rapid:
            prefix = "G0"
        else:
            prefix = "G1"
        self.last_rapid = rapid
        self.append("%s %s" % (prefix, " ".join(pos_string)))

    def finish(self):
        self.add_move_to_safety()
        self.append("M2 (end program)")
        self._finished = True

    def add_comment(self, comment):
        if hasattr(comment, "split"):
            lines = comment.split(os.linesep)
        else:
            lines = comment
        for line in lines:
            self.append(";%s" % line)

    def append(self, command):
        if self._finished:
            raise TypeError("GCodeGenerator: can't add further commands to a finished "
                            "GCodeGenerator instance: %s" % str(command))
        if hasattr(command, "split"):
            # single strings are turned into lists
            command = [command]
        for line in command:
            self.destination.write(line + os.linesep)
