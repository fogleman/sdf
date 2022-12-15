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

from pycam.errors import InvalidDataError
from pycam.Geometry.PointUtils import padd, pdot, pmul, pnormalized
import pycam.Plugins


class OpenGLViewModel(pycam.Plugins.PluginBase):

    DEPENDS = ["OpenGLWindow", "Models"]
    CATEGORIES = ["Model", "Visualization", "OpenGL"]

    def setup(self):
        self._event_handlers = (("visualize-items", self.draw_model),
                                ("model-changed", "visual-item-updated"),
                                ("model-list-changed", "visual-item-updated"))
        self.core.get("register_display_item")("show_model", "Show Model", 10)
        self.core.get("register_color")("color_model", "Model", 10)
        self.core.register_chain("get_draw_dimension", self.get_draw_dimension)
        self.register_event_handlers(self._event_handlers)
        self.core.emit_event("visual-item-updated")
        self._cache = {}
        return True

    def teardown(self):
        self.unregister_event_handlers(self._event_handlers)
        self.core.unregister_chain("get_draw_dimension", self.get_draw_dimension)
        self.core.get("unregister_display_item")("show_model")
        self.core.get("unregister_color")("color_model")
        self.core.emit_event("visual-item-updated")

    def _get_cache_key(self, model, *args, **kwargs):
        if hasattr(model, "uuid"):
            return "%s - %s - %s" % (model.uuid, repr(args), repr(kwargs))
        else:
            return None

    def _is_visible(self):
        return (self.core.get("show_model")
                and not (self.core.get("show_simulation")
                         and self.core.get("simulation_toolpath_moves")))

    def get_draw_dimension(self, low, high):
        if self._is_visible():
            for model_dict in self.core.get("models").get_visible():
                try:
                    model_box = model_dict.get_model().get_bounds().get_bounds()
                except InvalidDataError as exc:
                    self.log.warning("Failed to visualize model: %s", exc)
                    continue
                for index, (mlow, mhigh) in enumerate(zip(model_box.lower, model_box.upper)):
                    if (low[index] is None) or ((mlow is not None) and (mlow < low[index])):
                        low[index] = mlow
                    if (high[index] is None) or ((mhigh is not None) and (mhigh > high[index])):
                        high[index] = mhigh

    def draw_model(self):
        GL = self._GL
        if self._is_visible():
            fallback_color = self.core.get("models").FALLBACK_COLOR
            for model_dict in self.core.get("models").get_visible():
                try:
                    model = model_dict.get_model()
                except InvalidDataError as exc:
                    self.log.warning("Failed to visualize model: %s", exc)
                    continue
                col = model_dict.get_application_value("color", default=fallback_color)
                color = (col["red"], col["green"], col["blue"], col["alpha"])
                GL.glColor4f(*color)
                # reset the material color
                GL.glMaterial(GL.GL_FRONT_AND_BACK, GL.GL_AMBIENT_AND_DIFFUSE, color)
                # we need to wait until the color change is active
                GL.glFinish()
                if self.core.get("opengl_cache_enable"):
                    key = self._get_cache_key(model, color=color,
                                              show_directions=self.core.get("show_directions"))
                    do_caching = key is not None
                else:
                    do_caching = False
                if do_caching and key not in self._cache:
                    # Rendering a display list takes less than 5% of the time
                    # for a complete rebuild.
                    list_index = GL.glGenLists(1)
                    if list_index > 0:
                        # Somehow "GL_COMPILE_AND_EXECUTE" fails - we render
                        # it later.
                        GL.glNewList(list_index, GL.GL_COMPILE)
                    else:
                        do_caching = False
                    # next: compile an OpenGL display list
                if not do_caching or (key not in self._cache):
                    self.core.call_chain("draw_models", [model])
                if do_caching:
                    if key not in self._cache:
                        GL.glEndList()
                        GL.glCallList(list_index)
                        self._cache[key] = list_index
                    else:
                        # render a previously compiled display list
                        GL.glCallList(self._cache[key])


class OpenGLViewModelTriangle(pycam.Plugins.PluginBase):

    DEPENDS = ["OpenGLViewModel"]
    CATEGORIES = ["Model", "Visualization", "OpenGL"]

    def setup(self):
        self.core.register_chain("draw_models", self.draw_triangle_model, 10)
        return True

    def teardown(self):
        self.core.unregister_chain("draw_models", self.draw_triangle_model)

    def draw_triangle_model(self, models):
        def calc_normal(main, normals):
            suitable = (0, 0, 0, 'v')
            for normal, weight in normals:
                dot = pdot(main, normal)
                if dot > 0:
                    suitable = padd(suitable, pmul(normal, weight * dot))
            return pnormalized(suitable)

        if not models:
            return
        GL = self._GL
        removal_list = []
        for index, model in enumerate(models):
            if not hasattr(model, "triangles"):
                continue
            vertices = {}
            for t in model.triangles():
                for p in (t.p1, t.p2, t.p3):
                    if p not in vertices:
                        vertices[p] = []
                    vertices[p].append((pnormalized(t.normal), t.get_area()))
            GL.glBegin(GL.GL_TRIANGLES)
            for t in model.triangles():
                # The triangle's points are in clockwise order, but GL expects
                # counter-clockwise sorting.
                for p in (t.p1, t.p3, t.p2):
                    normal = calc_normal(pnormalized(t.normal), vertices[p])
                    GL.glNormal3f(normal[0], normal[1], normal[2])
                    GL.glVertex3f(p[0], p[1], p[2])
            GL.glEnd()
            removal_list.append(index)
        # remove all models that we processed
        removal_list.reverse()
        for index in removal_list:
            models.pop(index)


class OpenGLViewModelGeneric(pycam.Plugins.PluginBase):

    DEPENDS = ["OpenGLViewModel"]
    CATEGORIES = ["Model", "Visualization", "OpenGL"]

    def setup(self):
        self.core.register_chain("draw_models", self.draw_generic_model, 100)
        return True

    def teardown(self):
        self.core.unregister_chain("draw_models", self.draw_generic_model)

    def draw_generic_model(self, models):
        removal_list = []
        for index, model in enumerate(models):
            for item in next(model):
                # ignore invisible things like the normal of a ContourModel
                if hasattr(item, "to_opengl"):
                    item.to_opengl(show_directions=self.core.get("show_directions"))
            removal_list.append(index)
        removal_list.reverse()
        for index in removal_list:
            removal_list.pop(index)
