import numpy as np
import subprocess
import os
import tempfile
import meshio
import shutil

def simplify(points, ratio=0.5, agressive=7):
    fd, prefile= tempfile.mkstemp(suffix=".obj")
    fd, postfile = tempfile.mkstemp(suffix=".obj")
    print("Writing out {}".format(prefile))
    _mesh(points).write(prefile)
    exe_path = os.path.dirname(os.path.realpath(__file__))
    if os.name == 'nt':
        subprocess.run([exe_path+"\simplify.exe",prefile,postfile,str(ratio),str(agressive)])
    elif os.name == 'posix':
        subprocess.run([exe_path+"/simplify",prefile,postfile,str(ratio),str(agressive)])
    #os.remove(prefile)
    shutil.copyfile(prefile,"test1.obj")
    if os.path.getsize(postfile) > 0:
        #print("Reading {}".format(postfile))
        out = meshio.read(postfile)
        #print("out.points: {}".format(out.points))
        #print("out.cells: {}".format(out.cells[0][1]))
        points = out.points[out.cells[0][1].reshape(-1,1),:].reshape(-1,3)
        #print("points: {}".format(points))
    #os.remove(postfile)
    shutil.copyfile(postfile,"test2.obj")
    return points

def _mesh(points):
    points, cells = np.unique(points, axis=0, return_inverse=True)
    cells = [('triangle', cells.reshape((-1, 3)))]
    return meshio.Mesh(points, cells)

