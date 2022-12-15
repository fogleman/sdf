"""
Copyright 2017 Lars Kruse <devel@sumpfralle.de>

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

import pycam.Plugins
import pycam.Utils.log
from pycam.Gui.ControlsGTK import InputCheckBox, InputChoice, InputNumber

_log = pycam.Utils.log.get_logger()


class GCodeTouchOff(pycam.Plugins.PluginBase):
    """ TODO: this plugin currently does not change the generated toolpath - it is just the UI part
    """

    DEPENDS = ["ExportSettings"]
    CATEGORIES = ["GCode"]
    CONTROL_MAP = {
        "on_startup": ("Touch off on startup (initializes coordinate system for Z)", False, 10,
                       InputCheckBox, [], {}),
        "on_tool_change": ("Measure and compensate tool length on tool change", False, 20,
                           InputCheckBox, [], {}),
        "location_selector": ("Touch probe position", "startup", 30,
                              InputChoice, [(("Initial location (at startup)", "startup"),
                                             ("Fixed location (absolute)", "absolute"))], {}),
        "probe_position_x": ("Fixed probe position X", 0, 35, InputNumber, [], {"digits": 3}),
        "probe_position_y": ("Fixed probe position Y", 0, 36, InputNumber, [], {"digits": 3}),
        "probe_position_z": ("Fixed probe position Z", 0, 37, InputNumber, [], {"digits": 3}),
        "rapid_move_down": ("Rapid move down distance", 0.0, 50, InputNumber, [], {"digits": 1}),
        "slow_move_down": ("Probing distance (limit)", 0.1, 60, InputNumber, [], {"digits": 0}),
        "slow_move_speed": ("Probing speed", 100, 70, InputNumber, [], {"digits": 3, "lower": 1}),
        "probe_level_z": ("Z level of touch probe", 0.0, 80, InputNumber, [], {"digits": 3})}

    def setup(self):
        self.controls = {}
        self.core.get("register_parameter")("toolpath_profile", "touch_off", None,
                                            get_func=self._get_control_values,
                                            set_func=self._set_control_values)
        self._table = pycam.Gui.ControlsGTK.ParameterSection()
        self.core.register_ui("gcode_preferences", "Touch Off", self._table.get_widget(),
                              weight=70)
        self.core.register_ui_section("gcode_touch_off", self._table.add_widget,
                                      self._table.clear_widgets)
        for name, (label, start, weight, input_class, args, kwargs) in self.CONTROL_MAP.items():
            all_kw_args = dict(kwargs)
            all_kw_args.update({"change_handler": self.update_widgets, "start": start})
            control = input_class(*args, **all_kw_args)
            self.core.register_ui("gcode_touch_off", label, control.get_widget(), weight=weight)
            self.controls[name] = control
        self.update_widgets()
        self._table.get_widget().show()
        return True

    def teardown(self):
        for key, control in self.controls.items():
            self.core.unregister_ui("gcode_touch_off", control.get_widget())
        self.core.unregister_ui_section("gcode_touch_off")
        self.core.unregister_ui("gcode_preferences", self._table.get_widget())
        self.core.get("unregister_parameter")("toolpath_profile", "touch_off")

    def _get_control_values(self):
        """ used by the parameter manager for retrieving the current state """
        return {key: value.get_value() for key, value in self.controls.items()}

    def _set_control_values(self, params):
        """ used by the parameter manager for applying a new configuration """
        if params is None:
            # reset to defaults
            for key, control in self.controls.items():
                control.set_value(self.CONTROL_MAP[key][1])
        else:
            for key, value in params.items():
                self.controls[key].set_value(value)
        if self.gui:
            self.update_widgets()

    def update_widgets(self, widget=None):
        self._table.get_widget().show()
        self.controls["on_startup"].set_visible(True)
        self.controls["on_tool_change"].set_visible(True)
        # disable/enable the touch off position controls
        touch_off_enabled = (self.controls["on_startup"].get_value()
                             or self.controls["on_tool_change"].get_value())
        self.controls["location_selector"].set_visible(touch_off_enabled)
        # tool change controls
        pos_key = self.controls["location_selector"].get_value()
        # show or hide the vbox containing the absolute tool change location
        for name in ("probe_position_x",
                     "probe_position_y",
                     "probe_position_z"):
            self.controls[name].set_visible(touch_off_enabled and (pos_key == "absolute"))
        # disable/enable touch probe height
        for name in ("rapid_move_down", "slow_move_down", "slow_move_speed", "probe_level_z"):
            self.controls[name].set_visible(touch_off_enabled)
        self.core.emit_event("export-settings-control-changed")
