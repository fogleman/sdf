"""
Copyright 2017 Lars Kruse <devel@sumpfralle.de>

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
from pycam.workspace.data_models import ToolpathFilter


class ExportSettings(pycam.Plugins.ListPluginBase):

    UI_FILE = "export_settings.ui"
    DEPENDS = ["Toolpaths", "ParameterGroupManager"]
    CATEGORIES = ["Toolpath", "Export"]
    COLLECTION_ITEM_TYPE = pycam.workspace.data_models.ExportSettings

    def setup(self):
        if self.gui:
            list_box = self.gui.get_object("ExportSettingsBox")
            list_box.unparent()
            self.core.register_ui("main", "Export Settings", list_box, weight=50)
            self._gtk_handlers = []
            modelview = self.gui.get_object("ExportSettingTable")
            self.set_gtk_modelview(modelview)
            self.register_model_update(
                lambda: self.core.emit_event("export-settings-list-changed"))
            for action, obj_name in ((self.ACTION_UP, "ExportSettingMoveUp"),
                                     (self.ACTION_DOWN, "ExportSettingMoveDown"),
                                     (self.ACTION_DELETE, "ExportSettingDelete"),
                                     (self.ACTION_CLEAR, "ExportSettingDeleteAll")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            self._gtk_handlers.append((self.gui.get_object("ExportSettingNew"), "clicked",
                                       self._export_setting_new))
            # details of export settings
            self.item_details_container = self.gui.get_object("ExportSettingHandlingNotebook")

            def clear_item_details_container():
                for index in range(self.item_details_container.get_n_pages()):
                    self.item_details_container.remove_page(0)

            def add_item_details_container(item, name):
                self.item_details_container.append_page(item, self._gtk.Label(name))

            self.core.register_ui_section("export_settings_handling", add_item_details_container,
                                          clear_item_details_container)
            # register UI sections for GCode settings
            self.core.register_ui_section(
                "gcode_preferences",
                lambda item, name: self.core.register_ui("export_settings_handling", name, item),
                lambda: self.core.clear_ui_section("export_settings_handling"))
            general_widget = pycam.Gui.ControlsGTK.ParameterSection()
            general_widget.get_widget().show()
            self.core.register_ui_section("gcode_general_parameters", general_widget.add_widget,
                                          general_widget.clear_widgets)
            self.core.register_ui("gcode_preferences", "General", general_widget.get_widget())
            self._profile_selector = pycam.Gui.ControlsGTK.InputChoice(
                [], change_handler=lambda widget=None: self.core.emit_event(
                    "toolpath-profiles-selection-changed"))
            profile_widget = self._profile_selector.get_widget()
            profile_widget.show()
            self.core.register_ui("gcode_general_parameters", "GCode Profile", profile_widget)
            self.core.get("register_parameter_group")(
                "toolpath_profile", changed_set_event="toolpath-profiles-selection-changed",
                changed_set_list_event="toolpath-profiles-list-changed",
                get_related_parameter_names=self._get_selected_profile_parameter_names)
            # handle table changes
            self._gtk_handlers.extend((
                (modelview, "row-activated", "export-settings-changed"),
                (self.gui.get_object("ExportSettingNameCell"), "edited", self.edit_item_name)))
            # handle selection changes
            selection = modelview.get_selection()
            self._gtk_handlers.append((selection, "changed", "export-settings-selection-changed"))
            # define cell renderers
            self.gui.get_object("ExportSettingNameColumn").set_cell_data_func(
                self.gui.get_object("ExportSettingNameCell"), self.render_item_name)
            self._event_handlers = (
                ("toolpath-profiles-list-changed", self._update_profiles),
                ("export-settings-selection-changed", self._transfer_settings_to_controls),
                ("export-settings-selection-changed", "visual-item-updated"),
                ("export-settings-changed", self._transfer_settings_to_controls),
                ("export-settings-changed", self.force_gtk_modelview_refresh),
                ("export-settings-changed", "visual-item-updated"),
                ("export-settings-list-changed", self.force_gtk_modelview_refresh),
                ("export-settings-list-changed", "visual-item-updated"),
                ("export-settings-control-changed", self._transfer_controls_to_settings))
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._transfer_settings_to_controls()
        self.core.set("export_settings", self)
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main", self.gui.get_object("ExportSettingsBox"))
            self.core.get("unregister_parameter_group")("toolpath_profile")
        self.core.set("export_settings", None)

    def _export_setting_new(self, widget=None):
        with merge_history_and_block_events(self.core):
            params = {"gcode": self.core.get("get_default_parameter_values")("toolpath_profile")}
            new_item = pycam.workspace.data_models.ExportSettings(None, data=params)
            new_item.set_application_value("name", self.get_non_conflicting_name("Settings #%d"))
        self.select(new_item)

    def _transfer_settings_to_controls(self, widget=None):
        """transfer the content of the currently selected setting item to the related widgets"""
        settings = self.get_selected()
        if settings is None:
            self.item_details_container.hide()
        else:
            with self.core.blocked_events({"export-settings-control-changed"}):
                gcode_settings = settings.get_settings_by_type("gcode")
                if not gcode_settings or (ToolpathFilter.SAFETY_HEIGHT.value in gcode_settings):
                    # it looks like a "milling" profile
                    profile = "milling"
                else:
                    profile = "laser"
                self.select_profile(profile)
                self.core.get("set_parameter_values")("toolpath_profile", gcode_settings)
                self.item_details_container.show()

    def _transfer_controls_to_settings(self):
        """the value of a control related to export settings was changed by by the user

        The changed value needs to be transferred to the currently selected export settings.
        """
        settings = self.get_selected()
        profile = self.get_selected_profile()
        if settings and profile:
            gcode_settings = settings.get_settings_by_type("gcode")
            for key, value in self.core.get("get_parameter_values")("toolpath_profile").items():
                gcode_settings[key] = value
            settings.set_settings_by_type("gcode", gcode_settings)

    def _update_profiles(self):
        selected = self.get_selected_profile()
        profiles = list(self.core.get("get_parameter_sets")("toolpath_profile").values())
        choices = []
        for profile in sorted(profiles, key=lambda item: item["weight"]):
            choices.append((profile["label"], profile["name"]))
        self._profile_selector.update_choices(choices)
        if selected:
            self.select_profile(selected)
        elif profiles:
            self.select_profile(None)
        else:
            pass

    def _get_selected_profile_parameter_names(self):
        profile = self.get_selected_profile()
        return set() if profile is None else set(profile["parameters"].keys())

    def get_selected_profile(self):
        all_profiles = self.core.get("get_parameter_sets")("toolpath_profile")
        current_name = self._profile_selector.get_value()
        return all_profiles.get(current_name, None)

    def select_profile(self, item=None):
        if isinstance(item, str):
            profile_name = item
        elif item is None:
            profile_name = None
        else:
            profile_name = item["name"]
        self._profile_selector.set_value(profile_name)
