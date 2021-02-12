import functools
import numpy as np
import operator

from . import dn, d2, ease, mesh

# Constants

ORIGIN = np.array((0, 0, 0))

X = np.array((1, 0, 0))
Y = np.array((0, 1, 0))
Z = np.array((0, 0, 1))

UP = Z

# SDF Class

_ops = {}

class SDF3:
    def __init__(self, f):
        self.f = f
    def __call__(self, p):
        return self.f(p).reshape((-1, 1))
    def __getattr__(self, name):
        if name in _ops:
            f = _ops[name]
            return functools.partial(f, self)
        raise AttributeError
    def __or__(self, other):
        return union(self, other)
    def __and__(self, other):
        return intersection(self, other)
    def __sub__(self, other):
        return difference(self, other)
    def k(self, k=None):
        self._k = k
        return self
    def generate(self, *args, **kwargs):
        return mesh.generate(self, *args, **kwargs)
    def save(self, path, *args, **kwargs):
        return mesh.save(path, self, *args, **kwargs)
    def show_slice(self, *args, **kwargs):
        return mesh.show_slice(self, *args, **kwargs)

def sdf3(f):
    def wrapper(*args, **kwargs):
        return SDF3(f(*args, **kwargs))
    return wrapper

def op3(f):
    def wrapper(*args, **kwargs):
        return SDF3(f(*args, **kwargs))
    _ops[f.__name__] = wrapper
    return wrapper

def op32(f):
    def wrapper(*args, **kwargs):
        return d2.SDF2(f(*args, **kwargs))
    _ops[f.__name__] = wrapper
    return wrapper

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

@sdf3
def sphere(radius=1, center=ORIGIN):
    def f(p):
        return _length(p - center) - radius
    return f

@sdf3
def plane(normal=UP, point=ORIGIN):
    normal = _normalize(normal)
    def f(p):
        return np.dot(point - p, normal)
    return f

@sdf3
def slab(x0=None, y0=None, z0=None, x1=None, y1=None, z1=None, k=None):
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
    return intersection(*fs, k=k)

@sdf3
def box(size=1, center=ORIGIN, a=None, b=None):
    if a is not None and b is not None:
        a = np.array(a)
        b = np.array(b)
        size = b - a
        center = a + size / 2
        return box(size, center)
    size = np.array(size)
    def f(p):
        q = np.abs(p - center) - size / 2
        return _length(_max(q, 0)) + _min(np.amax(q, axis=1), 0)
    return f

@sdf3
def rounded_box(size, radius):
    size = np.array(size)
    def f(p):
        q = np.abs(p) - size / 2 + radius
        return _length(_max(q, 0)) + _min(np.amax(q, axis=1), 0) - radius
    return f

@sdf3
def wireframe_box(size, thickness):
    size = np.array(size)
    def g(a, b, c):
        return _length(_max(_vec(a, b, c), 0)) + _min(_max(a, _max(b, c)), 0)
    def f(p):
        p = np.abs(p) - size / 2 - thickness / 2
        q = np.abs(p + thickness / 2) - thickness / 2
        px, py, pz = p[:,0], p[:,1], p[:,2]
        qx, qy, qz = q[:,0], q[:,1], q[:,2]
        return _min(_min(g(px, qy, qz), g(qx, py, qz)), g(qx, qy, pz))
    return f

@sdf3
def torus(r1, r2):
    def f(p):
        xy = p[:,[0,1]]
        z = p[:,2]
        a = _length(xy) - r1
        b = _length(_vec(a, z)) - r2
        return b
    return f

@sdf3
def capsule(a, b, radius):
    a = np.array(a)
    b = np.array(b)
    def f(p):
        pa = p - a
        ba = b - a
        h = np.clip(np.dot(pa, ba) / np.dot(ba, ba), 0, 1).reshape((-1, 1))
        return _length(pa - np.multiply(ba, h)) - radius
    return f

@sdf3
def cylinder(radius):
    def f(p):
        return _length(p[:,[0,1]]) - radius;
    return f

@sdf3
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

@sdf3
def rounded_cylinder(ra, rb, h):
    def f(p):
        d = _vec(
            _length(p[:,[0,1]]) - ra + rb,
            np.abs(p[:,2]) - h / 2 + rb)
        return (
            _min(_max(d[:,0], d[:,1]), 0) +
            _length(_max(d, 0)) - rb)
    return f

@sdf3
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

@sdf3
def rounded_cone(r1, r2, h):
    def f(p):
        q = _vec(_length(p[:,[0,1]]), p[:,2])
        b = (r1 - r2) / h
        a = np.sqrt(1 - b * b)
        k = np.dot(q, _vec(-b, a))
        c1 = _length(q) - r1
        c2 = _length(q - _vec(0, h)) - r2
        c3 = np.dot(q, _vec(a, b)) - r1
        return np.where(k < 0, c1, np.where(k > a * h, c2, c3))
    return f

@sdf3
def ellipsoid(size):
    size = np.array(size)
    def f(p):
        k0 = _length(p / size)
        k1 = _length(p / (size * size))
        return k0 * (k0 - 1) / k1
    return f

@sdf3
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

@sdf3
def tetrahedron(r):
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        return (_max(np.abs(x + y) - z, np.abs(x - y) + z) - 1) / np.sqrt(3)
    return f

@sdf3
def octahedron(r):
    def f(p):
        return (np.sum(np.abs(p), axis=1) - r) * np.tan(np.radians(30))
    return f

@sdf3
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

@sdf3
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

# Positioning

@op3
def translate(other, offset):
    def f(p):
        return other(p - offset)
    return f

@op3
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

@op3
def rotate(other, angle, vector=Z):
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

@op3
def rotate_to(other, a, b):
    a = _normalize(np.array(a))
    b = _normalize(np.array(b))
    dot = np.dot(b, a)
    if dot == 1:
        return other
    if dot == -1:
        return rotate(other, np.pi, _perpendicular(a))
    angle = np.arccos(dot)
    v = _normalize(np.cross(b, a))
    return rotate(other, angle, v)

@op3
def orient(other, axis):
    return rotate_to(other, UP, axis)

@op3
def circular_array(other, count, offset):
    other = other.translate(X * offset)
    da = 2 * np.pi / count
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        d = np.hypot(x, y)
        a = np.arctan2(y, x) % da
        d1 = other(_vec(np.cos(a - da) * d, np.sin(a - da) * d, z))
        d2 = other(_vec(np.cos(a) * d, np.sin(a) * d, z))
        return _min(d1, d2)
    return f

# Alterations

@op3
def elongate(other, size):
    def f(p):
        q = np.abs(p) - size
        x = q[:,0].reshape((-1, 1))
        y = q[:,1].reshape((-1, 1))
        z = q[:,2].reshape((-1, 1))
        w = _min(_max(x, _max(y, z)), 0)
        return other(_max(q, 0)) + w
    return f

@op3
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

@op3
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

@op3
def bend_linear(other, p0, p1, v, e=ease.linear):
    p0 = np.array(p0)
    p1 = np.array(p1)
    v = -np.array(v)
    ab = p1 - p0
    def f(p):
        t = np.clip(np.dot(p - p0, ab) / np.dot(ab, ab), 0, 1)
        t = e(t).reshape((-1, 1))
        return other(p + t * v)
    return f

@op3
def bend_radial(other, r0, r1, dz, e=ease.linear):
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        r = np.hypot(x, y)
        t = np.clip((r - r0) / (r1 - r0), 0, 1)
        z = z + dz * e(t)
        return other(_vec(x, y, z))
    return f

@op3
def transition(f0, f1, p0=-Z, p1=Z, e=ease.linear):
    p0 = np.array(p0)
    p1 = np.array(p1)
    ab = p1 - p0
    def f(p):
        d1 = f0(p)
        d2 = f1(p)
        t = np.clip(np.dot(p - p0, ab) / np.dot(ab, ab), 0, 1)
        t = e(t).reshape((-1, 1))
        return t * d2 + (1 - t) * d1
    return f

@op3
def transition_radial(f0, f1, r0=0, r1=1, e=ease.linear):
    def f(p):
        d1 = f0(p)
        d2 = f1(p)
        r = np.hypot(p[:,0], p[:,1])
        t = np.clip((r - r0) / (r1 - r0), 0, 1)
        t = e(t).reshape((-1, 1))
        return t * d2 + (1 - t) * d1
    return f

# 3D => 2D Operations

@op32
def slice(other):
    # TODO: support specifying a slice plane
    # TODO: probably a better way to do this
    s = slab(z0=-1e-9, z1=1e-9)
    a = other & s
    b = other.negate() & s
    def f(p):
        p = _vec(p[:,0], p[:,1], np.zeros(len(p)))
        A = a(p).reshape(-1)
        B = -b(p).reshape(-1)
        w = A <= 0
        A[w] = B[w]
        return A
    return f

# Common

union = op3(dn.union)
difference = op3(dn.difference)
intersection = op3(dn.intersection)
blend = op3(dn.blend)
negate = op3(dn.negate)
dilate = op3(dn.dilate)
erode = op3(dn.erode)
shell = op3(dn.shell)
repeat = op3(dn.repeat)
