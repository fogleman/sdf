from sdfs import *
from mesh import generate
from stl import write_binary_stl

RESOLUTION = 0.01

def main():
    sdf = smooth_difference(
        0.05,
        smooth_intersection(0.05, box(2), sphere((0, 0, 0), 1.25)),
        capsule((-2, 0, 0), (2, 0, 0), 0.5),
        capsule((0, -2, 0), (0, 2, 0), 0.5),
        capsule((0, 0, -2), (0, 0, 2), 0.5),
    )

    s = 1.1
    points = generate(
        sdf, -s, -s, -s, s, s, s, RESOLUTION, RESOLUTION, RESOLUTION)
    print(len(points) // 3, 'triangles')
    write_binary_stl('out.stl', points)

if __name__ == '__main__':
    main()
