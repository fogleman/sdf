"""
Copyright 2009 Lode Leroy

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

# Inkscape uses a fixed resolution of 90 dpi
SVG_OUTPUT_DPI = 90


class SVGExporter:

    def __init__(self, output, unit="mm", maxx=None, maxy=None):
        if hasattr(output, "write"):
            # a stream was given
            self.output = output
        else:
            # a filename was given
            self.output = open(output, "w")
        if unit == "mm":
            dots_per_px = SVG_OUTPUT_DPI / 25.4
        else:
            dots_per_px = SVG_OUTPUT_DPI
        if maxx is None:
            width = 640
        else:
            width = dots_per_px * maxx
            if width <= 0:
                width = 640
        if maxy is None:
            height = 800
        else:
            height = dots_per_px * maxy
            if height <= 0:
                height = 800
        self.output.write(("<?xml version='1.0'?>\n"
                           "<svg xmlns='http://www.w3.org/2000/svg' width='%f' height='%f'>\n"
                           "<g transform='translate(0,%f) scale(%.10f)' stroke-width='0.05' "
                           "font-size='0.2'>\n") % (width, height, height, dots_per_px))
        self._fill = 'none'
        self._stroke = 'black'

    def close(self, close_stream=True):
        self.output.write("""</g>\n</svg>\n""")
        if close_stream:
            self.output.close()

    def stroke(self, stroke):
        self._stroke = stroke

    def fill(self, fill):
        self._fill = fill

    def add_dot(self, x, y):
        item = "<circle fill='%s' cx='%g' cy='%g' r='0.04'/>\n" % (self._fill, x, -y)
        self.output.write(item)

    def add_text(self, x, y, text):
        item = "<text fill='%s' x='%g' y='%g' dx='0.07'>%s</text>\n" % (self._fill, x, -y, text)
        self.output.write(item)

    def add_line(self, x1, y1, x2, y2):
        item = ("<line fill='%s' stroke='%s' x1='%.8f' y1='%.8f' x2='%.8f' y2='%.8f' />\n"
                % (self._fill, self._stroke, x1, -y1, x2, -y2))
        self.output.write(item)

    def add_lines(self, points):
        item = "<path fill='%s' stroke='%s' d='" % (self._fill, self._stroke)
        for i, p in enumerate(points):
            if i == 0:
                item += "M "
            else:
                item += " L "
            item += "%.8f %.8f" % (p[0], -p[1])
        item += "'/>\n"
        self.output.write(item)


# TODO: we need to create a unified "Exporter" interface and base class
class SVGExporterContourModel:

    def __init__(self, model, unit="mm", **kwargs):
        self.model = model
        self.unit = unit

    def write(self, stream):
        writer = SVGExporter(stream, unit=self.unit, maxx=self.model.maxx, maxy=self.model.maxy)
        for polygon in self.model.get_polygons():
            points = polygon.get_points()
            if polygon.is_closed:
                points.append(points[0])
            writer.add_lines(points)
        writer.close(close_stream=False)
