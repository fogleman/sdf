from sdf import *
import sys

def main():
    # load input mesh
    f = Mesh.from_file(sys.argv[1]).sdf(3)

    # make infinite cross-hatch rib pattern
    d = 0.5
    rib = slab(z0=-d, z1=d).repeat(5)
    rib = rib.rotate(np.pi / 4, Y) | rib.rotate(-np.pi / 4, Y)

    # intersect ribs with a shelled version of the input mesh
    d = 2
    rib &= f.erode(d / 2).shell(d)

    # final object is a thinner-shelled version of the mesh plus the ribs
    f = f.shell(1) | rib

    f &= slab(y0=-1)

    # convert SDF to STL
    f.save('out.stl', step=0.25, sparse=False)

if __name__ == '__main__':
    main()
