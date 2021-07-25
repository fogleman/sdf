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

import pycam.Utils.log
import pycam.Toolpath.Filters
from pycam.Toolpath import MOVE_STRAIGHT_RAPID, MACHINE_SETTING, COMMENT, MOVES_LIST

_log = pycam.Utils.log.get_logger()


class BaseGenerator:

    def __init__(self, destination, comment=None):
        if hasattr(destination, "write"):
            # assume that "destination" is something like a StringIO instance or an open file
            self.destination = destination
            # don't close the stream if we did not open it on our own
            self._close_stream_on_exit = False
        else:
            # open the file
            self.destination = open(destination, "w")
            self._close_stream_on_exit = True
        self._filters = []
        self._cache = {}
        # add a comment at the top of the file, if requested
        if comment:
            self.add_comment(comment)
        self.add_header()

    def _get_cache(self, key, default_value):
        return self._cache.get(key, default_value)

    def add_filters(self, filters):
        self._filters.extend(filters)
        self._filters.sort()

    def add_comment(self, comment):
        raise NotImplementedError("someone forgot to implement 'add_comment'")

    def add_command(self, command, comment=None):
        raise NotImplementedError("someone forgot to implement 'add_command'")

    def add_move(self, coordinates, is_rapid=False):
        raise NotImplementedError("someone forgot to implement 'add_move'")

    def add_footer(self):
        raise NotImplementedError("someone forgot to implement 'add_footer'")

    def finish(self):
        self.add_footer()
        if self._close_stream_on_exit:
            self.destination.close()

    def add_moves(self, moves, filters=None):
        # combine both lists/tuples in a type-agnostic way
        all_filters = list(self._filters)
        if filters:
            all_filters.extend(filters)
        filtered_moves = pycam.Toolpath.Filters.get_filtered_moves(moves, all_filters)
        for step in filtered_moves:
            if step.action in MOVES_LIST:
                is_rapid = step.action == MOVE_STRAIGHT_RAPID
                self.add_move(step.position, is_rapid)
                self._cache["position"] = step.position
                self._cache["rapid_move"] = is_rapid
            elif step.action == COMMENT:
                self.add_comment(step.text)
            elif step.action == MACHINE_SETTING:
                func_name = "command_%s" % step.key
                if hasattr(self, func_name):
                    _log.debug("GCode: machine setting '%s': %s", step.key, step.value)
                    getattr(self, func_name)(step.value)
                    self._cache[step.key] = step.value
                    self._cache["rapid_move"] = None
                else:
                    _log.warn("The current GCode exporter does not support the machine setting "
                              "'%s=%s' -> ignore", step.key, step.value)
            else:
                _log.warn("A non-basic toolpath item (%s) remained in the queue -> ignore", step)
