"""
This module uses the openvoronoi library (https://github.com/aewallin/openvoronoi).
This module is experimental and not well tested.

How to enable this module:
    * download openvoronoi
    * build the library (e.g. openvoronoi.so)
    * copy/link/install this library to a directory used by python's module importer
    * the presence of this library makes the module below importable (see "import openvoronoi")
    * the function pycam.Toolpath.MotionGrid.get_pocketing_polygons automatically used openvoronoi
      if it is available
"""

import math

# this import requires the openvoronoi library (optional) - see the module documentation above
import openvoronoi

from pycam.Geometry import epsilon
import pycam.Geometry.Model
from pycam.Geometry.Line import Line
import pycam.Geometry.Polygon
from pycam.Geometry.utils import get_points_of_arc
import pycam.Utils.log

_log = pycam.Utils.log.get_logger()


# point_set is a list of 2D points: [ [x0,y0], [x1,y1], ... , [xN,yN] ]
# NOTE: all points in point_set must be unique! i.e. no duplicate points allowed
#
# line_set is a list of line-segments, given as index-pairs into the point_set list
# [ [start0,end0] , [start1,end1], ... , [startM,endM] ]
# NOTE: intersecting line-segments are not allowed.
#
# this defines line-segments   point_set[start0] - points_set[end0]  and so on...
#
# NOTE: currently openvoronoi only supports vertices of degree 2 or lower.
# i.e. a "star" geometry where three or more line-segments connect to a central vertex is forbidden
# SUPPORTED:     point_set = [p0,p1,p2,p3]    line_set = [[0,1], [1,2], [2,3], [3,0]]
# NOT SUPPORTED: point_set = [p0,p1,p2,p3]    line_set = [[0,1], [0,2], [0,3]]
#                (three line-segments connect to p0!)
def _add_connected_point_set_to_diagram(point_set, line_set, dia):
    # add all points to the diagram
    vpoints = []
    for p in point_set:
        ovp = openvoronoi.Point(*p[:2])
        vpoints.append(dia.addVertexSite(ovp))
    _log.info("all vertices added to openvoronoi!")
    # now add all line-segments
    for segment in line_set:
        start_idx = vpoints[segment[0]]
        end_idx = vpoints[segment[1]]
        dia.addLineSite(start_idx, end_idx)
    _log.info("all lines added to openvoronoi!")


def _polygons_to_line_set(polygons):
    # all points (unique!)
    point_set = []
    # all line-segments (indexes into the point_set array)
    line_set = []
    previous_point_index = 0
    point_count = 0
    for polygon_index, polygon in enumerate(polygons):
        _log.info("polygon #%d has %d vertices", polygon_index, len(polygon))
        first_point = True
        poly_pts = polygon.get_points()
        # if the polygon is closed, repeat the first point at the end
        if polygon.is_closed and poly_pts:
            poly_pts.append(poly_pts[0])
        for p in poly_pts:
            point_count += 1
            if p not in point_set:
                # this point is a new point we have not seen before
                point_set.append(p)
            current_point_index = point_set.index(p)
            # on the first iteration we have no line-segment
            if not first_point:
                _log.info(" line from %s to %s", previous_point_index, current_point_index)
                line_set.append((previous_point_index, current_point_index))
            else:
                first_point = False
            previous_point_index = current_point_index
    _log.info("point_count: %d", len(point_set))
    _log.info("point_set size: %d", len(point_set))
    _log.info("number of line-segments: %d", len(line_set))
    _log.info("Point set: %s", str(point_set))
    _log.info("Line set: %s", str(line_set))
    return point_set, line_set


def _offset_loops_to_polygons(offset_loops):
    model = pycam.Geometry.Model.ContourModel()
    before = None
    for n_loop, loop in enumerate(offset_loops):
        lines = []
        _log.info("loop #%d has %d lines/arcs", n_loop, len(loop))
        for n_segment, item in enumerate(loop):
            point, radius = item[:2]
            point = (point.x, point.y, 0.0)
            if before is not None:
                if radius == -1:
                    lines.append(Line(before, point))
                    _log.info("%d line %s to %s", n_segment, before, point)
                else:
                    _log.info("%d arc %s to %s r=%f", n_segment, before, point, radius)
                    center, clock_wise = item[2:]
                    center = (center.x, center.y, 0.0)
                    direction_before = (before[0] - center[0], before[1] - center[1], 0.0)
                    direction_end = (point[0] - center[0], point[1] - center[1], 0.0)
                    angles = [180.0 * pycam.Geometry.get_angle_pi((1.0, 0.0, 0.0), (0, 0.0, 0.0),
                                                                  direction, (0.0, 0.0, 1.0),
                                                                  pi_factor=True)
                              for direction in (direction_before, direction_end)]
                    if clock_wise:
                        angles.reverse()
                    points = get_points_of_arc(center, radius, angles[0], angles[1])
                    last_p = before
                    for p in points:
                        lines.append(Line(last_p, p))
                        last_p = p
            before = point
        for line in lines:
            if line.len > epsilon:
                model.append(line)
    return model.get_polygons()


def pocket_model(polygons, offset):
    _log.info("number of polygons: %d", len(polygons))
    _log.info("offset distance: %f", offset)
    maxx = max([poly.maxx for poly in polygons])
    maxy = max([poly.maxy for poly in polygons])
    minx = min([poly.minx for poly in polygons])
    miny = min([poly.miny for poly in polygons])
    radius = math.sqrt((maxx - minx) ** 2 + (maxy - miny) ** 2) / 1.8
    _log.info("Radius: %f", radius)
    bin_size = int(math.ceil(math.sqrt(sum([len(poly.get_points()) for poly in polygons]))))
    _log.info("bin_size: %f", bin_size)
    dia = openvoronoi.VoronoiDiagram(radius, bin_size)
    point_set, line_set = _polygons_to_line_set(polygons)
    _add_connected_point_set_to_diagram(point_set, line_set, dia)
    _log.info("diagram complete")
    _log.info("diagram check: %s", str(dia.check()))
    offset_dia = openvoronoi.Offset(dia.getGraph())
    _log.info("offset diagram created")
    offset_loops = offset_dia.offset(offset)
    _log.info("got %d loops from openvoronoi", len(offset_loops))
    return _offset_loops_to_polygons(offset_loops)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        import pycam.Importers.DXFImporter as importer
        model = importer.import_model(sys.argv[1])
    else:
        model = pycam.Geometry.Model.ContourModel()
        # convert some points to a 2D model
        points = ((0.0, 0.0, 0.0), (0.5, 0.0, 0.0), (0.5, 0.5, 0.0), (0.0, 0.0, 0.0))
        print("original points: ", points)
        before = None
        for p in points:
            if before:
                model.append(Line(before, p))
            before = p
    if len(sys.argv) > 2:
        offset = float(sys.argv[2])
    else:
        offset = 0.4
    # scale model within a range of -1..1
    maxdim = max(model.maxx - model.minx, model.maxy - model.miny)
    # stay well below sqrt(2)/2 in all directions
    scale_value = 1.4 / maxdim
    print("Scaling factor: %f" % scale_value)
    model.scale(scale_value)
    shift_x = - (model.minx + (model.maxx - model.minx) / 2.0)
    shift_y = - (model.miny + (model.maxy - model.miny) / 2.0)
    print("Shifting x: ", shift_x)
    print("Shifting y: ", shift_y)
    model.shift(shift_x, shift_y, 0.0)
    print("Model dimensions x: %f..%f" % (model.minx, model.maxx))
    print("Model dimensions y: %f..%f" % (model.miny, model.maxy))

    pocket_model(model.get_polygons(), offset)
