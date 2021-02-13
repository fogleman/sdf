from sdf import *

def section(z0, z1, d0, d1, e=ease.linear):
    f = cylinder(d0/2).transition(
        cylinder(d1/2), Z * z0, Z * z1, e)
    return f & slab(z0=z0, z1=z1)

f = section(0, 0.2, 1, 1.25)
f |= section(0.2, 0.3, 1.25, 1).k(0.05)
f |= rounded_cylinder(0.6, 0.1, 0.2).translate(Z * 0.4).k(0.05)
f |= section(0.5, 1.75, 1, 0.25, ease.out_quad).k(0.01)
f |= section(1.75, 1.85, 0.25, 0.5).k(0.01)
f |= section(1.85, 1.90, 0.5, 0.25).k(0.05)
f |= sphere(0.3).translate(Z * 2.15).k(0.05)

f.save('pawn.stl', samples=2**26)
