from sdf import *

FONT = 'Arial'
TEXT = 'Hello, world!'

w, h = measure_text(FONT, TEXT)

f = rounded_box((w + 1, h + 1, 0.2), 0.1)
f -= text(FONT, TEXT).extrude(1)

f.save('text.stl')
