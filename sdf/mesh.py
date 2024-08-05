from scipy import interpolate

import numpy as np
import threading

from .d3 import sdf3, box

# TODO: allow transforming mesh
class Mesh:
    @classmethod
    def from_file(cls, path):
        import meshio

        mesh = meshio.read(path)

        points = mesh.points
        triangles = mesh.cells[0].data

        return cls(points, triangles)

    def __init__(self, points, triangles):
        self.points = points
        self.triangles = triangles

    @property
    def size(self):
        a = self.points.min(axis=0)
        b = self.points.max(axis=0)
        return tuple((b - a).tolist())

    @property
    def bounding_box(self):
        a = tuple(self.points.min(axis=0).tolist())
        b = tuple(self.points.max(axis=0).tolist())
        return (a, b)

    def scaled(self, scale):
        try:
            sx, sy, sz = scale
        except TypeError:
            sx = sy = sz = scale
        points = self.points * (sx, sy, sz)
        return Mesh(points, self.triangles)

    @sdf3
    def sdf(self, voxel_size, half_width=None):
        import pyopenvdb as vdb

        a, b = self.bounding_box
        estimator = box(a=a, b=b)

        transform = vdb.createLinearTransform(voxelSize=voxel_size)

        half_width_voxels = 3
        if half_width is not None:
            half_width_voxels = max(
                half_width_voxels, int(np.ceil(half_width / voxel_size)))

        grid = vdb.FloatGrid.createLevelSetFromPolygons(
            self.points, triangles=self.triangles,
            transform=transform, halfWidth=half_width_voxels)

        v0, v1 = grid.evalActiveVoxelBoundingBox()
        ijk0 = np.array(v0, dtype=int)
        ijk1 = np.array(v1, dtype=int)
        size = ijk1 - ijk0 + 1

        p0 = grid.transform.indexToWorld(ijk0)
        p1 = grid.transform.indexToWorld(ijk1)
        X = np.linspace(p0[0], p1[0], size[0])
        Y = np.linspace(p0[1], p1[1], size[1])
        Z = np.linspace(p0[2], p1[2], size[2])

        A = np.zeros(size, dtype=np.float32)
        grid.copyToArray(A, ijk=ijk0)

        interpolator = interpolate.RegularGridInterpolator(
            (X, Y, Z), A, bounds_error=False, fill_value=grid.background)

        # num_voxels = size[0] * size[1] * size[2]
        # print('mesh voxels = %d' % num_voxels)

        def f(p):
            e = estimator(p)
            d = interpolator(p).reshape((-1, 1))
            return np.where(e > grid.background, e, d)

        return f
