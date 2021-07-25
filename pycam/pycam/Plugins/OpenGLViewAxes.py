"""
Copyright 2011 Lars Kruse <devel@sumpfralle.de>

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

import pycam.Plugins
from pycam.Gui.OpenGLTools import draw_direction_cone


class OpenGLViewAxes(pycam.Plugins.PluginBase):

    DEPENDS = ["OpenGLWindow"]
    CATEGORIES = ["Visualization", "OpenGL"]

    def setup(self):
        self.core.register_event("visualize-items", self.draw_axes)
        self.core.get("register_display_item")("show_axes", "Show Coordinate System", 50)
        self.core.emit_event("visual-item-updated")
        return True

    def teardown(self):
        self.core.unregister_event("visualize-items", self.draw_axes)
        self.core.get("unregister_display_item")("show_axes")
        self.core.emit_event("visual-item-updated")

    def draw_axes(self):
        if not self.core.get("show_axes"):
            return
        GL = self._GL
        GL.glMatrixMode(GL.GL_MODELVIEW)
        GL.glLoadIdentity()
        low, high = [None, None, None], [None, None, None]
        self.core.call_chain("get_draw_dimension", low, high)
        if None in low or None in high:
            low, high = (0, 0, 0), (10, 10, 10)
        length = 1.2 * max(max(high), abs(min(low)))
        origin = (0, 0, 0)
        cone_length = 0.05
        old_line_width = GL.glGetFloatv(GL.GL_LINE_WIDTH)
        if self.core.get("view_light"):
            GL.glDisable(GL.GL_LIGHTING)
        GL.glLineWidth(1.5)
        # draw a colored line ending in a cone for each axis
        for index in range(3):
            end = [0, 0, 0]
            end[index] = length
            color = [0.0, 0.0, 0.0]
            # reduced brightness (not 1.0)
            color[index] = 0.8
            GL.glColor3f(*color)
            # we need to wait until the color change is active
            GL.glFinish()
            GL.glBegin(GL.GL_LINES)
            GL.glVertex3f(*origin)
            GL.glVertex3f(*end)
            GL.glEnd()
            # Position the cone slightly behind the end of the line - otherwise
            # the end of the line (width=2) is visible at the top of the cone.
            draw_direction_cone(origin, end, position=1.0 + cone_length, precision=32,
                                size=cone_length)
        GL.glLineWidth(old_line_width)
        if self.core.get("view_light"):
            GL.glEnable(GL.GL_LIGHTING)
