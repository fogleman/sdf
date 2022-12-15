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
import pycam.Toolpath.MotionGrid


class ProcessStrategySlicing(pycam.Plugins.PluginBase):

    DEPENDS = ["ParameterGroupManager", "PathParamOverlap", "PathParamStepDown",
               "PathParamMaterialAllowance", "PathParamPattern"]
    CATEGORIES = ["Process"]

    def setup(self):
        parameters = {"overlap": 0.1,
                      "step_down": 1.0,
                      "material_allowance": 0,
                      "path_pattern": None}
        self.core.get("register_parameter_set")("process", "slice", "Slice removal", None,
                                                parameters=parameters, weight=10)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("process", "slice")


class ProcessStrategyContour(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "PathParamStepDown", "PathParamMaterialAllowance",
               "PathParamMillingStyle"]
    CATEGORIES = ["Process"]

    def setup(self):
        parameters = {"step_down": 1.0,
                      "material_allowance": 0,
                      "overlap": 0.8,
                      "milling_style": pycam.Toolpath.MotionGrid.MillingStyle.IGNORE}
        self.core.get("register_parameter_set")("process", "contour", "Waterline", None,
                                                parameters=parameters, weight=20)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("process", "contour")


class ProcessStrategySurfacing(pycam.Plugins.PluginBase):

    DEPENDS = ["ParameterGroupManager", "PathParamOverlap", "PathParamMaterialAllowance",
               "PathParamPattern"]
    CATEGORIES = ["Process"]

    def setup(self):
        parameters = {"overlap": 0.6,
                      "material_allowance": 0,
                      "path_pattern": None}
        self.core.get("register_parameter_set")("process", "surface", "Surfacing", None,
                                                parameters=parameters, weight=50)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("process", "surface")


class ProcessStrategyEngraving(pycam.Plugins.PluginBase):

    DEPENDS = ["ParameterGroupManager", "PathParamStepDown", "PathParamMillingStyle",
               "PathParamRadiusCompensation", "PathParamTraceModel", "PathParamPocketingType"]
    CATEGORIES = ["Process"]

    def setup(self):
        parameters = {"step_down": 1.0,
                      "milling_style": pycam.Toolpath.MotionGrid.MillingStyle.IGNORE,
                      "radius_compensation": False,
                      "trace_models": [],
                      "pocketing_type": pycam.Toolpath.MotionGrid.PocketingType.NONE}
        self.core.get("register_parameter_set")("process", "engrave", "Engraving", None,
                                                parameters=parameters, weight=80)
        return True

    def teardown(self):
        self.core.get("unregister_parameter_set")("process", "engrave")
