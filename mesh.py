from multiprocessing.pool import ThreadPool
from skimage import measure
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

def marching_cubes(volume, level=0):
    verts, faces, _, _ = measure.marching_cubes(volume, level)
    return verts[faces].reshape((-1, 3))

def cartesian_product(*arrays):
    la = len(arrays)
    dtype = np.result_type(*arrays)
    arr = np.empty([len(a) for a in arrays] + [la], dtype=dtype)
    for i, a in enumerate(np.ix_(*arrays)):
        arr[...,i] = a
    return arr.reshape(-1, la)

def sample(sdf, x0, y0, z0, x1, y1, z1, dx, dy, dz):
    print('generating points')
    X = np.arange(x0, x1, dx, dtype='float32')
    Y = np.arange(y0, y1, dy, dtype='float32')
    Z = np.arange(z0, z1, dz, dtype='float32')
    P = cartesian_product(X, Y, Z)
    print(len(P))
    print('sampling sdf')
    wn = 8
    pool = ThreadPool(wn)
    arrays = [P[i::wn] for i in range(wn)]
    results = pool.map(sdf, arrays)
    a = np.dstack(results).reshape(len(P))
    return a.reshape((len(X), len(Y), len(Z)))

def length(a):
    return np.linalg.norm(a, axis=1)

def dot(a, b):
    return np.sum(a * b, axis=1)

def sphere(center, radius):
    def f(p):
        return length(p - center) - radius
    return f

def box(size):
    def f(p):
        q = np.abs(p) - size
        return length(np.maximum(q, 0)) + np.minimum(np.amax(q, axis=1), 0)
    return f

def round_box(size, radius):
    def f(p):
        q = np.abs(p) - size
        return length(np.maximum(q, 0)) + np.minimum(np.amax(q, axis=1), 0) - radius
    return f

def torus(center, r1, r2):
    def f(p):
        xz = p[:,[0,2]]
        y = p[:,1]
        a = length(xz) - r1
        b = length(np.stack([a, y], axis=1)) - r2
        return b
    return f

def capsule(a, b, radius):
    a = np.array(a)
    b = np.array(b)
    def f(p):
        pa = p - a
        ba = b - a
        h = np.clip(np.dot(pa, ba) / np.dot(ba, ba), 0, 1).reshape((-1, 1))
        return length(pa - np.multiply(ba, h)) - radius
    return f

def ellipsoid(x, y, z):
    radius = np.array([x, y, z])
    def f(p):
        k0 = length(p / radius)
        k1 = length(p / (radius * radius))
        return k0 * (k0 - 1) / k1
    return f

def union(a, b):
    def f(p):
        d1 = a(p)
        d2 = b(p)
        return np.minimum(d1, d2)
    return f

def difference(a, *bs):
    def f(p):
        d = a(p)
        for b in bs:
            d = np.maximum(d, -b(p))
        return d
    return f

def intersection(a, b):
    def f(p):
        d1 = a(p)
        d2 = b(p)
        return np.maximum(d1, d2)
    return f

def smooth_union(a, b, k):
    def f(p):
        d1 = a(p)
        d2 = b(p)
        h = np.clip(0.5 + 0.5 * (d2 - d1) / k, 0, 1)
        m = d2 + (d1 - d2) * h
        return m - k * h * (1 - h)
    return f

def smooth_difference(a, b, k):
    def f(p):
        d1 = a(p)
        d2 = b(p)
        h = np.clip(0.5 - 0.5 * (d2 + d1) / k, 0, 1)
        m = d1 + (-d2 - d1) * h
        return m + k * h * (1 - h)
    return f

def smooth_intersection(a, b, k):
    def f(p):
        d1 = a(p)
        d2 = b(p)
        h = np.clip(0.5 - 0.5 * (d2 - d1) / k, 0, 1)
        m = d2 + (d1 - d2) * h
        return m + k * h * (1 - h)
    return f

def run(path, sdf):
    step = 0.01
    s = 1.3
    volume = sample(sdf, -s, -s, -s, s, s, s, step, step, step)
    print('running marching cubes')
    points = marching_cubes(volume)
    print('writing output')
    write_binary_stl('out.stl', points)

def main():
    sdf = difference(
        intersection(box(1), sphere((0, 0, 0), 1.25)),
        capsule((-2, 0, 0), (2, 0, 0), 0.5),
        capsule((0, -2, 0), (0, 2, 0), 0.5),
        capsule((0, 0, -2), (0, 0, 2), 0.5),
    )
    run('out.stl', sdf)

if __name__ == '__main__':
    main()
