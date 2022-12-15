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
import time

import pycam.Plugins
from pycam.Utils.events import get_mainloop


class ProgressBar(pycam.Plugins.PluginBase):

    UI_FILE = "progress_bar.ui"
    CATEGORIES = ["System"]

    def setup(self):
        if not self._gtk:
            return False
        if self.gui:
            box = self.gui.get_object("ProgressBox")
            box.unparent()
            self.core.register_ui("main_window", "Progress", box, 50)
            self.core.add_item("progress",
                               lambda: ProgressGTK(self.core, self.gui, self._gtk, self.log))
            show_progress_button = self.gui.get_object("ShowToolpathProgressButton")
            # TODO: move this setting somewhere else or rename it
            self.core.add_item("show_toolpath_progress", show_progress_button.get_active,
                               show_progress_button.set_active)
            self._gtk_handlers = []
            self._gtk_handlers.append((show_progress_button, "clicked",
                                       lambda widget: self.core.emit_event("visual-item-updated")))
            self.register_gtk_handlers(self._gtk_handlers)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main_window", self.gui.get_object("ProgressBox"))
        self.core.set("progress", None)


class ProgressGTK:

    _PROGRESS_STACK = []

    def __init__(self, core, gui, gtk, log):
        ProgressGTK._PROGRESS_STACK.append(self)
        self._finished = False
        self._gtk = gtk
        self._gui = gui
        self.log = log
        self.core = core
        self._cancel_requested = False
        self._start_time = 0
        self._multi_maximum = 0
        self._multi_counter = 0
        self._multi_base_text = ""
        self._last_gtk_events_time = None
        self._main_widget = self._gui.get_object("ProgressBox")
        self._multi_widget = self._gui.get_object("MultipleProgressBar")
        self._cancel_button = self._gui.get_object("ProgressCancelButton")
        self._cancel_button.connect("clicked", self.cancel)
        self._progress_bar = self._gui.get_object("ProgressBar")
        self._progress_button = self._gui.get_object("ShowToolpathProgressButton")
        self._start_time = time.time()
        self._last_text = None
        self._last_percent = None
        self.update(text="", percent=0)
        self._cancel_button.set_sensitive(True)
        self._progress_button.hide()
        # enable "pulse" mode for a start (in case of unknown ETA)
        self._progress_bar.pulse()
        self._main_widget.show()
        self._multi_widget.hide()
        self._multi_widget.set_text("")
        self._multi_widget.set_fraction(0)
        self.core.emit_event("gui-disable")

    def set_multiple(self, count, base_text=None):
        if base_text:
            self._multi_base_text = base_text
        else:
            self._multi_base_text = ""
        self._multi_counter = 0
        if count > 1:
            self._multi_maximum = count
            self.update_multiple(increment=False)
        else:
            self._multi_maximum = 0

    def update_multiple(self, increment=True):
        if self._multi_maximum <= 1:
            self._multi_widget.hide()
            return
        self._multi_widget.show()
        if increment:
            self._multi_counter += 1
            self._progress_bar.set_fraction(0)
        if self._multi_base_text:
            text = "%s %d/%d" % (self._multi_base_text, self._multi_counter + 1,
                                 self._multi_maximum)
        else:
            text = "%d/%d" % (self._multi_counter + 1, self._multi_maximum)
        self._multi_widget.set_text(text)
        self._multi_widget.set_fraction(min(1.0, float(self._multi_counter) / self._multi_maximum))

    def disable_cancel(self):
        self._cancel_button.set_sensitive(False)

    def cancel(self, widget=None):
        self._cancel_requested = True

    def finish(self):
        if self._finished:
            self.log.debug("Called progressbar 'finish' twice: %s" % self)
            return
        ProgressGTK._PROGRESS_STACK.remove(self)
        if ProgressGTK._PROGRESS_STACK:
            # restore the latest state of the previous progress
            current = ProgressGTK._PROGRESS_STACK[-1]
            current.update(text=current._last_text, percent=current._last_percent)
            current.update_multiple(increment=False)
        else:
            # hide the widget
            self._main_widget.hide()
            self._multi_widget.hide()
            widget = self._main_widget
            while widget:
                if hasattr(widget, "resize_children"):
                    widget.resize_children()
                if hasattr(widget, "check_resize"):
                    widget.check_resize()
                widget = widget.get_parent()
            self.core.emit_event("gui-enable")
        self._finished = True

    def __del__(self):
        if not self._finished:
            self.finish()

    def update(self, text=None, percent=None):
        if text:
            self._last_text = text
        if percent:
            self._last_percent = percent
        if percent is not None:
            percent = min(max(percent, 0.0), 100.0)
            self._progress_bar.set_fraction(percent/100.0)
        if (not percent) and (self._progress_bar.get_fraction() == 0):
            # use "pulse" mode until we reach 1% of the work to be done
            self._progress_bar.pulse()
        # update the GUI
        current_time = time.time()
        # Don't update the GUI more often than once per second.
        # Exception: text-only updates
        # This restriction improves performance and reduces the
        # "snappiness" of the GUI.
        if (self._last_gtk_events_time is None) \
                or text \
                or (self._last_gtk_events_time + 0.5 <= current_time):
            # "estimated time of arrival" text
            time_estimation_suffix = " remaining ..."
            if self._progress_bar.get_fraction() > 0:
                total_fraction = ((self._progress_bar.get_fraction() + self._multi_counter)
                                  / max(1, self._multi_maximum))
                total_fraction = max(0.0, min(total_fraction, 1.0))
                eta_full = (time.time() - self._start_time) / total_fraction
                if eta_full > 0:
                    eta_delta = eta_full - (time.time() - self._start_time)
                    eta_delta = int(round(eta_delta))
                    if hasattr(self, "_last_eta_delta"):
                        previous_eta_delta = self._last_eta_delta
                        if eta_delta == previous_eta_delta + 1:
                            # We are currently toggling between two numbers.
                            # We want to avoid screen flicker, thus we just live
                            # with the slight inaccuracy.
                            eta_delta = self._last_eta_delta
                    self._last_eta_delta = eta_delta
                    eta_delta_obj = datetime.timedelta(seconds=eta_delta)
                    eta_text = "%s%s" % (eta_delta_obj, time_estimation_suffix)
                else:
                    eta_text = None
            else:
                eta_text = None
            if text is not None:
                lines = [text]
            else:
                old_lines = self._progress_bar.get_text().split(os.linesep)
                # skip the time estimation line
                lines = [line for line in old_lines if not line.endswith(time_estimation_suffix)]
            if eta_text:
                lines.append(eta_text)
            self._progress_bar.set_text(os.linesep.join(lines))
            # show the "show_tool_button" ("hide" is called in the progress decorator)
            # TODO: move "in_progress" somewhere else
            if self.core.get("toolpath_in_progress"):
                self._progress_button.show()
            get_mainloop().update()
            if not text or (self._start_time + 5 < current_time):
                # We don't store the timining if the text was changed.
                # This is especially nice for the snappines during font
                # initialization. This exception is only valid for the first
                # five seconds of the operation.
                self._last_gtk_events_time = current_time
        # return if the user requested a break
        return self._cancel_requested
