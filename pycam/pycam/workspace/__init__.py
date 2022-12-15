from enum import Enum


class CollectionName(Enum):
    MODELS = "models"
    TOOLS = "tools"
    PROCESSES = "processes"
    BOUNDS = "bounds"
    TASKS = "tasks"
    TOOLPATHS = "toolpaths"
    EXPORT_SETTINGS = "export_settings"
    EXPORTS = "exports"


class ToolShape(Enum):
    FLAT_BOTTOM = "flat_bottom"
    BALL_NOSE = "ball_nose"
    TORUS = "torus"


class ProcessStrategy(Enum):
    SLICE = "slice"
    CONTOUR = "contour"
    SURFACE = "surface"
    ENGRAVE = "engrave"


class PathPattern(Enum):
    SPIRAL = "spiral"
    GRID = "grid"


class BoundsSpecification(Enum):
    ABSOLUTE = "absolute"
    MARGINS = "margins"


class TaskType(Enum):
    MILLING = "milling"


class SourceType(Enum):
    FILE = "file"
    URL = "url"
    COPY = "copy"
    MODEL = "model"
    TASK = "task"
    TOOLPATH = "toolpath"
    OBJECT = "object"
    SUPPORT_BRIDGES = "support_bridges"


class ModelTransformationAction(Enum):
    SCALE = "scale"
    SHIFT = "shift"
    ROTATE = "rotate"
    MULTIPLY_MATRIX = "multiply_matrix"
    PROJECTION = "projection"
    TOGGLE_POLYGON_DIRECTIONS = "toggle_polygon_directions"
    REVISE_POLYGON_DIRECTIONS = "revise_polygon_directions"


class ToolpathTransformationAction(Enum):
    CROP = "crop"
    CLONE = "clone"
    SHIFT = "shift"


class ModelScaleTarget(Enum):
    FACTOR = "factor"
    SIZE = "size"


class PositionShiftTarget(Enum):
    DISTANCE = "distance"
    ALIGN_MIN = "align_min"
    ALIGN_MAX = "align_max"
    CENTER = "center"

    @classmethod
    def _get_shift_offset(cls, shift_target, shift_axes, obj):
        offset = []
        if shift_target == cls.DISTANCE:
            for value in shift_axes:
                offset.append(0.0 if value is None else value)
        elif shift_target == cls.ALIGN_MIN:
            for value, current_position in zip(shift_axes, (obj.minx, obj.miny, obj.minz)):
                offset.append(0.0 if value is None else (value - current_position))
        elif shift_target == cls.ALIGN_MAX:
            for value, current_position in zip(shift_axes, (obj.maxx, obj.maxy, obj.maxz)):
                offset.append(0.0 if value is None else (value - current_position))
        elif shift_target == cls.CENTER:
            for value, current_position in zip(shift_axes, obj.get_center()):
                offset.append(0.0 if value is None else (value - current_position))
        else:
            assert False
        return offset


class SupportBridgesLayout(Enum):
    GRID = "grid"
    DISTRIBUTED = "distributed"


class DistributionStrategy(Enum):
    CORNERS = "corners"
    EVENLY = "evenly"


class TargetType(Enum):
    FILE = "file"


class FormatType(Enum):
    GCODE = "gcode"
    MODEL = "model"


class FileType(Enum):
    STL = "stl"


class GCodeDialect(Enum):
    LINUXCNC = "linuxcnc"


class ToolpathFilter(Enum):
    SAFETY_HEIGHT = "safety_height"
    PLUNGE_FEEDRATE = "plunge_feedrate"
    STEP_WIDTH = "step_width"
    CORNER_STYLE = "corner_style"
    FILENAME_EXTENSION = "filename_extension"
    TOUCH_OFF = "touch_off"
    UNIT = "unit"


class ToolBoundaryMode(Enum):
    INSIDE = "inside"
    ALONG = "along"
    AROUND = "around"


class ModelType(Enum):
    TRIMESH = "trimesh"
    POLYGON = "polygon"


class LengthUnit(Enum):
    METRIC_MM = "metric_mm"
    IMPERIAL_INCH = "imperial_inch"
