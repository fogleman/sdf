"""
parse basic structures from an SVG file

The goal of this parser is not to grasp the full complexity of SVG. Only the following items
are supported:
    * "g": grouping of objects into layers
    * "path": parse the "d" attribute via svg.path into straight and non-straight lines

see https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#Groups


Copyright 2018 Lars Kruse <devel@sumpfralle.de>

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
import math

import xml.etree.ElementTree

from pycam.errors import AbortOperationException, MissingDependencyError
import pycam.Geometry.Line
import pycam.Geometry.Polygon
import pycam.Geometry.Model
import pycam.Utils
from pycam.Utils.locations import open_file_context

try:
    import svg.path
except ImportError:
    raise MissingDependencyError("Failed to load python module 'svg.path'. On a Debian-based "
                                 "system you may want to install 'python3-svg.path'.")

log = pycam.Utils.log.get_logger()


# the following tags are known to exist, but are not relevant for our importer
IGNORED_TAGS = {
    "defs",
    "metadata",
    # part of the "text" tag, which already causes a helpful warning to be emitted
    "tspan",
    "{http://creativecommons.org/ns#}Work",
    "{http://purl.org/dc/elements/1.1/}format",
    "{http://purl.org/dc/elements/1.1/}type",
    "{http://purl.org/dc/elements/1.1/}title",
    "{http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd}namedview",
    "{http://www.inkscape.org/namespaces/inkscape}path-effect",
    "{http://www.inkscape.org/namespaces/inkscape}perspective",
    "{http://www.w3.org/1999/02/22-rdf-syntax-ns#}RDF",
}
# these tags are technically difficult or impossible to implement
UNSUPPORTABLE_TAGS = {"text"}

PathGroup = collections.namedtuple("PathGroup", ("id", "paths"))


class SVGXMLParser:

    def __init__(self):
        self.groups = []
        self.namespace = ""
        self._emitted_tag_warnings = set()

    def _append_svg_path(self, path: svg.path.Path):
        if not self.groups:
            self.groups.append(PathGroup(None, []))
        self.groups[-1].paths.append(path)

    @staticmethod
    def _parse_svg_path_from_rectangle(x, y, dim_x, dim_y, rx, ry):
        def get_line(start, end):
            return svg.path.Line(complex(*start), complex(*end))

        def get_small_clockwise_arc(start, radius, end):
            # arc: we pick the small arc (<180 degrees)
            # sweep: we use counter-clockwise direction
            return svg.path.Arc(start=complex(*start), radius=complex(*radius),
                                rotation=0, arc=False, sweep=False, end=complex(*end))

        segments = []
        if rx is None and ry is None:
            # corners of the rectangle in counter-clockwise order
            p1, p2, p3, p4 = (x, y), (x + dim_x, y), (x + dim_x, y + dim_y), (x, y + dim_y)
            segments.append(get_line(p1, p2))
            segments.append(get_line(p2, p3))
            segments.append(get_line(p3, p4))
            segments.append(get_line(p4, p1))
        else:
            # Positions within the rectangle in counter-clockwise order, where the straight lines
            # and the arcs meet.
            p_bottom1, p_bottom2 = (x + rx, y), (x + dim_x - rx, y)
            p_right1, p_right2 = (x + dim_x, y + ry), (x + dim_x, y + dim_y - ry)
            p_top1, p_top2 = (x + dim_x - rx, y + dim_y), (x + rx, y + dim_y)
            p_left1, p_left2 = (x, y + dim_y - ry), (x, y + ry)
            segments.append(get_line(p_bottom1, p_bottom2))
            segments.append(get_small_clockwise_arc(p_bottom2, (rx, ry), p_right1))
            segments.append(get_line(p_right1, p_right2))
            segments.append(get_small_clockwise_arc(p_right2, (rx, ry), p_top1))
            segments.append(get_line(p_top1, p_top2))
            segments.append(get_small_clockwise_arc(p_top2, (rx, ry), p_left1))
            segments.append(get_line(p_left1, p_left2))
            segments.append(get_small_clockwise_arc(p_left2, (rx, ry), p_bottom1))
        path = svg.path.Path(*segments)
        path.closed = True
        return path

    def start(self, tag, attrib):
        if tag.startswith(self.namespace):
            tag = tag[len(self.namespace):]
        if tag.endswith("}svg"):
            self.namespace = tag[:-3]
        elif tag == "g":
            self.groups.append(PathGroup(attrib.get("id"), []))
        elif tag == "path":
            parsed_path = svg.path.parse_path(attrib["d"])
            self._append_svg_path(parsed_path)
        elif tag == "rect":
            parsed_path = self._parse_svg_path_from_rectangle(
                float(attrib["x"]), float(attrib["y"]),
                float(attrib["width"]), float(attrib["height"]),
                float(attrib.get("rx", 0)), float(attrib.get("ry", 0)))
            self._append_svg_path(parsed_path)
        elif tag in IGNORED_TAGS:
            if tag not in self._emitted_tag_warnings:
                log.debug("SVGImporter: ignoring irrelevant tag '<%s>'", tag)
                self._emitted_tag_warnings.add(tag)
        elif tag in UNSUPPORTABLE_TAGS:
            if tag not in self._emitted_tag_warnings:
                log.warning("SVGImporter: encountered the SVG tag '<%s>', which is not supported. "
                            "Please convert this object into a path (e.g. with inkscape).", tag)
                self._emitted_tag_warnings.add(tag)
        else:
            if tag not in self._emitted_tag_warnings:
                log.warning(
                    "SVGImporter: ignoring unsupported SVG element: <%s>. Please open an issue, "
                    "if you think it is a basic element and should be supported.", tag)
                self._emitted_tag_warnings.add(tag)

    def end(self, tag):
        pass

    def data(self, data):
        pass

    def close(self):
        pass


def parse_path_groups_from_svg_file(filename, callback=None):
    """ parse SVG data from a file and return the resulting svg.path objects grouped by layer """
    if callback is None:
        # we are not running interactively - use big chunks
        read_chunk_size = 1 * 1024 ** 3
    else:
        # read smaller 16 KB chunks (improving responsiveness of the GUI)
        read_chunk_size = 64 * 1024 ** 2
    target = SVGXMLParser()
    parser = xml.etree.ElementTree.XMLParser(target=target)
    try:
        with open_file_context(filename, "r", True) as svg_file:
            while True:
                chunk = svg_file.read(read_chunk_size)
                if not chunk:
                    break
                parser.feed(chunk)
                if callback and callback():
                    raise AbortOperationException(
                        "SVGImporter: load model operation was cancelled")
    except IOError as exc:
        log.error("SVGImporter: Failed to read svg file (%s): %s", filename, exc)
        return
    parser.close()
    return target.groups


# TODO: remove the hard-coded accuracy
def _get_polygons_from_svg_path(path: svg.path.Path, z, interpolation_accuracy=0.1,
                                min_interpolation_steps=5, max_interpolation_steps=32):
    """ convert an svg.path.Path object into a list of pycam.Geometry.Polygon.Polygon

    Non-linear segments are interpolated into a set of lines.

    @param z: the wanted z value for all (flat by design) paths
    @param interpolation_accuracy: peferred step width to be used for interpolation
    @param min_interpolation_steps: minimum number of steps to be used for interpolation
    @param max_interpolation_steps: maximum number of steps to be used for interpolation
    """
    polygons = []
    previous_segment_end = None
    for segment in path:
        if not segment:
            continue
        current_segment_start = segment.point(0)
        current_segment_end = segment.point(1)
        if (previous_segment_end is None) or (previous_segment_end != current_segment_start):
            # create a new polygon
            polygons.append(pycam.Geometry.Polygon.Polygon())
        current_polygon = polygons[-1]
        if isinstance(segment, svg.path.Line):
            step_count = 1
        else:
            # we need to add points on the (non-straight) way
            step_count = math.ceil(segment.length() / interpolation_accuracy)
            if min_interpolation_steps is not None:
                step_count = max(min_interpolation_steps, step_count)
            if max_interpolation_steps is not None:
                step_count = min(max_interpolation_steps, step_count)
        assert min_interpolation_steps > 0
        previous_path_point = None
        for step_index in range(0, step_count + 1):
            position = segment.point(step_index / step_count)
            new_point = (position.real, position.imag, z)
            if previous_path_point is not None:
                line = pycam.Geometry.Line.Line(previous_path_point, new_point)
                try:
                    current_polygon.append(line)
                except ValueError:
                    if line.len < 0.0001:
                        # zero-length line warnings are tolerable
                        pass
                    else:
                        raise
            previous_path_point = new_point
        previous_segment_end = current_segment_end
    # filter out all empty polygons
    return [polygon for polygon in polygons if polygon]


def get_polygons_from_path_groups(path_groups, z_level_map=None):
    """ convert a list of PathGroup instances to a list of polygons

    @param z_level_map: optional override of z levels for the different groups. Each group
        without a defined level is assigned a height of zero, one, two and so forth.
    """
    if z_level_map is None:
        z_level_map = {}
    polygons = []
    default_level = 0
    for group in path_groups:
        try:
            level = z_level_map[group.id]
        except KeyError:
            level = default_level
            default_level += 1
        for path in group.paths:
            polygons.extend(_get_polygons_from_svg_path(path, level))
    return polygons


def import_model(filename, callback=None, **kwargs):
    path_groups = parse_path_groups_from_svg_file(filename, callback=callback)
    model = pycam.Geometry.Model.ContourModel()
    for polygon in get_polygons_from_path_groups(path_groups):
        model.append(polygon)
    return model
