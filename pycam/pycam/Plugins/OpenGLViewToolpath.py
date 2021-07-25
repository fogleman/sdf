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
import pycam.Gui.OpenGLTools
from pycam.Toolpath import MOVES_LIST, MOVE_STRAIGHT_RAPID


class OpenGLViewToolpath(pycam.Plugins.PluginBase):

    DEPENDS = ["OpenGLWindow", "Toolpaths"]
    CATEGORIES = ["Toolpath", "Visualization", "OpenGL"]

    def setup(self):
        self.core.get("register_color")("color_toolpath_cut", "Toolpath cut", 60)
        self.core.get("register_color")("color_toolpath_return", "Toolpath rapid", 70)
        self.core.register_chain("get_draw_dimension", self.get_draw_dimension)
        self.core.get("register_display_item")("show_toolpath", "Show Toolpath", 30)
        self._event_handlers = (
            ("toolpath-list-changed", "visual-item-updated"),
            ("toolpath-changed", "visual-item-updated"),
            ("visualize-items", self.draw_toolpaths))
        self.register_event_handlers(self._event_handlers)
        self.core.emit_event("visual-item-updated")
        return True

    def teardown(self):
        self.core.unregister_chain("get_draw_dimension", self.get_draw_dimension)
        self.unregister_event_handlers(self._event_handlers)
        self.core.get("unregister_color")("color_toolpath_cut")
        self.core.get("unregister_color")("color_toolpath_return")
        self.core.get("unregister_display_item")("show_toolpath")
        self.core.emit_event("visual-item-updated")

    def get_draw_dimension(self, low, high):
        if self._is_visible():
            toolpaths = self.core.get("toolpaths").get_visible()
            for toolpath_dict in toolpaths:
                tp = toolpath_dict.get_toolpath()
                if tp:
                    mlow = tp.minx, tp.miny, tp.minz
                    mhigh = tp.maxx, tp.maxy, tp.maxz
                    if None in mlow or None in mhigh:
                        continue
                    for index in range(3):
                        if (low[index] is None) or (mlow[index] < low[index]):
                            low[index] = mlow[index]
                        if (high[index] is None) or (mhigh[index] > high[index]):
                            high[index] = mhigh[index]

    def _is_visible(self):
        return self.core.get("show_toolpath") \
                and not self.core.get("toolpath_in_progress") \
                and not self.core.get("show_simulation")

    def draw_toolpaths(self):
        toolpath_in_progress = self.core.get("toolpath_in_progress")
        if toolpath_in_progress is None and self.core.get("show_toolpath"):
            settings_filters = []
            # Use the currently selected export settings for an intuitive behaviour.
            selected_export_settings = self.core.get("export_settings").get_selected()
            if selected_export_settings:
                settings_filters.extend(selected_export_settings.get_toolpath_filters())
            for toolpath_dict in self.core.get("toolpaths").get_visible():
                toolpath = toolpath_dict.get_toolpath()
                if toolpath:
                    # TODO: enable the VBO code for speedup!
                    # moves = toolpath.get_moves_for_opengl(self.core.get("gcode_safety_height"))
                    # self._draw_toolpath_moves2(moves)
                    moves = toolpath.get_basic_moves(filters=settings_filters)
                    self._draw_toolpath_moves(moves)
        elif toolpath_in_progress is not None:
            if self.core.get("show_simulation") or self.core.get("show_toolpath_progress"):
                self._draw_toolpath_moves(toolpath_in_progress)

    def _draw_toolpath_moves2(self, paths):
        GL = self._GL
        GL.glDisable(GL.GL_LIGHTING)
        color_rapid = self.core.get("color_toolpath_return")
        color_cut = self.core.get("color_toolpath_cut")
        show_directions = self.core.get("show_directions")
        GL.glMatrixMode(GL.GL_MODELVIEW)
        GL.glLoadIdentity()
        coords = paths[0]
        try:
            coords.bind()
            GL.glEnableClientState(GL.GL_VERTEX_ARRAY)
            GL.glVertexPointerf(coords)
            for path in paths[1]:
                if path[2]:
                    GL.glColor4f(color_rapid["red"], color_rapid["green"], color_rapid["blue"],
                                 color_rapid["alpha"])
                else:
                    GL.glColor4f(color_cut["red"], color_cut["green"], color_cut["blue"],
                                 color_cut["alpha"])
                if show_directions:
                    GL.glDisable(GL.GL_CULL_FACE)
                    GL.glDrawElements(GL.GL_TRIANGLES, len(path[1]), GL.GL_UNSIGNED_INT, path[1])
                    GL.glEnable(GL.GL_CULL_FACE)
                GL.glDrawElements(GL.GL_LINE_STRIP, len(path[0]), GL.GL_UNSIGNED_INT, path[0])
        finally:
            coords.unbind()

    # Simulate still depends on this pathway
    def _draw_toolpath_moves(self, moves):
        GL = self._GL
        GL.glDisable(GL.GL_LIGHTING)
        show_directions = self.core.get("show_directions")
        color_rapid = self.core.get("color_toolpath_return")
        color_cut = self.core.get("color_toolpath_cut")
        GL.glMatrixMode(GL.GL_MODELVIEW)
        GL.glLoadIdentity()
        last_position = None
        last_rapid = None
        GL.glBegin(GL.GL_LINE_STRIP)
        transitions = []
        for step in moves:
            if step.action not in MOVES_LIST:
                continue
            is_rapid = step.action == MOVE_STRAIGHT_RAPID
            if last_rapid != is_rapid:
                GL.glEnd()
                if is_rapid:
                    GL.glColor4f(color_rapid["red"], color_rapid["green"], color_rapid["blue"],
                                 color_rapid["alpha"])
                else:
                    GL.glColor4f(color_cut["red"], color_cut["green"], color_cut["blue"],
                                 color_cut["alpha"])
                # we need to wait until the color change is active
                GL.glFinish()
                GL.glBegin(GL.GL_LINE_STRIP)
                if last_position is not None:
                    GL.glVertex3f(*last_position)
                last_rapid = is_rapid
            GL.glVertex3f(*step.position)
            if show_directions and (last_position is not None):
                transitions.append((last_position, step.position))
            last_position = step.position
        GL.glEnd()
        if show_directions:
            for p1, p2 in transitions:
                pycam.Gui.OpenGLTools.draw_direction_cone(p1, p2)
