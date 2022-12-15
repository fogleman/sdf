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


import collections
import decimal

from pycam.Geometry import epsilon
from pycam.Geometry.Line import Line
from pycam.Geometry.PointUtils import padd, psub, pmul, pdist, pnear, ptransform_by_matrix
from pycam.Toolpath import MOVE_SAFETY, MOVES_LIST, MACHINE_SETTING
import pycam.Toolpath.Steps as ToolpathSteps
import pycam.Utils.log


MAX_DIGITS = 12

_log = pycam.Utils.log.get_logger()


""" Toolpath filters are used for applying parameters to generic toolpaths.
"""


def toolpath_filter(our_category, key):
    """ decorator for toolpath filter functions
    e.g. see pycam.Plugins.ToolTypes
    """
    def toolpath_filter_inner(func):
        def get_filter_func(self, category, parameters, previous_filters):
            if (category == our_category):
                if isinstance(key, (list, tuple, set)) and any([(k in parameters) for k in key]):
                    # "key" is a list and at least one parameter is found
                    arg_dict = {}
                    for one_key in key:
                        if one_key in parameters:
                            arg_dict[one_key] = parameters[one_key]
                    result = func(self, **arg_dict)
                elif key in parameters:
                    result = func(self, parameters[key])
                else:
                    # no match found - ignore
                    result = None
                if result:
                    previous_filters.extend(result)
        return get_filter_func
    return toolpath_filter_inner


def get_filtered_moves(moves, filters):
    filters = list(filters)
    moves = list(moves)
    filters.sort()
    for one_filter in filters:
        moves |= one_filter
    return moves


class BaseFilter:

    PARAMS = []
    WEIGHT = 50

    def __init__(self, *args, **kwargs):
        # we want to achieve a stable order in order to be hashable
        self.settings = collections.OrderedDict(kwargs)
        # fail if too many arguments (without names) are given
        if len(args) > len(self.PARAMS):
            raise ValueError("Too many parameters: %d (expected: %d)"
                             % (len(args), len(self.PARAMS)))
        # fail if too few arguments (without names) are given
        for index, key in enumerate(self.PARAMS):
            if len(args) > index:
                self.settings[key] = args[index]
            elif key in self.settings:
                # named parameter are ok, as well
                pass
            else:
                raise ValueError("Missing parameter: %s" % str(key))

    def clone(self):
        return self.__class__(**self.settings)

    def __hash__(self):
        return hash((str(self.__class__), tuple(self.settings.items())))

    def __ror__(self, toolpath):
        # allow to use pycam.Toolpath.Toolpath instances (instead of a list)
        if hasattr(toolpath, "path") and hasattr(toolpath, "filters"):
            toolpath = toolpath.path
        # use a copy of the list -> changes will be permitted
        _log.debug("Applying toolpath filter: %s", self.__class__)
        return self.filter_toolpath(list(toolpath))

    def __repr__(self):
        class_name = str(self.__class__).split("'")[1].split(".")[-1]
        return "%s(%s)" % (class_name, self._render_settings())

    # comparison functions: they allow to use "filters.sort()"
    __eq__ = lambda self, other: self.WEIGHT == other.WEIGHT
    __ne__ = lambda self, other: self.WEIGHT != other.WEIGHT
    __lt__ = lambda self, other: self.WEIGHT < other.WEIGHT
    __le__ = lambda self, other: self.WEIGHT <= other.WEIGHT
    __gt__ = lambda self, other: self.WEIGHT > other.WEIGHT
    __ge__ = lambda self, other: self.WEIGHT >= other.WEIGHT

    def _render_settings(self):
        return ", ".join(["%s=%s" % (key, self.settings[key]) for key in self.settings])

    def filter_toolpath(self, toolpath):
        raise NotImplementedError(("The filter class %s failed to implement the 'filter_toolpath' "
                                   "method") % str(type(self)))


class SafetyHeight(BaseFilter):

    PARAMS = ("safety_height", )
    WEIGHT = 80

    def filter_toolpath(self, toolpath):
        last_pos = None
        max_height = None
        new_path = []
        safety_pending = False
        get_safe = lambda pos: tuple((pos[0], pos[1], self.settings["safety_height"]))
        for step in toolpath:
            if step.action == MOVE_SAFETY:
                safety_pending = True
            elif step.action in MOVES_LIST:
                new_pos = tuple(step.position)
                if (max_height is None) or (new_pos[2] > max_height):
                    max_height = new_pos[2]
                if not last_pos:
                    # there was a safety move (or no move at all) before
                    # -> move sideways
                    new_path.append(ToolpathSteps.MoveStraightRapid(get_safe(new_pos)))
                elif safety_pending:
                    safety_pending = False
                    if pnear(last_pos, new_pos, axes=(0, 1)):
                        # same x/y position - skip safety move
                        pass
                    else:
                        # go up, sideways and down
                        new_path.append(ToolpathSteps.MoveStraightRapid(get_safe(last_pos)))
                        new_path.append(ToolpathSteps.MoveStraightRapid(get_safe(new_pos)))
                else:
                    # we are in the middle of usual moves -> keep going
                    pass
                new_path.append(step)
                last_pos = new_pos
            else:
                # unknown move -> keep it
                new_path.append(step)
        # process pending safety moves
        if safety_pending and last_pos:
            new_path.append(ToolpathSteps.MoveStraightRapid(get_safe(last_pos)))
        if max_height > self.settings["safety_height"]:
            _log.warn("Toolpath exceeds safety height: %f => %f",
                      max_height, self.settings["safety_height"])
        return new_path


class MachineSetting(BaseFilter):

    PARAMS = ("key", "value")
    WEIGHT = 20

    def filter_toolpath(self, toolpath):
        result = []
        # move all previous machine settings
        while toolpath and toolpath[0].action == MACHINE_SETTING:
            result.append(toolpath.pop(0))
        # add the new setting
        for key, value in self._get_settings():
            result.append(ToolpathSteps.MachineSetting(key, value))
        return result + toolpath

    def _get_settings(self):
        return [(self.settings["key"], self.settings["value"])]

    def _render_settings(self):
        return "%s=%s" % (self.settings["key"], self.settings["value"])


class CornerStyle(MachineSetting):

    PARAMS = ("path_mode", "motion_tolerance", "naive_tolerance")
    WEIGHT = 25

    def _get_settings(self):
        return [("corner_style",
                 (self.settings["path_mode"], self.settings["motion_tolerance"],
                  self.settings["naive_tolerance"]))]

    def _render_settings(self):
        return "%s / %d / %d" % (self.settings["path_mode"],
                                 self.settings["motion_tolerance"],
                                 self.settings["naive_tolerance"])


class SelectTool(BaseFilter):

    PARAMS = ("tool_id", )
    WEIGHT = 35

    def filter_toolpath(self, toolpath):
        index = 0
        # skip all non-moves
        while (index < len(toolpath)) and (toolpath[index][0] not in MOVES_LIST):
            index += 1
        toolpath.insert(index, ToolpathSteps.MachineSetting("select_tool",
                                                            self.settings["tool_id"]))
        return toolpath


class TriggerSpindle(BaseFilter):
    """ control the spindle spin for each tool selection

    A spin-up command is added after each tool selection.
    A spin-down command is added before each tool selection and after the last move.
    If no tool selection is found, then single spin-up and spin-down commands are added before the
    first move and after the last move.
    """

    PARAMS = ("delay", )
    WEIGHT = 36

    def filter_toolpath(self, toolpath):
        def spin_up(path, index):
            path.insert(index, ToolpathSteps.MachineSetting("spindle_enabled", True))
            if self.settings["delay"]:
                path.insert(index + 1, ToolpathSteps.MachineSetting("delay",
                                                                    self.settings["delay"]))

        def spin_down(path, index):
            path.insert(index, ToolpathSteps.MachineSetting("spindle_enabled", False))

        # find all positions of "select_tool"
        tool_changes = [index for index, step in enumerate(toolpath)
                        if (step.action == MACHINE_SETTING) and (step.key == "select_tool")]
        if tool_changes:
            tool_changes.reverse()
            for index in tool_changes:
                spin_up(toolpath, index + 1)
                if index > 0:
                    # add a "disable"
                    spin_down(toolpath, index)
        else:
            # add a single spin-up before the first move
            for index, step in enumerate(toolpath):
                if step.action in MOVES_LIST:
                    spin_up(toolpath, index)
                    break
        # add "stop spindle" just after the last move
        index = len(toolpath) - 1
        while (toolpath[index].action not in MOVES_LIST) and (index > 0):
            index -= 1
        if toolpath[index].action in MOVES_LIST:
            spin_down(toolpath, index + 1)
        return toolpath


class SpindleSpeed(BaseFilter):
    """ add a spindle speed command after each tool selection

    If no tool selection is found, then a single spindle speed command is inserted before the first
    move.
    """

    PARAMS = ("speed", )
    WEIGHT = 37

    def filter_toolpath(self, toolpath):
        def set_speed(path, index):
            path.insert(index, ToolpathSteps.MachineSetting("spindle_speed",
                                                            self.settings["speed"]))

        # find all positions of "select_tool"
        tool_changes = [index for index, step in enumerate(toolpath)
                        if (step.action == MACHINE_SETTING) and (step.key == "select_tool")]
        if tool_changes:
            tool_changes.reverse()
            for index in tool_changes:
                set_speed(toolpath, index + 1)
        else:
            # no tool selections: add a single spindle speed command before the first move
            for index, step in enumerate(toolpath):
                if step.action in MOVES_LIST:
                    set_speed(toolpath, index)
                    break
        return toolpath


class PlungeFeedrate(BaseFilter):

    PARAMS = ("plunge_feedrate", )
    # must be greater than the weight of the SafetyHeight filter
    WEIGHT = 82

    def filter_toolpath(self, toolpath):
        new_path = []
        last_pos = None
        original_feedrate = None
        current_feedrate = None
        for step in toolpath:
            if (step.action == MACHINE_SETTING) and (step.key == "feedrate"):
                # store the current feedrate
                original_feedrate = step.value
                current_feedrate = step.value
            elif step.action in MOVES_LIST:
                # track the current position and adjust the feedrate if necessary
                if last_pos is not None and (step.position[2] < last_pos[2]):
                    # we are moving downwards
                    vertical_move = last_pos[2] - step.position[2]
                    # the ratio is 1.0 for a straight vertical move - otherwise between 0 and 1
                    vertical_ratio = vertical_move / pdist(last_pos, step.position)
                    max_feedrate = self.settings["plunge_feedrate"] / vertical_ratio
                    # never exceed the original feedrate
                    max_feedrate = min(original_feedrate, max_feedrate)
                    if current_feedrate != max_feedrate:
                        # we are too slow or too fast
                        new_path.append(ToolpathSteps.MachineSetting("feedrate", max_feedrate))
                        current_feedrate = max_feedrate
                else:
                    # we do not move down
                    if current_feedrate != original_feedrate:
                        # switch back to the maximum feedrate
                        new_path.append(ToolpathSteps.MachineSetting("feedrate",
                                                                     original_feedrate))
                        current_feedrate = original_feedrate
                last_pos = step.position
            else:
                pass
            new_path.append(step)
        return new_path


class Crop(BaseFilter):

    PARAMS = ("polygons", )
    WEIGHT = 90

    def filter_toolpath(self, toolpath):
        new_path = []
        last_pos = None
        optional_moves = []
        for step in toolpath:
            if step.action in MOVES_LIST:
                if last_pos:
                    # find all remaining pieces of this line
                    inner_lines = []
                    for polygon in self.settings["polygons"]:
                        inner, outer = polygon.split_line(Line(last_pos, step.position))
                        inner_lines.extend(inner)
                    # turn these lines into moves
                    for line in inner_lines:
                        if pdist(line.p1, last_pos) > epsilon:
                            new_path.append(ToolpathSteps.MoveSafety())
                            new_path.append(
                                ToolpathSteps.get_step_class_by_action(step.action)(line.p1))
                        else:
                            # we continue where we left
                            if optional_moves:
                                new_path.extend(optional_moves)
                                optional_moves = []
                        new_path.append(
                            ToolpathSteps.get_step_class_by_action(step.action)(line.p2))
                        last_pos = line.p2
                    optional_moves = []
                    # finish the line by moving to its end (if necessary)
                    if pdist(last_pos, step.position) > epsilon:
                        optional_moves.append(ToolpathSteps.MoveSafety())
                        optional_moves.append(step)
                last_pos = step.position
            elif step.action == MOVE_SAFETY:
                optional_moves = []
            else:
                new_path.append(step)
        return new_path


class TransformPosition(BaseFilter):
    """ shift or rotate a toolpath based on a given 3x3 or 3x4 matrix
    """

    PARAMS = ("matrix", )
    WEIGHT = 85

    def filter_toolpath(self, toolpath):
        new_path = []
        for step in toolpath:
            if step.action in MOVES_LIST:
                new_pos = ptransform_by_matrix(step.position, self.settings["matrix"])
                new_path.append(ToolpathSteps.get_step_class_by_action(step.action)(new_pos))
            else:
                new_path.append(step)
        return new_path


class TimeLimit(BaseFilter):
    """ This filter is used for the toolpath simulation. It returns only a partial toolpath within
    a given duration limit.
    """

    PARAMS = ("timelimit", )
    WEIGHT = 100

    def filter_toolpath(self, toolpath):
        feedrate = min_feedrate = 1
        new_path = []
        last_pos = None
        limit = self.settings["timelimit"]
        duration = 0
        for step in toolpath:
            if step.action in MOVES_LIST:
                if last_pos:
                    new_distance = pdist(step.position, last_pos)
                    new_duration = new_distance / max(feedrate, min_feedrate)
                    if (new_duration > 0) and (duration + new_duration > limit):
                        partial = (limit - duration) / new_duration
                        destination = padd(last_pos, pmul(psub(step.position, last_pos), partial))
                        duration = limit
                    else:
                        destination = step.position
                        duration += new_duration
                else:
                    destination = step.position
                new_path.append(ToolpathSteps.get_step_class_by_action(step.action)(destination))
                last_pos = step.position
            if (step.action == MACHINE_SETTING) and (step.key == "feedrate"):
                feedrate = step.value
            if duration >= limit:
                break
        return new_path


class MovesOnly(BaseFilter):
    """ Use this filter for checking if a given toolpath is empty/useless
    (only machine settings, safety moves, ...).
    """

    WEIGHT = 95

    def filter_toolpath(self, toolpath):
        return [step for step in toolpath if step.action in MOVES_LIST]


class Copy(BaseFilter):

    WEIGHT = 100

    def filter_toolpath(self, toolpath):
        return list(toolpath)


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


class StepWidth(BaseFilter):

    PARAMS = ("step_width", )
    NUM_OF_AXES = 3
    WEIGHT = 60

    def filter_toolpath(self, toolpath):
        minimum_steps = []
        conv = []
        for key in "xyz":
            minimum_steps.append(self.settings["step_width"][key])
        for step_width in minimum_steps:
            conv.append(_get_num_converter(step_width)[0])
        last_pos = None
        path = []
        for step in toolpath:
            if step.action in MOVES_LIST:
                if last_pos:
                    real_target_position = []
                    diff = [(abs(a_conv(a_last_pos) - a_conv(a_pos)))
                            for a_conv, a_last_pos, a_pos in zip(conv, last_pos, step.position)]
                    position_changed = False
                    # For every axis: if the new position is closer than the defined step width,
                    # then stay at the previous position.
                    # see https://sf.net/p/pycam/discussion/860184/thread/930b1c7f/
                    for axis_distance, min_distance, axis_last, axis_wanted in zip(
                            diff, minimum_steps, last_pos, step.position):
                        if axis_distance >= min_distance:
                            real_target_position.append(axis_wanted)
                            position_changed = True
                        else:
                            real_target_position.append(axis_last)
                    if not position_changed:
                        # The limitation was not exceeded for any axis.
                        continue
                else:
                    real_target_position = step.position
                # TODO: this would also change the GCode output - we want
                # this, but it sadly breaks other code pieces that rely on
                # floats instead of decimals at this point. The output
                # conversion needs to move into the GCode output hook.
#               destination = [a_conv(a_pos) for a_conv, a_pos in zip(conv, step.position)]
                destination = real_target_position
                path.append(ToolpathSteps.get_step_class_by_action(step.action)(destination))
                # We store the real machine position (instead of the "wanted" position).
                last_pos = real_target_position
            else:
                # forget "last_pos" - we don't know what happened in between
                last_pos = None
                path.append(step)
        return path
