from multiprocessing.pool import ThreadPool
from skimage import measure

import multiprocessing
import itertools
import numpy as np
import time

from .stl import write_binary_stl

WORKERS = multiprocessing.cpu_count()
SAMPLES = 2 ** 22
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

def _estimate_bounds(sdf):
    s = 16
    x0 = y0 = z0 = -1e9
    x1 = y1 = z1 = 1e9
    prev = None
    for i in range(32):
        X = np.linspace(x0, x1, s)
        Y = np.linspace(y0, y1, s)
        Z = np.linspace(z0, z1, s)
        d = np.array([X[1] - X[0], Y[1] - Y[0], Z[1] - Z[0]])
        threshold = np.linalg.norm(d) / 2
        if threshold == prev:
            break
        prev = threshold
        P = _cartesian_product(X, Y, Z)
        volume = sdf(P).reshape((len(X), len(Y), len(Z)))
        where = np.argwhere(volume <= threshold)
        x1, y1, z1 = (x0, y0, z0) + where.max(axis=0) * d + d / 2
        x0, y0, z0 = (x0, y0, z0) + where.min(axis=0) * d - d / 2
    return ((x0, y0, z0), (x1, y1, z1))

def generate(
        sdf,
        step=None, bounds=None, samples=SAMPLES,
        workers=WORKERS, batch_size=BATCH_SIZE,
        verbose=False):

    start = time.time()

    if bounds is None:
        bounds = _estimate_bounds(sdf)
    (x0, y0, z0), (x1, y1, z1) = bounds

    if step is None and samples is not None:
        volume = (x1 - x0) * (y1 - y0) * (z1 - z0)
        step = (volume / samples) ** (1 / 3)

    try:
        dx, dy, dz = step
    except TypeError:
        dx = dy = dz = step

    if verbose:
        print('min %g, %g, %g' % (x0, y0, z0))
        print('max %g, %g, %g' % (x1, y1, z1))
        print('step %g, %g, %g' % (dx, dy, dz))

    X = np.arange(x0, x1, dx)
    Y = np.arange(y0, y1, dy)
    Z = np.arange(z0, z1, dz)

    s = batch_size
    Xs = [X[i:i+s+1] for i in range(0, len(X), s)]
    Ys = [Y[i:i+s+1] for i in range(0, len(Y), s)]
    Zs = [Z[i:i+s+1] for i in range(0, len(Z), s)]

    if verbose:
        num_batches = len(Xs) * len(Ys) * len(Zs)
        num_samples = num_batches * BATCH_SIZE ** 3
        print('%d samples in %d batches with %d workers' %
            (num_samples, num_batches, workers))

    pool = ThreadPool(workers)
    results = pool.map(_worker, itertools.product([sdf], Xs, Ys, Zs))
    points = [p for r in results for p in r]

    if verbose:
        triangles = len(points) // 3
        seconds = time.time() - start
        print('%d triangles in %g seconds' % (triangles, seconds))

    return points

def save(path, *args, **kwargs):
    points = generate(*args, **kwargs)
    write_binary_stl(path, points)
