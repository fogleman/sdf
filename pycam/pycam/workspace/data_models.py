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

import collections
import copy
from enum import Enum
import functools
import io
import os.path
import time
import uuid

from pycam.Cutters.CylindricalCutter import CylindricalCutter
from pycam.Cutters.SphericalCutter import SphericalCutter
from pycam.Cutters.ToroidalCutter import ToroidalCutter
from pycam.Geometry import Box3D, Point3D
import pycam.Geometry.Model
from pycam.Geometry.Plane import Plane
from pycam.PathGenerators import UpdateToolView
import pycam.PathGenerators.DropCutter
import pycam.PathGenerators.EngraveCutter
import pycam.PathGenerators.PushCutter
import pycam.Toolpath
import pycam.Toolpath.Filters as tp_filters
import pycam.Toolpath.MotionGrid as MotionGrid
import pycam.Toolpath.SupportGrid
from pycam.Importers import detect_file_type
from pycam.Utils import get_application_key, get_type_name, MultiLevelDictionaryAccess
from pycam.Utils.events import get_event_handler
from pycam.Utils.progress import ProgressContext
from pycam.Utils.locations import get_data_file_location
import pycam.Utils.log
from pycam.workspace import (
    BoundsSpecification, CollectionName, DistributionStrategy, FileType, FormatType, GCodeDialect,
    ModelScaleTarget, ModelTransformationAction, ModelType, LengthUnit, PathPattern,
    PositionShiftTarget, ProcessStrategy, SourceType, SupportBridgesLayout, TargetType, TaskType,
    ToolBoundaryMode, ToolpathFilter, ToolpathTransformationAction, ToolShape)
from pycam.errors import (LoadFileError, PycamBaseException, InvalidDataError, InvalidKeyError,
                          MissingAttributeError, MissingDependencyError, UnexpectedAttributeError)

_log = pycam.Utils.log.get_logger()


# dictionary of all collections by name
_data_collections = {}
_cache = {}


APPLICATION_ATTRIBUTES_KEY = "X-Application"


def _get_enum_value(enum_class, value):
    try:
        return enum_class(value)
    except ValueError:
        raise InvalidKeyError(value, enum_class)


def _get_enum_resolver(enum_class):
    """ return a function that would convert a raw value to an enum item of the given class """
    return functools.partial(_get_enum_value, enum_class)


def _get_list_item_value(item_converter, values):
    return [item_converter(value) for value in values]


def _get_list_resolver(item_converter):
    return functools.partial(_get_list_item_value, item_converter)


def _bool_converter(value):
    if isinstance(value, int):
        if value == 1:
            return True
        elif value == 0:
            return False
        else:
            raise InvalidDataError("Invalid boolean value: {} (int)".format(value))
    elif isinstance(value, str):
        if value.lower() in ("true", "yes", "1", "on", "enabled"):
            return True
        elif value.lower() in ("false", "no", "0", "off", "disabled"):
            return False
        else:
            raise InvalidDataError("Invalid boolean value: {} (string)".format(value))
    elif isinstance(value, bool):
        return value
    else:
        raise InvalidDataError("Invalid boolean value type ({}): {}"
                               .format(get_type_name(value), value))


class LimitSingle(collections.namedtuple("LimitSingle", ("value", "is_relative"))):

    @property
    def export(self):
        """return the storage string for later parsing"""
        if self.is_relative:
            return "{:f}%".format(100.0 * self.value)
        else:
            return self.value


Limit3D = collections.namedtuple("Limit3D", ("x", "y", "z"))
AxesValues = collections.namedtuple("AxesValues", ("x", "y", "z"))
CacheItem = collections.namedtuple("CacheItem", ("timestamp", "content"))


def _limit3d_converter(point):
    """ convert a tuple or list of three numbers or a dict with x/y/z keys into a 'Limit3D' """
    if len(point) != 3:
        raise InvalidDataError("A 3D limit needs to contain exactly three items: {}"
                               .format(point))
    result = []
    if isinstance(point, dict):
        try:
            point = (point["x"], point["y"], point["z"])
        except KeyError:
            raise InvalidDataError("All three axis are required for lower/upper limits")
    for value in point:
        is_relative = False
        if isinstance(value, LimitSingle):
            value, is_relative = value
        elif isinstance(value, str):
            try:
                if value.endswith("%"):
                    is_relative = True
                    # convert percent value to 0..1
                    value = float(value[:-1]) / 100.0
                else:
                    value = float(value)
            except ValueError:
                raise InvalidDataError("Failed to parse float from 3D limit: {}".format(value))
        elif isinstance(value, (int, float)):
            value = float(value)
        else:
            raise InvalidDataError("Non-numeric data supplied for 3D limit: {}".format(value))
        result.append(LimitSingle(value, is_relative))
    return Limit3D(*result)


def _axes_values_converter(data, allow_none=False, wanted_axes="xyz"):
    result = {key: None for key in "xyz"}
    if isinstance(data, (list, dict)):
        if isinstance(data, dict):
            data = dict(data)
            for key in wanted_axes:
                try:
                    value = data.pop(key)
                except KeyError:
                    if allow_none:
                        value = None
                    else:
                        raise InvalidDataError("Missing mandatory axis component ({})".format(key))
                result[key] = value
            if data:
                raise InvalidDataError("Superfluous axes key(s) supplied: {} (expected: x / y / z)"
                                       .format(" / ".join(data.keys())))
        else:
            # a list
            data = list(data)
            if len(data) != len(wanted_axes):
                raise InvalidDataError("Invalid number of axis components supplied: {:d} "
                                       "(expected: {:d})".format(len(result), len(wanted_axes)))
            for key, value in zip(wanted_axes, data):
                result[key] = value
        for key, value in result.items():
            try:
                result[key] = None if value is None else float(value)
            except ValueError:
                raise InvalidDataError("Axis value is not a float: {} ({})"
                                       .format(value, get_type_name(value)))
    else:
        try:
            factor = float(data)
        except ValueError:
            raise InvalidDataError("Axis value is not a float: {} ({})"
                                   .format(data, get_type_name(data)))
        for key in result:
            result[key] = factor
    return AxesValues(**result)


def _get_from_collection(collection_name, wanted, many=False):
    """ retrieve one or more items from a collection

    @param collection_name: identifier of the relevant collection
    @param wanted: ID (or list of IDs) to be used for filtering the collection items
    @param many: expect "wanted" to be a list; return a tuple instead of a single value
    """
    default_result = [] if many else None
    try:
        collection = _data_collections[collection_name]
    except KeyError:
        _log.info("Requested item (%s) from unknown collection (%s)", wanted, collection_name)
        return default_result
    try:
        if many:
            return tuple(collection[item_id] for item_id in wanted
                         if collection[item_id] is not None)
        else:
            return collection[wanted]
    except KeyError:
        return default_result


def _get_collection_resolver(collection_name, many=False):
    assert isinstance(collection_name, CollectionName)
    return functools.partial(_get_from_collection, collection_name, many=many)


def _set_parser_context(description):
    """ store a string describing the current parser context (useful for error messages) """
    def wrap(func):
        @functools.wraps(func)
        def inner_function(self, *args, **kwargs):
            original_description = getattr(self, "_current_parser_context", None)
            self._current_parser_context = description
            try:
                result = func(self, *args, **kwargs)
            except PycamBaseException as exc:
                # add a prefix to exceptions
                exc.message = "{} -> {}".format(self._current_parser_context, exc)
                raise exc
            if original_description is None:
                delattr(self, "_current_parser_context")
            else:
                self._current_parser_context = original_description
            return result
        return inner_function
    return wrap


def _set_allowed_attributes(attr_set):
    def wrap(func):
        @functools.wraps(func)
        def inner_function(self, *args, **kwargs):
            self.validate_allowed_attributes(attr_set)
            return func(self, *args, **kwargs)
        return inner_function
    return wrap


def _require_model_type(wanted_type):
    def wrap(func):
        @functools.wraps(func)
        def inner_function(self, model, *args, **kwargs):
            if (wanted_type == ModelType.TRIMESH) and not hasattr(model, "triangles"):
                raise InvalidDataError(
                    "Expected 3D mesh model, but received '{}'".format(type(model)))
            elif (wanted_type == ModelType.POLYGON) and not hasattr(model, "get_polygons"):
                raise InvalidDataError(
                    "Expected 2D polygon model, but received '{}'".format(type(model)))
            else:
                return func(self, model, *args, **kwargs)
        return inner_function
    return wrap


class CacheStorage:
    """ cache result values of a method

    The method's instance object may be a BaseDataContainer (or another non-trivial object).
    Arguments for the method call are hashed.
    Multiple data keys for a BaseDataContainer may be specified - a change of their value
    invalidates cached values.
    """

    def __init__(self, relevant_dict_keys, max_cache_size=10):
        self._relevant_dict_keys = tuple(relevant_dict_keys)
        self._max_cache_size = max_cache_size

    def __call__(self, calc_function):
        def wrapped(inst, *args, **kwargs):
            return self.get_cached(inst, args, kwargs, calc_function)
        return wrapped

    @classmethod
    def _get_stable_hashs_for_value(cls, value):
        """calculate a hash value for simple values and complex objects"""
        if isinstance(value, dict):
            for key_value in sorted(value.items()):
                yield from cls._get_stable_hashs_for_value(key_value)
        elif isinstance(value, (list, tuple)):
            for item in value:
                yield from cls._get_stable_hashs_for_value(item)
        elif isinstance(value, (float, int, str)):
            yield hash(value)
        elif isinstance(value, pycam.Toolpath.Toolpath):
            yield hash(value)
        elif value is None:
            yield hash(None)
        elif isinstance(value, BaseDataContainer):
            yield from cls._get_stable_hashs_for_value(value.get_dict())
        elif isinstance(value, Enum):
            yield hash(value.value)
        else:
            assert False, ("Non-hashable type needs hash conversion for cache key: {}"
                           .format(type(value)))

    def _get_cache_key(self, inst, args, kwargs):
        hashes = []
        for key in self._relevant_dict_keys:
            value = inst.get_value(key)
            hashes.append(hash(key))
            hashes.extend(self._get_stable_hashs_for_value(value))
        return (tuple(hashes)
                + tuple(self._get_stable_hashs_for_value(args))
                + tuple(self._get_stable_hashs_for_value(kwargs)))

    def get_cached(self, inst, args, kwargs, calc_function):
        # every instance manages its own cache
        try:
            hash(inst)
        except TypeError:
            # this item is not cacheable - deliver it directly
            _log.info("Directly serving value due to non-hashable instance (skipping the cache): "
                      "%s", inst)
            return calc_function(inst, *args, **kwargs)
        try:
            my_cache = _cache[hash(inst)]
        except KeyError:
            my_cache = {}
            _cache[hash(inst)] = my_cache
        cache_key = self._get_cache_key(inst, args, kwargs)
        try:
            return my_cache[cache_key].content
        except KeyError:
            pass
        cache_item = CacheItem(time.time(), calc_function(inst, *args, **kwargs))
        my_cache[cache_key] = cache_item
        if len(my_cache) > self._max_cache_size:
            # remove the oldest cache item
            item_list = [(key, value.timestamp) for key, value in my_cache.items()]
            item_list.sort(key=lambda item: item[1])
            my_cache.pop(item_list[0][0])
        return cache_item.content


class BaseDataContainer:

    attribute_converters = {}
    attribute_defaults = {}
    changed_event = None

    def __init__(self, data):
        assert isinstance(data, dict), "Expecting a dict, but received '{}'".format(type(data))
        data = copy.deepcopy(data)
        # split the application-specific data (e.g. colors or visibility flags) from the model data
        self._application_attributes = data.pop(APPLICATION_ATTRIBUTES_KEY, {})
        self._data = data
        self._multi_level_dict = MultiLevelDictionaryAccess(self._data)

    @classmethod
    def parse_from_dict(cls, data):
        return cls(data)

    def get_value(self, key, default=None, raw=False):
        """ get a value from the data dictionary

        @param key may be a simple string or a tuple of strings (multi-level access)
        """
        try:
            raw_value = self._multi_level_dict.get_value(key)
        except KeyError:
            if default is not None:
                raw_value = default
            elif key in self.attribute_defaults:
                raw_value = copy.deepcopy(self.attribute_defaults[key])
            else:
                if hasattr(self, "_current_parser_context"):
                    # the context will be added automatically
                    raise MissingAttributeError("missing attribute '{}'".format(key))
                else:
                    # generate a suitable context based on the object itself
                    raise MissingAttributeError("{} -> missing attribute '{}'"
                                                .format(get_type_name(self), key))
        if raw:
            return raw_value
        elif key in self.attribute_converters:
            value = self.attribute_converters[key](raw_value)
            if hasattr(value, "set_related_collection"):
                # special case for Source: we need the original collection for "copy"
                value.set_related_collection(self.collection_name)
            return value
        else:
            return raw_value

    def set_value(self, key, value):
        """ set a value of the data dictionary and notify subscribes in case of changes

        @param key may be a simple string or a tuple of strings (multi-level access)
        """
        new_value = copy.deepcopy(value)
        try:
            is_different = (self._multi_level_dict.get_value(key) != new_value)
        except KeyError:
            # the key is missing
            is_different = True
        if is_different:
            self._multi_level_dict.set_value(key, new_value)
            self.notify_changed()

    def extend_value(self, key, values):
        """extend a value (which must be a list) with additional values

        This is just a convenience wrapper for the combination of "get_value", "get_dict",
        "extend" and "set_value".
        @param key may be a simple string or a tuple of strings (multi-level access)
        """
        if values:
            try:
                current_list = self._multi_level_dict.get_value(key)
            except KeyError:
                current_list = []
                self._multi_level_dict.set_value(key, current_list)
            current_list.extend(values)
            self.notify_changed()

    def get_dict(self, with_application_attributes=False):
        result = copy.deepcopy(self._data)
        # fill missing slots with their default values
        result_multi_level = MultiLevelDictionaryAccess(result)
        # replace all enum variables with their value
        result_multi_level.apply_recursive_item_modification(lambda value: isinstance(value, Enum),
                                                             lambda value: value.value)
        for key, value in self.attribute_defaults.items():
            value = copy.deepcopy(value)
            # resolve enums into their string representation
            if isinstance(value, Enum):
                value = value.value
            try:
                # check if the value for this key exists
                result_multi_level.get_value(key)
            except KeyError:
                # the value does not exist: set it with its default
                result_multi_level.set_value(key, value)
        if with_application_attributes:
            minimized_data = {key: value
                              for key, value in copy.deepcopy(self._application_attributes).items()
                              if value}
            if minimized_data:
                result[APPLICATION_ATTRIBUTES_KEY] = minimized_data
        return result

    def _get_current_application_dict(self):
        try:
            return self._application_attributes[get_application_key()]
        except KeyError:
            self._application_attributes[get_application_key()] = {}
        return self._application_attributes[get_application_key()]

    def set_application_value(self, key, value):
        new_value = copy.deepcopy(value)
        value_dict = self._get_current_application_dict()
        if value_dict.get(key) != new_value:
            value_dict[key] = new_value
            self.notify_changed()

    def get_application_value(self, key, default=None):
        return self._get_current_application_dict().get(key, default)

    @classmethod
    def _get_not_matching_keys(cls, data_dict, allowed_keys):
        """ retrieve hierarchical keys from a nested dictionary that are not part of 'allowed_keys'

        The items of the dict are tested for being contained in "allowed_keys".
        Nested keys are specified as tuples of the keys of the nesting levels.
        Valid examples (returning an empty result):
            {"foo": "bar"}, {"foo", "baz", "fu"}
            {"foo": {"bar": "baz"}}, {("foo", "bar"), "fu"}
            {}, {"foo"}
            {"foo": 1, "bar": {"baz": 2, "fu": {"foobar": 3}}},
                {"foo", ("bar", "baz"), ("bar, "fu", "foobar")}
        """
        non_matching = set()
        for key, value in data_dict.items():
            if key not in allowed_keys and (key, ) not in allowed_keys:
                if isinstance(value, dict):
                    # the key itself is not allowed - try to go down to the next level
                    sub_keys = {tuple(allowed_key[1:])
                                for allowed_key in allowed_keys
                                if isinstance(allowed_key, tuple) and (key == allowed_key[0])}
                    for sub_non_matching in cls._get_not_matching_keys(value, sub_keys):
                        if isinstance(sub_non_matching, tuple):
                            non_matching.add((key, ) + sub_non_matching)
                        else:
                            non_matching.add((key, sub_non_matching))
                else:
                    non_matching.add(key)
        return non_matching

    def validate_allowed_attributes(self, allowed_attributes):
        unexpected_attributes = self._get_not_matching_keys(self._data, allowed_attributes)
        if unexpected_attributes:
            unexpected_attributes_string = " / ".join(
                "->".join(item) if isinstance(item, tuple) else item
                for item in unexpected_attributes)
            raise UnexpectedAttributeError("unexpected attributes were given: {}"
                                           .format(unexpected_attributes_string))

    def notify_changed(self):
        if self.changed_event:
            get_event_handler().emit_event(self.changed_event)

    def validate(self):
        """ try to verify the validity of a data item

        All operations of the items are executed (avoiding permanent side-effects).  Most problems
        of the data structure should be discovered during this operation.  Non-trivial problems
        (e.g. missing permissions for file operations) are not guaranteed to be detected.

        throws PycamBaseException in case of errors
        """
        raise NotImplementedError

    def __str__(self):
        attr_dict_string = ", ".join("{}={}".format(key, value)
                                     for key, value in self.get_dict().items())
        return "{}({})".format(get_type_name(self), attr_dict_string)


class BaseCollection:

    def __init__(self, name, list_changed_event=None):
        self._name = name
        self._list_changed_event = list_changed_event
        self._data = []

    @property
    def list_changed_event(self):
        return self._list_changed_event

    def clear(self):
        if self._data:
            while self._data:
                self._data.pop()
            self.notify_list_changed()

    def __setitem__(self, index, value):
        if self._data[index] != value:
            self._data[index] = value
            self.notify_list_changed()

    def append(self, value):
        self._data.append(value)
        self.notify_list_changed()

    def __getitem__(self, index_or_key):
        for item in self._data:
            if index_or_key == item.get_id():
                return item
        else:
            # Not found by ID? Interpret the value as an index.
            if isinstance(index_or_key, int):
                return self._data[index_or_key]
            else:
                _log.warning("Failed to find item in collection (%s): %s (expected: %s)",
                             self._name, index_or_key, [item.get_id() for item in self._data])
                return None

    def __delitem__(self, index):
        item = self[index]
        if item is not None:
            try:
                self.remove(item)
            except ValueError:
                pass

    def remove(self, item):
        _log.info("Removing '{}' from collection '{}'".format(item.get_id(), self._name))
        try:
            self._data.remove(item)
        except ValueError:
            raise KeyError("Failed to remove '{}' from collection '{}'"
                           .format(item.get_id(), self._name))
        self.notify_list_changed()

    def __iter__(self):
        return iter(self._data)

    def __len__(self):
        return len(self._data)

    def __contains__(self, key):
        return (key in self._data) or (key in [item.get_id() for item in self._data])

    def __bool__(self):
        return len(self._data) > 0

    def swap_by_index(self, index1, index2):
        assert index1 != index2
        smaller, bigger = min(index1, index2), max(index1, index2)
        item1 = self._data.pop(bigger)
        item2 = self._data.pop(smaller)
        self._data.insert(smaller, item1)
        self._data.insert(bigger, item2)
        self.notify_list_changed()

    def get_dict(self, with_application_attributes=False, without_uuids=False):
        result = {}
        for item in self._data:
            item_id = item.get_id()
            data = item.get_dict(with_application_attributes=with_application_attributes)
            if without_uuids:
                try:
                    data.pop(item.unique_attribute)
                except KeyError:
                    pass
            result[item_id] = data
        return result

    def notify_list_changed(self):
        if self._list_changed_event:
            get_event_handler().emit_event(self._list_changed_event)

    def validate(self):
        for item in self._data:
            item.validate()


class BaseCollectionItemDataContainer(BaseDataContainer):

    # the name of the collection should be overwritten in every subclass
    collection_name = None
    list_changed_event = None
    unique_attribute = "uuid"

    def __init__(self, item_id, data, add_to_collection=True):
        super().__init__(data)
        assert self.collection_name is not None, (
            "Missing unique attribute ({}) of '{}' class"
            .format(self.unique_attribute, get_type_name(self)))
        if item_id is None:
            item_id = uuid.uuid4().hex
        try:
            hash(item_id)
        except TypeError:
            raise InvalidDataError("Invalid item ID ({}): not hashable".format(item_id))
        self._data[self.unique_attribute] = item_id
        if add_to_collection:
            self.get_collection().append(self)

    def get_id(self):
        return self.get_dict()[self.unique_attribute]

    @classmethod
    def get_collection(cls):
        try:
            return _data_collections[cls.collection_name]
        except KeyError:
            collection = BaseCollection(cls.collection_name,
                                        list_changed_event=cls.list_changed_event)
            _data_collections[cls.collection_name] = collection
            return collection


class Source(BaseDataContainer):

    attribute_converters = {
        "type": _get_enum_resolver(SourceType),
        "models": _get_collection_resolver(CollectionName.MODELS, many=True),
        "layout": _get_enum_resolver(SupportBridgesLayout),
        "distribution": _get_enum_resolver(DistributionStrategy),
        ("grid", "distances"): functools.partial(_axes_values_converter, wanted_axes="xy"),
        ("grid", "offsets", "x"): _get_list_resolver(float),
        ("grid", "offsets", "y"): _get_list_resolver(float),
        ("shape", "height"): float,
        ("shape", "thickness"): float,
        ("shape", "length"): float,
        "average_distance": float,
        "minimum_count": int,
    }
    attribute_defaults = {
        ("grid", "offsets", "x"): [],
        ("grid", "offsets", "y"): [],
        "minimum_count": 3,
        "average_distance": None,
    }

    def __hash__(self):
        source_type = self.get_value("type")
        if source_type == SourceType.COPY:
            raise TypeError("unhashable generic source")
        elif source_type in (SourceType.FILE, SourceType.URL):
            return hash(self.get_value("location"))
        elif source_type == SourceType.MODEL:
            return hash(self._get_source_model())
        elif source_type == SourceType.TASK:
            return hash(self._get_source_task())
        elif source_type == SourceType.TOOLPATH:
            return hash(self._get_source_toolpath())
        elif source_type == SourceType.OBJECT:
            return hash(self._get_source_object())
        elif source_type == SourceType.SUPPORT_BRIDGES:
            return hash(self._get_source_support_bridges())
        else:
            raise InvalidKeyError(source_type, SourceType)

    @CacheStorage({"type"})
    @_set_parser_context("Source")
    def get(self, related_collection_name):
        _log.debug("Retrieving source {}".format(self))
        source_type = self.get_value("type")
        if source_type == SourceType.COPY:
            if related_collection_name is None:
                # handle "validate" check gracefully
                raise ValueError("'related_collection_name' may not be None")
            else:
                return self._get_source_copy(related_collection_name)
        elif source_type in (SourceType.FILE, SourceType.URL):
            return self._get_source_location(source_type)
        elif source_type == SourceType.MODEL:
            return self._get_source_model()
        elif source_type == SourceType.TASK:
            return self._get_source_task()
        elif source_type == SourceType.TOOLPATH:
            return self._get_source_toolpath()
        elif source_type == SourceType.OBJECT:
            return self._get_source_object()
        elif source_type == SourceType.SUPPORT_BRIDGES:
            return self._get_source_support_bridges()
        else:
            raise InvalidKeyError(source_type, SourceType)

    @_set_parser_context("Source 'copy'")
    @_set_allowed_attributes({"type", "original"})
    def _get_source_copy(self, related_collection_name):
        source_name = self.get_value("original")
        return _get_from_collection(related_collection_name, source_name).get_model()

    @_set_parser_context("Source 'file/url'")
    @_set_allowed_attributes({"type", "location"})
    def _get_source_location(self, source_type):
        location = self.get_value("location")
        if source_type == SourceType.FILE:
            if not os.path.isabs(location):
                # try to guess the absolute location
                # TODO: add the directory of the most recently loaded workspace file
                # guess the git base directory
                git_checkout_dir = os.path.join(os.path.dirname(__file__),
                                                os.path.pardir, os.path.pardir)
                search_directories = [os.getcwd(), git_checkout_dir]
                abs_location = get_data_file_location(location, silent=True,
                                                      priority_directories=search_directories)
                # hopefully it worked - otherwise normal error handling will happen
                if abs_location is not None:
                    location = abs_location
            location = "file://" + os.path.abspath(location)
        try:
            detected_filetype = detect_file_type(location)
        except MissingDependencyError as exc:
            _log.critical(exc)
            raise LoadFileError(exc)
        if detected_filetype:
            try:
                return detected_filetype.importer(detected_filetype.uri)
            except LoadFileError as exc:
                raise InvalidDataError("Failed to detect file type ({}): {}".format(location, exc))
        else:
            raise InvalidDataError("Failed to load data from '{}'".format(location))

    @_set_parser_context("Source 'model'")
    @_set_allowed_attributes({"type", "items"})
    def _get_source_model(self):
        model_names = self.get_value("items")
        return _get_from_collection(CollectionName.MODELS, model_names, many=True)

    @_set_parser_context("Source 'task'")
    @_set_allowed_attributes({"type", "item"})
    def _get_source_task(self):
        task_name = self.get_value("item")
        return _get_from_collection(CollectionName.TASKS, task_name)

    @_set_parser_context("Source 'toolpath'")
    @_set_allowed_attributes({"type", "items"})
    def _get_source_toolpath(self):
        toolpath_names = self.get_value("items")
        return _get_from_collection(CollectionName.TOOLPATHS, toolpath_names, many=True)

    @_set_parser_context("Source 'object'")
    @_set_allowed_attributes({"type", "data"})
    def _get_source_object(self):
        """ transfer method for intra-process transfer """
        return self.get_value("data")

    @staticmethod
    def _get_values_or_repeat_last(input_values, default=0):
        """ pass through values taken from an input list

        The last value is repeated forever, after the input list is exhausted.
        In case of an empty list, the default value is returned again and again.
        """
        value = default
        for value in input_values:
            yield value
        # continue yielding the last value forever
        while True:
            yield value

    @_set_parser_context("Source 'support_bridges'")
    @_set_allowed_attributes({
        "type", "models", "layout", "distribution", ("grid", "distances"),
        "average_distance", "minimum_count", ("grid", "offsets", "x"), ("grid", "offsets", "y"),
        ("shape", "height"), ("shape", "width"), ("shape", "length")})
    def _get_source_support_bridges(self):
        layout = self.get_value("layout")
        models = self.get_value("models")
        height = self.get_value(("shape", "height"))
        width = self.get_value(("shape", "width"))
        bridge_length = self.get_value(("shape", "length"))
        if layout == SupportBridgesLayout.GRID:
            box = pycam.Geometry.Model.get_combined_bounds(model.get_model() for model in models)
            if box is None:
                return None
            else:
                grid_distances = self.get_value(("grid", "distances"))
                grid_offsets_x = self.get_value(("grid", "offsets", "x"))
                grid_offsets_y = self.get_value(("grid", "offsets", "y"))
                return pycam.Toolpath.SupportGrid.get_support_grid(
                    box.lower.x, box.upper.x, box.lower.y, box.upper.y, box.lower.z,
                    grid_distances.x, grid_distances.y, height, width, bridge_length,
                    adjustments_x=self._get_values_or_repeat_last(grid_offsets_x),
                    adjustments_y=self._get_values_or_repeat_last(grid_offsets_y))
        elif layout == SupportBridgesLayout.DISTRIBUTED:
            if not models:
                return None
            else:
                distribution = self.get_value("distribution")
                minimum_count = self.get_value("minimum_count")
                average_distance = self.get_value("average_distance")
                box = pycam.Geometry.Model.get_combined_bounds(model.get_model()
                                                               for model in models)
                if box is None:
                    return None
                else:
                    if distribution == DistributionStrategy.CORNERS:
                        start_at_corners = True
                    elif distribution == DistributionStrategy.EVENLY:
                        start_at_corners = False
                    else:
                        assert False
                    if average_distance is None:
                        dim_x, dim_y = box.get_dimensions()[:2]
                        # default distance: at least three pieces per side
                        average_distance = (dim_x + dim_y) / 6
                    combined_model = pycam.Geometry.Model.get_combined_model(model.get_model()
                                                                             for model in models)
                    return pycam.Toolpath.SupportGrid.get_support_distributed(
                        combined_model, combined_model.minz, average_distance, minimum_count,
                        width, height, bridge_length, start_at_corners=start_at_corners)
        else:
            assert False

    def validate(self):
        try:
            # try it with a invalid "related_collection_name" - hopefully it works
            self.get(None)
        except ValueError:
            # The "copy" source requires a suitable "related_collection_name" parameter. Thus we
            # cannot fully check the validity.
            pass


class ModelTransformation(BaseDataContainer):

    attribute_converters = {"action": _get_enum_resolver(ModelTransformationAction),
                            "scale_target": _get_enum_resolver(ModelScaleTarget),
                            "shift_target": _get_enum_resolver(PositionShiftTarget),
                            "center": _axes_values_converter,
                            "vector": _axes_values_converter,
                            "angle": float,
                            "axes": functools.partial(_axes_values_converter, allow_none=True)}

    def get_transformed_model(self, model):
        action = self.get_value("action")
        if action == ModelTransformationAction.SCALE:
            return self._get_scaled_model(model)
        elif action == ModelTransformationAction.SHIFT:
            return self._get_shifted_model(model)
        elif action == ModelTransformationAction.ROTATE:
            return self._get_rotated_model(model)
        elif action == ModelTransformationAction.MULTIPLY_MATRIX:
            return self._get_matrix_multiplied_model(model)
        elif action == ModelTransformationAction.PROJECTION:
            return self._get_projected_model(model)
        elif action in (ModelTransformationAction.TOGGLE_POLYGON_DIRECTIONS,
                        ModelTransformationAction.REVISE_POLYGON_DIRECTIONS):
            return self._get_polygon_transformed(model)
        else:
            raise InvalidKeyError(action, ModelTransformationAction)

    @_set_parser_context("Model transformation 'scale'")
    @_set_allowed_attributes({"action", "scale_target", "axes"})
    def _get_scaled_model(self, model):
        target = self.get_value("scale_target")
        axes = self.get_value("axes")
        kwargs = {}
        if target == ModelScaleTarget.FACTOR:
            for key, value in zip(("scale_x", "scale_y", "scale_z"), axes):
                kwargs[key] = 1.0 if value is None else value
        elif target == ModelScaleTarget.SIZE:
            for key, current_size, target_size in zip(
                    ("scale_x", "scale_y", "scale_z"), model.get_dimensions(), axes):
                if target_size == 0:
                    raise InvalidDataError("Model transformation 'scale' does not accept "
                                           "zero as a target size ({}).".format(key))
                elif target_size is None:
                    kwargs[key] = 1.0
                elif current_size == 0:
                    kwargs[key] = 1.0
                    # don't scale axis if it's flat
                else:
                    kwargs[key] = target_size / current_size
        else:
            assert False
        new_model = model.copy()
        with ProgressContext("Scaling model") as progress:
            new_model.scale(callback=progress.update, **kwargs)
        return new_model

    @_set_parser_context("Model transformation 'shift'")
    @_set_allowed_attributes({"action", "shift_target", "axes"})
    def _get_shifted_model(self, model):
        target = self.get_value("shift_target")
        axes = self.get_value("axes")
        offset = target._get_shift_offset(target, axes, model)
        new_model = model.copy()
        with ProgressContext("Shifting Model") as progress:
            new_model.shift(*offset, callback=progress.update)
        return new_model

    @_set_parser_context("Model transformation 'rotate'")
    @_set_allowed_attributes({"action", "center", "vector", "angle"})
    def _get_rotated_model(self, model):
        center = self.get_value("center")
        vector = self.get_value("vector")
        angle = self.get_value("angle")
        new_model = model.copy()
        with ProgressContext("Rotating Model") as progress:
            new_model.rotate(center, vector, angle, callback=progress.update)
        return new_model

    @_set_parser_context("Model transformation 'matrix multiplication'")
    @_set_allowed_attributes({"action", "matrix"})
    def _get_matrix_multiplied_model(self, model):
        matrix = self.get_value("matrix")
        lengths = [len(row) for row in matrix]
        if not lengths == [3, 3, 3]:
            raise InvalidDataError("Invalid Matrix row lengths ({}) - expected [3, 3, 3] instead."
                                   .format(lengths))
        # add zero shift offsets (the fourth column)
        for row in matrix:
            row.append(0)
        new_model = model.copy()
        with ProgressContext("Transform Model") as progress:
            new_model.transform_by_matrix(matrix, callback=progress.update)
        return new_model

    @_set_parser_context("Model transformation 'projection'")
    @_set_allowed_attributes({"action", "center", "vector"})
    @_require_model_type(ModelType.TRIMESH)
    def _get_projected_model(self, model):
        center = self.get_value("center")
        vector = self.get_value("vector")
        plane = Plane(center, vector)
        with ProgressContext("Calculate waterline of model") as progress:
            return model.get_waterline_contour(plane, callback=progress.update)

    @_set_parser_context("Model transformation 'polygon directions'")
    @_set_allowed_attributes({"action"})
    @_require_model_type(ModelType.POLYGON)
    def _get_polygon_transformed(self, model):
        action = self.get_value("action")
        new_model = model.copy()
        if action == ModelTransformationAction.REVISE_POLYGON_DIRECTIONS:
            with ProgressContext("Revise polygon directions") as progress:
                new_model.revise_directions(callback=progress.update)
        elif action == ModelTransformationAction.TOGGLE_POLYGON_DIRECTIONS:
            with ProgressContext("Reverse polygon directions") as progress:
                new_model.reverse_directions(callback=progress.update)
        else:
            assert False
        return new_model

    def validate(self):
        model = pycam.Geometry.Model.Model()
        self.get_transformed_model(model)


class Model(BaseCollectionItemDataContainer):

    collection_name = CollectionName.MODELS
    changed_event = "model-changed"
    list_changed_event = "model-list-changed"
    attribute_converters = {"source": Source,
                            "transformations": _get_list_resolver(ModelTransformation)}
    attribute_defaults = {"transformations": []}

    @CacheStorage({"source", "transformations"})
    @_set_parser_context("Model")
    def get_model(self):
        _log.debug("Generating model {}".format(self.get_id()))
        model = self.get_value("source").get(CollectionName.MODELS)
        for transformation in self.get_value("transformations"):
            model = transformation.get_transformed_model(model)
        return model

    def validate(self):
        self.get_model()


class Tool(BaseCollectionItemDataContainer):

    collection_name = CollectionName.TOOLS
    changed_event = "tool-changed"
    list_changed_event = "tool-list-changed"
    attribute_converters = {"shape": _get_enum_resolver(ToolShape),
                            "tool_id": int,
                            "radius": float,
                            "diameter": float,
                            "toroid_radius": float,
                            "height": float,
                            "feed": float,
                            ("spindle", "speed"): float,
                            ("spindle", "spin_up_delay"): float,
                            ("spindle", "spin_up_enabled"): _bool_converter}
    attribute_defaults = {"tool_id": 1,
                          "height": 10,
                          "feed": 300,
                          ("spindle", "speed"): 1000,
                          ("spindle", "spin_up_delay"): 0,
                          ("spindle", "spin_up_enabled"): True}

    @_set_parser_context("Tool")
    def get_tool_geometry(self):
        height = self.get_value("height")
        shape = self.get_value("shape")
        if shape == ToolShape.FLAT_BOTTOM:
            return CylindricalCutter(self.radius, height=height)
        elif shape == ToolShape.BALL_NOSE:
            return SphericalCutter(self.radius, height=height)
        elif shape == ToolShape.TORUS:
            toroid_radius = self.get_value("toroid_radius")
            return ToroidalCutter(self.radius, toroid_radius, height=height)
        else:
            raise InvalidKeyError(shape, ToolShape)

    @property
    @_set_parser_context("Tool radius")
    def radius(self):
        """ offer a uniform interface for retrieving the radius value from "radius" or "diameter"

        May raise MissingAttributeError if valid input sources are missing.
        """
        try:
            return self.get_value("radius")
        except MissingAttributeError:
            pass
        return self.get_value("diameter") / 2.0

    @property
    def diameter(self):
        return 2 * self.radius

    def get_toolpath_filters(self):
        result = []
        result.append(tp_filters.SelectTool(self.get_value("tool_id")))
        result.append(tp_filters.MachineSetting("feedrate", self.get_value("feed")))
        result.append(tp_filters.SpindleSpeed(self.get_value(("spindle", "speed"))))
        if self.get_value(("spindle", "spin_up_enabled")):
            result.append(tp_filters.TriggerSpindle(
                delay=self.get_value(("spindle", "spin_up_delay"))))
        return result

    def validate(self):
        self.get_tool_geometry()
        self.get_toolpath_filters()


class Process(BaseCollectionItemDataContainer):

    collection_name = CollectionName.PROCESSES
    changed_event = "process-changed"
    list_changed_event = "process-list-changed"
    attribute_converters = {"strategy": _get_enum_resolver(ProcessStrategy),
                            "milling_style": _get_enum_resolver(MotionGrid.MillingStyle),
                            "path_pattern": _get_enum_resolver(PathPattern),
                            "grid_direction": _get_enum_resolver(MotionGrid.GridDirection),
                            "spiral_direction": _get_enum_resolver(MotionGrid.SpiralDirection),
                            "pocketing_type": _get_enum_resolver(MotionGrid.PocketingType),
                            "trace_models": _get_collection_resolver(CollectionName.MODELS,
                                                                     many=True),
                            "rounded_corners": _bool_converter,
                            "radius_compensation": _bool_converter,
                            "overlap": float,
                            "step_down": float}
    attribute_defaults = {"overlap": 0,
                          "path_pattern": PathPattern.GRID,
                          "grid_direction": MotionGrid.GridDirection.X,
                          "spiral_direction": MotionGrid.SpiralDirection.OUT,
                          "rounded_corners": True,
                          "radius_compensation": False}

    @_set_parser_context("Process")
    def get_path_generator(self):
        _log.debug("Retrieving path generator for process {}".format(self.get_id()))
        strategy = _get_enum_value(ProcessStrategy, self.get_value("strategy"))
        if strategy == ProcessStrategy.SLICE:
            return pycam.PathGenerators.PushCutter.PushCutter(waterlines=False)
        elif strategy == ProcessStrategy.CONTOUR:
            return pycam.PathGenerators.PushCutter.PushCutter(waterlines=True)
        elif strategy == ProcessStrategy.SURFACE:
            return pycam.PathGenerators.DropCutter.DropCutter()
        elif strategy == ProcessStrategy.ENGRAVE:
            return pycam.PathGenerators.EngraveCutter.EngraveCutter()
        else:
            raise InvalidKeyError(strategy, ProcessStrategy)

    @_set_parser_context("Process")
    def get_motion_grid(self, tool_radius, box, recurse_immediately=False):
        """ create a generator for the moves to be tried (while respecting obstacles) for a process
        """
        _log.debug("Generating motion grid for process {}".format(self.get_id()))
        strategy = self.get_value("strategy")
        overlap = self.get_value("overlap")
        line_distance = 2 * tool_radius * (1 - overlap)
        with ProgressContext("Calculating moves") as progress:
            if strategy == ProcessStrategy.SLICE:
                milling_style = self.get_value("milling_style")
                path_pattern = self.get_value("path_pattern")
                if path_pattern == PathPattern.SPIRAL:
                    func = functools.partial(MotionGrid.get_spiral,
                                             spiral_direction=self.get_value("spiral_direction"),
                                             rounded_corners=self.get_value("rounded_corners"))
                elif path_pattern == PathPattern.GRID:
                    func = functools.partial(MotionGrid.get_fixed_grid,
                                             grid_direction=self.get_value("grid_direction"))
                else:
                    raise InvalidKeyError(path_pattern, PathPattern)
                motion_grid = func(box, self.get_value("step_down"), line_distance=line_distance,
                                   milling_style=milling_style)
            elif strategy == ProcessStrategy.CONTOUR:
                # The waterline only works with a millingstyle generating parallel lines in the
                # same direction (not going backwards and forwards). Thus we just pick one of the
                # "same direction" styles.
                # TODO: probably the milling style should be configurable (but never "IGNORE").
                motion_grid = MotionGrid.get_fixed_grid(
                    box, self.get_value("step_down"), line_distance=line_distance,
                    grid_direction=MotionGrid.GridDirection.X,
                    milling_style=MotionGrid.MillingStyle.CONVENTIONAL,
                    use_fixed_start_position=True)
            elif strategy == ProcessStrategy.SURFACE:
                milling_style = self.get_value("milling_style")
                path_pattern = self.get_value("path_pattern")
                if path_pattern == PathPattern.SPIRAL:
                    func = functools.partial(MotionGrid.get_spiral,
                                             spiral_direction=self.get_value("spiral_direction"),
                                             rounded_corners=self.get_value("rounded_corners"))
                elif path_pattern == PathPattern.GRID:
                    func = functools.partial(MotionGrid.get_fixed_grid,
                                             grid_direction=self.get_value("grid_direction"))
                else:
                    raise InvalidKeyError(path_pattern, PathPattern)
                # surfacing requires a finer grid (arbitrary factor)
                step_width = tool_radius / 4.0
                motion_grid = func(box, None, step_width=step_width, line_distance=line_distance,
                                   milling_style=milling_style)
            elif strategy == ProcessStrategy.ENGRAVE:
                milling_style = self.get_value("milling_style")
                models = [m.get_model() for m in self.get_value("trace_models")]
                if not models:
                    _log.error("No trace models given: you need to assign a 2D model to the "
                               "engraving process.")
                    return None
                radius_compensation = self.get_value("radius_compensation")
                if radius_compensation:
                    with ProgressContext("Offsetting models") as offset_progress:
                        offset_progress.set_multiple(len(models), "Model")
                        for index, model in enumerate(models):
                            models[index] = model.get_offset_model(tool_radius,
                                                                   callback=offset_progress.update)
                            offset_progress.update_multiple()
                line_distance = 1.8 * tool_radius
                step_width = tool_radius / 4.0
                pocketing_type = self.get_value("pocketing_type")
                motion_grid = MotionGrid.get_lines_grid(
                    models, box, self.get_value("step_down"), line_distance=line_distance,
                    step_width=step_width, milling_style=milling_style,
                    pocketing_type=pocketing_type, skip_first_layer=True, callback=progress.update)
            else:
                raise InvalidKeyError(strategy, ProcessStrategy)
            if recurse_immediately:
                motion_grid = MotionGrid.resolve_multi_level_generator(motion_grid, 2)
        return motion_grid

    def validate(self):
        self.get_path_generator()
        self.get_motion_grid(tool_radius=1, box=Box3D(Point3D(0, 0, 0), Point3D(1, 1, 1)))


class Boundary(BaseCollectionItemDataContainer):

    collection_name = CollectionName.BOUNDS
    changed_event = "bounds-changed"
    list_changed_event = "bounds-list-changed"
    attribute_converters = {"specification": _get_enum_resolver(BoundsSpecification),
                            "reference_models": _get_collection_resolver(CollectionName.MODELS,
                                                                         many=True),
                            "lower": _limit3d_converter,
                            "upper": _limit3d_converter,
                            "tool_boundary": _get_enum_resolver(ToolBoundaryMode)}
    attribute_defaults = {"tool_boundary": ToolBoundaryMode.ALONG,
                          "reference_models": []}

    @_set_parser_context("Boundary")
    def coerce_limits(self, models=None):
        abs_boundary = self.get_absolute_limits(models=models)
        if abs_boundary is None:
            # nothing to be changed
            return
        for axis_name, lower, upper in (("X", abs_boundary.minx, abs_boundary.maxx),
                                        ("Y", abs_boundary.miny, abs_boundary.maxy),
                                        ("Z", abs_boundary.minz, abs_boundary.maxz)):
            if upper < lower:
                # TODO: implement boundary adjustment in case of conflicts
                _log.warning("Negative Boundary encountered for %s: %g < %g. "
                             "Coercing is not implemented, yet.", axis_name, lower, upper)

    @CacheStorage({"specification", "reference_models", "lower", "upper", "tool_boundary"})
    @_set_parser_context("Boundary")
    def get_absolute_limits(self, tool_radius=None, models=None):
        lower = self.get_value("lower")
        upper = self.get_value("upper")
        if self.get_value("specification") == BoundsSpecification.MARGINS:
            # choose the appropriate set of models
            reference_models = self.get_value("reference_models")
            if reference_models:
                # configured models always take precedence
                models = reference_models
            elif models:
                # use the supplied models (e.g. for toolpath calculation)
                pass
            else:
                # use all visible models -> for live visualization
                # TODO: filter for visible models
                models = Model.get_collection()
            model_box = pycam.Geometry.Model.get_combined_bounds([model.get_model()
                                                                  for model in models])
            if model_box is None:
                # zero-sized models -> no action
                return None
            low, high = [], []
            for model_lower, model_upper, margin_lower, margin_upper in zip(
                    model_box.lower, model_box.upper, lower, upper):
                dim = model_upper - model_lower
                if margin_lower.is_relative:
                    low.append(model_lower - margin_lower.value * dim)
                else:
                    low.append(model_lower - margin_lower.value)
                if margin_upper.is_relative:
                    high.append(model_upper + margin_upper.value * dim)
                else:
                    high.append(model_upper + margin_upper.value)
        else:
            # absolute boundary
            low, high = [], []
            for abs_lower, abs_upper in zip(lower, upper):
                if abs_lower.is_relative:
                    raise InvalidDataError("Relative (%) values not allowed for absolute boundary")
                low.append(abs_lower.value)
                if abs_upper.is_relative:
                    raise InvalidDataError("Relative (%) values not allowed for absolute boundary")
                high.append(abs_upper.value)
        tool_limit = self.get_value("tool_boundary")
        # apply inside/along/outside if a tool is given
        if tool_radius and (tool_limit != ToolBoundaryMode.ALONG):
            if tool_limit == ToolBoundaryMode.INSIDE:
                offset = -tool_radius
            else:
                offset = tool_radius
            # apply offset only for x and y
            for index in range(2):
                low[index] -= offset
                high[index] += offset
        return Box3D(Point3D(*low), Point3D(*high))

    def validate(self):
        self.get_absolute_limits()


class Task(BaseCollectionItemDataContainer):

    collection_name = CollectionName.TASKS
    changed_event = "task-changed"
    list_changed_event = "task-list-changed"
    attribute_converters = {"process": _get_collection_resolver(CollectionName.PROCESSES),
                            "bounds": _get_collection_resolver(CollectionName.BOUNDS),
                            "tool": _get_collection_resolver(CollectionName.TOOLS),
                            "type": _get_enum_resolver(TaskType),
                            "collision_models": _get_collection_resolver(CollectionName.MODELS,
                                                                         many=True)}

    @CacheStorage({"process", "bounds", "tool", "type", "collision_models"})
    @_set_parser_context("Task")
    def generate_toolpath(self):
        _log.debug("Generating toolpath for task {}".format(self.get_id()))
        process = self.get_value("process")
        bounds = self.get_value("bounds")
        task_type = self.get_value("type")
        if task_type == TaskType.MILLING:
            tool = self.get_value("tool")
            box = bounds.get_absolute_limits(tool_radius=tool.radius,
                                             models=self.get_value("collision_models"))
            path_generator = process.get_path_generator()
            if path_generator is None:
                # we assume that an error message was given already
                return
            models = [m.get_model() for m in self.get_value("collision_models")]
            if not models:
                # issue a warning - and go ahead ...
                _log.warn("No collision model was selected. This can be intentional, but maybe "
                          "you simply forgot it.")
            motion_grid = process.get_motion_grid(tool.radius, box, recurse_immediately=True)
            _log.debug("MotionGrid completed")
            if motion_grid is None:
                # we assume that an error message was given already
                return
            with ProgressContext("Calculating toolpath") as progress:
                draw_callback = UpdateToolView(
                    progress.update,
                    max_fps=get_event_handler().get("tool_progress_max_fps", 1)).update
                moves = path_generator.generate_toolpath(
                    tool.get_tool_geometry(), models, motion_grid, minz=box.lower.z,
                    maxz=box.upper.z, draw_callback=draw_callback)
            if not moves:
                _log.info("No valid moves found")
                return None
            return pycam.Toolpath.Toolpath(toolpath_path=moves, tool=tool,
                                           toolpath_filters=tool.get_toolpath_filters())
        else:
            raise InvalidKeyError(task_type, TaskType)

    def validate(self):
        # We cannot call "get_toolpath" - this would be too expensive. Use its attribute accesses
        # directly instead.
        self.get_value("process")
        self.get_value("bounds")
        task_type = self.get_value("type")
        if task_type != TaskType.MILLING:
            raise InvalidKeyError(task_type, TaskType)


class ToolpathTransformation(BaseDataContainer):

    attribute_converters = {"action": _get_enum_resolver(ToolpathTransformationAction),
                            # TODO: we should add and implement 'allow_percent=True' here
                            "offset": _axes_values_converter,
                            "clone_count": int,
                            "lower": functools.partial(_axes_values_converter, allow_none=True),
                            "upper": functools.partial(_axes_values_converter, allow_none=True),
                            "shift_target": _get_enum_resolver(PositionShiftTarget),
                            "axes": functools.partial(_axes_values_converter, allow_none=True),
                            "models": _get_collection_resolver(CollectionName.MODELS, many=True)}

    def get_transformed_toolpath(self, toolpath):
        action = self.get_value("action")
        if action == ToolpathTransformationAction.CROP:
            return self._get_cropped_toolpath(toolpath)
        elif action == ToolpathTransformationAction.CLONE:
            return self._get_cloned_toolpath(toolpath)
        elif action == ToolpathTransformationAction.SHIFT:
            return self._get_shifted_toolpath(toolpath)
        else:
            raise InvalidKeyError(action, ToolpathTransformationAction)

    @CacheStorage({"action", "offset", "clone_count"})
    @_set_parser_context("Toolpath transformation 'clone'")
    @_set_allowed_attributes({"action", "offset", "clone_count"})
    def _get_cloned_toolpath(self, toolpath):
        offset = self.get_value("offset")
        clone_count = self.get_value("clone_count")
        new_moves = list(toolpath.path)
        for index in range(1, (clone_count + 1)):
            shift_matrix = ((1, 0, 0, index * offset[0]),
                            (0, 1, 0, index * offset[1]),
                            (0, 0, 1, index * offset[2]))
            shifted = toolpath | tp_filters.TransformPosition(shift_matrix)
            new_moves.extend(shifted)
        new_toolpath = toolpath.copy()
        new_toolpath.path = new_moves
        return new_toolpath

    @CacheStorage({"action", "shift_target", "axes"})
    @_set_parser_context("Model transformation 'shift'")
    @_set_allowed_attributes({"action", "shift_target", "axes"})
    def _get_shifted_toolpath(self, toolpath):
        target = self.get_value("shift_target")
        axes = self.get_value("axes")
        offset = target._get_shift_offset(target, axes, toolpath)
        shift_matrix = ((1, 0, 0, offset[0]),
                        (0, 1, 0, offset[1]),
                        (0, 0, 1, offset[2]))
        new_toolpath = toolpath.copy()
        new_toolpath.path = toolpath | tp_filters.TransformPosition(shift_matrix)
        return new_toolpath

    @CacheStorage({"action", "models"})
    @_set_parser_context("Model transformation 'crop'")
    @_set_allowed_attributes({"action", "models"})
    def _get_cropped_toolpath(self, toolpath):
        polygons = []
        for model in [m.get_model() for m in self.get_value("models")]:
            if hasattr(model, "get_polygons"):
                polygons.extend(model.get_polygons())
            else:
                raise InvalidDataError("Toolpath Crop: 'models' may only contain 2D models")
        # Store the new toolpath first separately - otherwise we can't
        # revert the changes in case of an empty result.
        new_moves = toolpath | tp_filters.Crop(polygons)
        if new_moves | tp_filters.MovesOnly():
            new_toolpath = toolpath.copy()
            new_toolpath.path = new_moves
            return new_toolpath
        else:
            _log.info("Toolpath cropping: the result is empty")
            return None

    def validate(self):
        toolpath = pycam.Toolpath.Toolpath()
        self.get_transformed_toolpath(toolpath)


class Toolpath(BaseCollectionItemDataContainer):

    collection_name = CollectionName.TOOLPATHS
    changed_event = "toolpath-changed"
    list_changed_event = "toolpath-list-changed"
    attribute_converters = {"source": Source,
                            "transformations": _get_list_resolver(ToolpathTransformation)}
    attribute_defaults = {"transformations": []}

    @CacheStorage({"source", "transformations"})
    @_set_parser_context("Toolpath")
    def get_toolpath(self):
        _log.debug("Generating toolpath {}".format(self.get_id()))
        task = self.get_value("source").get(CollectionName.TOOLPATHS)
        toolpath = task.generate_toolpath()
        for transformation in self.get_value("transformations"):
            # the toolpath may be empty or invalidated by a transformation
            if toolpath is not None:
                toolpath = transformation.get_transformed_toolpath(toolpath)
        return toolpath

    def append_transformation(self, transform_dict):
        current_transformations = self.get_value("transformations", raw=True)
        current_transformations.append(copy.deepcopy(transform_dict))
        # verify the result (bail out on error)
        self.attribute_converters["transformations"](current_transformations)
        # there was no problem - overwrite the previous transformations
        self.set_value("transformations", current_transformations)

    def validate(self):
        self.get_toolpath()


class ExportSettings(BaseCollectionItemDataContainer):

    collection_name = CollectionName.EXPORT_SETTINGS
    changed_event = "export-settings-changed"
    list_changed_event = "export-settings-list-changed"

    attribute_converters = {("gcode", ToolpathFilter.UNIT.value): _get_enum_resolver(LengthUnit)}
    attribute_defaults = {("gcode", ToolpathFilter.UNIT.value): LengthUnit.METRIC_MM}

    def get_settings_by_type(self, export_type):
        return self.get_dict().get(export_type, {})

    def set_settings_by_type(self, export_type, value):
        return self.set_value(export_type, value)

    @_set_parser_context("Export settings")
    def get_toolpath_filters(self):
        result = []
        for text_name, parameters in self.get_settings_by_type("gcode").items():
            filter_name = _get_enum_value(ToolpathFilter, text_name)
            if filter_name == ToolpathFilter.SAFETY_HEIGHT:
                result.append(tp_filters.SafetyHeight(float(parameters)))
            elif filter_name == ToolpathFilter.PLUNGE_FEEDRATE:
                result.append(tp_filters.PlungeFeedrate(float(parameters)))
            elif filter_name == ToolpathFilter.STEP_WIDTH:
                result.append(tp_filters.StepWidth({key: float(parameters[key]) for key in "xyz"}))
            elif filter_name == ToolpathFilter.CORNER_STYLE:
                mode = _get_enum_value(pycam.Toolpath.ToolpathPathMode, parameters["mode"])
                motion_tolerance = parameters.get("motion_tolerance", 0)
                naive_tolerance = parameters.get("naive_tolerance", 0)
                result.append(tp_filters.CornerStyle(mode, motion_tolerance, naive_tolerance))
            elif filter_name == ToolpathFilter.FILENAME_EXTENSION:
                # this export setting is only used for filename dialogs
                pass
            elif filter_name == ToolpathFilter.UNIT:
                unit = _get_enum_value(LengthUnit, parameters)
                result.append(tp_filters.MachineSetting("unit", unit))
            elif filter_name == ToolpathFilter.TOUCH_OFF:
                # TODO: implement this (see pycam/Exporters/GCodeExporter.py)
                pass
            else:
                raise InvalidKeyError(filter_name, ToolpathFilter)
        return result

    def validate(self):
        self.get_toolpath_filters()


class Target(BaseDataContainer):

    attribute_converters = {"type": _get_enum_resolver(TargetType)}

    @_set_parser_context("Export target")
    def open(self, dry_run=False):
        _log.debug("Opening target {}".format(self))
        target_type = self.get_value("type")
        if target_type == TargetType.FILE:
            location = self.get_value("location")
            if dry_run:
                # run basic checks and raise errors in case of obvious problems
                if not os.path.isdir(os.path.dirname(location)):
                    raise LoadFileError("Directory of target ({}) does not exist"
                                        .format(location))
            else:
                try:
                    return open(location, "w")
                except OSError as exc:
                    raise LoadFileError(exc)
        else:
            raise InvalidKeyError(target_type, TargetType)

    def validate(self):
        self.open(dry_run=True)


class Formatter(BaseDataContainer):

    attribute_converters = {"type": _get_enum_resolver(FormatType),
                            "filetype": _get_enum_resolver(FileType),
                            "dialect": _get_enum_resolver(GCodeDialect),
                            "export_settings": _get_collection_resolver(
                                CollectionName.EXPORT_SETTINGS)}
    attribute_defaults = {"dialect": GCodeDialect.LINUXCNC,
                          "export_settings": None,
                          "comment": ""}

    @staticmethod
    def _test_sources(items, test_function, message_template):
        failing_items = [item for item in items if not test_function(item)]
        if failing_items:
            raise InvalidDataError(
                message_template.format(" / ".join(get_type_name(item) for item in failing_items)))

    @_set_parser_context("Export formatter: type selection")
    def write_data(self, source, target):
        _log.debug("Writing formatter data {}".format(self))
        # we expect a tuple of items as input
        if not isinstance(source, (list, tuple)):
            raise InvalidDataError("Invalid source data type: {} (expected: list of items)"
                                   .format(get_type_name(source)))
        format_type = self.get_value("type")
        if format_type == FormatType.GCODE:
            self._test_sources(source, lambda item: isinstance(item, Toolpath),
                               "Invalid source data type: {} (expected: list of toolpaths)")
            return self._write_gcode(source, target)
        elif format_type == FormatType.MODEL:
            self._test_sources(source, lambda item: isinstance(item, Model),
                               "Invalid source data type: {} (expected: list of models)")
            self._test_sources(source, lambda item: item.get_model().is_export_supported(),
                               "Sources lacking 'export' support: {}")
            return self._write_model(source, target)
        else:
            raise InvalidKeyError(format_type, FormatType)

    @_set_parser_context("Export formatter 'GCode'")
    @_set_allowed_attributes({"type", "comment", "dialect", "export_settings"})
    def _write_gcode(self, source, target):
        comment = self.get_value("comment")
        dialect = self.get_value("dialect")
        if dialect == GCodeDialect.LINUXCNC:
            generator = pycam.Exporters.GCode.LinuxCNC.LinuxCNC(target, comment=comment)
        else:
            raise InvalidKeyError(dialect, GCodeDialect)
        export_settings = self.get_value("export_settings")
        if export_settings:
            generator.add_filters(export_settings.get_toolpath_filters())
        for toolpath in source:
            calculated = toolpath.get_toolpath()
            # TODO: implement toolpath.get_meta_data()
            generator.add_moves(calculated.path, calculated.filters)
        generator.finish()
        target.close()
        return True

    @_set_parser_context("Export formatter 'Model'")
    @_set_allowed_attributes({"type", "filetype"})
    def _write_model(self, source, target):
        source = tuple(source)
        if source:
            export_name = " / ".join(item.get_id() for item in source)
        else:
            export_name = "unknown"
        combined_model = pycam.Geometry.Model.get_combined_model(item.get_model()
                                                                 for item in source)
        filetype = self.get_value("filetype")
        if filetype == FileType.STL:
            from pycam.Exporters.STLExporter import STLExporter
            self._test_sources(source, lambda item: hasattr(item.get_model(), "triangles"),
                               "Models without triangles: {}")
            exporter = STLExporter(combined_model, name=export_name)
            exporter.write(target)
            target.close()
        else:
            raise InvalidKeyError(filetype, FileType)

    def validate(self):
        self.write_data([], io.StringIO())


class Export(BaseCollectionItemDataContainer):

    collection_name = CollectionName.EXPORTS
    attribute_converters = {"format": Formatter,
                            "source": Source,
                            "target": Target}

    def run_export(self, dry_run=False):
        _log.debug("Running export {}".format(self.get_id()))
        formatter = self.get_value("format")
        source = self.get_value("source").get(CollectionName.EXPORTS)
        target = self.get_value("target")
        if dry_run:
            open_target = io.StringIO()
        else:
            open_target = target.open()
        formatter.write_data(source, open_target)

    def validate(self):
        self.run_export(dry_run=True)
