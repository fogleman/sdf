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

import collections

from pycam.Toolpath import MOVE_STRAIGHT, MOVE_STRAIGHT_RAPID, MOVE_ARC, MOVE_SAFETY, \
        MACHINE_SETTING, COMMENT


def get_step_class_by_action(action):
    return {
        MOVE_STRAIGHT: MoveStraight,
        MOVE_STRAIGHT_RAPID: MoveStraightRapid,
        MOVE_ARC: MoveArc,
        MOVE_SAFETY: MoveSafety,
        MACHINE_SETTING: MachineSetting,
        COMMENT: Comment,
    }[action]


MoveClass = collections.namedtuple("Move", ("action", "position"))
MachineSettingClass = collections.namedtuple("MachineSetting", ("action", "key", "value"))
CommentClass = collections.namedtuple("Comment", ("action", "text"))


MoveStraight = lambda position: MoveClass(MOVE_STRAIGHT, position)
MoveStraightRapid = lambda position: MoveClass(MOVE_STRAIGHT_RAPID, position)
MoveArc = lambda position: MoveClass(MOVE_ARC, position)
MoveSafety = lambda: MoveClass(MOVE_SAFETY, None)
MachineSetting = lambda key, value: MachineSettingClass(MACHINE_SETTING, key, value)
Comment = lambda text: CommentClass(COMMENT, text)
