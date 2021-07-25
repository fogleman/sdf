Introduction to PyCAM
=====================

PyCAM is a toolpath generator for 3 axis machines. This text is supposed
to introduce you to the basics of using PyCAM.

Create a model for your object
------------------------------

PyCAM supports the following file types:

-   STL -- for 3D models (e.g. created by
    [Blender](http://www.blender.org/), [Art of
    Illusion](http://www.artofillusion.org/),
    [OpenSCAD](http://openscad.org/),
    [Meshlab](http://meshlab.sourceforge.net/), ...)
-   DXF -- for engravings (limited DXF support: only 2D with basic
    elements)
-   SVG -- for engravings (see
    [requirements](requirements#Optional_external_programs)
    for details)

See [supported formats](supported-formats.md) for more details.

You can create your model file with the program of your choice. After
loading the file in PyCAM you will see the model shape in the 3D
visualization window.

Preparation of the model
------------------------

Sometimes you may need to move, rotate or resize your model before
processing it.

PyCAM supports the following basic model transformations:

-   rotate around the x, y or z axis (90 degree steps)
-   mirror along the xy, xz or yz plane
-   swap two axes: x with y, x with z or y with z

The following resize operations are available:

-   scale the whole model by a given factor (100% -&gt; no scaling)
-   scale one axis to a given length (the optional “proportional”
    setting defines if this factor should be applied to all axes)

The model can be moved to a different location:

-   move the model by a specific offset for each axis
-   move the model to the origin of the coordinate system (the lower
    limit of each model dimension becomes zero)

The modified model can be saved as an STL (3D) or SVG (2D) file.

Defining an operation
---------------------

PyCAM uses *tasks* to specify the detailed settings for a toolpath to be
generated.

A task is a combination of the following profiles:

-   a tool
-   a process
-   a bounding box

Each of these profiles will be described below.

### Specify the tools

Each toolpath is connected with a tool. The tool shape and its dimension
are important for calculating accurate toolpaths. Multiple tools can be
necessary for rough and finishing operations.

The most important setting is the radius of the tool.

Additionally you can define the shape of your tool. The following three
shapes are available:

-   cylindrical (round shaft; flat top): the most common tool shape
-   spherical (radius cutter / corner-rounding cutter; round shaft;
    spherical top)
-   toroidal (round shaft; “donut”-like top)

You need at least one tool.

It is common to use a big tool for the first rough milling operation.
The finish milling operation is usually done with a smaller tool.
Specify all necessary tools for your planned operations.


### Specify the milling processes

The process settings specify the strategy of the toolpath generator.
This determines the height of each layer of material to be removed and
some other details.

The following operations are available:

-   Push Cutter: removes the excessive material in multiple layers of
    fixed height (see the “step down” setting) - this is common for an
    initial rough operation or an optionally following contour cutting
    operation
-   Drop Cutter: follow the height of the model - this should be last
    operation (it assumes that the material above was removed before)
-   Engrave Cutter: this operation is only suitable for contour models
    (from a DXF file)

You will want to take a look at the following process settings:

-   Material Allowance: how much material should be left (minimum
    required distance between the tool and the object) - this is useful
    for rough operations with big tools
-   Step Down: the maximum material height of each layer during a rough
    operation - this depends on the material and the tool size

See [Process Settings](process-settings.md) for more details about
process settings.

### Specify the bounding box

Each operation is applied to a specific bounding box. The default
bounding box has a 10% margin at each side of the model. You need to
define other bounding boxes, if you want to treat different parts of the
object with more or less fine grained operations.

The bounding box can be related to the size of the model (*relative
margin* or *fixed margin*). Alternatively you can also define a custom
bounding box that does not depend on the model size. These three ways of
defining the bounding box are just different views of the same data.

See [Bounding Box](bounding-box.md) for more details about
specifying bounding boxes.

Generate the toolpath(s)
------------------------

You need to define a task for each toolpath to be generated.

Each task can be marked as *enabled*. All *enabled* tasks are performed
when clicking on *Generate all toolpaths*. Alternatively you can
click *Generate Toolpath* to process only the currently selected
task.


Examine generated toolpaths
---------------------------

The new tab *Toolpaths* appears as soon as at least one toolpath was
generated. The attribute *visible* of each toolpath defines if the
toolpath should be shown in the 3D visualization window.

Export toolpaths as GCode
-------------------------

Choose *Export Toolpaths* from the *File* menu to store all toolpaths
(see *Toolpaths* tab) in a GCode file.

The GCode file can be used with any common machine controller software,
e.g. [LinuxCNC](http://www.linuxcnc.org/).

