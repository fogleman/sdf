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


import pycam.Geometry.Model
import pycam.Plugins
import pycam.workspace.data_models


class ModelSupport(pycam.Plugins.PluginBase):

    UI_FILE = "model_support.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model", "Support bridges"]
    MODEL_NAME_TEMPLATE = "Support Model #%d"

    def setup(self):
        if self.gui:
            self._support_frame = self.gui.get_object("ModelExtensionsFrame")
            self._support_frame.unparent()
            self.core.register_ui("model_handling", "Support", self._support_frame, 0)
            support_model_type_selector = self.gui.get_object("SupportGridTypesControl")
            self._gtk_handlers = []
            self._gtk_handlers.append((support_model_type_selector, "changed",
                                       "support-model-changed"))

            def add_support_model_type(obj, name):
                types_model = support_model_type_selector.get_model()
                # the model is gone (for unknown reasons) when the GTK loop stops
                if types_model is not None:
                    types_model.append((obj, name))
                    # enable the first item by default
                    if len(types_model) == 1:
                        support_model_type_selector.set_active(0)

            def clear_support_model_type_selector():
                model = support_model_type_selector.get_model()
                # the model is gone (for unknown reasons) when the GTK loop stops
                if model is not None:
                    model.clear()

            def clear_support_model_settings():
                children = container.get_children()
                for child in children:
                    container.remove(child)

            def get_support_model_type():
                index = support_model_type_selector.get_active()
                if index < 0:
                    return None
                else:
                    selector_model = support_model_type_selector.get_model()
                    return selector_model[index][0]

            def set_support_model_type(model_type):
                selector_model = support_model_type_selector.get_model()
                for index, row in enumerate(selector_model):
                    if row[0] == model_type:
                        support_model_type_selector.set_active(index)
                        break
                else:
                    support_model_type_selector.set_active(-1)

            self.core.register_ui_section("support_model_type_selector", add_support_model_type,
                                          clear_support_model_type_selector)
            self.core.register_ui("support_model_type_selector", "none", "none", weight=-100)
            container = self.gui.get_object("SupportAddOnContainer")
            self.core.register_ui_section(
                "support_model_settings",
                lambda obj, name: container.pack_start(obj, expand=False, fill=False, padding=0),
                clear_support_model_settings)
            # TODO: remove public settings
            self.core.add_item("support_model_type", get_support_model_type,
                               set_support_model_type)
            grid_thickness = self.gui.get_object("SupportGridThickness")
            self._gtk_handlers.append((grid_thickness, "value-changed", "support-model-changed"))
            self.core.add_item("support_grid_thickness", grid_thickness.get_value,
                               grid_thickness.set_value)
            grid_height = self.gui.get_object("SupportGridHeight")
            self._gtk_handlers.append((grid_height, "value-changed", "support-model-changed"))
            self.core.add_item("support_grid_height", grid_height.get_value, grid_height.set_value)
            self._gtk_handlers.append((self.gui.get_object("CreateSupportModel"), "clicked",
                                       self._add_support_model))
            # support grid defaults
            self.core.set("support_grid_thickness", 0.5)
            self.core.set("support_grid_height", 0.5)
            self.core.set("support_grid_type", "none")
            self.core.register_chain("get_draw_dimension", self.get_draw_dimension)
            # handlers
            self._event_handlers = (
                ("model-change-after", "support-model-changed"),
                ("bounds-changed", "support-model-changed"),
                ("model-selection-changed", "support-model-changed"),
                ("support-model-changed", self.update_support_model))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_widgets()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_chain("get_draw_dimension", self.get_draw_dimension)
            self.core.unregister_ui("model_handling", self.gui.get_object("ModelExtensionsFrame"))
            self.core.unregister_ui("support_model_type_selector", "none")
            self.core.unregister_ui_section("support_model_settings")
            self.core.unregister_ui_section("support_model_type_selector")

    def _update_widgets(self):
        models = self.core.get("models").get_selected()
        if models:
            self._support_frame.show()
        else:
            self._support_frame.hide()
        grid_type = self.core.get("support_model_type")
        details_box = self.gui.get_object("SupportGridDetailsBox")
        # show/hide the common details (width/height)
        # enable/disable the "create support model" button
        create_button = self.gui.get_object("CreateSupportModel")
        if grid_type == "none":
            details_box.hide()
            create_button.set_sensitive(False)
        else:
            details_box.show()
            create_button.set_sensitive(True)

    def _add_support_model(self, widget=None):
        for model_object in self.core.get("current_support_models"):
            self.core.get("models").add_model(model_object.get_dict(),
                                              name_template=self.MODEL_NAME_TEMPLATE,
                                              color=self.core.get("color_support_preview"))
        # Disable the support model type -> avoid confusing visualization.
        # (this essentially removes the support grid from the 3D view)
        self.gui.get_object("SupportGridTypesControl").set_active(0)

    def get_draw_dimension(self, low, high):
        if not self.core.get("show_support_preview"):
            return
        support_model_objects = self.core.get("current_support_models", [])
        support_models = []
        for model_object in support_model_objects:
            support_model = model_object.get_model()
            if support_model:
                support_models.append(support_model)
        model_box = pycam.Geometry.Model.get_combined_bounds(support_models)
        if model_box is None:
            return
        for index, (mlow, mhigh) in enumerate(zip(model_box.lower, model_box.upper)):
            if (low[index] is None) or (mlow < low[index]):
                low[index] = mlow
            if (high[index] is None) or (mhigh > high[index]):
                high[index] = mhigh

    def update_support_model(self, widget=None):
        old_support_model_objects = self.core.get("current_support_models")
        selected_models = self.core.get("models").get_selected()
        grid_type = self.core.get("support_model_type")
        new_support_model_objects = []
        if (grid_type == "none") or (not selected_models):
            new_support_model_objects = []
        else:
            # update the support model
            self.core.call_chain("get_support_models", selected_models, new_support_model_objects)
        if old_support_model_objects != new_support_model_objects:
            self.core.set("current_support_models", new_support_model_objects)
            self.core.emit_event("visual-item-updated")
        # show/hide controls
        self._update_widgets()
