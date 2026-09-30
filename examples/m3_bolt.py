from sdf import *

import numpy as np

# An M3 hexagon socket head cap screw (ISO 4762 / DIN 912) with a true ISO
# metric thread. All units are millimeters. Dimensions are the nominal values
# from the standards; where a standard only gives a limit, the limit is used.
#
# The head points up (+Z), the bearing face under the head is at z = 0
# and the tip of the screw is at z = -LENGTH.

LENGTH = 10 # nominal length, measured from under the head

# Thread (ISO 261 / ISO 68-1 / ISO 965-1): M3 x 0.5 coarse, right-handed
D = 3 # major diameter
P = 0.5 # pitch
H = 3 ** 0.5 / 2 * P # height of the fundamental triangle
D3 = D - 17 / 12 * H # minor diameter of the rounded root (d3 = 2.387)

# Head (ISO 4762)
DK = 5.5 # head diameter (plain, not knurled)
K = 3 # head height
V = 0.3 # radius of the top edge of the head (v max)
DW = 5.07 # diameter of the bearing face (dw min); the edge is chamfered to it
RF = 0.2 # underhead fillet radius (r min 0.1, da max 3.6 limits it to 0.3)
S = 2.5 # hex socket size across flats (a 2.5 mm hex key)
T = 1.3 # depth of the full hex socket (key engagement t min)
SOCKET_ANGLE = 120 # included angle of the conical socket bottom (unspecified)

# Point (ISO 4753 chamfered end): a 45° chamfer down to a point diameter
# slightly smaller than the thread root, leaving about 1P of incomplete thread
DP = 2

# Distance from the head to the first full thread (lg): screws up to 20 mm
# long are threaded to within 3P of the head, longer ones have a thread length
# b = 18 mm. The thread fades out over 2P toward the head.
LG = 3 * P if LENGTH <= 20 else LENGTH - 18
RUNOUT = 2 * P

STEP = 0.02 # sample spacing of the output mesh

@sdf3
def iso_thread(d, p):
    # Infinite right-handed rod with the ISO 68-1 basic profile: a flat crest
    # P/8 wide at the major diameter and straight flanks at 60°. The root is
    # rounded tangent to the flanks with radius H/6 (ISO 965-1 asks for at
    # least 0.125P), which puts its bottom at d3.
    h = 3 ** 0.5 / 2 * p
    r0 = d / 2 # crest
    r1 = d / 2 - 5 / 8 * h # where the flanks meet the root arc (d1 / 2)
    rr = h / 6 # root radius
    rc = d / 2 - 13 / 24 * h # root arc center, at u = p / 2
    u0, u1 = p / 16, p * 3 / 8 # the flank runs from (u0, r0) to (u1, r1)
    def f(q):
        r = np.hypot(q[:,0], q[:,1])
        # axial position relative to the helix, folded using the symmetry of
        # the profile so that u = 0 is the middle of a crest and u = p / 2 is
        # the middle of a root
        u = q[:,2] - np.arctan2(q[:,1], q[:,0]) * p / (2 * np.pi)
        u = np.abs((u + p / 2) % p - p / 2)
        # unsigned distance to the crest flat, flank and root arc
        crest = np.hypot(np.maximum(u - u0, 0), r - r0)
        eu, er = u1 - u0, r1 - r0
        t = np.clip(((u - u0) * eu + (r - r0) * er) / (eu * eu + er * er), 0, 1)
        flank = np.hypot(u - u0 - t * eu, r - r0 - t * er)
        vu, vr = u - p / 2, r - rc
        on_arc = vr <= vu * np.tan(np.radians(30))
        root = np.where(on_arc, np.abs(np.hypot(vu, vr) - rr), np.inf)
        dist = np.minimum(np.minimum(crest, flank), root)
        # the profile is a function of u, so it is enough to compare radii
        # to know whether we are inside
        profile = np.where(u < u0, r0, np.where(u < u1,
            r0 + (u - u0) * er / eu,
            rc - np.sqrt(np.maximum(rr * rr - (u - p / 2) ** 2, 0))))
        return np.where(r > profile, dist, -dist)
    return f

def cone(apex, angle):
    # solid cone opening upward (+Z) with its apex on the Z axis
    a = np.radians(angle / 2)
    return line((-np.cos(a), np.sin(a)), (0, apex)).revolve()

def blank():
    # half cross section in the (r, z) plane, revolved around the Z axis. the
    # shank and fillet run up into the head: if the pieces only touched, the
    # distance would be zero all over the internal face between them
    head = rounded_rectangle(np.array((DK, 2 * K)), V) & d2.slab(y0=0)
    head &= line((-1, 1), (DW / 2, 0))
    shank = rectangle(a=(-D / 2, -LENGTH), b=(D / 2, K))
    shank &= line((-1, 1), (DP / 2, -LENGTH))
    fillet = rectangle(a=(-D / 2 - RF, -RF), b=(D / 2 + RF, K))
    fillet -= circle(RF, (D / 2 + RF, -RF))
    return (head | shank | fillet).revolve()

def thread():
    # the full thread ends LG below the head, then its root rises along a cone
    # until it meets the major diameter RUNOUT higher up
    z0 = -LG + RUNOUT
    slope = (D - D3) / 2 / RUNOUT
    runout = line((-1, slope), (D / 2, z0)).revolve()
    return iso_thread(D, P) | runout | slab(z0=z0)

def socket():
    # hex socket with a conical bottom that meets the corners at depth T
    e = S * 2 / 3 ** 0.5 # size across corners
    apex = K - T - e / 2 / np.tan(np.radians(SOCKET_ANGLE / 2))
    return hexagon(e / 2).extrude(4 * K) & cone(apex, SOCKET_ANGLE)

f = blank() & thread()
f -= socket()

# the padding is a fractional number of steps so that no sample lands exactly
# on a surface at a round-numbered dimension, where marching cubes would make
# degenerate (non-manifold) triangles
pad = 2.3 * STEP
bounds = (
    (-DK / 2 - pad, -DK / 2 - pad, -LENGTH - pad),
    (DK / 2 + pad, DK / 2 + pad, K + pad))
f.save('m3_bolt.stl', step=STEP, bounds=bounds)
