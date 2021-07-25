Features of PyCAM
=================

Supported file formats
----------------------

### Import

-   STL (binary/ascii)
-   DXF
-   SVG
-   PS/EPS

### Export

-   STL (ascii)
-   SVG
-   GCode

Model operations
----------------

STL files describe 3D models of triangles.
[OpenSCAD](http://openscad.org), [Art of
Illusion](http://www.artofillusion.org/),
[MeshLab](http://meshlab.sourceforge.net/) and other programs can export
3D models as STL files.

2D models are imported from SVG, DXF, PS and EPS files.

Implemented model operations:

-   scale the mode by a given factor
-   move the model
-   rotate around x, y or z axis (90 degrees)
-   flip the model against the xy-, xz- or yz-plane
-   swap axes
-   save the model to an ascii STL file
-   reverse line directions of 2D contour models (toggles inside/outside
    of polygons)
-   2D projection of 3D models
-   automatically fix inside/outside relationships of 2D polygons
-   [extrude 2D models](http://fab.senselab.org/node/227) with
    configurable slopes

Cutter definitions
------------------

PyCAM needs to know the shape and size of the cutter (drill) to generate
the toolpath shaping a model.

The following cutter attributes are supported:

-   shapes: cylindrical, spherical, toroidal
-   dimensions: radius and (if used) torus radius

Processing settings
-------------------

The processing settings determine the way the toolpath is generated.
This mainly includes the direction of force (Drop Cutter vs. Push
Cutter) and the path strategy.

### Details

-   Strategies: Slice removal, Contour (two modes), Drop cutter,
    Engraving
-   Milling style: conventional / climb / minimize movements
-   Grid direction: x, y or both
-   Material Allowance: amount of material to remain around the model
-   Overlap: how far parallel toolpath should overlap
-   Step down: maximum height of material to be abraded with one slice
    of the Push Cutter
-   Engrave offset: move the cutter parallel to the given 2D model
-   Pocketing type: clearing a closed area

### Support Bridges

If you want all pieces of your model to stay connected to the material
around (e.g. if you don't use a vacuum table), then you may want to add
support bridges to your model.

These support bridges can be defined in two ways:

-   a horizontal/vertical grid
-   automatic distribution of support bridges along the outline (corners
    or edges) of parts of the model

The width, height and length of the support bridges are configurable.

Engrave text
------------

PyCAM includes the single-line fonts developed by
[QCAD](http://qcad.org). You can type text and define some properties
(skew, pitch, line spacing). The result can be exported to an SVG file
or used directly in PyCAM (for engraving).

See the rendered output of all [single-line fonts](engrave-fonts.md) included in PyCAM.

Toolpath handling
-----------------

-   [crop toolpath](http://fab.senselab.org/en/blog/cropping-toolpaths-model-outline)
    to the outline of a model or to arbitrary 2D contours
-   [clone a toolpath](http://fab.senselab.org/en/blog/cloning-toolpath-mass-production)
    in a grid of columns and rows

GCode features
--------------

GCode is a common input format for machine control software (e.g.
[LinuxCNC](http://www.linuxcnc.org/)). The GCode file may contain one or mothe
toolpaths.

Available Features:

-   export toolpath as GCode files
-   Measurement unit: millimeter or inches
-   Speed: rotation speed of the drill
-   Feedrate: maximum speed of the drill against the material
-   join multiple toolpaths into one gcode file (including tool changes)
-   Safety height: z-value of the safe position above the object
-   specify path precision vs. processing speed
    ([G61/G64](http://www.linuxcnc.org/docs/html/gcode_main.html#G61,%20G61.1,%20G64%20Path%20Control%7CGCode))
-   specify the minimum step width for all three axes
-   [*touch off* and *tool change*](touch-off.md) operations
-   export tool definitions to LinuxCNC (for improved visualization)

GUI features
------------

-   interactive [visualization of the 3D model](3d-view)
    (rotate, pan and zoom with mouse or keyboard)
-   load and save processing settings file
    -   useful for extending the current processing templates
-   fully configurable model view items (colors, visibility)
-   management of toolpaths
-   default templates for three operatios are defined (“rough”,
    “semi-finish”, “finish”)
-   show progress bar for time consuming operations
-   show drill progress during path generation (optional)
-   show a
    [simulation of tool moves](http://fab.senselab.org/en/blog/new-simulation-mode-video-tutorial)
-   show statistics of connected worker threads in a process pool
    (see [Server Mode](server-mode.md))

Command-line features
---------------------

-   load an STL/DXF/PS/EPS/SVG model file
-   load a processing settings file
-   create a GCode file non-interactively (currently with only one
    toolpath):
    -   almost all GUI options are usable via command-line arguments

Parallel processing
-------------------

PyCAM automatically uses all available CPU cores to run toolpath
calculations in parallel.

Additionally you can connect multiple hosts for distributed processing
within the pool. See the [Server Mode](server-mode.md) for more
details.

Please check the requirements for all possible
[features on different platforms](parallel-processing).

Internal features
-----------------

### Collision detection

Currently there is one implementation used for generating a toolpath:

-   triangular collision calculation:
    -   calculates the collision position by checking all relevant
        triangles and their direction
