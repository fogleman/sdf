from sdf import *
import os

def generate(f, name, samples=2**26):
    os.makedirs('models', exist_ok=True)
    os.makedirs('images', exist_ok=True)
    stl_path = 'models/%s.stl' % name
    png_path = 'images/%s.png' % name
    render_cmd = './render %s %s' % (stl_path, png_path)
    f.save(stl_path, samples=samples)
    os.system(render_cmd)

# example
f = sphere(1) & box(1.5)
c = cylinder(0.5)
f -= c.orient(X) | c.orient(Y) | c.orient(Z)
generate(f, 'example')

# sphere
f = sphere(1)
generate(f, 'sphere')

# box
f = box(1)
generate(f, 'box')

f = box((1, 2, 3))
generate(f, 'box2')
