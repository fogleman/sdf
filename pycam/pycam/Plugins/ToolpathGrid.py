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


class ToolpathGrid(pycam.Plugins.PluginBase):

    UI_FILE = "toolpath_grid.ui"
    DEPENDS = ["Toolpaths"]
    CATEGORIES = ["Toolpath"]

    def setup(self):
        if self.gui:
            self._gtk_handlers = []
            self._frame = self.gui.get_object("ToolpathGridFrame")
            self.core.register_ui("toolpath_handling", "Clone grid", self._frame, 30)
            for objname in ("GridYCount", "GridXCount"):
                self.gui.get_object(objname).set_value(1)
            for objname in ("GridYCount", "GridXCount", "GridYDistance", "GridXDistance"):
                self._gtk_handlers.append((self.gui.get_object(objname), "value-changed",
                                           self._update_widgets))
            self._gtk_handlers.append((self.gui.get_object("GridCreate"), "clicked",
                                       self.create_toolpath_grid))
            self.core.register_event("toolpath-selection-changed", self._update_widgets)
            self.register_gtk_handlers(self._gtk_handlers)
            self._update_widgets()
        return True

    def teardown(self):
        if self.gui:
            self.core.unregister_event("toolpath-selection-changed", self._update_widgets)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("toolpath_handling", self._frame)

    def _get_toolpaths_dim(self, toolpaths):
        """ calculate the maximum dimensions for x and y of all toolpaths """
        # collect non-empty toolpaths
        paths = [path for path in (tp.get_toolpath() for tp in toolpaths) if path]
        if paths:
            maxx = max([path.maxx for path in paths])
            minx = min([path.minx for path in paths])
            maxy = max([path.maxy for path in paths])
            miny = min([path.miny for path in paths])
            return (maxx - minx), (maxy - miny)
        else:
            return None, None

    def _update_widgets(self, widget=None):
        toolpaths = self.core.get("toolpaths").get_selected()
        if toolpaths:
            x_dim, y_dim = self._get_toolpaths_dim(toolpaths)
        if toolpaths and (x_dim is not None) and (y_dim is not None):
            x_count = self.gui.get_object("GridXCount").get_value()
            x_space = self.gui.get_object("GridXDistance").get_value()
            y_count = self.gui.get_object("GridYCount").get_value()
            y_space = self.gui.get_object("GridYDistance").get_value()
            x_width = x_dim * x_count + x_space * (x_count - 1)
            y_width = y_dim * y_count + y_space * (y_count - 1)
            self.gui.get_object("LabelGridXWidth").set_label(
                "%g%s" % (x_width, self.core.get("unit_string")))
            self.gui.get_object("LabelGridYWidth").set_label(
                "%g%s" % (y_width, self.core.get("unit_string")))
            self._frame.show()
        else:
            self._frame.hide()

    def create_toolpath_grid(self, widget=None):
        x_count = int(self.gui.get_object("GridXCount").get_value())
        y_count = int(self.gui.get_object("GridYCount").get_value())
        x_space = self.gui.get_object("GridXDistance").get_value()
        y_space = self.gui.get_object("GridYDistance").get_value()
        for toolpath in self.core.get("toolpaths").get_selected():
            toolpath.append_transformation(
                {"action": "clone", "offset": [x_space, 0, 0], "clone_count": x_count})
            toolpath.append_transformation(
                {"action": "clone", "offset": [0, y_space, 0], "clone_count": y_count})
