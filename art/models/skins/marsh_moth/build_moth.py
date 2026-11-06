"""Builds the Marsh Moth skin's 3D pieces in Blender, and renders or exports them.

    blender -b -P build_moth.py -- render   renders moth_views.png's three views
    blender -b -P build_moth.py -- export   writes marsh_moth.fbx for Studio

Run paint_moth.py first. The pieces, named as they will be in
ReplicatedStorage.SkinModels (shared/OutfitLook.luau):

    SkinMothHead       the fuzzy head, ruff and chest fur (moth_head.png)
    SkinMothAntennae   the feathered antennae, made Neon in the game
    SkinMothWingL/R    a wing each, fore and hind (moth_wing.png)
    SkinMothGlowL/R    each wing's glowing rings and dots, made Neon in the game

The avatar faces -Y, its feet on Z 0, with a head 1.2 studs tall.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import moth_shape as shape  # noqa: E402

MODE = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "render"
random.seed(11)

THICK = 0.035  # how thick the wings are
HINGE = (0.18, 0.56, 3.55)  # where the left wing's root is on the avatar (+X)
SWEEP = math.radians(14)  # how far the wings sweep back in the renders
FUR, ANTENNA, EYE = (0.02, 0.48), 0.62, 0.87  # bands of moth_head.png

for block in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for item in list(block):
        block.remove(item)
scene = bpy.context.scene


class Piece:
    """A mesh built up bit by bit, with one UV per vertex."""

    def __init__(self):
        self.verts, self.faces, self.uvs = [], [], []

    def add(self, verts, faces, uvs):
        base = len(self.verts)
        self.verts += verts
        self.faces += [tuple(i + base for i in face) for face in faces]
        self.uvs += uvs

    def object(self, name, material, smooth=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.verts, [], self.faces)
        layer = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for index in poly.loop_indices:
                layer.data[index].uv = self.uvs[me.loops[index].vertex_index]
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        if smooth:
            me.shade_smooth()
        me.materials.append(material)
        o = bpy.data.objects.new(name, me)
        scene.collection.objects.link(o)
        return o


def textured(name, file):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.72
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(os.path.join(HERE, file))
    m.node_tree.links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def plain(name, color, emit=0.0, rough=0.6, emit_color=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*(emit_color or color), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


# Wings ------------------------------------------------------------------------


def sheet(piece, curve, spacing=0.17):
    """A wing panel: a thin shell, its surface curved, its edge closed."""
    points = list(curve)
    n = len(points)
    u0, u1 = min(p[0] for p in points), max(p[0] for p in points)
    v0, v1 = min(p[1] for p in points), max(p[1] for p in points)
    row = 0
    v = v0
    while v < v1:
        u = u0 + (spacing / 2 if row % 2 else 0)
        while u < u1:
            if shape.inside((u, v), curve) and min(math.hypot(u - a, v - b) for a, b in curve) > spacing * 0.7:
                points.append((u, v))
            u += spacing
        v += spacing * 0.87
        row += 1
    edges = [(i, (i + 1) % n) for i in range(n)]
    result = delaunay_2d_cdt([Vector(p) for p in points], edges, [], 0, 1e-6)
    coords, triangles = [tuple(c) for c in result[0]], result[2]
    triangles = [t for t in triangles if shape.inside(tuple(sum(coords[i][k] for i in t) / 3 for k in (0, 1)), curve)]

    count = len(coords)
    verts, uvs = [], []
    for side in (0, THICK):
        for u, v in coords:
            verts.append((u, shape.lift(u, v) + side, v))
            uvs.append(shape.to_uv(u, v))
    faces = [tuple(t) for t in triangles] + [tuple(i + count for i in reversed(t)) for t in triangles]
    used = {}
    for t in triangles:
        for i in range(3):
            key = tuple(sorted((t[i], t[(i + 1) % 3])))
            used[key] = used.get(key, 0) + 1
    for (a, b), times in used.items():
        if times == 1:
            faces.append((a, b, b + count, a + count))
    piece.add(verts, faces, uvs)


def ring(piece, u, v, inner, outer, n=44):
    """A flat ring on both faces of the wing, a little proud of them."""
    for offset in (-0.012, THICK + 0.012):
        verts, faces = [], []
        for i in range(n):
            a = i / n * math.tau
            for r in (inner, outer):
                x, z = u + r * math.cos(a), v + r * math.sin(a)
                verts.append((x, shape.lift(x, z) + offset, z))
            j = (i + 1) % n
            faces.append((2 * i, 2 * i + 1, 2 * j + 1, 2 * j))
        piece.add(verts, faces, [(0, 0)] * len(verts))


def dot(piece, u, v, size):
    """A little diamond on both faces of the wing."""
    for offset in (-0.012, THICK + 0.012):
        verts = []
        for du, dv in ((size, 0), (0, size * 1.5), (-size, 0), (0, -size * 1.5)):
            x, z = u + du, v + dv
            verts.append((x, shape.lift(x, z) + offset, z))
        piece.add(verts, [(0, 1, 2, 3)], [(0, 0)] * 4)


def mirrored(piece):
    other = Piece()
    other.add([(-x, y, z) for x, y, z in piece.verts], [tuple(reversed(f)) for f in piece.faces], list(piece.uvs))
    return other


wing_mat = textured("moth_wing", "moth_wing.png")
glow_mat = plain("moth_glow", (0.55, 1, 0.75), emit=8)
fore, hind = shape.fore_outline(), shape.hind_outline()

wing = Piece()
sheet(wing, hind)
sheet(wing, fore)
glow = Piece()
for name, curve, dots in (("fore", fore, 15), ("hind", hind, 11)):
    u, v, r = shape.EYES[name]
    ring(glow, u, v, r * 0.5, r * 0.62)
    for du, dv in shape.margin_dots(curve, dots):
        dot(glow, du, dv, 0.045)

objects = {}
for side, sign in (("L", 1), ("R", -1)):
    w = wing if sign > 0 else mirrored(wing)
    g = glow if sign > 0 else mirrored(glow)
    objects["SkinMothWing" + side] = w.object("SkinMothWing" + side, wing_mat)
    objects["SkinMothGlow" + side] = g.object("SkinMothGlow" + side, glow_mat, smooth=False)

# Head -------------------------------------------------------------------------


def tuft(piece, base, direction, length, width, droop=0.0):
    """A pointed lock of fur: three-sided, curving down at the tip."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0.13, 0.2, 1))).normalized()
    up = d.cross(side).normalized()
    b = Vector(base)
    mid = b + d * (length * 0.55)
    tip = b + d * length + Vector((0, 0, -droop * length))
    verts, uvs = [], []
    shade = random.uniform(*FUR)
    for centre, w, v in ((b, width, 0.02), (mid, width * 0.72, 0.5)):
        for i in range(3):
            a = i / 3 * math.tau
            verts.append(tuple(centre + (side * math.cos(a) + up * math.sin(a)) * w))
            uvs.append((shade, v))
    verts.append(tuple(tip))
    uvs.append((shade, 0.98))
    faces = []
    for i in range(3):
        j = (i + 1) % 3
        faces.append((i, j, j + 3, i + 3))
        faces.append((i + 3, j + 3, 6))
    piece.add(verts, faces, uvs)


def dome(piece, centre, radii, u, rings=9, n=20, flat=1.0):
    """A squashed sphere."""
    verts, faces, uvs = [], [], []
    for r in range(rings + 1):
        phi = r / rings * math.pi
        for i in range(n):
            a = i / n * math.tau
            verts.append((
                centre[0] + radii[0] * math.sin(phi) * math.cos(a),
                centre[1] + radii[1] * math.sin(phi) * math.sin(a),
                centre[2] + radii[2] * math.cos(phi) * flat,
            ))
            uvs.append((u, 0.05 + 0.9 * r / rings))
    for r in range(rings):
        for i in range(n):
            j = (i + 1) % n
            faces.append((r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i))
    piece.add(verts, faces, uvs)


head = Piece()
CENTRE = Vector((0, 0, 4.62))
dome(head, CENTRE, (0.66, 0.64, 0.64), 0.25)
# Big dark eyes on the sides of the face.
for sx in (-1, 1):
    dome(head, (sx * 0.42, -0.42, 4.68), (0.3, 0.27, 0.34), EYE)

# Short fur all over the head, leaning back, clear of the eyes.
count = 640
for i in range(count):
    z = 1 - 2 * (i + 0.5) / count
    r = math.sqrt(1 - z * z)
    a = i * 2.39996
    normal = Vector((r * math.cos(a), r * math.sin(a), z))
    point = CENTRE + Vector((normal.x * 0.64, normal.y * 0.62, normal.z * 0.62))
    if abs(point.x) > 0.14 and point.y < -0.25 and 4.32 < point.z < 5.05:
        continue
    lean = normal + Vector((0, 1.0, -0.35))
    tuft(head, point, lean, random.uniform(0.13, 0.24), 0.062, 0.2)

# The ruff: long locks round the neck, three layers, drooping over the shoulders.
for layer, (reach, top, length, count) in enumerate(((1.02, 4.12, 0.95, 78), (0.84, 4.2, 0.74, 66), (0.66, 4.3, 0.54, 54))):
    for i in range(count):
        a = (i + layer * 0.5) / count * math.tau
        point = Vector((reach * math.cos(a), reach * 0.66 * math.sin(a), top + random.uniform(-0.05, 0.05)))
        direction = Vector((math.cos(a) * 0.8, math.sin(a) * 0.6, -0.62 + random.uniform(-0.12, 0.12)))
        tuft(head, point, direction, length * random.uniform(0.82, 1.15), 0.085, 0.42)

# Thick fur over the chest and back, a thorax.
for i in range(190):
    front = i % 2 == 0
    x = random.uniform(-0.92, 0.92)
    z = random.uniform(2.95, 3.95)
    if abs(x) > 0.92 - (3.95 - z) * 0.42:
        continue
    y = -0.5 if front else 0.5
    tuft(head, (x, y, z), (x * 0.25, y * 0.9, -1.0), random.uniform(0.3, 0.5), 0.08, 0.3)

objects["SkinMothHead"] = head.object("SkinMothHead", textured("moth_head", "moth_head.png"))

# Antennae ---------------------------------------------------------------------


def bezier(a, b, c, d, t):
    s = 1 - t
    return a * s ** 3 + b * 3 * s * s * t + c * 3 * s * t * t + d * t ** 3


def stalk(piece, points, width):
    """A tapering tube through points."""
    sides = 5
    verts, faces = [], []
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        side = ahead.cross(Vector((0.1, 1, 0.2))).normalized()
        up = ahead.cross(side).normalized()
        w = width * (1 - i / len(points)) + 0.004
        for k in range(sides):
            a = k / sides * math.tau
            verts.append(tuple(p + (side * math.cos(a) + up * math.sin(a)) * w))
    for i in range(len(points) - 1):
        for k in range(sides):
            j = (k + 1) % sides
            faces.append((i * sides + k, i * sides + j, (i + 1) * sides + j, (i + 1) * sides + k))
    piece.add(verts, faces, [(ANTENNA, 0.5)] * len(verts))


antennae = Piece()
for sx in (-1, 1):
    a = Vector((sx * 0.2, -0.46, 5.08))
    b = Vector((sx * 0.42, -0.66, 5.62))
    c = Vector((sx * 0.98, -0.66, 6.14))
    d = Vector((sx * 1.55, -0.42, 5.86))
    spine = [bezier(a, b, c, d, i / 40) for i in range(41)]
    stalk(antennae, spine, 0.028)
    for i in range(3, 40):
        p = spine[i]
        ahead = (spine[i + 1] - spine[i - 1]).normalized()
        t = i / 40
        length = 0.3 * math.sin(math.pi * min(1, t * 1.05)) ** 0.7 + 0.03
        out = ahead.cross(Vector((0, 1, 0))).normalized()
        for lean in (1, -1):
            barb = (out * lean + ahead * 0.5).normalized()
            stalk(antennae, [p, p + barb * length * 0.5, p + barb * length + Vector((0, 0.03, 0))], 0.009)

objects["SkinMothAntennae"] = antennae.object("SkinMothAntennae", plain("moth_antenna", (0.8, 0.66, 0.3), emit=1.1, emit_color=(0.95, 0.85, 0.45)))


def report():
    """Triangle counts, and each piece's size and middle in Roblox's axes
    (x, y, z = -X, Z, Y), for OutfitLook.luau's MOTH table."""
    total = 0
    for name, o in objects.items():
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        total += tris
        low = [min(v.co[k] for v in o.data.vertices) for k in range(3)]
        high = [max(v.co[k] for v in o.data.vertices) for k in range(3)]
        size = [high[k] - low[k] for k in range(3)]
        middle = [(high[k] + low[k]) / 2 for k in range(3)]
        print(f"FIT {name}: {tris} tris size ({size[0]:.3f}, {size[2]:.3f}, {size[1]:.3f}) middle ({-middle[0]:.3f}, {middle[2]:.3f}, {middle[1]:.3f})")
    print("total", total)


report()

if MODE == "export":
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects.values():
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(HERE, "marsh_moth.fbx"),
        use_selection=True,
        path_mode="COPY",
        embed_textures=True,
        axis_forward="Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH"},
        bake_space_transform=True,
    )
    print("exported")
    raise SystemExit

# Renders ----------------------------------------------------------------------

for side, sign in (("L", 1), ("R", -1)):
    for name in ("SkinMothWing", "SkinMothGlow"):
        o = objects[name + side]
        o.location = (sign * HINGE[0], HINGE[1], HINGE[2])
        o.rotation_euler = (0, 0, -sign * -SWEEP)


def block(name, size, at, material, r=0.09):
    sx, sy, sz = (s / 2 for s in size)
    verts = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = at
    scene.collection.objects.link(o)
    bevel = o.modifiers.new("b", "BEVEL")
    bevel.width = r
    bevel.segments = 3
    return o


thorax = plain("thorax", (0.05, 0.035, 0.028), rough=0.85)
limb = plain("limb", (0.018, 0.035, 0.03), rough=0.8)
block("torso", (2, 1, 2), (0, 0, 3), thorax)
block("armL", (0.95, 0.95, 2), (-1.5, 0, 3), limb)
block("armR", (0.95, 0.95, 2), (1.5, 0, 3), limb)
block("legL", (0.95, 0.95, 2), (-0.5, 0, 1), limb)
block("legR", (0.95, 0.95, 2), (0.5, 0, 1), limb)
eye_mat = plain("eye", (0.45, 1, 0.65), emit=7)
for sx in (-1, 1):
    me = bpy.data.meshes.new("glowEye")
    p = Piece()
    dome(p, (sx * 0.47, -0.655, 4.72), (0.07, 0.05, 0.1), EYE)
    p.object("glowEye", eye_mat)

ground = bpy.data.meshes.new("water")
ground.from_pydata([(-40, -30, 0), (40, -30, 0), (40, 40, 0), (-40, 40, 0)], [], [(0, 1, 2, 3)])
ground.materials.append(plain("water", (0.006, 0.014, 0.02), rough=0.8))
water = bpy.data.objects.new("water", ground)
scene.collection.objects.link(water)

world = bpy.data.worlds.new("night")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.024, 0.055, 1)
scene.world = world


def lamp(name, at, power, color, size=6, aim=(0, 0, 3.5)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.color = color
    data.size = size
    o = bpy.data.objects.new(name, data)
    o.location = at
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (Vector(aim) - Vector(at)).to_track_quat("-Z", "Y")
    scene.collection.objects.link(o)


lamp("moon", (-8, -14, 14), 1500, (0.68, 0.78, 1), 12)
lamp("back", (6, 16, 12), 1500, (0.66, 0.84, 1), 12)
lamp("rimL", (-16, 6, 6), 700, (0.35, 0.85, 0.75), 8)
lamp("rimR", (16, 6, 6), 700, (0.45, 0.65, 1), 8)

scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = 1000
scene.render.resolution_y = 900

data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.rotation_mode = "QUATERNION"
for name, at, aim, lens in (
    ("front", (0, -15, 4.2), (0, 0, 3.3), 42),
    ("back", (6.5, 13.5, 5.2), (0, 0, 3.2), 42),
    ("close", (-2.0, -7.4, 5.3), (0, 0, 4.75), 58),
):
    cam.location = at
    cam.rotation_quaternion = (Vector(aim) - Vector(at)).to_track_quat("-Z", "Y")
    data.lens = lens
    scene.render.filepath = os.path.join(HERE, f"moth_{name}.png")
    bpy.ops.render.render(write_still=True)
print("rendered")
