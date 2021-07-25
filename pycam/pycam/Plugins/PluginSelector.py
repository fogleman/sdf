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

import os

import pycam.Plugins


class PluginSelector(pycam.Plugins.PluginBase):

    UI_FILE = "plugin_selector.ui"
    CATEGORIES = ["Plugins"]
    COLUMN_NAME, COLUMN_DESCRIPTION, COLUMN_ENABLED, COLUMN_DEPENDS, COLUMN_DEPENDS_OK, \
        COLUMN_SOURCE = range(6)

    def setup(self):
        if self.gui:
            self.plugin_window = self.gui.get_object("PluginManagerWindow")
            self._gtk_handlers = []
            self._gtk_handlers.extend((
                (self.plugin_window, "delete-event", self.toggle_plugin_window, False),
                (self.plugin_window, "destroy", self.toggle_plugin_window, False)))
            self._gtk_handlers.append((self.gui.get_object("ClosePluginManager"), "clicked",
                                       self.toggle_plugin_window, False))
            self._treemodel = self.gui.get_object("PluginsModel")
            self._treemodel.clear()
            action = self.gui.get_object("TogglePluginWindow")
            self._gtk_handlers.append((action, "toggled", self.toggle_plugin_window))
            self.register_gtk_accelerator("plugins", action, None, "TogglePluginWindow")
            self.core.register_ui("view_menu", "TogglePluginWindow", action, 60)
            # model filters
            model_filter = self.gui.get_object("PluginsModel").filter_new()
            for obj_name in ("StatusFilter", "CategoryFilter"):
                self._gtk_handlers.append((self.gui.get_object(obj_name), "changed",
                                           lambda widget: model_filter.refilter()))
            self.gui.get_object("PluginsTable").set_model(model_filter)
            model_filter.set_visible_func(self._filter_set_visible)
            self._gtk_handlers.append((self.gui.get_object("PluginsEnabledCell"), "toggled",
                                       self.toggle_plugin_state))
            self.core.register_event("plugin-list-changed", self._update_plugin_model)
            self.register_gtk_handlers(self._gtk_handlers)
            self._update_plugin_model()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.plugin_window.hide()
            action = self.gui.get_object("TogglePluginWindow")
            self.core.unregister_ui("view_menu", action)
            self.core.unregister_event("plugin-list-changed", self._update_plugin_model)

    def toggle_plugin_window(self, widget=None, value=None, action=None):
        toggle_plugin_button = self.gui.get_object("TogglePluginWindow")
        checkbox_state = toggle_plugin_button.get_active()
        if value is None:
            new_state = checkbox_state
        else:
            if action is None:
                new_state = value
            else:
                new_state = action
        if new_state:
            self.plugin_window.show()
        else:
            self.plugin_window.hide()
        toggle_plugin_button.set_active(new_state)
        # don't destroy the window with a "destroy" event
        return True

    def _filter_set_visible(self, model, m_iter, data):
        manager = self.core.get("plugin-manager")
        status_filter = self.gui.get_object("StatusFilter")
        status_index = status_filter.get_active()
        if status_index > 0:
            status_name = status_filter.get_model()[status_index][1]
        cat_filter = self.gui.get_object("CategoryFilter")
        cat_index = cat_filter.get_active()
        if cat_index > 0:
            cat_name = cat_filter.get_model()[cat_index][0]
        plugin_name = model.get_value(m_iter, 0)
        if not plugin_name:
            return False
        plugin = manager.get_plugin(plugin_name)
        if (cat_index > 0) and (cat_name not in plugin.CATEGORIES):
            return False
        elif (status_index > 0):
            if (status_name == "enabled") and not manager.get_plugin_state(plugin_name):
                return False
            elif (status_name == "disabled") and manager.get_plugin_state(plugin_name):
                return False
            elif (status_name == "dep_missing") \
                    and not manager.get_plugin_missing_dependencies(plugin_name):
                return False
            elif (status_name == "dep_satisfied") \
                    and (manager.get_plugin_state(plugin_name)
                         or manager.get_plugin_missing_dependencies(plugin_name)):
                return False
            elif (status_name == "not_required") \
                    and (not manager.get_plugin_state(plugin_name)
                         or manager.is_plugin_required(plugin_name)
                         or (plugin_name == "PluginSelector")):
                return False
        return True

    def _update_plugin_model(self):
        manager = self.core.get("plugin-manager")
        names = manager.get_plugin_names()
        model = self._treemodel
        model.clear()
        categories = {}
        for name in names:
            plugin = manager.get_plugin(name)
            for cat_name in plugin.CATEGORIES:
                categories[cat_name] = True
            enabled = manager.get_plugin_state(name)
            depends_missing = manager.get_plugin_missing_dependencies(name)
            is_required = manager.is_plugin_required(name)
            satisfied = not (bool(depends_missing) or is_required)
            # never disable the manager
            if plugin == self:
                satisfied = False
            depends_markup = []
            for depend in plugin.DEPENDS:
                if depend in depends_missing:
                    depends_markup.append('<span foreground="red">%s</span>' % depend)
                else:
                    depends_markup.append(depend)
            model.append((name, "Beschreibung", enabled, os.linesep.join(depends_markup),
                          satisfied, "Hint"))
        self.gui.get_object("PluginsDescriptionColumn").queue_resize()
        self.gui.get_object("PluginsTable").queue_resize()
        # update the category filter
        categories = list(categories.keys())
        categories.sort()
        categories.insert(0, "All categories")
        model = self.gui.get_object("CategoryList")
        cat_index = self.gui.get_object("CategoryFilter").get_active()
        if cat_index >= 0:
            cat_selection = model[cat_index][0]
        else:
            cat_selection = None
        model.clear()
        for cat_name in categories:
            model.append((cat_name, ))
        if cat_selection in categories:
            cat_index = categories.index(cat_selection)
        else:
            cat_index = 0
        self.gui.get_object("CategoryFilter").set_active(cat_index)
        # status selection
        status_selector = self.gui.get_object("StatusFilter")
        if status_selector.get_active() < 0:
            status_selector.set_active(0)
        # trigger an update of the filter model
        self.gui.get_object("PluginsTable").get_model().refilter()

    def toggle_plugin_state(self, cell, path):
        filter_model = self.gui.get_object("PluginsTable").get_model()
        plugin_name = filter_model[int(path)][self.COLUMN_NAME]
        manager = self.core.get("plugin-manager")
        enabled = manager.get_plugin_state(plugin_name)
        if enabled:
            manager.disable_plugin(plugin_name)
        else:
            manager.enable_plugin(plugin_name)
        self._update_plugin_model()
