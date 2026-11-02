# Blender (5.2) script: adds a jaw to the Mire Stalker's Meshy rig and exports
# it for Roblox. Run headless from this folder:
#   blender --background --factory-startup --python add_jaw.py
#
# Meshy's humanoid rig has no jaw. This adds a Jaw bone under Head, hinged
# inside the head behind the mouth, and hands it the lower half of the open
# mouth (lower lip, lower fangs, chin): their weight on the head's bones
# (Meshy puts the face on headfront, not Head) moves to Jaw, fading in over
# a few centimetres at the edges so the corners of the mouth stretch rather
# than tear. The darker base colour replaces Meshy's. Writes
# mire_stalker_jaw.fbx (for Roblox) and mire_stalker_jaw.glb (to check).
#
# Places are in the model's own glTF coordinates (metres, Y up, the face
# looking along +Z), measured from close-ups of the head.

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "mire_stalker_rigged.glb")
DARK_TEXTURE = os.path.join(HERE, "texture_base_color_dark.png")

HINGE = (0.026, 3.36, 0.15)  # inside the head, behind the mouth, a little above its middle
CHIN = (0.026, 3.20, 0.46)  # where the bone points: the front of the lower fangs
CUT = (3.37, 3.31)  # height: no jaw above the first, all jaw below the second
BACK = (0.13, 0.24)  # depth: no jaw behind the first, all jaw in front of the second
SIDE = (0.26, 0.19)  # sideways from the middle: no jaw past the first, all jaw within the second
HEAD_BONES = ("Head", "headfront", "head_end")  # the head's own bones, whose weight the jaw can take


def to_blender(point):
    # glTF (x, y up, z forward) to Blender (x, -z, y up), as the importer turns it.
    x, y, z = point
    return Vector((x, -z, y))


def to_gltf(point):
    return (point.x, point.z, -point.y)


def smooth(edge0, edge1, value):
    # 0 at edge0, 1 at edge1, eased between (either way round).
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
mesh = max(meshes, key=lambda o: len(o.data.vertices))
# The importer's bone-shape sphere isn't part of the body.
for extra in meshes:
    if extra is not mesh:
        bpy.data.objects.remove(extra, do_unlink=True)
print("armature", armature.name, "mesh", mesh.name, "bones", len(armature.data.bones))

# The bone.
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode="EDIT")
edit_bones = armature.data.edit_bones
to_armature = armature.matrix_world.inverted()
jaw = edit_bones.new("Jaw")
jaw.head = to_armature @ to_blender(HINGE)
jaw.tail = to_armature @ to_blender(CHIN)
jaw.parent = edit_bones["Head"]
jaw.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

# The weights.
head_groups = [mesh.vertex_groups[name] for name in HEAD_BONES if name in mesh.vertex_groups]
by_index = {g.index: g for g in head_groups}
jaw_group = mesh.vertex_groups.new(name="Jaw")
moved, total = 0, 0.0
for vertex in mesh.data.vertices:
    on_head = [(by_index[g.group], g.weight) for g in vertex.groups if g.group in by_index and g.weight > 0]
    if not on_head:
        continue
    x, y, z = to_gltf(mesh.matrix_world @ vertex.co)
    share = smooth(CUT[0], CUT[1], y) * smooth(BACK[0], BACK[1], z) * smooth(SIDE[0], SIDE[1], abs(x - HINGE[0]))
    if share <= 0:
        continue
    jaw_group.add([vertex.index], sum(w for _, w in on_head) * share, "REPLACE")
    for group, weight in on_head:
        group.add([vertex.index], weight * (1 - share), "REPLACE")
    moved += 1
    total += share
print(f"jaw takes {moved} vertices ({total:.0f} in full)")

# The darker colours.
dark = bpy.data.images.load(DARK_TEXTURE)
for material in mesh.data.materials:
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            link = next(iter(node.inputs["Base Color"].links), None)
            if link and link.from_node.type == "TEX_IMAGE":
                link.from_node.image = dark
                print("base colour now", os.path.basename(DARK_TEXTURE), "in", material.name)

bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, "mire_stalker_jaw.glb"), export_format="GLB", export_animations=False)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(HERE, "mire_stalker_jaw.fbx"),
    object_types={"ARMATURE", "MESH"},
    add_leaf_bones=False,
    bake_anim=False,
    path_mode="COPY",
    embed_textures=True,
    apply_scale_options="FBX_SCALE_ALL",
)
print("exported")
