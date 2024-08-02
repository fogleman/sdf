from sdf import *
import meshio
import pyopenvdb as vdb
import sys

def main():
    args = sys.argv[1:]
    if len(args) != 1:
        print('Usage: python vdb.py input.stl')
        return

    mesh = meshio.read(args[0])

    points = mesh.points
    triangles = mesh.cells[0].data

    transform = vdb.createLinearTransform(voxelSize=0.25)

    grid = vdb.FloatGrid.createLevelSetFromPolygons(points, triangles=triangles, transform=transform, halfWidth=3)

    print(dir(grid))
    print(grid.evalActiveVoxelBoundingBox())

    points, triangles, quads = grid.convertToPolygons(adaptivity=0)
    triangles = triangles[:,[2,1,0]]
    triangles = np.concatenate([triangles, quads[:,[2,1,0]], quads[:,[0,3,2]]])
    cells = [
        ('triangle', triangles),
    ]
    mesh = meshio.Mesh(points, cells)
    mesh.write('out.stl')

if __name__ == '__main__':
    main()
