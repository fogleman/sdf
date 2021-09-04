from sdf import *
  
t = torus(2, 0.5)
f = union(
    t.orient(X),
    t.orient(Y),
    t.orient(Z),
    k=0.1,
)

f.show()