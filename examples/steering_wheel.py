from sdf import *

# Simple wheel with finger indents
finger_r = 30   # radius of finger indent
n = 16          # number of finger indents

spoke_angles = [0, 80, 160]

# Draw the outer edge of the wheel with finger indents
pts = [[0, 10, 0]]
s = -1
for i in range(0,2*n):
    pts = np.vstack((pts,[20*i, -10 ,s*finger_r]))
    s = -s
pts = np.vstack((pts,[20*(2*n-1), 10, 0]))

# Make the inner finger indent smooth
ring = rounded_polygon(pts)

# Wrap the steering wheel around
f = ring.rounded_extrude(20,10).rotateD(-90,X).wrap_around(10, 20*(2*n-2))

wheel_r = (20*(2*n-2)-10)/np.pi/2

# Create a 2d plane for carving out the spokes
spokes = circle(wheel_r)

inner_r = wheel_r - 10
center_r = 30   # center of steering wheel
rounding_r = 10 # cutout rounding
spoke_thickness = 20

# Determine the angle for the spokes of the wheel for cutting out
delta_inner_ang = arc_sinD((spoke_thickness/2) / inner_r)
delta_center_ang = arc_sinD((spoke_thickness/2) / center_r)

# Cut out the holes in the middle of the ring leaving the spokes
for i in range(len(spoke_angles)):
    j = (i + 1) % len(spoke_angles)
    ang1 = spoke_angles[i]
    ang2 = spoke_angles[j]
    if ang2 < ang1:
        ang2 = ang2 + 360
    # Draw a polygon around the holes and create a center point to allow angles
    # of spokes beyond 180 degrees
    spokes -= rounded_polygon(round_polygon_corners([
        [inner_r*cosD(ang1+delta_inner_ang),inner_r*sinD(ang1+delta_inner_ang),0],
        [inner_r*cosD((ang1+ang2)/2),inner_r*sinD((ang1+ang2)/2),inner_r],
        [inner_r*cosD(ang2-delta_inner_ang),inner_r*sinD(ang2-delta_inner_ang),inner_r],
        [center_r*cosD(ang2-delta_center_ang),center_r*sinD(ang2-delta_center_ang),0],
        [center_r*cosD((ang1+ang2)/2),center_r*sinD((ang1+ang2)/2),-center_r],
        [center_r*cosD(ang1+delta_center_ang),center_r*sinD(ang1+delta_center_ang),-center_r]
      ], rounding_r))

f |= spokes.rounded_extrude(15,7.5).bend_radial(inner_r*.31,inner_r*0.81,10,ease.in_out_quad).translate((0,0,-10)).k(5)
f.save('/dev/shm/steering_wheel.stl', samples=2**21)

