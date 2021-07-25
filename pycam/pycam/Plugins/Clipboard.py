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

from io import StringIO

import pycam.Plugins
from pycam.Utils.locations import get_all_program_locations


CLIPBOARD_TARGETS = {
    "dxf": ("image/vnd.dxf", ),
    "ps": ("application/postscript", ),
    "stl": ("application/sla", ),
    "svg": ("image/x-inkscape-svg", "image/svg+xml"),
}


class Clipboard(pycam.Plugins.PluginBase):

    UI_FILE = "clipboard.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["System"]

    def setup(self):
        if not self._gtk:
            return False
        if self.gui:
            self._gtk_handlers = []
            self.clipboard = self._gtk.Clipboard.get(self._gdk.SELECTION_PRIMARY)
            self.core.set("clipboard-set", self._copy_text_to_clipboard)
            self._gtk_handlers.append((self.clipboard, "owner-change",
                                       self._update_clipboard_widget))
            # menu item and shortcut
            self.copy_action = self.gui.get_object("CopyModelToClipboard")
            self._gtk_handlers.append((self.copy_action, "activate", self.copy_model_to_clipboard))
            self.register_gtk_accelerator("clipboard", self.copy_action, "<Control>c",
                                          "CopyModelToClipboard")
            self.core.register_ui("edit_menu", "CopyModelToClipboard", self.copy_action, 20)
            self.paste_action = self.gui.get_object("PasteModelFromClipboard")
            self._gtk_handlers.append((self.paste_action, "activate",
                                       self.paste_model_from_clipboard))
            self.register_gtk_accelerator("clipboard", self.paste_action, "<Control>v",
                                          "PasteModelFromClipboard")
            self.core.register_ui("edit_menu", "PasteModelFromClipboard", self.paste_action, 25)
            self._event_handlers = (("model-selection-changed", self._update_clipboard_widget), )
            self.register_event_handlers(self._event_handlers)
            self.register_gtk_handlers(self._gtk_handlers)
            self._update_clipboard_widget()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.unregister_gtk_accelerator("clipboard", self.copy_action)
            self.core.unregister_ui("edit_menu", self.copy_action)
            self.unregister_gtk_accelerator("clipboard", self.paste_action)
            self.core.unregister_ui("edit_menu", self.paste_action)
            self.core.set("clipboard-set", None)

    def _get_exportable_models(self):
        models = self.core.get("models").get_selected()
        exportable = []
        for model in models:
            if model.get_model().is_export_supported():
                exportable.append(model)
        return exportable

    def _update_clipboard_widget(self, widget=None, data=None):
        models = self._get_exportable_models()
        # copy button
        self.gui.get_object("CopyModelToClipboard").set_sensitive(len(models) > 0)
        data, importer = self._get_data_and_importer_from_clipboard()
        paste_button = self.gui.get_object("PasteModelFromClipboard")
        paste_button.set_sensitive(data is not None)

    def _copy_text_to_clipboard(self, text, targets=None):
        if targets is None:
            self.clipboard.set_text(text)
        else:
            if targets in CLIPBOARD_TARGETS:
                targets = CLIPBOARD_TARGETS[targets]
            clip_targets = [(key, self._gtk.TARGET_OTHER_WIDGET, index)
                            for index, key in enumerate(targets)]

            def get_func(clipboard, selectiondata, info, extra_args):
                text, clip_type = extra_args
                selectiondata.set(clip_type, 8, text)

            if "svg" in "".join(targets).lower():
                # Inkscape for Windows strictly requires the BITMAP type
                clip_type = self._gdk.SELECTION_TYPE_BITMAP
            else:
                clip_type = self._gdk.SELECTION_TYPE_STRING
            self.clipboard.set_with_data(clip_targets, get_func, lambda *args: None,
                                         (text, clip_type))
            self.clipboard.store()

    def copy_model_to_clipboard(self, widget=None):
        models = self._get_exportable_models()
        if not models:
            return
        text_buffer = StringIO()

        # TODO: use a better way to discover the "merge" ability
        def same_type(m1, m2):
            return isinstance(m1, pycam.Geometry.Model.ContourModel) == \
                    isinstance(m2, pycam.Geometry.Model.ContourModel)

        merged_model = models.pop(0).get_model()
        for model in models:
            # merge only 3D _or_ 2D models (don't mix them)
            other_model = model.get_model()
            if same_type(merged_model, other_model):
                merged_model += other_model
        # TODO: add "comment=get_meta_data()" here
        merged_model.export(unit=self.core.get("unit")).write(text_buffer)
        text_buffer.seek(0)
        is_contour = isinstance(merged_model, pycam.Geometry.Model.ContourModel)
        # TODO: this should not be decided here
        if is_contour:
            targets = CLIPBOARD_TARGETS["svg"]
        else:
            targets = CLIPBOARD_TARGETS["stl"]
        self._copy_text_to_clipboard(text_buffer.read(), targets)

    def _get_data_and_importer_from_clipboard(self):
        for targets, filename in ((CLIPBOARD_TARGETS["svg"], "foo.svg"),
                                  (CLIPBOARD_TARGETS["stl"], "foo.stl"),
                                  (CLIPBOARD_TARGETS["ps"], "foo.ps"),
                                  (CLIPBOARD_TARGETS["dxf"], "foo.dxf")):
            for target in targets:
                atom = self._gdk.Atom.intern(target, False)
                data = self.clipboard.wait_for_contents(atom)
                if data is not None:
                    detected_filetype = pycam.Importers.detect_file_type(filename)
                    if detected_filetype:
                        return data, detected_filetype.importer
                    else:
                        return None, None
        return None, None

    def paste_model_from_clipboard(self, widget=None):
        data, importer = self._get_data_and_importer_from_clipboard()
        progress = self.core.get("progress")
        if data:
            progress.update(text="Loading model from clipboard")
            text_buffer = StringIO(data.data)
            model = importer(text_buffer, program_locations=get_all_program_locations(self.core),
                             unit=self.core.get("unit"), fonts_cache=self.core.get("fonts"),
                             callback=progress.update)
            if model:
                models = self.core.get("models")
                self.log.info("Loaded a model from clipboard")
                models.add_model(model, name_template="Pasted model #%d")
            else:
                self.log.warn("Failed to load a model from clipboard")
        else:
            self.log.warn("The clipboard does not contain suitable data")
        progress.finish()
