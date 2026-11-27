"""Exporte le voyageur (sans squelette, dans sa pose de modélisation) en FBX avec textures intégrées,
pour l'auto-rigging Mixamo (squelette complet avec doigts).
Usage : python3 export_for_mixamo.py <traveler.glb> <sortie.fbx>"""
import sys
import bpy
from mathutils import Vector

src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type == "ARMATURE":
        for c in o.children:
            mw = c.matrix_world.copy()
            c.parent = None
            c.matrix_world = mw
        bpy.data.objects.remove(o)
for o in list(bpy.data.objects):
    if o.type == "MESH":
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                o.modifiers.remove(m)
        o.vertex_groups.clear()
    elif o.type == "EMPTY":
        bpy.data.objects.remove(o)
# seul le corps (le fichier contient aussi une petite sphère technique)
for o in list(bpy.data.objects):
    if o.type == "MESH" and len(o.data.vertices) < 1000:
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [v.co for o in meshes for v in o.data.vertices]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
print("boîte", tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx))
# pieds au sol, centré
for o in meshes:
    for v in o.data.vertices:
        v.co.x -= (mn.x + mx.x) / 2
        v.co.y -= (mn.y + mx.y) / 2
        v.co.z -= mn.z
for img in bpy.data.images:
    img.pack() if not img.packed_file else None
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, path_mode="COPY", embed_textures=True,
                         apply_scale_options="FBX_SCALE_ALL", add_leaf_bones=False)
print("ok", out)
