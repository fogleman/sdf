import numpy as np
import struct
import subprocess

def write_binary_stl(path, points):
    n = len(points) // 3

    points = np.array(points, dtype='float32').reshape((-1, 3, 3))
    normals = np.cross(points[:,1] - points[:,0], points[:,2] - points[:,0])
    normals /= np.linalg.norm(normals, axis=1).reshape((-1, 1))

    dtype = np.dtype([
        ('normal', ('<f', 3)),
        ('points', ('<f', (3, 3))),
        ('attr', '<H'),
    ])

    a = np.zeros(n, dtype=dtype)
    a['points'] = points
    a['normal'] = normals

    with open(path, 'wb') as fp:
        fp.write(b'\x00' * 80)
        fp.write(struct.pack('<I', n))
        fp.write(a.tobytes())

def read_binary_stl(path):
    with open(path, 'rb') as fp:
        fp.seek(80)
        n = struct.unpack("<I",fp.read(4))
        points = np.zeros((n[0],9))
        for i in range(n[0]):
            points[i,:] = struct.unpack_from('<12xfffffffffxx', fp.read(50))
        return points.reshape((-1,3))

