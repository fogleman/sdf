Overview
--------

[OpenSCAD](http://openscad.org) is a parametric (non-interactive) 2D/3D
modeller. The following hints refer to 2D modeling.

3D to 2D projection / Sectional drawing
---------------------------------------

The following example code creates a sectional drawing of a sphere at a
specific z-level:

    projection(cut=true) translate([0, 0, -3]) sphere(r=10);

See the [OpenSCAD User
Manual](http://en.wikibooks.org/wiki/OpenSCAD_User_Manual/3D_to_2D_Projection)
for details.

2D modeling
------------

OpenSCAD supports a variety of 2D primitives. See the [OpenSCAD User
Manual](http://en.wikibooks.org/wiki/OpenSCAD_User_Manual/2D_Primitives)
for details.

DXF Export
----------

OpenSCAD can export 2D models to DXF.

Sadly there are currently several limitations:

-   The latest release (2010.05) creates single lines (instead of
    connected line segments). This makes it hard to manipulate the DXF
    file with [Inkscape](http://inkscape.org) or other vector graphic
    editors. The latest revision (development repository) fixed this
    issue.
-   Lines defining outlines and inner holes are currently drawn in the
    same direction (clockwise). Thus PyCAM can't distinguish between
    inner and outer lines for engraving offsets. You can reverse the
    inner lines with a vector graphics editor (e.g. Inkscape).

Both of the above issues can be easily fixed with PyCAM's [Revise
directions](model-transformations#Miscellaneous) operation.
