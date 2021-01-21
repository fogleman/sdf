import numpy as np

def _checked(f):
    def wrapper(*args, **kwargs):
        return f(*args, **kwargs).reshape((-1, 1))
    return wrapper

def _length(a):
    return np.linalg.norm(a, axis=1)

def _normalize(a):
    return a / _length(a)

def _dot(a, b):
    return np.sum(a * b, axis=1)

def sphere(center, radius):
    @_checked
    def f(p):
        return _length(p - center) - radius
    return f

def box(size):
    size = np.array(size) / 2
    @_checked
    def f(p):
        q = np.abs(p) - size
        return _length(np.maximum(q, 0)) + np.minimum(np.amax(q, axis=1), 0)
    return f

def aabb(a, b):
    a = np.array(a)
    b = np.array(b)
    size = b - a
    offset = a + size / 2
    return translate(offset, box(size))

def round_box(size, radius):
    size = np.array(size) / 2
    @_checked
    def f(p):
        q = np.abs(p) - size
        return _length(np.maximum(q, 0)) + np.minimum(np.amax(q, axis=1), 0) - radius
    return f

def torus(r1, r2):
    @_checked
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
    @_checked
    def f(p):
        pa = p - a
        ba = b - a
        h = np.clip(np.dot(pa, ba) / np.dot(ba, ba), 0, 1).reshape((-1, 1))
        return _length(pa - np.multiply(ba, h)) - radius
    return f

def capped_cylinder(a, b, radius):
    a = np.array(a)
    b = np.array(b)
    @_checked
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

def rounded_cylinder(ra, rb, h):
    @_checked
    def f(p):
        d = np.stack([
            _length(p[:,[0,2]]) - 2 * ra + rb,
            np.abs(p[:,1]) - h], axis=-1)
        return (
            np.minimum(np.maximum(d[:,0], d[:,1]), 0) +
            _length(np.maximum(d, 0)) - rb)
    return f

def capped_cone(a, b, ra, rb):
    a = np.array(a)
    b = np.array(b)
    @_checked
    def f(p):
        rba = rb - ra
        baba = np.dot(b - a, b - a)
        papa = _dot(p - a, p - a)
        paba = np.dot(p - a, b - a) / baba
        x = np.sqrt(papa - paba * paba * baba)
        cax = np.maximum(0, x - np.where(paba < 0.5, ra, rb))
        cay = np.abs(paba - 0.5) - 0.5
        k = rba * rba + baba
        f = np.clip((rba * (x - ra) + paba * baba) / k, 0, 1)
        cbx = x - ra - f * rba
        cby = paba - f
        s = np.where(np.logical_and(cbx < 0, cay < 0), -1, 1)
        return s * np.sqrt(np.minimum(
            cax * cax + cay * cay * baba,
            cbx * cbx + cby * cby * baba))
    return f

def ellipsoid(size):
    size = np.array(size)
    @_checked
    def f(p):
        k0 = _length(p / size)
        k1 = _length(p / (size * size))
        return k0 * (k0 - 1) / k1
    return f

def pyramid(h):
    @_checked
    def f(p):
        a = np.abs(p[:,[0,2]]) - 0.5
        w = a[:,1] > a[:,0]
        a[w] = a[:,[1,0]][w]
        px = a[:,0]
        py = p[:,1]
        pz = a[:,1]
        m2 = h * h + 0.25
        qx = pz
        qy = h * py - 0.5 * px
        qz = h * px + 0.5 * py
        s = np.maximum(-qx, 0)
        t = np.clip((qy - 0.5 * pz) / (m2 + 0.25), 0, 1)
        a = m2 * (qx + s) ** 2 + qy * qy
        b = m2 * (qx + 0.5 * t) ** 2 + (qy - m2 * t) ** 2
        d2 = np.where(
            np.minimum(qy, -qx * m2 - qy * 0.5) > 0,
            0, np.minimum(a, b))
        return np.sqrt((d2 + qz * qz) / m2) * np.sign(np.maximum(qz, -py))
    return f

def octahedron(s):
    @_checked
    def f(p):
        return (np.sum(np.abs(p), axis=1) - s) * 0.57735027
    return f

def union(a, *bs):
    @_checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = np.minimum(d1, d2)
        return d1
    return f

def difference(a, *bs):
    @_checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = np.maximum(d1, -d2)
        return d1
    return f

def intersection(a, *bs):
    @_checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            d1 = np.maximum(d1, d2)
        return d1
    return f

def smooth_union(k, a, *bs):
    @_checked
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
    @_checked
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
    @_checked
    def f(p):
        d1 = a(p)
        for b in bs:
            d2 = b(p)
            h = np.clip(0.5 - 0.5 * (d2 - d1) / k, 0, 1)
            m = d2 + (d1 - d2) * h
            d1 = m + k * h * (1 - h)
        return d1
    return f

def blend(k, a, b):
    @_checked
    def f(p):
        return k * b(p) + (1 - k) * a(p)
    return f

def translate(offset, sdf):
    @_checked
    def f(p):
        return sdf(p - offset)
    return f

def scale(factor, sdf):
    try:
        x, y, z = factor
    except TypeError:
        x = y = z = factor
    @_checked
    def f(p):
        return sdf(p / (x, y, z))
    return f

def rotate(vector, angle, sdf):
    x, y, z = _normalize(np.array(vector).reshape(1, -1))[0]
    s = np.sin(angle)
    c = np.cos(angle)
    m = 1 - c
    matrix = np.array([
        [m*x*x + c, m*x*y + z*s, m*z*x - y*s],
        [m*x*y - z*s, m*y*y + c, m*y*z + x*s],
        [m*z*x + y*s, m*y*z - x*s, m*z*z + c],
    ]).T
    @_checked
    def f(p):
        return sdf(np.dot(p, matrix))
    return f

def repeat(count, spacing, sdf):
    count = np.array(count)
    spacing = np.array(spacing)
    @_checked
    def f(p):
        q = p - spacing * np.clip(np.round(p / spacing), -count, count)
        return sdf(q)
    return f

def elongate(size, sdf):
    @_checked
    def f(p):
        q = np.abs(p) - size
        x = q[:,0].reshape((-1, 1))
        y = q[:,1].reshape((-1, 1))
        z = q[:,2].reshape((-1, 1))
        w = np.minimum(np.maximum(x, np.maximum(y, z)), 0)
        return sdf(np.maximum(q, 0)) + w
    return f

def twist(k, sdf):
    @_checked
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        c = np.cos(k * z)
        s = np.sin(k * z)
        x2 = c * x - s * y
        y2 = s * x + c * y
        z2 = z
        return sdf(np.stack([x2, y2, z2], axis=-1))
    return f

def bend(k, sdf):
    @_checked
    def f(p):
        x = p[:,0]
        y = p[:,1]
        z = p[:,2]
        c = np.cos(k * x)
        s = np.sin(k * x)
        x2 = c * x - s * y
        y2 = s * x + c * y
        z2 = z
        return sdf(np.stack([x2, y2, z2], axis=-1))
    return f

def onion(thickness, sdf):
    @_checked
    def f(p):
        return np.abs(sdf(p)) - thickness
    return f
