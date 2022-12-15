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
import random
import string

import pycam.Plugins
from pycam.Utils.events import get_mainloop
import pycam.Utils.threading


class ParallelProcessing(pycam.Plugins.PluginBase):

    UI_FILE = "parallel_processing.ui"
    CATEGORIES = ["System"]

    def setup(self):
        if self.gui and self._gtk:
            box = self.gui.get_object("MultiprocessingFrame")
            box.unparent()
            self.core.register_ui("preferences", "Parallel processing", box, 60)
            # "process pool" window
            self.process_pool_window = self.gui.get_object("ProcessPoolWindow")
            self.process_pool_window.set_default_size(500, 400)
            self._gtk_handlers = []
            self._gtk_handlers.extend((
                (self.process_pool_window, "delete-event", self.toggle_process_pool_window, False),
                (self.process_pool_window, "destroy", self.toggle_process_pool_window, False)))
            self._gtk_handlers.append((
                self.gui.get_object("ProcessPoolWindowClose"), "clicked",
                self.toggle_process_pool_window, False))
            self.gui.get_object("ProcessPoolRefreshInterval").set_value(3)
            self.process_pool_model = self.gui.get_object("ProcessPoolStatisticsModel")
            # show/hide controls
            self.enable_parallel_processes = self.gui.get_object("EnableParallelProcesses")
            if pycam.Utils.threading.is_multiprocessing_available():
                self.gui.get_object("ParallelProcessingDisabledLabel").hide()
                if pycam.Utils.threading.is_server_mode_available():
                    self.gui.get_object("ServerModeDisabledLabel").hide()
                else:
                    self.gui.get_object("ServerModeSettingsFrame").hide()
            else:
                self.gui.get_object("ParallelProcessSettingsBox").hide()
                self.gui.get_object("EnableParallelProcesses").hide()
            self._gtk_handlers.append((self.enable_parallel_processes,
                                       "toggled", self.handle_parallel_processes_settings))
            self.number_of_processes = self.gui.get_object("NumberOfProcesses")
            self.number_of_processes.set_value(pycam.Utils.threading.get_number_of_processes())
            self.server_port_local_obj = self.gui.get_object("ServerPortLocal")
            self.server_port_remote_obj = self.gui.get_object("RemoteServerPort")
            self.auth_key_obj = self.gui.get_object("ServerPassword")
            self._gtk_handlers.extend((
                (self.number_of_processes, "value-changed",
                 self.handle_parallel_processes_settings),
                (self.gui.get_object("EnableServerMode"), "toggled",
                 self.initialize_multiprocessing),
                (self.gui.get_object("ServerPasswordGenerate"), "clicked",
                 self.generate_random_server_password),
                (self.gui.get_object("ServerPasswordShow"), "toggled",
                 self.update_parallel_processes_settings)))
            cpu_cores = pycam.Utils.threading.get_number_of_cores()
            if cpu_cores is None:
                cpu_cores = "unknown"
            self.gui.get_object("AvailableCores").set_label(str(cpu_cores))
            toggle_button = self.gui.get_object("ToggleProcessPoolWindow")
            self._gtk_handlers.append((toggle_button, "toggled", self.toggle_process_pool_window))
            self.register_gtk_accelerator("processes", toggle_button, None,
                                          "ToggleProcessPoolWindow")
            self.core.register_ui("view_menu", "ToggleProcessPoolWindow", toggle_button, 40)
            self.register_gtk_handlers(self._gtk_handlers)
            self.enable_parallel_processes.set_active(
                pycam.Utils.threading.is_multiprocessing_enabled())
            self.update_parallel_processes_settings()
        return True

    def teardown(self):
        self.enable_parallel_processes.set_active(False)
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.process_pool_window.hide()
            self.core.unregister_ui("preferences", self.gui.get_object("MultiprocessingFrame"))
            toggle_button = self.gui.get_object("ToggleProcessPoolWindow")
            self.core.unregister_ui("view_menu", toggle_button)
            self.unregister_gtk_accelerator("processes", toggle_button)

    def toggle_process_pool_window(self, widget=None, value=None, action=None):
        toggle_process_pool_checkbox = self.gui.get_object("ToggleProcessPoolWindow")
        checkbox_state = toggle_process_pool_checkbox.get_active()
        if value is None:
            new_state = checkbox_state
        else:
            if action is None:
                new_state = value
            else:
                new_state = action
        if new_state:
            is_available = pycam.Utils.threading.is_pool_available()
            disabled_box = self.gui.get_object("ProcessPoolDisabledBox")
            statistics_box = self.gui.get_object("ProcessPoolStatisticsBox")
            if is_available:
                disabled_box.hide()
                statistics_box.show()
                # start the refresh function
                interval = int(max(1,
                                   self.gui.get_object("ProcessPoolRefreshInterval").get_value()))
                self._gobject.timeout_add_seconds(interval, self.update_process_pool_statistics,
                                                  interval)
            else:
                disabled_box.show()
                statistics_box.hide()
            self.process_pool_window.show()
        else:
            self.process_pool_window.hide()
        toggle_process_pool_checkbox.set_active(new_state)
        # don't destroy the window with a "destroy" event
        return True

    def update_process_pool_statistics(self, original_interval):
        stats = pycam.Utils.threading.get_pool_statistics()
        model = self.process_pool_model
        model.clear()
        for item in stats:
            model.append(item)
        self.gui.get_object("ProcessPoolConnectedWorkersValue").set_text(str(len(stats)))
        details = pycam.Utils.threading.get_task_statistics()
        detail_text = os.linesep.join(["%s: %s" % (key, value)
                                       for (key, value) in details.items()])
        self.gui.get_object("ProcessPoolDetails").set_text(detail_text)
        current_interval = int(max(1,
                                   self.gui.get_object("ProcessPoolRefreshInterval").get_value()))
        if original_interval != current_interval:
            # initiate a new repetition
            self._gobject.timeout_add_seconds(
                current_interval, self.update_process_pool_statistics, current_interval)
            # stop the current repetition
            return False
        else:
            # don't repeat, if the window is hidden
            return self.gui.get_object("ToggleProcessPoolWindow").get_active()

    def generate_random_server_password(self, widget=None):
        all_characters = string.letters + string.digits
        random_pw = "".join([random.choice(all_characters) for i in range(12)])
        self.auth_key_obj.set_text(random_pw)

    def update_parallel_processes_settings(self, widget=None):
        parallel_settings = self.gui.get_object("ParallelProcessSettingsBox")
        server_enabled = self.gui.get_object("EnableServerMode")
        server_mode_settings = self.gui.get_object("ServerModeSettingsTable")
        # update the show/hide state of the password
        hide_password = self.gui.get_object("ServerPasswordShow").get_active()
        self.auth_key_obj.set_visibility(hide_password)
        if (self.gui.get_object("NumberOfProcesses").get_value() == 0) \
                and self.enable_parallel_processes.get_active():
            self.gui.get_object("ZeroProcessesWarning").show()
        else:
            self.gui.get_object("ZeroProcessesWarning").hide()
        if self.enable_parallel_processes.get_active():
            parallel_settings.set_sensitive(True)
            if server_enabled.get_active():
                # don't allow changes for an active connection
                server_mode_settings.set_sensitive(False)
            else:
                server_mode_settings.set_sensitive(True)
        else:
            parallel_settings.set_sensitive(False)
            server_enabled.set_active(False)
        # check suitability of collision detection engines
        self.core.emit_event("parallel-processing-changed")

    def handle_parallel_processes_settings(self, widget=None):
        new_num_of_processes = self.number_of_processes.get_value()
        new_enable_parallel = self.enable_parallel_processes.get_active()
        old_num_of_processes = pycam.Utils.threading.get_number_of_processes()
        old_enable_parallel = pycam.Utils.threading.is_multiprocessing_enabled()
        if (old_num_of_processes != new_num_of_processes) \
                or (old_enable_parallel != new_enable_parallel):
            self.initialize_multiprocessing()

    def initialize_multiprocessing(self, widget=None):
        complete_area = self.gui.get_object("MultiprocessingFrame")
        # prevent any further actions while the connection is established
        complete_area.set_sensitive(False)
        # wait for the above "set_sensitive" to finish
        get_mainloop().update()
        enable_parallel = self.enable_parallel_processes.get_active()
        enable_server_obj = self.gui.get_object("EnableServerMode")
        enable_server = enable_server_obj.get_active()
        remote_host = self.gui.get_object("RemoteServerHostname").get_text()
        if remote_host:
            remote_port = int(self.server_port_remote_obj.get_value())
            remote = "%s:%s" % (remote_host, remote_port)
        else:
            remote = None
        local_port = int(self.server_port_local_obj.get_value())
        auth_key = self.auth_key_obj.get_text()
        auth_key = None if auth_key is None else auth_key.encode("utf-8")
        if not auth_key and enable_parallel and enable_server:
            self.log.error("You need to provide a password for this connection.")
            enable_server_obj.set_active(False)
        elif enable_parallel:
            if enable_server and \
                    (pycam.Utils.get_platform() == pycam.Utils.OSPlatform.WINDOWS):
                if self.number_of_processes.get_value() > 0:
                    self.log.warn("Mixed local and remote processes are currently not available "
                                  "on the Windows platform. Setting the number of local processes "
                                  "to zero.")
                    self.number_of_processes.set_value(0)
                self.number_of_processes.set_sensitive(False)
            else:
                self.number_of_processes.set_sensitive(True)
            num_of_processes = int(self.number_of_processes.get_value())
            error = pycam.Utils.threading.init_threading(
                number_of_processes=num_of_processes, enable_server=enable_server, remote=remote,
                server_credentials=auth_key, local_port=local_port)
            if error:
                self.log.error("Failed to start server: %s", error)
                pycam.Utils.threading.cleanup()
                enable_server_obj.set_active(False)
        else:
            pycam.Utils.threading.cleanup()
            self.log.info("Multiprocessing disabled")
        # set the label of the "connect" button
        if enable_server_obj.get_active():
            info = self._gtk.stock_lookup(self._gtk.STOCK_DISCONNECT)
        else:
            info = self._gtk.stock_lookup(self._gtk.STOCK_CONNECT)
        enable_server_obj.set_label(info.label)
        complete_area.set_sensitive(True)
        self.update_parallel_processes_settings()
