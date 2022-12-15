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

from pycam.Flow.history import merge_history_and_block_events
import pycam.Plugins
# TODO: move Toolpath.Bounds here?
import pycam.Toolpath
from pycam.workspace.data_models import (Boundary, BoundsSpecification, LimitSingle,
                                         ToolBoundaryMode)


_RELATIVE_UNIT = ("%", "mm")


class Bounds(pycam.Plugins.ListPluginBase):

    UI_FILE = "bounds.ui"
    DEPENDS = ["Models"]
    CATEGORIES = ["Bounds"]
    COLLECTION_ITEM_TYPE = Boundary

    # mapping of boundary types and GUI control elements
    CONTROL_BUTTONS = ("TypeRelativeMargin", "TypeCustom",
                       "ToolLimit", "RelativeUnit", "BoundaryLowX",
                       "BoundaryLowY", "BoundaryLowZ", "BoundaryHighX",
                       "BoundaryHighY", "BoundaryHighZ")
    CONTROL_SIGNALS = ("toggled", "value-changed", "changed")

    def setup(self):
        self._event_handlers = []
        self.core.set("bounds", self)
        if self.gui:
            bounds_box = self.gui.get_object("BoundsBox")
            bounds_box.unparent()
            self.core.register_ui("main", "Bounds", bounds_box, 30)
            self._boundsview = self.gui.get_object("BoundsTable")
            self.set_gtk_modelview(self._boundsview)
            self.register_model_update(lambda: self.core.emit_event("bounds-list-changed"))
            for action, obj_name in ((self.ACTION_UP, "BoundsMoveUp"),
                                     (self.ACTION_DOWN, "BoundsMoveDown"),
                                     (self.ACTION_DELETE, "BoundsDelete")):
                self.register_list_action_button(action, self.gui.get_object(obj_name))
            self._treemodel = self._boundsview.get_model()
            self._treemodel.clear()
            self._gtk_handlers = []
            self._gtk_handlers.append((self._boundsview.get_selection(), "changed",
                                       "bounds-selection-changed"))
            self._gtk_handlers.append((self.gui.get_object("BoundsNew"), "clicked",
                                       self._bounds_new))
            # model selector
            self.models_control = pycam.Gui.ControlsGTK.InputTable(
                [], change_handler=lambda *args: self.core.emit_event("bounds-control-changed"))
            self.gui.get_object("ModelsViewPort").add(self.models_control.get_widget())
            # quickly adjust the bounds via buttons
            for obj_name in ("MarginIncreaseX", "MarginIncreaseY", "MarginIncreaseZ",
                             "MarginDecreaseX", "MarginDecreaseY", "MarginDecreaseZ",
                             "MarginResetX", "MarginResetY", "MarginResetZ"):
                axis = obj_name[-1]
                if "Increase" in obj_name:
                    args = "+"
                elif "Decrease" in obj_name:
                    args = "-"
                else:
                    args = "0"
                self._gtk_handlers.append((self.gui.get_object(obj_name), "clicked",
                                           self._adjust_bounds, axis, args))
            # connect change handler for boundary settings
            for axis in "XYZ":
                for value in ("Low", "High"):
                    obj_name = "Boundary%s%s" % (value, axis)
                    self._gtk_handlers.append((self.gui.get_object(obj_name), "value-changed",
                                               "bounds-control-changed"))
            # register all controls
            for obj_name in self.CONTROL_BUTTONS:
                obj = self.gui.get_object(obj_name)
                if obj_name == "TypeRelativeMargin":
                    self._gtk_handlers.append((obj, "toggled", "bounds-control-changed"))
                elif obj_name == "RelativeUnit":
                    self._gtk_handlers.append((obj, "changed", "bounds-control-changed"))
                else:
                    for signal in self.CONTROL_SIGNALS:
                        try:
                            handler = obj.connect(signal, lambda *args: None)
                            obj.disconnect(handler)
                            self._gtk_handlers.append((obj, signal, "bounds-control-changed"))
                            break
                        except TypeError:
                            continue
                    else:
                        self.log.info("Failed to connect to widget '%s'", str(obj_name))
                        continue
            self._gtk_handlers.append((self.gui.get_object("NameCell"), "edited",
                                       self.edit_item_name))
            # define cell renderers
            self.gui.get_object("SizeColumn").set_cell_data_func(self.gui.get_object("SizeCell"),
                                                                 self._render_bounds_size)
            self.gui.get_object("NameColumn").set_cell_data_func(self.gui.get_object("NameCell"),
                                                                 self.render_item_name)
            self._event_handlers.extend((
                ("model-list-changed", self._update_model_list),
                ("model-changed", self._update_model_list),
                ("bounds-selection-changed", self._update_bounds_widgets),
                ("bounds-changed", self._update_bounds_widgets),
                ("bounds-list-changed", self._select_first_if_non_empty),
                ("bounds-control-changed", self._transfer_controls_to_bounds)))
            self.register_gtk_handlers(self._gtk_handlers)
            self._update_model_list()
            self._update_bounds_widgets()
        # the models and the bounds itself may change the effective size of the boundary
        for incoming_event in ("bounds-list-changed", "bounds-changed",
                               "model-list-changed", "model-changed"):
            self._event_handlers.append((incoming_event, self.force_gtk_modelview_refresh))
        self.register_event_handlers(self._event_handlers)
        self.register_state_item("bounds-list", self)
        self.core.register_namespace("bounds", pycam.Plugins.get_filter(self))
        return True

    def teardown(self):
        self.unregister_event_handlers(self._event_handlers)
        if self.gui:
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_ui("main", self.gui.get_object("BoundsBox"))
        self.clear_state_items()
        self.core.unregister_namespace("bounds")
        self.core.set("bounds", None)
        self.clear()

    def get_selected_models(self, index=False):
        return self.models_control.get_value()

    def select_models(self, models):
        self.models_control.set_value([model.get_id() for model in models])

    def _render_bounds_size(self, column, cell, model, m_iter, data):
        bounds = self.get_by_path(model.get_path(m_iter))
        if not bounds:
            return
        box = bounds.get_absolute_limits()
        if box is None:
            text = ""
        else:
            text = "%g x %g x %g" % tuple([box.upper[i] - box.lower[i] for i in range(3)])
        cell.set_property("text", text)

    def _select_first_if_non_empty(self):
        """ automatically select a bounds item if none is selected and the list is not empty

        Without this automatic selection the bounding box would not be visible directly after
        startup.
        """
        if not self.get_selected() and (len(self.get_all()) > 0):
            self.select(self.get_all()[0])

    def _update_model_list(self):
        choices = []
        for model in self.core.get("models").get_all():
            choices.append((model.get_application_value("name", model.get_id()), model))
        self.models_control.update_choices(choices)

    def _transfer_controls_to_bounds(self):
        bounds = self.get_selected()
        if bounds:
            bounds.set_value("reference_models",
                             [model.get_id() for model in self.get_selected_models()])
            is_percent = (self.gui.get_object("RelativeUnit").get_active() == 0)
            # absolute bounds or margins around models
            if self.gui.get_object("TypeRelativeMargin").get_active():
                specification = BoundsSpecification.MARGINS
            else:
                specification = BoundsSpecification.ABSOLUTE
                # disallow percent values
                is_percent = False
            bounds.set_value("specification", specification.value)
            # overwrite all limit values and set or remove their "relative" flags
            for name, obj_keys in (("lower", ("BoundaryLowX", "BoundaryLowY", "BoundaryLowZ")),
                                   ("upper", ("BoundaryHighX", "BoundaryHighY", "BoundaryHighZ"))):
                limits = [LimitSingle(self.gui.get_object(name).get_value(), is_percent).export
                          for name in obj_keys]
                bounds.set_value(name, limits)
            tool_limit_mode = {
                0: ToolBoundaryMode.INSIDE,
                1: ToolBoundaryMode.ALONG,
                2: ToolBoundaryMode.AROUND}[self.gui.get_object("ToolLimit").get_active()]
            bounds.set_value("tool_boundary", tool_limit_mode.value)

    def _copy_from_bounds_to_controls(self, bounds):
        self.select_models(bounds.get_value("reference_models"))
        is_percent = False
        lower = bounds.get_value("lower")
        upper = bounds.get_value("upper")
        for name, limit in (("BoundaryLowX", lower.x),
                            ("BoundaryLowY", lower.y),
                            ("BoundaryLowZ", lower.z),
                            ("BoundaryHighX", upper.x),
                            ("BoundaryHighY", upper.y),
                            ("BoundaryHighZ", upper.z)):
            # beware: the result is not perfect, if "is_relative" is not consistent for all axes
            if limit.is_relative:
                is_percent = True
            factor = 100 if is_percent else 1
            self.gui.get_object(name).set_value(limit.value * factor)
        self.gui.get_object("RelativeUnit").set_active(0 if is_percent else 1)
        is_absolute = (bounds.get_value("specification") == BoundsSpecification.ABSOLUTE)
        if is_absolute:
            self.gui.get_object("TypeCustom").set_active(True)
        else:
            self.gui.get_object("TypeRelativeMargin").set_active(True)
        tool_border_index = {ToolBoundaryMode.INSIDE: 0,
                             ToolBoundaryMode.ALONG: 1,
                             ToolBoundaryMode.AROUND: 2}[bounds.get_value("tool_boundary")]
        self.gui.get_object("ToolLimit").set_active(tool_border_index)

    def _validate_bounds(self):
        """ check if any dimensions is below zero and fix these problems """
        bounds = self.get_selected()
        if bounds:
            bounds.coerce_limits()

    def _update_bounds_widgets(self, widget=None):
        bounds = self.get_selected()
        self.log.debug("Update Bounds controls: %s", bounds)
        control_box = self.gui.get_object("BoundsSettingsControlsBox")
        if not bounds:
            control_box.hide()
        else:
            self._validate_bounds()
            with self.core.blocked_events({"bounds-control-changed"}):
                self._copy_from_bounds_to_controls(bounds)
                self._update_bounds_widgets_visibility()
                control_box.show()

    def _update_bounds_widgets_visibility(self):
        # show the proper descriptive label for the current margin type
        relative_label = self.gui.get_object("MarginTypeRelativeLabel")
        custom_label = self.gui.get_object("MarginTypeCustomLabel")
        model_list = self.gui.get_object("ModelsTableFrame")
        percent_switch = self.gui.get_object("RelativeUnit")
        controls_x = self.gui.get_object("MarginControlsX")
        controls_y = self.gui.get_object("MarginControlsY")
        controls_z = self.gui.get_object("MarginControlsZ")
        if self.gui.get_object("TypeRelativeMargin").get_active():
            relative_label.show()
            custom_label.hide()
            model_list.show()
            percent_switch.show()
            controls_x.show()
            controls_y.show()
            controls_z.show()
        else:
            relative_label.hide()
            custom_label.show()
            model_list.hide()
            percent_switch.hide()
            controls_x.hide()
            controls_y.hide()
            controls_z.hide()

    def _adjust_bounds(self, widget, axis, change_target):
        bounds = self.get_selected()
        if not bounds:
            return
        axis_index = "XYZ".index(axis)
        change_factor = {"0": 0, "+": 1, "-": -1}[change_target]
        is_margin = self.gui.get_object("TypeRelativeMargin").get_active()
        is_percent = (self.gui.get_object("RelativeUnit").get_active() == 0)
        change_value = change_factor * (0.1 if is_percent else 1)
        change_vector = {"lower": [0, 0, 0], "upper": [0, 0, 0]}
        change_vector["lower"][axis_index] = change_value if is_margin else -change_value
        change_vector["upper"][axis_index] = change_value
        for key in ("lower", "upper"):
            if change_target == "0":
                limits = [LimitSingle(0 if (index == axis_index) else orig.value,
                                      orig.is_relative).export
                          for index, orig in enumerate(bounds.get_value(key))]
            else:
                limits = [LimitSingle(orig.value + change, orig.is_relative).export
                          for orig, change in zip(bounds.get_value(key), change_vector[key])]
            bounds.set_value(key, limits)

    def _bounds_new(self, widget=None):
        with merge_history_and_block_events(self.core):
            params = {"specification": "margins", "lower": [0, 0, 0], "upper": [0, 0, 0],
                      "reference_models": []}
            new_bounds = Boundary(None, data=params)
            new_bounds.set_application_value("name", self.get_non_conflicting_name("Bounds #%d"))
        self.select(new_bounds)
