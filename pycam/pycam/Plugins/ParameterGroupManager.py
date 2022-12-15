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

import copy
import functools

import pycam.Plugins
from pycam.Utils import MultiLevelDictionaryAccess


class ParameterGroupManager(pycam.Plugins.PluginBase):

    CATEGORIES = ["Plugins"]

    def setup(self):
        self._groups = {}
        self._parameterized_function_cache = []
        self.core.set("get_parameter_values", self.get_parameter_values)
        self.core.set("set_parameter_values", self.set_parameter_values)
        self.core.set("get_default_parameter_values", self.get_default_parameter_values)
        self.core.set("get_parameter_sets", self.get_parameter_sets)
        self.core.set("register_parameter_group", self.register_parameter_group)
        self.core.set("register_parameter_set", self.register_parameter_set)
        self.core.set("register_parameter", self.register_parameter)
        self.core.set("unregister_parameter_group", self.unregister_parameter_group)
        self.core.set("unregister_parameter_set", self.unregister_parameter_set)
        self.core.set("unregister_parameter", self.unregister_parameter)
        return True

    def teardown(self):
        for name in ("set_parameter_values", "get_parameter_values", "get_parameter_sets",
                     "register_parameter_set", "register_parameter_group", "register_parameter",
                     "unregister_parameter_set", "unregister_parameter_group",
                     "unregister_parameter"):
            self.core.set(name, None)

    def _get_parameterized_function(self, func, *args):
        wanted_key = (func, args)
        for key, value in self._parameterized_function_cache:
            if key == wanted_key:
                return value
        else:
            partial_func = functools.partial(func, *args)
            self._parameterized_function_cache.append((wanted_key, partial_func))
            return partial_func

    def register_parameter_group(self, name, changed_set_event=None, changed_set_list_event=None,
                                 get_related_parameter_names=None):
        if name in self._groups:
            self.log.debug("Registering parameter group '%s' again", name)
        self._groups[name] = {"changed_set_event": changed_set_event,
                              "changed_set_list_event": changed_set_list_event,
                              "get_related_parameter_names": get_related_parameter_names,
                              "sets": {},
                              "parameters": {}}
        if changed_set_event:
            self.core.register_event(
                changed_set_event,
                self._get_parameterized_function(self._update_widgets_visibility, name))

    def _update_widgets_visibility(self, group_name):
        group = self._groups[group_name]
        related_parameter_names = group["get_related_parameter_names"]()
        for param in group["parameters"].values():
            is_visible = param["name"] in related_parameter_names
            control = param["control"]
            if control is None:
                pass
            elif hasattr(control, "set_visible"):
                control.set_visible(is_visible)
            elif is_visible:
                control.show()
            else:
                control.hide()

    def register_parameter_set(self, group_name, name, label, func, parameters=None, weight=100):
        if group_name not in self._groups:
            self.log.info("Unknown parameter group: %s", group_name)
            return
        group = self._groups[group_name]
        if name in group["sets"]:
            self.log.debug("Registering parameter set '%s' again", name)
        if parameters is None:
            parameters = {}
        group["sets"][name] = {"name": name, "label": label, "func": func,
                               "parameters": copy.deepcopy(parameters), "weight": weight}
        event = group["changed_set_list_event"]
        if event:
            self.core.emit_event(event)

    def register_parameter(self, group_name, name, control, get_func=None, set_func=None):
        if isinstance(name, (list, tuple)):
            name = tuple(name)
        if group_name not in self._groups:
            self.log.info("Unknown parameter group: %s", group_name)
            return
        group = self._groups[group_name]
        if name in group["parameters"]:
            self.log.debug("Registering parameter '%s' in group '%s' again", name, group_name)
        if not get_func:
            get_func = control.get_value
        if not set_func:
            set_func = control.set_value
        group["parameters"][name] = {"name": name, "control": control, "get_func": get_func,
                                     "set_func": set_func}

    def get_default_parameter_values(self, group_name, set_name=None):
        """ retrieve the default values of a given parameter group

        @param group_name: name of the parameter group
        """
        result = {}
        if group_name not in self._groups:
            self.log.info("Default Parameter Values: unknown parameter group: %s", group_name)
            return result
        group = self._groups[group_name]
        if not group["sets"]:
            self.log.info("Default Parameter Values: missing parameter sets in group: %s",
                          group_name)
            return result
        multi_level_access = MultiLevelDictionaryAccess(result)
        if set_name is None:
            default_set = sorted(group["sets"].values(), key=lambda item: item["weight"])[0]
        else:
            try:
                default_set = group["sets"][set_name]
            except KeyError:
                self.log.warning("Default Parameter Values: failed to find request set: %s",
                                 set_name)
                return result
        for key, value in default_set["parameters"].items():
            try:
                multi_level_access.set_value(key, value)
            except TypeError as exc:
                self.log.error("Failed to get default parameter '%s' for group '%s': %s",
                               key, group_name, exc)
        return result

    def get_parameter_values(self, group_name):
        if group_name not in self._groups:
            self.log.info("Unknown parameter group: %s", group_name)
            return {}
        result = {}
        multi_level_access = MultiLevelDictionaryAccess(result)
        group = self._groups[group_name]
        related_parameter_names = group["get_related_parameter_names"]()
        for parameter in group["parameters"].values():
            key = parameter["name"]
            if key in related_parameter_names:
                value = parameter["get_func"]()
                try:
                    multi_level_access.set_value(key, value)
                except TypeError as exc:
                    self.log.error("Failed to get parameter '%s' for group '%s': %s",
                                   key, group_name, exc)
        return result

    def set_parameter_values(self, group_name, value_dict):
        if group_name not in self._groups:
            self.log.info("Unknown parameter group: %s", group_name)
            return
        group = self._groups[group_name]
        multi_level_access = MultiLevelDictionaryAccess(value_dict)
        for parameter in group["parameters"].values():
            try:
                value = multi_level_access.get_value(parameter["name"])
            except KeyError:
                # the incoming value dictionary does not contain the key - we can skip it
                pass
            except TypeError as exc:
                # this should not happen: the value dictionary is malformed
                self.log.error("Failed to get parameter '%s' for group '%s': %s",
                               parameter["name"], group_name, exc)
            else:
                parameter["set_func"](value)

    def get_parameter_sets(self, group_name):
        if group_name not in self._groups:
            self.log.info("Unknown parameter group: %s", group_name)
            return
        group = self._groups[group_name]
        return dict(group["sets"])

    def unregister_parameter_group(self, group_name):
        if group_name not in self._groups:
            self.log.debug("Tried to unregister a non-existing parameter group: %s", group_name)
            return
        group = self._groups[group_name]
        if group["parameters"]:
            self.log.debug("Unregistering parameter from group '%s', but it still contains "
                           "parameters: %s", group_name, ", ".join(group["parameters"].keys()))
            for name in list(group["parameters"]):
                self.unregister_parameter(group_name, name)
        if group["sets"]:
            self.log.debug("Unregistering parameter group (%s), but it still contains sets: %s",
                           group_name, ", ".join(group["sets"].keys()))
            for set_name in group["sets"]:
                self.unregister_parameter_set(group_name, set_name)
        changed_set_event = group["changed_set_event"]
        if changed_set_event:
            self.core.unregister_event(
                changed_set_event,
                self._get_parameterized_function(self._update_widgets_visibility, group_name))
        del self._groups[group_name]

    def unregister_parameter_set(self, group_name, set_name):
        if group_name not in self._groups:
            self.log.debug("Tried to unregister set '%s' from a non-existing parameter group: %s",
                           set_name, group_name)
            return
        group = self._groups[group_name]
        if set_name not in group["sets"]:
            self.log.debug("Tried to unregister non-existing parameter set '%s' from group '%s'",
                           set_name, group_name)
            return
        del group["sets"][set_name]
        event = group["changed_set_list_event"]
        if event:
            self.core.emit_event(event)

    def unregister_parameter(self, group_name, name):
        if isinstance(name, (list, tuple)):
            name = tuple(name)
        if group_name not in self._groups:
            self.log.debug("Tried to unregister parameter '%s' from a non-existing parameter "
                           "group: %s", name, group_name)
            return
        group = self._groups[group_name]
        if name in group["parameters"]:
            del group["parameters"][name]
        else:
            self.log.debug("Tried to unregister the non-existing parameter '%s' from group '%s'",
                           name, group_name)
