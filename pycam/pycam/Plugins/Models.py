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

import copy
import random

from pycam.Flow.history import merge_history_and_block_events, rollback_history_on_failure
import pycam.Plugins
import pycam.workspace.data_models


class Models(pycam.Plugins.ListPluginBase):

    UI_FILE = "models.ui"
    CATEGORIES = ["Model"]
    ICONS = {"visible": "visible.svg", "hidden": "visible_off.svg"}
    FALLBACK_COLOR = {"red": 0.5, "green": 0.5, "blue": 1.0, "alpha": 1.0}
    COLLECTION_ITEM_TYPE = pycam.workspace.data_models.Model

    def setup(self):
        if self.gui:
            self.model_frame = self.gui.get_object("ModelBox")
            self.model_frame.unparent()
            self.core.register_ui("main", "Models", self.model_frame, weight=-50)
            model_handling_obj = self.gui.get_object("ModelHandlingNotebook")

            def clear_model_handling_obj():
                for index in range(model_handling_obj.get_n_pages()):
                    model_handling_obj.remove_page(0)

            def add_model_handling_item(item, name):
                model_handling_obj.append_page(item, self._gtk.Label(name))

            self.core.register_ui_section("model_handling", add_model_handling_item,
                                          clear_model_handling_obj)
            self._modelview = self.gui.get_object("ModelView")
            self.set_gtk_modelview(self._modelview)
            self.register_model_update(lambda: self.core.emit_event("model-list-changed"))
            for action, obj_name in ((self.ACTION_UP, "ModelMoveUp"),
                                     (self.ACTION_DOWN, "ModelMoveDown"),
                                     (self.ACTION_DELETE, "ModelDelete"),
                                     (self.ACTION_CLEAR, "ModelDeleteAll")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            self._gtk_handlers = []
            self._gtk_handlers.extend((
                (self.gui.get_object("ModelColorButton"), "color-set",
                 self._store_colors_of_selected_models),
                (self._modelview, "row-activated", self.toggle_item_visibility),
                (self.gui.get_object("NameCell"), "edited", self.edit_item_name)))
            self._treemodel = self.gui.get_object("ModelList")
            self._treemodel.clear()
            selection = self._modelview.get_selection()
            selection.set_mode(self._gtk.SelectionMode.MULTIPLE)
            self._gtk_handlers.append((selection, "changed", "model-selection-changed"))
            # define cell renderers
            self.gui.get_object("NameColumn").set_cell_data_func(
                self.gui.get_object("NameCell"), self.render_item_name)
            self.gui.get_object("VisibleColumn").set_cell_data_func(
                self.gui.get_object("VisibleSymbol"), self.render_item_visible_state)
            self._event_handlers = (
                ("model-selection-changed", self._apply_colors_of_selected_models),
                ("model-list-changed", self.force_gtk_modelview_refresh))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._apply_colors_of_selected_models()
            # update the model list
            self.core.emit_event("model-list-changed")
        self.core.set("models", self)
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui_section("model_handling")
            self.core.unregister_ui("main", self.gui.get_object("ModelBox"))
            self.core.unregister_ui("main", self.model_frame)
        self.clear_state_items()
        self.core.set("models", None)
        self.clear()
        return True

    def _get_model_gdk_color(self, color_dict):
        return self._gdk.RGBA(red=color_dict["red"],
                              green=color_dict["green"],
                              blue=color_dict["blue"],
                              alpha=color_dict["alpha"])

    def _apply_model_color_to_button(self, model, color_button):
        color = model.get_application_value("color")
        if color is not None:
            color_button.set_rgba(self._get_model_gdk_color(color))

    def _apply_colors_of_selected_models(self, widget=None):
        color_button = self.gui.get_object("ModelColorButton")
        models = self.get_selected()
        color_button.set_sensitive(len(models) > 0)
        if models:
            # use the color of the first model, if it exists
            self._apply_model_color_to_button(models[0], color_button)

    def _store_colors_of_selected_models(self, widget=None):
        color = self.gui.get_object("ModelColorButton").get_rgba()
        for model in self.get_selected():
            model.set_application_value("color", {
                "red": color.red, "green": color.green, "blue": color.blue, "alpha": color.alpha})
        self.core.emit_event("visual-item-updated")

    def render_visible_state(self, column, cell, model, m_iter, data):
        item, cell = super().render_visible_state(column, cell, model, m_iter, data)
        color = self._get_or_create_model_application_color(item)
        if color is not None:
            cell.set_property("cell-background-gdk", self._get_model_gdk_color(color))

    def _get_or_create_model_application_color(self, model):
        color = model.get_application_value("color")
        if color is None:
            # TODO: use a proper palette instead of random values
            color = {"red": random.random(),
                     "green": random.random(),
                     "blue": random.random(),
                     "alpha": 0.8}
            model.set_application_value("color", color)
        return color

    def add_model(self, model_params, name=None, color=None, name_template="Model #%d"):
        """

        @param model_params: a dictionary describing the model, e.g.:
            {"source": {"type": "object", "data": FOO}}
        """
        self.log.info("Adding new model: %s", name)
        if not color:
            color = self.core.get("color_model")
        if not color:
            color = self.FALLBACK_COLOR.copy()
        if name is None:
            name = self.get_non_conflicting_name(name_template)
        with rollback_history_on_failure(self.core):
            with merge_history_and_block_events(self.core):
                new_model = pycam.workspace.data_models.Model(None, copy.deepcopy(model_params))
                new_model.set_application_value("name", name)
                new_model.set_application_value("color", color)
                new_model.set_application_value("visible", True)
