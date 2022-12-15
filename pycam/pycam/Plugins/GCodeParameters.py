"""
Copyright 2011-2012 Lars Kruse <devel@sumpfralle.de>

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
import pycam.Gui.ControlsGTK
from pycam.Toolpath import ToolpathPathMode


class GCodeSafetyHeight(pycam.Plugins.PluginBase):

    DEPENDS = ["ExportSettings"]
    CATEGORIES = ["GCode"]

    def setup(self):
        # TODO: update the current filters after a change
        self.control = pycam.Gui.ControlsGTK.InputNumber(
            digits=1,
            change_handler=lambda *args: self.core.emit_event("export-settings-control-changed"))
        self.core.get("register_parameter")("toolpath_profile", "safety_height", self.control)
        self.core.register_ui("gcode_general_parameters", "Safety Height",
                              self.control.get_widget(), weight=20)
        return True

    def teardown(self):
        self.core.unregister_ui("gcode_general_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("toolpath_profile", "safety_height")


class GCodePlungeFeedrate(pycam.Plugins.PluginBase):

    DEPENDS = ["ExportSettings"]
    CATEGORIES = ["GCode"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputNumber(
            digits=1,
            change_handler=lambda *args: self.core.emit_event("export-settings-control-changed"))
        self.core.get("register_parameter")("toolpath_profile", "plunge_feedrate", self.control)
        self.core.register_ui("gcode_general_parameters", "Plunge feedrate limit",
                              self.control.get_widget(), weight=25)
        return True

    def teardown(self):
        self.core.unregister_ui("gcode_general_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("toolpath_profile", "plunge_feedrate")


# TODO: move to settings for ToolpathOutputDialects
class GCodeFilenameExtension(pycam.Plugins.PluginBase):

    DEPENDS = ["ExportSettings"]
    CATEGORIES = ["GCode"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputString(
            max_length=6,
            change_handler=lambda *args: self.core.emit_event("export-settings-control-changed"))
        self.core.get("register_parameter")("toolpath_profile", "filename_extension",
                                            self.control)
        self.core.register_ui("gcode_general_parameters", "Custom GCode filename extension",
                              self.control.get_widget(), weight=80)
        return True

    def teardown(self):
        self.core.unregister_ui("gcode_general_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("toolpath_profile", "filename_extension")


class GCodeStepWidth(pycam.Plugins.PluginBase):

    DEPENDS = ["ExportSettings"]
    CATEGORIES = ["GCode"]

    def setup(self):
        self._table = pycam.Gui.ControlsGTK.ParameterSection()
        self.core.register_ui("gcode_preferences", "Step precision", self._table.get_widget())
        self.core.register_ui_section("gcode_step_width", self._table.add_widget,
                                      self._table.clear_widgets)
        self.controls = []
        for key in "xyz":
            control = pycam.Gui.ControlsGTK.InputNumber(
                digits=8, start=0.0001, increment=0.00005, lower=0.00000001,
                change_handler=lambda *args: self.core.emit_event(
                    "export-settings-control-changed"))
            # Somehow "unknown signal" warnings are emitted during "destroy" of the last two
            # widgets.  This feels like a namespace conflict, but there is no obvious cause.
            if key != "x":
                control.set_enable_destroy(False)
            self.core.register_ui("gcode_step_width", key.upper(), control.get_widget(),
                                  weight="xyz".index(key))
            self.core.get("register_parameter")("toolpath_profile", ("step_width", key), control)
            self.controls.append((key, control))
        return True

    def teardown(self):
        while self.controls:
            key, control = self.controls.pop()
            self.core.unregister_ui("gcode_step_width", control)
            self.core.get("unregister_parameter")("toolpath_profile", ("step_width", key))
        self.core.unregister_ui("gcode_general_parameters", self._table.get_widget())


class GCodeCornerStyle(pycam.Plugins.PluginBase):

    DEPENDS = ["ExportSettings"]
    CATEGORIES = ["GCode"]

    def setup(self):
        self._table = pycam.Gui.ControlsGTK.ParameterSection()
        self.core.register_ui("gcode_preferences", "Corner style", self._table.get_widget())
        self.core.register_ui_section("gcode_corner_style", self._table.add_widget,
                                      self._table.clear_widgets)
        self.motion_tolerance = pycam.Gui.ControlsGTK.InputNumber(
            digits=3, lower=0,
            change_handler=lambda *args: self.core.emit_event("export-settings-control-changed"))
        self.core.register_ui("gcode_corner_style", "Motion blending tolerance",
                              self.motion_tolerance.get_widget(), weight=30)
        self.core.get("register_parameter")(
            "toolpath_profile", ("corner_style", "motion_tolerance"), self.motion_tolerance)
        self.naive_tolerance = pycam.Gui.ControlsGTK.InputNumber(
            digits=3, lower=0,
            change_handler=lambda *args: self.core.emit_event("export-settings-control-changed"))
        self.core.register_ui("gcode_corner_style", "Naive CAM tolerance",
                              self.naive_tolerance.get_widget(), weight=50)
        self.core.get("register_parameter")(
            "toolpath_profile", ("corner_style", "naive_tolerance"), self.naive_tolerance)
        self.path_mode = pycam.Gui.ControlsGTK.InputChoice(
            (("Exact path mode (G61)", ToolpathPathMode.CORNER_STYLE_EXACT_PATH.value),
             ("Exact stop mode (G61.1)", ToolpathPathMode.CORNER_STYLE_EXACT_STOP.value),
             ("Continuous with maximum speed (G64)",
              ToolpathPathMode.CORNER_STYLE_OPTIMIZE_SPEED.value),
             ("Continuous with tolerance (G64 P/Q)",
              ToolpathPathMode.CORNER_STYLE_OPTIMIZE_TOLERANCE.value)),
            change_handler=lambda *args: self.core.emit_event("export-settings-control-changed"))
        self.path_mode.get_widget().connect("changed", self.update_widgets)
        self.core.register_ui("gcode_corner_style", "Path mode", self.path_mode.get_widget(),
                              weight=10)
        self.core.get("register_parameter")(
            "toolpath_profile", ("corner_style", "mode"), self.path_mode)
        self.update_widgets()
        return True

    def teardown(self):
        self.core.unregister_ui("gcode_corner_style", self.motion_tolerance.get_widget())
        self.core.unregister_ui("gcode_corner_style", self.naive_tolerance.get_widget())
        self.core.unregister_ui("gcode_corner_style", self.path_mode.get_widget())
        self.core.unregister_ui_section("gcode_corner_style")
        self.core.unregister_ui("gcode_preferences", self._table.get_widget())
        for name in ("motion_tolerance", "naive_tolerance", "mode"):
            self.core.get("unregister_parameter")("toolpath_profile", ("corner_style", name))

    def update_widgets(self, widget=None):
        enable_tolerances = (self.path_mode.get_value()
                             == ToolpathPathMode.CORNER_STYLE_OPTIMIZE_TOLERANCE)
        controls = (self.motion_tolerance, self.naive_tolerance)
        for control in controls:
            control.get_widget().set_sensitive(enable_tolerances)
