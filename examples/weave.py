from sdf import *

f = rounded_box([3.2, 1, 0.25], 0.1).translate((1.5, 0, 0.0625))
f = f.bend_linear(X * 0.75, X * 2.25, Z * -0.1875, ease.in_out_quad)
f = f.circular_array(3, 0)

f = f.repeat((2.7, 5.4, 0), padding=1)
f |= f.translate((2.7 / 2, 2.7, 0))

f &= cylinder(10)
f |= (cylinder(12) - cylinder(10)) & slab(z0=-0.5, z1=0.5).k(0.25)

f.save('weave.stl')
