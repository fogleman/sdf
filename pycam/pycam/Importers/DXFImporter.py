"""
$ID$

Copyright 2010 Lars Kruse <devel@sumpfralle.de>

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

import math
import re
import os

from pycam.errors import AbortOperationException, LoadFileError
from pycam.Geometry.Triangle import Triangle
from pycam.Geometry.PointUtils import pdist
from pycam.Geometry.Line import Line
import pycam.Geometry.Model
import pycam.Geometry.Matrix
from pycam.Geometry.utils import get_bezier_lines, get_points_of_arc
import pycam.Utils.log
import pycam.Utils

log = pycam.Utils.log.get_logger()


def _unescape_control_characters(text):
    # see http://www.kxcad.net/autodesk/autocad/AutoCAD_2008_Command_Reference/d0e73428.htm
    # and QCad: qcadlib/src/filters/rs_filterdxf.cpp
    for src, dest in (("%%d", u"\u00B0"), ("%%p", u"\u00B1"), ("%%c", u"\u2205"),
                      (r"\P", os.linesep), (r"\~", " ")):
        text = text.replace(src, dest)
    # convert "\U+xxxx" to unicode characters
    return re.sub(r"\\U\+([0-9a-fA-F]{4})", lambda hex_in: chr(int(hex_in.groups()[0], 16)), text)


class DXFParser:
    """ parse most entities of an DXF file

    Reference: http://images.autodesk.com/adsk/files/autocad_2012_pdf_dxf-reference_enu.pdf
    """

    # see http://www.autodesk.com/techpubs/autocad/acad2000/dxf/group_code_value_types_dxf_01.htm
    MAX_CHARS_PER_LINE = 2049

    KEYS = {
        "MARKER": 0,
        "DEFAULT": 1,
        "TEXT_MORE": 3,
        "TEXT_FONT": 7,
        "P1_X": 10,
        "P1_Y": 20,
        "P1_Z": 30,
        "P2_X": 11,
        "P2_Y": 21,
        "P2_Z": 31,
        "P3_X": 12,
        "P3_Y": 22,
        "P3_Z": 32,
        "P4_X": 13,
        "P4_Y": 23,
        "P4_Z": 33,
        "RADIUS": 40,
        "TEXT_HEIGHT": 40,
        "TEXT_WIDTH_FINAL": 41,
        "VERTEX_BULGE": 42,
        "ANGLE_START": 50,
        "TEXT_ROTATION": 50,
        "ANGLE_END": 51,
        "TEXT_SKEW_ANGLE": 51,
        "COLOR": 62,
        # in the context of the current entity (e.g. VERTEX / POLYLINE / LWPOLYLINE)
        "ENTITY_FLAGS": 70,
        "TEXT_MIRROR_FLAGS": 71,
        "MTEXT_ALIGNMENT": 71,
        "TEXT_ALIGN_HORIZONTAL": 72,
        "TEXT_ALIGN_VERTICAL": 73,
        "CURVE_TYPE": 75,
    }

    IGNORE_KEYS = ("DICTIONARY", "VPORT", "LTYPE", "STYLE", "APPID", "DIMSTYLE", "BLOCK_RECORD",
                   "BLOCK", "ENDBLK", "ACDBDICTIONARYWDFLT", "POINT", "ACDBPLACEHOLDER", "LAYOUT",
                   "MLINESTYLE", "DICTIONARYVAR", "CLASS", "HATCH", "VIEW", "VIEWPORT")

    def __init__(self, inputstream, color_as_height=False, fonts_cache=None, callback=None):
        self.inputstream = inputstream
        self.line_number = 0
        self.lines = []
        self.triangles = []
        self._input_stack = []
        self._color_as_height = color_as_height
        if callback:
            # no "percent" updates - just pulse ...
            def callback_wrapper(text="", percent=None):
                return callback()
            self.callback = callback_wrapper
        else:
            self.callback = None
        self._fonts_cache = fonts_cache
        self._open_sequence = None
        self._open_sequence_items = []
        self._open_sequence_params = {}
        # run the parser
        self.parse_content()
        self.optimize_line_order()

    def get_model(self):
        return {"lines": self.lines, "triangles": self.triangles}

    def optimize_line_order(self):
        groups = []
        current_group = []
        groups.append(current_group)
        remaining_lines = self.lines[:]
        while remaining_lines:
            if self.callback and self.callback():
                return
            if not current_group:
                current_group.append(remaining_lines.pop(0))
            else:
                first_line = current_group[0]
                last_line = current_group[-1]
                for line in remaining_lines:
                    if last_line.p2 == line.p1:
                        current_group.append(line)
                        remaining_lines.remove(line)
                        break
                    if first_line.p1 == line.p2:
                        current_group.insert(0, line)
                        remaining_lines.remove(line)
                        break
                else:
                    current_group = []
                    groups.append(current_group)

        def get_distance_between_groups(group1, group2):
            forward = pdist(group1[-1].p2, group2[0].p1)
            backward = pdist(group2[-1].p2, group1[0].p1)
            return min(forward, backward)

        remaining_groups = groups[:]
        ordered_groups = []
        while remaining_groups:
            if not ordered_groups:
                ordered_groups.append(remaining_groups.pop(0))
            else:
                current_group = ordered_groups[-1]
                closest_distance = None
                for cmp_group in remaining_groups:
                    cmp_distance = get_distance_between_groups(current_group, cmp_group)
                    if (closest_distance is None) or (cmp_distance < closest_distance):
                        closest_distance = cmp_distance
                        closest_group = cmp_group
                ordered_groups.append(closest_group)
                remaining_groups.remove(closest_group)
        result = []
        for group in ordered_groups:
            result.extend(group)
        self.lines = result

    def _push_on_stack(self, key, value):
        self._input_stack.append((key, value))

    def _read_key_value(self):
        if self._input_stack:
            return self._input_stack.pop()
        try:
            line1 = self.inputstream.readline(self.MAX_CHARS_PER_LINE).strip()
            line2 = self.inputstream.readline(self.MAX_CHARS_PER_LINE).strip()
        except IOError:
            return None, None
        if not line1 and not line2:
            return None, None
        try:
            line1 = int(line1)
        except ValueError:
            log.warn("DXFImporter: Invalid key in line %d (int expected): %s",
                     self.line_number, line1)
            return None, None
        if line1 in [self.KEYS[key]
                     for key in ("P1_X", "P1_Y", "P1_Z", "P2_X", "P2_Y", "P2_Z", "RADIUS",
                                 "ANGLE_START", "ANGLE_END", "TEXT_HEIGHT", "TEXT_WIDTH_FINAL",
                                 "TEXT_ROTATION", "TEXT_SKEW_ANGLE", "VERTEX_BULGE")]:
            try:
                line2 = float(line2)
            except ValueError:
                log.warn("DXFImporter: Invalid input in line %d (float expected): %s",
                         self.line_number, line2)
                line1 = None
                line2 = None
        elif line1 in [self.KEYS[key]
                       for key in ("COLOR", "TEXT_MIRROR_FLAGS", "TEXT_ALIGN_HORIZONTAL",
                                   "TEXT_ALIGN_VERTICAL", "MTEXT_ALIGNMENT", "CURVE_TYPE",
                                   "ENTITY_FLAGS")]:
            try:
                line2 = int(line2)
            except ValueError:
                log.warn("DXFImporter: Invalid input in line %d (int expected): %s",
                         self.line_number, line2)
                line1 = None
                line2 = None
        elif line1 in [self.KEYS[key] for key in ("DEFAULT", "TEXT_MORE")]:
            line2 = _unescape_control_characters(self._carefully_decode(line2))
        else:
            line2 = self._carefully_decode(line2).upper()
        self.line_number += 2
        return line1, line2

    def _carefully_decode(self, text):
        try:
            return text.decode("utf-8")
        except UnicodeDecodeError:
            log.warn("DXFImporter: Invalid character in string in line %d", self.line_number)
            return text.decode("utf-8", errors="ignore")

    def parse_content(self):
        key, value = self._read_key_value()
        while (key is not None) and not ((key == self.KEYS["MARKER"]) and (value == "EOF")):
            if self.callback and self.callback():
                return
            if key == self.KEYS["MARKER"]:
                if value in ("SECTION", "TABLE", "LAYER", "ENDTAB", "ENDSEC"):
                    # we don't handle these meta-information
                    pass
                elif value == "LINE":
                    self.parse_line()
                elif value == "LWPOLYLINE":
                    self.parse_lwpolyline()
                elif value == "POLYLINE":
                    self.parse_polyline(True)
                elif value == "VERTEX":
                    self.parse_vertex()
                elif value == "SEQEND":
                    self.close_sequence()
                elif value == "ARC":
                    self.parse_arc()
                elif value == "CIRCLE":
                    self.parse_arc(circle=True)
                elif value == "TEXT":
                    self.parse_text()
                elif value == "MTEXT":
                    self.parse_mtext()
                elif value == "3DFACE":
                    self.parse_3dface()
                elif value in self.IGNORE_KEYS:
                    log.debug("DXFImporter: Ignored a blacklisted element in line %d: %s",
                              self.line_number, value)
                else:
                    # not supported
                    log.warn("DXFImporter: Ignored unsupported element in line %d: %s",
                             self.line_number, value)
            key, value = self._read_key_value()

    def close_sequence(self):
        start_line = self.line_number
        if self._open_sequence == "POLYLINE":
            self.parse_polyline(False)
        else:
            log.warn("DXFImporter: unexpected SEQEND found at line %d", start_line)

    def parse_vertex(self):
        start_line = self.line_number
        point = [None, None, 0]
        color = None
        bulge = None
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["P1_X"]:
                point[0] = value
            elif key == self.KEYS["P1_Y"]:
                point[1] = value
            elif key == self.KEYS["P1_Z"]:
                point[2] = value
            elif key == self.KEYS["COLOR"]:
                color = value
            elif key == self.KEYS["VERTEX_BULGE"]:
                bulge = value
            else:
                pass
            key, value = self._read_key_value()
        end_line = self.line_number
        if key is not None:
            self._push_on_stack(key, value)
        if self._color_as_height and (color is not None):
            # use the color code as the z coordinate
            point[2] = float(color) / 255
        if None in point:
            log.warn("DXFImporter: Missing attribute of VERTEX item between line %d and %d",
                     start_line, end_line)
        else:
            self._open_sequence_items.append(((point[0], point[1], point[2]), bulge))

    def parse_polyline(self, init):
        params = self._open_sequence_params
        if init:
            self._open_sequence = "POLYLINE"
            self._open_sequence_items = []
            key, value = self._read_key_value()
            while (key is not None) and (key != self.KEYS["MARKER"]):
                if key == self.KEYS["CURVE_TYPE"]:
                    if value == 8:
                        params["CURVE_TYPE"] = "BEZIER"
                elif key == self.KEYS["ENTITY_FLAGS"]:
                    if value == 1:
                        if "ENTITY_FLAGS" not in params:
                            params["ENTITY_FLAGS"] = set()
                        params["ENTITY_FLAGS"].add("IS_CLOSED")
                key, value = self._read_key_value()
            if key is not None:
                self._push_on_stack(key, value)
        else:
            # closing
            if ("CURVE_TYPE" in params) and (params["CURVE_TYPE"] == "BEZIER"):
                self.lines.extend(get_bezier_lines(self._open_sequence_items))
                if ("ENTITY_FLAGS" in params) and ("IS_CLOSED" in params["ENTITY_FLAGS"]):
                    # repeat the same polyline on the other side
                    self._open_sequence_items.reverse()
                    self.lines.extend(get_bezier_lines(self._open_sequence_items))
            else:
                points = [p for p, bulge in self._open_sequence_items]
                for index in range(len(points) - 1):
                    point = points[index]
                    next_point = points[index + 1]
                    if point != next_point:
                        self.lines.append(Line(point, next_point))
                if ("ENTITY_FLAGS" in params) and ("IS_CLOSED" in params["ENTITY_FLAGS"]):
                    # repeat the same polyline on the other side
                    self.lines.append(Line(points[-1], points[0]))
            self._open_sequence_items = []
            self._open_sequence_params = {}
            self._open_sequence = None

    def parse_lwpolyline(self):
        start_line = self.line_number
        points = []

        def add_point(p_array, bulge):
            # fill all "None" values with zero
            for index in range(len(p_array)):
                if p_array[index] is None:
                    if (index == 0) or (index == 1):
                        log.debug("DXFImporter: weird LWPOLYLINE input date in line %d: %s",
                                  self.line_number, p_array)
                    p_array[index] = 0
            points.append(((p_array[0], p_array[1], p_array[2]), bulge))

        current_point = [None, None, None]
        bulge = None
        is_closed = False
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["P1_X"]:
                axis = 0
            elif key == self.KEYS["P1_Y"]:
                axis = 1
            elif not self._color_as_height and (key == self.KEYS["P1_Z"]):
                axis = 2
            elif self._color_as_height and (key == self.KEYS["COLOR"]):
                # interpret the color as the height
                axis = 2
                value = float(value) / 255
            elif key == self.KEYS["VERTEX_BULGE"]:
                bulge = value
                axis = None
            elif key == self.KEYS["ENTITY_FLAGS"]:
                if value == 1:
                    is_closed = True
                axis = None
            else:
                axis = None
            if axis is not None:
                if current_point[axis] is None:
                    # The current point definition is not complete, yet.
                    current_point[axis] = value
                else:
                    # The current point seems to be complete.
                    add_point(current_point, bulge)
                    current_point = [None, None, None]
                    current_point[axis] = value
                    bulge = None
            key, value = self._read_key_value()
        end_line = self.line_number
        # The last lines were not used - they are just the marker for the next
        # item.
        if key is not None:
            self._push_on_stack(key, value)
        # check if there is a remaining item in "current_point"
        if len(current_point) != current_point.count(None):
            add_point(current_point, bulge)
        if len(points) < 2:
            # too few points for a polyline
            log.warn("DXFImporter: Empty LWPOLYLINE definition between line %d and %d",
                     start_line, end_line)
        else:
            if is_closed:
                points.append(points[0])
            for index in range(len(points) - 1):
                point, bulge = points[index]
                # It seems like the "next_bulge" value is not relevant for the current set of
                # vertices. At least the test DXF file "bezier_lines.dxf" indicates, that we can
                # ignore it for the decision about a straight line or a bezier line.
                next_point = points[index + 1][0]
                if point != next_point:
                    if bulge:
                        self.lines.extend(get_bezier_lines(((point, bulge), (next_point, bulge))))
                    else:
                        # straight line
                        self.lines.append(Line(point, next_point))
                else:
                    log.warn("DXFImporter: Ignoring zero-length LINE (between input line %d and "
                             "%d): %s", start_line, end_line, point)

    def parse_mtext(self):
        start_line = self.line_number
        # the z-level defaults to zero (for 2D models)
        ref_point = [None, None, 0]
        direction_vector = [None, None, None]
        color = None
        text_groups_start = []
        text_end = []
        text_height = None
        rotation = 0
        width_final = None
        font_name = "normal"
        alignment = 0
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["DEFAULT"]:
                text_end = value
            elif key == self.KEYS["TEXT_MORE"]:
                text_groups_start.append(value)
            elif key == self.KEYS["P1_X"]:
                ref_point[0] = value
            elif key == self.KEYS["P1_Y"]:
                ref_point[1] = value
            elif key == self.KEYS["P1_Z"]:
                ref_point[2] = value
            elif key == self.KEYS["P2_X"]:
                direction_vector[0] = value
                # according to DXF spec: the last one wins
                rotation = None
            elif key == self.KEYS["P2_Y"]:
                direction_vector[1] = value
                # according to DXF spec: the last one wins
                rotation = None
            elif key == self.KEYS["P2_Z"]:
                direction_vector[2] = value
                # according to DXF spec: the last one wins
                rotation = None
            elif key == self.KEYS["COLOR"]:
                color = value
            elif key == self.KEYS["TEXT_HEIGHT"]:
                text_height = value
            elif key == self.KEYS["TEXT_ROTATION"]:
                rotation = value
                # according to DXF spec: the last one wins
                direction_vector = [None, None, None]
            elif key == self.KEYS["TEXT_FONT"]:
                font_name = value
            elif key == self.KEYS["MTEXT_ALIGNMENT"]:
                alignment = value
            elif key == self.KEYS["TEXT_WIDTH_FINAL"]:
                width_final = value
            else:
                pass
            key, value = self._read_key_value()
        end_line = self.line_number
        # The last lines were not used - they are just the marker for the next
        # item.
        text = "".join(text_groups_start) + text_end
        if key is not None:
            self._push_on_stack(key, value)
        if None in ref_point:
            log.warn("DXFImporter: Incomplete MTEXT definition between line %d and %d: missing "
                     "location point", start_line, end_line)
        elif not text:
            log.warn("DXFImporter: Incomplete MTEXT definition between line %d and %d: missing "
                     "text", start_line, end_line)
        elif not text_height:
            log.warn("DXFImporter: Incomplete MTEXT definition between line %d and %d: missing "
                     "height", start_line, end_line)
        else:
            if self._color_as_height and (color is not None):
                # use the color code as the z coordinate
                ref_point[2] = float(color) / 255
            if self._fonts_cache:
                font = self._fonts_cache.get_font(font_name)
            else:
                font = None
            if not font:
                log.warn("DXFImporter: No fonts are available - skipping MTEXT item between line "
                         "%d and %d", start_line, end_line)
                return
            model = font.render(text)
            if (None in (model.minx, model.miny, model.minz)
                    or (model.minx == model.maxx) or (model.miny == model.maxy)):
                log.warn("DXFImporter: Empty rendered MTEXT item between line %d and %d",
                         start_line, end_line)
                return
            model.scale(text_height / (model.maxy - model.miny), callback=self.callback)
            # this setting seems to refer to a box - not the text width - ignore
            if False and width_final:
                scale_x = width_final / (model.maxx - model.minx)
                model.scale(scale_x, callback=self.callback)
            if rotation:
                matrix = pycam.Geometry.Matrix.get_rotation_matrix_axis_angle((0, 0, 1), rotation)
            elif None not in direction_vector:
                # Due to the parsing code above only "rotation" or
                # "direction_vector" is set at the same time.
                matrix = pycam.Geometry.Matrix.get_rotation_matrix_from_to((1, 0, 0),
                                                                           direction_vector)
            else:
                matrix = None
            if matrix:
                model.transform_by_matrix(matrix, callback=self.callback)
            # horizontal alignment
            if alignment % 3 == 1:
                offset_horiz = 0
            elif alignment % 3 == 2:
                offset_horiz = -(model.maxx - model.minx) / 2
            else:
                offset_horiz = -(model.maxx - model.minx)
            # vertical alignment
            if alignment <= 3:
                offset_vert = -(model.maxy - model.miny)
            elif alignment <= 6:
                offset_vert = -(model.maxy - model.miny) / 2
            else:
                offset_vert = 0
            # shift the text to its final destination
            shift_x = ref_point[0] - model.minx + offset_horiz
            shift_y = ref_point[1] - model.miny + offset_vert
            shift_z = ref_point[2] - model.minz
            model.shift(shift_x, shift_y, shift_z, callback=self.callback)
            for polygon in model.get_polygons():
                for line in polygon.get_lines():
                    self.lines.append(line)

    def parse_text(self):
        start_line = self.line_number
        # the z-level defaults to zero (for 2D models)
        ref_point = [None, None, 0]
        ref_point2 = [None, None, 0]
        color = None
        text = None
        text_height = None
        rotation = 0
        width_final = None
        skew_angle = 0
        font_name = "normal"
        mirror_flags = 0
        align_horiz = 0
        align_vert = 0
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["DEFAULT"]:
                text = value
            elif key == self.KEYS["P1_X"]:
                ref_point[0] = value
            elif key == self.KEYS["P1_Y"]:
                ref_point[1] = value
            elif key == self.KEYS["P1_Z"]:
                ref_point[2] = value
            elif key == self.KEYS["P2_X"]:
                ref_point2[0] = value
            elif key == self.KEYS["P2_Y"]:
                ref_point2[1] = value
            elif key == self.KEYS["P2_Z"]:
                ref_point2[2] = value
            elif key == self.KEYS["COLOR"]:
                color = value
            elif key == self.KEYS["TEXT_HEIGHT"]:
                text_height = value
            elif key == self.KEYS["TEXT_ROTATION"]:
                rotation = value
            elif key == self.KEYS["TEXT_SKEW_ANGLE"]:
                skew_angle = value
            elif key == self.KEYS["TEXT_FONT"]:
                font_name = value
            elif key == self.KEYS["TEXT_MIRROR_FLAGS"]:
                mirror_flags = value
            elif key == self.KEYS["TEXT_ALIGN_HORIZONTAL"]:
                align_horiz = value
            elif key == self.KEYS["TEXT_ALIGN_VERTICAL"]:
                align_vert = value
            elif key == self.KEYS["TEXT_WIDTH_FINAL"]:
                width_final = value
            else:
                pass
            key, value = self._read_key_value()
        end_line = self.line_number
        # The last lines were not used - they are just the marker for the next
        # item.
        if key is not None:
            self._push_on_stack(key, value)
        if (None not in ref_point2) and (ref_point != ref_point2):
            # just a warning - continue as usual
            log.warn("DXFImporter: Second alignment point is not implemented for TEXT items - the "
                     "text specified between line %d and %d may be slightly misplaced",
                     start_line, end_line)
        if None in ref_point:
            log.warn("DXFImporter: Incomplete TEXT definition between line %d and %d: missing "
                     "location point", start_line, end_line)
        elif not text:
            log.warn("DXFImporter: Incomplete TEXT definition between line %d and %d: missing "
                     "text", start_line, end_line)
        elif not text_height:
            log.warn("DXFImporter: Incomplete TEXT definition between line %d and %d: missing "
                     "height", start_line, end_line)
        else:
            if self._color_as_height and (color is not None):
                # use the color code as the z coordinate
                ref_point[2] = float(color) / 255
            if self._fonts_cache:
                font = self._fonts_cache.get_font(font_name)
            else:
                font = None
            if not font:
                log.warn("DXFImporter: No fonts are available - skipping TEXT item between line "
                         "%d and %d", start_line, end_line)
                return
            if skew_angle:
                # calculate the "skew" factor
                if (skew_angle <= -90) or (skew_angle >= 90):
                    log.warn("DXFImporter: Invalid skew angle for TEXT between line %d and %d",
                             start_line, end_line)
                    skew = 0
                else:
                    skew = math.tan(skew_angle)
            else:
                skew = 0
            model = font.render(text, skew=skew)
            if ((model.minx is None) or (model.miny is None)
                    or (model.minz is None) or (model.minx == model.maxx)
                    or (model.miny == model.maxy)):
                log.warn("DXFImporter: Empty rendered TEXT item between line %d and %d",
                         start_line, end_line)
                return
            model.scale(text_height / (model.maxy - model.miny), callback=self.callback)
            if mirror_flags & 2:
                # x mirror left/right
                model.transform_by_template("yz_mirror", callback=self.callback)
            if mirror_flags & 4:
                # y mirror upside/down
                model.transform_by_template("xz_mirror", callback=self.callback)
            # this setting seems to refer to a box - not the text width - ignore
            if False and width_final:
                scale_x = width_final / (model.maxx - model.minx)
                model.scale(scale_x, callback=self.callback)
            if rotation:
                matrix = pycam.Geometry.Matrix.get_rotation_matrix_axis_angle((0, 0, 1), rotation)
                model.transform_by_matrix(matrix, callback=self.callback)
            # horizontal alignment
            if align_horiz == 0:
                offset_horiz = 0
            elif align_horiz == 1:
                offset_horiz = - (model.maxx - model.minx) / 2
            elif align_horiz == 2:
                offset_horiz = - (model.maxx - model.minx)
            else:
                log.warn("DXFImporter: Horizontal TEXT justifications (3..5) are not supported - "
                         "ignoring (between line %d and %d)", start_line, end_line)
                offset_horiz = 0
            # vertical alignment
            if align_vert in (0, 1):
                # we don't distinguish between "bottom" and "base"
                offset_vert = 0
            elif align_vert == 2:
                offset_vert = - (model.maxy - model.miny) / 2
            elif align_vert == 3:
                offset_vert = - (model.maxy - model.miny)
            else:
                log.warn("DXFImporter: Invalid vertical TEXT justification between line %d and %d",
                         start_line, end_line)
                offset_vert = 0
            # shift the text to its final destination
            shift_x = ref_point[0] - model.minx + offset_horiz
            shift_y = ref_point[1] - model.miny + offset_vert
            shift_z = ref_point[2] - model.minz
            model.shift(shift_x, shift_y, shift_z, callback=self.callback)
            for polygon in model.get_polygons():
                for line in polygon.get_lines():
                    self.lines.append(line)

    def parse_3dface(self):
        start_line = self.line_number
        # the z-level defaults to zero (for 2D models)
        p1 = [None, None, 0]
        p2 = [None, None, 0]
        p3 = [None, None, 0]
        p4 = [None, None, 0]
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["P1_X"]:
                p1[0] = value
            elif key == self.KEYS["P1_Y"]:
                p1[1] = value
            elif key == self.KEYS["P1_Z"]:
                p1[2] = value
            elif key == self.KEYS["P2_X"]:
                p2[0] = value
            elif key == self.KEYS["P2_Y"]:
                p2[1] = value
            elif key == self.KEYS["P2_Z"]:
                p2[2] = value
            elif key == self.KEYS["P3_X"]:
                p3[0] = value
            elif key == self.KEYS["P3_Y"]:
                p3[1] = value
            elif key == self.KEYS["P3_Z"]:
                p3[2] = value
            elif key == self.KEYS["P4_X"]:
                p4[0] = value
            elif key == self.KEYS["P4_Y"]:
                p4[1] = value
            elif key == self.KEYS["P4_Z"]:
                p4[2] = value
            else:
                pass
            key, value = self._read_key_value()
        end_line = self.line_number
        # The last lines were not used - they are just the marker for the next
        # item.
        if key is not None:
            self._push_on_stack(key, value)
        if (None in p1) or (None in p2) or (None in p3):
            log.warn("DXFImporter: Incomplete 3DFACE definition between line %d and %d",
                     start_line, end_line)
        else:
            # no color height adjustment for 3DFACE
            point1 = tuple(p1)
            point2 = tuple(p2)
            point3 = tuple(p3)
            triangles = []
            triangles.append((point1, point2, point3))
            # DXF specifies, that p3=p4 if triangles (instead of quads) are
            # written.
            if (None not in p4) and (p3 != p4):
                point4 = (p4[0], p4[1], p4[2])
                triangles.append((point3, point4, point1))
            for t in triangles:
                if (t[0] != t[1]) and (t[0] != t[2]) and (t[1] != t[2]):
                    self.triangles.append(Triangle(t[0], t[1], t[2]))
                else:
                    log.warn("DXFImporter: Ignoring zero-sized 3DFACE (between input line %d and "
                             "%d): %s", start_line, end_line, t)

    def parse_line(self):
        start_line = self.line_number
        # the z-level defaults to zero (for 2D models)
        p1 = [None, None, 0]
        p2 = [None, None, 0]
        color = None
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["P1_X"]:
                p1[0] = value
            elif key == self.KEYS["P1_Y"]:
                p1[1] = value
            elif key == self.KEYS["P1_Z"]:
                p1[2] = value
            elif key == self.KEYS["P2_X"]:
                p2[0] = value
            elif key == self.KEYS["P2_Y"]:
                p2[1] = value
            elif key == self.KEYS["P2_Z"]:
                p2[2] = value
            elif key == self.KEYS["COLOR"]:
                color = value
            else:
                pass
            key, value = self._read_key_value()
        end_line = self.line_number
        # The last lines were not used - they are just the marker for the next
        # item.
        if key is not None:
            self._push_on_stack(key, value)
        if (None in p1) or (None in p2):
            log.warn("DXFImporter: Incomplete LINE definition between line %d and %d",
                     start_line, end_line)
        else:
            if self._color_as_height and (color is not None):
                # use the color code as the z coordinate
                p1[2] = float(color) / 255
                p2[2] = float(color) / 255
            line = Line((p1[0], p1[1], p1[2]), (p2[0], p2[1], p2[2]))
            if line.p1 != line.p2:
                self.lines.append(line)
            else:
                log.warn("DXFImporter: Ignoring zero-length LINE (between input line %d and %d): "
                         "%s", start_line, end_line, line)

    def parse_arc(self, circle=False):
        start_line = self.line_number
        # the z-level defaults to zero (for 2D models)
        center = [None, None, 0]
        color = None
        radius = None
        if circle:
            angle_start = 0
            angle_end = 360
        else:
            angle_start = None
            angle_end = None
        key, value = self._read_key_value()
        while (key is not None) and (key != self.KEYS["MARKER"]):
            if key == self.KEYS["P1_X"]:
                center[0] = value
            elif key == self.KEYS["P1_Y"]:
                center[1] = value
            elif key == self.KEYS["P1_Z"]:
                center[2] = value
            elif key == self.KEYS["RADIUS"]:
                radius = value
            elif key == self.KEYS["ANGLE_START"]:
                angle_start = value
            elif key == self.KEYS["ANGLE_END"]:
                angle_end = value
            elif key == self.KEYS["COLOR"]:
                color = value
            else:
                pass
            key, value = self._read_key_value()
        end_line = self.line_number
        # The last lines were not used - they are just the marker for the next item.
        if key is not None:
            self._push_on_stack(key, value)
        if (None in center) or (None in (radius, angle_start, angle_end)):
            log.warn("DXFImporter: Incomplete ARC definition between line %d and %d",
                     start_line, end_line)
        else:
            if self._color_as_height and (color is not None):
                # use the color code as the z coordinate
                center[2] = float(color) / 255
            center = tuple(center)
            xy_point_coords = get_points_of_arc(center, radius, angle_start, angle_end)
            # Somehow the order of points seems to be the opposite of what is
            # expected.
            xy_point_coords.reverse()
            if len(xy_point_coords) > 1:
                for index in range(len(xy_point_coords) - 1):
                    p1 = xy_point_coords[index]
                    p1 = (p1[0], p1[1], center[2])
                    p2 = xy_point_coords[index + 1]
                    p2 = (p2[0], p2[1], center[2])
                    if p1 != p2:
                        self.lines.append(Line(p1, p2))
            else:
                log.warn("DXFImporter: Ignoring tiny ARC (between input line %d and %d): %s / %s "
                         "(%s - %s)", start_line, end_line, center, radius, angle_start, angle_end)

    def check_header(self):
        # TODO: this function is not used?
        # we expect "0" in the first line and "SECTION" in the second one
        key, value = self._read_key_value()
        if (key != self.KEYS["MARKER"]) or (value and (value != "SECTION")):
            log.error("DXFImporter: DXF file header not recognized")
            return None


def import_model(filename, color_as_height=False, fonts_cache=None, callback=None, **kwargs):
    if hasattr(filename, "read"):
        should_close = False
        infile = filename
    else:
        should_close = True
        try:
            infile = pycam.Utils.URIHandler(filename).open()
        except IOError as exc:
            raise LoadFileError("DXFImporter: Failed to read file ({}): {}".format(filename, exc))

    result = DXFParser(infile, color_as_height=color_as_height, fonts_cache=fonts_cache,
                       callback=callback)
    if should_close:
        infile.close()

    model_data = result.get_model()
    lines = model_data["lines"]
    triangles = model_data["triangles"]

    if callback and callback():
        raise AbortOperationException("DXFImporter: load model operation was cancelled")

    # 3D models are preferred over 2D models
    if triangles:
        if lines:
            log.warn("DXFImporter: Ignoring 2D elements in DXF file: %d lines", len(lines))
        model = pycam.Geometry.Model.Model()
        for index, triangle in enumerate(triangles):
            model.append(triangle)
            # keep the GUI smooth
            if callback and (index % 50 == 0):
                callback()
        log.info("DXFImporter: Imported DXF model (3D): %d triangles",
                 len(model.triangles()))
        return model
    elif lines:
        model = pycam.Geometry.Model.ContourModel()
        for index, line in enumerate(lines):
            model.append(line)
            # keep the GUI smooth
            if callback and (index % 50 == 0):
                callback()
        # z scaling is always targeted at the 0..1 range
        if color_as_height and (model.minz != model.maxz):
            # scale z to 1
            scale_z = 1.0 / (model.maxz - model.minz)
            if callback:
                callback(text="Scaling height for multi-layered 2D model")
            log.info("DXFImporter: scaling height for multi-layered 2D model")
            model.scale(scale_x=1.0, scale_y=1.0, scale_z=scale_z, callback=callback)
        # shift the model down to z=0
        if model.minz != 0:
            if callback:
                callback(text="Shifting 2D model down to to z=0")
            model.shift(0, 0, -model.minz, callback=callback)
        log.info("DXFImporter: Imported DXF model (2D): %d lines / %d polygons",
                 len(lines), len(model.get_polygons()))
        return model
    else:
        link = "http://pycam.sourceforge.net/supported-formats"
        raise LoadFileError('DXFImporter: No supported elements found in DXF file!\n'
                            '<a href="%s">Read PyCAM\'s modeling hints.</a>'.format(link))
