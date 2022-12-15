"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>
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

import collections
import decimal
import math

import pycam.Utils.log
_log = pycam.Utils.log.get_logger()


INFINITE = 100000
epsilon = 0.00001

# use the "decimal" module for fixed precision numbers (only for debugging)
_use_precision = False


# the lambda functions below are more efficient than function definitions

if _use_precision:
    ceil = lambda value: int((value + number(1).next_minus()) // 1)
else:
    ceil = lambda value: int(math.ceil(value))

# return "0" for "-epsilon < value < 0" (to work around floating inaccuracies)
# otherwise: return the sqrt function of the current type (could even raise
# exceptions)
if _use_precision:
    sqrt = lambda value: (((value < -epsilon) or (value > 0)) and value.sqrt()) or 0
else:
    sqrt = lambda value: (((value < -epsilon) or (value > 0)) and math.sqrt(value)) or 0

if _use_precision:
    number = lambda value: decimal.Decimal(str(value))
else:
    number = float


Point3D = collections.namedtuple("Point3D", ("x", "y", "z"))
Vector3D = collections.namedtuple("Vector3D", ("x", "y", "z"))


class DimensionalObject:
    """ mixin class for providing 3D objects with size information

    At least the attributes min[xyz] and max[xyz] must be provided by the inheriting class.
    """

    __slots__ = ()

    def get_diagonal(self):
        return Vector3D(self.maxx - self.minx, self.maxy - self.miny, self.maxz - self.minz)

    def get_center(self):
        return Point3D((self.maxx + self.minx) / 2,
                       (self.maxy + self.miny) / 2,
                       (self.maxz + self.minz) / 2)

    def get_dimensions(self):
        return self.get_diagonal()


class Box3D(collections.namedtuple("Box3D", ("lower", "upper")), DimensionalObject):

    __slots__ = ()

    @property
    def minx(self):
        return self.lower.x

    @property
    def miny(self):
        return self.lower.y

    @property
    def minz(self):
        return self.lower.z

    @property
    def maxx(self):
        return self.upper.x

    @property
    def maxy(self):
        return self.upper.y

    @property
    def maxz(self):
        return self.upper.z


def _id_generator():
    current_id = 0
    while True:
        yield current_id
        current_id += 1


class IDGenerator:

    __id_gen_func = _id_generator()

    def __init__(self):
        self.id = next(self.__id_gen_func)


class TransformableContainer(DimensionalObject):
    """ a base class for geometrical objects containing other elements

    This class is mainly used for simplifying model transformations in a
    consistent way.

    Every subclass _must_ implement a 'next' generator returning (via yield)
    its children.
    Additionally a method 'reset_cache' for any custom re-initialization must
    be provided. This method is called when all children of the object were
    successfully transformed.

    A method 'get_children_count' for calculating the number of children
    (recursively) is necessary for the "callback" parameter of
    "transform_by_matrix".

    Optionally the method 'transform_by_matrix' may be used to perform
    object-specific calculations (e.g. retaining the 'normal' vector of a
    triangle).

    The basic primitives that are part of TransformableContainer _must_
    implement the above 'transform_by_matrix' method. These primitives are
    not required to be a subclass of TransformableContainer.
    """

    def transform_by_matrix(self, matrix, transformed_list=None, callback=None):
        from pycam.Geometry.PointUtils import ptransform_by_matrix
        if transformed_list is None:
            transformed_list = []
        # Prevent any kind of loops or double transformations (e.g. Points in
        # multiple containers (Line, Triangle, ...).
        # Use the 'id' builtin to prevent expensive object comparions.
        for item in next(self):
            if isinstance(item, TransformableContainer):
                item.transform_by_matrix(matrix, transformed_list, callback=callback)
            elif not id(item) in transformed_list:
                # Don't transmit the 'transformed_list' if the object is
                # not a TransformableContainer. It is not necessary and it
                # is hard to understand on the lowest level (e.g. Point).
                if isinstance(item, str):
                    theval = getattr(self, item)
                    if isinstance(theval, tuple):
                        setattr(self, item, ptransform_by_matrix(theval, matrix))
                    elif isinstance(theval, list):
                        setattr(self, item, [ptransform_by_matrix(x, matrix) for x in theval])
                elif isinstance(item, tuple):
                    _log.error("ERROR!! A tuple (Point, Vector) made it into base "
                               "transform_by_matrix without a back reference. "
                               "Point/Vector remains unchanged.")
                else:
                    item.transform_by_matrix(matrix, callback=callback)
            # run the callback - e.g. for a progress counter
            if callback and callback():
                # user requesteded abort
                break
        self.reset_cache()

    def __iter__(self):
        return self

    def __next__(self):
        raise NotImplementedError(("'%s' is a subclass of 'TransformableContainer' but it fails "
                                   "to implement the 'next' generator") % str(type(self)))

    def get_children_count(self):
        raise NotImplementedError(("'%s' is a subclass of 'TransformableContainer' but it fails "
                                   "to implement the 'get_children_count' method")
                                  % str(type(self)))

    def reset_cache(self):
        raise NotImplementedError(("'%s' is a subclass of 'TransformableContainer' but it fails "
                                   "to implement the 'reset_cache' method") % str(type(self)))

    def is_completely_inside(self, minx=None, maxx=None, miny=None, maxy=None, minz=None,
                             maxz=None):
        return (((minx is None) or (minx - epsilon <= self.minx))
                and ((maxx is None) or (self.maxx <= maxx + epsilon))
                and ((miny is None) or (miny - epsilon <= self.miny))
                and ((maxy is None) or (self.maxy <= maxy + epsilon))
                and ((minz is None) or (minz - epsilon <= self.minz))
                and ((maxz is None) or (self.maxz <= maxz + epsilon)))

    def is_completely_outside(self, minx=None, maxx=None, miny=None, maxy=None, minz=None,
                              maxz=None):
        return (((maxx is None) or (maxx + epsilon < self.minx))
                or ((minx is None) or (self.maxx < minx - epsilon))
                or ((maxy is None) or (maxy + epsilon < self.miny))
                or ((miny is None) or (self.maxy < miny - epsilon))
                or ((maxz is None) or (maxz + epsilon < self.minz))
                or ((minz is None) or (self.maxz < minz - epsilon)))
