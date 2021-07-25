"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>

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
# Tkinter is used for "EmergencyDialog" below - but we will try to import it
# carefully.
# import Tkinter
import sys

import pycam.Utils.log

log = pycam.Utils.log.get_logger()


DEPENDENCY_DESCRIPTION = {
    "gtk": ("Python bindings for GTK+",
            "Install the package 'python-gtk2'",
            "see http://www.bonifazi.eu/appunti/pygtk_windows_installer.exe"),
    "opengl": ("Python bindings for OpenGL",
               "Install the package 'python-opengl'",
               "see http://www.bonifazi.eu/appunti/pygtk_windows_installer.exe"),
    "gtkgl": ("GTK extension for OpenGL",
              "The OpenGL widget for GTK3 is not yet supported by pycam",
              "code contributions are welcome - see http://pycam.sf.net/"),
    "gl": ("OpenGL support of graphic driver",
           "Your current graphic driver does not seem to support OpenGL.",
           ""),
}

REQUIREMENTS_LINK = "http://pycam.sourceforge.net/requirements"

# Usually the windows registry "HKEY_LOCAL_MACHINE/SOFTWARE/Gtk+/Path" contains
# something like: C:\Programs\Common files\GTK
# Afterwards we need to append "\bin" to get the library subdirectory.
WINDOWS_GTK_REGISTRY_PATH = r"SOFTWARE\Gtk+"
WINDOWS_GTK_REGISTRY_KEY = "Path"
WINDOWS_GTK_LIB_SUBDIR = "bin"


def import_gtk_carefully():
    """ especially for windows: try to locate required libraries manually, if
    the import of GTK fails
    """
    try:
        import _winreg
        in_windows = True
    except ImportError:
        in_windows = False
    try:
        import gi
        # avoid Gtk version warnings for later imports
        gi.require_version("Gtk", "3.0")
    except ImportError:
        pass
    if not in_windows:
        # We are not in windows - thus we just try to import gtk without
        # the need for any more manual preparations.
        import gi.repository.Gtk  # noqa F401
    else:
        # We try to retrieve the GTK library directory from the registry before
        # trying any import. Otherwise the user will always see a warning
        # dialog regarding the missing libglib-2.0-0.dll file. This Windows
        # warning dialog can't be suppressed - thus we should try to avoid it.
        try:
            reg_path = _winreg.OpenKey(_winreg.HKEY_LOCAL_MACHINE, WINDOWS_GTK_REGISTRY_PATH)
            gtk_dll_path = os.path.join(_winreg.QueryValueEx(
                reg_path, WINDOWS_GTK_REGISTRY_KEY)[0], WINDOWS_GTK_LIB_SUBDIR)
            _winreg.CloseKey(reg_path)
        except NameError:
            # GTK is probably not installed - the next import will fail
            pass
        except OSError:
            # "WindowsError" - this happens with pyinstaller binaries
            pass
        else:
            # add the new path to the PATH environment variable
            if "PATH" in os.environ:
                if gtk_dll_path not in os.environ["PATH"].split(os.pathsep):
                    # append the guessed path to the library search path
                    os.environ["PATH"] += "%s%s" % (os.pathsep, gtk_dll_path)
            else:
                os.environ["PATH"] = gtk_dll_path
        # everything should be prepared - now we try to import it again
        import gi.repository.Gtk  # noqa F401


def requirements_details_gtk():
    result = {}
    try:
        import_gtk_carefully()
        result["gtk"] = True
    except ImportError as err_msg:
        log.error("Failed to import GTK: %s", str(err_msg))
        result["gtk"] = False
    return result


def recommends_details_gtk():
    result = {}
    try:
        import gtk.gtkgl  # noqa F401
        result["gtkgl"] = True
        result["gl"] = True
    except ImportError as err_msg:
        log.warn("Failed to import OpenGL for GTK (ImportError): %s", str(err_msg))
        result["gtkgl"] = False
    except RuntimeError as err_msg:
        log.warn("Failed to import OpenGL for GTK (RuntimeError): %s", str(err_msg))
        result["gl"] = False
    try:
        import OpenGL  # noqa F401
        result["opengl"] = True
    except ImportError as err_msg:
        log.warn("Failed to import OpenGL: %s", str(err_msg))
        result["opengl"] = False


def check_dependencies(details):
    """you can feed this function with the output of
    '(requirements|recommends)_details_*'.
    The result is True if all dependencies are met.
    """
    failed = [key for (key, state) in details.items() if not state]
    return len(failed) == 0


def get_dependency_report(details, prefix=""):
    result = []
    columns = {"description": 0, "advice": 1}
    if sys.platform.startswith("win"):
        columns["advice"] = 2
    for key, state in details.items():
        text = "%s%s: " % (prefix, DEPENDENCY_DESCRIPTION[key][columns["description"]])
        if state:
            text += "OK"
        else:
            text += "MISSING (%s)" % DEPENDENCY_DESCRIPTION[key][columns["advice"]]
        result.append(text)
    return os.linesep.join(result)


def set_parent_controls_sensitivity(widget, new_state):
    """ go through all widgets above the given one and change their
    "sensitivity" state. This effects everything besides the single
    given widget, its direct line of ancestors and all attached
    labels (e.g for notebook tabs).
    Useful for disabling the screen while an action is going on.
    """
    def disable_if_different(obj, extra_args):
        parent, active = extra_args
        if hasattr(parent, "get_tab_label") and (obj is parent.get_tab_label(active)):
            # skip the label of the current tab (in a notebook)
            return
        if obj is not active:
            obj.set_sensitive(new_state)
    child = widget
    parent = widget.get_parent()
    while parent:
        # Use "forall" instead of "foreach" - this also catches all tab labels.
        parent.forall(disable_if_different, (parent, child))
        child = parent
        parent = parent.get_parent()


class EmergencyDialog:
    """ This graphical message window requires no external dependencies.
    The Tk interface package is part of the main python distribution.
    Use this class for displaying dependency errors (especially on Windows).
    """

    def __init__(self, title, message):
        try:
            import Tkinter
        except ImportError:
            # tk is not installed
            log.warn("Failed to show error dialog due to a missing Tkinter Python package.")
            return
        try:
            root = Tkinter.Tk()
        except Tkinter.TclError as err_msg:
            log.info("Failed to create error dialog window (%s). Probably you are running PyCAM "
                     "from a terminal.", err_msg)
            return
        root.title(title)
        root.bind("<Return>", self.finish)
        root.bind("<Escape>", self.finish)
        root.minsize(300, 100)
        self.root = root
        frame = Tkinter.Frame(root)
        frame.pack()
        # add text output as label
        message = Tkinter.Message(root, text=message)
        # we need some space for the dependency report
        message["width"] = 800
        message.pack()
        # add the "close" button
        close = Tkinter.Button(root, text="Close")
        close["command"] = self.finish
        close.pack(side=Tkinter.BOTTOM)
        root.mainloop()

    def finish(self, *args):
        self.root.quit()
