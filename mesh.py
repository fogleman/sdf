from multiprocessing.pool import ThreadPool
from skimage import measure
import multiprocessing
import itertools
import numpy as np

NUM_WORKERS = multiprocessing.cpu_count()
BATCH_SIZE = 48

def _marching_cubes(volume, level=0):
    verts, faces, _, _ = measure.marching_cubes(volume, level)
    return verts[faces].reshape((-1, 3))

def _cartesian_product(*arrays):
    la = len(arrays)
    dtype = np.result_type(*arrays)
    arr = np.empty([len(a) for a in arrays] + [la], dtype=dtype)
    for i, a in enumerate(np.ix_(*arrays)):
        arr[...,i] = a
    return arr.reshape(-1, la)

def _worker(job):
    sdf, X, Y, Z = job
    P = _cartesian_product(X, Y, Z)
    volume = sdf(P).reshape((len(X), len(Y), len(Z)))
    try:
        points = _marching_cubes(volume)
    except ValueError:
        return []
    scale = np.array([X[1] - X[0], Y[1] - Y[0], Z[1] - Z[0]])
    offset = np.array([X[0], Y[0], Z[0]])
    return points * scale + offset

def generate(
        sdf, x0, y0, z0, x1, y1, z1, dx, dy, dz,
        num_workers=NUM_WORKERS, batch_size=BATCH_SIZE):
    s = batch_size
    X = np.arange(x0, x1, dx)
    Y = np.arange(y0, y1, dy)
    Z = np.arange(z0, z1, dz)
    Xs = [X[i:i+s+1] for i in range(0, len(X), s)]
    Ys = [Y[i:i+s+1] for i in range(0, len(Y), s)]
    Zs = [Z[i:i+s+1] for i in range(0, len(Z), s)]
    print(len(Xs) * len(Ys) * len(Zs), 'batches')
    pool = ThreadPool(num_workers)
    results = pool.map(_worker, itertools.product([sdf], Xs, Ys, Zs))
    points = [p for r in results for p in r]
    return points
