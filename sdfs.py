import numpy as np

def checked(f):
    def wrapper(*args, **kwargs):
        return f(*args, **kwargs).reshape((-1, 1))
    return wrapper

def _length(a):
    return np.linalg.norm(a, axis=1)

def _dot(a, b):
    return np.sum(a * b, axis=1)

def sphere(center, radius):
    @checked
    def f(p):
        return _length(p - center) - radius
    return f

def box(size):
    @checked
    def f(p):
        q = np.abs(p) - size
        return _length(np.maximum(q, 0)) + np.minimum(np.amax(q, axis=1), 0)
    return f

def round_box(size, radius):
    size = np.array(size) / 2
    @checked
    def f(p):
        q = np.abs(p) - size
        return _length(np.maximum(q, 0)) + np.minimum(np.amax(q, axis=1), 0) - radius
    return f

def torus(center, r1, r2):
    @checked
    def f(p):
        xz = p[:,[0,2]]
        y = p[:,1]
        a = _length(xz) - r1
        b = _length(np.stack([a, y], axis=1)) - r2
        return b
    return f

def capsule(a, b, radius):
    a = np.array(a)
    b = np.array(b)
    @checked
    def f(p):
        pa = p - a
        ba = b - a
        h = np.clip(np.dot(pa, ba) / np.dot(ba, ba), 0, 1).reshape((-1, 1))
        return _length(pa - np.multiply(ba, h)) - radius
    return f

def capped_cylinder(a, b, radius):
    a = np.array(a)
    b = np.array(b)
    @checked
    def f(p):
        ba = b - a
        pa = p - a
        baba = np.dot(ba, ba)
        paba = np.dot(pa, ba).reshape((-1, 1))
        x = _length(pa * baba - ba * paba) - radius * baba
        y = np.abs(paba - baba * 0.5) - baba * 0.5
        x = x.reshape((-1, 1))
        y = y.reshape((-1, 1))
        x2 = x * x
        y2 = y * y * baba
        d = np.where(
            np.maximum(x, y) < 0,
            -np.minimum(x2, y2),
            np.where(x > 0, x2, 0) + np.where(y > 0, y2, 0))
        return np.sign(d) * np.sqrt(np.abs(d)) / baba
    return f

def ellipsoid(x, y, z):
    radius = np.array([x, y, z])
    @checked
    def f(p):
        k0 = _length(p / radius)
        k1 = _length(p / (radius * radius))
        return k0 * (k0 - 1) / k1
    return f

def union(a, *bs):
    @checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = np.minimum(d1, d2)
        return d1
    return f

def difference(a, *bs):
    @checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = np.maximum(d1, -d2)
        return d1
    return f

def intersection(a, *bs):
    @checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = np.maximum(d1, d2)
        return d1
    return f

def smooth_union(k, a, *bs):
    @checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            h = np.clip(0.5 + 0.5 * (d2 - d1) / k, 0, 1)
            m = d2 + (d1 - d2) * h
            d1 = m - k * h * (1 - h)
        return d1
    return f

def smooth_difference(k, a, *bs):
    @checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            h = np.clip(0.5 - 0.5 * (d2 + d1) / k, 0, 1)
            m = d1 + (-d2 - d1) * h
            d1 = m + k * h * (1 - h)
        return d1
    return f

def smooth_intersection(k, a, *bs):
    @checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            h = np.clip(0.5 - 0.5 * (d2 - d1) / k, 0, 1)
            m = d2 + (d1 - d2) * h
            d1 = m + k * h * (1 - h)
        return d1
    return f

def translate(offset, sdf):
    @checked
    def f(p):
        return sdf(p - offset)
    return f
