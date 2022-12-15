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

import collections

from gi.repository import Gtk
from gi.repository import GObject

import pycam.Utils.log


_log = pycam.Utils.log.get_logger()


ParameterSectionWidget = collections.namedtuple("ParameterSectionWidget",
                                                ("widget", "label", "weight", "signal_handlers"))


def _input_conversion(func):
    def _input_conversion_wrapper(self, value):
        if hasattr(self, "_input_converter") and self._input_converter:
            new_value = self._input_converter(value)
        else:
            new_value = value
        return func(self, new_value)
    return _input_conversion_wrapper


def _output_conversion(func):
    def _output_conversion_wrapper(self):
        result = func(self)
        if not (result is None) and hasattr(self, "_output_converter") and \
                self._output_converter:
            result = self._output_converter(result)
        return result
    return _output_conversion_wrapper


class WidgetBaseClass:

    def get_widget(self):
        return self.control

    def set_visible(self, state):
        if state:
            self.get_widget().show()
        else:
            self.get_widget().hide()

    def is_visible(self):
        return self.get_widget().props.visible


class InputBaseClass(WidgetBaseClass):

    def connect(self, signal, handler, control=None):
        if not handler:
            return
        if control is None:
            control = self.get_widget()
        if not hasattr(self, "_handler_ids"):
            self._handler_ids = []
        self._handler_ids.append((control, control.connect(signal, handler)))

    def destroy(self):
        while hasattr(self, "_handler_ids") and self._handler_ids:
            control, handler_id = self._handler_ids.pop()
            control.disconnect(handler_id)
        if getattr(self, "destroy_widget", True):
            self.get_widget().destroy()

    def set_conversion(self, set_conv=None, get_conv=None):
        self._input_converter = set_conv
        self._output_converter = get_conv

    def set_enable_destroy(self, do_destroy):
        """ due to signal handler leakage we may want to disable "destroy" for some widgets """
        self.destroy_widget = do_destroy


class InputNumber(InputBaseClass):

    # 'float("inf")' was not accepted by pygtk - thus we use reasonable large limits
    def __init__(self, digits=0, start=0, lower=-999999, upper=999999, increment=1,
                 change_handler=None):
        # beware: the default values for lower/upper are both zero
        adjustment = Gtk.Adjustment(value=start, lower=lower, upper=upper, step_incr=increment)
        self.control = Gtk.SpinButton.new(adjustment, climb_rate=1, digits=digits)
        self.control.set_value(start)
        self.connect("value-changed", change_handler)

    @_output_conversion
    def get_value(self):
        return self.control.get_value()

    @_input_conversion
    def set_value(self, value):
        self.control.set_value(value)


class InputString(InputBaseClass):

    def __init__(self, start="", max_length=32, change_handler=None):
        self.control = Gtk.Entry.new()
        self.control.set_max_length(max_length)
        self.control.set_text(start)
        self.connect("changed", change_handler)

    @_output_conversion
    def get_value(self):
        return self.control.get_text()

    @_input_conversion
    def set_value(self, value):
        self.control.set_text(value)


class InputChoice(InputBaseClass):

    def __init__(self, choices, start=None, change_handler=None):
        self.model = Gtk.ListStore(GObject.TYPE_STRING)
        self._values = []
        for label, value in choices:
            self.model.append((label, ))
            self._values.append(value)
        renderer = Gtk.CellRendererText()
        self.control = Gtk.ComboBox.new_with_model(self.model)
        self.control.pack_start(renderer, expand=False)
        self.control.add_attribute(renderer, 'text', 0)
        if start is None:
            self.control.set_active(0)
        else:
            self.set_value(start)
        self.connect("changed", change_handler)

    @_output_conversion
    def get_value(self):
        index = self.control.get_active()
        if index < 0:
            return None
        else:
            return self._values[index]

    @_input_conversion
    def set_value(self, value):
        if value is None:
            if len(self._values) > 0:
                # activate the first item as the default
                self.control.set_active(0)
            else:
                self.control.set_active(-1)
        else:
            if value in self._values:
                self.control.set_active(self._values.index(value))
            else:
                # this may occur, if plugins were removed
                _log.debug2("Unknown value: %s (expected: %s)", value, self._values)

    def update_choices(self, choices):
        selected = self.get_value()
        for choice_index, (label, value) in enumerate(choices):
            if value not in self._values:
                # this choice is new
                self.model.insert(choice_index, (label, ))
                self._values.insert(choice_index, value)
                continue
            index = self._values.index(value)
            # the current choice is preceded by some obsolete items
            while index > choice_index:
                m_iter = self.model.get_iter((index,))
                self.model.remove(m_iter)
                self._values.pop(index)
                index -= 1
            # update the label column
            row = self.model[index]
            row[0] = label
        # check if there are obsolete items after the last one
        while len(self.model) > len(choices):
            m_iter = self.model.get_iter((len(choices),))
            self.model.remove(m_iter)
            self._values.pop(-1)
        self.set_value(selected)


class InputTable(InputChoice):

    def __init__(self, choices, change_handler=None):
        self.model = Gtk.ListStore(GObject.TYPE_STRING)
        self._values = []
        for label, value in choices:
            self.model.append((label,))
            self._values.append(value)
        renderer = Gtk.CellRendererText()
        self.control = Gtk.ScrolledWindow()
        self.control.show()
        self._treeview = Gtk.TreeView(self.model)
        self._treeview.show()
        self.control.add(self._treeview)
        self.control.set_shadow_type(Gtk.ShadowType.ETCHED_OUT)
        self.control.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        # Sadly there seems to be no way to adjust the size of the ScrolledWindow to its content.
        # The default size of the ScrolledWindow is too small (making it hard to select the model).
        self.control.set_size_request(200, -1)
        column = Gtk.TreeViewColumn()
        column.pack_start(renderer, expand=False)
        column.set_attributes(renderer, text=0)
        self._treeview.append_column(column)
        self._treeview.set_headers_visible(False)
        self._selection = self._treeview.get_selection()
        self._selection.set_mode(Gtk.SelectionMode.MULTIPLE)
        self.connect("changed", change_handler, self._selection)

    def get_value(self):
        model, rows = self._selection.get_selected_rows()
        return [self._values[path[0]] for path in rows]

    def set_value(self, items):
        selection = self._selection
        if items is None:
            items = []
        for index, value in enumerate(self._values):
            path = Gtk.TreePath.new_from_indices((index, ))
            if value in items:
                selection.select_path(path)
            else:
                selection.unselect_path(path)


class InputCheckBox(InputBaseClass):

    def __init__(self, start=False, change_handler=None):
        self.control = Gtk.CheckButton()
        self.control.set_active(start)
        self.connect("toggled", change_handler)

    @_output_conversion
    def get_value(self):
        return self.control.get_active()

    @_input_conversion
    def set_value(self, value):
        self.control.set_active(value)


class ParameterSection(WidgetBaseClass):

    def __init__(self):
        self._widgets = []
        self._table = Gtk.Table(rows=1, columns=2)
        self._table.set_col_spacings(3)
        self._table.set_row_spacings(3)
        self.update_widgets()
        self._update_widgets_visibility()

    def get_widget(self):
        return self._table

    def add_widget(self, widget, label, weight=None):
        # if no specific weight is given: keep the order of added events stable
        if weight is None:
            if self._widgets:
                weight = max([item.weight for item in self._widgets]) + 1
            else:
                weight = 50
        item = ParameterSectionWidget(widget, label, weight, [])
        self._widgets.append(item)
        for signal in ("hide", "show"):
            item.signal_handlers.append(widget.connect(signal, self._update_widgets_visibility))
        self.update_widgets()

    def clear_widgets(self):
        while self._widgets:
            item = self._widgets.pop()
            for signal_handler in item.signal_handlers:
                item.widget.disconnect(signal_handler)
        self.update_widgets()

    def update_widgets(self):
        widgets = list(self._widgets)
        widgets.sort(key=lambda item: item.weight)
        # remove all widgets from the table
        for child in self._table.get_children():
            self._table.remove(child)
        # add the current controls
        for index, widget in enumerate(widgets):
            if hasattr(widget.widget, "get_label"):
                # checkbox
                widget.widget.set_label(widget.label)
                self._table.attach(widget.widget, 0, 2, index, index + 1, xoptions=Gtk.Align.FILL,
                                   yoptions=Gtk.Align.FILL)
            elif not widget.label:
                self._table.attach(widget.widget, 0, 2, index, index + 1, xoptions=Gtk.Align.FILL,
                                   yoptions=Gtk.Align.FILL)
            else:
                # spinbutton, combobox, ...
                label = Gtk.Label("%s:" % widget.label)
                label.set_alignment(0.0, 0.5)
                self._table.attach(label, 0, 1, index, index + 1, xoptions=Gtk.Align.FILL,
                                   yoptions=Gtk.Align.FILL)
                self._table.attach(widget.widget, 1, 2, index, index + 1, xoptions=Gtk.Align.FILL,
                                   yoptions=Gtk.Align.FILL)
        self._update_widgets_visibility()

    def _get_table_row_of_widget(self, widget):
        for child in self._table.get_children():
            if child is widget:
                return self._get_child_row(child)
        return -1

    def _get_child_row(self, widget):
        return Gtk.Container.child_get_property(self._table, widget, "top-attach")

    def _update_widgets_visibility(self, widget=None):
        # Hide and show labels (or other items) that share a row with a
        # configured item (according to its visibility).
        visibility_collector = []
        for widget in self._widgets:
            table_row = self._get_table_row_of_widget(widget.widget)
            is_visible = widget.widget.props.visible
            visibility_collector.append(is_visible)
            for child in self._table.get_children():
                if widget == child:
                    continue
                if self._get_child_row(child) == table_row:
                    if is_visible:
                        child.show()
                    else:
                        child.hide()
        # hide the complete section if all items are hidden
        if any(visibility_collector):
            self._table.show()
        else:
            self._table.hide()
