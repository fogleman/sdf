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


from pycam.Geometry import Box3D, Point3D
import pycam.Plugins


class OpenGLViewDimension(pycam.Plugins.PluginBase):

    UI_FILE = "opengl_view_dimension.ui"
    DEPENDS = ["Bounds", "Models", "OpenGLWindow"]
    CATEGORIES = ["Model", "Visualization", "OpenGL"]

    def setup(self):
        if self.gui:
            self.core.register_ui("opengl_window", "Dimension",
                                  self.gui.get_object("DimensionTable"), weight=20)
            self.core.get("register_display_item")("show_dimensions", "Show Dimensions", 60)
            self._event_handlers = (
                ("model-change-after", self.update_model_dimensions),
                ("visual-item-updated", self.update_model_dimensions),
                ("model-list-chaned", self.update_model_dimensions))
            self.register_event_handlers(self._event_handlers)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.core.unregister_ui("opengl_window", self.gui.get_object("DimensionTable"))
            self.core.get("unregister_display_item")("show_dimensions")

    def update_model_dimensions(self, widget=None):
        dimension_bar = self.gui.get_object("DimensionTable")
        models = [m.get_model() for m in self.core.get("models").get_visible()]
        model_box = pycam.Geometry.Model.get_combined_bounds(models)
        if model_box is None:
            model_box = Box3D(Point3D(0, 0, 0), Point3D(0, 0, 0))
        bounds = self.core.get("bounds").get_selected()
        if self.core.get("show_dimensions"):
            for value, label_suffix in ((model_box.lower.x, "XMin"), (model_box.upper.x, "XMax"),
                                        (model_box.lower.y, "YMin"), (model_box.upper.y, "YMax"),
                                        (model_box.lower.z, "ZMin"), (model_box.upper.z, "ZMax")):
                label_name = "ModelCorner%s" % label_suffix
                value = "%.3f" % value
                if label_suffix.lower().endswith("max"):
                    value += self.core.get("unit_string")
                self.gui.get_object(label_name).set_label(value)
            if bounds:
                bounds_box = bounds.get_absolute_limits()
                if bounds_box is None:
                    bounds_size = ("", "", "")
                else:
                    bounds_size = ["%.3f %s" % (high - low, self.core.get("unit_string"))
                                   for low, high in zip(bounds_box.lower, bounds_box.upper)]
                for axis, size_string in zip("xyz", bounds_size):
                    self.gui.get_object("model_dim_" + axis).set_text(size_string)
            dimension_bar.show()
        else:
            dimension_bar.hide()
