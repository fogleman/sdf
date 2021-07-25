[EXAMPLES]
.nf
.B pycam \-\-export\-gcode=output.ngc \-\-bounds\-type=relative\-margin \-\-bounds-lower=0.1,0.05,-0.1 foo.stl

.fi
Use the default settings to process the model \fBfoo.stl\fR with an adjusted
lower margin (minx, miny, minz) of 10% (for x), 5% (for y) and \-10% (for z).

[ENVIRONMENT]
.IP PYCAM_DATA_DIR
Override the default data directory of PyCAM. This allows
you to provide customized logos, menu files or non-default sample files.
.IP PYCAM_FONT_DIR
Override the default location of engrave fonts.
.IP PYTHONPATH
You may want to define this variable in case that you installed the
\fBPyCAM\fR python package in a non-default location.

[REPORTING BUGS]
See http://sourceforge.net/tracker/?group_id=237831&atid=1104176

[SEE ALSO]
Take a look at the output of \fBpycam \-\-help\fR to get a slightly better
formatted list of options. The manual that you are reading right now is
derived from this output.

Take a look at the wiki for more information about PyCAM:
http://sourceforge.net/apps/mediawiki/pycam/

The website of the PyCAM project: http://pycam.sourceforge.net

