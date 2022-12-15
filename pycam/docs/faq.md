Introduction
============

What is PyCAM?
--------------

PyCAM is a toolpath generator for 3 axis machines (usually: milling
machines). Your workflow will probably look like this:

1.  load a 3D or 2D model
2.  specify some processing parameters (tool size, ...)
3.  save the resulting GCode to a file

The GCode file can be used by most standards-compliant machine
controllers (e.g. [LinuxCNC](http://www.linuxcnc.org/)).

What licence applies to PyCAM? Does it cost money?
--------------------------------------------------

PyCAM is [free software](http://www.gnu.org/philosophy/free-sw.html)
licenced under the GPL v3. Thus you may use, change and distribute it
without any costs and you do not need any kind of approval from its
authors. Please take a look at the [licence
details](http://www.gnu.org/licenses/gpl.html) for further information.

Installing PyCAM
================

Requirement installer for Windows: “the NTVDM CPU has encountered an illegal instruction”
-----------------------------------------------------------------------------------------

The above errors seems to be triggered occasionally when installing the
*GtkGLext* component of the dependency installer in Windows XP SP3.

The root cause seems to be the (quite outdated) installer script for
*GtkGLext*. Please take a look at this
[filelist](http://sourceforge.net/projects/pycam/files/dependency-installer/win32/external_binaries/gtkglext/)
and download the two required DLL files manually. There you also find
the preferred location of these two files.

Running PyCAM
=============

Failed to initialize the interactive 3D model view
--------------------------------------------------

A lot of new users of PyCAM stumble upon this error message. The
solution depends on your platform and your method of installation.

Please take a look at [OpenGL troubles](opengl-troubles.md) for
details.

PyCAM consumes all my memory! \[only Unix\]
-------------------------------------------

There seems to be a problem with PyCAM v0.5.x running under Python 2.7.
Ubuntu Natty and Oneiric (11.04 / 11.10)) and other distributions ship
this version of Python by default. The specific cause of the problem was
discovered recently by jferrara. It will be fixed in release v0.6 of
PyCAM.

* Solution A: install Python 2.6 and use it for running PyCAM.
* Solution B: apply this small patch for PyCAM: <http://sourceforge.net/projects/pycam/forums/forum/860184/topic/4753623?message=10917042>

SVG import: postoedit reports a missing MSVCR100.dll library \[only Windows\]
-----------------------------------------------------------------------------

After installing *inkscape*, *pstoedit* and *ghostscript* the import of
SVG files fails with an an error report referring to a missing library
MSVCR100.dll (only relevant for PyCAM before v0.7).

pstoedit v3.60 (or later) depends on the MS Visual C++ 2010 library.
Thus you have to options to solve this issue:

* Solution A: install an older version of *pstoedit* (e.g. [v3.50](http://sourceforge.net/projects/pstoedit/files/pstoedit/3.50/))
* Solution B: install [Microsoft Visual C++ 2010 Redistributable Package (x86)](http://www.microsoft.com/download/en/details.aspx?id=5555) - maybe you also need to install [Windows Installer 3.1 Redistributable (v2)](http://www.microsoft.com/download/en/details.aspx?displaylang=en&id=25)

Toolpaths (general)
===================

Cropping a toolpath results in no moves at all
----------------------------------------------

The *crop* feature reduces the x-y area of all tool moves to the
projected area of the current model.

You should press the *2D projection* button to see if the resulting 2D
projection meets your expectations. PyCAM is partly guessing the height
of the slicing plane: usually z=0 is assumed, but the bottom of the
model is used if the model is completely above or below this plane. Just
shift the model along the z axis if you want to force a specific slicing
plane.

Toolpaths for 3D models
=======================

The *surface* path generator goes down to the bottom of the model. This will break my tool!
-------------------------------------------------------------------------------------------

The *surface* path generator should be the last step of your workflow.
You should probably use a “push cutter” strategy before. This will
remove the material in slices of configurable height.

My *Art of Illusion* models are half-way turned over
----------------------------------------------------

The coordinate system of [Art of Illusion](http://artofillusion.org/)
assumes that the xy plane is the front face of a model. Thus the height
of the model goes along the y axis - instead of the more common z axis.
Just swap the y and z axes (see 
[Model Transformations](model-transformations.md)) to fix this issue.

Toolpaths for 2D models
=======================

I can't open SVG files
----------------------

PyCAM (before v0.7) contains no built-in support for SVG. Thus you
needed to install [Inkscape](http://inkscape.org) and
[pstoedit](http://www.pstoedit.net/pstoedit).

See the list of
[requirements](requirements#Optional_external_programs) for
details.

My SVG models are empty
-----------------------

Please read the [2D modeling with Inkscape (SVG)](modeling-inkscape-svg.md).

The most common problems are:

-   partially transparent items are ignored (opacity must be at 100%)
-   items outside of the document sheet (the canvas) are ignored
-   [ghostscript](http://pages.cs.wisc.edu/~ghost/) is not installed
    (probably only relevant for Windows users)

Rapid moves are placed below the model instead of above
-------------------------------------------------------

Probably you need to adjust the *safety height* (see *GCode settings*)
according to the height of your model. Alternatively you could also shift
the model down to z=0.

Toolpaths with an offset are placed inside of the model instead of outside
--------------------------------------------------------------------------

There can be two reasons:

* you specified a negative engraving offset: In this case the toolpath is supposed to be inside of the polygons. This is a feature.
* the polygon's winding is clockwise instead of counter-clockwise (or vice versa): use the *toggle directions* or *revise directions* button to fix this issue.

How can I specify the depth for gravures?
-----------------------------------------

The height of the bounding box defines the depth of a gravure. Just
increase the upper z-margin of the bounding box. You will need to switch
to the “fixed margin” style to accomplish this.

Why can't the pocketing algorithm handle simple holes/islands?
--------------------------------------------------------------

Sadly both major libraries offering 2D polygon operations
([CGAL](http://www.cgal.org/) and
[GPC](http://www.cs.man.ac.uk/~toby/alan/software/)) were distributed
under GPL-incompatible licenses until recently. Since the middle of 2012
[CGAL switched to the GPL](http://www.cgal.org/license.html). Thus it is
now possible to use this great library for geometry operations. So this
missing feature can be added easily as soon as someone feels like
jumping into this task ...

Open Questions
==============

Just add your problem or question here - it will get collected and
answered ...

(Or use the
[forum](http://sourceforge.net/projects/pycam/forums/forum/860184), if
you expect a longer discussion.)
