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


class ModelSwapAxes(pycam.Plugins.PluginBase):

    UI_FILE = "model_swap_axes.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model"]

    def setup(self):
        if self.gui:
            swap_box = self.gui.get_object("ModelSwapBox")
            swap_box.unparent()
            self.core.register_ui("model_handling", "Swap axes", swap_box, 0)
            self._gtk_handlers = ((self.gui.get_object("SwapAxesButton"), "clicked",
                                   self._swap_axes), )
            self._event_handlers = (("model-selection-changed", self._update_controls), )
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_controls()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("model_handling", self.gui.get_object("ModelSwapBox"))

    def _update_controls(self):
        box = self.gui.get_object("ModelSwapBox")
        if self.core.get("models").get_selected():
            box.show()
        else:
            box.hide()

    def _swap_axes(self, widget=None):
        models = self.core.get("models").get_selected()
        if not models:
            return
        for axes, matrix in (("XY", [[0, 1, 0], [1, 0, 0], [0, 0, 1]]),
                             ("XZ", [[0, 0, 1], [0, 1, 0], [1, 0, 0]]),
                             ("YZ", [[1, 0, 0], [0, 0, 1], [0, 1, 0]])):
            if self.gui.get_object("SwapAxes%s" % axes).get_active():
                break
        else:
            assert False, "No axis selected"
        for model in models:
            model.extend_value("transformations",
                               [{"action": "multiply_matrix", "matrix": matrix}])
