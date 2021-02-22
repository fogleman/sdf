from PIL import Image, ImageFont, ImageDraw
import scipy.ndimage as nd
import numpy as np

from . import d2

# TODO: add support for newlines?

PIXELS = 2 ** 22

def _load_image(thing):
    if isinstance(thing, str):
        return Image.open(thing)
    elif isinstance(thing, (np.ndarray, np.generic)):
        return Image.fromarray(thing)
    return Image.fromarray(np.array(thing))

def measure_text(name, text, width=None, height=None):
    font = ImageFont.truetype(name, 96)
    x0, y0, x1, y1 = font.getbbox(text)
    aspect = (x1 - x0) / (y1 - y0)
    if width is None and height is None:
        height = 1
    if width is None:
        width = height * aspect
    if height is None:
        height = width / aspect
    return (width, height)

def measure_image(thing, width=None, height=None):
    im = _load_image(thing)
    w, h = im.size
    aspect = w / h
    if width is None and height is None:
        height = 1
    if width is None:
        width = height * aspect
    if height is None:
        height = width / aspect
    return (width, height)

@d2.sdf2
def text(font_name, text, width=None, height=None, pixels=PIXELS, points=512):
    # load font file
    font = ImageFont.truetype(font_name, points)

    # compute texture bounds
    p = 0.2
    x0, y0, x1, y1 = font.getbbox(text)
    px = int((x1 - x0) * p)
    py = int((y1 - y0) * p)
    tw = x1 - x0 + 1 + px * 2
    th = y1 - y0 + 1 + py * 2

    # render text to image
    im = Image.new('L', (tw, th))
    draw = ImageDraw.Draw(im)
    draw.text((px - x0, py - y0), text, font=font, fill=255)

    return _sdf(width, height, pixels, px, py, im)

@d2.sdf2
def image(thing, width=None, height=None, pixels=PIXELS):
    im = _load_image(thing).convert('L')
    return _sdf(width, height, pixels, 0, 0, im)

def _sdf(width, height, pixels, px, py, im):
    tw, th = im.size

    # downscale image if necessary
    factor = (pixels / (tw * th)) ** 0.5
    if factor < 1:
        tw, th = int(round(tw * factor)), int(round(th * factor))
        px, py = int(round(px * factor)), int(round(py * factor))
        im = im.resize((tw, th))

    # convert to numpy array and apply distance transform
    im = im.convert('1')
    a = np.array(im)
    inside = -nd.distance_transform_edt(a)
    outside = nd.distance_transform_edt(~a)
    texture = np.zeros(a.shape)
    texture[a] = inside[a]
    texture[~a] = outside[~a]

    # save debug image
    # a = np.abs(texture)
    # lo, hi = a.min(), a.max()
    # a = (a - lo) / (hi - lo) * 255
    # im = Image.fromarray(a.astype('uint8'))
    # im.save('debug.png')

    # compute world bounds
    pw = tw - px * 2
    ph = th - py * 2
    aspect = pw / ph
    if width is None and height is None:
        height = 1
    if width is None:
        width = height * aspect
    if height is None:
        height = width / aspect
    x0 = -width / 2
    y0 = -height / 2
    x1 = width / 2
    y1 = height / 2

    # scale texture distances
    scale = width / tw
    texture *= scale

    # prepare fallback rectangle
    # TODO: reduce size based on mesh resolution instead of dividing by 2
    rectangle = d2.rectangle((width / 2, height / 2))

    def f(p):
        x = p[:,0]
        y = p[:,1]
        u = (x - x0) / (x1 - x0)
        v = (y - y0) / (y1 - y0)
        v = 1 - v
        i = u * pw + px
        j = v * ph + py
        d = _bilinear_interpolate(texture, i, j)
        q = rectangle(p).reshape(-1)
        outside = (i < 0) | (i >= tw-1) | (j < 0) | (j >= th-1)
        d[outside] = q[outside]
        return d

    return f

def _bilinear_interpolate(a, x, y):
    x0 = np.floor(x).astype(int)
    x1 = x0 + 1
    y0 = np.floor(y).astype(int)
    y1 = y0 + 1

    x0 = np.clip(x0, 0, a.shape[1] - 1)
    x1 = np.clip(x1, 0, a.shape[1] - 1)
    y0 = np.clip(y0, 0, a.shape[0] - 1)
    y1 = np.clip(y1, 0, a.shape[0] - 1)

    pa = a[y0, x0]
    pb = a[y1, x0]
    pc = a[y0, x1]
    pd = a[y1, x1]

    wa = (x1 - x) * (y1 - y)
    wb = (x1 - x) * (y - y0)
    wc = (x - x0) * (y1 - y)
    wd = (x - x0) * (y - y0)

    return wa * pa + wb * pb + wc * pc + wd * pd
