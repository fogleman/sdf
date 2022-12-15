from sdf import *

f = circle(3).taper_extrude(5,2.5/5,ease.out_quint)
f |= circle(3).taper_extrude(3,1,ease.linear).mirror([0,0,1])
f |= sphere(0.5).translate((0,0,5))
f.save('spinning_top.stl', samples=2**22)
