import functools
import numpy as np
import operator

from .sdf import sdf, registered_sdf

# Constants

ORIGIN = np.array((0, 0, 0))

X = np.array((1, 0, 0))
Y = np.array((0, 1, 0))
Z = np.array((0, 0, 1))

UP = Z

# Helpers

def _length(a):
    return np.linalg.norm(a, axis=1)

def _normalize(a):
    return a / np.linalg.norm(a)

def _dot(a, b):
    return np.sum(a * b, axis=1)

def _vec(*arrs):
    return np.stack(arrs, axis=-1)

def _perpendicular(v):
    if v[1] == 0 and v[2] == 0:
        if v[0] == 0:
            raise ValueError('zero vector')
        else:
            return np.cross(v, [0, 1, 0])
    return np.cross(v, [1, 0, 0])

_min = np.minimum
_max = np.maximum

# Primitives

@sdf
def sphere(radius=1, center=ORIGIN):
    def f(p):
        return _length(p - center) - radius
    return f

@sdf
def plane(normal=UP, point=ORIGIN):
    normal = _normalize(normal)
    def f(p):
        return np.dot(point - p, normal)
    return f

@sdf
def slab(x0=None, y0=None, z0=None, x1=None, y1=None, z1=None):
    fs = []
    if x0 is not None:
        fs.append(plane(X, (x0, 0, 0)))
    if x1 is not None:
        fs.append(plane(-X, (x1, 0, 0)))
    if y0 is not None:
        fs.append(plane(Y, (0, y0, 0)))
    if y1 is not None:
        fs.append(plane(-Y, (0, y1, 0)))
    if z0 is not None:
        fs.append(plane(Z, (0, 0, z0)))
    if z1 is not None:
        fs.append(plane(-Z, (0, 0, z1)))
    return functools.reduce(operator.and_, fs)

@sdf
def box(size=1, center=ORIGIN):
    size = np.array(size) / 2
    def f(p):
        q = np.abs(p - center) - size
        return _length(_max(q, 0)) + _min(np.amax(q, axis=1), 0)
    return f

@sdf
def aabb(a, b):
    a = np.array(a)
    b = np.array(b)
    size = b - a
    offset = a + size / 2
    return box(size).translate(offset)

@sdf
def rounded_box(size, radius):
    size = np.array(size) / 2 - radius
    def f(p):
        q = np.abs(p) - size
        return _length(_max(q, 0)) + _min(np.amax(q, axis=1), 0) - radius
    return f

@sdf
def bounding_box(b, e):
    def g(a, b, c):
        return _length(_max(_vec(a, b, c), 0)) + _min(_max(a, _max(b, c)), 0)
    def f(p):
        p = np.abs(p) - b
        q = np.abs(p + e) - e
        px, py, pz = p[:,0], p[:,1], p[:,2]
        qx, qy, qz = q[:,0], q[:,1], q[:,2]
        return _min(_min(g(px, qy, qz), g(qx, py, qz)), g(qx, qy, pz))
    return f

@sdf
def torus(r1, r2):
    def f(p):
        xy = p[:,[0,1]]
        z = p[:,2]
        a = _length(xy) - r1
        b = _length(_vec(a, z)) - r2
        return b
    return f

@sdf
def capsule(a, b, radius):
    a = np.array(a)
    b = np.array(b)
    def f(p):
        pa = p - a
        ba = b - a
        h = np.clip(np.dot(pa, ba) / np.dot(ba, ba), 0, 1).reshape((-1, 1))
        return _length(pa - np.multiply(ba, h)) - radius
    return f

@sdf
def cylinder(radius):
    def f(p):
        return _length(p[:,[0,1]]) - radius;
    return f

@sdf
def capped_cylinder(a, b, radius):
    a = np.array(a)
    b = np.array(b)
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
            _max(x, y) < 0,
            -_min(x2, y2),
            np.where(x > 0, x2, 0) + np.where(y > 0, y2, 0))
        return np.sign(d) * np.sqrt(np.abs(d)) / baba
    return f

@sdf
def rounded_cylinder(ra, rb, h):
    def f(p):
        d = _vec(
            _length(p[:,[0,1]]) - 2 * ra + rb,
            np.abs(p[:,2]) - h)
        return (
            _min(_max(d[:,0], d[:,1]), 0) +
            _length(_max(d, 0)) - rb)
    return f

@sdf
def capped_cone(a, b, ra, rb):
    a = np.array(a)
    b = np.array(b)
    def f(p):
        rba = rb - ra
        baba = np.dot(b - a, b - a)
        papa = _dot(p - a, p - a)
        paba = np.dot(p - a, b - a) / baba
        x = np.sqrt(papa - paba * paba * baba)
        cax = _max(0, x - np.where(paba < 0.5, ra, rb))
        cay = np.abs(paba - 0.5) - 0.5
        k = rba * rba + baba
        f = np.clip((rba * (x - ra) + paba * baba) / k, 0, 1)
        cbx = x - ra - f * rba
        cby = paba - f
        s = np.where(np.logical_and(cbx < 0, cay < 0), -1, 1)
        return s * np.sqrt(_min(
            cax * cax + cay * cay * baba,
            cbx * cbx + cby * cby * baba))
    return f

@sdf
def ellipsoid(size):
    size = np.array(size)
    def f(p):
        k0 = _length(p / size)
        k1 = _length(p / (size * size))
        return k0 * (k0 - 1) / k1
    return f

@sdf
def pyramid(h):
    def f(p):
        a = np.abs(p[:,[0,1]]) - 0.5
        w = a[:,1] > a[:,0]
        a[w] = a[:,[1,0]][w]
        px = a[:,0]
        py = p[:,2]
        pz = a[:,1]
        m2 = h * h + 0.25
        qx = pz
        qy = h * py - 0.5 * px
        qz = h * px + 0.5 * py
        s = _max(-qx, 0)
        t = np.clip((qy - 0.5 * pz) / (m2 + 0.25), 0, 1)
        a = m2 * (qx + s) ** 2 + qy * qy
        b = m2 * (qx + 0.5 * t) ** 2 + (qy - m2 * t) ** 2
        d2 = np.where(
            _min(qy, -qx * m2 - qy * 0.5) > 0,
            0, _min(a, b))
        return np.sqrt((d2 + qz * qz) / m2) * np.sign(_max(qz, -py))
    return f

# Platonic Solids

@sdf
def tetrahedron(r):
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        return (_max(np.abs(x + y) - z, np.abs(x - y) + z) - 1) / np.sqrt(3)
    return f

@sdf
def octahedron(r):
    def f(p):
        return (np.sum(np.abs(p), axis=1) - r) * np.tan(np.radians(30))
    return f

@sdf
def dodecahedron(r):
    x, y, z = _normalize(((1 + np.sqrt(5)) / 2, 1, 0))
    def f(p):
        p = np.abs(p / r)
        a = np.dot(p, (x, y, z))
        b = np.dot(p, (z, x, y))
        c = np.dot(p, (y, z, x))
        q = (_max(_max(a, b), c) - x) * r
        return q
    return f

@sdf
def icosahedron(r):
    x, y, z = _normalize(((np.sqrt(5) + 3) / 2, 1, 0))
    w = np.sqrt(3) / 3
    def f(p):
        p = np.abs(p / r)
        a = np.dot(p, (x, y, z))
        b = np.dot(p, (z, x, y))
        c = np.dot(p, (y, z, x))
        d = np.dot(p, (w, w, w)) - x
        return _max(_max(_max(a, b), c) - x, d) * r
    return f

# Combinations

@registered_sdf
def union(a, *bs, k=None):
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            if k is None:
                d1 = _min(d1, d2)
            else:
                h = np.clip(0.5 + 0.5 * (d2 - d1) / k, 0, 1)
                m = d2 + (d1 - d2) * h
                d1 = m - k * h * (1 - h)
        return d1
    return f

@registered_sdf
def difference(a, *bs, k=None):
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            if k is None:
                d1 = _max(d1, -d2)
            else:
                h = np.clip(0.5 - 0.5 * (d2 + d1) / k, 0, 1)
                m = d1 + (-d2 - d1) * h
                d1 = m + k * h * (1 - h)
        return d1
    return f

@registered_sdf
def intersection(a, *bs, k=None):
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            if k is None:
                d1 = _max(d1, d2)
            else:
                h = np.clip(0.5 - 0.5 * (d2 - d1) / k, 0, 1)
                m = d2 + (d1 - d2) * h
                d1 = m + k * h * (1 - h)
        return d1
    return f

@registered_sdf
def blend(a, *bs, k=0.5):
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = k * d2 + (1 - k) * d1
        return d1
    return f

# Positioning

@registered_sdf
def translate(other, offset):
    def f(p):
        return other(p - offset)
    return f

@registered_sdf
def scale(other, factor):
    try:
        x, y, z = factor
    except TypeError:
        x = y = z = factor
    s = (x, y, z)
    m = min(x, min(y, z))
    def f(p):
        return other(p / s) * m
    return f

@registered_sdf
def rotate(other, vector, angle):
    x, y, z = _normalize(vector)
    s = np.sin(angle)
    c = np.cos(angle)
    m = 1 - c
    matrix = np.array([
        [m*x*x + c, m*x*y + z*s, m*z*x - y*s],
        [m*x*y - z*s, m*y*y + c, m*y*z + x*s],
        [m*z*x + y*s, m*y*z - x*s, m*z*z + c],
    ]).T
    def f(p):
        return other(np.dot(p, matrix))
    return f

@registered_sdf
def rotate_to(other, a, b):
    a = _normalize(np.array(a))
    b = _normalize(np.array(b))
    dot = np.dot(b, a)
    if dot == 1:
        return other
    if dot == -1:
        return rotate(other, _perpendicular(a), np.pi)
    angle = np.arccos(dot)
    v = _normalize(np.cross(b, a))
    return rotate(other, v, angle)

@registered_sdf
def orient(other, axis):
    return rotate_to(other, UP, axis)

@registered_sdf
def repeat(other, count, spacing):
    count = np.array(count)
    spacing = np.array(spacing)
    def f(p):
        q = p - spacing * np.clip(np.round(p / spacing), -count, count)
        return other(q)
    return f

# Alterations

@registered_sdf
def elongate(other, size):
    def f(p):
        q = np.abs(p) - size
        x = q[:,0].reshape((-1, 1))
        y = q[:,1].reshape((-1, 1))
        z = q[:,2].reshape((-1, 1))
        w = _min(_max(x, _max(y, z)), 0)
        return other(_max(q, 0)) + w
    return f

@registered_sdf
def twist(other, k):
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        c = np.cos(k * z)
        s = np.sin(k * z)
        x2 = c * x - s * y
        y2 = s * x + c * y
        z2 = z
        return other(_vec(x2, y2, z2))
    return f

@registered_sdf
def bend(other, k):
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        c = np.cos(k * x)
        s = np.sin(k * x)
        x2 = c * x - s * y
        y2 = s * x + c * y
        z2 = z
        return other(_vec(x2, y2, z2))
    return f

@registered_sdf
def shell(other, thickness):
    def f(p):
        return np.abs(other(p)) - thickness
    return f

@registered_sdf
def extrude(other, h):
    def f(p):
        d = other(p[:,[0,1]])
        w = _vec(d.reshape(-1), np.abs(p[:,2]) - h / 2)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
    return f

@registered_sdf
def revolve(other, offset=0):
    def f(p):
        xy = p[:,[0,1]]
        q = _vec(_length(xy) - offset, p[:,2])
        return other(q)
    return f



# TODO: separate 2D and 3D SDFs (different module / namespace)

@sdf
def circle(radius=1, center=(0, 0)):
    def f(p):
        return _length(p - center) - radius
    return f

@sdf
def box2(size=1, center=(0, 0)):
    size = np.array(size) / 2
    def f(p):
        q = np.abs(p - center) - size
        return _length(_max(q, 0)) + _min(np.amax(q, axis=1), 0)
    return f

@sdf
def rounded_box2(size, radius, center=(0, 0)):
    try:
        r0, r1, r2, r3 = radius
    except TypeError:
        r0 = r1 = r2 = r3 = radius
    def f(p):
        x = p[:,0]
        y = p[:,1]
        r = np.zeros(len(p)).reshape((-1, 1))
        r[np.logical_and(x > 0, y > 0)] = r0
        r[np.logical_and(x > 0, y <= 0)] = r1
        r[np.logical_and(x <= 0, y <= 0)] = r2
        r[np.logical_and(x <= 0, y > 0)] = r3
        q = np.abs(p) - size + r
        return (
            _min(_max(q[:,0], q[:,1]), 0).reshape((-1, 1)) +
            _length(_max(q, 0)).reshape((-1, 1)) - r)
    return f

@sdf
def equilateral_triangle():
    def f(p):
        k = 3 ** 0.5
        p = _vec(
            np.abs(p[:,0]) - 1,
            p[:,1] + 1 / k)
        w = p[:,0] + k * p[:,1] > 0
        q = _vec(
            p[:,0] - k * p[:,1],
            -k * p[:,0] - p[:,1]) / 2
        p = np.where(w.reshape((-1, 1)), q, p)
        p = _vec(
            p[:,0] - np.clip(p[:,0], -2, 0),
            p[:,1])
        return -_length(p) * np.sign(p[:,1])
    return f

@sdf
def hexagon(r):
    def f(p):
        k = np.array((3 ** 0.5 / -2, 0.5, np.tan(np.pi / 6)))
        p = np.abs(p)
        p -= 2 * k[:2] * _min(_dot(k[:2], p), 0).reshape((-1, 1))
        p -= _vec(
            np.clip(p[:,0], -k[2] * r, k[2] * r),
            np.zeros(len(p)) + r)
        return _length(p) * np.sign(p[:,1])
    return f

@sdf
def rounded_x(w, r):
    def f(p):
        p = np.abs(p)
        q = (_min(p[:,0] + p[:,1], w) * 0.5).reshape((-1, 1))
        return _length(p - q) - r
    return f
