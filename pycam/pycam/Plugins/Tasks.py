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

import time

from pycam.errors import PycamBaseException
from pycam.Flow.history import merge_history_and_block_events
import pycam.Plugins
import pycam.Utils
from pycam.Utils.progress import ProgressContext
import pycam.workspace.data_models


class Tasks(pycam.Plugins.ListPluginBase):

    UI_FILE = "tasks.ui"
    CATEGORIES = ["Task"]
    DEPENDS = ["Models", "Tools", "Processes", "Bounds", "Toolpaths"]
    COLLECTION_ITEM_TYPE = pycam.workspace.data_models.Task

    def setup(self):
        if self.gui:
            self._gtk_handlers = []
            task_frame = self.gui.get_object("TaskBox")
            task_frame.unparent()
            self.core.register_ui("main", "Tasks", task_frame, weight=40)
            self._taskview = self.gui.get_object("TaskView")
            self.set_gtk_modelview(self._taskview)
            self.register_model_update(lambda: self.core.emit_event("task-list-changed"))
            for action, obj_name in ((self.ACTION_UP, "TaskMoveUp"),
                                     (self.ACTION_DOWN, "TaskMoveDown"),
                                     (self.ACTION_DELETE, "TaskDelete")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            self._gtk_handlers.append((self.gui.get_object("TaskNew"), "clicked", self._task_new))
            # parameters
            parameters_box = self.gui.get_object("TaskParameterBox")

            def clear_parameter_widgets():
                parameters_box.foreach(parameters_box.remove)

            def add_parameter_widget(item, name):
                # create a frame within an alignment and the item inside
                if item.get_parent():
                    item.unparent()
                frame_label = self._gtk.Label()
                frame_label.set_markup("<b>%s</b>" % name)
                frame = self._gtk.Frame()
                frame.set_label_widget(frame_label)
                align = self._gtk.Alignment()
                frame.add(align)
                align.set_padding(0, 3, 12, 3)
                align.add(item)
                frame.show_all()
                parameters_box.pack_start(frame, expand=False, fill=False, padding=0)

            self.core.register_ui_section("task_parameters", add_parameter_widget,
                                          clear_parameter_widgets)
            self.core.get("register_parameter_group")(
                "task", changed_set_event="task-type-changed",
                changed_set_list_event="task-type-list-changed",
                get_related_parameter_names=self._get_type_parameter_names)
            self.models_widget = pycam.Gui.ControlsGTK.ParameterSection()
            self.core.register_ui_section("task_models", self.models_widget.add_widget,
                                          self.models_widget.clear_widgets)
            self.core.register_ui("task_parameters", "Collision models",
                                  self.models_widget.get_widget(), weight=20)
            self.components_widget = pycam.Gui.ControlsGTK.ParameterSection()
            self.core.register_ui_section("task_components", self.components_widget.add_widget,
                                          self.components_widget.clear_widgets)
            self.core.register_ui("task_parameters", "Components",
                                  self.components_widget.get_widget(), weight=10)
            # table
            self._gtk_handlers.append((self.gui.get_object("NameCell"), "edited",
                                       self.edit_item_name))
            selection = self._taskview.get_selection()
            self._gtk_handlers.append((selection, "changed", "task-selection-changed"))
            selection.set_mode(self._gtk.SelectionMode.MULTIPLE)
            self._treemodel = self.gui.get_object("TaskList")
            self._treemodel.clear()
            # generate toolpaths
            self._gtk_handlers.extend((
                (self.gui.get_object("GenerateToolPathButton"), "clicked",
                 self._generate_selected_toolpaths),
                (self.gui.get_object("GenerateAllToolPathsButton"), "clicked",
                 self._generate_all_toolpaths)))
            # shape selector
            self._gtk_handlers.append((self.gui.get_object("TaskTypeSelector"), "changed",
                                       "task-type-changed"))
            # define cell renderers
            self.gui.get_object("NameColumn").set_cell_data_func(self.gui.get_object("NameCell"),
                                                                 self.render_item_name)
            self._event_handlers = (
                ("task-type-list-changed", self._update_task_type_widgets),
                ("task-selection-changed", self._update_task_widgets),
                ("task-selection-changed", self._update_toolpath_buttons),
                ("task-changed", self._update_task_widgets),
                ("task-changed", self.force_gtk_modelview_refresh),
                ("task-list-changed", self.force_gtk_modelview_refresh),
                ("task-list-changed", self._update_toolpath_buttons),
                ("task-control-changed", self._transfer_controls_to_task))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_toolpath_buttons()
            self._update_task_type_widgets()
            self._update_task_widgets()
        self.register_state_item("tasks", self)
        self.core.set("tasks", self)
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main", self.gui.get_object("TaskBox"))
            self.core.unregister_ui("task_parameters", self.models_widget)
            self.core.unregister_ui("task_parameters", self.components_widget)
            self.core.unregister_ui_section("task_models")
            self.core.unregister_ui_section("task_components")
            self.core.unregister_ui_section("task_parameters")
            self.core.get("unregister_parameter_group")("task")
        self.clear_state_items()
        self.clear()

    def _get_type_parameter_names(self):
        the_type = self._get_type()
        return set() if the_type is None else set(the_type["parameters"].keys())

    def _get_type(self, name=None):
        types = self.core.get("get_parameter_sets")("task")
        if name is None:
            # find the currently selected one
            selector = self.gui.get_object("TaskTypeSelector")
            model = selector.get_model()
            index = selector.get_active()
            if index < 0:
                return None
            type_name = model[index][1]
        else:
            type_name = name
        if type_name in types:
            return types[type_name]
        else:
            return None

    def select_type(self, name):
        selector = self.gui.get_object("TaskTypeSelector")
        for index, row in enumerate(selector.get_model()):
            if row[1] == name:
                selector.set_active(index)
                break
        else:
            selector.set_active(-1)

    def _update_task_type_widgets(self):
        model = self.gui.get_object("TaskTypeList")
        model.clear()
        types = list(self.core.get("get_parameter_sets")("task").values())
        for one_type in sorted(types, key=lambda item: item["weight"]):
            model.append((one_type["label"], one_type["name"]))
        # check if any on the processes became obsolete due to a missing plugin
        type_names = [one_type["name"] for one_type in types]
        for task in self.get_all():
            if task.get_value("type") not in type_names:
                self.get_collection().remove(task)
        # show "new" only if a strategy is available
        self.gui.get_object("TaskNew").set_sensitive(len(model) > 0)
        selector_box = self.gui.get_object("TaskChooserBox")
        if len(model) < 2:
            selector_box.hide()
        else:
            selector_box.show()

    def _update_toolpath_buttons(self):
        selected_toolpaths = self.get_selected()
        if selected_toolpaths is None:
            selected_toolpaths = []
        self.gui.get_object("GenerateToolPathButton").set_sensitive(len(selected_toolpaths) > 0)
        self.gui.get_object("GenerateAllToolPathsButton").set_sensitive(len(self.get_all()) > 0)

    def _update_task_widgets(self):
        tasks = self.get_selected()
        control_box = self.gui.get_object("TaskDetails")
        if len(tasks) != 1:
            control_box.hide()
        else:
            task = tasks[0]
            with self.core.blocked_events({"task-control-changed"}):
                task_type = task.get_value("type").value
                self.select_type(task_type)
                self.core.get("set_parameter_values")("task", task.get_dict())
                control_box.show()
                # trigger an update of the task parameter widgets based on the task type
                self.core.emit_event("task-type-changed")

    def _transfer_controls_to_task(self, widget=None):
        tasks = self.get_selected()
        if len(tasks) == 1:
            task = tasks[0]
            task_type = self._get_type()
            task.set_value("type", task_type["name"])
            for key, value in self.core.get("get_parameter_values")("task").items():
                task.set_value(key, value)

    def _task_new(self, widget=None, task_type="milling"):
        with merge_history_and_block_events(self.core):
            params = {"type": task_type}
            params.update(self.core.get("get_default_parameter_values")("task",
                                                                        set_name=task_type))
            new_task = pycam.workspace.data_models.Task(None, data=params)
            new_task.set_application_value("name", self.get_non_conflicting_name("Task #%d"))
        self.select(new_task)

    def generate_toolpaths(self, tasks):
        with ProgressContext("Generate Toolpaths") as progress:
            progress.set_multiple(len(tasks), "Toolpath")
            for task in tasks:
                if not self.generate_toolpath(task, callback=progress.update):
                    # break out of the loop, if cancel was requested
                    break
                progress.update_multiple()
        # This explicit event is necessary as the initial event hits the toolpath visualiation
        # plugin while the path is being calculated (i.e.: it is not displayed without
        # "show_progress").
        self.core.emit_event("toolpath-list-changed")

    def _generate_selected_toolpaths(self, widget=None):
        tasks = self.get_selected()
        self.generate_toolpaths(tasks)

    def _generate_all_toolpaths(self, widget=None):
        self.generate_toolpaths(self.get_all())

    def generate_toolpath(self, task, callback=None):
        start_time = time.time()
        if callback:
            callback(text="Preparing toolpath generation")
        self.core.set("current_tool", task.get_value("tool").get_tool_geometry())
        # run the toolpath generation
        if callback:
            callback(text="Calculating the toolpath")
        new_toolpath = pycam.workspace.data_models.Toolpath(
            None, {"source": {"type": "task", "item": task.get_id()}})
        try:
            # generate the toolpath (filling the cache) and check if it is empty
            if new_toolpath.get_toolpath() is None:
                self.log.warning("An empty toolpath was generated.")
        except PycamBaseException as exc:
            # an error occurred - "toolpath" contains the error message
            self.log.error("Failed to generate toolpath: %s", exc)
            # we were not successful (similar to a "cancel" request)
            return False
        except Exception:
            # catch all non-system-exiting exceptions
            self.log.error(pycam.Utils.get_exception_report())
            return False
        finally:
            self.core.set("current_tool", None)
            self.core.set("toolpath_in_progress", None)
        self.log.info("Toolpath generation time: %f", time.time() - start_time)
        # return "False" if the action was cancelled
        if callback:
            return not callback()
        else:
            return True
