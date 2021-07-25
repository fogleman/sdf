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

from pycam.Geometry import Box3D, Point3D
import pycam.Geometry.Model
import pycam.Plugins
import pycam.Toolpath.SupportGrid
from pycam.workspace import SupportBridgesLayout, SourceType
import pycam.workspace.data_models


class ModelSupportGrid(pycam.Plugins.PluginBase):

    UI_FILE = "model_support_grid.ui"
    DEPENDS = ["Models", "ModelSupport"]
    CATEGORIES = ["Model", "Support bridges"]

    def setup(self):
        if self.gui:
            grid_box = self.gui.get_object("SupportModelGridBox")
            grid_box.unparent()
            self.core.register_ui("support_model_type_selector", "Grid", "grid", weight=-10)
            self.core.register_ui("support_model_settings", "Grid settings", grid_box)
            support_model_changed = lambda widget=None: \
                self.core.emit_event("support-model-changed")
            self._gtk_handlers = []
            # support grid
            # TODO: remove these adjustments
            self.grid_adjustments_x = []
            self.grid_adjustments_y = []
            self.grid_adjustment_axis_x_last = True
            self._block_manual_adjust_update = False
            grid_distance_x = self.gui.get_object("SupportGridDistanceX")
            self._gtk_handlers.append((grid_distance_x, "value-changed", support_model_changed))
            self.core.add_item("support_grid_distance_x", grid_distance_x.get_value,
                               grid_distance_x.set_value)
            grid_distance_square = self.gui.get_object("SupportGridDistanceSquare")
            self._gtk_handlers.append((grid_distance_square, "clicked",
                                       self.update_support_controls))
            grid_distance_y = self.gui.get_object("SupportGridDistanceY")
            self._gtk_handlers.append((grid_distance_y, "value-changed", support_model_changed))

            def get_support_grid_distance_y():
                if grid_distance_square.get_active():
                    return self.core.get("support_grid_distance_x")
                else:
                    return grid_distance_y.get_value()

            self.core.add_item("support_grid_distance_y", get_support_grid_distance_y,
                               grid_distance_y.set_value)
            grid_offset_x = self.gui.get_object("SupportGridOffsetX")
            self._gtk_handlers.append((grid_offset_x, "value-changed", support_model_changed))
            self.core.add_item("support_grid_offset_x", grid_offset_x.get_value,
                               grid_offset_x.set_value)
            grid_offset_y = self.gui.get_object("SupportGridOffsetY")
            self._gtk_handlers.append((grid_offset_y, "value-changed", support_model_changed))
            self.core.add_item("support_grid_offset_y", grid_offset_y.get_value,
                               grid_offset_y.set_value)
            # manual grid adjustments
            self.grid_adjustment_axis_x = self.gui.get_object("SupportGridPositionManualAxisX")
            self._gtk_handlers.extend((
                (self.grid_adjustment_axis_x, "toggled", self.switch_support_grid_manual_selector),
                (self.gui.get_object("SupportGridPositionManualResetOne"), "clicked",
                 lambda *args: self.reset_support_grid_manual(reset_all=False)),
                (self.gui.get_object("SupportGridPositionManualResetAll"), "clicked",
                 lambda *args: self.reset_support_grid_manual(True))))
            self.grid_adjustment_model = self.gui.get_object("SupportGridPositionManualList")
            self.grid_adjustment_selector = self.gui.get_object(
                "SupportGridPositionManualSelector")
            self._gtk_handlers.append((self.grid_adjustment_selector, "changed",
                                       self.switch_support_grid_manual_selector))
            self.grid_adjustment_value = self.gui.get_object("SupportGridPositionManualAdjustment")
            self.grid_adjustment_value_control = self.gui.get_object(
                "SupportGridPositionManualShiftControl")
            # FIXME
            # self.grid_adjustment_value_control.set_update_policy(self._gtk.UPDATE_DISCONTINUOUS)
            self._gtk_handlers.extend((
                (self.grid_adjustment_value_control, "move-slider",
                 self.update_support_grid_manual_adjust),
                (self.grid_adjustment_value_control, "value-changed",
                 self.update_support_grid_manual_adjust),
                (self.gui.get_object("SupportGridPositionManualShiftControl2"),
                 "value-changed", self.update_support_grid_manual_adjust)))

            def get_set_grid_adjustment_value(value=None):
                if self.grid_adjustment_axis_x.get_active():
                    adjustments = self.grid_adjustments_x
                else:
                    adjustments = self.grid_adjustments_y
                index = self.grid_adjustment_selector.get_active()
                if value is None:
                    if 0 <= index < len(adjustments):
                        return adjustments[index]
                    else:
                        return 0
                else:
                    while len(adjustments) <= index:
                        adjustments.append(0)
                    adjustments[index] = value

            # TODO: remove these public settings
            self.core.add_item("support_grid_adjustment_value", get_set_grid_adjustment_value,
                               get_set_grid_adjustment_value)
            grid_distance_square.set_active(True)
            self.core.set("support_grid_distance_x", 10.0)
            # handlers
            self._event_handlers = (("support-model-changed", self.update_support_controls), )
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
        self.core.register_chain("get_support_models", self._get_support_models)
        return True

    def teardown(self):
        if self.gui and self._gtk:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_chain("get_support_models", self._get_support_models)
            self.core.unregister_ui("support_model_type_selector", "grid")
            self.core.unregister_ui("support_model_settings",
                                    self.gui.get_object("SupportModelGridBox"))

    def _get_support_models(self, models, support_models):
        grid_type = self.core.get("support_model_type")
        if (grid_type == "grid") and models:
            # we create exactly one support model for all input models
            s = self.core
            box = self._get_bounds(models)
            if (box is not None
                    and (s.get("support_grid_thickness") > 0)
                    and ((s.get("support_grid_distance_x") > 0)
                         or (s.get("support_grid_distance_y") > 0))
                    and ((s.get("support_grid_distance_x") == 0)
                         or (s.get("support_grid_distance_x") > s.get("support_grid_thickness")))
                    and ((s.get("support_grid_distance_y") == 0)
                         or (s.get("support_grid_distance_y") > s.get("support_grid_thickness")))
                    and (s.get("support_grid_height") > 0)):
                # TODO: allow explicit configuration of bridge length
                bridge_length = max(s.get("support_grid_thickness"), s.get("support_grid_height"))
                model_definition = {
                    "source": {
                        "type": SourceType.SUPPORT_BRIDGES,
                        "layout": SupportBridgesLayout.GRID,
                        "models": tuple(model.get_id() for model in models),
                        "grid": {"distances": {"x": s.get("support_grid_distance_x"),
                                               "y": s.get("support_grid_distance_y")},
                                 "offsets": {"x": [s.get("support_grid_offset_x")],
                                             "y": [s.get("support_grid_offset_y")]}},
                        "shape": {"height": s.get("support_grid_height"),
                                  "width": s.get("support_grid_thickness"),
                                  "length": bridge_length},
                    }
                }
                support_models.append(pycam.workspace.data_models.Model(
                    "support", model_definition, add_to_collection=False))
            # all models are processed -> wipe the input list
            models.clear()

    def update_support_controls(self, widget=None):
        grid_type = self.core.get("support_model_type")
        if grid_type == "grid":
            grid_square = self.gui.get_object("SupportGridDistanceSquare")
            distance_y = self.gui.get_object("SupportGridDistanceYControl")
            distance_y.set_sensitive(not grid_square.get_active())
            if grid_square.get_active():
                # We let "distance_y" track the value of "distance_x".
                self.core.set("support_grid_distance_y", self.core.get("support_grid_distance_x"))
            self.update_support_grid_manual_model()
            self.switch_support_grid_manual_selector()
            self.gui.get_object("SupportModelGridBox").show()
        else:
            self.gui.get_object("SupportModelGridBox").hide()

    def switch_support_grid_manual_selector(self, widget=None):
        """ Event handler for a switch between the x and y axis selector for
        manual adjustment. Final goal: update the adjustment combobox with the
        current values for that axis.
        """
        old_axis_was_x = self.grid_adjustment_axis_x_last
        self.grid_adjustment_axis_x_last = self.grid_adjustment_axis_x.get_active()
        if self.grid_adjustment_axis_x.get_active():
            # x axis is selected
            if not old_axis_was_x:
                self.update_support_grid_manual_model()
            max_distance = self.core.get("support_grid_distance_x")
        else:
            # y axis
            if old_axis_was_x:
                self.update_support_grid_manual_model()
            max_distance = self.core.get("support_grid_distance_y")
        # we allow an individual adjustment of 66% of the distance
        max_distance /= 1.5
        if hasattr(self.grid_adjustment_value, "set_lower"):
            # gtk 2.14 is required for "set_lower" and "set_upper"
            self.grid_adjustment_value.set_lower(-max_distance)
            self.grid_adjustment_value.set_upper(max_distance)
        if self.grid_adjustment_value.get_value() \
                != self.core.get("support_grid_adjustment_value"):
            self.grid_adjustment_value.set_value(self.core.get("support_grid_adjustment_value"))
        self.gui.get_object("SupportGridPositionManualShiftBox").set_sensitive(
            self.grid_adjustment_selector.get_active() >= 0)

    def update_support_grid_manual_adjust(self, widget=None, data1=None, data2=None):
        """ Update the current entry in the manual adjustment combobox after
        a manual change. Additionally the slider and the numeric control are
        synched.
        """
        if self._block_manual_adjust_update:
            return
        self._block_manual_adjust_update = True
        new_value = self.grid_adjustment_value.get_value()
        self.core.set("support_grid_adjustment_value", new_value)
        tree_iter = self.grid_adjustment_selector.get_active_iter()
        if tree_iter is not None:
            value_string = "(%+.1f)" % new_value
            self.grid_adjustment_model.set(tree_iter, 1, value_string)
        self.core.emit_event("support-model-changed")
        self._block_manual_adjust_update = False

    def reset_support_grid_manual(self, widget=None, reset_all=False):
        if reset_all:
            self.grid_adjustments_x = []
            self.grid_adjustments_y = []
        else:
            self.core.set("support_grid_adjustment_value", 0)
        self.update_support_grid_manual_model()
        self.switch_support_grid_manual_selector()
        self.core.emit_event("support-model-changed")

    def update_support_grid_manual_model(self):
        old_index = self.grid_adjustment_selector.get_active()
        model = self.grid_adjustment_model
        model.clear()
        s = self.core
        # get the toolpath without adjustments
        box = self._get_bounds()
        base_x, base_y = pycam.Toolpath.SupportGrid.get_support_grid_locations(
            box.lower.x, box.upper.x, box.lower.y, box.upper.y,
            s.get("support_grid_distance_x"),
            s.get("support_grid_distance_y"),
            offset_x=s.get("support_grid_offset_x"),
            offset_y=s.get("support_grid_offset_y"))
        # fill the adjustment lists
        while len(self.grid_adjustments_x) < len(base_x):
            self.grid_adjustments_x.append(0)
        while len(self.grid_adjustments_y) < len(base_y):
            self.grid_adjustments_y.append(0)
        # select the currently active list
        if self.grid_adjustment_axis_x.get_active():
            base = base_x
            adjustments = self.grid_adjustments_x
        else:
            base = base_y
            adjustments = self.grid_adjustments_y
        # generate the model content
        for index, base_value in enumerate(base):
            position = "%.2f%s" % (base_value, s.get("unit"))
            if (0 <= index < len(adjustments)) and (adjustments[index] != 0):
                diff = "(%+.1f)" % adjustments[index]
            else:
                diff = ""
            model.append((position, diff))
        if old_index < len(base):
            self.grid_adjustment_selector.set_active(old_index)
        else:
            self.grid_adjustment_selector.set_active(-1)

    def _get_bounds(self, models=None):
        if not models:
            models = self.core.get("models").get_selected()
        models = [m.get_model() for m in models]
        box = pycam.Geometry.Model.get_combined_bounds(models)
        if box is None:
            return None
        else:
            # TODO: the x/y offset should be configurable via a control
            margin = 5
            return Box3D(Point3D(box.lower.x - margin, box.lower.y - margin, box.lower.z),
                         Point3D(box.upper.x + margin, box.upper.y + margin, box.upper.z))
