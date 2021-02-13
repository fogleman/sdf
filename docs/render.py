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
