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


class ModelScaling(pycam.Plugins.PluginBase):

    UI_FILE = "model_scaling.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model"]

    def setup(self):
        if self.gui:
            scale_box = self.gui.get_object("ModelScaleBox")
            scale_box.unparent()
            self.core.register_ui("model_handling", "Scale", scale_box, -5)
            scale_percent = self.gui.get_object("ScalePercent")
            scale_button = self.gui.get_object("ScaleModelButton")
            scale_percent.set_value(100)
            scale_dimension_button = self.gui.get_object("ScaleAllAxesButton")
            scale_dimension_control = self.gui.get_object("ScaleDimensionControl")
            self._gtk_handlers = []
            self._gtk_handlers.extend((
                (scale_percent, "focus-in-event",
                 lambda widget, data: scale_button.grab_default()),
                (scale_percent, "focus-out-event",
                 lambda widget, data: scale_box.get_toplevel().set_default(None)),
                (scale_button, "clicked", self._scale_model),
                (self.gui.get_object("ScaleDimensionAxis"), "changed",
                 lambda widget=None: self.core.emit_event("model-change-after")),
                (scale_dimension_control, "focus-in-event",
                 lambda widget, data: scale_dimension_button.grab_default()),
                (scale_dimension_control, "focus-out-event",
                 lambda widget, data: scale_box.get_toplevel().set_default(None)),
                (scale_dimension_button, "clicked",
                 lambda widget: self._scale_model_axis_fit(proportionally=True)),
                (self.gui.get_object("ScaleSelectedAxisButton"), "clicked",
                 lambda widget: self._scale_model_axis_fit(proportionally=False)),
                (self.gui.get_object("ScaleInchMM"), "clicked",
                 lambda widget: self._scale_model(percent=(100 * 25.4))),
                (self.gui.get_object("ScaleMMInch"), "clicked",
                 lambda widget: self._scale_model(percent=(100 / 25.4)))))
            self._event_handlers = (
                ("model-selection-changed", self._update_scale_controls),
                ("model-change-after", self._update_scale_controls))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_scale_controls()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("model_handling", self.gui.get_object("ModelScaleBox"))

    def _update_scale_controls(self):
        models = self.core.get("models").get_selected()
        scale_box = self.gui.get_object("ModelScaleBox")
        if not models:
            scale_box.hide()
            return
        else:
            scale_box.show()
            # scale controls
            axis_control = self.gui.get_object("ScaleDimensionAxis")
            scale_selected_button = self.gui.get_object("ScaleSelectedAxisButton")
            scale_all_button = self.gui.get_object("ScaleAllAxesButton")
            scale_value = self.gui.get_object("ScaleDimensionControl")
            index = axis_control.get_active()
            enable_controls = False
            for model_dict in models:
                model = model_dict.get_model()
                dims = (model.maxx - model.minx, model.maxy - model.miny, model.maxz - model.minz)
                value = dims[index]
                non_zero_dimensions = [i for i, dim in enumerate(dims) if dim > 0]
                enable_controls = enable_controls or (index in non_zero_dimensions)
            scale_selected_button.set_sensitive(enable_controls)
            scale_all_button.set_sensitive(enable_controls)
            scale_value.set_sensitive(enable_controls)
            scale_value.set_value(value)

    def _scale_model(self, widget=None, percent=None):
        models = self.core.get("models").get_selected()
        if not models:
            return
        if percent is None:
            percent = self.gui.get_object("ScalePercent").get_value()
        factor = percent / 100.0
        if (factor <= 0) or (factor == 1):
            return
        axes = [factor] * 3
        for model in models:
            model.extend_value("transformations",
                               [{"action": "scale", "scale_target": "factor", "axes": axes}])

    def _scale_model_axis_fit(self, widget=None, proportionally=False):
        models = self.core.get("models").get_selected()
        if not models:
            return
        value = self.gui.get_object("ScaleDimensionValue").get_value()
        index = self.gui.get_object("ScaleDimensionAxis").get_active()
        if proportionally:
            axes = [value] * 3
        else:
            axes = [None, None, None]
            axes[index] = value
        for model in models:
            model.extend_value("transformations",
                               [{"action": "scale", "scale_target": "size", "axes": axes}])
