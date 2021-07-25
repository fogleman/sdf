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


class ModelRotation(pycam.Plugins.PluginBase):

    UI_FILE = "model_rotation.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model"]

    def setup(self):
        if self.gui:
            rotation_box = self.gui.get_object("ModelRotationBox")
            rotation_box.unparent()
            self.core.register_ui("model_handling", "Rotation", rotation_box, -10)
            self._gtk_handlers = ((self.gui.get_object("RotateModelButton"), "clicked",
                                   self._rotate_model), )
            self._event_handlers = (("model-selection-changed", self._update_controls), )
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_controls()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("model_handling", self.gui.get_object("ModelRotationBox"))

    def _update_controls(self):
        widget = self.gui.get_object("ModelRotationBox")
        if self.core.get("models").get_selected():
            widget.show()
        else:
            widget.hide()

    def _rotate_model(self, widget=None):
        models = self.core.get("models").get_selected()
        if not models:
            return
        center = [0, 0, 0]
        for axis in "XYZ":
            if self.gui.get_object("RotationAxis%s" % axis).get_active():
                break
        axis_vector = {"X": [1, 0, 0], "Y": [0, 1, 0], "Z": [0, 0, 1]}[axis]
        for control, angle in (("RotationAngle90CCKW", -90),
                               ("RotationAngle90CKW", 90),
                               ("RotationAngle180", 180),
                               ("RotationAngleCustomCKW",
                                self.gui.get_object("RotationAngle").get_value())):
            if self.gui.get_object(control).get_active():
                break
        for model in models:
            model.extend_value("transformations", [{"action": "rotate", "center": center,
                                                    "vector": axis_vector, "angle": angle}])
