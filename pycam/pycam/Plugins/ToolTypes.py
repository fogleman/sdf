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
import pycam.Cutters.SphericalCutter
import pycam.Cutters.ToroidalCutter
import pycam.Cutters.CylindricalCutter


def tool_params_and_filters(*param_names):
    def get_params_and_filters_inner(func):
        def get_tool_func(self, parameters):
            filters = []
            self.core.call_chain("toolpath_filters", "tool", parameters, filters)
            args = []
            for param_name in param_names:
                args.append(parameters[param_name])
            cutter = func(self, *args)
            return cutter, filters
        return get_tool_func
    return get_params_and_filters_inner


class ToolTypeBallNose(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools", "ToolParamRadius", "ToolParamFeedrate"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        parameters = {"radius": 1.0,
                      "feed": 300,
                      ("spindle", "speed"): 1000,
                      ("spindle", "spin_up_enabled"): True,
                      ("spindle", "spin_up_delay"): 3}
        self.core.get("register_parameter_set")("tool", "ball_nose", "Ball nose", self.get_tool,
                                                parameters=parameters, weight=20)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("tool", "ball_nose")

    @tool_params_and_filters("radius")
    def get_tool(self, radius):
        return pycam.Cutters.SphericalCutter.SphericalCutter(radius)


class ToolTypeBullNose(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools", "ToolParamRadius", "ToolParamToroidRadius", "ToolParamFeedrate"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        parameters = {"radius": 1.0,
                      "toroid_radius": 0.25,
                      "feed": 300,
                      ("spindle", "speed"): 1000,
                      ("spindle", "spin_up_enabled"): True,
                      ("spindle", "spin_up_delay"): 3}
        self.core.get("register_parameter_set")("tool", "torus", "Bull nose", self.get_tool,
                                                parameters=parameters, weight=30)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("tool", "torus")

    @tool_params_and_filters("radius", "toroid_radius")
    def get_tool(self, radius, toroid_radius):
        return pycam.Cutters.ToroidalCutter.ToroidalCutter(radius, toroid_radius)


class ToolTypeFlat(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools", "ToolParamRadius", "ToolParamFeedrate"]
    CATEGORIES = ["Tool", "Parameter"]

    def setup(self):
        parameters = {"radius": 1.0,
                      "feed": 300,
                      ("spindle", "speed"): 1000,
                      ("spindle", "spin_up_enabled"): True,
                      ("spindle", "spin_up_delay"): 3}
        self.core.get("register_parameter_set")("tool", "flat_bottom", "Flat bottom",
                                                self.get_tool, parameters=parameters, weight=10)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("tool", "flat_bottom")

    @tool_params_and_filters("radius")
    def get_tool(self, radius):
        return pycam.Cutters.CylindricalCutter.CylindricalCutter(radius)
