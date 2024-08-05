from sdf import *
import sys

def hollowed_with_cross_hatch_ribs(f, shell_thickness, rib_width, rib_height, rib_spacing):
    # make infinite cross-hatch rib pattern
    d = rib_width / 2
    rib = slab(z0=-d, z1=d).repeat(rib_spacing)
    rib = rib.rotate(np.pi / 4, Y) | rib.rotate(-np.pi / 4, Y)

    # intersect ribs with a shelled version of the input mesh
    d = rib_height
    rib &= f.erode(d / 2).shell(d)

    # final object is a thinner-shelled version of the mesh plus the ribs
    d = shell_thickness
    f = f.erode(d / 2).shell(d) | rib

    return f

def hollowed(f, shell_thickness):
    d = shell_thickness
    return f.erode(d / 2).shell(d)

def main():
    mesh = Mesh.from_file(sys.argv[1])

    f = mesh.sdf(voxel_size=0.25, half_width=1)

    shell_thickness = 0.5
    # rib_width = 0.5
    # rib_height = 1
    # rib_spacing = 4
    # f = hollowed_with_cross_hatch_ribs(
    #     f, shell_thickness, rib_width, rib_height, rib_spacing)

    f = hollowed(f, shell_thickness)

    f &= slab(y0=0)

    # f = f.rotate(np.pi/4)
    # f = f.twist(np.pi / 2 / 48)
    # f = f.circular_array(5, 4.0)
    # f = f.elongate((10, 10, 1))

    f.save('out.stl', step=0.25)

if __name__ == '__main__':
    main()
