# sdf
`sdf` is a library for generating Signed Distance Fields in Python 3.

## Installation
Download and navigate to this repository, then run
```python3 setup.py install```

## Documentation
 * /docs folder

## Basic Usage
```python
from sdf import *

f = sphere(1) & box(1.5)

c = cylinder(0.5)
f -= c.orient(X) | c.orient(Y) | c.orient(Z)

f.save('out.stl')
```

## 2D Primitives
 * Circle
 * Plane
 * Slab
 * Box
 * AABB
 * Rounded Box
 * Equilateral Triangle
 * Hexagon
 * Rounded X


## 3D Primitives
 * Sphere
 * Plane
 * Slab
 * Box
 * AABB
 * Rounded Box
 * Bounding Box
 * Torus
 * Capsule
 * Cylinder
 * Capped Cylinder
 * Rounded Cylinder
 * Capped Cone
 * Rounded Cone
 * Ellipsoid
 * Pyramid
 * Tetrahedron
 * Octahedron
 * Dodecahedron
 * Icosahedron

## Operations
 * Union (`|`)
 * Difference (`-`)
 * Intersection (`&`)

## Positioning Functions
 * Translate 
 * Scale
 * Rotate
 * Rotate To (3D only)
 * Orient (3D only)
 * Circular Array

## Alterations
 * Elongate
 * Twist
 * Bend
 * Transition
 * Slice (3D -> 2D)
 * Extrude (2D -> 3D)
 * Revolve (2D -> 3D)

## Constants
 * `X` : (1, 0, 0)
 * `Y` : (0, 1, 0)
 * `Z` : (0, 0, 1)
 * `UP` : A pseudonym for `Z`
 * `ORIGIN` : (0, 0, 0)