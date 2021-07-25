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
from pycam.Gui.ControlsGTK import InputCheckBox, InputNumber


class ToolParamRadius(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        self.control = InputNumber(
            lower=0.001, digits=4,
            change_handler=lambda widget=None: self.core.emit_event("tool-control-changed"))
        self.control.set_conversion(set_conv=lambda value: value * 2.0,
                                    get_conv=lambda value: value / 2.0)
        self.core.get("register_parameter")("tool", "radius", self.control)
        self.core.register_ui("tool_size", "Tool Diameter", self.control.get_widget(), weight=10)
        return True

    def teardown(self):
        self.core.get("unregister_parameter")("tool", "radius")
        self.core.unregister_ui("tool_size", self.control.get_widget())


class ToolParamToroidRadius(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        self.control = InputNumber(
            lower=0.001, digits=4,
            change_handler=lambda widget=None: self.core.emit_event("tool-control-changed"))
        self.core.get("register_parameter")("tool", "toroid_radius", self.control)
        self.core.register_ui("tool_size", "Toroid Radius", self.control.get_widget(), weight=50)
        return True

    def teardown(self):
        self.core.unregister_ui("tool_size", self.control.get_widget())
        self.core.get("unregister_parameter")("tool", "toroid_radius")


class ToolParamFeedrate(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        self.control = InputNumber(
            lower=1, digits=0,
            change_handler=lambda widget=None: self.core.emit_event("tool-control-changed"))
        self.core.get("register_parameter")("tool", "feed", self.control)
        self.core.register_ui("tool_speed", "Feedrate", self.control.get_widget(), weight=10)
        return True

    def teardown(self):
        self.core.unregister_ui("tool_speed", self.control.get_widget())
        self.core.get("unregister_parameter")("tool", "feed")


class ToolParamSpindle(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        self.controls = []
        for attribute, label, weight, control_class, extra in (
                ("spin_up_enabled", "Spindle Spin-Up/Spin-Down", 30, InputCheckBox, {}),
                ("speed", "Spindle Speed", 40, InputNumber, {"lower": 1, "digits": 0}),
                ("spin_up_delay", "Spindle Spin-Up Delay", 50, InputNumber,
                 {"lower": 0, "digits": 0})):
            control = control_class(
                change_handler=lambda widget=None: self.core.emit_event("tool-control-changed"),
                **extra)
            self.core.get("register_parameter")("tool", ("spindle", attribute), control)
            self.core.register_ui("tool_spindle", label, control.get_widget(), weight=weight)
            self.controls.append((control, attribute))
        return True

    def teardown(self):
        for control, attribute in self.controls:
            self.core.get("unregister_parameter")("tool", ("spindle", attribute))
            self.core.unregister_ui("tool_spindle", control.get_widget())
