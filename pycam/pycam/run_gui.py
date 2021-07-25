#!/usr/bin/env python3
"""

Copyright 2010-2018 Lars Kruse <devel@sumpfralle.de>
Copyright 2008-2009 Lode Leroy

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

import argparse
import logging
import os
import socket
import sys
import warnings

# we need the multiprocessing exception for remote connections
try:
    import multiprocessing
    from multiprocessing import AuthenticationError
except ImportError:
    multiprocessing = None
    # use an arbitrary other Exception
    AuthenticationError = socket.error

try:
    from pycam import VERSION
except ImportError:
    # running locally (without a proper PYTHONPATH) requires manual intervention
    sys.path.insert(0, os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)),
                                                     os.pardir)))
    from pycam import VERSION

from pycam.errors import InitializationError
from pycam.Flow.history import DataHistory, merge_history_and_block_events
from pycam.Gui import QuestionStatus
import pycam.Gui.common as GuiCommon
from pycam.Gui.common import EmergencyDialog
import pycam.Gui.Settings
import pycam.Gui.Console
import pycam.Importers.TestModel
import pycam.Importers
import pycam.Plugins
import pycam.Utils
from pycam.Utils.events import get_event_handler
import pycam.Utils.log
import pycam.Utils.threading

# register the glut32.dll manually for the pyinstaller standalone executable
if hasattr(sys, "frozen") and sys.frozen and "_MEIPASS2" in os.environ:
    from ctypes import windll
    windll[os.path.join(os.path.normpath(os.environ["_MEIPASS2"]), "glut32.dll")]

# The installer for PyODE does not add the required PATH variable.
if pycam.Utils.get_platform() == pycam.Utils.OSPlatform.WINDOWS:
    os.environ["PATH"] = os.environ.get("PATH", "") + os.path.pathsep + sys.exec_prefix
# The GtkGLExt installer does not add the required PATH variable.
if pycam.Utils.get_platform() == pycam.Utils.OSPlatform.WINDOWS:
    import _winreg
    path = None
    try:
        reg = _winreg.ConnectRegistry(None, _winreg.HKEY_LOCAL_MACHINE)
        regkey = _winreg.OpenKey(reg, r"SOFTWARE\GtkGLExt\1.0\Runtime")
    except WindowsError:
        regkey = None
    index = 0
    while regkey:
        try:
            key, value = _winreg.EnumValue(regkey, index)[:2]
        except WindowsError:
            # no more items left
            break
        if key == "Path":
            path = os.path.join(str(value), "bin")
            break
        index += 1
    if path:
        os.environ["PATH"] = os.environ.get("PATH", "") + os.path.pathsep + path


EXIT_CODES = {"ok": 0,
              "requirements": 1,
              "load_model_failed": 2,
              "write_output_failed": 3,
              "parsing_failed": 4,
              "server_without_password": 5,
              "connection_error": 6,
              "toolpath_error": 7}

log = pycam.Utils.log.get_logger()


def show_gui(workspace_filename=None):
    pycam.Utils.set_application_key("pycam-gtk")
    deps_gtk = GuiCommon.requirements_details_gtk()
    report_gtk = GuiCommon.get_dependency_report(deps_gtk, prefix="\t")
    if GuiCommon.check_dependencies(deps_gtk):
        from pycam.Gui.Project import ProjectGui
        gui_class = ProjectGui
    else:
        full_report = []
        full_report.append("PyCAM dependency problem")
        full_report.append("Error: Failed to load the GTK interface.")
        full_report.append("Details:")
        full_report.append(report_gtk)
        full_report.append("")
        full_report.append("Detailed list of requirements: %s" % GuiCommon.REQUIREMENTS_LINK)
        log.critical(os.linesep.join(full_report))
        return EXIT_CODES["requirements"]

    event_manager = get_event_handler()
    history = DataHistory()
    event_manager.set("history", history)

    with merge_history_and_block_events(event_manager):
        log.debug("Initializing user interface")
        gui = gui_class(event_manager)
        # initialize plugins
        log.debug("Loading all available plugins")
        plugin_manager = pycam.Plugins.PluginManager(core=event_manager)
        plugin_manager.import_plugins()
        # some more initialization
        log.debug("Resetting preferences")
        gui.reset_preferences()
        log.debug("Loading preferences")
        gui.load_preferences()
        has_loaded_custom_workspace = False
        log.debug("Loading workspace")
        if workspace_filename is None:
            gui.load_startup_workspace()
        else:
            if gui.load_workspace_from_file(workspace_filename):
                has_loaded_custom_workspace = True
            else:
                gui.load_startup_workspace()

    log.debug("Finished initialization")
    log.debug("Configured events: %s", ", ".join(event_manager.get_events_summary_lines()))
    shutdown_calls = []

    def shutdown_handler():
        # prevent repeated calls
        if shutdown_calls:
            return
        shutdown_calls.append(True)
        # optionally save workspace (based on configuration or dialog response)
        if has_loaded_custom_workspace:
            # A custom workspace file was given via command line - we always want to ask before
            # overwriting it.
            response = gui.get_question_response(
                "Save Workspace to '{}'?".format(workspace_filename), True)
            should_store = response.is_yes
        elif event_manager.get("save_workspace_on_exit") == QuestionStatus.ASK.value:
            response = gui.get_question_response("Save Workspace?", True, allow_memorize=True)
            if response.should_memorize:
                event_manager.set(
                    "save_workspace_on_exit",
                    (QuestionStatus.YES if response.is_yes else QuestionStatus.NO).value)
            should_store = response.is_yes
        elif event_manager.get("save_workspace_on_exit") == QuestionStatus.YES.value:
            should_store = True
        else:
            should_store = False
        if should_store:
            gui.save_startup_workspace()

        gui.save_preferences()
        with merge_history_and_block_events(event_manager, emit_events_after=False):
            plugin_manager.disable_all_plugins()
        # close the GUI
        gui.stop()
        history.cleanup()

    # Register our shutdown handler: it should be run _before_ the GTK main loop stops.
    # Otherwise some references and signals are gone when the teardown actions are exeucted.
    event_manager.register_event("mainloop-stop", shutdown_handler)
    # open the GUI - wait until the window is closed
    gui.run_forever()
    event_manager.unregister_event("mainloop-stop", shutdown_handler)
    # show final statistics
    log.debug("Configured events: %s", ", ".join(event_manager.get_events_summary_lines()))
    for event, stats in sorted(event_manager.get_events_summary().items()):
        if len(stats["handlers"]) > 0:
            log.info("Remaining listeners for event '%s': %s",
                     event, ", ".join(str(func) for func in stats["handlers"]))
    # no error -> return no error code
    return None


def execute(parser, args, pycam):
    # try to change the process name
    pycam.Utils.setproctitle("pycam")

    if args.trace:
        log.setLevel(logging.DEBUG // 2)
    elif args.debug:
        log.setLevel(logging.DEBUG)
    elif args.quiet:
        log.setLevel(logging.WARNING)
        # disable the progress bar
        args.progress = "none"
        # silence all warnings
        warnings.filterwarnings("ignore")
    else:
        log.setLevel(logging.INFO)

    # check if server-auth-key is given -> this is mandatory for server mode
    if (args.enable_server or args.start_server) and not args.server_authkey:
        parser.error(
            "You need to supply a shared secret for server mode. This is supposed to prevent you "
            "from exposing your host to remote access without authentication.\nPlease add the "
            "'--server-auth-key' argument followed by a shared secret password.")
        return EXIT_CODES["server_without_password"]

    # initialize multiprocessing
    try:
        if args.server_authkey is None:
            server_auth_key = None
        else:
            server_auth_key = args.server_authkey.encode("utf-8")
        if args.start_server:
            pycam.Utils.threading.init_threading(
                args.parallel_processes, remote=args.remote_server, run_server=True,
                server_credentials=server_auth_key)
            pycam.Utils.threading.cleanup()
            return EXIT_CODES["ok"]
        else:
            pycam.Utils.threading.init_threading(
                args.parallel_processes, enable_server=args.enable_server,
                remote=args.remote_server, server_credentials=server_auth_key)
    except socket.error as err_msg:
        log.error("Failed to connect to remote server: %s", err_msg)
        return EXIT_CODES["connection_error"]
    except AuthenticationError as err_msg:
        log.error("The remote server rejected your authentication key: %s", err_msg)
        return EXIT_CODES["connection_error"]

    try:
        show_gui(workspace_filename=args.workspace_filename)
    except InitializationError as exc:
        EmergencyDialog("PyCAM startup failure", str(exc))
        return EXIT_CODES["requirements"]


def get_args_parser():
    parser = argparse.ArgumentParser(prog="PyCAM", description="Toolpath generator",
                                     epilog="PyCAM website: https://github.com/SebKuzminsky/pycam")
    # general options
    group_processing = parser.add_argument_group("Processing")
    group_processing.add_argument(
        "--number-of-processes", dest="parallel_processes", default=None, type=int,
        action="store",
        help=("override the default detection of multiple CPU cores. Parallel processing only "
              "works with Python 2.6 (or later) or with the additional 'multiprocessing' module."))
    group_processing.add_argument(
        "--enable-server", dest="enable_server", default=False, action="store_true",
        help="enable a local server and (optionally) remote worker servers.")
    group_processing.add_argument(
        "--remote-server", dest="remote_server", default=None, action="store",
        help=("Connect to a remote task server to distribute the processing load. "
              "The server is given as an IP or a hostname with an optional port (default: 1250) "
              "separated by a colon."))
    group_processing.add_argument(
        "--start-server-only", dest="start_server", default=False, action="store_true",
        help="Start only a local server for handling remote requests.")
    group_processing.add_argument(
        "--server-auth-key", dest="server_authkey", default="", action="store",
        help=("Secret used for connecting to a remote server or for granting access to remote "
              "clients."))
    group_workspace = parser.add_argument_group("Workspace")
    group_workspace.add_argument(
        "--workspace-file", dest="workspace_filename",
        help="Workspace file to be loaded during startup")
    group_verbosity = parser.add_argument_group("Verbosity")
    group_verbosity.add_argument(
        "-q", "--quiet", dest="quiet", default=False, action="store_true",
        help="output only warnings and errors.")
    group_verbosity.add_argument(
        "-d", "--debug", dest="debug", default=False, action="store_true",
        help="enable output of debug messages.")
    group_verbosity.add_argument(
        "--trace", dest="trace", default=False, action="store_true",
        help="enable more verbose debug messages.")
    group_verbosity.add_argument(
        "--progress", dest="progress", default="text", action="store",
        choices=["none", "text", "bar", "dot"],
        help=("specify the type of progress bar used in non-GUI mode. The following options are "
              "available: text, none, bar, dot."))
    group_introspection = parser.add_argument_group("Introspection")
    group_introspection.add_argument(
        "--profiling", dest="profile_destination", action="store",
        help="store profiling statistics in a file (only for debugging)")
    group_introspection.add_argument("--version", action="version",
                                     version="%(prog)s {}".format(VERSION))
    return parser


def main_func():
    # The PyInstaller standalone executable requires this "freeze_support" call. Otherwise we will
    # see a warning regarding an invalid argument called "--multiprocessing-fork". This problem can
    # be triggered on single-core systems with these arguments:
    #    "--enable-server --server-auth-key foo".
    if hasattr(multiprocessing, "freeze_support"):
        multiprocessing.freeze_support()
    parser = get_args_parser()
    args = parser.parse_args()
    try:
        if args.profile_destination:
            import cProfile
            exit_code = cProfile.run('execute(parser, args, pycam)',
                                     args.profile_destination)
        else:
            # We need to add the parameter "pycam" to avoid weeeeird namespace
            # issues. Any idea how to fix this?
            exit_code = execute(parser, args, pycam)
    except KeyboardInterrupt:
        log.info("Quit requested")
        exit_code = None
    pycam.Utils.threading.cleanup()
    if exit_code is not None:
        sys.exit(exit_code)
    else:
        sys.exit(EXIT_CODES["ok"])


if __name__ == "__main__":
    main_func()
