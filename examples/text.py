from sdf import *

f = rounded_box((7, 2, 0.2), 0.1)
f -= text('Arial', 'Hello, world!').extrude(1)
f.save('text.stl')
