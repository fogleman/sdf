from functools import partial

from . import mesh, sdfs

_registered_sdfs = {}

class SDF:
    def __init__(self, f):
        self.f = f
    def __call__(self, p):
        return self.f(p).reshape((-1, 1))
    def __getattr__(self, name):
        if name in _registered_sdfs:
            f = _registered_sdfs[name]
            return partial(f, self)
        raise AttributeError
    def __or__(self, other):
        return sdfs.union(self, other)
    def __and__(self, other):
        return sdfs.intersection(self, other)
    def __sub__(self, other):
        return sdfs.difference(self, other)
    def union(self, *others, **kwargs):
        return sdfs.union(self, *others, **kwargs)
    def intersection(self, *others, **kwargs):
        return sdfs.intersection(self, *others, **kwargs)
    def difference(self, *others, **kwargs):
        return sdfs.difference(self, *others, **kwargs)
    def generate(self, *args, **kwargs):
        return mesh.generate(self, *args, **kwargs)
    def save(self, path, *args, **kwargs):
        return mesh.save(path, self, *args, **kwargs)

def sdf(f):
    def wrapper(*args, **kwargs):
        return SDF(f(*args, **kwargs))
    return wrapper

def registered_sdf(f):
    def wrapper(*args, **kwargs):
        return SDF(f(*args, **kwargs))
    _registered_sdfs[f.__name__] = wrapper
    return wrapper
