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

import math

from pycam.Geometry import number, sqrt
from pycam.Geometry.PointUtils import pcross, pmul, pnormalized
import pycam.Geometry.Matrix as Matrix
import pycam.Plugins


# The length of the distance vector does not matter - it will be normalized and
# multiplied later anyway.
VIEWS = {
    "reset": {"distance": (-1.0, -1.0, 1.0), "center": (0.0, 0.0, 0.0),
              "up": (0.0, 0.0, 1.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
    "top": {"distance": (0.0, 0.0, 1.0), "center": (0.0, 0.0, 0.0),
            "up": (0.0, 1.0, 0.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
    "bottom": {"distance": (0.0, 0.0, -1.0), "center": (0.0, 0.0, 0.0),
               "up": (0.0, 1.0, 0.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
    "left": {"distance": (-1.0, 0.0, 0.0), "center": (0.0, 0.0, 0.0),
             "up": (0.0, 0.0, 1.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
    "right": {"distance": (1.0, 0.0, 0.0), "center": (0.0, 0.0, 0.0),
              "up": (0.0, 0.0, 1.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
    "front": {"distance": (0.0, -1.0, 0.0), "center": (0.0, 0.0, 0.0),
              "up": (0.0, 0.0, 1.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
    "back": {"distance": (0.0, 1.0, 0.0), "center": (0.0, 0.0, 0.0),
             "up": (0.0, 0.0, 1.0), "znear": 0.01, "zfar": 10000.0, "fovy": 30.0},
}


class OpenGLWindow(pycam.Plugins.PluginBase):

    UI_FILE = "opengl.ui"
    CATEGORIES = ["Visualization", "OpenGL"]

    def setup(self):
        if not self._GL:
            self.log.error("Failed to initialize the interactive 3D model view.\nPlease verify "
                           "that all requirements (especially the Python package for 'OpenGL' - "
                           "e.g. 'python3-opengl') are installed.")
            return False
        # test support for GLArea (since GTK v3.16)
        try:
            self._gtk.GLArea
        except AttributeError:
            self.log.error("Failed to initialize the interactive 3D model view probably due to an "
                           "outdated version of GTK (required: v3.16).")
            return False
        if self.gui:
            # buttons for rotating, moving and zooming the model view window
            self.BUTTON_ROTATE = self._gdk.ModifierType.BUTTON1_MASK
            self.BUTTON_MOVE = self._gdk.ModifierType.BUTTON2_MASK
            self.BUTTON_ZOOM = self._gdk.ModifierType.BUTTON3_MASK
            self.BUTTON_RIGHT = 3
            self.context_menu = self._gtk.Menu()
            self.window = self.gui.get_object("OpenGLWindow")
            self.window.insert_action_group(self.core.get("gtk_action_group_prefix"),
                                            self.core.get("gtk_action_group"))
            drag_n_drop_func = self.core.get("configure-drag-drop-func")
            if drag_n_drop_func:
                drag_n_drop_func(self.window)
            self.initialized = False
            self.is_visible = False
            self._last_view = VIEWS["reset"]
            self._position = [200, 200]
            box = self.gui.get_object("OpenGLPrefTab")
            self.core.register_ui("preferences", "OpenGL", box, 40)
            self._gtk_handlers = []
            # options
            # TODO: move the default value somewhere else
            for name, objname, default in (("view_light", "OpenGLLight", True),
                                           ("view_shadow", "OpenGLShadow", True),
                                           ("view_polygon", "OpenGLPolygon", True),
                                           ("view_perspective", "OpenGLPerspective", True),
                                           ("opengl_cache_enable", "OpenGLCache", True)):
                obj = self.gui.get_object(objname)
                self.core.add_item(name, obj.get_active, obj.set_active)
                obj.set_active(default)
                self._gtk_handlers.append((obj, "toggled", self.glsetup))
                self._gtk_handlers.append((obj, "toggled", "visual-item-updated"))
            # frames per second
            skip_obj = self.gui.get_object("DrillProgressFrameSkipControl")
            self.core.add_item("tool_progress_max_fps", skip_obj.get_value, skip_obj.set_value)
            # info bar above the model view
            detail_box = self.gui.get_object("InfoBox")

            def clear_window():
                for child in detail_box.get_children():
                    detail_box.remove(child)

            def add_widget_to_window(item, name):
                if len(detail_box.get_children()) > 0:
                    sep = self._gtk.HSeparator()
                    detail_box.pack_start(sep, fill=True, expand=True, padding=0)
                    sep.show()
                detail_box.pack_start(item, fill=True, expand=True, padding=0)
                item.show()

            self.core.register_ui_section("opengl_window", add_widget_to_window, clear_window)
            self.core.register_ui("opengl_window", "Views", self.gui.get_object("ViewControls"),
                                  weight=0)
            # color box
            color_frame = self.gui.get_object("ColorPrefTab")
            color_frame.unparent()
            self._color_settings = {}
            self.core.register_ui("preferences", "Colors", color_frame, 30)
            self.core.set("register_color", self.register_color_setting)
            self.core.set("unregister_color", self.unregister_color_setting)
            # TODO: move "material" to simulation viewer
            for name, label, weight in (("color_background", "Background", 10),
                                        ("color_material", "Material", 80)):
                self.core.get("register_color")(name, label, weight)
            # display items
            items_frame = self.gui.get_object("DisplayItemsPrefTab")
            items_frame.unparent()
            self._display_items = {}
            self.core.register_ui("preferences", "Display Items", items_frame, 20)
            self.core.set("register_display_item", self.register_display_item)
            self.core.set("unregister_display_item", self.unregister_display_item)
            # visual and general settings
            # TODO: should directions be here?
            self.core.get("register_display_item")("show_directions", "Show Directions", 80)
            # toggle window state
            toggle_3d = self.gui.get_object("Toggle3DView")
            self._gtk_handlers.append((toggle_3d, "toggled", self.toggle_3d_view))
            self.register_gtk_accelerator("opengl", toggle_3d, "<Control><Shift>v",
                                          "ToggleOpenGLView")
            self.core.register_ui("view_menu", "ViewOpenGL", toggle_3d, -20)
            self.mouse = {"start_pos": None, "button": None, "event_timestamp": 0,
                          "last_timestamp": 0, "pressed_pos": None, "pressed_timestamp": 0,
                          "pressed_button": None}
            self.window.connect("delete-event", self.destroy)
            self.window.set_default_size(560, 400)
            for obj_name, view in (("ResetView", "reset"),
                                   ("LeftView", "left"),
                                   ("RightView", "right"),
                                   ("FrontView", "front"),
                                   ("BackView", "back"),
                                   ("TopView", "top"),
                                   ("BottomView", "bottom")):
                self._gtk_handlers.append((self.gui.get_object(obj_name), "clicked",
                                           self.rotate_view, VIEWS[view]))
            # key binding
            self._gtk_handlers.append((self.window, "key-press-event", self.key_handler))
            # OpenGL stuff
            self.area = self._gtk.GLArea(auto_render=False, has_alpha=True, has_depth_buffer=True)
            self.area.show()
            # first run; might also be important when doing other fancy
            # called when a part of the screen is uncovered
            self._gtk_handlers.append((self.area, 'render', self.paint))
            # resize window
            self._gtk_handlers.append((self.area, "resize", self._resize_window))
            # catch mouse events
            self.area.set_events((self._gdk.InputSource.MOUSE
                                  | self._gdk.EventMask.POINTER_MOTION_MASK
                                  | self._gdk.EventMask.BUTTON_PRESS_MASK
                                  | self._gdk.EventMask.BUTTON_RELEASE_MASK
                                  | self._gdk.EventMask.SCROLL_MASK))
            self._gtk_handlers.extend((
                (self.area, "button-press-event", self.mouse_press_handler),
                (self.area, "motion-notify-event", self.mouse_handler),
                (self.area, "button-release-event", self.context_menu_handler),
                (self.area, "scroll-event", self.scroll_handler)))
            self.gui.get_object("OpenGLBox").pack_end(self.area, fill=True, expand=True, padding=0)

            def get_area_allocation(self=self):
                allocation = self.area.get_allocation()
                return allocation.width, allocation.height

            self.camera = Camera(self.core, get_area_allocation, self._GL, self._GLU)
            self._event_handlers = (("visual-item-updated", self.update_view),
                                    ("visualization-state-changed", self._update_widgets),
                                    ("model-list-changed", self._restore_latest_view))
            # handlers
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
            # show the window - the handlers _must_ be registered before "show"
            self.area.show()
            toggle_3d.set_active(True)
            # refresh display
            self.core.emit_event("visual-item-updated")

            def get_get_set_functions(name):
                get_func = lambda: self.core.get(name)
                set_func = lambda value: self.core.set(name, value)
                return get_func, set_func

            for name in ("view_light", "view_shadow", "view_polygon", "view_perspective",
                         "opengl_cache_enable", "tool_progress_max_fps"):
                self.register_state_item("settings/view/opengl/%s" % name,
                                         *get_get_set_functions(name))
        return True

    def teardown(self):
        if self.gui:
            self.core.unregister_ui("preferences", self.gui.get_object("OpenGLPrefTab"))
            toggle_3d = self.gui.get_object("Toggle3DView")
            # hide the window
            toggle_3d.set_active(False)
            self.core.unregister_ui("view_menu", toggle_3d)
            self.unregister_gtk_accelerator("opengl", toggle_3d)
            for name in ("color_background", "color_tool", "color_material"):
                self.core.get("unregister_color")(name)
            for name in ("show_tool", "show_directions"):
                self.core.get("unregister_display_item")(name)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.unregister_event_handlers(self._event_handlers)
            # the area will be created during setup again
            self.gui.get_object("OpenGLBox").remove(self.area)
            self.area = None
            self.core.unregister_ui("preferences", self.gui.get_object("DisplayItemsPrefTab"))
            self.core.unregister_ui("preferences", self.gui.get_object("OpenGLPrefTab"))
            self.core.unregister_ui("opengl_window", self.gui.get_object("ViewControls"))
            self.core.unregister_ui("preferences", self.gui.get_object("ColorPrefTab"))
            self.core.unregister_ui_section("opengl_window")
        self.clear_state_items()

    def update_view(self, widget=None, data=None):
        if self.is_visible:
            self.trigger_rendering()

    def _update_widgets(self):
        self.unregister_gtk_handlers(self._gtk_handlers)
        self.gui.get_object("Toggle3DView").set_active(self.is_visible)
        self.register_gtk_handlers(self._gtk_handlers)

    def register_display_item(self, name, label, weight=100):
        if name in self._display_items:
            self.log.debug("Tried to register display item '%s' twice", name)
            return
        # create an action and three derived items:
        #  - a checkbox for the preferences window
        #  - a tool item for the drop-down list in the 3D window
        #  - a menu item for the context menu in the 3D window
        # the string value will be interpreted by the callback as the most recently updated widget
        action_name = ".".join((self.core.get("gtk_action_group_prefix"), name))
        action = self._gio.SimpleAction.new_stateful(name, self._glib.VariantType.new("s"),
                                                     self._glib.Variant.new_string("0"))
        widgets = []
        for index, item in enumerate((self._gtk.CheckButton(),
                                      self._gtk.ToggleToolButton(),
                                      self._gtk.CheckMenuItem())):
            item.insert_action_group(self.core.get("gtk_action_group_prefix"),
                                     self.core.get("gtk_action_group"))
            item.set_label(label)
            item.set_action_target_value(self._glib.Variant.new_string(str(index)))
            item.set_action_name(action_name)
            # The "target value" (the stringified widget index) is used by GTK for guessing the
            # sensitivity of a control.  This approach differs from ours - we ignore it.
            item.set_sensitive(True)
            widgets.append(item)
        self._display_items[name] = {"name": name, "label": label, "weight": weight,
                                     "widgets": widgets, "action": action}

        def synchronize_widgets(action, widget_index_variant, widgets=widgets, is_blocked=[],
                                name=name):
            """ copy the state of the most recently changed ("activated") control to the others

            widget_index_variant: GLib.Variant containing the stringified index of the changed
                widget (0, 1 or 2) - based on the widgets list
            widgets: the three associated widgets
            is_blocked: we need to avoid pseudo-recursive calls of this function after every
                programmatic change of a control
            """
            widget_index = int(widget_index_variant.get_string())
            if not is_blocked:
                is_blocked.append(True)
                current_widget = widgets[widget_index]
                current_value = current_widget.get_active()
                for index, widget in enumerate(widgets):
                    if widget_index != index:
                        if hasattr(widget, "set_active"):
                            widget.set_active(current_value)
                        else:
                            widget.set_state(current_value)
                    widget.set_sensitive(True)
                self.core.set(name, current_value)
                self.core.emit_event("visual-item-updated")
                is_blocked.clear()

        action.connect("activate", synchronize_widgets)
        self.core.get("gtk_action_group").add_action(action)
        self.core.add_item(name, set_func=widgets[0].set_active)
        # add this item to the state handler
        self.register_state_item("settings/view/items/%s" % name,
                                 widgets[0].get_active, widgets[0].set_active)
        # synchronize the widgets
        synchronize_widgets(None, self._glib.Variant.new_string("0"))
        self._rebuild_display_items()

    def unregister_display_item(self, name):
        if name not in self._display_items:
            self.log.info("Failed to unregister unknown display item: %s", name)
            return
        first_widget = self._display_items[name]["widgets"][0]
        self.unregister_state_item("settings/view/items/%s" % name,
                                   first_widget.get_active, first_widget.set_active)
        action_name = ".".join((self.core.get("gtk_action_group_prefix"), name))
        self.core.get("gtk_action_group").remove(action_name)
        del self._display_items[name]
        self._rebuild_display_items()

    def _rebuild_display_items(self):
        pref_box = self.gui.get_object("PreferencesVisibleItemsBox")
        toolbar = self.gui.get_object("ViewItems")
        for parent in pref_box, self.context_menu, toolbar:
            for child in parent.get_children():
                parent.remove(child)
        items = list(self._display_items.values())
        items.sort(key=lambda item: item["weight"])
        for item in items:
            pref_box.pack_start(item["widgets"][0], expand=True, fill=True, padding=0)
            toolbar.add(item["widgets"][1])
            self.context_menu.add(item["widgets"][2])
        for parent in (pref_box, toolbar, self.context_menu):
            parent.show_all()
            parent.insert_action_group(self.core.get("gtk_action_group_prefix"),
                                       self.core.get("gtk_action_group"))

    def register_color_setting(self, name, label, weight=100):
        if name in self._color_settings:
            self.log.debug("Tried to register color '%s' twice", name)
            return

        def get_color_wrapper(obj):
            def gtk_color_to_dict():
                color_components = obj.get_rgba()
                return {"red": color_components.red,
                        "green": color_components.green,
                        "blue": color_components.blue,
                        "alpha": color_components.alpha}
            return gtk_color_to_dict

        def set_color_wrapper(obj):
            def set_gtk_color_by_dict(color):
                obj.set_rgba(
                    self._gdk.RGBA(color["red"], color["green"], color["blue"], color["alpha"]))
            return set_gtk_color_by_dict

        widget = self._gtk.ColorButton()
        widget.set_use_alpha(True)
        wrappers = (get_color_wrapper(widget), set_color_wrapper(widget))
        self._color_settings[name] = {"name": name, "label": label, "weight": weight,
                                      "widget": widget, "wrappers": wrappers}
        widget.connect("color-set", lambda widget: self.core.emit_event("visual-item-updated"))
        self.core.add_item(name, *wrappers)
        self.register_state_item("settings/view/colors/%s" % name, *wrappers)
        self._rebuild_color_settings()

    def unregister_color_setting(self, name):
        if name not in self._color_settings:
            self.log.debug("Failed to unregister unknown color item: %s", name)
            return
        wrappers = self._color_settings[name]["wrappers"]
        self.unregister_state_item("settings/view/colors/%s" % name, *wrappers)
        del self._color_settings[name]
        self._rebuild_color_settings()

    def _rebuild_color_settings(self):
        color_table = self.gui.get_object("ColorTable")
        for child in color_table.get_children():
            color_table.remove(child)
        items = list(self._color_settings.values())
        items.sort(key=lambda item: item["weight"])
        for index, item in enumerate(items):
            label = self._gtk.Label("%s:" % item["label"])
            label.set_alignment(0.0, 0.5)
            color_table.attach(label, 0, index, 1, 1)
            color_table.attach(item["widget"], 1, index, 1, 1)
        color_table.show_all()

    def toggle_3d_view(self, widget=None, value=None):
        current_state = self.is_visible
        if value is None:
            new_state = not current_state
        else:
            new_state = value
        if new_state == current_state:
            return
        elif new_state:
            if self.is_visible:
                self.reset_view()
            else:
                # the window is just hidden
                self.show()
        else:
            self.hide()

    def show(self):
        self.is_visible = True
        self.window.move(*self._position)
        self.window.show()

    def hide(self):
        self.is_visible = False
        self._position = self.window.get_position()
        self.window.hide()

    def key_handler(self, widget=None, event=None):
        if event is None:
            return
        try:
            keyval = getattr(event, "keyval")
            get_state = getattr(event, "get_state")
            key_string = getattr(event, "string")
        except AttributeError:
            return
        # define arrow keys and "vi"-like navigation keys
        move_keys_dict = {
            self._gdk.KEY_Left: (1, 0),
            self._gdk.KEY_Down: (0, -1),
            self._gdk.KEY_Up: (0, 1),
            self._gdk.KEY_Right: (-1, 0),
            ord("h"): (1, 0),
            ord("j"): (0, -1),
            ord("k"): (0, 1),
            ord("l"): (-1, 0),
            ord("H"): (1, 0),
            ord("J"): (0, -1),
            ord("K"): (0, 1),
            ord("L"): (-1, 0),
        }
        if key_string and (key_string in '1234567'):
            self._last_view = None
            names = ["reset", "front", "back", "left", "right", "top", "bottom"]
            index = '1234567'.index(key_string)
            self.rotate_view(view=VIEWS[names[index]])
            self.trigger_rendering()
        elif key_string in ('i', 'm', 's', 'p'):
            if key_string == 'i':
                key = "view_light"
            elif key_string == 'm':
                key = "view_polygon"
            elif key_string == 's':
                key = "view_shadow"
            elif key_string == 'p':
                key = "view_perspective"
            else:
                key = None
            # toggle setting
            self.core.set(key, not self.core.get(key))
            # re-init gl settings
            self.glsetup()
            self.trigger_rendering()
        elif key_string in ("+", "-"):
            self._last_view = None
            if key_string == "+":
                self.camera.zoom_in()
            else:
                self.camera.zoom_out()
            self.trigger_rendering()
        elif keyval in move_keys_dict.keys():
            self._last_view = None
            move_x, move_y = move_keys_dict[keyval]
            if get_state() & self._gdk.ModifierType.SHIFT_MASK:
                # shift key pressed -> rotation
                base = 0
                factor = 10
                self.camera.rotate_camera_by_screen(base, base, base - factor * move_x,
                                                    base - factor * move_y)
            else:
                # no shift key -> moving
                self.camera.shift_view(x_dist=move_x, y_dist=move_y)
            self.trigger_rendering()
        else:
            self.log.debug("Unhandled key pressed: %s (%s)", keyval, get_state())

    def glsetup(self, widget=None):
        GL = self._GL
        GLUT = self._GLUT
        if not GLUT.glutInit:
            self.log.error("Failed to execute 'GLUT.glutInit': probably you need to install the"
                           "C library providing GLUT functions (e.g. 'freeglut3-dev' or "
                           "'freeglut-devel'). OpenGL visualization is disabled.")
            return
        GLUT.glutInit()
        GLUT.glutInitDisplayMode(GLUT.GLUT_RGBA | GLUT.GLUT_DOUBLE | GLUT.GLUT_DEPTH
                                 | GLUT.GLUT_MULTISAMPLE | GLUT.GLUT_ALPHA | GLUT.GLUT_ACCUM)
        if self.core.get("view_shadow"):
            # TODO: implement shadowing (or remove the setting)
            pass
        # use vertex normals for smooth rendering
        GL.glShadeModel(GL.GL_SMOOTH)
        bg_col = self.core.get("color_background")
        GL.glClearColor(bg_col["red"], bg_col["green"], bg_col["blue"], 1.0)
        GL.glHint(GL.GL_PERSPECTIVE_CORRECTION_HINT, GL.GL_NICEST)
        GL.glMatrixMode(GL.GL_MODELVIEW)
        # enable blending/transparency (alpha) for colors
        GL.glEnable(GL.GL_BLEND)
        # see http://wiki.delphigl.com/index.php/glBlendFunc
        GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA)
        GL.glEnable(GL.GL_DEPTH_TEST)
        # "less" is OpenGL's default
        GL.glDepthFunc(GL.GL_LESS)
        # slightly improved performance: ignore all faces inside the objects
        GL.glCullFace(GL.GL_BACK)
        GL.glEnable(GL.GL_CULL_FACE)
        # enable antialiasing
        GL.glEnable(GL.GL_LINE_SMOOTH)
#       GL.glEnable(GL.GL_POLYGON_SMOOTH)
        GL.glHint(GL.GL_LINE_SMOOTH_HINT, GL.GL_NICEST)
        GL.glHint(GL.GL_POLYGON_SMOOTH_HINT, GL.GL_NICEST)
        # TODO: move to toolpath drawing
        GL.glLineWidth(0.8)
#       GL.glEnable(GL.GL_MULTISAMPLE_ARB)
        GL.glEnable(GL.GL_POLYGON_OFFSET_FILL)
        GL.glPolygonOffset(1.0, 1.0)
        # ambient and diffuse material lighting is defined in OpenGLViewModel
        GL.glMaterial(GL.GL_FRONT_AND_BACK, GL.GL_SPECULAR, (1.0, 1.0, 1.0, 1.0))
        GL.glMaterial(GL.GL_FRONT_AND_BACK, GL.GL_SHININESS, (100.0))
        if self.core.get("view_polygon"):
            GL.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_FILL)
        else:
            GL.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_LINE)
        GL.glMatrixMode(GL.GL_MODELVIEW)
        GL.glLoadIdentity()
        GL.glMatrixMode(GL.GL_PROJECTION)
        GL.glLoadIdentity()
        GL.glViewport(0, 0, self.area.get_allocation().width, self.area.get_allocation().height)
        # lighting
        GL.glLightModeli(GL.GL_LIGHT_MODEL_LOCAL_VIEWER, GL.GL_TRUE)
        # Light #1
        # setup the ambient light
        GL.glLightfv(GL.GL_LIGHT0, GL.GL_AMBIENT, (0.3, 0.3, 0.3, 1.0))
        # setup the diffuse light
        GL.glLightfv(GL.GL_LIGHT0, GL.GL_DIFFUSE, (0.8, 0.8, 0.8, 1.0))
        # setup the specular light
        GL.glLightfv(GL.GL_LIGHT0, GL.GL_SPECULAR, (0.1, 0.1, 0.1, 1.0))
        # enable Light #1
        GL.glEnable(GL.GL_LIGHT0)
        # Light #2
        # spotlight with small light cone (like a desk lamp)
#       GL.glLightfv(GL.GL_LIGHT1, GL.GL_SPOT_CUTOFF, 10.0)
        # ... directed at the object
        v = self.camera.view
        GL.glLightfv(GL.GL_LIGHT1, GL.GL_SPOT_DIRECTION,
                     (v["center"][0], v["center"][1], v["center"][2]))
        GL.glLightfv(GL.GL_LIGHT1, GL.GL_AMBIENT, (0.3, 0.3, 0.3, 1.0))
        # and dark outside of the light cone
#       GL.glLightfv(GL.GL_LIGHT1, GL.GL_SPOT_EXPONENT, 100.0)
#       GL.glLightf(GL.GL_LIGHT1, GL.GL_QUADRATIC_ATTENUATION, 0.5)
        # setup the diffuse light
        GL.glLightfv(GL.GL_LIGHT1, GL.GL_DIFFUSE, (0.9, 0.9, 0.9, 1.0))
        # setup the specular light
        GL.glLightfv(GL.GL_LIGHT1, GL.GL_SPECULAR, (1.0, 1.0, 1.0, 1.0))
        # enable Light #2
        GL.glEnable(GL.GL_LIGHT1)
        if self.core.get("view_light"):
            GL.glEnable(GL.GL_LIGHTING)
        else:
            GL.glDisable(GL.GL_LIGHTING)
        GL.glEnable(GL.GL_NORMALIZE)
        GL.glColorMaterial(GL.GL_FRONT_AND_BACK, GL.GL_AMBIENT_AND_DIFFUSE)
        GL.glColorMaterial(GL.GL_FRONT_AND_BACK, GL.GL_SPECULAR)
#       GL.glColorMaterial(GL.GL_FRONT_AND_BACK, GL.GL_EMISSION)
        GL.glEnable(GL.GL_COLOR_MATERIAL)

    def destroy(self, widget=None, data=None):
        self.hide()
        self.core.emit_event("visualization-state-changed")
        # don't close the window
        return True

    def _restore_latest_view(self):
        """ this function is called whenever the model list changes

        The function will restore the latest selected view - including
        automatic distance adjustment. The latest view is always reset to
        None, if any manual change (e.g. panning via mouse or keyboard)
        occurred.
        """
        if self._last_view:
            self.rotate_view(view=self._last_view)

    def context_menu_handler(self, widget, event):
        if ((event.button == self.mouse["pressed_button"] == self.BUTTON_RIGHT)
                and self.context_menu
                and (event.get_time() - self.mouse["pressed_timestamp"] < 300)
                and (abs(event.x - self.mouse["pressed_pos"][0]) < 3)
                and (abs(event.y - self.mouse["pressed_pos"][1]) < 3)):
            # A quick press/release cycle with the right mouse button
            # -> open the context menu.
            self.context_menu.popup(None, None, None, None, event.button, int(event.get_time()))

    def scroll_handler(self, widget, event):
        """ handle events of the scroll wheel

        shift key: horizontal pan instead of vertical
        control key: zoom
        """
        remember_last_view = self._last_view
        self._last_view = None
        try:
            modifier_state = event.get_state()
        except AttributeError:
            # this should probably never happen
            return
        control_pressed = modifier_state & self._gdk.ModifierType.CONTROL_MASK
        shift_pressed = modifier_state & self._gdk.ModifierType.SHIFT_MASK
        if ((event.direction == self._gdk.ScrollDirection.RIGHT)
                or ((event.direction == self._gdk.ScrollDirection.UP) and shift_pressed)):
            # horizontal move right
            self.camera.shift_view(x_dist=-1)
        elif ((event.direction == self._gdk.ScrollDirection.LEFT)
                or ((event.direction == self._gdk.ScrollDirection.DOWN) and shift_pressed)):
            # horizontal move left
            self.camera.shift_view(x_dist=1)
        elif (event.direction == self._gdk.ScrollDirection.UP) and control_pressed:
            # zoom in
            self.camera.zoom_in()
        elif event.direction == self._gdk.ScrollDirection.UP:
            # vertical move up
            self.camera.shift_view(y_dist=1)
        elif (event.direction == self._gdk.ScrollDirection.DOWN) and control_pressed:
            # zoom out
            self.camera.zoom_out()
        elif event.direction == self._gdk.ScrollDirection.DOWN:
            # vertical move down
            self.camera.shift_view(y_dist=-1)
        else:
            # no interesting event -> no re-painting
            self._last_view = remember_last_view
            return
        self.trigger_rendering()

    def mouse_press_handler(self, widget, event):
        self.mouse["pressed_timestamp"] = event.get_time()
        self.mouse["pressed_button"] = event.button
        self.mouse["pressed_pos"] = event.x, event.y
        self.mouse_handler(widget, event)

    def mouse_handler(self, widget, event):
        x, y, state = event.x, event.y, event.state
        if self.mouse["button"] is None:
            if ((state & self.BUTTON_ZOOM)
                    or (state & self.BUTTON_ROTATE)
                    or (state & self.BUTTON_MOVE)):
                self.mouse["button"] = state
                self.mouse["start_pos"] = [x, y]
        else:
            # Don't try to create more than 25 frames per second (enough for
            # a decent visualization).
            if event.get_time() - self.mouse["event_timestamp"] < 40:
                return
            elif state & self.mouse["button"] & self.BUTTON_ZOOM:
                self._last_view = None
                # the start button is still active: update the view
                start_x, start_y = self.mouse["start_pos"]
                self.mouse["start_pos"] = [x, y]
                # Move the mouse from lower left to top right corner for
                # scaling up.
                scale = 1 - 0.01 * ((x - start_x) + (start_y - y))
                # do some sanity checks, scale no more than
                # 1:100 on any given click+drag
                if scale < 0.01:
                    scale = 0.01
                elif scale > 100:
                    scale = 100
                self.camera.scale_distance(scale)
                self.trigger_rendering()
            elif ((state & self.mouse["button"] & self.BUTTON_MOVE)
                    or (state & self.mouse["button"] & self.BUTTON_ROTATE)):
                self._last_view = None
                start_x, start_y = self.mouse["start_pos"]
                self.mouse["start_pos"] = [x, y]
                if (state & self.BUTTON_MOVE):
                    # Determine the biggest dimension (x/y/z) for moving the
                    # screen's center in relation to this value.
                    low, high = [None, None, None], [None, None, None]
                    self.core.call_chain("get_draw_dimension", low, high)
                    # use zero as fallback for undefined axes (None)
                    max_dim = max((v_high or 0) - (v_low or 0) for v_high, v_low in zip(high, low))
                    if max_dim == 0:
                        # some arbitrary value if there are no visible objects
                        max_dim = 10
                    self.camera.move_camera_by_screen(x - start_x, y - start_y, max_dim)
                else:
                    # BUTTON_ROTATE
                    # update the camera position according to the mouse movement
                    self.camera.rotate_camera_by_screen(start_x, start_y, x, y)
                self.trigger_rendering()
            else:
                # button was released
                self.mouse["button"] = None
                self.trigger_rendering()
        self.mouse["event_timestamp"] = event.get_time()

    def rotate_view(self, widget=None, view=None):
        if view:
            self._last_view = view.copy()
        self.camera.set_view(view)
        self.trigger_rendering()

    def reset_view(self):
        self.rotate_view(view=None)
        self.trigger_rendering()

    def _resize_window(self, widget, width, height, data=None):
        self.trigger_rendering()

    def paint(self, widget=None, data=None):
        if not self.initialized:
            self.glsetup()
            self.initialized = True
        # draw the items
        GL = self._GL
        prev_mode = GL.glGetIntegerv(GL.GL_MATRIX_MODE)
        GL.glMatrixMode(GL.GL_MODELVIEW)
        # clear the background with the configured color
        bg_col = self.core.get("color_background")
        GL.glClearColor(bg_col["red"], bg_col["green"], bg_col["blue"], 1.0)
        GL.glClear(GL.GL_COLOR_BUFFER_BIT | GL.GL_DEPTH_BUFFER_BIT)
        self.camera.position_camera()
        # adjust Light #2
        v = self.camera.view
        lightpos = (v["center"][0] + v["distance"][0],
                    v["center"][1] + v["distance"][1],
                    v["center"][2] + v["distance"][2])
        GL.glLightfv(GL.GL_LIGHT1, GL.GL_POSITION, lightpos)
        # trigger the visualization of all items
        self.core.emit_event("visualize-items")
        GL.glMatrixMode(prev_mode)
        GL.glFlush()
        # Return "True" in order to propagate the "render" signal.
        return True

    def trigger_rendering(self):
        self.area.queue_render()


class Camera:

    def __init__(self, core, get_dim_func, import_gl, import_glu):
        self._GL = import_gl
        self._GLU = import_glu
        self.view = None
        self.core = core
        self._get_dim_func = get_dim_func
        self.set_view(self.view)

    def set_view(self, view=None):
        if view is None:
            self.view = VIEWS["reset"].copy()
        else:
            self.view = view.copy()
        self.center_view()
        self.auto_adjust_distance()

    def _get_low_high_dims(self):
        low, high = [None, None, None], [None, None, None]
        self.core.call_chain("get_draw_dimension", low, high)
        return low, high

    def center_view(self):
        center = []
        low, high = self._get_low_high_dims()
        if None in low or None in high:
            center = [0, 0, 0]
        else:
            for index in range(3):
                center.append((low[index] + high[index]) / 2)
        self.view["center"] = center

    def auto_adjust_distance(self):
        v = self.view
        # adjust the distance to get a view of the whole object
        low_high = list(zip(*self._get_low_high_dims()))
        if (None, None) in low_high:
            return
        max_dim = max([high - low for low, high in low_high])
        distv = pnormalized((v["distance"][0], v["distance"][1], v["distance"][2]))
        # The multiplier "1.25" is based on experiments. 1.414 (sqrt(2)) should
        # be roughly sufficient for showing the diagonal of any model.
        distv = pmul(distv, (max_dim * 1.25) / number(math.sin(v["fovy"] / 2)))
        self.view["distance"] = distv
        # Adjust the "far" distance for the camera to make sure, that huge
        # models (e.g. x=1000) are still visible.
        self.view["zfar"] = 100 * max_dim

    def scale_distance(self, scale):
        if scale != 0:
            scale = number(scale)
            dist = self.view["distance"]
            self.view["distance"] = (scale * dist[0], scale * dist[1], scale * dist[2])

    def get(self, key, default=None):
        if (self.view is not None) and key in self.view:
            return self.view[key]
        else:
            return default

    def set(self, key, value):
        self.view[key] = value

    def move_camera_by_screen(self, x_move, y_move, max_model_shift):
        """ move the camera according to a mouse movement
        @type x_move: int
        @value x_move: movement of the mouse along the x axis
        @type y_move: int
        @value y_move: movement of the mouse along the y axis
        @type max_model_shift: float
        @value max_model_shift: maximum shifting of the model view (e.g. for
            x_move == screen width)
        """
        factors_x, factors_y = self._get_axes_vectors()
        width, height = self._get_screen_dimensions()
        # relation of x/y movement to the respective screen dimension
        win_x_rel = (-2 * x_move) / float(width) / math.sin(self.view["fovy"])
        win_y_rel = (-2 * y_move) / float(height) / math.sin(self.view["fovy"])
        # This code is completely arbitrarily based on trial-and-error for
        # finding a nice movement speed for all distances.
        # Anyone with a better approach should just fix this.
        distance_vector = self.get("distance")
        distance = float(sqrt(sum([dim ** 2 for dim in distance_vector])))
        win_x_rel *= math.cos(win_x_rel / distance) ** 20
        win_y_rel *= math.cos(win_y_rel / distance) ** 20
        # update the model position that should be centered on the screen
        old_center = self.view["center"]
        new_center = []
        for i in range(3):
            new_center.append(old_center[i]
                              + max_model_shift * (number(win_x_rel) * factors_x[i]
                                                   + number(win_y_rel) * factors_y[i]))
        self.view["center"] = tuple(new_center)

    def rotate_camera_by_screen(self, start_x, start_y, end_x, end_y):
        factors_x, factors_y = self._get_axes_vectors()
        width, height = self._get_screen_dimensions()
        # calculate rotation factors - based on the distance to the center
        # (between -1 and 1)
        rot_x_factor = (2.0 * start_x) / width - 1
        rot_y_factor = (2.0 * start_y) / height - 1
        # calculate rotation angles (between -90 and +90 degrees)
        xdiff = end_x - start_x
        ydiff = end_y - start_y
        # compensate inverse rotation left/right side (around x axis) and
        # top/bottom (around y axis)
        if rot_x_factor < 0:
            ydiff = -ydiff
        if rot_y_factor > 0:
            xdiff = -xdiff
        rot_x_angle = rot_x_factor * math.pi * ydiff / height
        rot_y_angle = rot_y_factor * math.pi * xdiff / width
        # rotate around the "up" vector with the y-axis rotation
        original_distance = self.view["distance"]
        original_up = self.view["up"]
        y_rot_matrix = Matrix.get_rotation_matrix_axis_angle(factors_y, rot_y_angle)
        new_distance = Matrix.multiply_vector_matrix(original_distance, y_rot_matrix)
        new_up = Matrix.multiply_vector_matrix(original_up, y_rot_matrix)
        # rotate around the cross vector with the x-axis rotation
        x_rot_matrix = Matrix.get_rotation_matrix_axis_angle(factors_x, rot_x_angle)
        new_distance = Matrix.multiply_vector_matrix(new_distance, x_rot_matrix)
        new_up = Matrix.multiply_vector_matrix(new_up, x_rot_matrix)
        self.view["distance"] = new_distance
        self.view["up"] = new_up

    def position_camera(self):
        GL = self._GL
        GLU = self._GLU
        width, height = self._get_screen_dimensions()
        prev_mode = GL.glGetIntegerv(GL.GL_MATRIX_MODE)
        GL.glMatrixMode(GL.GL_PROJECTION)
        GL.glLoadIdentity()
        v = self.view
        # position the light according to the current bounding box
        light_pos = [0, 0, 0]
        low, high = self._get_low_high_dims()
        if None not in low and None not in high:
            for index in range(3):
                light_pos[index] = 2 * (high[index] - low[index])
        GL.glLightfv(GL.GL_LIGHT0, GL.GL_POSITION, (light_pos[0], light_pos[1], light_pos[2], 0.0))
        # position the camera
        camera_position = (v["center"][0] + v["distance"][0],
                           v["center"][1] + v["distance"][1],
                           v["center"][2] + v["distance"][2])
        # position a second light at camera position
        GL.glLightfv(GL.GL_LIGHT1, GL.GL_POSITION, (camera_position[0], camera_position[1],
                                                    camera_position[2], 0.0))
        if self.core.get("view_perspective"):
            # perspective view
            GLU.gluPerspective(v["fovy"], (0.0 + width) / height, v["znear"], v["zfar"])
        else:
            # parallel projection
            # This distance calculation is completely based on trial-and-error.
            distance = math.sqrt(sum([d ** 2 for d in v["distance"]]))
            distance *= math.log(math.sqrt(width * height)) / math.log(10)
            sin_factor = math.sin(v["fovy"] / 360.0 * math.pi) * distance
            left = v["center"][0] - sin_factor
            right = v["center"][0] + sin_factor
            top = v["center"][1] + sin_factor
            bottom = v["center"][1] - sin_factor
            near = v["center"][2] - 2 * sin_factor
            far = v["center"][2] + 2 * sin_factor
            GL.glOrtho(left, right, bottom, top, near, far)
        GLU.gluLookAt(camera_position[0], camera_position[1], camera_position[2],
                      v["center"][0], v["center"][1], v["center"][2],
                      v["up"][0], v["up"][1], v["up"][2])
        GL.glMatrixMode(prev_mode)

    def shift_view(self, x_dist=0, y_dist=0):
        obj_dim = []
        low, high = self._get_low_high_dims()
        if None in low or None in high:
            return
        for index in range(3):
            obj_dim.append(high[index] - low[index])
        max_dim = max(obj_dim)
        factor = 50
        self.move_camera_by_screen(x_dist * factor, y_dist * factor, max_dim)

    def zoom_in(self):
        self.scale_distance(sqrt(0.5))

    def zoom_out(self):
        self.scale_distance(sqrt(2))

    def _get_screen_dimensions(self):
        return self._get_dim_func()

    def _get_axes_vectors(self):
        """calculate the model vectors along the screen's x and y axes"""
        # The "up" vector defines, in what proportion each axis of the model is
        # in line with the screen's y axis.
        v_up = self.view["up"]
        factors_y = (number(v_up[0]), number(v_up[1]), number(v_up[2]))
        # Calculate the proportion of each model axis according to the x axis of
        # the screen.
        distv = self.view["distance"]
        distv = pnormalized((distv[0], distv[1], distv[2]))
        factors_x = pnormalized(pcross(distv, (v_up[0], v_up[1], v_up[2])))
        return (factors_x, factors_y)
