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
import pycam.Utils


class ModelExport(pycam.Plugins.PluginBase):

    UI_FILE = "model_export.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Model", "Export"]

    def setup(self):
        if self.gui:
            self._gtk_handlers = []
            save_action = self.gui.get_object("SaveModel")
            self.register_gtk_accelerator("model", save_action, "<Control>s", "SaveModel")
            self._gtk_handlers.append((save_action, "activate", self.save_model))
            self.core.register_ui("file_menu", "SaveModel", save_action, 20)
            save_as_action = self.gui.get_object("SaveAsModel")
            self.register_gtk_accelerator("model", save_as_action, "<Control><Shift>s",
                                          "SaveAsModel")
            self._gtk_handlers.append((save_as_action, "activate", self.save_as_model))
            self.core.register_ui("file_menu", "SaveAsModel", save_as_action, 25)
            self._event_handlers = (("model-selection-changed", self._update_widgets), )
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            self._update_widgets()
        self.core.register_chain("model_export", self._fallback_model_export, weight=1000)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            save_action = self.gui.get_object("SaveModel")
            self.core.unregister_ui("file_menu", save_action)
            self.unregister_gtk_accelerator("model", save_action)
            save_as_action = self.gui.get_object("SaveAsModel")
            self.core.unregister_ui("file_menu", save_as_action)
            self.unregister_gtk_accelerator("model", save_as_action)
        self.core.unregister_chain("model_export", self._fallback_model_export)

    def _fallback_model_export(self, models):
        if models:
            self.log.info("Failed to export %d model(s)", len(models))

    def save_model(self, widget=None):
        # TODO: add "filename" property to models
        pass

    def save_as_model(self, widget=None, filename=None):
        self.core.call_chain("model_export", self.core.get("models").get_selected())

    def _update_widgets(self):
        models = self.core.get("models").get_selected()
        save_as_possible = len(models) > 0
        self.gui.get_object("SaveAsModel").set_sensitive(save_as_possible)
        # TODO: fix this
        save_possible = False and bool(self.core.last_model_uri
                                       and save_as_possible
                                       and self.core.last_model_uri.is_writable())
        # TODO: fix this dirty hack to avoid silent overwrites of PS/DXF files as SVG
        if save_possible:
            extension = os.path.splitext(self.core.last_model_uri.get_path())[-1].lower()
            # TODO: fix these hard-coded file extensions
            if extension[1:] in ("eps", "ps", "dxf"):
                # can't save 2D formats except SVG
                save_possible = False
        self.gui.get_object("SaveModel").set_sensitive(save_possible)


class ModelExportTrimesh(pycam.Plugins.PluginBase):

    DEPENDS = ["ModelExport"]

    def setup(self):
        self.core.register_chain("model_export", self.export_trimesh, weight=30)
        return True

    def teardown(self):
        self.core.unregister_chain("model_export", self.export_trimesh)

    def export_trimesh(self, models):
        removal_list = []
        for index, model in enumerate(models):
            if not hasattr(model.get_model(), "triangles"):
                continue
            # determine the file type
            # TODO: this needs to be decided by the exporter code
            type_filter = [("STL models", "*.stl")]
            model_name = model["name"]
            filename = self.core.get("get_filename_func")("Save model '%s' to ..." % model_name,
                                                          mode_load=False,
                                                          type_filter=type_filter,
                                                          filename_templates=[])
            if not filename:
                continue
            uri = pycam.Utils.URIHandler(filename)
            if not uri:
                continue
            if not uri.is_local():
                self.log.error("Unable to write file to a non-local destination: %s", uri)
                continue
            try:
                file_in = open(uri.get_local_path(), "w")
                # TODO: fill in "comment" with "meta_data"
                # TODO: call a specific exporter
                model.get_model().export(unit=self.core.get("unit")).write(file_in)
                file_in.close()
                removal_list.append(index)
            except IOError as err_msg:
                self.log.error("Failed to save model file: %s", err_msg)
            else:
                self.log.info("Successfully stored '%s' as '%s'.", filename, model_name)
        removal_list.reverse()
        for index in removal_list:
            models.pop(index)


class ModelExportContour(pycam.Plugins.PluginBase):

    DEPENDS = ["ModelExport"]

    def setup(self):
        self.core.register_chain("model_export", self.export_contour, weight=40)
        return True

    def teardown(self):
        self.core.unregister_chain("model_export", self.export_contour)

    def export_contour(self, models):
        removal_list = []
        for index, model in enumerate(models):
            if not hasattr(model.get_model(), "get_polygons"):
                continue
            # determine the file type
            # TODO: this needs to be decided by the exporter code
            type_filter = [("SVG models", "*.svg")]
            filename = self.core.get("get_filename_func")("Save model '%s' to ..." % model["name"],
                                                          mode_load=False,
                                                          type_filter=type_filter,
                                                          filename_templates=[])
            if not filename:
                continue
            uri = pycam.Utils.URIHandler(filename)
            if not uri:
                continue
            if not uri.is_local():
                self.log.error("Unable to write file to a non-local destination: %s", uri)
                continue
            try:
                file_in = open(uri.get_local_path(), "w")
                # TODO: fill in "comment" with "meta_data"
                # TODO: call a specific exporter
                model.get_model().export(unit=self.core.get("unit")).write(file_in)
                file_in.close()
                removal_list.append(index)
            except IOError as err_msg:
                self.log.error("Failed to save model file: %s", err_msg)
            else:
                self.log.info("Successfully stored '%s' as '%s'.", filename, model["name"])
        removal_list.reverse()
        for index in removal_list:
            models.pop(index)
