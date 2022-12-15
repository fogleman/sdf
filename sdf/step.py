import numpy as np
import struct
import getpass
import struct
from datetime import datetime

edge_curve = {}

def _make_edge_curve(i,a,b,fp,v0,v1,s01):
    a_str = struct.pack('<fff',a[0],a[1],a[2])
    b_str = struct.pack('<fff',b[0],b[1],b[2])
    f_val = a_str+b_str
    r_val = b_str+a_str
    if f_val in edge_curve:
        n = edge_curve[f_val]
        ec_dir = ".T."
    elif r_val in edge_curve:
        n = edge_curve[r_val]
        ec_dir = ".F."
    else:
        fp.write("#{} = EDGE_CURVE('', #{}, #{}, #{},.T.);\n".format(i,v0,v1,s01)); n=i; i+=1
        edge_curve[f_val] = n
        ec_dir = ".T."
    return i, n, ec_dir


def write_step(path, points, tol=0):
    n = len(points) // 3

    points = np.array(points, dtype='float32').reshape((-1, 3, 3))
    normals = np.cross(points[:,1] - points[:,0], points[:,2] - points[:,0])
    normals_len = np.linalg.norm(normals, axis=1).reshape((-1, 1))
    normals /= normals_len

    vec01 = points[:,1] - points[:,0]
    vec01_len = np.linalg.norm(vec01, axis=1).reshape((-1, 1))
    vec01 /= vec01_len

    vec12 = points[:,2] - points[:,1]
    vec12_len = np.linalg.norm(vec12, axis=1).reshape((-1, 1))
    vec12 /= vec12_len

    vec20 = points[:,0] - points[:,2]
    vec20_len= np.linalg.norm(vec20, axis=1).reshape((-1, 1))
    vec20 /= vec20_len

    OPEN_SHELL = []

    with open(path, 'w') as fp:
        fp.write("ISO-10303-21;\n")
        fp.write("HEADER;\n")
        fp.write("FILE_DESCRIPTION(('STP203'),'2;1');\n")
        fp.write("FILE_NAME('{}','{}',('{}'),('PythonSDF'),' ','pschou/py-sdf',' ');\n".format(path,datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),getpass.getuser()))
        fp.write("FILE_SCHEMA(('CONFIG_CONTROL_DESIGN'));\n")
        fp.write("ENDSEC;\n")
        fp.write("DATA;\n")
        fp.write("#1 = CARTESIAN_POINT('', (0,0,0));\n")
        fp.write("#2 = DIRECTION('', (0, 0, 1));\n")
        fp.write("#3 = DIRECTION('', (1, 0, 0));\n")
        fp.write("#4 = AXIS2_PLACEMENT_3D('',#1,#2,#3);\n")

        i = 5

        for j in range(n):
            if any([vec01_len[j] < tol, vec12_len[j] < tol, vec20_len[j] < tol, normals_len[j] < tol]):
                continue
            #fp.write("#{} ".format(i))
            fp.write("#{} = CARTESIAN_POINT('', ({},{},{}));\n".format(i,points[j,0,0],points[j,0,1],points[j,0,2])); p0=i;i+=1
            fp.write("#{} = VERTEX_POINT('', #{});\n".format(i,p0)); v0=i;i+=1
            fp.write("#{} = CARTESIAN_POINT('', ({},{},{}));\n".format(i,points[j,1,0],points[j,1,1],points[j,1,2])); p1=i;i+=1
            fp.write("#{} = VERTEX_POINT('', #{});\n".format(i,p1)); v1=i;i+=1
            fp.write("#{} = CARTESIAN_POINT('', ({},{},{}));\n".format(i,points[j,2,0],points[j,2,1],points[j,2,2])); p2=i;i+=1
            fp.write("#{} = VERTEX_POINT('', #{});\n".format(i,p2)); v2=i;i+=1
            #fp.write("#{} = CARTESIAN_POINT('', ({},{},{}));\n".format(i,points[j,0,0],points[j,0,1],points[j,0,2])); i+=1
            #fp.write("#{} = DIRECTION('', ({}, {}, {}));\n".format(i, normals[j,0],normals[j,1],normals[j,2]); i+=1

            fp.write("#{} = DIRECTION('', ({}, {}, {}));\n".format(i, vec01[j,0],vec01[j,1],vec01[j,2])); d01=i; i+=1
            fp.write("#{} = VECTOR('',#{},1);\n".format(i,d01)); v01=i; i+=1
            fp.write("#{} = LINE('',#{}, #{});\n".format(i,p0,v01)); L01=i; i+=1
            fp.write("#{} = SURFACE_CURVE('', #{});\n".format(i,L01)); s01=i; i+=1
            i, ec01, ec_dir01 = _make_edge_curve(i,points[j,0,:],points[j,1,:],fp,v0,v1,s01)

            fp.write("#{} = DIRECTION('', ({}, {}, {}));\n".format(i, vec12[j,0],vec12[j,1],vec12[j,2])); d12=i; i+=1
            fp.write("#{} = VECTOR('',#{},1);\n".format(i,d12)); v12=i; i+=1
            fp.write("#{} = LINE('',#{}, #{});\n".format(i,p1,v12)); L12=i; i+=1
            fp.write("#{} = SURFACE_CURVE('', #{});\n".format(i,L12)); s12=i; i+=1
            #fp.write("#{} = EDGE_CURVE('', #{}, #{}, #{},.T.);\n".format(i,v1,v2,s12)); ec12=i; i+=1
            i, ec12, ec_dir12 = _make_edge_curve(i,points[j,1,:],points[j,2,:],fp,v1,v2,s12)

            fp.write("#{} = DIRECTION('', ({}, {}, {}));\n".format(i, vec20[j,0],vec20[j,1],vec20[j,2])); d20=i; i+=1
            fp.write("#{} = VECTOR('',#{},1);\n".format(i,d20)); v20=i; i+=1
            fp.write("#{} = LINE('',#{}, #{});\n".format(i,p2,v20)); L20=i; i+=1
            fp.write("#{} = SURFACE_CURVE('', #{});\n".format(i,L20)); s20=i; i+=1
            #fp.write("#{} = EDGE_CURVE('', #{}, #{}, #{},.T.);\n".format(i,v2,v0,s20)); ec20=i; i+=1
            i, ec20, ec_dir20 = _make_edge_curve(i,points[j,2,:],points[j,0,:],fp,v2,v0,s20)

            fp.write("#{} = ORIENTED_EDGE('',*,*,#{},{});\n".format(i,ec01,ec_dir01)); oe01=i; i+=1
            fp.write("#{} = ORIENTED_EDGE('',*,*,#{},{});\n".format(i,ec12,ec_dir12)); oe12=i; i+=1
            fp.write("#{} = ORIENTED_EDGE('',*,*,#{},{});\n".format(i,ec20,ec_dir20)); oe20=i; i+=1

            fp.write("#{} = DIRECTION('', ({}, {}, {}));\n".format(i, normals[j,0],normals[j,1],normals[j,2])); n=i; i+=1
            fp.write("#{} = AXIS2_PLACEMENT_3D('',#{},#{},#{});\n".format(i,p0,n,d01)); ap=i; i+=1
            fp.write("#{} = PLANE('',#{});\n".format(i,ap)); plane=i; i+=1
            fp.write("#{} = EDGE_LOOP('', (#{},#{},#{}));\n".format(i,oe01,oe12,oe20)); eL=i; i+=1
            fp.write("#{} = FACE_BOUND('', #{},.T.);\n".format(i,eL)); fb=i; i+=1
            fp.write("#{} = ADVANCED_FACE('', (#{}),#{},.T.);\n".format(i,fb,plane)); OPEN_SHELL.append(i); i+=1

        fp.write("#{} = OPEN_SHELL('',(#{}));\n".format(i,",#".join([str(i) for i in OPEN_SHELL]))); osh=i; i+=1
        fp.write("#{} = SHELL_BASED_SURFACE_MODEL('', (#{}));\n".format(i,osh)); sm=i; i+=1
        fp.write("#{} = MANIFOLD_SURFACE_SHAPE_REPRESENTATION('', (#4, #{}));\n".format(i,sm)); i+=1
        fp.write("ENDSEC;\n")
        fp.write("END-ISO-10303-21;\n")
