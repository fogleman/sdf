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


import datetime
import os
import re

import pycam.Plugins
import pycam.Utils


class Log(pycam.Plugins.PluginBase):

    UI_FILE = "log.ui"
    DEPENDS = ["Clipboard"]
    CATEGORIES = ["System"]

    def setup(self):
        if not self._gtk:
            return False
        if self.gui:
            # menu item and shortcut
            log_action = self.gui.get_object("ToggleLogWindow")
            self._gtk_handlers = []
            self._gtk_handlers.append((log_action, "toggled", self.toggle_log_window))
            self.register_gtk_accelerator("log", log_action, "<Control>l", "ToggleLogWindow")
            self.core.register_ui("view_menu", "ToggleLogWindow", log_action, 100)
            # status bar
            self.status_bar = self.gui.get_object("StatusBar")
            event_bar = self.gui.get_object("StatusBarEventBox")
            self._gtk_handlers.append((event_bar, "button-press-event", self.toggle_log_window))
            event_bar.unparent()
            self.core.register_ui("main_window", "Status", event_bar, 100)
            # "log" window
            self.log_window = self.gui.get_object("LogWindow")
            self.log_window.set_default_size(500, 400)
            hide_window = lambda *args: self.toggle_log_window(value=False)
            self._gtk_handlers.extend([
                (self.log_window, "delete-event", hide_window),
                (self.log_window, "destroy", hide_window),
                (self.gui.get_object("LogWindowClose"), "clicked", hide_window),
                (self.gui.get_object("LogWindowClear"), "clicked", self.clear_log_window),
                (self.gui.get_object("LogWindowCopyToClipboard"), "clicked",
                 self.copy_log_to_clipboard)])
            self.log_model = self.gui.get_object("LogWindowList")
            # window state
            self._log_window_position = None
            # register a callback for the log window
            pycam.Utils.log.add_hook(self.add_log_message)
            self.register_gtk_handlers(self._gtk_handlers)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.log_window.hide()
            log_action = self.gui.get_object("ToggleLogWindow")
            self.core.unregister_ui("view_menu", log_action)
            self.unregister_gtk_accelerator("log", log_action)
            self.core.unregister_ui("main_window", self.gui.get_object("StatusBarEventBox"))
            self.core.unregister_ui("view_menu", self.gui.get_object("ToggleLogWindow"))
            # TODO: disconnect the log handler

    def add_log_message(self, title, message, record=None):
        timestamp = datetime.datetime.fromtimestamp(record.created).strftime("%H:%M")
        # avoid the ugly character for a linefeed
        message = " ".join(message.splitlines())
        self.log_model.append((timestamp, title, message))
        # update the status bar (if the GTK interface is still active)
        if self.status_bar.get_parent() is not None:
            # remove the last message from the stack (probably not necessary)
            self.status_bar.pop(0)
            # push the new message
            try:
                self.status_bar.push(0, message)
            except TypeError:
                new_message = re.sub(r"[^\w\s]", "", message)
                self.status_bar.push(0, new_message)
            # highlight the "warning" icon for warnings/errors
            if record and record.levelno > 20:
                self.gui.get_object("StatusBarWarning").show()

    def copy_log_to_clipboard(self, widget=None):
        def copy_row(model, path, it, content):
            columns = []
            for column in range(model.get_n_columns()):
                columns.append(model.get_value(it, column))
            content.append(" ".join(columns))
        content = []
        self.log_model.foreach(copy_row, content)
        self.core.get("clipboard-set")(os.linesep.join(content))
        self.gui.get_object("StatusBarWarning").hide()

    def clear_log_window(self, widget=None):
        self.log_model.clear()
        self.gui.get_object("StatusBarWarning").hide()

    def toggle_log_window(self, widget=None, value=None, action=None):
        toggle_log_checkbox = self.gui.get_object("ToggleLogWindow")
        checkbox_state = toggle_log_checkbox.get_active()
        if value is None:
            new_state = checkbox_state
        elif isinstance(value, self._gdk.Event):
            # someone clicked at the status bar -> toggle the window state
            new_state = not checkbox_state
        else:
            if action is None:
                new_state = value
            else:
                new_state = action
        if new_state:
            if self._log_window_position:
                self.log_window.move(*self._log_window_position)
            self.log_window.show()
        else:
            self._log_window_position = self.log_window.get_position()
            self.log_window.hide()
        toggle_log_checkbox.set_active(new_state)
        self.gui.get_object("StatusBarWarning").hide()
        # don't destroy the window with a "destroy" event
        return True
