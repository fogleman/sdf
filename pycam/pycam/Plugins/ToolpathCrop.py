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


import pycam.Gui.ControlsGTK
import pycam.Plugins


class ToolpathCrop(pycam.Plugins.PluginBase):

    UI_FILE = "toolpath_crop.ui"
    DEPENDS = ["Models", "Toolpaths"]
    CATEGORIES = ["Toolpath"]

    def setup(self):
        if self.gui:
            self._frame = self.gui.get_object("ToolpathCropFrame")
            self.core.register_ui("toolpath_handling", "Crop", self._frame, 40)
            self._gtk_handlers = []
            self._gtk_handlers.append((self.gui.get_object("CropButton"), "clicked",
                                       self.crop_toolpath))
            # model selector
            self.models_widget = pycam.Gui.ControlsGTK.InputTable(
                [], change_handler=self._update_widgets)

            def get_converter(model_refs):
                models_dict = {}
                for model in self.core.get("models"):
                    models_dict[id(model)] = model
                models = []
                for model_ref in model_refs:
                    models.append(models_dict[model_ref])
                return models

            def set_converter(models):
                return [id(model) for model in models]

            self.models_widget.set_conversion(set_conv=set_converter, get_conv=get_converter)
            self.gui.get_object("ModelTableContainer").add(self.models_widget.get_widget())
            self._event_handlers = (
                ("model-list-changed", self._update_models_list),
                ("toolpath-selection-changed", self._update_visibility))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_widgets()
            self._update_visibility()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.gui.get_object("ModelTableContainer").remove(self.models_widget.get_widget())
            self.core.unregister_ui("toolpath_handling", self._frame)

    def _update_models_list(self):
        choices = []
        for model in self.core.get("models").get_all():
            if hasattr(model.get_model(), "get_polygons"):
                choices.append((model.get_id(), model))
        self.models_widget.update_choices(choices)

    def _update_visibility(self):
        if self.core.get("toolpaths").get_selected():
            self._frame.show()
        else:
            self._frame.hide()

    def _update_widgets(self, widget=None):
        models = [m.get_model() for m in self.models_widget.get_value()]
        info_label = self.gui.get_object("ToolpathCropInfo")
        info_box = self.gui.get_object("ToolpathCropInfoBox")
        button = self.gui.get_object("CropButton")
        # update info
        if not models:
            info_box.show()
            info_label.set_label("Hint: select a model")
            button.set_sensitive(False)
        else:
            info_box.hide()
            button.set_sensitive(True)

    def crop_toolpath(self, widget=None):
        model_ids = [model.get_id() for model in self.models_widget.get_value()]
        for toolpath in self.core.get("toolpaths").get_selected():
            toolpath.append_transformation({"action": "crop", "models": model_ids})
