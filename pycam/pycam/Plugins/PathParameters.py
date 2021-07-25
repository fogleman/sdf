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
import pycam.Gui.ControlsGTK
import pycam.Toolpath.MotionGrid


class PathParamOverlap(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        # configure the input/output converter
        self.control = pycam.Gui.ControlsGTK.InputNumber(
            lower=0, upper=99, digits=0, increment=10,
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.control.set_conversion(
            set_conv=lambda float_value: int(float_value * 100.0),
            get_conv=lambda percent: percent / 100.0)
        self.core.get("register_parameter")("process", "overlap", self.control)
        self.core.register_ui("process_path_parameters", "Overlap [%]", self.control.get_widget(),
                              weight=10)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("process", "overlap")


class PathParamStepDown(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputNumber(
            lower=0.01, digits=2, start=1,
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("process", "step_down", self.control)
        self.core.register_ui("process_path_parameters", "Step down", self.control.get_widget(),
                              weight=20)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("process", "step_down")


class PathParamMaterialAllowance(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputNumber(
            start=0, lower=0, digits=2,
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("process", "material_allowance", self.control)
        self.core.register_ui("process_path_parameters", "Material allowance",
                              self.control.get_widget(), weight=30)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("process", "material_allowance")


class PathParamMillingStyle(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "PathParamPattern"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            (("ignore", pycam.Toolpath.MotionGrid.MillingStyle.IGNORE.value),
             ("climb / down", pycam.Toolpath.MotionGrid.MillingStyle.CLIMB.value),
             ("conventional / up", pycam.Toolpath.MotionGrid.MillingStyle.CONVENTIONAL.value)),
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("path_pattern", "milling_style", self.control)
        self.core.get("register_parameter")("process", "milling_style", self.control)
        self.core.register_ui("process_path_parameters", "Milling style",
                              self.control.get_widget(), weight=50)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("path_pattern", "milling_style")
        self.core.get("unregister_parameter")("process", "milling_style")


class PathParamGridDirection(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "PathParamPattern"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            (("x", pycam.Toolpath.MotionGrid.GridDirection.X.value),
             ("y", pycam.Toolpath.MotionGrid.GridDirection.Y.value),
             ("xy", pycam.Toolpath.MotionGrid.GridDirection.XY.value)),
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("path_pattern", "grid_direction", self.control)
        self.core.get("register_parameter")("process", "grid_direction", self.control)
        self.core.register_ui("process_path_parameters", "Direction", self.control.get_widget(),
                              weight=40)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("path_pattern", "grid_direction")
        self.core.get("unregister_parameter")("process", "grid_direction")


class PathParamSpiralDirection(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "PathParamPattern"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            (("outside -> center", pycam.Toolpath.MotionGrid.SpiralDirection.IN.value),
             ("center -> outside", pycam.Toolpath.MotionGrid.SpiralDirection.OUT.value)),
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("path_pattern", "spiral_direction", self.control)
        self.core.register_ui("process_path_parameters", "Direction", self.control.get_widget(),
                              weight=40)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("path_pattern", "spiral_direction")


class PathParamPattern(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "ParameterGroupManager"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.choices = []
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            [], change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("process", "path_pattern", self.control)
        self.core.get("register_parameter_group")(
            "path_pattern", changed_set_event="process-path-pattern-changed",
            changed_set_list_event="process-path-pattern-list-changed",
            get_related_parameter_names=self._get_pattern_parameter_names)
        self.core.register_ui("process_path_parameters", "Pattern", self.control.get_widget(),
                              weight=5)
        self._event_handlers = (
            ("process-path-pattern-list-changed", self._update_pattern_list_widget),
            ("process-changed", "process-path-pattern-changed"))
        self.register_event_handlers(self._event_handlers)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.unregister_event_handlers(self._event_handlers)
        self.core.get("unregister_parameter")("process", "path_pattern")
        self.core.get("unregister_parameter_group")("path_pattern")

    def _update_pattern_list_widget(self):
        patterns = list(self.core.get("get_parameter_sets")("path_pattern").values())
        patterns.sort(key=lambda item: item["weight"])
        self.choices = []
        for pattern in patterns:
            self.choices.append((pattern["label"], pattern["name"]))
        self.control.update_choices(self.choices)
        if not self.control.get_value() and self.choices:
            self.control.set_value({"name": self.choices[0][1], "parameters": {}})

    def _get_pattern_parameter_names(self):
        pattern_name = self.control.get_value()
        # The path pattern is not used for all process strategies. Thus we need to check, whether
        # we are currently in use (i.e. visible).
        is_visible = self.control.is_visible()
        if pattern_name and is_visible:
            pattern = self.core.get("get_parameter_sets")("path_pattern")[pattern_name]
            return set(pattern["parameters"].keys())
        else:
            return set()


class PathParamRoundedSpiralCorners(pycam.Plugins.PluginBase):

    DEPENDS = {"Processes", "PathParamPattern"}
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputCheckBox(
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("path_pattern", "rounded_corners", self.control)
        self.core.register_ui("process_path_parameters", "Rounded corners",
                              self.control.get_widget(), weight=80)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("path_pattern", "rounded_corners")


class PathParamRadiusCompensation(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputCheckBox(
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("process", "radius_compensation", self.control)
        self.core.register_ui("process_path_parameters", "Radius compensation",
                              self.control.get_widget(), weight=80)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("process", "radius_compensation")


class PathParamTraceModel(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "Models"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputTable(
            [], change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("process", "trace_models", self.control)
        self.core.register_ui("process_path_parameters", "Trace models (2D)",
                              self.control.get_widget(), weight=5)
        self.core.register_event("model-list-changed", self._update_models)
        self.core.register_event("model-changed", self._update_models)
        return True

    def teardown(self):
        self.core.unregister_event("model-changed", self._update_models)
        self.core.unregister_event("model-list-changed", self._update_models)
        self.core.get("unregister_parameter")("process", "trace_models")
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())

    def _update_models(self):
        choices = []
        for model in self.core.get("models").get_all():
            if hasattr(model.get_model(), "get_polygons"):
                choices.append((model.get_application_value("name", model.get_id()),
                                model.get_id()))
        self.control.update_choices(choices)


class PathParamPocketingType(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes"]
    CATEGORIES = ["Process", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            (("none", pycam.Toolpath.MotionGrid.PocketingType.NONE.value),
             ("holes", pycam.Toolpath.MotionGrid.PocketingType.HOLES.value),
             ("material", pycam.Toolpath.MotionGrid.PocketingType.MATERIAL.value)),
            change_handler=lambda widget=None: self.core.emit_event("process-control-changed"))
        self.core.get("register_parameter")("process", "pocketing_type", self.control)
        self.core.register_ui("process_path_parameters", "Pocketing", self.control.get_widget(),
                              weight=60)
        return True

    def teardown(self):
        self.core.unregister_ui("process_path_parameters", self.control.get_widget())
        self.core.get("unregister_parameter")("process", "pocketing_type")
