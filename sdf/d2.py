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

def _length(a, axis=1):
    #return np.linalg.norm(a, axis=axis)
    return np.sum(a * a, axis=axis) ** 0.5

def _length2(a, axis=1):
    return np.sum(a * a, axis=axis)

def _normalize(a):
    return a / np.linalg.norm(a)

def _dot(a, b, axis=1):
    return np.sum(a * b, axis=axis)

def _unit(a, axis=1):
    return a / _length(a, axis=axis)

def _project(a,b,axis=1):
    #print(a,b)
    #print(a*b, a*a, b*b)
    #print(np.sum(a * b, axis=axis),np.sum(b * b, axis=axis),b)
    return _dot(a,b,axis=axis)/_dot(b,b,axis=axis)*b

def _is_rh(a,b):
    r = _unit(a,axis=0)
    return (r[1]*b[0]-r[0]*b[1]) > 0

#def _T(a):
#    return np.transpose(a)

def _vec(*arrs):
    return np.stack(arrs, axis=-1)

_min = np.minimum
_max = np.maximum

# Winding curve function, TODO: could be used for bounding box checks
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
    outside = (a > 0) & (b > 0)
    return np.where(outside, _min(a,b), _max(a,b))

def _additive(a, b):
    outside = (a > 0) & (b > 0)
    return np.where(outside, _min(a,b), _max(a,b))
def _subtractive(a, b):
    inside = (a < 0) & (b < 0)
    return np.where(inside, _max(a,b), _min(a,b))

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
            if np.array_equal(vi, vj):
                continue 
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

@sdf2
def rounded_polygon(points):
    points = [np.array(pt) for pt in points]
    #print("size p:{}".format(p.shape))
    n = len(points)
    centers = np.zeros((n, 2))
    curve_left = np.zeros(n, dtype=bool)
    for i in range(n):
        if points[i][2] != 0:
            j = (i + n - 1) % n
            vi = points[i][0:2]
            vj = points[j][0:2]
            curve = points[i][2]
            if np.array_equal(vi, vj):
                continue
            e = vj - vi

            seg_len = np.sum(e*e)**0.5/2
            if abs(curve) < seg_len:
                raise Exception("radius too small on segment {} - {} => {}".format(vi, vj, seg_len))

            # find the center point, radius vector, and if in circle
            t = np.sign(curve) * _vec(-e[1],e[0])  # perpendicular to linesegment pointing away from center
            middle = (vi + vj)/2
            center = middle - ((curve**2 - seg_len**2) ** 0.5) * t / (np.dot(t,t) ** 0.5)
            centers[i,:] = center
            curve_left[i] = t[0] < 0
    def f(p):
        s = np.ones(len(p))
        d = np.inf * s
        for i in range(n):
            j = (i + n - 1) % n
            vi = points[i][0:2]
            vj = points[j][0:2]
            curve = points[i][2]
            if np.array_equal(vi, vj):
                continue
            e = vj - vi
            w = p - vi
            if curve == 0:
                b = w - e * np.clip(np.dot(w, e) / np.dot(e, e), 0, 1).reshape((-1, 1))
                d = _min(d, _dot(b, b))
                c1 = p[:,1] >= vi[1]
                c2 = p[:,1] < vj[1]
                c3 = e[0] * w[:,1] > e[1] * w[:,0]
                c = _vec(c1, c2, c3)
                s = np.where(np.all(c, axis=1) | np.all(~c, axis=1), -s, s)
            else:
                center = centers[i,:]
                CL = curve_left[i]
                pc = p - center

                # build use rotation tensors to find point location with respect to arc
                ri = (vi - center)
                #Tiy = ri[1]*pc[:,0]-ri[0]*pc[:,1]
                c_iy = ri[1]*pc[:,0] > ri[0]*pc[:,1]
                rj = (vj - center)
                #Tjy = rj[1]*pc[:,0]-rj[0]*pc[:,1]
                c_jy = rj[1]*pc[:,0] < rj[0]*pc[:,1]
                in_arc = np.logical_and(np.logical_xor(curve < 0, c_iy), np.logical_xor(curve < 0, c_jy))

                # determine distance for in arc points
                r = _length(pc[in_arc],axis=1)
                d[in_arc] = _min((abs(curve)-r)**2,d[in_arc])

                # distance to the arc endpoints
                vi_d = _length2(p[~in_arc] - vi)  # we only really need to do one side
                #vj_d = _length2(p[~in_arc] - vj)

                # minimum distance to anchor
                #d = _min(_length2(p - vi), d)
                d[~in_arc] = _min(vi_d, d[~in_arc])

                # check if point is in the arc circle
                in_circle = np.zeros(len(p), dtype=bool)
                in_circle[in_arc] = r <= abs(curve)

                # check if x axis crossing exists and right handed if on the positive x axis
                c1 = p[:,1] >= vi[1]
                c2 = p[:,1] < vj[1]
                # check if line segment crosses the positive side of the x axis
                c3 = e[0] * w[:,1] > e[1] * w[:,0]

                c = _vec(c1, c2, c3)
                below = (p[:,1] < vj[1]) & (p[:,1] < vi[1]) & (p[:,1] < center[1])
                above = (p[:,1] > vj[1]) & (p[:,1] > vi[1]) & (p[:,1] > center[1])
                #horizon = _vec(p[:,1] < vj[1], p[:,1] < vi[1], p[:,1] < center[1])

                s = np.where(
                    (~CL & in_circle & ((c1 & c2) | (~c1 & ~c2)))
                    | (np.all( c, axis=1) & ~in_circle) # right handed axis cross and not in circle
                    | (np.all(~c, axis=1) & ~in_circle) # left handed axis cross and not in circle
                    | ((above | below) & in_circle)     # in arc below or above
                    #| ((np.all(horizon) | np.all(~horizon)) & in_circle)    # in arc below or above
                   , -s, s)
        return s * np.sqrt(d)
    return f

# Rounding

def round_polygon_smooth_ends(points, sides=None):
    # This moves the points on either end of the segment to smooth out edges
    points = [np.array(pt) for pt in points]
    out = []
    if not sides or not isinstance(sides, list):
        raise Exception("Sides must be a list of sides to round, [0,...N]")

    #print("size p:{}".format(p.shape))
    n = len(points)
    for i in range(n):
        j = (i + n - 1) % n
        k = (i + 1) % n
        l = (i + 2) % n

        if j in sides:
            # we shouldn't do this twice in a row
            continue

        if not i in sides:
            # go to next side if it isn't specified
            out.append(points[i])
            continue

        vj = points[j][0:2]
        vi = points[i][0:2]
        vk = points[k][0:2]
        vl = points[l][0:2]

        va = vi - vj
        vb = vk - vi
        vc = vl - vk

        if (points[i][2] > 0) & (points[k][2] < 0) & (points[l][2] > 0):
            va_p = _vec(-va[1],va[0])  # perpendicular to linesegment pointing to center
            middle_a = (vi + vj)/2
            center_a = middle_a + ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0)
            #print("center_a",center_a)

            vc_p = _vec(-vc[1],vc[0])  # perpendicular to linesegment pointing away from center
            middle_c = (vk + vl)/2
            center_c = middle_c + ((points[l][2]**2 - (_length(vc,axis=0)/2)**2) ** 0.5) * _unit(vc_p,axis=0)
            #print("center_c",center_c)

            center_ac = center_c-center_a

            a = abs(points[i][2]) + abs(points[k][2])
            b = abs(points[k][2]) + abs(points[l][2])
            d2 = _length2(center_c-center_a,axis=0)

            x = (d2 + a**2 - b**2) / (2 * (d2**0.5))
            h = (a**2 - x**2) ** 0.5
            #print("a=",a,"b=",b,"d2=",d2,"x=",x,"h=",h, )
            c2 = center_a + x*_unit(center_ac,axis=0) + h*_unit(_vec(center_ac[1],-center_ac[0]),axis=0)
            #print("c2=",c2)
            p0=c2+_unit(center_a-c2,axis=0)*abs(points[k][2])
            p1=c2+_unit(center_c-c2,axis=0)*abs(points[k][2])
            out.append(np.array([p0[0],p0[1],points[i][2]]))
            out.append(np.array([p1[0],p1[1],points[k][2]]))


        elif (points[i][2] < 0) & (points[k][2] > 0) & (points[l][2] < 0):
            va_p = -_vec(-va[1],va[0])  # perpendicular to linesegment pointing to center
            middle_a = (vi + vj)/2
            center_a = middle_a + ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0)
            #print("center_a",center_a)

            vc_p = -_vec(-vc[1],vc[0])  # perpendicular to linesegment pointing away from center
            middle_c = (vk + vl)/2
            center_c = middle_c + ((points[l][2]**2 - (_length(vc,axis=0)/2)**2) ** 0.5) * _unit(vc_p,axis=0)
            #print("center_c",center_c)

            center_ac = center_c-center_a

            a = abs(points[i][2]) + abs(points[k][2])
            b = abs(points[k][2]) + abs(points[l][2])
            d2 = _length2(center_c-center_a,axis=0)

            x = (d2 + a**2 - b**2) / (2 * (d2**0.5))
            h = (a**2 - x**2) ** 0.5
            #print("a=",a,"b=",b,"d2=",d2,"x=",x,"h=",h, )
            c2 = center_a + x*_unit(center_ac,axis=0) - h*_unit(_vec(center_ac[1],-center_ac[0]),axis=0)
            #print("c2=",c2)
            p0=c2+_unit(center_a-c2,axis=0)*abs(points[k][2])
            p1=c2+_unit(center_c-c2,axis=0)*abs(points[k][2])
            out.append(np.array([p0[0],p0[1],points[i][2]]))
            out.append(np.array([p1[0],p1[1],points[k][2]]))
        else:
            raise Exception("Cannot smooth ends when not alternating concave and convex at {} {} {}",
               points[i][2],points[k][2],points[l][2])

        #if points[i][2] < 0) & points[k][2] < 0
    return np.vstack(out).tolist()


def round_polygon_corners(points, radii, corners=None):
    points = [np.array(pt) for pt in points]
    out = []
    #print("size p:{}".format(p.shape))
    n = len(points)
    for i in range(n):
        j = (i + n - 1) % n
        k = (i + 1) % n

        if corners:
            if not isinstance(corners, list):
                raise Exception("Corners must be a list of corners to round, [0,...N]")

            if not i in corners:
                # go to next vertex if it isn't specified
                out.append(points[i])
                continue

            if isinstance(radii, list):
                radius = radii[corners.index(i)]
            #print("radius=",radius, " index=", corners.index(i))
        else:
            radius = radii

        #print(i,j,k)
        vj = points[j][0:2]
        vi = points[i][0:2]
        vk = points[k][0:2]

        va = vj - vi
        vb = vk - vi

        if (va[0]*vb[1] == va[1]*vb[0]) | (va[0]*vb[1] == -va[1]*vb[0]):
            # points are along a line, do nothing!
            out.append(points[i])
            continue

        rh = 1
        if _is_rh(va, vb):
            rh = -1
        #    rh_radius = -radius
        #else:
        #    rh_radius = radius
        #print("rh=",rh)

        reverse = False
        #print("rounding corner {}".format(points[i]))
        # line-line
        #print("test", points[i][2] == 0 , points[k][2] == 0)
        if (points[i][2] == 0) & (points[k][2] == 0):
            #print("found line-line")
            #print("vi  ", vj-vi, vk-vi)
            bisector = _unit(va,axis=0) + _unit(vb,axis=0)
            va_p = -_unit(np.array((va[1],-va[0])),axis=0)*rh*radius # perpendicular to linesegment
            #print("va_p=",va_p)
            #print("pvk=",pvk, "bisector=", bisector)
            rk = _unit(_project(va_p,bisector,axis=0),axis=0)
            #print("rk=",rk)
            #print("dot", _dot(bisector,va_p,axis=0))
            center = bisector / _dot(bisector,va_p,axis=0)
            #center = _project(rk,bisector,axis=0)
            #print("center=",center)
            p0 = vi + _project(center,va,axis=0)
            p1 = vi + _project(center,vb,axis=0)
            out.append(np.array([p0[0],p0[1],0]))
            out.append(np.array([p1[0],p1[1],-rh*radius]))
            continue

        elif (points[i][2] == 0) & (rh*points[k][2] > 0):
            #print("found line-convex")
            vb_p = _vec(-vb[1],vb[0])*rh  # perpendicular to linesegment pointing away from center
            middle_b = (vi + vk)/2
            center_b = middle_b + ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0)
            #print("center_b=",center_b)
            va_p = -rh*_unit(np.array((va[1],-va[0])),axis=0)*radius # perpendicular to linesegment
            #print("va_p=",va_p)
            h2 = _length2(_project(center_b-vi-va_p,va_p,axis=0),axis=0)
            #print("h2=",h2)
            vi_d = ((abs(radius) + rh*points[k][2])**2 - h2) ** 0.5
            #print("vi_d=",vi_d,"first",(_dot(center_b-vi,_unit(va,axis=0),axis=0)))
            p0 = vi + _unit(va,axis=0) * (_dot(center_b-vi,_unit(va,axis=0),axis=0) + vi_d)
            #print("p0=",p0,"vi=",vi)
            c2 = p0 + va_p
            #print("c2=",c2)
            p1 = c2 + radius * _unit(center_b-c2,axis=0)
            out.append(np.array([p0[0],p0[1],0]))
            out.append(np.array([p1[0],p1[1],-rh*radius]))
            continue

        elif (points[i][2] == 0) & (rh*points[k][2] < 0):
            #print("found line-concave")
            vb_p = -_vec(-vb[1],vb[0])*rh  # perpendicular to linesegment pointing to center
            middle_b = (vi + vk)/2
            center_b = middle_b + ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0)
            #print("center_b=",center_b)
            va_p = -rh*_unit(np.array((va[1],-va[0])),axis=0)*radius # perpendicular to linesegment
            #print("va_p=",va_p)
            h2 = _length2(_project(center_b-vi-va_p,va_p,axis=0),axis=0)
            #print("h2=",h2)
            vi_d = ((abs(radius) + rh*points[k][2])**2 - h2) ** 0.5
            #print("vi_d=",vi_d,"first",(_dot(center_b-vi,_unit(va,axis=0),axis=0)))
            p0 = vi + _unit(va,axis=0) * (_dot(center_b-vi,_unit(va,axis=0),axis=0) - vi_d)
            #print("p0=",p0,"vi=",vi)
            c2 = p0 + va_p
            #print("c2=",c2)
            p1 = c2 - radius * _unit(center_b-c2,axis=0)
            out.append(np.array([p0[0],p0[1],0]))
            out.append(np.array([p1[0],p1[1],-rh*radius]))
            continue

        elif (rh*points[i][2] > 0) & (rh*points[k][2] > 0):
            #print("found convex-convex")
            vb_p = rh*_vec(-vb[1],vb[0])  # perpendicular to linesegment pointing to center
            middle_b = (vi + vk)/2
            #print("middle_b", middle_b, "vec", ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0))
            center_b = middle_b + ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0)
            #print("center_b=",center_b)
            va_p = rh*_vec(-va[1],va[0])  # perpendicular to linesegment pointing to center
            middle_a = (vi + vj)/2
            #print("middle_a", middle_a, "vec", ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0))
            center_a = middle_a - ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0)
            #print("center_a=",center_a)
            center_ab = center_b-center_a
            #print("center_ab=",center_ab, _unit(center_ab,axis=0))
            d2 = _length2(center_ab,axis=0)
            if d2 < 1e-10:
                out.append(points[i])
                continue
            a2 = (abs(points[i][2]) + radius) **2
            b2 = (abs(points[k][2]) + radius) **2
            x = (d2 + a2 - b2) / (2 * (d2**0.5))
            h = (a2 - x**2) ** 0.5
            #print("a2=",a2,"b2=",b2,"d2=",d2,"x=",x,"h=",h, )
            c2 = center_a + x*_unit(center_ab,axis=0) + rh*h*_unit(_vec(center_ab[1],-center_ab[0]),axis=0)
            #print("first",x*_unit(center_ab,axis=0),"second",h*_unit(_vec(center_ab[1],-center_ab[0]),axis=0))
            #print("c2=",c2)
            p0 = radius*_unit(center_a-c2,axis=0)+c2
            #print("p0=",p0)
            p1 = radius*_unit(center_b-c2,axis=0)+c2
            #print("p1=",p1)
            out.append(np.array([p0[0],p0[1],points[i][2]]))
            out.append(np.array([p1[0],p1[1],-rh*radius]))
        elif (rh*points[i][2] < 0) & (rh*points[k][2] < 0):
            #print("found concave-concave", vi)
            vb_p = rh*_vec(-vb[1],vb[0])  # perpendicular to linesegment pointing to center
            middle_b = (vi + vk)/2
            #print("middle_b", middle_b, "vec", ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0))
            center_b = middle_b - ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0)
            #print("center_b=",center_b)
            va_p = rh*_vec(-va[1],va[0])  # perpendicular to linesegment pointing to center
            middle_a = (vi + vj)/2
            #print("middle_a", middle_a, "vec", ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0))
            center_a = middle_a + ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0)
            #print("center_a=",center_a)
            center_ab = center_b-center_a
            #print("center_ab=",center_ab, _unit(center_ab,axis=0))
            d2 = _length2(center_ab,axis=0)
            if d2 < 1e-10:
                out.append(points[i])
                continue
            a2 = (abs(points[i][2]) - radius) **2
            b2 = (abs(points[k][2]) - radius) **2
            x = (d2 + a2 - b2) / (2 * (d2**0.5))
            h = (a2 - x**2) ** 0.5
            #print("a2=",a2,"b2=",b2,"d2=",d2,"x=",x,"h=",h, )
            c2 = center_a + x*_unit(center_ab,axis=0) + rh*h*_unit(_vec(center_ab[1],-center_ab[0]),axis=0)
            #print("first",x*_unit(center_ab,axis=0),"second",h*_unit(_vec(center_ab[1],-center_ab[0]),axis=0))
            #print("c2=",c2)
            p0 = -radius*_unit(center_a-c2,axis=0)+c2
            #print("p0=",p0)
            p1 = -radius*_unit(center_b-c2,axis=0)+c2
            #print("p1=",p1)
            out.append(np.array([p0[0],p0[1],points[i][2]]))
            out.append(np.array([p1[0],p1[1],-rh*radius]))
        elif (rh*points[i][2] < 0) & (rh*points[k][2] > 0):
            #print("found concave-convex", vi)
            vb_p = rh*_vec(-vb[1],vb[0])  # perpendicular to linesegment pointing to center
            middle_b = (vi + vk)/2
            #print("middle_b", middle_b, "vec", ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0))
            center_b = middle_b + ((points[k][2]**2 - (_length(vb,axis=0)/2)**2) ** 0.5) * _unit(vb_p,axis=0)
            #print("center_b=",center_b)
            va_p = rh*_vec(-va[1],va[0])  # perpendicular to linesegment pointing to center
            middle_a = (vi + vj)/2
            #print("middle_a", middle_a, "vec", ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0))
            center_a = middle_a + ((points[i][2]**2 - (_length(va,axis=0)/2)**2) ** 0.5) * _unit(va_p,axis=0)
            #print("center_a=",center_a)
            center_ab = center_b-center_a
            #print("center_ab=",center_ab, _unit(center_ab,axis=0))
            d2 = _length2(center_ab,axis=0)
            if d2 < 1e-10:
                out.append(points[i])
                continue
            a2 = (abs(points[i][2]) - radius) **2
            b2 = (abs(points[k][2]) + radius) **2
            x = (d2 + a2 - b2) / (2 * (d2**0.5))
            h = (a2 - x**2) ** 0.5
            #print("a2=",a2,"b2=",b2,"d2=",d2,"x=",x,"h=",h, )
            c2 = center_a + x*_unit(center_ab,axis=0) - rh*h*_unit(_vec(center_ab[1],-center_ab[0]),axis=0)
            #print("first",x*_unit(center_ab,axis=0),"second",h*_unit(_vec(center_ab[1],-center_ab[0]),axis=0))
            #print("c2=",c2)
            #p0 = c2
            p0 = -radius*_unit(center_a-c2,axis=0)+c2
            #print("p0=",p0)
            p1 = radius*_unit(center_b-c2,axis=0)+c2
            #print("p1=",p1)
            out.append(np.array([p0[0],p0[1],points[i][2]]))
            out.append(np.array([p1[0],p1[1],-rh*radius]))
        elif (points[k][2] == 0) | ((rh*points[i][2] > 0) & (rh*points[k][2] < 0)):
            #print([
            #    [vk[0],vk[1],0],
            #    [vi[0],vi[1],0],
            #    [vj[0],vj[1],-points[i][2]]
            #  ], [radius], [1])
            p = round_polygon_corners([
                [vk[0],vk[1],0],
                [vi[0],vi[1],-points[k][2]],
                [vj[0],vj[1],-points[i][2]]
              ], [radius], [1])
            #print("p",p)
            out.append(np.array([p[2][0],p[2][1],points[i][2]]))
            out.append(np.array([p[1][0],p[1][1],-rh*radius]))
        else:
            out.append(points[i])

        #va_p = np.sign(points[i][2]) * _vec(-va[1],va[0])
        #vb_p = np.sign(points[k][2]) * _vec(-vb[1],vb[0])

        #va_middle = (vi + vj)/2
        #vb_middle = (vi + vk)/2

        #e = vj - vi
        #va_center = va_middle - ((curve**2 - seg_len**2) ** 0.5) * t / (np.dot(t,t) ** 0.5)

        #if points[j][2] != 0:
        #    vap = _project(vb,[va[1],-va[0]])
        #    vj_curve = 

        #if reverse == False:
        #    out.append(np.array([p0[0],p0[1],points[j][2]]))
        #    out.append(np.array([p1[0],p1[1],rh_radius]))
        #else:
        #    out.append(np.array([p1[0],p1[1],points[j][2]]))
        #    out.append(np.array([p0[0],p0[1],rh_radius]))
    return np.vstack(out).tolist()

def rounded_cog(outer_r, cog_r, num, center=ORIGIN):
    half_ang = 360/num/4
    b = outer_r - cog_r
    f = sinD(half_ang)*b
    if (cog_r <= 0) | (outer_r <= 0):
        raise Exception("rounded_cog: radii must be positive")
    if cog_r <= f:
        raise Exception("rounded_cog: cog radius too small")
    outer_center = (b**2-f**2)**0.5+(cog_r**2-f**2)**0.5
    pts = [[outer_r, 0, cog_r]]
    s = 1
    for i in range(2*num):
        if (i % 2 == 0) & (i > 0):
            pts = np.vstack((pts,[
                outer_r*cosD((i*2)*half_ang),
                outer_r*sinD((i*2)*half_ang),
                s*cog_r]))
        pts = np.vstack((pts,[
                outer_center*cosD((i*2+1)*half_ang),
                outer_center*sinD((i*2+1)*half_ang),
                s*cog_r]))
        s = -s
    pts = round_polygon_smooth_ends(pts, list(range(1,3*num,3)))
    return rounded_polygon(pts)
    # TODO: simplify this function into angle driven
    #def fun(p):
    #    p_ang = np.arctan2(p[:,1]-center[1],p[:,0]-center[0])
    #    p_ang = half_ang - np.abs(np.mod(p_ang,2*half_ang) - half_ang)
    #    p_len = _length(p - center)
    #    px = np.sin(p_ang)*p_len
    #    py = np.cos(p_ang)*p_len
    #    return _length(p - center) - radius
    #return fun


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
def edge(other, width):
    def f(p):
        return np.abs(other(p)) - width
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
def rotateD(other, angle):
    s = np.sin(angle*(180/np.pi))
    c = np.cos(angle*(180/np.pi))
    #m = 1 - c
    matrix = np.array([
        [c, -s],
        [s, c],
    ]).T
    def f(p):
        return other(np.dot(p, matrix))
    return f

@op2
def mirror(other, axis=Y, center=ORIGIN):
    u = _normalize(np.array(axis))
    #m = 1 - c
    matrix_a = np.array([
        [u[0], u[1]],
        [-u[1], u[0]],
    ]).T
    matrix_b = [[-1,0],[0,1]]
    matrix_c = np.array([
        [u[0], -u[1]],
        [u[1], u[0]],
    ]).T
    # Create the overall transformation matrix
    matrix = np.matmul(np.matmul(matrix_a,matrix_b),matrix_c)
    def f(p):
        return other(np.dot(p-center, matrix)+center)
    return f

@op2
def mirror_copy(other, axis=Y, center=ORIGIN):
    u = _normalize(np.array(axis))
    #m = 1 - c
    matrix_a = np.array([
        [u[0], u[1]],
        [-u[1], u[0]],
    ]).T
    matrix_b = [[-1,0],[0,1]]
    matrix_c = np.array([
        [u[0], -u[1]],
        [u[1], u[0]],
    ]).T
    # Create the overall transformation matrix
    matrix = np.matmul(np.matmul(matrix_a,matrix_b),matrix_c)
    def f(p):
        return _min(other(np.dot(p-center, matrix)+center),other(p))
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
def rounded_extrude_stack(obj1,obj2,h1,h2,radius=1,weld_radius=None):
    h_mid = (h1+h2)/2
    if weld_radius is None:
      weld_radius = radius

    def f(p):
        d1 = obj1(p[:,[0,1]]).reshape(-1)
        d2 = obj2(p[:,[0,1]]).reshape(-1)
        mid_d = (d2-d1)/2

        w = (p[:,2]) - h1
        out = np.abs(p[:,2] - h_mid) - h_mid

        # top of bottom
        xyplane = (d2 <= 0) & (d1 > 0)
        out[xyplane] = np.abs(w[xyplane]-h2/2) - h2/2
        xyplane = (d2 > 0) & (d1 <= 0)
        out[xyplane] = np.abs(w[xyplane]+h1/2) - h1/2

        # sides of bottom
        side = (w < 0) & (w > -h1)
        out[side] = _mindist(d1[side],out[side])
        # sides of top
        side = (w > 0) & (w < h2)
        out[side] = _mindist(d2[side],out[side])

        # top crown space
        crown = (w > h2-radius) & (d2 > -radius)
        out[crown] = _length(_vec(_max(d2[crown]+radius,0),_max(w[crown]-h2+radius,0))) - radius
        # top bottom-crown space
        #crown = (w < radius) & (w > 0) & (d2 > -radius) & (mid_d < 0) & (d1 > 0)
        crown = (w <= radius) & (d2 > -radius) & (mid_d < 0) & (d1 > 0)
        crown_radius = _min(-mid_d[crown],radius)
        out[crown & (d2 <= 0) & (w >= 0)] = 2*radius
        out[crown] = _min(_length(_vec(_max(d2[crown]+crown_radius,0),_max(-w[crown]+crown_radius,0))) - crown_radius, out[crown])
        # bottom top-crown space
        #crown = (w > -radius) & (w <= 0) & (d1 >= -radius) & (mid_d > 0) & (d2 > 0)
        crown = (w >= -radius) & (d1 >= -radius) & (mid_d >= 0) & (d2 > 0)
        crown_radius = _min(mid_d[crown],radius)
        out[crown & (d1 <= 0) & (w <= 0)] = 2*radius
        out[crown] = _min(_length(_vec(_max(d1[crown]+crown_radius,0),_max(w[crown]+crown_radius,0))) - crown_radius, out[crown])
        # bottom bottom-crown space
        crown = (-w > h1-radius) & (d1 > -radius)
        out[crown] = _length(_vec(_max(d1[crown]+radius,0),_max(-w[crown]-h1+radius,0))) - radius

        # weld top joint
        g = _max(weld_radius**2 - _max(weld_radius - np.abs(mid_d),0)**2,0)**0.5
        mid = (mid_d > 0) & (d2 < weld_radius) & (abs(w) < g) & ((d2 < mid_d + w * (weld_radius-mid_d)/_max(g,1e-20)))
        out[mid] = _min(weld_radius - ((g[mid] - w[mid])**2+(weld_radius-d2[mid])**2)**0.5, out[mid])

        # weld bottom joint
        mid = (mid_d < 0) & (d1 < weld_radius) & (abs(w) < g) & ((d1 < -mid_d - w * (weld_radius+mid_d)/_max(g,1e-20)))
        out[mid] = _min(weld_radius - ((g[mid] + w[mid])**2+(weld_radius-d1[mid])**2)**0.5, out[mid])

        return out
    return f

@op23
def rounded_extrude(other,h,radius=1):
    if radius == 0:
        return extrude(other,h)
    elif radius > 0:
        def f(p):
            d = other(p[:,[0,1]]).reshape(-1)
            w = np.abs(p[:,2]) - h/2
            out = _mindist(w,d)
            # head space
            #head = (w > -2*radius) & (w <= -radius) & (d >= -radius) & (d <= 0)
            #out[head] = _max(w[head] + (radius - (radius**2 - (radius + d[head])**2)**0.5), d[head])
            # crown space
            crown = np.logical_and(w > -radius,d > -radius)
            out[crown] = _length(_vec(_max(d[crown]+radius,0),_max(w[crown]+radius,0))) - radius
            return out
        return f
    elif radius < 0:
        radius = -radius
        def f(p):
            d = other(p[:,[0,1]]).reshape(-1)
            w = np.abs(p[:,2]) - h/2
            out = _mindist(w,d)
            # inside space
            inside = (w <= 0) & (d <= 0)
            out[inside] = _max(radius - _length(_vec(d[inside], w[inside])), out[inside])
            # crown space
            crown = (w+radius > 0) & (d >= 0) & (w <= d)
            out[crown] = _length(_vec(d[crown], w[crown]+radius))
            crown = (w >= 0) & (d+radius > 0) & (d <= w)
            out[crown] = _length(_vec(d[crown]+radius, w[crown]))
            return out
        return f


@op23
def taper_extrude(other, h, slope=0, e=ease.linear):
    def f(p):
        d = other(p[:,[0,1]]).reshape(-1) + e(np.clip(p[:,2]/h,0,1))*h*slope
        w = _vec(d, np.abs(p[:,2] - h/2) - h / 2)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
    return f

@op23
def scale_extrude(other, h, top=1, bottom=1, e=ease.linear):
    def f(p):
        q = e(np.clip(p[:,[2]]/h,0,1))
        sc = ((1 - q)*top + q * bottom)
        d = other(p[:,[0,1]] * sc) / sc
        w = _vec(d.reshape(-1), np.abs(p[:,2] - h/2) - h / 2)
        return _min(_max(w[:,0], w[:,1]), 0) + _length(_max(w, 0))
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

def arc_sinD(slope):
    return np.arcsin(slope)*(180.0/np.pi)
def arc_cosD(slope):
    return np.arccos(slope)*(180.0/np.pi)
def arc_tanD(slope):
    return np.arctan(slope)*(180.0/np.pi)
def arc_tan2D(y,x):
    return np.arctan2(y,x)*(180.0/np.pi)
def sinD(ang):
    return np.sin(ang*(np.pi/180))
def cosD(ang):
    return np.cos(ang*(np.pi/180))
def tanD(ang):
    return np.tan(ang*(np.pi/180))
def arc_lenD(ang, radius):
    return 2*radius*sinD(ang/2)
def arc_depthD(ang, radius):
    return radius*(1-cosD(ang/2))
