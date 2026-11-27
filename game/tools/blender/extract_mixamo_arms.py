"""Bras FPS à partir du voyageur riggé par Mixamo : garde seulement les sommets des bras
(épaules, bras, avant-bras, mains, doigts), dans la pose de repos (pose A d'origine),
avec le squelette Mixamo complet. Affiche les repères utiles au jeu (longueurs, axes de la main).
Usage : python3 extract_mixamo_arms.py <mixamo.fbx> <sortie.glb>"""
import sys
import bpy
import numpy as np
from mathutils import Vector

src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
me = [o for o in bpy.data.objects if o.type == "MESH"][0]
if arm.animation_data:
    arm.animation_data.action = None
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
    pb.scale = (1, 1, 1)
bpy.context.view_layer.update()
ARM_KEYS = ("Shoulder", "Arm", "ForeArm", "Hand")
names = {g.index: g.name.replace("mixamorig:", "") for g in me.vertex_groups}
keep = []
for v in me.data.vertices:
    w = sum(g.weight for g in v.groups if any(k in names[g.group] for k in ARM_KEYS))
    keep.append(w > 0.55)
# poids : seulement les os du bras (l'épaule et le torse restent près de la caméra dans le jeu,
# un sommet qui leur serait lié s'étirerait à travers l'écran) ; l'épaule est reportée sur le bras
gid = {g.name.replace("mixamorig:", ""): g.index for g in me.vertex_groups}
for v, k in zip(me.data.vertices, keep):
    if not k:
        continue
    acc = {}
    for g in v.groups:
        n = names[g.group]
        if n.endswith("Shoulder"):
            n = n.replace("Shoulder", "Arm")
        if any(t in n for t in ("Arm", "ForeArm", "Hand")):
            acc[n] = acc.get(n, 0.0) + g.weight
    tot = sum(acc.values()) or 1.0
    for g in list(v.groups):
        me.vertex_groups[g.group].remove([v.index])
    for n, w in acc.items():
        me.vertex_groups[gid[n]].add([v.index], w / tot, "REPLACE")
import bmesh
bm = bmesh.new()
bm.from_mesh(me.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i, k in enumerate(keep) if not k], context="VERTS")
bm.to_mesh(me.data)
bm.free()
print("sommets gardés", len(me.data.vertices))
mw = arm.matrix_world
B = arm.data.bones
def gpos(n):
    return mw @ B["mixamorig:" + n].head_local
for side in ("Right", "Left"):
    s, e, h = gpos(side + "Arm"), gpos(side + "ForeArm"), gpos(side + "Hand")
    print(side, "bras %.3f avant-bras %.3f" % ((e - s).length, (h - e).length), "épaule", tuple(round(x, 3) for x in s))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False,
                          export_image_format="JPEG", export_image_quality=88)
print("ok", out)
