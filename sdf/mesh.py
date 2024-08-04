import numpy as np
import threading

from .d3 import sdf3, box

# Triangle Meshes

# TODO: support linear transformations on point batches
# TODO: make sure vdb grid aligns with sample grid
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
    def sdf(self, half_width=None):
        import pyopenvdb as vdb

        lock = threading.Lock()
        grids = {}

        def get_grid(step):
            with lock:
                if step not in grids:
                    dx, dy, dz = step
                    half_width_voxels = 3
                    if half_width is not None:
                        half_width_voxels = max(
                            half_width_voxels, int(np.ceil(half_width / min(dx, dy, dz))))
                    transform = vdb.createLinearTransform(
                        [[dx, 0, 0, 0], [0, dy, 0, 0], [0, 0, dz, 0], [0, 0, 0, 1]])
                    grid = vdb.FloatGrid.createLevelSetFromPolygons(
                        self.points, triangles=self.triangles,
                        transform=transform, halfWidth=half_width_voxels)
                    grids[step] = grid
                return grids[step]

        a, b = self.bounding_box
        estimator = box(a=a, b=b)

        def f(p):
            if not hasattr(p, 'info'):
                return estimator(p)
            grid = get_grid(p.info['step'])
            a = np.zeros(p.info['shape'])
            ijk = grid.transform.worldToIndex(p[0])
            ijk = [int(round(x)) for x in ijk]
            grid.copyToArray(a, ijk=ijk)
            return a

        return f
