from sdf import *

f = sphere(2) & slab(z0=-0.5, z1=0.5).k(0.1)
f -= cylinder(1).k(0.1)
f -= cylinder(0.25).circular_array(16, 2).k(0.1)

f.save('gearlike.stl', samples=2**26)
