import numpy as np
import struct

def write_binary_stl(path, points):
    n = len(points) // 3
    dtype = np.dtype([
        ('normal', ('<f', 3)),
        ('points', ('<f', 9)),
        ('attr', '<H'),
    ])
    a = np.zeros(n, dtype=dtype)
    a['points'] = np.array(points, dtype='float32').reshape((-1, 9))
    with open(path, 'wb') as fp:
        fp.write(b'\x00' * 80)
        fp.write(struct.pack('<I', n))
        fp.write(a.tobytes())
