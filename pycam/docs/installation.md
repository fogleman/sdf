Installing the latest release
-----------------------------

### Linux / \*BSD

1.  [download](http://sourceforge.net/projects/pycam/files/) the archive
    of your choice
2.  install the [requirements](requirements.md) for your system
3.  run `scripts/pycam` in the PyCAM directory

### Mac OS X

See [Installation MacOS](installation-macos.md) for details.

### Windows

Use the [standalone executable for Windows](https://sourceforge.net/projects/pycam/files/pycam/0.5.1/pycam-0.5.1.1_standalone.exe/download).
There are no further requirements.

If you want to use [multiple CPU cores or distributed processing](parallel-processing), then you will need to use the
[dependency installer](https://sourceforge.net/projects/pycam/files/pycam/0.5.1/python2.5-gtk-opengl.exe/download)
and the [PyCAM installer package](https://sourceforge.net/projects/pycam/files/pycam/0.5.1/pycam-0.5.1.win32.exe/download).

Installing the development version
----------------------------------

1.  install the [git](http://git-scm.com/) client (via your package
    manager or by [downloading](http://git-scm.com/downloads) it)
2.  checkout the PyCAM repository:
    `git clone `[`git@github.com:SebKuzminsky/pycam.git`](git@github.com:SebKuzminsky/pycam.git)
3.  install the [requirements](requirements.md) for your system
4.  run `pycam/run_gui.py` in the PyCAM directory
