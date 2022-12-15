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

import pycam.Gui.common
import pycam.Plugins


class ToolpathSimulation(pycam.Plugins.PluginBase):

    UI_FILE = "toolpath_simulation.ui"
    DEPENDS = ["Toolpaths", "OpenGLViewToolpath"]
    CATEGORIES = ["Toolpath"]

    def setup(self):
        self._running = None
        if self.gui:
            self._gtk_handlers = []
            self._frame = self.gui.get_object("SimulationBox")
            self.core.register_ui("toolpath_handling", "Simulation", self._frame, 25)
            self._speed_factor_widget = self.gui.get_object("SimulationSpeedFactorValue")
            self._speed_factor_widget.set_value(1.0)
            self._progress = self.gui.get_object("SimulationProgressTimelineValue")
            self._timer_widget = self.gui.get_object("SimulationProgressTimeDisplay")
            self._timer_widget.set_label("")
            self.core.set("show_simulation", False)
            self._toolpath_moves = None
            self._start_button = self.gui.get_object("SimulationStartButton")
            self._pause_button = self.gui.get_object("SimulationPauseButton")
            self._stop_button = self.gui.get_object("SimulationStopButton")
            for obj, handler in ((self._start_button, self._start_simulation),
                                 (self._pause_button, self._pause_simulation),
                                 (self._stop_button, self._stop_simulation)):
                self._gtk_handlers.append((obj, "clicked", handler))
            self._gtk_handlers.append((self._progress, "value-changed", self._update_toolpath))
            self._gtk_handlers.append((self._speed_factor_widget, "value-changed",
                                       self._update_speed_factor_step))
            self._event_handlers = (("toolpath-selection-changed", self._update_visibility), )
            self.register_event_handlers(self._event_handlers)
            self.register_gtk_handlers(self._gtk_handlers)
            self._update_visibility()
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            del self.core["show_simulation"]
            self.core.unregister_ui("toolpath_handling", self._frame)

    def _update_visibility(self):
        toolpaths = self.core.get("toolpaths").get_selected()
        if toolpaths and (len(toolpaths) == 1):
            self._frame.show()
        else:
            self._frame.hide()

    def _update_speed_factor_step(self, widget):
        new_step = max(0.25, widget.get_value() / 10)
        if widget.get_step_increment() != new_step:
            widget.set_step_increment(new_step)

    def _start_simulation(self, widget=None):
        if self._running is None:
            # initial start of simulation (not just continuing)
            toolpaths = self.core.get("toolpaths").get_selected()
            if not toolpaths:
                # this should not happen
                return
            # we use only one toolpath
            self._toolpath = toolpaths[0].get_toolpath()
            # calculate duration (in seconds)
            self._duration = 60 * self._toolpath.get_machine_move_distance_and_time()[1]
            self._progress.set_upper(self._duration)
            self._progress.set_value(0)
            self._toolpath_moves = None
            self.core.set("show_simulation", True)
            self.core.set("current_tool", self._toolpath.tool.get_tool_geometry())
            self._running = True
            interval_ms = int(1000 / self.core.get("tool_progress_max_fps"))
            pycam.Gui.common.set_parent_controls_sensitivity(self._frame, False)
            self._gobject.timeout_add(interval_ms, self._next_timestep)
        else:
            self._running = True
        self._start_button.set_sensitive(False)
        self._pause_button.set_sensitive(True)
        self._stop_button.set_sensitive(True)

    def _pause_simulation(self, widget=None):
        self._start_button.set_sensitive(True)
        self._pause_button.set_sensitive(False)
        self._running = False

    def _stop_simulation(self, widget=None):
        self._running = None
        self.core.set("show_simulation", False)
        self.core.set("toolpath_in_progress", None)
        self.core.set("current_tool", None)
        self._toolpath_moves = None
        self._timer_widget.set_label("")
        self._progress.set_value(0)
        self._start_button.set_sensitive(True)
        self._pause_button.set_sensitive(False)
        self._stop_button.set_sensitive(False)
        pycam.Gui.common.set_parent_controls_sensitivity(self._frame, True)
        self.core.emit_event("visual-item-updated")

    def _next_timestep(self):
        if self._running is None:
            # stop operation
            return False
        if not self._running:
            # pause -> no change
            return True
        if self._progress.get_value() < self._progress.get_upper():
            time_step = (self._speed_factor_widget.get_value()
                         / self.core.get("tool_progress_max_fps"))
            new_time = self._progress.get_value() + time_step
            new_time = min(new_time, self._progress.get_upper())
            if new_time != self._progress.get_value():
                # update the visualization
                self._progress.set_value(new_time)
        return True

    def _update_toolpath(self, widget=None):
        if (self._running is not None) and (self._progress.get_upper() > 0):
            fraction = self._progress.get_value() / self._progress.get_upper()
            current = datetime.timedelta(seconds=int(self._progress.get_value()))
            complete = datetime.timedelta(seconds=int(self._progress.get_upper()))
            self._timer_widget.set_label("%s / %s" % (current, complete))
            moves = self._toolpath.get_moves(max_time=self._duration * fraction / 60)
            if moves:
                tool = self.core.get("current_tool")
                if tool:
                    last_position = moves[-1][1]
                    tool.moveto(last_position)
            self.core.set("toolpath_in_progress", moves)
            self.core.emit_event("visual-item-updated")
