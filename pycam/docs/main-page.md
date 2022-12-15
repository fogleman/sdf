Use PyCAM to generate toolpaths suitable for 3-Axis CNC machining
-----------------------------------------------------------------

You can use **svg and dxf files for 2.5D milling** and **stl files for
full 3-axis 3D milling!**

Take a look at some [screenshots](screenshots.md) for a quick
overview of the features. The [list of features](features.md)
gives you more details.

Read the [Installation](installation.md) instructions.

Watch some [Videos Tutorials](http://vimeo.com/channels/pycam) in
multiple languages. You are welcome to
[translate](video-translations.md) the subtitles to your native
language!

Join the [mailing lists](http://sourceforge.net/mail/?group_id=237831)
if you want to follow recent developments.

Read our [development blog](http://fab.senselab.org/pycam) about
interesting new features and plans.

Check the [FAQ](faq.md) section if are looking for answers.

Look for [alternative programs](other-programs.md) generating
G-Code for CNC machining, if PyCAM should not fulfill your needs. In
this case: please [let us know, what's
missing](wanted-features)!

Add the features that you want to see in PyCAM to the
[wishlist](wanted-features.md) ....

Common workflow
---------------

A common workflow could look like this:

1.  open an STL model file
2.  configure cutter settings (e.g. drill shape and size)
3.  configure processing settings (e.g. the toolpath strategy, remaining
    material, ...)
4.  start the toolpath generation
5.  repeat steps 2..4 if you want to add more toolpaths
6.  export the generated toolpaths to a file (in GCode format)

The output (GCode) can be used for [LinuxCNC](http://www.linuxcnc.org/) and other
machine controller software.

Graphical User Interface
------------------------

The graphical user interface of PyCAM is based on GTK. All available
features are configurable in different tabs. The complete setup can be
stored in task settings file for later re-use.

The [3D View](3d-view) is based on OpenGL. It is not strictly
required for the operation. But it is very helpful for making sure that
the result meets your expectations.

Alternatively you can also use most features of PyCAM via its
[command line interface](cli-examples.md) (e.g. for batch
processing).

Command-line Interface
----------------------

PyCAM supports non-interactive toolpath generation. This is useful for
batch processing.

See some [examples](cli-examples.md) for the command-line
usage.

Requirements
------------

See the requirement list for the different platforms: [Requirements](requirements.md).

Open issues / Plans
-------------------

Take a look at our [TODO](todo.md) list.

Development
-----------

Take a look at [Developer's Guide](developers-guide.md) if you
want to improve PyCAM.
