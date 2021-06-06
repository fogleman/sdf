import functools
import numpy as np
import operator

from . import dn, d3, ease

# Constants

ORIGIN = np.array((0, 0))

X = np.array((1, 0))
Y = np.array((0, 1))

UP = Y

# SDF Class

_ops = {}

class SDF2:
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

def sdf2(f):
    def wrapper(*args, **kwargs):
        return SDF2(f(*args, **kwargs))
    return wrapper

def op2(f):
    def wrapper(*args, **kwargs):
        return SDF2(f(*args, **kwargs))
    _ops[f.__name__] = wrapper
    return wrapper

def op23(f):
    def wrapper(*args, **kwargs):
        return d3.SDF3(f(*args, **kwargs))
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

_min = np.minimum
_max = np.maximum

def _wn(pnts, poly):
    # Winding number algorithm
    #print("points: {}".format(pnts.shape))
    #print("points: {}".format(pnts))
    #print("min: {}".format(np.min(poly, axis=0)))

    x0 = poly[:-1,0]   # polygon `from` coordinates
    y0 = poly[:-1,1]   # polygon `from` coordinates
    x1 = poly[1 :,0]   # polygon `to` coordinates
    y1 = poly[1 :,1]   # polygon `to` coordinates
    #pp = np.atleast_2d(points).reshape(2, -1)
    #del_tails = pp.T[:, None] - self.v[:, :-1].T  # shaped (n, m, 2)
    #b1 = del_tails[:, :, 1] >= 0.0
    #b2 = np.less.outer(pp[1], self.v[1, 1:])
    #sides = np.sign(np.einsum("ijk, kj -> ij", del_tails, self._ie))
    #wn_pos = (b1 & b2 & (sides > 0)).sum(axis=1, dtype=int)
    #wn_neg = (~b1 & ~b2 & (sides < 0)).sum(axis=1, dtype=int)
    #wn = wn_pos - wn_neg

    x = pnts[:,0]         # point coordinates
    y = pnts[:,1]         # point coordinates
    #print("x0: {} y0: {} x1: {} y1: {} x: {} y: {}".format(x0,y0,x1,y1,x,y))
    y_y0 = y[:,None] - y0
    x_x0 = x[:,None] - x0
    #print("y_y0: {}".format(y_y0))
    #print("x_x0: {}".format(x_x0))
    diff_ = (x1 - x0) * y_y0 - (y1 - y0) * x_x0  # diff => einsum in original
    chk1 = (y_y0 >= 0.0)
    chk2 = np.less(y[:, None], y1)  # pnts[:, 1][:, None], poly[1:, 1])
    chk3 = np.sign(diff_).astype(np.int)
    #print("chk1: {}".format(chk1))
    pos = (chk1 & chk2 & (chk3 > 0)).sum(axis=1, dtype=int)
    neg = (~chk1 & ~chk2 & (chk3 < 0)).sum(axis=1, dtype=int)
    #print("pos: {}".format(pos))
    #print("neg: {}".format(neg))
    #print("wn size: {} {}".format(pos.shape,neg.shape))
    return (pos - neg)
    #print("wn : {}".format(wn))
    #out_ = pnts[np.nonzero(wn)]
    #if return_winding:
    #    return out_, wn
    #return out_

def _mindist(a, b):
    inside = (a < 0 and b < 0)
    r = inside * _max(a,b) + _min(a,b)
#    ret = np.array(len(a))
#    for out, i in enumerate(outside):
#      if (out):
#        ret[i] = min(max(a[i], 0), max(b[i], 0))
#      else:
#        ret[i] = max(a[i], b[i])
#    return ret

# Primitives

@sdf2
def circle(radius=1, center=ORIGIN):
    def f(p):
        return _length(p - center) - radius
    return f

@sdf2
def line(normal=UP, point=ORIGIN):
    normal = _normalize(normal)
    def f(p):
        return np.dot(point - p, normal)
    return f

@sdf2
def crop(x0=None, y0=None, x1=None, y1=None, k=None):
    fs = []
    if x0 is not None:
        fs.append(line(X, (x0, 0)))
    if x1 is not None:
        fs.append(line(-X, (x1, 0)))
    if y0 is not None:
        fs.append(line(Y, (0, y0)))
    if y1 is not None:
        fs.append(line(-Y, (0, y1)))
    return intersection(*fs, k=k)

@sdf2
def rectangle(size=1, center=ORIGIN, a=None, b=None):
    if a is not None and b is not None:
        a = np.array(a)
        b = np.array(b)
        size = b - a
        center = a + size / 2
        return rectangle(size, center)
    size = np.abs(np.array(size))
    def f(p):
        q = np.abs(p - center) - size / 2
        return _length(_max(q, 0)) + _min(np.amax(q, axis=1), 0)
    return f

@sdf2
def rounded_rectangle(size=1, radius=0.1, center=ORIGIN, a=None, b=None):
    if a is not None and b is not None:
        a = np.array(a)
        b = np.array(b)
        size = b - a
        center = a + size / 2
        return rounded_rectangle(size, radius, center)
    try:
        r0, r1, r2, r3 = radius
    except TypeError:
        r0 = r1 = r2 = r3 = radius
    size = np.abs(np.array(size))
    def f(p):
        x = p[:,0]
        y = p[:,1]
        r = np.zeros(len(p)).reshape((-1, 1))
        r[np.logical_and(x > 0, y > 0)] = r0
        r[np.logical_and(x > 0, y <= 0)] = r1
        r[np.logical_and(x <= 0, y <= 0)] = r2
        r[np.logical_and(x <= 0, y > 0)] = r3
        q = np.abs(p - center) - size / 2 + r
        return (
            _min(_max(q[:,0], q[:,1]), 0).reshape((-1, 1)) +
            _length(_max(q, 0)).reshape((-1, 1)) - r)
    return f

@sdf2
def equilateral_triangle(r=1, center=ORIGIN):
    k = 3 ** 0.5
    def f(p):
        p = _vec(
            np.abs((p[:,0]-center[0])/r) - 1,
            (p[:,1]-center[1])/r + 1 / k)
        w = p[:,0] + k * p[:,1] > 0
        q = _vec(
            p[:,0] - k * p[:,1],
            -k * p[:,0] - p[:,1]) / 2
        p = np.where(w.reshape((-1, 1)), q, p)
        p = _vec(
            p[:,0] - np.clip(p[:,0], -2, 0),
            p[:,1])
        return -_length(p) * np.sign(p[:,1]) * r
    return f

@sdf2
def equilateral_polygon(n, r):
    sw = np.tan(np.pi/n)*r
    ang = np.pi/n
    ang2 = 2*np.pi/n
    #points = [np.array(p) for p in points]
    def f(p):
        a = np.arctan2(p[:,1], p[:,0])
        edge = np.round(a / ang2) * ang2
        s = np.sin(edge)
        c = np.cos(edge)
        x = c*p[:,0]+s*p[:,1] - r
        y = _max(np.abs(-s*p[:,0]+c*p[:,1]) - sw, 0)
        #rot = a - np.abs(np.mod(a,2*np.pi/n) - np.pi/n)
        #s = np.sin(rot)
        #c = np.cos(rot)
        #matrix = np.array([
        #    [c, -s],
        #    [s, c],
        #]).T
        #pt = np.dot(p, matrix)
        #x = pt[:,0] - r
        #y = _min(pt[:,1] - sw,0)
        #print("p: {} c: {} s: {} x: {} y: {}".format(p.shape,c.shape,s.shape,x.shape,y.shape))
        return np.sign(x) * _length(_vec(x, y))
    return f

@sdf2
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

@sdf2
def rounded_x(w, r):
    def f(p):
        p = np.abs(p)
        q = (_min(p[:,0] + p[:,1], w) * 0.5).reshape((-1, 1))
        return _length(p - q) - r
    return f

@sdf2
def polygon(points):
    points = [np.array(p) for p in points]
    def f(p):
        n = len(points)
        d = _dot(p - points[0], p - points[0])
        s = np.ones(len(p))
        for i in range(n):
            j = (i + n - 1) % n
            vi = points[i]
            vj = points[j]
            e = vj - vi
            w = p - vi
            b = w - e * np.clip(np.dot(w, e) / np.dot(e, e), 0, 1).reshape((-1, 1))
            d = _min(d, _dot(b, b))
            c1 = p[:,1] >= vi[1]
            c2 = p[:,1] < vj[1]
            c3 = e[0] * w[:,1] > e[1] * w[:,0]
            c = _vec(c1, c2, c3)
            s = np.where(np.all(c, axis=1) | np.all(~c, axis=1), -s, s)
        return s * np.sqrt(d)
    return f

#@sdf2
#def in_polygon(points):
#    wn_points = np.array(points)
#    wn_points = np.vstack((wn_points, wn_points[0,:]))
#    points = [np.array(p) for p in points]
#    #print("poly: {}".format(wn_points))
#    #print("result: {}".format(_wn(np.array([[0,1],[3.5,0],[3.9,1],[4.5,1],[3.5,2]]),wn_points)))
#    #print("should be 0 0 1 0 0")
#    def f(p):
#        n = len(points)
#        wn = (2*(np.mod(_wn(p, wn_points),2)==0))-1
#        d = _dot(p - points[0], p - points[0])
#        s = np.ones(len(p))
#        for i in range(n):
#            j = (i + n - 1) % n
#            vi = points[i]
#            vj = points[j]
#            e = vj - vi
#            w = p - vi
#            b = w - e * np.clip(np.dot(w, e) / np.dot(e, e), 0, 1).reshape((-1, 1))
#            d = _min(d, _dot(b, b))
#            c1 = p[:,1] >= vi[1]
#            c2 = p[:,1] < vj[1]
#            #print("e: {}, w: {} c1: {} c2: {}".format(e.shape,w.shape,c1.shape,c2.shape))
#            c3 = e[0] * w[:,1] > e[1] * w[:,0]
#            #print("e: {}, w: {} c1: {} c2: {} c3: {}".format(e.shape,w.shape,c1.shape,c2.shape,c3.shape))
#            c = _vec(c1, c2, c3)
#            s = np.where(np.all(c, axis=1) | np.all(~c, axis=1), -s, s)
#        return np.sqrt(d) * wn
#    return f

# Positioning

@op2
def translate(other, offset):
    def f(p):
        return other(p - offset)
    return f

@op2
def scale(other, factor):
    try:
        x, y = factor
    except TypeError:
        x = y = factor
    s = (x, y)
    m = min(x, y)
    def f(p):
        return other(p / s) * m
    return f

@op2
def rotate(other, angle):
    s = np.sin(angle)
    c = np.cos(angle)
    #m = 1 - c
    matrix = np.array([
        [c, -s],
        [s, c],
    ]).T
    def f(p):
        return other(np.dot(p, matrix))
    return f

@op2
def circular_array(other, count):
    angles = [i / count * 2 * np.pi for i in range(count)]
    return union(*[other.rotate(a) for a in angles])

# Alterations

@op2
def elongate(other, size):
    def f(p):
        q = np.abs(p) - size
        x = q[:,0].reshape((-1, 1))
        y = q[:,1].reshape((-1, 1))
        w = _min(_max(x, y), 0)
        return other(_max(q, 0)) + w
    return f

# 2D => 3D Operations

@op23
def extrude(other, h):
    def f(p):
        d = other(p[:,[0,1]])
        w = _vec(d.reshape(-1), np.abs(p[:,2]) - h / 2)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
    return f

@op23
def taper_extrude(other, h, angle):
    taper = np.sin(angle)
    def f(p):
        d = other(p[:,[0,1]]*np.max(1+np.clip(p[:,[2]],0,h)*taper,0))
        w = _vec(d.reshape(-1), np.abs(p[:,2]) - h / 2)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
    return f

@op23
def rounded_extrude(other,h,radius=1):
    def f(p):
        d = other(p[:,[0,1]])
        w = _vec(d.reshape(-1), np.abs(p[:,2]) - h / 2)
        th = radius * (w[:,0] > -radius) * (w[:,1] > -radius)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w+np.stack((th,th),axis=1), 0)) - th
    return f

@op23
def extrude_to(a, b, h, e=ease.linear):
    def f(p):
        d1 = a(p[:,[0,1]])
        d2 = b(p[:,[0,1]])
        t = e(np.clip(p[:,2] / h, -0.5, 0.5) + 0.5)
        d = d1 + (d2 - d1) * t.reshape((-1, 1))
        w = _vec(d.reshape(-1), np.abs(p[:,2]) - h / 2)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
    return f

@op23
def revolve(other, offset=0):
    def f(p):
        xy = p[:,[0,1]]
        q = _vec(_length(xy) - offset, p[:,2])
        return other(q)
    return f

@op23
def helix_revolve(other, offset=0, pitch=1, rotations=1):
    # Note: Use a negative pitch to reverse the helix direction.
    abs_pitch = abs(pitch)
    sgn_pitch = np.sign(pitch)
    s = np.sin(rotations*2*np.pi)
    c = np.cos(rotations*2*np.pi)
    top_rotation = np.array([
        [c, s],
        [-s, c],
    ]).T

    
    def f(p):
        a = -np.arctan2(p[:,1], -p[:,0]) / (sgn_pitch*2*np.pi) + 1/2
        z = p[:,2] - a*abs_pitch
        n0 = np.floor(z/abs_pitch)
        n1 = np.ceil(z/abs_pitch)
        #z -= (_max(n,0) - np.ceil(_max(n+a-rotations,0))) * abs_pitch
        z0 = z-(_max(n0,0) - np.ceil(_max(n0+a-rotations,0))) * abs_pitch
        z1 = z-(_max(n1,0) - np.ceil(_max(n1+a-rotations,0))) * abs_pitch

        # Climing distance
        xy = p[:,[0,1]]
        #q = _vec(_length(xy) - offset, z)
        d = _min(other(_vec(_length(xy) - offset, z0)),other(_vec(_length(xy) - offset, z1)))

        # Base distance
        d_xz = _max(other(p[:,[0,2]]),0)
        base_d = _vec(_length(np.hstack((d_xz,_vec(p[:,1])))))

        #np.dot(p, matrix)
        # Top distance
        top_xy = np.dot(p[:,[0,1]], top_rotation)
        d_xz = _max(other(np.hstack((top_xy[:,[0]],p[:,[2]]-pitch*rotations))),0)
        top_d = _vec(_length(np.hstack((d_xz,_vec(top_xy[:,1])))))
        #base_d = _vec(_length(np.hstack((base,_vec(p[:,1])))))

        #return base_d
        return _min(_min(d, base_d),top_d)
        #return _min(top_d, base_d)
        #w = _vec(d.reshape(-1), np.abs(p[:,2]) - h / 2)
        #return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
    return f

# Common

union = op2(dn.union)
difference = op2(dn.difference)
intersection = op2(dn.intersection)
blend = op2(dn.blend)
negate = op2(dn.negate)
dilate = op2(dn.dilate)
erode = op2(dn.erode)
shell = op2(dn.shell)
repeat = op2(dn.repeat)
