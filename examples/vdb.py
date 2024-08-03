from sdf import *
import meshio
import pyopenvdb as vdb
import sys
import threading

@sdf3
def mesh_from_file(path):
    mesh = meshio.read(path)

    points = mesh.points
    triangles = mesh.cells[0].data
    estimator = box(a=points.min(axis=0), b=points.max(axis=0))

    lock = threading.Lock()
    grids = {}

    def get_grid(voxel_size):
        with lock:
            if voxel_size not in grids:
                transform = vdb.createLinearTransform(voxelSize=voxel_size)
                grid = vdb.FloatGrid.createLevelSetFromPolygons(
                    points, triangles=triangles, transform=transform, halfWidth=3)
                grids[voxel_size] = grid
            return grids[voxel_size]

    def f(p):
        if not hasattr(p, 'info'):
            return estimator(p)
        nx = len(np.unique(p[:,0]))
        ny = len(np.unique(p[:,1]))
        nz = len(np.unique(p[:,2]))
        voxel_size = float((p[1] - p[0]).max()) if len(p) > 1 else 1
        voxel_size = round(voxel_size, 9)
        transform = vdb.createLinearTransform(voxelSize=voxel_size)
        grid = get_grid(voxel_size)
        a = np.zeros(nx * ny * nz).reshape((nx, ny, nz))
        ijk = transform.worldToIndex(p[0])
        ijk = [int(round(x)) for x in ijk]
        grid.copyToArray(a, ijk=ijk)
        return a

    return f

def main():
    f = mesh_from_file(sys.argv[1])
    # f = f.shell(0.25)
    f &= slab(y0=-2)
    f.save('out.stl', step=0.2, sparse=False)

if __name__ == '__main__':
    main()
