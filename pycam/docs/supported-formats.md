Supported formats of PyCAM
==========================

PyCAM can import and export data from and to different formats.

Read the following pages for hints about creating usable models:

- [2D modeling with Inkscape (SVG)](modeling-inkscape-svg.md)
- [2D modeling with OpenSCAD (DXF)](modeling-openscad-dxf.md)

STL
---

[STL files](http://en.wikipedia.org/wiki/STL_(file_format)) describe the surface
of 3D models as a mesh of triangles. The STL format definition describes
an ascii and a binary storage format. Both are supported by PyCAM.

PyCAM can transform 3D models and save the result as an ascii STL file.

DXF
---

[DXF files](http://en.wikipedia.org/wiki/DXF_(file_format)) can describe 3D or
2D models. PyCAM can import both types. The following DXF primitives are
supported:

-   LINE / POLYLINE / LWPOLYLINE
-   ARC / CIRCLE
-   TEXT / MTEXT
-   3DFACE

SVG
---

[Scalable vector files](http://en.wikipedia.org/wiki/Scalable_Vector_Graphics) can describe 2D
models. They are supposed to be used as contour models for engravings.

Before PyCAM v0.7 you needed to install *Inkscape* and *pstoedit* if you want
to import SVG files. Please take a look at the
[requirements](requirements#Optional_external_programs) for more details.

Additionally you should read the [hints for Inkscape](modeling-inkscape-svg.md) to avoid 
common pitfalls.
