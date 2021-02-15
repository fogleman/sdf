from PIL import Image, ImageFont, ImageDraw
import scipy.ndimage as nd
import numpy as np

from . import d2

# TODO: add text measuring capability
# TODO: add support for newlines?

@d2.sdf2
def text(name, text, width=None, height=None, texture_point_size=512):
    # load font file
    font = ImageFont.truetype(name, texture_point_size)

    # compute texture bounds
    p = 16
    x0, y0, x1, y1 = font.getbbox(text)
    w = x1 - x0 + 1 + p * 2
    h = y1 - y0 + 1 + p * 2

    # render to 1-bit image
    im = Image.new('1', (w, h))
    draw = ImageDraw.Draw(im)
    draw.text((p - x0, p - y0), text, font=font, fill=255)

    # convert to numpy array and apply distance transform
    a = np.array(im)
    inside = -nd.distance_transform_edt(a)
    outside = nd.distance_transform_edt(~a)
    texture = np.zeros(a.shape)
    texture[a] = inside[a]
    texture[~a] = outside[~a]

    # save debug image
    # x = max(abs(texture.min()), abs(texture.max()))
    # texture = (texture + x) / (2 * x) * 255
    # im = Image.fromarray(texture.astype('uint8'))
    # im.save('text.png')

    # compute world bounds
    h, w = texture.shape
    aspect = w / h
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
    scale = width / w
    texture *= scale

    # prepare fallback rectangle
    rectangle = d2.rectangle((width / 2, height / 2)) # TODO: is this ok?

    def f(p):
        x = p[:,0]
        y = p[:,1]
        u = (x - x0) / (x1 - x0)
        v = (y - y0) / (y1 - y0)
        v = 1 - v
        i = np.round(u * w).astype(int)
        j = np.round(v * h).astype(int)
        d = np.take(texture, j * w + i, mode='clip')
        q = rectangle(p).reshape(-1)
        outside = (i < 0) | (i >= w) | (j < 0) | (j >= h)
        d[outside] = q[outside]
        return d

    return f
