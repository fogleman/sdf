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
import pycam.workspace.data_models


class OpenGLViewSupportModelPreview(pycam.Plugins.PluginBase):

    DEPENDS = ["OpenGLWindow", "OpenGLViewModel"]
    CATEGORIES = ["Visualization", "OpenGL", "Support bridges"]

    def setup(self):
        self.core.register_event("visualize-items", self.draw_support_preview)
        self.core.get("register_display_item")("show_support_preview",
                                               "Show Support Model Preview", 30)
        self.core.get("register_color")("color_support_preview", "Support model", 30)
        self.core.emit_event("visual-item-updated")
        return True

    def teardown(self):
        self.core.unregister_event("visualize-items", self.draw_support_preview)
        self.core.get("unregister_display_item")("show_support_preview")
        self.core.get("unregister_color")("color_support_preview")
        self.core.emit_event("visual-item-updated")

    def draw_support_preview(self):
        if not self.core.get("show_support_preview"):
            return
        models = []
        for model_object in (self.core.get("current_support_models") or []):
            model = model_object.get_model()
            if model:
                models.append(model)
        if not models:
            return
        GL = self._GL
        # disable lighting
        if self.core.get("view_light"):
            GL.glDisable(GL.GL_LIGHTING)
        # show a wireframe
        if self.core.get("view_polygon"):
            GL.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_LINE)
        # change the color
        col = self.core.get("color_support_preview")
        color = (col["red"], col["green"], col["blue"], col["alpha"])
        GL.glColor4f(*color)
        # we need to wait until the color change is active
        GL.glFinish()
        # draw the models
        self.core.call_chain("draw_models", models)
        # enable lighting again
        if self.core.get("view_light"):
            GL.glEnable(GL.GL_LIGHTING)
        # enable polygon fill mode again
        if self.core.get("view_polygon"):
            GL.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_FILL)
