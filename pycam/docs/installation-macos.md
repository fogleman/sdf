Versions, dependencies and complications
----------------------------------------

Please note that the most recent successful usage of PyCAM on MacOS was
reported around 2012. Thus you should stick with PyCAM v0.5.1 and be prepared
to tackle weird dependency problems, if you really need to run PyCAM on MacOS.

You should use Linux instead, if you want to use a more recent release of PyCAM.

Install requirements via MacPorts
---------------------------------

First you need to install [MacPorts](http://www.macports.org/install.php).

Afterwards you need to install the following packages:

-   py25-gtk
-   py25-gtkglext
-   py25-opengl (at least v3.0.1b2)

Simply run the following to install all dependencies:

     sudo port install py25-gtk py25-gtkglext py25-opengl

Run PyCAM
---------

-   extract the [PyCAM archive](https://sourceforge.net/projects/pycam/files/pycam/)
-   run */opt/local/bin/python2.5 pycam* from within PyCAM's directory
    -   the above line refers to MacPorts' Python interpreter (instead
        of MacOS' native Python) - otherwise it will not find OpenGL and
        the other required modules

Problems? Solutions!
--------------------

Below you will find a list of potential problems reported by PyCAM
users.

If these workarounds do not help: please ask a question in the
[*Help* forum](http://sourceforge.net/projects/pycam/forums/forum/860184) and
provide the following relevant information about your setup.

Get the list of installed python-related packages:

    port installed | grep py

Get Python's output for every interesting *import* statement:

    foo@bar:~$ /opt/local/bin/python2.5
    Python 2.5.5 (r255:77872, Nov 28 2010, 19:00:19)
    [GCC 4.4.5] on linux2
    Type "help", "copyright", "credits” or "license" for more information.
    >>> import gtk.gtkgl
    >>> import OpenGL.GL as GL
    >>> import OpenGL.GLU as GLU
    >>> import OpenGL.GLUT as GLUT

(the above output of a successful test was taken on Linux - your
installed versions may differ slightly)

### OpenGL (python-gtkglext1) missing

Some users reported the following warning from PyCAM, even though they
installed all required packages:

> Please install 'python-gtkglext1'

Since none of the PyCAM developers is a Mac OS user, it is not easy for
us to track down this issue. Currently it looks like a problem of
[Python 2.5 and *ctypes*](https://trac.macports.org/ticket/26186) on Mac
OS X. Please try the following steps to fix it:

1.  install the libffi package: `port install libffi`
2.  rebuild Python: `port -v upgrade --force python25`

(suggested on
[stackoverflow](http://stackoverflow.com/questions/4535725/ctypes-import-not-working-on-python-2-5/4536064#4536064))

Alternatively you could try to update Python to v2.6 and install the
corresponding packages for GTK, OpenGL and so on.

Please report back, if one of the above suggestions fixes the problem
for you - thanks!

### OpenGL is too old

According to a [forum post from
lilalinux](http://sourceforge.net/projects/pycam/forums/forum/860183/topic/3800091)
you need at least OpenGL v3.0.1b2. Otherwise you will probably get a
blank 3D visualization window.
