from sdf import *
from matplotlib import pyplot as plt

f = polygon([[0,0], [1,0], [0,1]]).translate([-3.5, -0.5]) | rectangle(1) |    circle(0.5).translate([3, 0])

f.show()
