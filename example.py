from sdf import *

f = sphere(1) & box(0.75)

c = cylinder(0.5)
f -= c.orient('x') | c.orient('y') | c.orient('z')

f.save('out.stl', verbose=True)
