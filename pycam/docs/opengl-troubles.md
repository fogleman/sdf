Troubleshooting OpenGL issues
=============================

Diganostics for all platforms
-----------------------------

First you should try to open a Python console:

On Linux: open a terminal and type

    python

Windows: run `C:\\Python25\\python.exe`

Python's interactive console should now be waiting for your commands.
Its output could look like this:

    Python 2.5.5 (r255:77872, Nov 28 2010, 19:00:19) 
    [GCC 4.4.5] on linux2
    Type "help", "copyright", "credits" or "license" for more information.
    >>>

Now its time to import all relevant modues manually:

    import gtk
    import OpenGL.GL
    import OpenGL.GLU
    import OpenGL.GLUT
    import gtk.gtkgl

It is acceptable to see some warnings just after the *gtk* import. Every
other message could be a sign of a problem. Please report these messages
via the forum or the developer mailing list if you encounter a problem
that you cannot solve on your own.

Details for Unix
----------------

Verify the installed packages:

Debian / Ubuntu:

    dpkg -l python-gtk2 python-gtkglext1 python-opengl | grep ^i

OpenSuSE:

    zypper -i --match-any python-gtk2 python-gtkglext python-opengl

MacOS:

    port installed | grep python

The packages mentioned above should be marked as installed. The
following versions are known to work:

-   python-gtk2: 2.24.0
-   python-gtkglext 1.1.0
-   python-opengl 3.0.1

*Specific for MacOS:*

-   python-opengl may not be older than v3.0.1b2 - otherwise you get a
    blank 3D view window
-   please take a look at the [MacOS installation
    instructions](installation-macos)
    for platform-specific issues

Details for Windows
-------------------

### missing libgdkglext-win32-1.0-0.dll

Valid for: Windows, installer package with dependency installer

In the beginning of 2012 a download site went down that hosted one of the programs that
are downloaded during the installation process of the dependency installer.
Older dependency installers are also affected - even the ones that were working before.

Download the [updated dependency installer](http://sourceforge.net/projects/pycam/files/dependency-installer/win32/external_binaries/gtkglext/gtkglext-win32-1.2.0.exe/download) and run it again.

### missing DLL (name is known)

DLL management under Windows is a bit complicated. You need to make sure
that all relevant libraries are accessible in the list of directories
defined in the PATH environment variable.

An example of this kind of problems was exposed by an older version of
the dependency installer package for Windows. Users were struggling with
an error message claiming that *libgdkglext1-win32-1.0.0.dll* could not
be found. This file is installed along with *python-gtkglext* in
*C:\\GtkGLExt\\1.0\\bin* as you can see in Windows search facility. The
problem is gone as soon as you add this path to your environment
settings (see *Settings -&gt; System -&gt; Advanced -&gt; Environment
variables*).

### missing DLL (name is unknown)

The following example error message is given:

    >>> import gtk.gtkgl
    Traceback (most recent call last):
      File "<interactive input>", line 1, in <module>
      File "C:\pkg\Python25\Lib\site-packages\gtk-2.0\gtk\gtkgl\__init__.py", line 21, in <module>
        from _gtkgl import *
    ImportError: DLL load failed: The specified module could not be found.

* Step 1: locate the related *PYD* file (a kind of Python DLL) - it resides just next to the \*.py file that caused the error message. Here: *C:\\Python25\\Lib\\site-packages\\gtk-2.0\\gtk\\gtkgl\\\_gtkgl.pyd*
* Step 2: Download and run [DependencyWalker](http://dependencywalker.com)
* Step 3: Open the *PYD* file with Depdendy Walker and check if any of the libraries are marked as missing or unknown.

Now you should know the name of the missing library - thus you can
continue with the section above.
