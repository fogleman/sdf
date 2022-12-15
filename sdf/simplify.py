import numpy as np
import subprocess
import os
import tempfile
import meshio
import shutil
from scipy import optimize

#def simplify(points, ratio=0.5, agressive=7):
#    prefile = tempfile.NamedTemporaryFile(suffix=".obj")
#    postfile = tempfile.NamedTemporaryFile(suffix=".obj")
#    print("Writing out {} for simplification.".format(prefile.name))
#    _mesh(points).write(prefile.name)
#    exe_path = os.path.dirname(os.path.realpath(__file__))
#    if os.name == 'nt':
#        subprocess.run([exe_path+"\simplify.exe",prefile.name,postfile.name,str(ratio),str(agressive)])
#    elif os.name == 'posix':
#        subprocess.run([exe_path+"/simplify",prefile.name,postfile.name,str(ratio),str(agressive)])
#    #os.remove(prefile.name)
#    #shutil.copyfile(prefile.name,"test1.obj")
#    if os.path.getsize(postfile.name) > 0:
#        #print("Reading {}".format(postfile.name))
#        out = meshio.read(postfile.name)
#        #print("out.points: {}".format(out.points))
#        #print("out.cells: {}".format(out.cells[0][1]))
#        points = out.points[out.cells[0][1].reshape(-1,1),:].reshape(-1,3)
#        #print("points: {}".format(points))
#    #os.remove(postfile.name)
#    #shutil.copyfile(postfile.name,"test2.obj")
#    prefile.close()
#    postfile.close()
#    return points
#
#def simplify_and_cut(sdf, points, ratio=0.5, agressive=7):
#    prefile = tempfile.NamedTemporaryFile(suffix=".obj")
#    postfile = tempfile.NamedTemporaryFile(suffix=".obj")
#    _mesh(points).write(prefile.name)
#    exe_path = os.path.dirname(os.path.realpath(__file__))
#    if os.name == 'nt':
#        subprocess.run([exe_path+"\simplify.exe",prefile.name,postfile.name,str(ratio),str(agressive)])
#    elif os.name == 'posix':
#        subprocess.run([exe_path+"/simplify",prefile.name,postfile.name,str(ratio),str(agressive)])
#    if os.path.getsize(postfile.name) > 0:
#        #print("Reading {}".format(postfile.name))
#        out = meshio.read(postfile.name)
#        tri_points = out.points[out.cells[0][1].reshape(-1,1),:].reshape(-1,3,3)
#
#        centroid = np.average(tri_points,axis=1)
#
#        normals = np.cross(tri_points[:,1] - tri_points[:,0], tri_points[:,2] - tri_points[:,0])
#        normals_len = np.linalg.norm(normals, axis=1).reshape((-1, 1))
#        normals /=  normals_len
#        normals_step = normals * 0.0025
#
#        d1 = sdf(centroid + normals_step).reshape((-1, 1))
#        d2 = sdf(centroid - normals_step).reshape((-1, 1))
#        d21 = np.abs(d2 - d1)
#        dp21 = np.abs(d2 + d1) / 2
#        #print("size d21", d21.shape)
#        #print("size normals {}".format(list(normals)))
#        valid = ((d21 > 0.0035) & (d21 < 0.0055) & (dp21 > 0.0025))[:,0]
#        #print("size valid {}".format(valid))
#        #t = normals[valid[:,0]]
#        #print("size normals t" , t.shape)
#        #print("size valid", valid.shape)
#        direction = np.where(np.abs(d1[valid]) < np.abs(d2[valid]), normals[valid], -normals[valid])
#        centroid = centroid[valid] + direction * dp21[valid] # * 0.005 / d21[valid]
#
#        points = []
#        points.append(tri_points[~valid])
#        points.append(np.transpose([tri_points[valid,1,:],tri_points[valid,0,:],centroid],[1,0,2]))
#        points.append(np.transpose([centroid,tri_points[valid,0],tri_points[valid,2]],[1,0,2]))
#        points.append(np.transpose([tri_points[valid,2],tri_points[valid,1],centroid],[1,0,2]))
#        points = np.concatenate(points).astype(np.float32).reshape((-1,3))
#    prefile.close()
#    postfile.close()
#    return points

def _mesh(points):
    points, cells = np.unique(points, axis=0, return_inverse=True)
    cells = [('triangle', cells.reshape((-1, 3)))]
    return meshio.Mesh(points, cells)

def simplify(sdf, points, simp_agressive=7, simp_ratio=0.5, simp_add_random=None, simp_smooth=False, simp_cut=False):
    prefile = tempfile.NamedTemporaryFile(suffix=".obj")
    postfile = tempfile.NamedTemporaryFile(suffix=".obj")
    prefile.close()
    postfile.close()
    _mesh(points).write(prefile.name)
    exe_path = os.path.dirname(os.path.realpath(__file__))
    print("Simplifying...")
    if os.name == 'nt':
        subprocess.run([exe_path+"\simplify.exe",prefile.name,postfile.name,str(simp_ratio),str(simp_agressive)])
    elif os.name == 'posix':
        subprocess.run([exe_path+"/simplify",prefile.name,postfile.name,str(simp_ratio),str(simp_agressive)])
    if os.path.getsize(postfile.name) > 0:
        #print("Reading {}".format(postfile.name))
        out = meshio.read(postfile.name)
        points = out.points
        cells = out.cells[0][1]

#        points_x = points + [[0.00125,0,0]]
#        points_y = points + [[0,0.00125,0]]
#        points_z = points + [[0,0,0.00125]]
#        d = sdf(points)
#        dx = sdf(points_x)
#        dy = sdf(points_y)
#        dz = sdf(points_z)
#        sx = (dx-d)/0.00125
#        sy = (dy-d)/0.00125
#        sz = (dz-d)/0.00125
#        points = out.points+d*np.transpose([sx[:,0],sy[:,0],sz[:,0]],[1,0])

        if simp_cut:
            print("Cutting...")
            tri_points = points[cells.reshape(-1,1),:].reshape(-1,3,3)

            centroid = np.average(tri_points,axis=1)

            normals = np.cross(tri_points[:,1] - tri_points[:,0], tri_points[:,2] - tri_points[:,0])
            normals_len = np.linalg.norm(normals, axis=1).reshape((-1, 1))
            normals /=  normals_len
            normals_step = normals * 0.00125

            d1 = sdf(centroid - normals_step).reshape((-1, 1))
            d2 = sdf(centroid + normals_step).reshape((-1, 1))
            d21 = np.abs(d2 - d1)
            dp21 = (d2 + d1) / 2
            valid = ((d21 > 0.0017) & (d21 < 0.0026))[:,0] #& (dp21 > 0.0025))[:,0]
            direction = normals[valid] * dp21[valid]

            left = (tri_points[:,2]+tri_points[:,0])/2
            right = (tri_points[:,1]+tri_points[:,0])/2
            top = (tri_points[:,1]+tri_points[:,2])/2
            #left[valid] += direction
            #right[valid] += direction
            #top[valid] += direction
            centroid[valid] -= direction
            #centroid = centroid[valid] + direction * dp21[valid] # * 0.005 / d21[valid]

            points = np.transpose([centroid,
                tri_points[:,0],
                right,
                tri_points[:,1],
                top,
                tri_points[:,2],
                left,
            ],[1,0,2]).astype(np.float32).reshape((-1,3))
            s = len(tri_points)*7
            cells = np.transpose([
                [range(0,s,7),range(1,s,7),range(2,s,7)],
                [range(0,s,7),range(2,s,7),range(3,s,7)],
                [range(0,s,7),range(3,s,7),range(4,s,7)],
                [range(0,s,7),range(4,s,7),range(5,s,7)],
                [range(0,s,7),range(5,s,7),range(6,s,7)],
                [range(0,s,7),range(6,s,7),range(1,s,7)],
            ],[2,0,1])
            points = points[cells.reshape(-1,1),:].reshape(-1,3).astype(np.float32)
            points, cells = np.unique(points, axis=0, return_inverse=True)

        if simp_add_random:
            print("Adding Random...")
            points += np.random.normal(scale=simp_add_random, size=((points.shape)))

        if simp_smooth:
            print("Smoothing...")
            d = sdf(points)
            for i in range(3):
               rpoints = points + np.random.normal(scale=0.00125, size=((points.shape)))
               d2 = sdf(rpoints)
               vec = np.abs(d) < np.abs(d2)
               points = np.where(vec, points, rpoints)
               d = np.where(vec, d, d2)
#            dx = sdf(points + [[0.00125,0,0]])
#            dy = sdf(points + [[0,0.00125,0]])
#            dz = sdf(points + [[0,0,0.00125]])
#            dmx = sdf(points - [[0.00125,0,0]])
#            dmy = sdf(points - [[0,0.00125,0]])
#            dmz = sdf(points - [[0,0,0.00125]])
#            print("Shifting...")
#            sx = (d-dx)[:,0]
#            sy = (d-dy)[:,0]
#            sz = (d-dz)[:,0]
#            smx = (dmx-d)[:,0]
#            smy = (dmy-d)[:,0]
#            smz = (dmz-d)[:,0]
#            points = points+d*_normalize(np.transpose([
#              np.where(np.abs(sx) > np.abs(smx), sx, smx),
#              np.where(np.abs(sy) > np.abs(smy), sy, smy),
#              np.where(np.abs(sz) > np.abs(smz), sz, smz),
#            ],[1,0]))
#            print("points", points.shape)
#            def fun(p):
#                #print("p", p.shape)
#                return sdf(p.reshape((-1,3))).repeat(3,1).flat
#            sol = optimize.root(fun, points, options={'eps':0.00125, 'maxfev':10})
#            points = sol.x.reshape(-1,3)

        points = points[cells.reshape(-1,1),:].reshape(-1,3)
    return points

def _normalize(a):
    return a / np.linalg.norm(a)
