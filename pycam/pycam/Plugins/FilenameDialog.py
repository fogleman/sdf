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


def _get_filters_from_list(gtk, filter_list):
    result = []
    for one_filter in filter_list:
        current_filter = gtk.FileFilter()
        current_filter.set_name(one_filter[0])
        file_extensions = one_filter[1]
        if not isinstance(file_extensions, (list, tuple)):
            file_extensions = [file_extensions]
        for ext in file_extensions:
            current_filter.add_pattern(pycam.Utils.get_case_insensitive_file_pattern(ext))
        result.append(current_filter)
    return result


def _get_filename_with_suffix(filename, type_filter):
    # use the first extension provided by the filter as the default
    if isinstance(type_filter[0], (tuple, list)):
        filter_ext = type_filter[0][1]
    else:
        filter_ext = type_filter[1]
    if isinstance(filter_ext, (list, tuple)):
        filter_ext = filter_ext[0]
    if not filter_ext.startswith("*"):
        # weird filter content
        return filename
    else:
        filter_ext = filter_ext[1:]
    basename = os.path.basename(filename)
    if (basename.rfind(".") == -1) or (basename[-6:].rfind(".") == -1):
        # The filename does not contain a dot or the dot is not within the
        # last five characters. Dots within the start of the filename are
        # ignored.
        return filename + filter_ext
    else:
        # contains at least one dot
        return filename


class FilenameDialog(pycam.Plugins.PluginBase):

    CATEGORIES = ["System"]

    def setup(self):
        if not self._gtk:
            return False
        else:
            self.last_dirname = None
            self.core.set("get_filename_func", self.get_filename_dialog)
            return True

    def teardown(self):
        self.core.set("get_filename_func", None)

    def get_filename_dialog(self, title="Choose file ...", mode_load=False, type_filter=None,
                            filename_templates=None, filename_extension=None, parent=None,
                            extra_widget=None):
        if parent is None:
            parent = self.core.get("main_window")
        # we open a dialog
        if mode_load:
            action = self._gtk.FileChooserAction.OPEN
            stock_id_ok = self._gtk.STOCK_OPEN
        else:
            action = self._gtk.FileChooserAction.SAVE
            stock_id_ok = self._gtk.STOCK_SAVE
        dialog = self._gtk.FileChooserDialog(title=title, parent=parent, action=action,
                                             buttons=(self._gtk.STOCK_CANCEL,
                                                      self._gtk.ResponseType.CANCEL,
                                                      stock_id_ok,
                                                      self._gtk.ResponseType.OK))
        # set the initial directory to the last one used
        if self.last_dirname and os.path.isdir(self.last_dirname):
            dialog.set_current_folder(self.last_dirname)
        # add extra parts
        if extra_widget:
            extra_widget.show_all()
            dialog.get_content_area().pack_start(extra_widget, expand=False, fill=False, padding=0)
        # add filter for files
        if type_filter:
            for file_filter in _get_filters_from_list(self._gtk, type_filter):
                dialog.add_filter(file_filter)
        # guess the export filename based on the model's filename
        valid_templates = []
        if filename_templates:
            for template in filename_templates:
                if not template:
                    continue
                elif hasattr(template, "get_path"):
                    valid_templates.append(template.get_path())
                else:
                    valid_templates.append(template)
        if valid_templates:
            filename_template = valid_templates[0]
            # remove the extension
            default_filename = os.path.splitext(filename_template)[0]
            if filename_extension:
                default_filename += os.path.extsep + filename_extension
            elif type_filter:
                for one_type in type_filter:
                    extension = one_type[1]
                    if isinstance(extension, (list, tuple, set)):
                        extension = extension[0]
                    # use only the extension of the type filter string
                    extension = os.path.splitext(extension)[1]
                    if extension:
                        default_filename += extension
                        # finish the loop
                        break
            dialog.select_filename(default_filename)
            dialog.set_current_name(os.path.basename(default_filename))
        # add filter for all files
        ext_filter = self._gtk.FileFilter()
        ext_filter.set_name("All files")
        ext_filter.add_pattern("*")
        dialog.add_filter(ext_filter)
        done = False
        while not done:
            dialog.set_filter(dialog.list_filters()[0])
            response = dialog.run()
            filename = dialog.get_filename()
            uri = pycam.Utils.URIHandler(filename)
            dialog.hide()
            if response != self._gtk.ResponseType.OK:
                dialog.destroy()
                return None
            if not mode_load and filename:
                # check if we want to add a default suffix
                filename = _get_filename_with_suffix(filename, type_filter)
            if not mode_load and os.path.exists(filename):
                overwrite_window = self._gtk.MessageDialog(
                    parent, type=self._gtk.MessageType.WARNING,
                    buttons=self._gtk.ButtonsType.YES_NO,
                    message_format="This file exists. Do you want to overwrite it?")
                overwrite_window.set_title("Confirm overwriting existing file")
                response = overwrite_window.run()
                overwrite_window.destroy()
                done = (response == self._gtk.ResponseType.YES)
            elif mode_load and not uri.exists():
                not_found_window = self._gtk.MessageDialog(
                    parent, type=self._gtk.MessageType.ERROR, buttons=self._gtk.ButtonsType.OK,
                    message_format="This file does not exist. Please choose a different filename.")
                not_found_window.set_title("Invalid filename selected")
                response = not_found_window.run()
                not_found_window.destroy()
                done = False
            else:
                done = True
        if extra_widget:
            extra_widget.unparent()
        dialog.destroy()
        # add the file to the list of recently used ones
        if filename:
            self.core.get("set_last_filename")(filename)
        return filename
