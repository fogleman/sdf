Dive into PyCAM
===============

The following guide tries to push you as quickly as possible through the
process of milling your first model based on a toolpath made with PyCAM.
All the gory details will be missing - but at least you will know the
basics.


Prepare a GCode file with PyCAM
-------------------------------

1. Load a model: Open an STL file of your choice OR just continue with PyCAM's default model (a box with text elevated on top)

2. Fix the dimensions of the model: Rotate, mirror and scale the model until its dimensions are fine for you. In a perfect world you would do this with your 3D modeler - but in case of emergency this can also be done with PyCAM.

3. Position the model: Many people adjust the top of their model to _z=0_. This makes it quite easy to touch-off (calibrate _z_) the tip of the tool at the top of your material.

4. Define the bounding box: This part is a bit tricky and depends on your approach of clamping the base material to the milling machine. Basically the bounding box describes the shape of the available material.

5. Define a first task: The first milling task will usually remove big amounts of material without caring too much for a high surface quality. Choose a big tool and configure a *slice removal* process with a minimum overlap. This process will remove a lot of material with as few moves as possible.

6. Define more granular tasks: Now you are ready for a smaller tool and the *surface* strategy with a high overlap (e.g. 60%). This will give you quite a good surface quality.

7. Generate the toolpath for both tasks: This can take some minutes.

8. Configure GCode details: The most important GCode setting is the safety height. This defines the z-level at which the machine (including the tool) is free to move without any obstacles. The default is slightly above zero. You absolutely need to make sure that the safety height is always clearly above the level of the top of your material. You will see all changes reflected in the 3D preview immediately.

9. Write GCode: Now you can export both toolpaths to a file. This GCode file can be imported by your machine controller software (e.g. [LinuxCNC](http://www.linuxcnc.org/)) - see below.

Run the GCode file
------------------

*The following part is not done with PyCAM - but this section may help
you anyway to understand the process.*

Machine controller software like LinuxCNC can import the GCode file. Now
you just need to following a few final steps:

-   turn on the machine
-   *home* its coordinate system (via your stop-switches)
-   fixiate your material block to the milling bed
-   Move the tip of the tool to the the origin of your coordinate system
    (x=0, y=0, z=0) for the simplest kind of touch-off.
-   Run the GCode.
-   Your machine controller software will pause before starting the
    second tasks only if you created separate tools of both tasks in
    PyCAM.

The final result of this milling operation should be very similar to
your original model. Increase overlap and experiment with other
parameters if you need to improve its quality. At this moment will you
understand the importance of the fixiation - especially if you isolated
a part of the model form the fixiated part. You can always use *support
bridges* (in PyCAM) to overcome this problem.

Let's go, start up pycam!
=========================

*written by <User:svenhee> - incomplete*

**(Screenshots will follow)** After we start up PyCAM we see the
pycam-textbox in the visualisation window. You can actually go and
prepare to mill this if you want but we will open up our own file. All
the work will be done in the other window which opens up in the “model”
tab. In the “model” tab, click file&gt; open model and find and open the
stl file you want to work on. In this guide we will use a file for a 2
piece mould.

After opening this file it is in a position that can not be used for
milling. We will transform the model to position it correctly. The way
in which it apears depends on how it was made, you may not need to
change its position.

-   Choose x&lt;-&gt;z, then click swap. The model is recalculated.
-   Then choose y&lt;-&gt; and click swap. After recalculating the model
    is in the right position to be milled but upside down.
-   Choose x-y plane and then click flip. After recalculating the model
    is set correctly for milling.
-   If you need to rotate the model, click rotate after selecting the
    axis you want to rotate. Each click will rotate 90 degrees
    clockwise.

The model is recalculated. We will now save this model under a new name
(file&gt;save model as), this way we can open the model again later in
the position it is now.

Because this is a trial we do not want to mill this mould full size.
That would take a lot more time an material where a smaller model would
give us a lot of experience too.

Under “Model dimension” choose a factor (we use 30% here) and click
scale model.

The model now is no longer starting at Origin. To put it back, click To
origin.

If you leave the model as it is now, the g-code will include rapid moves
inside the model. Bring the top of the model down by entering the height
of the model (after rescaling) in “move model”, in this case 50x0.30= 15
millimeters, add - so use -15 in direction z, then click shift.
