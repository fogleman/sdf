from sdf import *

sdf = smooth_difference(
    0.05,
    smooth_intersection(0.05, box(2), sphere((0, 0, 0), 1.25)),
    capsule((-2, 0, 0), (2, 0, 0), 0.5),
    capsule((0, -2, 0), (0, 2, 0), 0.5),
    capsule((0, 0, -2), (0, 0, 2), 0.5),
)

save('example.stl', sdf, verbose=True)
