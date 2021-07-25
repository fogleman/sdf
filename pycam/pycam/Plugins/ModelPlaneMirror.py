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


class ModelPlaneMirror(pycam.Plugins.PluginBase):

    UI_FILE = "model_plane_mirror.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model"]

    def setup(self):
        if self.gui:
            mirror_box = self.gui.get_object("ModelMirrorBox")
            mirror_box.unparent()
            self.core.register_ui("model_handling", "Mirror", mirror_box, 0)
            self._gtk_handlers = ((self.gui.get_object("PlaneMirrorButton"), "clicked",
                                   self._plane_mirror), )
            self._event_handlers = (("model-selection-changed", self._update_plane_widgets), )
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_plane_widgets()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)

    def _update_plane_widgets(self):
        plane_widget = self.gui.get_object("ModelMirrorBox")
        if self.core.get("models").get_selected():
            plane_widget.show()
        else:
            plane_widget.hide()

    def _plane_mirror(self, widget=None):
        models = self.core.get("models").get_selected()
        if not models:
            return
        for plane, matrix in (("XY", [[1, 0, 0], [0, 1, 0], [0, 0, -1]]),
                              ("XZ", [[1, 0, 0], [0, -1, 0], [0, 0, 1]]),
                              ("YZ", [[-1, 0, 0], [0, 1, 0], [0, 0, 1]])):
            if self.gui.get_object("MirrorPlane%s" % plane).get_active():
                break
        else:
            assert False, "No mirror plane selected"
        for model in models:
            model.extend_value("transformations",
                               [{"action": "multiply_matrix", "matrix": matrix}])
