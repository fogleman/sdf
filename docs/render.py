from sdf import *
import os

def generate(f, name, samples=2**26):
    os.makedirs('models', exist_ok=True)
    os.makedirs('images', exist_ok=True)
    stl_path = 'models/%s.stl' % name
    png_path = 'images/%s.png' % name
    if os.path.exists(png_path):
        return
    render_cmd = './render %s %s' % (stl_path, png_path)
    f.save(stl_path, samples=samples)
    os.system(render_cmd)

# example
f = sphere(1) & box(1.5)
c = cylinder(0.5)
f -= c.orient(X) | c.orient(Y) | c.orient(Z)
generate(f, 'example')

# sphere(radius=1, center=ORIGIN)
f = sphere(1)
generate(f, 'sphere')

# box(size=1, center=ORIGIN, a=None, b=None)
f = box(1)
generate(f, 'box')

f = box((1, 2, 3))
generate(f, 'box2')

# rounded_box(size, radius)
f = rounded_box((1, 2, 3), 0.25)
generate(f, 'rounded_box')

# wireframe_box(size, thickness)
f = wireframe_box((1, 2, 3), 0.05)
generate(f, 'wireframe_box')

# torus(r1, r2)
f = torus(1, 0.25)
generate(f, 'torus')

# capsule(a, b, radius)
f = capsule(-Z, Z, 0.5)
generate(f, 'capsule')

# capped_cylinder(a, b, radius)
f = capped_cylinder(-Z, Z, 0.5)
generate(f, 'capped_cylinder')

# rounded_cylinder(ra, rb, h)
f = rounded_cylinder(0.5, 0.1, 2)
generate(f, 'rounded_cylinder')

# capped_cone(a, b, ra, rb)
f = capped_cone(-Z, Z, 1, 0.5)
generate(f, 'capped_cone')

# rounded_cone(r1, r2, h)
f = rounded_cone(0.75, 0.25, 2)
generate(f, 'rounded_cone')

# ellipsoid(size)
f = ellipsoid((1, 2, 3))
generate(f, 'ellipsoid')

# pyramid(h)
f = pyramid(1)
generate(f, 'pyramid')

# tetrahedron(r)
f = tetrahedron(1)
generate(f, 'tetrahedron')

# octahedron(r)
f = octahedron(1)
generate(f, 'octahedron')

# dodecahedron(r)
f = dodecahedron(1)
generate(f, 'dodecahedron')

# icosahedron(r)
f = icosahedron(1)
generate(f, 'icosahedron')

# plane(normal=UP, point=ORIGIN)
f = sphere() & plane()
generate(f, 'plane')

# slab(x0=None, y0=None, z0=None, x1=None, y1=None, z1=None, k=None)
f = sphere() & slab(z0=-0.5, z1=0.5, x0=0)
generate(f, 'slab')

# cylinder(radius)
f = sphere() - cylinder(0.5)
generate(f, 'cylinder')

# translate(other, offset)
f = sphere().translate((0, 0, 2))
generate(f, 'translate')

# scale(other, factor)
f = sphere().scale((1, 2, 3))
generate(f, 'scale')

# rotate(other, angle, vector=Z)
# rotate_to(other, a, b)
f = capped_cylinder(-Z, Z, 0.5).rotate(pi / 4, X)
generate(f, 'rotate')

# orient(other, axis)
c = capped_cylinder(-Z, Z, 0.25)
f = c.orient(X) | c.orient(Y) | c.orient(Z)
generate(f, 'orient')

# boolean operations

a = box((3, 3, 0.5))
b = sphere()

# union
f = a | b
generate(f, 'union')

# difference
f = a - b
generate(f, 'difference')

# intersection
f = a & b
generate(f, 'intersection')

# smooth union
f = a | b.k(0.25)
generate(f, 'smooth_union')

# smooth difference
f = a - b.k(0.25)
generate(f, 'smooth_difference')

# smooth intersection
f = a & b.k(0.25)
generate(f, 'smooth_intersection')

# repeat(other, spacing, count=None, padding=0)
f = sphere().repeat(3, (1, 1, 0))
generate(f, 'repeat')

# circular_array(other, count, offset)
f = capped_cylinder(-Z, Z, 0.5).circular_array(8, 4)
generate(f, 'circular_array')
