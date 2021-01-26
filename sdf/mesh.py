from functools import partial
from multiprocessing.pool import ThreadPool
from skimage import measure

import multiprocessing
import itertools
import numpy as np
import time

from . import progress, stl

WORKERS = multiprocessing.cpu_count()
SAMPLES = 2 ** 22
BATCH_SIZE = 32

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

def _skip(sdf, job):
    X, Y, Z = job
    x0, x1 = X[0], X[-1]
    y0, y1 = Y[0], Y[-1]
    z0, z1 = Z[0], Z[-1]
    x = (x0 + x1) / 2
    y = (y0 + y1) / 2
    z = (z0 + z1) / 2
    r = abs(sdf(np.array([(x, y, z)])).reshape(-1)[0])
    d = np.linalg.norm(np.array((x-x0, y-y0, z-z0)))
    return r > d

def _worker(sdf, job, force):
    X, Y, Z = job
    if not force and _skip(sdf, job):
        return None
        # return _debug_triangles(X, Y, Z)
    P = _cartesian_product(X, Y, Z)
    volume = sdf(P).reshape((len(X), len(Y), len(Z)))
    try:
        points = _marching_cubes(volume)
    except Exception:
        return []
        # return _debug_triangles(X, Y, Z)
    scale = np.array([X[1] - X[0], Y[1] - Y[0], Z[1] - Z[0]])
    offset = np.array([X[0], Y[0], Z[0]])
    return points * scale + offset

def _estimate_bounds(sdf):
    # TODO: raise exception if bound estimation fails
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
        where = np.argwhere(np.abs(volume) <= threshold)
        x1, y1, z1 = (x0, y0, z0) + where.max(axis=0) * d + d / 2
        x0, y0, z0 = (x0, y0, z0) + where.min(axis=0) * d - d / 2
    return ((x0, y0, z0), (x1, y1, z1))

def generate(
        sdf,
        step=None, bounds=None, samples=SAMPLES,
        workers=WORKERS, batch_size=BATCH_SIZE,
        verbose=False, force=False):

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

    batches = list(itertools.product(Xs, Ys, Zs))
    num_batches = len(batches)
    num_samples = sum(len(xs) * len(ys) * len(zs)
        for xs, ys, zs in batches)

    if verbose:
        print('%d samples in %d batches with %d workers' %
            (num_samples, num_batches, workers))

    points = []
    skipped = empty = nonempty = 0
    bar = progress.Bar(num_batches, enabled=verbose)
    pool = ThreadPool(workers)
    f = partial(_worker, sdf, force=force)
    for result in pool.imap(f, batches):
        bar.increment(1)
        if result is None:
            skipped += 1
        elif len(result) == 0:
            empty += 1
        else:
            nonempty += 1
            points.extend(result)
    bar.done()

    if verbose:
        print('%d skipped, %d empty, %d nonempty' % (skipped, empty, nonempty))
        triangles = len(points) // 3
        seconds = time.time() - start
        print('%d triangles in %g seconds' % (triangles, seconds))

    return points

def save(path, *args, **kwargs):
    points = generate(*args, **kwargs)
    stl.write_binary_stl(path, points)

def _debug_triangles(X, Y, Z):
    x0, x1 = X[0], X[-1]
    y0, y1 = Y[0], Y[-1]
    z0, z1 = Z[0], Z[-1]

    p = 0.25
    x0, x1 = x0 + (x1 - x0) * p, x1 - (x1 - x0) * p
    y0, y1 = y0 + (y1 - y0) * p, y1 - (y1 - y0) * p
    z0, z1 = z0 + (z1 - z0) * p, z1 - (z1 - z0) * p

    v = [
        (x0, y0, z0),
        (x0, y0, z1),
        (x0, y1, z0),
        (x0, y1, z1),
        (x1, y0, z0),
        (x1, y0, z1),
        (x1, y1, z0),
        (x1, y1, z1),
    ]

    return [
        v[3], v[5], v[7],
        v[5], v[3], v[1],
        v[0], v[6], v[4],
        v[6], v[0], v[2],
        v[0], v[5], v[1],
        v[5], v[0], v[4],
        v[5], v[6], v[7],
        v[6], v[5], v[4],
        v[6], v[3], v[7],
        v[3], v[6], v[2],
        v[0], v[3], v[2],
        v[3], v[0], v[1],
    ]
