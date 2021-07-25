"""
Copyright 2012 Lars Kruse <devel@sumpfralle.de>

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


import csv
from io import StringIO

import pycam.Plugins
import pycam.Utils.log

_log = pycam.Utils.log.get_logger()


class MemoryAnalyzer(pycam.Plugins.PluginBase):

    UI_FILE = "memory_analyzer.ui"
    DEPENDS = ["Clipboard"]
    CATEGORIES = ["System"]

    def setup(self):
        if not self._gtk:
            return False
        if self.gui:
            # menu item and shortcut
            self.toggle_action = self.gui.get_object("ToggleMemoryAnalyzerAction")
            self._gtk_handlers = []
            self._gtk_handlers.append((self.toggle_action, "toggled", self.toggle_window))
            self.register_gtk_accelerator("memory_analyzer", self.toggle_action, None,
                                          "ToggleMemoryAnalyzerAction")
            self.core.register_ui("view_menu", "ToggleMemoryAnalyzerAction", self.toggle_action,
                                  80)
            # the window
            self.window = self.gui.get_object("MemoryAnalyzerWindow")
            self.window.set_default_size(500, 400)
            hide_window = lambda *args: self.toggle_window(value=False)
            self._gtk_handlers.extend([
                (self.window, "delete-event", hide_window),
                (self.window, "destroy", hide_window),
                (self.gui.get_object("MemoryAnalyzerCloseButton"), "clicked", hide_window),
                (self.gui.get_object("MemoryAnalyzerCopyButton"), "clicked",
                 self.copy_to_clipboard),
                (self.gui.get_object("MemoryAnalyzerRefreshButton"), "clicked",
                 self.refresh_memory_analyzer)])
            self.model = self.gui.get_object("MemoryAnalyzerModel")
            # window state
            self._window_position = None
            # check if "heapy" is available - this disables all widgets
            try:
                import guppy
            except ImportError:
                self._guppy = None
                self.gui.get_object("MemoryAnalyzerDataBox").hide()
            else:
                self._guppy = guppy
                self.gui.get_object("MemoryAnalyzerBrokenLabel").hide()
            self.register_gtk_handlers(self._gtk_handlers)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.window.hide()
            self.core.unregister_ui("view_menu", self.toggle_action)
            self.unregister_gtk_accelerator("memory_analyzer", self.toggle_action)

    def toggle_window(self, widget=None, value=None, action=None):
        checkbox_state = self.toggle_action.get_active()
        if value is None:
            new_state = checkbox_state
        elif action is None:
            new_state = value
        else:
            new_state = action
        if new_state:
            if self._window_position:
                self.window.move(*self._window_position)
            self.refresh_memory_analyzer()
            self.window.show()
        else:
            self._window_position = self.window.get_position()
            self.window.hide()
        self.toggle_action.set_active(new_state)
        # don't destroy the window with a "destroy" event
        return True

    def refresh_memory_analyzer(self, widget=None):
        self.model.clear()
        self.gui.get_object("MemoryAnalyzerLoadingLabel").show()
        for objname in ("MemoryAnalyzerRefreshButton", "MemoryAnalyzerCopyButton"):
            self.gui.get_object(objname).set_sensitive(False)
        self._gobject.idle_add(self._refresh_data_in_background)

    def _refresh_data_in_background(self):
        if not self._guppy:
            return
        memory_state = self._guppy.hpy().heap()
        for row in memory_state.stat.get_rows():
            item = (row.name, row.count, row.size / 1024, row.size / row.count)
            self.model.append(item)
        for objname in ("MemoryAnalyzerRefreshButton", "MemoryAnalyzerCopyButton"):
            self.gui.get_object(objname).set_sensitive(True)
        self.gui.get_object("MemoryAnalyzerRefreshButton").set_sensitive(True)
        self.gui.get_object("MemoryAnalyzerLoadingLabel").hide()

    def copy_to_clipboard(self, widget=None):
        text_buffer = StringIO()
        writer = csv.writer(text_buffer)
        writer.writerow(("Type", "Count", "Size (all) [kB]", "Average size [B]"))
        for row in self.model:
            writer.writerow(row)
        self.core.get("clipboard-set")(text_buffer.getvalue())
        text_buffer.close()
