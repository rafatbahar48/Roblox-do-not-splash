"""Paints the Marsh Moth's textures: moth_wing.png and moth_head.png.

Run it in Blender, which comes with numpy:
    blender -b -P paint_moth.py
"""
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import moth_shape as shape  # noqa: E402

SIZE = 1024
rng = np.random.default_rng(23)


def box_blur(image, radius):
    """Blurs by averaging over a box, along both axes."""
    for axis in (0, 1):
        padded = np.concatenate([np.repeat(image.take([0], axis), radius + 1, axis), image, np.repeat(image.take([-1], axis), radius, axis)], axis)
        total = np.cumsum(padded, axis)
        size = image.shape[axis]
        upper = total.take(range(2 * radius + 1, 2 * radius + 1 + size), axis)
        lower = total.take(range(0, size), axis)
        image = (upper - lower) / (2 * radius + 1)
    return image


def blur(image, radius):
    """Close to a Gaussian: three box blurs."""
    for _ in range(3):
        image = box_blur(image, max(1, radius // 2))
    return image


def noise(cells):
    """Smooth noise from 0 to 1, with about this many blobs across."""
    step = max(1, SIZE // cells)
    small = rng.random((SIZE // step + 2, SIZE // step + 2)).astype(np.float32)
    big = np.kron(small, np.ones((step, step), dtype=np.float32))[:SIZE, :SIZE]
    big = blur(big, step) if step > 1 else big
    return (big - big.min()) / (big.max() - big.min() + 1e-6)


def clouds():
    return 0.55 * noise(7) + 0.3 * noise(18) + 0.15 * noise(50)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = t[..., None] if isinstance(t, np.ndarray) else t
    return a * (1 - t) + b * t


def rgb(r, g, b):
    return np.array([r, g, b], dtype=np.float32) / 255


# Where each pixel is on the wing.
rows, cols = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
U = (cols + 0.5) / SIZE * shape.SPAN - shape.PAD_U
V = (1 - (rows + 0.5) / SIZE) * shape.SPAN - shape.PAD_V
R = np.hypot(U, V)


def fill(curve):
    """1 inside a closed curve, 0 outside."""
    hit = np.zeros((SIZE, SIZE), dtype=bool)
    for i in range(len(curve)):
        (x1, y1), (x2, y2) = curve[i - 1], curve[i]
        if y1 == y2:
            continue
        crossing = ((y1 > V) != (y2 > V)) & (U < (x2 - x1) * (V - y1) / (y2 - y1) + x1)
        hit ^= crossing
    return hit.astype(np.float32)


def segment(a, b):
    """How far each pixel is from the line a to b."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = np.clip(((U - ax) * dx + (V - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(U - (ax + t * dx), V - (ay + t * dy))


DEEP = rgb(20, 88, 84)       # the wing's teal heart
DUSK = rgb(84, 128, 88)       # moss green further out
LICHEN = rgb(176, 196, 134)  # pale dusting
CREAM = rgb(226, 222, 176)
UMBER = rgb(34, 26, 22)
BARK = rgb(70, 52, 38)
AMBER = rgb(226, 150, 52)
RUST = rgb(150, 60, 24)
INK = rgb(10, 12, 12)


def wing_layer(curve, eye, reach, veins):
    area = fill(curve)
    # How deep inside the wing a pixel is, roughly: 0.5 on the edge, 1 deep in.
    depth = blur(area, 26)
    wobble = clouds() - 0.5

    colour = mix(DEEP, DUSK, smoothstep(0.25, 1.0, R / reach + wobble * 0.5))
    # Pale dusting, thickest in the clouds.
    colour = mix(colour, LICHEN, smoothstep(0.56, 0.8, clouds()) * 0.5)
    # A dark furry root.
    colour = mix(colour, UMBER, np.exp(-R / 0.55))

    # A wavy dark line and pale band, then a dark edge.
    wave = 0.02 * np.sin(np.arctan2(V, U + 0.001) * 26) + wobble * 0.05
    line = np.exp(-(((depth + wave - 0.8) / 0.016) ** 2))
    colour = mix(colour, UMBER, line * 0.9)
    band = smoothstep(0.78, 0.74, depth + wave) * smoothstep(0.64, 0.68, depth + wave)
    colour = mix(colour, CREAM, band * 0.8)
    colour = mix(colour, BARK, smoothstep(0.66, 0.6, depth + wave))

    # Veins fanning from the root.
    vein = np.zeros((SIZE, SIZE), dtype=np.float32)
    for i in range(veins):
        u, v = curve[int((i + 0.5) / veins * len(curve))]
        if math.hypot(u, v) > 1.3:
            bend = (u * 0.5 - v * 0.05, v * 0.5 + u * 0.05)
            near = np.minimum(segment((0, 0), bend), segment(bend, (u, v)))
            vein = np.maximum(vein, np.exp(-((near / 0.016) ** 2)))
    colour = mix(colour, UMBER, vein * 0.55)

    # The eye spot, ring by ring.
    eu, ev, er = eye
    d = np.hypot(U - eu, V - ev) / er
    colour = mix(colour, CREAM, smoothstep(1.02, 0.97, d))
    colour = mix(colour, INK, smoothstep(0.86, 0.82, d))
    colour = mix(colour, AMBER, smoothstep(0.66, 0.62, d))
    colour = mix(colour, RUST, smoothstep(0.5, 0.46, d))
    colour = mix(colour, INK, smoothstep(0.36, 0.33, d))
    crescent = smoothstep(0.3, 0.27, np.hypot(U - eu + er * 0.1, V - ev - er * 0.1) / er) * smoothstep(0.17, 0.2, d)
    colour = mix(colour, CREAM, crescent * 0.9)
    return colour, area


def save(name, pixels):
    """Writes an image, its top row first."""
    height, width = pixels.shape[:2]
    image = bpy.data.images.new(name, width, height, alpha=False)
    rgba = np.ones((height, width, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(pixels, 0, 1)
    image.pixels.foreach_set(rgba[::-1].ravel())
    image.filepath_raw = os.path.join(HERE, name)
    image.file_format = "PNG"
    image.save()


fore, fore_area = wing_layer(shape.fore_outline(), shape.EYES["fore"], 4.8, 13)
hind, hind_area = wing_layer(shape.hind_outline(), shape.EYES["hind"], 3.6, 11)
wing = mix(hind, fore, fore_area)
# Powdery scales all over.
wing *= (0.9 + 0.2 * rng.random((SIZE, SIZE)).astype(np.float32))[..., None]
save("moth_wing.png", wing)

# The head's texture is bands, left to right: fur (dark at the root, pale at
# the tip, up the picture), the antennae and the eyes.
HEAD = 256
v = np.linspace(1, 0, HEAD, dtype=np.float32)[:, None] * np.ones((1, HEAD), dtype=np.float32)
u = np.linspace(0, 1, HEAD, dtype=np.float32)[None, :] * np.ones((HEAD, 1), dtype=np.float32)
head = mix(rgb(52, 38, 28), rgb(112, 86, 58), smoothstep(0.0, 0.4, v))
head = mix(head, rgb(226, 214, 160), smoothstep(0.4, 0.95, v))
head *= (0.8 + 0.4 * rng.random((1, HEAD)).astype(np.float32))[..., None]
head = np.where((u > 0.5)[..., None], rgb(120, 86, 40), head)
head = np.where((u > 0.75)[..., None], mix(INK, rgb(30, 66, 58), v), head)
save("moth_head.png", head)
print("painted")
