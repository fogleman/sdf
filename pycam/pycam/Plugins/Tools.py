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
from pycam.Flow.history import merge_history_and_block_events
import pycam.workspace.data_models


class Tools(pycam.Plugins.ListPluginBase):

    DEPENDS = ["ParameterGroupManager"]
    CATEGORIES = ["Tool"]
    UI_FILE = "tools.ui"
    COLLECTION_ITEM_TYPE = pycam.workspace.data_models.Tool

    def setup(self):
        self.core.set("tools", self)
        if self.gui:
            tool_frame = self.gui.get_object("ToolBox")
            tool_frame.unparent()
            self.core.register_ui("main", "Tools", tool_frame, weight=10)
            self._gtk_handlers = []
            self._modelview = self.gui.get_object("ToolTable")
            self.set_gtk_modelview(self._modelview)
            self.register_model_update(lambda: self.core.emit_event("tool-list-changed"))
            for action, obj_name in ((self.ACTION_UP, "ToolMoveUp"),
                                     (self.ACTION_DOWN, "ToolMoveDown"),
                                     (self.ACTION_DELETE, "ToolDelete")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            self._gtk_handlers.append((self.gui.get_object("ToolNew"), "clicked", self._tool_new))
            # parameters
            parameters_box = self.gui.get_object("ToolParameterBox")

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
                parameters_box.pack_start(frame, expand=True, fill=True, padding=0)

            self.core.register_ui_section("tool_parameters", add_parameter_widget,
                                          clear_parameter_widgets)
            self.core.get("register_parameter_group")(
                "tool", changed_set_event="tool-shape-changed",
                changed_set_list_event="tool-shape-list-changed",
                get_related_parameter_names=self._get_selected_shape_parameter_names)
            self.size_widget = pycam.Gui.ControlsGTK.ParameterSection()
            self.core.register_ui("tool_parameters", "Size", self.size_widget.get_widget(),
                                  weight=10)
            self.core.register_ui_section("tool_size", self.size_widget.add_widget,
                                          self.size_widget.clear_widgets)
            self.speed_widget = pycam.Gui.ControlsGTK.ParameterSection()
            self.core.register_ui("tool_parameters", "Speed", self.speed_widget.get_widget(),
                                  weight=20)
            self.core.register_ui_section("tool_speed", self.speed_widget.add_widget,
                                          self.speed_widget.clear_widgets)
            self.spindle_widget = pycam.Gui.ControlsGTK.ParameterSection()
            self.core.register_ui("tool_parameters", "Spindle", self.spindle_widget.get_widget(),
                                  weight=30)
            self.core.register_ui_section("tool_spindle", self.spindle_widget.add_widget,
                                          self.spindle_widget.clear_widgets)
            # table updates
            cell = self.gui.get_object("ShapeCell")
            self.gui.get_object("ShapeColumn").set_cell_data_func(cell, self._render_tool_shape)
            self._gtk_handlers.append((self.gui.get_object("IDCell"), "edited",
                                       self._edit_tool_id))
            self._gtk_handlers.append((self.gui.get_object("NameCell"), "edited",
                                       self.edit_item_name))
            # selector
            self._gtk_handlers.append((self._modelview.get_selection(), "changed",
                                       "tool-selection-changed"))
            # shape selector
            self._gtk_handlers.append((self.gui.get_object("ToolShapeSelector"), "changed",
                                       "tool-control-changed"))
            # define cell renderers
            self.gui.get_object("IDColumn").set_cell_data_func(
                self.gui.get_object("IDCell"), self._render_tool_info, "tool_id")
            self.gui.get_object("NameColumn").set_cell_data_func(
                self.gui.get_object("NameCell"), self._render_tool_info, "name")
            self.gui.get_object("ShapeColumn").set_cell_data_func(
                self.gui.get_object("ShapeCell"), self._render_tool_shape)
            self._event_handlers = (
                ("tool-shape-list-changed", self._update_shape_widgets),
                ("tool-selection-changed", self._update_tool_widgets),
                ("tool-changed", self._update_tool_widgets),
                ("tool-changed", self.force_gtk_modelview_refresh),
                ("tool-list-changed", self.force_gtk_modelview_refresh),
                ("tool-control-changed", self._transfer_controls_to_tool))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_shape_widgets()
            self._update_tool_widgets()
        self.core.register_namespace("tools", pycam.Plugins.get_filter(self))
        self.register_state_item("tools", self)
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main", self.gui.get_object("ToolBox"))
            self.core.unregister_ui_section("tool_speed")
            self.core.unregister_ui_section("tool_size")
            self.core.unregister_ui("tool_parameters", self.size_widget.get_widget())
            self.core.unregister_ui("tool_parameters", self.speed_widget.get_widget())
            self.core.unregister_ui("tool_parameters", self.spindle_widget.get_widget())
            self.core.unregister_ui_section("tool_parameters")
            self.core.get("unregister_parameter_group")("tool")
        self.clear_state_items()
        self.core.unregister_namespace("tools")
        self.core.set("tools", None)
        self.clear()
        return True

    def _render_tool_info(self, column, cell, model, m_iter, key):
        tool = self.get_by_path(model.get_path(m_iter))
        if key in ("tool_id", ):
            text = tool.get_value(key)
        else:
            text = tool.get_application_value(key)
        cell.set_property("text", str(text))

    def _render_tool_shape(self, column, cell, model, m_iter, data):
        tool = self.get_by_path(model.get_path(m_iter))
        text = "%g%s" % (tool.diameter, self.core.get("unit"))
        cell.set_property("text", text)

    def _edit_tool_id(self, cell, path, new_text):
        tool = self.get_by_path(path)
        try:
            new_value = int(new_text)
        except ValueError:
            return
        if tool and (new_value != tool.get_value("tool_id")):
            tool.set_value("tool_id", new_value)

    def _get_selected_shape_parameter_names(self):
        shape = self._get_selected_shape()
        return set() if shape is None else set(shape["parameters"].keys())

    def _get_selected_shape(self, name=None):
        shapes = self.core.get("get_parameter_sets")("tool")
        if name is None:
            # find the currently selected one
            selector = self.gui.get_object("ToolShapeSelector")
            model = selector.get_model()
            index = selector.get_active()
            if index < 0:
                return None
            shape_name = model[index][1]
        else:
            shape_name = name
        if shape_name in shapes:
            return shapes[shape_name]
        else:
            return None

    def select_shape(self, name):
        selector = self.gui.get_object("ToolShapeSelector")
        for index, row in enumerate(selector.get_model()):
            if row[1] == name:
                selector.set_active(index)
                break
        else:
            selector.set_active(-1)

    def _update_shape_widgets(self):
        """update controls that depend on the list of available shapes"""
        model = self.gui.get_object("ToolShapeList")
        model.clear()
        shapes = list(self.core.get("get_parameter_sets")("tool").values())
        shapes.sort(key=lambda item: item["weight"])
        for shape in shapes:
            model.append((shape["label"], shape["name"]))
        # check if any on the tools became obsolete due to a missing plugin
        shape_names = [shape["name"] for shape in shapes]
        for tool in self.get_all():
            if not tool.get_value("shape").value in shape_names:
                self.get_collection().remove(tool)
        # show "new" only if a strategy is available
        self.gui.get_object("ToolNew").set_sensitive(len(model) > 0)
        selector_box = self.gui.get_object("ToolSelectorBox")
        if len(model) < 2:
            selector_box.hide()
        else:
            selector_box.show()

    def _update_tool_widgets(self, widget=None):
        """transfer the content of the currently selected tool to the related widgets"""
        tool = self.get_selected()
        control_box = self.gui.get_object("ToolSettingsControlsBox")
        if tool is None:
            control_box.hide()
        else:
            with self.core.blocked_events({"tool-control-changed"}):
                shape_name = tool.get_value("shape").value
                self.select_shape(shape_name)
                self.core.get("set_parameter_values")("tool", tool.get_dict())
                control_box.show()
                # trigger an update of the tool parameter widgets based on the shape
                self.core.emit_event("tool-shape-changed")

    def _transfer_controls_to_tool(self):
        """the value of a tool-related control was changed by by the user

        The changed value needs to be transferred to the currently selected tool.
        """
        tool = self.get_selected()
        shape = self._get_selected_shape()
        if tool and shape:
            tool.set_value("shape", shape["name"])
            for key, value in self.core.get("get_parameter_values")("tool").items():
                tool.set_value(key, value)

    def _tool_new(self, widget=None, shape="flat_bottom"):
        # look for an unused tool ID
        existing_tool_ids = [tool.get_value("tool_id") for tool in self.get_all()]
        tool_id = 1
        while tool_id in existing_tool_ids:
            tool_id += 1
        with merge_history_and_block_events(self.core):
            params = {"shape": shape, "tool_id": tool_id}
            params.update(self.core.get("get_default_parameter_values")("tool", set_name=shape))
            new_tool = pycam.workspace.data_models.Tool(None, data=params)
            new_tool.set_application_value("name", self.get_non_conflicting_name("Tool #%d"))
        self.select(new_tool)
