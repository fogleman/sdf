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

import code
from io import StringIO
import os
import sys

import pycam.Plugins


class GtkConsole(pycam.Plugins.PluginBase):

    UI_FILE = "gtk_console.ui"
    DEPENDS = ["Clipboard"]
    CATEGORIES = ["System"]

    # sys.ps1 and sys.ps2 don't seem to be available outside of the shell
    PROMPT_PS1 = ">>> "
    PROMPT_PS2 = "... "

    def setup(self):
        self._history = []
        self._history_position = None
        if not self._gtk:
            return False
        if self.gui:
            self._console = code.InteractiveConsole(locals=self.core.get_namespace(),
                                                    filename="PyCAM")
            # redirect sys.stdin/stdout - "exec" always writes there
            self._original_stdout = sys.stdout
            self._original_stdin = sys.stdin
            self._console_buffer = self.gui.get_object("ConsoleViewBuffer")
            # redirect the virtual console output to the window
            sys.stdout = StringIO()

            def console_write(data):
                self._console_buffer.insert(self._console_buffer.get_end_iter(), data)
                self._console_buffer.place_cursor(self._console_buffer.get_end_iter())

            self._console.write = console_write
            # make sure that we are never waiting for input (e.g. "help()")
            sys.stdin = StringIO()
            # multiprocessing has a bug regarding the handling of sys.stdin:
            # see http://bugs.python.org/issue10174
            sys.stdin.fileno = lambda: -1
            self._clear_console()
            console_action = self.gui.get_object("ToggleConsoleWindow")
            self.register_gtk_accelerator("console", console_action, None, "ToggleConsoleWindow")
            self.core.register_ui("view_menu", "ToggleConsoleWindow", console_action, 90)
            self._window = self.gui.get_object("ConsoleDialog")
            self._window_position = None
            self._gtk_handlers = []
            hide_window = lambda *args: self._set_window_visibility(value=False)
            for objname, signal, func in (
                    ("ConsoleExecuteButton", "clicked", self._execute_command),
                    ("CommandInput", "activate", self._execute_command),
                    ("CopyConsoleButton", "clicked", self._copy_to_clipboard),
                    ("WipeConsoleButton", "clicked", self._clear_console),
                    ("CommandInput", "key-press-event", self._scroll_history),
                    ("ToggleConsoleWindow", "toggled", self._set_window_visibility),
                    ("CloseConsoleButton", "clicked", hide_window),
                    ("ConsoleDialog", "delete-event", hide_window),
                    ("ConsoleDialog", "destroy", hide_window)):
                self._gtk_handlers.append((self.gui.get_object(objname), signal, func))
            self.register_gtk_handlers(self._gtk_handlers)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self._set_window_visibility(value=False)
            sys.stdout = self._original_stdout
            sys.stdin = self._original_stdin
            console_action = self.gui.get_object("ToggleConsoleWindow")
            self.unregister_gtk_accelerator("console", console_action)
            self.core.unregister_ui("view_menu", console_action)

    def _clear_console(self, widget=None):
        start, end = self._console_buffer.get_bounds()
        self._console_buffer.delete(start, end)
        self._console.write(self.PROMPT_PS1)

    def _execute_command(self, widget=None):
        input_control = self.gui.get_object("CommandInput")
        text = input_control.get_text()
        if not text:
            return
        input_control.set_text("")
        # add the command to the console window
        self._console.write(text + os.linesep)
        # execute command - check if it needs more input
        if not self._console.push(text):
            # append result to console view
            sys.stdout.seek(0)
            for line in sys.stdout.readlines():
                self._console.write(line)
            # clear the buffer
            sys.stdout.truncate(0)
            # scroll down console view to the end of the buffer
            view = self.gui.get_object("ConsoleView")
            view.scroll_mark_onscreen(self._console_buffer.get_insert())
            # show the prompt again
            self._console.write(self.PROMPT_PS1)
        else:
            # show the "waiting for more" prompt
            self._console.write(self.PROMPT_PS2)
        # add to history
        if not self._history or (text != self._history[-1]):
            self._history.append(text)
        self._history_position = None

    def _copy_to_clipboard(self, widget=None):
        start, end = self._console_buffer.get_bounds()
        content = self._console_buffer.get_text(start, end)
        self.core.get("clipboard-set")(content)

    def _set_window_visibility(self, widget=None, value=None, action=None):
        toggle_checkbox = self.gui.get_object("ToggleConsoleWindow")
        checkbox_state = toggle_checkbox.get_active()
        if value is None:
            new_state = checkbox_state
        elif action is None:
            new_state = value
        else:
            new_state = action
        if new_state:
            if self._window_position:
                self._window.move(*self._window_position)
            self._window.show()
        else:
            self._window_position = self._window.get_position()
            self._window.hide()
        toggle_checkbox.set_active(new_state)
        return True

    def _scroll_history(self, widget=None, event=None):
        if event is None:
            return False
        try:
            keyval = getattr(event, "keyval")
            get_state = getattr(event, "get_state")
        except AttributeError:
            return False
        if get_state():
            # ignore, if any modifier is pressed
            return False
        input_control = self.gui.get_object("CommandInput")
        if (keyval == self._gdk.KEY_Up):
            if self._history_position is None:
                # store the current (new) line for later
                self._history_lastline_backup = input_control.get_text()
                # start with the last item
                self._history_position = len(self._history) - 1
            elif self._history_position > 0:
                self._history_position -= 1
            else:
                # invalid -> no change
                return True
        elif (keyval == self._gdk.KEY_Down):
            if self._history_position is None:
                return True
            self._history_position += 1
        else:
            # all other keys: ignore
            return False
        if self._history_position >= len(self._history):
            input_control.set_text(self._history_lastline_backup)
            # make sure that the backup can be stored again
            self._history_position = None
        else:
            input_control.set_text(self._history[self._history_position])
        # move the cursor to the end of the new text
        input_control.set_position(0)
        input_control.grab_focus()
        return True
