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


class ModelPolygons(pycam.Plugins.PluginBase):

    UI_FILE = "model_polygons.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model"]

    def setup(self):
        if self.gui:
            polygon_frame = self.gui.get_object("ModelPolygonFrame")
            polygon_frame.unparent()
            self.core.register_ui("model_handling", "Polygons", polygon_frame, 0)
            self._gtk_handlers = (
                (self.gui.get_object("ToggleModelDirectionButton"),
                 "clicked", self._adjust_polygons, "toggle_polygon_directions"),
                (self.gui.get_object("DirectionsGuessButton"),
                 "clicked", self._adjust_polygons, "revise_polygon_directions"))
            self._event_handlers = (
                ("model-change-after", self._update_polygon_controls),
                ("model-selection-changed", self._update_polygon_controls))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_polygon_controls()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("model_handling", self.gui.get_object("ModelPolygonFrame"))

    def _get_polygon_models(self):
        models = []
        for model in self.core.get("models").get_selected():
            if model and hasattr(model.get_model(), "reverse_directions"):
                models.append(model)
        return models

    def _update_polygon_controls(self):
        models = self._get_polygon_models()
        frame = self.gui.get_object("ModelPolygonFrame")
        if models:
            frame.show()
        else:
            frame.hide()

    def _adjust_polygons(self, widget=None, action=None):
        models = self._get_polygon_models()
        for model in models:
            model.extend_value("transformations", [{"action": action}])
