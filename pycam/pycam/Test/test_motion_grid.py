"""
Copyright 2018 Lars Kruse <devel@sumpfralle.de>

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

import unittest

from pycam.Geometry import Box3D, Point3D
from pycam.Toolpath.MotionGrid import (
    GridDirection, MillingStyle, StartPosition, get_fixed_grid, get_fixed_grid_layer,
    get_fixed_grid_line, get_spiral_layer, get_spiral_layer_lines)


def _resolve_nested(level_count, source):
    """ resolve multiple levels of generators """
    assert level_count > 0
    if level_count > 1:
        return [_resolve_nested(level_count - 1, item) for item in source]
    else:
        return list(source)


class TestMotionGrid(unittest.TestCase):

    def assert_almost_equal_line(self, line1, line2):
        self.assertEqual(len(line1), len(line2))
        for pos1, pos2 in zip(line1, line2):
            self.assert_almost_equal_positions(pos1, pos2)

    def assert_almost_equal_lines(self, lines1, lines2):
        self.assertEqual(len(lines1), len(lines2))
        for line1, line2 in zip(lines1, lines2):
            self.assert_almost_equal_line(line1, line2)

    def assert_almost_equal_positions(self, pos1, pos2):
        self.assertEqual(len(pos1), 3)
        self.assertEqual(len(pos2), 3)
        for v1, v2 in zip(pos1, pos2):
            self.assertAlmostEqual(v1, v2)

    def assert_almost_equal_layer(self, layer1, layer2):
        self.assertEqual(len(layer1), len(layer2))
        for line1, line2 in zip(layer1, layer2):
            self.assert_almost_equal_line(line1, line2)

    def assert_almost_equal_grid(self, grid1, grid2):
        self.assertEqual(len(grid1), len(grid2))
        for layer1, layer2 in zip(grid1, grid2):
            self.assert_almost_equal_layer(layer1, layer2)

    def test_fixed_grid_line(self):
        for z in (-1, 0, 1):
            # simple line without steps
            line = _resolve_nested(
                1, get_fixed_grid_line(-2, 2, 3, z, grid_direction=GridDirection.X))
            self.assert_almost_equal_line(line, [(-2, 3, z), (2, 3, z)])
            # simple line with steps
            line = _resolve_nested(
                1, get_fixed_grid_line(-2, 2, 3, z, step_width=0.9,
                                       grid_direction=GridDirection.X))
            self.assert_almost_equal_line(line, [(-2, 3, z), (-1.2, 3, z), (-0.4, 3, z),
                                                 (0.4, 3, z), (1.2, 3, z), (2.0, 3, z)])
            # simple line in Y direction
            line = _resolve_nested(
                1, get_fixed_grid_line(0, 2, 3, z, grid_direction=GridDirection.Y))
            self.assert_almost_equal_line(line, [(3, 0, z), (3, 2, z)])

    def test_fixed_grid_layer(self):
        for z in (-1, 0, 1):
            # simple zigzag moves
            layer, end_position = get_fixed_grid_layer(
                0, 2, 0, 1, z, line_distance=1, grid_direction=GridDirection.X,
                milling_style=MillingStyle.IGNORE, start_position=StartPosition.NONE)
            layer = _resolve_nested(2, layer)
            self.assert_almost_equal_layer(layer, (
                ((0, 0, z), (2, 0, z)), ((2, 0, z), (2, 1, z)), ((2, 1, z), (0, 1, z))))
            self.assertEqual(end_position, StartPosition.Y)
            # always move along X in positive direction
            layer, end_position = get_fixed_grid_layer(
                0, 2, 0, 1, z, line_distance=1, grid_direction=GridDirection.X,
                milling_style=MillingStyle.CONVENTIONAL, start_position=StartPosition.NONE)
            layer = _resolve_nested(2, layer)
            self.assert_almost_equal_layer(layer, (
                ((0, 0, z), (2, 0, z)), ((0, 1, z), (2, 1, z))))
            self.assertEqual(end_position, StartPosition.X | StartPosition.Y)
            # always move along X in negative direction
            layer, end_position = get_fixed_grid_layer(
                0, 2, 0, 1, z, line_distance=1, grid_direction=GridDirection.X,
                milling_style=MillingStyle.CLIMB, start_position=StartPosition.NONE)
            layer = _resolve_nested(2, layer)
            self.assert_almost_equal_layer(layer, (
                ((0, 1, z), (2, 1, z)), ((0, 0, z), (2, 0, z))))
            self.assertEqual(end_position, StartPosition.X)
            # always move along Y in negative direction
            layer, end_position = get_fixed_grid_layer(
                0, 2, 0, 1, z, line_distance=1, grid_direction=GridDirection.Y,
                milling_style=MillingStyle.CONVENTIONAL, start_position=StartPosition.NONE)
            layer = _resolve_nested(2, layer)
            self.assert_almost_equal_layer(layer, (
                ((0, 1, z), (0, 0, z)), ((1, 1, z), (1, 0, z)), ((2, 1, z), (2, 0, z))))
            self.assertEqual(end_position, StartPosition.X)
            # always move along X in positive direction, starting from positive Y
            layer, end_position = get_fixed_grid_layer(
                0, 2, 0, 1, z, line_distance=1, grid_direction=GridDirection.X,
                milling_style=MillingStyle.CLIMB, start_position=StartPosition.Y)
            layer = _resolve_nested(2, layer)
            self.assert_almost_equal_layer(layer, (
                ((0, 1, z), (2, 1, z)), ((0, 0, z), (2, 0, z))))
            self.assertEqual(end_position, StartPosition.X)

    def test_fixed_grid(self):
        box = Box3D(Point3D(-3, -2, -1), Point3D(3, 2, 1))
        grid = _resolve_nested(3, get_fixed_grid(
            box, 1.2, line_distance=2.0, step_width=None,
            grid_direction=GridDirection.X, milling_style=MillingStyle.CONVENTIONAL,
            start_position=StartPosition.Z))
        self.assert_almost_equal_grid(grid, (
            (((-3, -2, 1), (3, -2, 1)), ((-3, 0, 1), (3, 0, 1)), ((-3, 2, 1), (3, 2, 1))),
            (((3, 2, 0), (-3, 2, 0)), ((3, 0, 0), (-3, 0, 0)), ((3, -2, 0), (-3, -2, 0))),
            (((-3, -2, -1), (3, -2, -1)), ((-3, 0, -1), (3, 0, -1)), ((-3, 2, -1), (3, 2, -1))),
        ))

    def test_spiral_layer_lines(self):
        for z in (-1, 0, 1):
            spiral_lines = _resolve_nested(1, get_spiral_layer_lines(
                0, 2, 0, 2, z, 1, 1, GridDirection.X, StartPosition.NONE))
            self.assert_almost_equal_lines(spiral_lines, (
                ((0, 0, z), (2, 0, z)), ((2, 0, z), (2, 2, z)), ((2, 2, z), (0, 2, z)),
                ((0, 2, z), (0, 1, z)), ((0, 1, z), (1, 1, z))))

    def test_spiral_layer(self):
        for z in (-1, 0, 1):
            # sharp corners
            spiral_lines = _resolve_nested(1, get_spiral_layer(
                0, 2, 0, 2, z, 1, None, GridDirection.X, StartPosition.NONE, False, False))
            self.assert_almost_equal_lines(spiral_lines, (
                ((0, 0, z), (2, 0, z)), ((2, 0, z), (2, 2, z)), ((2, 2, z), (0, 2, z)),
                ((0, 2, z), (0, 1, z)), ((0, 1, z), (1, 1, z))))
            # rounded corners
            spiral_lines = _resolve_nested(1, get_spiral_layer(
                0, 2, 0, 2, z, 2, None, GridDirection.X, StartPosition.NONE, True, False))
            # verify a few interesting points along the arc
            self.assert_almost_equal_line(spiral_lines[0], ((0, 0, z), (1, 0, z)))
            self.assert_almost_equal_positions(
                spiral_lines[5][0], (1.7071067811865475, 0.2928932188134523, z))
            self.assert_almost_equal_positions(spiral_lines[9][0], (2.0, 1.0, z))
            self.assert_almost_equal_positions(
                spiral_lines[13][0], (1.7071067811865475, 1.7071067811865475, z))
            self.assert_almost_equal_line(spiral_lines[17], ((1, 2, z), (0, 2, z)))

    def xtest_fixed_grid(self):
        box = Box3D(Point3D(-1, -1, -1), Point3D(1, 1, 1))
        fixed_grid = get_fixed_grid(
            box, 0.5, line_distance=0.8, step_width=0.6, grid_direction=GridDirection.X,
            milling_style=MillingStyle.IGNORE, start_position=StartPosition.Z)
        resolved_fixed_grid = [list(layer) for layer in fixed_grid]
        print(resolved_fixed_grid)
