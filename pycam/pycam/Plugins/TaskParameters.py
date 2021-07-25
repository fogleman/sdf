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


import pycam.Gui.ControlsGTK
import pycam.Plugins


class TaskParamCollisionModels(pycam.Plugins.PluginBase):

    DEPENDS = ["Models", "Tasks"]
    CATEGORIES = ["Model", "Task", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputTable(
            [], change_handler=lambda widget=None: self.core.emit_event("task-control-changed"))
        # The usual height of "-1" seems to hide this widget at least for the GTK version
        # shipped with 12.04 and 13.04 - see https://github.com/SebKuzminsky/pycam/issues/43.
        self.control.get_widget().set_size_request(240, 120)
        self.core.get("register_parameter")("task", "collision_models", self.control)
        self.core.register_ui("task_models", "", self.control.get_widget(), weight=5)
        self.core.register_event("model-list-changed", self._update_models)
        self.core.register_event("model-changed", self._update_models)
        return True

    def teardown(self):
        self.core.unregister_event("model-changed", self._update_models)
        self.core.unregister_event("model-list-changed", self._update_models)
        self.core.get("unregister_parameter")("task", "collision_models")
        self.core.unregister_ui("task_models", self.control.get_widget())

    def _update_models(self):
        choices = []
        for model in self.core.get("models").get_all():
            if hasattr(model.get_model(), "triangles"):
                choices.append((model.get_application_value("name", model.get_id()),
                                model.get_id()))
        self.control.update_choices(choices)


class TaskParamTool(pycam.Plugins.PluginBase):

    DEPENDS = ["Tools", "Tasks"]
    CATEGORIES = ["Tool", "Task", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            [], change_handler=lambda widget=None: self.core.emit_event("task-control-changed"))
        self.core.get("register_parameter")("task", "tool", self.control)
        self.core.register_ui("task_components", "Tool", self.control.get_widget(), weight=10)
        self.core.register_event("tool-list-changed", self._update_tools)
        return True

    def teardown(self):
        self.core.unregister_event("tool-list-changed", self._update_tools)
        self.core.get("unregister_parameter")("task", "tool")
        self.core.unregister_ui("task_models", self.control.get_widget())

    def _update_tools(self):
        choices = []
        for tool in self.core.get("tools").get_all():
            choices.append((tool.get_application_value("name", tool.get_id()), tool.get_id()))
        self.control.update_choices(choices)


class TaskParamProcess(pycam.Plugins.PluginBase):

    DEPENDS = ["Processes", "Tasks"]
    CATEGORIES = ["Process", "Task", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            [], change_handler=lambda widget=None: self.core.emit_event("task-control-changed"))
        self.core.get("register_parameter")("task", "process", self.control)
        self.core.register_ui("task_components", "Process", self.control.get_widget(), weight=20)
        self.core.register_event("process-list-changed", self._update_processes)
        return True

    def teardown(self):
        self.core.unregister_event("process-list-changed", self._update_processes)
        self.core.get("unregister_parameter")("task", "process")
        self.core.unregister_ui("task_models", self.control.get_widget())

    def _update_processes(self):
        choices = []
        for process in self.core.get("processes").get_all():
            choices.append((process.get_application_value("name", process.get_id()),
                            process.get_id()))
        self.control.update_choices(choices)


class TaskParamBounds(pycam.Plugins.PluginBase):

    DEPENDS = ["Bounds", "Tasks"]
    CATEGORIES = ["Bounds", "Task", "Parameter"]

    def setup(self):
        self.control = pycam.Gui.ControlsGTK.InputChoice(
            [], change_handler=lambda widget=None: self.core.emit_event("task-control-changed"))
        self.core.get("register_parameter")("task", "bounds", self.control)
        self.core.register_ui("task_components", "Bounds", self.control.get_widget(), weight=30)
        self.core.register_event("bounds-list-changed", self._update_bounds)
        return True

    def teardown(self):
        self.core.unregister_event("bounds-list-changed", self._update_bounds)
        self.core.get("unregister_parameter")("task", "bounds")
        self.core.unregister_ui("task_models", self.control.get_widget())

    def _update_bounds(self):
        choices = []
        bounds = self.core.get("bounds")
        for bound in bounds.get_all():
            choices.append((bound.get_application_value("name", bound.get_id()), bound.get_id()))
        self.control.update_choices(choices)
