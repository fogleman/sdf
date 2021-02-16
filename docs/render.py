from sdf import *
import os

def generate(f, name, samples=2**26, **kwargs):
    os.makedirs('models', exist_ok=True)
    os.makedirs('images', exist_ok=True)
    stl_path = 'models/%s.stl' % name
    png_path = 'images/%s.png' % name
    if os.path.exists(png_path):
        return
    render_cmd = './render %s %s' % (stl_path, png_path)
    f.save(stl_path, samples=samples, **kwargs)
    os.system(render_cmd)

# example
f = sphere(1) & box(1.5)
c = cylinder(0.5)
f -= c.orient(X) | c.orient(Y) | c.orient(Z)
example = f
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

# blend(a, *bs, k=0.5)
f = sphere().blend(box())
generate(f, 'blend')

# dilate(other, r)
f = example.dilate(0.1)
generate(f, 'dilate')

# erode(other, r)
f = example.erode(0.1)
generate(f, 'erode')

# shell(other, thickness)
f = sphere().shell(0.05) & plane(-Z)
generate(f, 'shell')

# elongate(other, size)
f = example.elongate((0.25, 0.5, 0.75))
generate(f, 'elongate')

# twist(other, k)
f = box().twist(pi / 2)
generate(f, 'twist')

# bend(other, k)
f = box().bend(1)
generate(f, 'bend')

# bend_linear(other, p0, p1, v, e=ease.linear)
f = capsule(-Z * 2, Z * 2, 0.25).bend_linear(-Z, Z, X, ease.in_out_quad)
generate(f, 'bend_linear')

# bend_radial(other, r0, r1, dz, e=ease.linear)
f = box((5, 5, 0.25)).bend_radial(1, 2, -1, ease.in_out_quad)
generate(f, 'bend_radial', sparse=False)

# transition_linear(f0, f1, p0=-Z, p1=Z, e=ease.linear)
f = box().transition_linear(sphere(), e=ease.in_out_quad)
generate(f, 'transition_linear')

# transition_radial(f0, f1, r0=0, r1=1, e=ease.linear)
f = box().transition_radial(sphere(), e=ease.in_out_quad)
generate(f, 'transition_radial')

# extrude(other, h)
f = hexagon(1).extrude(1)
generate(f, 'extrude')

# extrude_to(a, b, h, e=ease.linear)
f = rectangle(2).extrude_to(circle(1), 2, ease.in_out_quad)
generate(f, 'extrude_to')

# revolve(other, offset=0)
f = hexagon(1).revolve(3)
generate(f, 'revolve')

# slice(other)
f = example.translate((0, 0, 0.55)).slice().extrude(0.1)
generate(f, 'slice')

# text(name, text, width=None, height=None, texture_point_size=512)
f = rounded_box((7, 2, 0.2), 0.1)
f -= text('Georgia', 'Hello, World!').extrude(0.2).rotate(pi).translate(0.1 * Z)
generate(f, 'text')

# wrap_around(other, x0, x1, r=None, e=ease.linear)
FONT = 'Arial'
TEXT = ' wrap_around ' * 3
w, h = measure_text(FONT, TEXT)
f = text(FONT, TEXT).extrude(0.1).orient(Y).wrap_around(-w / 2, w / 2)
generate(f, 'wrap_around')
