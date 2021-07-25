import numpy as np
import subprocess
import os
import sys
import tempfile
import shutil
import sdf

def pycam(settings_file, points):
    prefile = tempfile.NamedTemporaryFile(suffix=".stl")
    prefile.close()
    sdf.save_mesh(prefile.name, points)
    exe_path = os.path.dirname(os.path.realpath(__file__))
    if os.name == 'nt':
        print("Calling pycam: ", settings_file)
        #print([exe_path+"/../slic3r/linux/Slic3r"] + opt)
        #DIR=exe_path+"/../pycam/pycam"
        DIR=exe_path+"\\..\\pycam\\pycam"
        my_env = os.environ.copy()
        my_env["PYTHONPATH"] = DIR
        #subprocess.run(["PYTHONPATH="+DIR, DIR+"/run_cli.py", "--log-level", "info", settings_file])
        subprocess.run([sys.executable, DIR+"\\run_cli.py", "--log-level", "info", settings_file], env=my_env)
    elif os.name == 'posix':
        print("Calling pycam: ", settings_file)
        #print([exe_path+"/../slic3r/linux/Slic3r"] + opt)
        DIR=exe_path+"/../pycam/pycam"
        my_env = os.environ.copy()
        my_env["PYTHONPATH"] = DIR
        #subprocess.run(["PYTHONPATH="+DIR, DIR+"/run_cli.py", "--log-level", "info", settings_file])
        subprocess.run([DIR+"/run_cli.py", "--log-level", "info", settings_file], env=my_env)
