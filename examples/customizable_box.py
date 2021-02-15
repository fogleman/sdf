from sdf import *

WIDTH = 12
HEIGHT = 6
DEPTH = 2
ROWS = 3
COLS = 5
WALL_THICKNESS = 0.25
WALL_RADIUS = 0.5
BOTTOM_RADIUS = 0.25
TOP_FILLET = 0.125
DIVIDER_THICKNESS = 0.2
ROW_DIVIDER_DEPTH = 1.75
COL_DIVIDER_DEPTH = 1.5
DIVIDER_FILLET = 0.1
LID_THICKNESS = 0.25
LID_DEPTH = 0.75
LID_RADIUS = 0.125
SAMPLES = 2 ** 24

def dividers():
    col_spacing = WIDTH / COLS
    row_spacing = HEIGHT / ROWS
    c = rounded_box((DIVIDER_THICKNESS, 1e9, COL_DIVIDER_DEPTH), DIVIDER_FILLET)
    c = c.translate(Z * COL_DIVIDER_DEPTH / 2)
    c = c.repeat((col_spacing, 0, 0))
    r = rounded_box((1e9, DIVIDER_THICKNESS, ROW_DIVIDER_DEPTH), DIVIDER_FILLET)
    r = r.translate(Z * ROW_DIVIDER_DEPTH / 2)
    r = r.repeat((0, row_spacing, 0))
    if COLS % 2 != 0:
        c = c.translate((col_spacing / 2, 0, 0))
    if ROWS % 2 != 0:
        r = r.translate((0, row_spacing / 2, 0))
    return c | r

def box():
    d = dividers()
    p = WALL_THICKNESS
    f = rounded_box((WIDTH - p, HEIGHT - p, 1e9), WALL_RADIUS)
    f &= slab(z0=p/2).k(BOTTOM_RADIUS)
    d &= f
    f = f.shell(WALL_THICKNESS)
    f &= slab(z1=DEPTH).k(TOP_FILLET)
    return f | d

def lid():
    p = WALL_THICKNESS
    f = rounded_box((WIDTH + p, HEIGHT + p, 1e9), WALL_RADIUS)
    f &= slab(z0=p/2).k(LID_RADIUS)
    f = f.shell(LID_THICKNESS)
    f &= slab(z1=LID_DEPTH).k(TOP_FILLET)
    return f

box().save('box.stl', samples=SAMPLES)
lid().save('lid.stl', samples=SAMPLES)
