Using PyCAM via the command-line
================================

**WARNING: this page is outdated. Please refer to the output of
“pycam --help” or [browse it online](/manpages/pycam.1.html).**

The following examples show some command use-cases for the
non-interactive generation of GCode with PyCAM:

-   load a specific settings file for the GUI:

<!-- -->

    pycam --config SOME_CONFIG_FILE

-   open a model:

<!-- -->

    pycam SOME_MODEL_FILE

-   generate a GCode file using all default tasks (taken from the
    default settings):

<!-- -->

    pycam SOME_MODEL_FILE DESTINATION_GCODE_FILE

-   generate a GCode file using a custom settings file and picking just
    one specific task:

<!-- -->

    pycam --config YOUR_SETTINGS_FILE --task 2 SOME_MODEL_FILE DESTINATION_GCODE_FILE
