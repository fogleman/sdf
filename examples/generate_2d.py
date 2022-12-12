from sdf import *
import numpy as np

f = rectangle(1) - circle(0.5)
points = f.generate(workers=1)

print(np.array(points).shape)
