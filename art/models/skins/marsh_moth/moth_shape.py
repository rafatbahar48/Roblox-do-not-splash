"""The Marsh Moth's wing shapes, shared by paint_moth.py and build_moth.py.

Everything is in studs, on one wing: u runs outward from the hinge on the
avatar's back, v runs up.
"""
import math

# Outlines, traced round through these points (smoothed by outline()).
FORE = [
    (0.0, 0.2), (0.55, 1.0), (1.45, 1.8), (2.55, 2.4), (3.55, 2.62), (4.3, 2.5), (4.38, 2.05),
    (4.0, 1.4), (3.45, 0.75), (2.75, 0.22), (1.9, -0.12), (1.0, -0.24), (0.1, -0.14),
]
HIND = [
    (0.05, -0.02), (0.95, -0.16), (1.95, -0.22), (2.6, -0.7), (2.78, -1.35), (2.5, -1.95), (2.05, -2.3),
    (1.86, -2.8), (1.98, -3.3), (1.82, -3.66), (1.52, -3.38), (1.42, -2.82), (1.2, -2.35), (0.62, -1.6), (0.16, -0.8),
]

# The eye spots: u, v and radius.
EYES = {"fore": (2.5, 1.32, 0.6), "hind": (1.68, -1.25, 0.5)}

# Where a wing's point lands on its texture: uv = (u + PAD_U, v + PAD_V) / SPAN.
PAD_U, PAD_V, SPAN = 0.2, 3.9, 7.0


def to_uv(u, v):
    return (u + PAD_U) / SPAN, (v + PAD_V) / SPAN


def smooth(points, per=10):
    """A closed Catmull-Rom curve through points."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for step in range(per):
            t = step / per
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[k] + (p2[k] - p0[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * t3)
                for k in (0, 1)
            ))
    return out


def outline(points, waves=0, amount=0.0):
    """A wing's edge. waves scallops it, away from the hinge."""
    curve = smooth(points)
    if not waves:
        return curve
    out = []
    n = len(curve)
    for i, (u, v) in enumerate(curve):
        a, b = curve[i - 1], curve[(i + 1) % n]
        tu, tv = b[0] - a[0], b[1] - a[1]
        length = math.hypot(tu, tv) or 1
        # Outward, for an outline that runs clockwise.
        nu, nv = -tv / length, tu / length
        reach = min(1, max(0, (math.hypot(u, v) - 1.2) / 1.2))
        lift = amount * reach * abs(math.sin(i / n * math.pi * waves))
        out.append((u + nu * lift, v + nv * lift))
    return out


def fore_outline():
    return outline(FORE, 13, 0.05)


def hind_outline():
    return outline(HIND, 11, 0.05)


def lift(u, v):
    """How far a wing's surface curves back from flat, in studs."""
    r = math.hypot(u, v)
    theta = math.atan2(v, u + 0.001)
    return 0.045 * r ** 1.5 + 0.03 * math.sin(theta * 9) * min(r, 3) / 3


def inside(point, polygon):
    x, y = point
    hit = False
    for i in range(len(polygon)):
        (x1, y1), (x2, y2) = polygon[i - 1], polygon[i]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def margin_dots(curve, count, inset=0.26):
    """Points just inside a wing's edge, evenly round its far side."""
    out = []
    far = [p for p in curve if math.hypot(*p) > 1.7]
    for i in range(count):
        u, v = far[int((i + 0.5) / count * len(far))]
        r = math.hypot(u, v)
        out.append((u - u / r * inset, v - v / r * inset))
    return out
