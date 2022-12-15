"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>
Copyright 2008 Lode Leroy

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

import time

from pycam.Geometry import epsilon, INFINITE
from pycam.Geometry.PointUtils import pdist, pnormalized, points_in_line, psub
from pycam.Utils.events import get_event_handler


class Hit:
    def __init__(self, cl, cp, t, d, direction):
        self.cl = cl
        self.cp = cp
        self.t = t
        self.d = d
        self.dir = direction
        self.z = -INFINITE

    def __repr__(self):
        return "%s - %s - %s - %s" % (self.d, self.cl, self.dir, self.cp)


def get_free_paths_triangles(models, cutter, p1, p2, return_triangles=False):
    if (len(models) == 0) or ((len(models) == 1) and (models[0] is None)):
        return (p1, p2)
    elif len(models) == 1:
        # only one model is left - just continue
        model = models[0]
    else:
        # multiple models were given - process them in layers
        result = get_free_paths_triangles(models[:1], cutter, p1, p2, return_triangles)
        # group the result into pairs of two points (start/end)
        point_pairs = []
        while result:
            pair1 = result.pop(0)
            pair2 = result.pop(0)
            point_pairs.append((pair1, pair2))
        all_results = []
        for pair in point_pairs:
            one_result = get_free_paths_triangles(models[1:], cutter, pair[0], pair[1],
                                                  return_triangles)
            all_results.extend(one_result)
        return all_results

    backward = pnormalized(psub(p1, p2))
    forward = pnormalized(psub(p2, p1))
    xyz_dist = pdist(p2, p1)

    minx = min(p1[0], p2[0])
    maxx = max(p1[0], p2[0])
    miny = min(p1[1], p2[1])
    maxy = max(p1[1], p2[1])
    minz = min(p1[2], p2[2])

    # find all hits along scan line
    hits = []

    triangles = model.triangles(minx - cutter.distance_radius, miny - cutter.distance_radius, minz,
                                maxx + cutter.distance_radius, maxy + cutter.distance_radius,
                                INFINITE)

    for t in triangles:
        (cl1, d1, cp1) = cutter.intersect(backward, t, start=p1)
        if cl1:
            hits.append(Hit(cl1, cp1, t, -d1, backward))
        (cl2, d2, cp2) = cutter.intersect(forward, t, start=p1)
        if cl2:
            hits.append(Hit(cl2, cp2, t, d2, forward))

    # sort along the scan direction
    hits.sort(key=lambda h: h.d)

    count = 0
    points = []
    for h in hits:
        if h.dir == forward:
            if count == 0:
                if -epsilon <= h.d <= xyz_dist + epsilon:
                    if len(points) == 0:
                        points.append((p1, None, None))
                    points.append((h.cl, h.t, h.cp))
            count += 1
        else:
            if count == 1:
                if -epsilon <= h.d <= xyz_dist + epsilon:
                    points.append((h.cl, h.t, h.cp))
            count -= 1

    if len(points) % 2 == 1:
        points.append((p2, None, None))

    if len(points) == 0:
        # check if the path is completely free or if we are inside of the model
        inside_counter = 0
        for h in hits:
            if -epsilon <= h.d:
                # we reached the outer limit of the model
                break
            if h.dir == forward:
                inside_counter += 1
            else:
                inside_counter -= 1
        if inside_counter <= 0:
            # we are not inside of the model
            points.append((p1, None, None))
            points.append((p2, None, None))

    if return_triangles:
        return points
    else:
        # return only the cutter locations (without triangles)
        return [cut_info[0] for cut_info in points]


def get_max_height_triangles(model, cutter, x, y, minz, maxz):
    """ calculate the lowest position of a tool at a location without colliding with a model

    @param model: a 3D model
    @param cutter: the tool to be used
    @param x: requested position along the x axis
    @param y: requested position along the y axis
    @param minz: the tool should never go lower
        used as the resulting z level, if no collision was found or it was lower than minz
    @param maxz: the highest allowed tool position
    @result: a tuple (x/y/z) or None (if the height limit was exeeded)
    """
    if model is None:
        return (x, y, minz)
    p = (x, y, maxz)
    height_max = None
    box_x_min = cutter.get_minx(p)
    box_x_max = cutter.get_maxx(p)
    box_y_min = cutter.get_miny(p)
    box_y_max = cutter.get_maxy(p)
    box_z_min = minz
    box_z_max = maxz
    # reduce the set of triangles to be checked for collisions
    triangles = model.triangles(box_x_min, box_y_min, box_z_min, box_x_max, box_y_max, box_z_max)
    for t in triangles:
        cut = cutter.drop(t, start=p)
        if cut and ((height_max is None) or (cut[2] > height_max)):
            height_max = cut[2]
    if (height_max is None) or (height_max < minz + epsilon):
        # no collision occurred or the collision height is lower than the minimum
        return (x, y, minz)
    elif height_max > maxz + epsilon:
        # there was a collision above the upper allowed z level -> no suitable tool location found
        return None
    else:
        # a suitable tool location was found within the bounding box
        return (x, y, height_max)


def _get_dynamic_fill_points(start, end, max_height_point_func, remaining_levels):
    """ generator for adding points between two given points

    Points are only added, if the point in their middle (especially its height) is not in line with
    the outer points.
    More points are added recursively (limited via "remaining_levels") between start/middle and
    middle/end.
    The start and end points are never emitted.  This should be done by the caller.
    """
    if remaining_levels <= 0:
        return
    middle = max_height_point_func((start[0] + end[0]) / 2, (start[1] + end[1]) / 2)
    if middle is None:
        return
    if points_in_line(start, middle, end):
        return
    # the three points are not in line - thus we should add some interval points
    for p in _get_dynamic_fill_points(start, middle, max_height_point_func, remaining_levels - 1):
        yield p
    yield middle
    for p in _get_dynamic_fill_points(middle, end, max_height_point_func, remaining_levels - 1):
        yield p


def _dynamic_point_fill_generator(positions, max_height_point_func, max_level_count):
    """ add more points between the given positions in order to detect minor bumps in the model

    If the calculated height between two given positions (points) is not in line with its
    neighbours, then additional points are added until the recursion limit ("max_level_count") is
    reached or until the interpolated points are in line with their neighbours.
    The input positions are returned unchanged, if less than three points are given.
    """
    # handle incoming lists/tuples as well as generators
    positions = iter(positions)
    if max_level_count <= 0:
        # reached the maximum recursion limit - simply deliver the input values
        for p in positions:
            yield p
        return
    try:
        p1 = next(positions)
    except StopIteration:
        # no items were provided - we do the same
        return
    try:
        p2 = next(positions)
    except StopIteration:
        # only one item was provided - we just deliver it unchanged
        yield p1
        return
    last_segment_wants_more_points = False
    for p3 in positions:
        yield p1
        if (None not in (p1, p2, p3)) and not points_in_line(p1, p2, p3):
            for p in _get_dynamic_fill_points(p1, p2, max_height_point_func, max_level_count - 1):
                yield p
            last_segment_wants_more_points = True
        else:
            last_segment_wants_more_points = False
        p1, p2 = p2, p3
    yield p1
    if last_segment_wants_more_points:
        for p in _get_dynamic_fill_points(p1, p2, max_height_point_func, max_level_count - 1):
            yield p
    yield p2


def _filter_linear_points(positions):
    """ reduce the input positions by removing all points which are in line with their neighbours

    The input can be either a list or a generator.
    """
    # handle incoming lists/tuples as well as generators
    positions = iter(positions)
    try:
        p1 = next(positions)
    except StopIteration:
        # no items were provided - we do the same
        return
    try:
        p2 = next(positions)
    except StopIteration:
        # only one item was provided - we just deliver it unchanged
        yield p1
        return
    for p3 in positions:
        if (None not in (p1, p2, p3) and points_in_line(p1, p2, p3)):
            # the three points are in line -> skip p2
            p2 = p3
        else:
            # the three points are not in line -> emit them unchanged
            yield p1
            p1, p2 = p2, p3
    # emit the backlog
    yield p1
    yield p2


def get_max_height_dynamic(model, cutter, positions, minz, maxz, max_depth=5):
    """ calculate the tool positions based on a given set of x/y locations

    The given input locations should be suitable for the tool size in order to find all relevant
    major features of the model.  Additional locations are recursively added, if the calculated
    height between every set of two points is not in line with its neighbours.
    The result is a list of points to be traveled by the tool.
    """
    # for now there is only a triangle-mesh based calculation
    get_max_height = lambda x, y: get_max_height_triangles(model, cutter, x, y, minz, maxz)
    # calculate suitable tool locations (without collisions) for each given position
    points_with_height = (get_max_height(x, y) for x, y in positions)
    # Spread more positions between the existing ones.
    dynamically_filled_points = _dynamic_point_fill_generator(points_with_height, get_max_height,
                                                              max_depth)
    # Remove all points that are in line between their neighbours.
    return list(_filter_linear_points(dynamically_filled_points))


class UpdateToolView:
    """ visualize the position of the tool and the partial toolpath during toolpath generation """

    def __init__(self, callback, max_fps=1):
        self.callback = callback
        self.core = get_event_handler()
        self.last_update_time = time.time()
        self.max_fps = max_fps
        self.last_tool_position = None
        self.current_tool_position = None

    def update(self, text=None, percent=None, tool_position=None, toolpath=None):
        if toolpath is not None:
            self.core.set("toolpath_in_progress", toolpath)
        # always store the most recently reported tool_position for the next visualization
        if tool_position is not None:
            self.current_tool_position = tool_position
        redraw_wanted = False
        current_time = time.time()
        if (current_time - self.last_update_time) > 1.0 / self.max_fps:
            if self.current_tool_position != self.last_tool_position:
                tool = self.core.get("current_tool")
                if tool:
                    tool.moveto(self.current_tool_position)
                self.last_tool_position = self.current_tool_position
                redraw_wanted = True
            if self.core.get("show_toolpath_progress"):
                redraw_wanted = True
            self.last_update_time = current_time
            if redraw_wanted:
                self.core.emit_event("visual-item-updated")
        # break the loop if someone clicked the "cancel" button
        return self.callback(text=text, percent=percent)
