from sdf import *

s = sphere(0.75)
s = s.translate(Z * -3) | s.translate(Z * 3)
s = s.union(capsule(Z * -3, Z * 3, 0.5), k=1)

f = sphere(1.5).union(s.orient(X), s.orient(Y), s.orient(Z), k=1)

f.save('blobby.stl', samples=2**26)
