"""
Copyright 2010-2011 Lars Kruse <devel@sumpfralle.de>

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

import math

# careful import
try:
    import OpenGL.GL as GL
    import OpenGL.GLUT as GLUT
except (ImportError, RuntimeError):
    pass

from pycam.Geometry import sqrt
from pycam.Geometry.PointUtils import pcross, pnorm, pnormalized, psub


def keep_matrix(func):
    def keep_matrix_wrapper(*args, **kwargs):
        pushed_matrix_mode = GL.glGetIntegerv(GL.GL_MATRIX_MODE)
        GL.glPushMatrix()
        result = func(*args, **kwargs)
        final_matrix_mode = GL.glGetIntegerv(GL.GL_MATRIX_MODE)
        GL.glMatrixMode(pushed_matrix_mode)
        GL.glPopMatrix()
        GL.glMatrixMode(final_matrix_mode)
        return result
    return keep_matrix_wrapper


@keep_matrix
def draw_direction_cone(p1, p2, position=0.5, precision=12, size=0.1):
    distance = psub(p2, p1)
    length = pnorm(distance)
    direction = pnormalized(distance)
    if direction is None:
        # zero-length line
        return
    cone_length = length * size
    cone_radius = cone_length / 3.0
    # move the cone to the middle of the line
    GL.glTranslatef((p1[0] + p2[0]) * position,
                    (p1[1] + p2[1]) * position,
                    (p1[2] + p2[2]) * position)
    # rotate the cone according to the line direction
    # The cross product is a good rotation axis.
    cross = pcross(direction, (0, 0, -1))
    if pnorm(cross) != 0:
        # The line direction is not in line with the z axis.
        try:
            angle = math.asin(sqrt(direction[0] ** 2 + direction[1] ** 2))
        except ValueError:
            # invalid angle - just ignore this cone
            return
        # convert from radians to degree
        angle = angle / math.pi * 180
        if direction[2] < 0:
            angle = 180 - angle
        GL.glRotatef(angle, cross[0], cross[1], cross[2])
    elif direction[2] == -1:
        # The line goes down the z axis - turn it around.
        GL.glRotatef(180, 1, 0, 0)
    else:
        # The line goes up the z axis - nothing to be done.
        pass
    # center the cone
    GL.glTranslatef(0, 0, -cone_length * position)
    # draw the cone
    GLUT.glutWireCone(cone_radius, cone_length, precision, 1)
