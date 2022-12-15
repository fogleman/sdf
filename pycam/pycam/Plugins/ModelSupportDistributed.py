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


import pycam.Plugins
from pycam.workspace import DistributionStrategy, SupportBridgesLayout, SourceType
import pycam.workspace.data_models


class ModelSupportDistributed(pycam.Plugins.PluginBase):

    UI_FILE = "model_support_distributed.ui"
    DEPENDS = ["Models", "ModelSupport"]
    CATEGORIES = ["Model", "Support bridges"]

    def setup(self):
        if self.gui:
            support_expander = self.gui.get_object("DistributedSupportExpander")
            support_expander.unparent()
            self._gtk_handlers = []
            self.core.register_ui("support_model_type_selector", "Distributed (edges)",
                                  "distributed_edges", weight=0)
            self.core.register_ui("support_model_type_selector", "Distributed (corners)",
                                  "distributed_corners", weight=10)
            self.core.register_ui("support_model_settings", "Grid settings", support_expander)
            grid_length = self.gui.get_object("SupportGridLength")
            self._gtk_handlers.append((grid_length, "value-changed", "support-model-changed"))
            self.core.add_item("support_grid_length", grid_length.get_value, grid_length.set_value)
            average_distance = self.gui.get_object("GridAverageDistance")
            self._gtk_handlers.append((average_distance, "value-changed", "support-model-changed"))
            self.core.add_item("support_grid_average_distance", average_distance.get_value,
                               average_distance.set_value)
            minimum_bridges = self.gui.get_object("GridMinBridgesPerPolygon")
            self._gtk_handlers.append((minimum_bridges, "value-changed", "support-model-changed"))
            self.core.add_item("support_grid_minimum_bridges", minimum_bridges.get_value,
                               minimum_bridges.set_value)
            # TODO: remove these public settings
            self.core.set("support_grid_average_distance", 30)
            self.core.set("support_grid_minimum_bridges", 2)
            self.core.set("support_grid_length", 5)
            self.core.register_chain("get_support_models", self._get_support_models)
            # register handlers
            self._event_handlers = (("support-model-changed", self.update_support_controls),)
            self.register_gtk_handlers(self._gtk_handlers)
            self.register_event_handlers(self._event_handlers)
        return True

    def teardown(self):
        if self.gui:
            self.unregister_event_handlers(self._event_handlers)
            self.unregister_gtk_handlers(self._gtk_handlers)
            self.core.unregister_chain("get_support_models", self._get_support_models)
            self.core.unregister_ui("support_model_type_selector", "distributed_edges")
            self.core.unregister_ui("support_model_type_selector", "distributed_corners")
            self.core.unregister_ui("support_model_settings",
                                    self.gui.get_object("DistributedSupportExpander"))

    def update_support_controls(self):
        grid_type = self.core.get("support_model_type")
        if grid_type in ("distributed_edges", "distributed_corners"):
            self.gui.get_object("DistributedSupportExpander").show()
        else:
            self.gui.get_object("DistributedSupportExpander").hide()

    def _get_support_models(self, models, support_models):
        grid_type = self.core.get("support_model_type")
        if grid_type in ("distributed_edges", "distributed_corners"):
            s = self.core
            for model in models:
                if (model.get_model()
                        and (s.get("support_grid_thickness") > 0)
                        and (s.get("support_grid_height") > 0)
                        and (s.get("support_grid_average_distance") > 0)
                        and (s.get("support_grid_minimum_bridges") > 0)):
                    if grid_type == "distributed_corners":
                        distribution = DistributionStrategy.CORNERS
                    else:
                        distribution = DistributionStrategy.EVENLY
                    model_definition = {
                        "source": {
                            "type": SourceType.SUPPORT_BRIDGES,
                            "layout": SupportBridgesLayout.DISTRIBUTED,
                            "models": tuple(model.get_id() for model in models),
                            "average_distance": s.get("support_grid_average_distance"),
                            "shape": {"height": s.get("support_grid_height"),
                                      "width": s.get("support_grid_thickness"),
                                      "length": s.get("support_grid_length")},
                            "minimum_count": s.get("support_grid_minimum_bridges"),
                            "distribution": distribution,
                        }
                    }
                    support_models.append(pycam.workspace.data_models.Model(
                        "support", model_definition, add_to_collection=False))
            # all models are processed -> wipe the input list
            models.clear()
