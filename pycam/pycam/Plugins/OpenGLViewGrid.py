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

import math

import pycam.Plugins


class OpenGLViewGrid(pycam.Plugins.PluginBase):

    UI_FILE = "opengl_view_grid.ui"
    DEPENDS = ["OpenGLWindow"]
    CATEGORIES = ["Visualization", "OpenGL"]
    MINOR_LINES = 5
    MAJOR_LINES = 1

    def setup(self):
        if self.gui:
            self.box = self.gui.get_object("GridSizeBox")
            self.core.register_ui("opengl_window", "Grid", self.box, weight=30)
            self.core.register_event("visual-item-updated", self._update_widget_state)
        self.core.register_event("visualize-items", self.draw_grid)
        self.core.get("register_display_item")("show_grid", "Show Base Grid", 80)
        self.core.get("register_color")("color_grid", "Base Grid", 80)
        self.core.emit_event("visual-item-updated")
        return True

    def teardown(self):
        if self.gui:
            self.core.unregister_event("visual-item-updated", self._update_widget_state)
            self.core.unregister_ui("opengl_window", self.box)
        self.core.unregister_event("visualize-items", self.draw_grid)
        self.core.get("unregister_color")("color_grid")
        self.core.get("unregister_display_item")("show_grid")
        self.core.emit_event("visual-item-updated")

    def _update_widget_state(self):
        if self.core.get("show_grid"):
            self.box.show()
        else:
            self.box.hide()

    def draw_grid(self):
        if not self.core.get("show_grid"):
            return
        GL = self._GL
        low, high = [None, None, None], [None, None, None]
        self.core.call_chain("get_draw_dimension", low, high)
        if None in low or None in high:
            low, high = (0, 0, 0), (10, 10, 10)
        max_value = max(abs(low[0]), abs(low[1]), high[0], high[1])
        base_size = 10 ** int(math.log(max_value, 10))
        grid_size = math.ceil(float(max_value) / base_size) * base_size
        minor_distance = float(base_size) / self.MINOR_LINES
        if grid_size / base_size > 5:
            minor_distance *= 5
        elif grid_size / base_size > 2.5:
            minor_distance *= 2.5
        major_skip = self.MINOR_LINES / self.MAJOR_LINES
        if self.gui:
            unit = self.core.get("unit_string")
            self.gui.get_object("MajorGridSizeLabel").set_text(
                "%g%s" % (minor_distance * major_skip, unit))
            self.gui.get_object("MinorGridSizeLabel").set_text("%g%s" % (minor_distance, unit))
        line_counter = int(math.ceil(grid_size / minor_distance))
        color = self.core.get("color_grid")
        GL.glColor4f(color["red"], color["green"], color["blue"], color["alpha"])
        GL.glFinish()
        is_light = GL.glIsEnabled(GL.GL_LIGHTING)
        GL.glDisable(GL.GL_LIGHTING)
        GL.glBegin(GL.GL_LINES)
        grid_low = [-grid_size, -grid_size]
        grid_high = [grid_size, grid_size]
        for index in range(2):
            if high[index] <= 0:
                grid_high[index] = 0
            if low[index] >= 0:
                grid_low[index] = 0
        for index in range(-line_counter, line_counter + 1):
            position = index * minor_distance
            if index % major_skip == 0:
                GL.glEnd()
                GL.glLineWidth(3)
                GL.glBegin(GL.GL_LINES)
            if (index == 0) or ((index > 0) and (high[1] > 0)) or ((index < 0) and (low[1] < 0)):
                GL.glVertex3f(grid_low[0], position, 0)
                GL.glVertex3f(grid_high[0], position, 0)
            if (index == 0) or ((index > 0) and (high[0] > 0)) or ((index < 0) and (low[0] < 0)):
                GL.glVertex3f(position, grid_low[1], 0)
                GL.glVertex3f(position, grid_high[1], 0)
            if index % major_skip == 0:
                GL.glEnd()
                GL.glLineWidth(1)
                GL.glBegin(GL.GL_LINES)
        GL.glEnd()
        if is_light:
            GL.glEnable(GL.GL_LIGHTING)
