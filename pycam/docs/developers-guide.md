Mailing lists
-------------

Please join our development mailing list
[pycam-devel@sourceforge.net](http://sourceforge.net/mailarchive/forum.php?forum_name=pycam-devel).

Introduction
------------

The code of PyCAM including all related files and previous releases is
stored in a subversion repository. You need to checkout a local working
copy to start working on PyCAM:

    svn co https://pycam.svn.sourceforge.net/svnroot/pycam/trunk pycam

Upload your changes with:

    svn commit

Previous versions are stored in the *tags* path of the repository:
<https://pycam.svn.sourceforge.net/svnroot/pycam/tags>

Changing the GTK interface
--------------------------

The definition of the complete GUI is stored in an XML file (GTKBuilder
UI format).

You can change this GUI with the program *glade* (available in a package
of the same name in Debian and Ubuntu).

Whenever you change the name (this is not the label) of a control, you
should also replace all occurrences of this string in the file
`src/pycam/Gui/Project.py`.

Please add tooltips wherever it is suitable.

### Adding a menu item

Three steps are required to add a new menu item:

1.  add an action item (the very first icon in the left sidebar in
    *glade*) to the GUI file (see above)
    1.  add a suitable label - it will be visible as the text of the
        menu item
    2.  put an underscore in front of a character to mark it as the
        hotkey of this item
2.  add the item with its name to the file
    `share/gtk-interface/menubar.xml`
3.  add a handler for this action to `src/pycam/Gui/Project.py`
    1.  search for `accel\_key` (around line 160)

Changing default settings
-------------------------

PyCAM uses two types of settings.

The general settings define the unit size (imperial or metric), colors,
program locations and so on. They are stored automatically on exit in
the file `\~/.pycam/preferences.conf`.

The task settings describe the tools, processes, bounding boxes and
tasks. They are not stored automatically. Thus they are at their default
values on each start of PyCAM.

### General preferences

The default general PyCAM settings are defined at the top of
`src/pycam/Gui/Project.py` in the dictionary `PREFERENCES_DEFAULTS`.

### Task settings

The default task settings are defined in the file
`src/pycam/Gui/Settings.py` in the dictionary `BASIC_DEFAULT_CONFIG`.

Preparing a tutorial video
--------------------------

Some people really appreciate to use video tutorials for a quick
introduction. The following steps could help you to prepare one.

### Record a session

Use one of the available screen recorders.
[RecordMyDesktop](http://recordmydesktop.sourceforge.net) is a good
choice. Debian or Ubuntu users just install *gtk-recordmydesktop*.

Maybe you want to turn the background into a single flat color -
probably black - before starting the session.

### Uncompressing and cropping the video

If you recorded the whole screen, but you need only a part of it, then
run the following:

    ffmpeg -i INPUT_FILE -crop WIDTH:HEIGHT:LEFT_X:TOP_Y -vcodec ffv1 OUTPUT_FILE

Even if you don't need to crop the video, you should still use the line
above (without the *-crop* parameter) to convert the video into a
non-compressed format. Otherwise you will run later (during cutting)
into problems with missing keyframes resulting in half-way broken video
startup frames.

### Cut and merge the video

Use the following example for cutting a small part of the video:

    mencoder -ovc raw -noskip -forceidx -vf harddup -ss START_TIME -endpos DURATION INPUT_FILE -o OUTPUT_FILE

Combine multiple cutted video pieces:

    mencode -idx -ovc raw INPUT_FILE1 INPUT_FILE2 -o OUTPUT_FILE

### Add subtitles

Use one of the common subtitle editors (e.g.
[Gnome-Subtitles](http://gnome-subtitles.sourceforge.net/)) to create an
SRT file. You can obviously also do this manually with your favorite
text editor.

Run the following to merge the subtitles permanently with the video:

    mencoder -sub SUBTITLE_FILE -subfont-text-scale 3 -subalign 0 -subpos 2 -utf8 INPUT_FILE -o OUTPUT_FILE -ovc lavc -lavcopts vbitrate=1200

### Uploading

You should probably upload the video to one of the common video sharing
websites. Currently all videos are available at
[Vimeo](http://vimeo.com/channels/pycam).

### Publishing

Please announce your new tutorial via the [PyCAM's developer's
blog](http://fab.senselab.org/pycam). Send a mail to the mailing list,
if you need access to the blog.

The original video file and the available subtitles should be later
committed to the development repository. Additionally the new video
should be added to the [Video Translations](video-translations.md) page.
