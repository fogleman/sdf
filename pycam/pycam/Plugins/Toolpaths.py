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
import pycam.Toolpath
import pycam.workspace.data_models


class Toolpaths(pycam.Plugins.ListPluginBase):

    UI_FILE = "toolpaths.ui"
    CATEGORIES = ["Toolpath"]
    ICONS = {"visible": "visible.svg", "hidden": "visible_off.svg"}
    COLLECTION_ITEM_TYPE = pycam.workspace.data_models.Toolpath

    def setup(self):
        if self.gui:
            self.tp_box = self.gui.get_object("ToolpathsBox")
            self.tp_box.unparent()
            self.core.register_ui("main", "Toolpaths", self.tp_box, weight=50)
            self._gtk_handlers = []
            self._modelview = self.gui.get_object("ToolpathTable")
            self.set_gtk_modelview(self._modelview)
            self.register_model_update(lambda: self.core.emit_event("toolpath-list-changed"))
            self._treemodel = self.gui.get_object("ToolpathListModel")
            self._treemodel.clear()
            for action, obj_name in ((self.ACTION_UP, "ToolpathMoveUp"),
                                     (self.ACTION_DOWN, "ToolpathMoveDown"),
                                     (self.ACTION_DELETE, "ToolpathDelete"),
                                     (self.ACTION_CLEAR, "ToolpathDeleteAll")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            # toolpath operations
            toolpath_handling_obj = self.gui.get_object("ToolpathHandlingNotebook")

            def clear_toolpath_handling_obj():
                for index in range(toolpath_handling_obj.get_n_pages()):
                    toolpath_handling_obj.remove_page(0)

            def add_toolpath_handling_item(item, name):
                toolpath_handling_obj.append_page(item, self._gtk.Label(name))

            self.core.register_ui_section("toolpath_handling", add_toolpath_handling_item,
                                          clear_toolpath_handling_obj)
            # handle table changes
            self._gtk_handlers.extend((
                (self._modelview, "row-activated", self.toggle_item_visibility),
                (self._modelview, "row-activated", "toolpath-changed"),
                (self.gui.get_object("ToolpathNameCell"), "edited", self.edit_item_name)))
            # handle selection changes
            selection = self._modelview.get_selection()
            self._gtk_handlers.append((selection, "changed", "toolpath-selection-changed"))
            selection.set_mode(self._gtk.SelectionMode.MULTIPLE)
            # define cell renderers
            self.gui.get_object("ToolpathNameColumn").set_cell_data_func(
                self.gui.get_object("ToolpathNameCell"), self.render_item_name)
            self.gui.get_object("ToolpathTimeColumn").set_cell_data_func(
                self.gui.get_object("ToolpathTimeCell"), self._render_machine_time)
            self.gui.get_object("ToolpathVisibleColumn").set_cell_data_func(
                self.gui.get_object("ToolpathVisibleSymbol"), self.render_item_visible_state)
            self._event_handlers = (
                ("toolpath-list-changed", self._update_toolpath_tab_visibility),
                ("toolpath-list-changed", self.force_gtk_modelview_refresh))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_toolpath_tab_visibility()
        self.core.set("toolpaths", self)
        self.core.register_namespace("toolpaths", pycam.Plugins.get_filter(self))
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main", self.gui.get_object("ToolpathsBox"))
        self.core.unregister_namespace("toolpaths")
        self.core.set("toolpaths", None)

    def _update_toolpath_tab_visibility(self):
        has_toolpaths = len(self.get_all()) > 0
        if has_toolpaths:
            self.tp_box.show()
        else:
            self.tp_box.hide()

    def _render_machine_time(self, column, cell, model, m_iter, data):
        def get_time_string(minutes):
            if minutes > 180:
                return "%d hours" % int(round(minutes / 60))
            elif minutes > 3:
                return "%d minutes" % int(round(minutes))
            else:
                return "%d seconds" % int(round(minutes * 60))

        toolpath = self.get_by_path(model.get_path(m_iter))
        path = toolpath.get_toolpath()
        if path:
            text = get_time_string(path.get_machine_time())
        else:
            text = "empty"
        cell.set_property("text", text)
