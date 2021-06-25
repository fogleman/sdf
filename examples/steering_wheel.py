from sdf import *

# Simple wheel with finger indents
outer_r = 100   # outer side of the outer ring
inner_r = 80    # inner side of the outer ring
center_r = 30   # center of steering wheel
rounding_r = 10 # cutout rounding
depth = 30      # thickness of the ring
depth_r = 10    # rounding on the depth

finger_r = 30   # radius of finger indent
n = 12          # number of finger indents

spokes = [0, 80, 160]
spoke_thickness = 20

# Draw the outer edge of the wheel with finger indents
pts = [[outer_r, 0, finger_r]]
s = -1
for i in range(1,2*n):
    pts = np.vstack((pts,[outer_r*cosD(i*360/(2*n)),outer_r*sinD(i*360/(2*n)),s*finger_r]))
    s = -s

# Make the inner finger indent smooth
pts = round_polygon_smooth_ends(pts, list(range(1,2*n,2)))
ring = rounded_polygon(pts)

# Determine the angle for the spokes of the wheel for cutting out
delta_inner_ang = arc_sinD((spoke_thickness/2) / inner_r)
delta_center_ang = arc_sinD((spoke_thickness/2) / center_r)

# Cut out the holes in the middle of the ring leaving the spokes
for i in range(len(spokes)):
    j = (i + 1) % len(spokes)
    ang1 = spokes[i]
    ang2 = spokes[j]
    if ang2 < ang1:
        ang2 = ang2 + 360
    # Draw a polygon around the holes and create a center point to allow angles
    # of spokes beyond 180 degrees
    ring -= rounded_polygon(round_polygon_corners([
        [inner_r*cosD(ang1+delta_inner_ang),inner_r*sinD(ang1+delta_inner_ang),0],
        [inner_r*cosD((ang1+ang2)/2),inner_r*sinD((ang1+ang2)/2),inner_r],
        [inner_r*cosD(ang2-delta_inner_ang),inner_r*sinD(ang2-delta_inner_ang),inner_r],
        [center_r*cosD(ang2-delta_center_ang),center_r*sinD(ang2-delta_center_ang),0],
        [center_r*cosD((ang1+ang2)/2),center_r*sinD((ang1+ang2)/2),-center_r],
        [center_r*cosD(ang1+delta_center_ang),center_r*sinD(ang1+delta_center_ang),-center_r]
      ], rounding_r))


f = ring.rounded_extrude(depth,depth_r)

f.save('steering_wheel_1.stl', samples=2**23)
