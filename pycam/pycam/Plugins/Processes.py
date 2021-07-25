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

from pycam.Flow.history import merge_history_and_block_events
import pycam.Plugins
import pycam.workspace.data_models


class Processes(pycam.Plugins.ListPluginBase):

    DEPENDS = ["ParameterGroupManager"]
    CATEGORIES = ["Process"]
    UI_FILE = "processes.ui"
    COLLECTION_ITEM_TYPE = pycam.workspace.data_models.Process

    def setup(self):
        self.core.set("processes", self)
        if self.gui and self._gtk:
            process_frame = self.gui.get_object("ProcessBox")
            process_frame.unparent()
            self._gtk_handlers = []
            self.core.register_ui("main", "Processes", process_frame, weight=20)
            self._modelview = self.gui.get_object("ProcessEditorTable")
            self.set_gtk_modelview(self._modelview)
            self.register_model_update(lambda: self.core.emit_event("process-list-changed"))
            for action, obj_name in ((self.ACTION_UP, "ProcessMoveUp"),
                                     (self.ACTION_DOWN, "ProcessMoveDown"),
                                     (self.ACTION_DELETE, "ProcessDelete")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            self._gtk_handlers.append((self.gui.get_object("ProcessNew"), "clicked",
                                       self._process_new))
            # parameters
            parameters_box = self.gui.get_object("ProcessParametersBox")

            def clear_parameter_widgets():
                parameters_box.foreach(parameters_box.remove)

            def add_parameter_widget(item, name):
                # create a frame with an align and the item inside
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
                parameters_box.pack_start(frame, expand=False, fill=True, padding=0)

            self.core.register_ui_section("process_parameters", add_parameter_widget,
                                          clear_parameter_widgets)
            self.core.get("register_parameter_group")(
                "process", changed_set_event="process-strategy-changed",
                changed_set_list_event="process-strategy-list-changed",
                get_related_parameter_names=self._get_selected_strategy_parameter_names)
            self.parameter_widget = pycam.Gui.ControlsGTK.ParameterSection()
            self.core.register_ui_section("process_path_parameters",
                                          self.parameter_widget.add_widget,
                                          self.parameter_widget.clear_widgets)
            self.core.register_ui("process_parameters", "Path parameters",
                                  self.parameter_widget.get_widget(), weight=10)
            self._gtk_handlers.append((self._modelview.get_selection(), "changed",
                                       "process-selection-changed"))
            self._gtk_handlers.append((self.gui.get_object("NameCell"), "edited",
                                       self.edit_item_name))
            self._treemodel = self.gui.get_object("ProcessList")
            self._treemodel.clear()
            self._gtk_handlers.append((self.gui.get_object("StrategySelector"), "changed",
                                       "process-control-changed"))
            # define cell renderers
            self.gui.get_object("NameColumn").set_cell_data_func(
                self.gui.get_object("NameCell"), self.render_item_name)
            self.gui.get_object("DescriptionColumn").set_cell_data_func(
                self.gui.get_object("DescriptionCell"), self._render_process_description)
            self._event_handlers = (
                ("process-strategy-list-changed", self._update_strategy_widgets),
                ("process-selection-changed", self._update_process_widgets),
                ("process-changed", self._update_process_widgets),
                ("process-changed", self.force_gtk_modelview_refresh),
                ("process-list-changed", self.force_gtk_modelview_refresh),
                ("process-control-changed", self._transfer_controls_to_process))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self.select_strategy(None)
            self._update_strategy_widgets()
            self._update_process_widgets()
        self.register_state_item("processes", self)
        self.core.register_namespace("processes", pycam.Plugins.get_filter(self))
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main", self.gui.get_object("ProcessBox"))
            self.core.unregister_ui_section("process_path_parameters")
            self.core.unregister_ui("process_parameters", self.parameter_widget.get_widget())
            self.core.unregister_ui_section("process_parameters")
            self.core.get("unregister_parameter_group")("process")
        self.clear_state_items()
        self.core.unregister_namespace("processes")
        self.core.set("processes", None)
        self.clear()
        return True

    def _render_process_description(self, column, cell, model, m_iter, data):
        # TODO: describe the strategy
        text = "TODO"
#       process = self.get_by_path(model.get_path(m_iter))
        cell.set_property("text", text)

    def _update_strategy_widgets(self):
        model = self.gui.get_object("StrategyModel")
        model.clear()
        strategies = list(self.core.get("get_parameter_sets")("process").values())
        strategies.sort(key=lambda item: item["weight"])
        for strategy in strategies:
            model.append((strategy["label"], strategy["name"]))
        # check if any on the processes became obsolete due to a missing plugin
        removal = []
        strat_names = [strategy["name"] for strategy in strategies]
        for index, process in enumerate(self.get_all()):
            if not process.get_value("strategy").value in strat_names:
                removal.append(index)
        removal.reverse()
        collection = self.get_collection()
        for index in removal:
            del collection[index]
        # show "new" only if a strategy is available
        self.gui.get_object("ProcessNew").set_sensitive(len(model) > 0)
        selector_box = self.gui.get_object("ProcessSelectorBox")
        if len(model) < 2:
            selector_box.hide()
        else:
            selector_box.show()

    def _get_selected_strategy_parameter_names(self):
        strategy = self._get_selected_strategy()
        return set() if strategy is None else set(strategy["parameters"].keys())

    def _get_selected_strategy(self, name=None):
        """ get a strategy object - either based on the given name or the currently selected one
        """
        strategies = self.core.get("get_parameter_sets")("process")
        if name is None:
            # find the currently selected one
            selector = self.gui.get_object("StrategySelector")
            model = selector.get_model()
            index = selector.get_active()
            if index < 0:
                return None
            strategy_name = model[index][1]
        else:
            strategy_name = name
        if strategy_name in strategies:
            return strategies[strategy_name]
        else:
            return None

    def select_strategy(self, name):
        selector = self.gui.get_object("StrategySelector")
        for index, row in enumerate(selector.get_model()):
            if row[1] == name:
                selector.set_active(index)
                break
        else:
            selector.set_active(-1)

    def _transfer_controls_to_process(self):
        process = self.get_selected()
        strategy = self._get_selected_strategy()
        if process and strategy:
            process.set_value("strategy", strategy["name"])
            value_set = self.core.get("get_parameter_values")("process")
            if "path_pattern" in value_set:
                value_set.update(self.core.get("get_parameter_values")("path_pattern"))
            for key, value in value_set.items():
                process.set_value(key, value)

    def _update_process_widgets(self, widget=None, data=None):
        process = self.get_selected()
        control_box = self.gui.get_object("ProcessSettingsControlsBox")
        if process is None:
            control_box.hide()
        else:
            with self.core.blocked_events({"process-control-changed",
                                           "process-strategy-changed",
                                           "process-path-pattern-changed"}):
                strategy_name = process.get_value("strategy").value
                self.select_strategy(strategy_name)
                data_dict = process.get_dict()
                self.core.get("set_parameter_values")("process", data_dict)
                if "path_pattern" in data_dict:
                    self.core.get("set_parameter_values")("path_pattern", data_dict)
                control_box.show()
            self.core.emit_event("process-strategy-changed")
            self.core.emit_event("process-changed")

    def _process_new(self, widget=None, strategy="slice"):
        with merge_history_and_block_events(self.core):
            params = {"strategy": strategy}
            params.update(self.core.get("get_default_parameter_values")("process",
                                                                        set_name=strategy))
            new_process = pycam.workspace.data_models.Process(None, data=params)
            new_process.set_application_value("name", self.get_non_conflicting_name("Process #%d"))
        self.select(new_process)
