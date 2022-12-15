import numpy as np
import subprocess
import os
import tempfile
import shutil
import sdf

def slic3r(path, points, options={}):
    prefile = tempfile.NamedTemporaryFile(suffix=".stl")
    prefile.close()
    sdf.save_mesh(prefile.name, points)
    exe_path = os.path.dirname(os.path.realpath(__file__))
    if os.name == 'nt':
        opt = []
        if "output" not in options:
            options["output"] = path
        for k in options:
            opt += ["--"+k,str(options[k])]
        print("Calling slic3r:", opt)
        #print([exe_path+"/../slic3r/linux/Slic3r"] + opt)
        DIR=exe_path+"\..\slic3r\win"
        #os.environ["LD_LIBRARY_PATH"] = DIR+"/bin"
        subprocess.run([DIR+"\Slic3r-console.exe"]+opt+[prefile.name])
        #os.environ["LD_LIBRARY_PATH"] = DIR+"/bin"
        #subprocess.run([DIR+"/perl-local", "-I"+DIR+"/local-lib/lib/perl5", DIR+"/slic3r.pl"]+opt+[prefile.name])
        #subprocess.run([DIR+"/Slic3r-console.exe", "-I"+DIR+"/local-lib/lib/perl5", DIR+"/slic3r.pl"]+opt+[prefile.name])
    elif os.name == 'posix':
        opt = []
        if "output" not in options:
            options["output"] = path
        for k in options:
            opt += ["--"+k,str(options[k])]
        print("Calling slic3r:", opt)
        #print([exe_path+"/../slic3r/linux/Slic3r"] + opt)
        DIR=exe_path+"/../slic3r/linux"
        os.environ["LD_LIBRARY_PATH"] = DIR+"/bin"
        subprocess.run([DIR+"/perl-local", "-I"+DIR+"/local-lib/lib/perl5", DIR+"/slic3r.pl"]+opt+[prefile.name])
