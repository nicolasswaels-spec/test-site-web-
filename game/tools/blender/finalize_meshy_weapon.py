"""Prépare une arme générée par Meshy pour le jeu : orientation (bouche vers +X), mise à
l'échelle (longueur voulue), repères muzzle / sight / hand_r / hand_l (positions données en
fraction de la boîte englobante, mesurées sur le visuel), puis export GLB.
Usage : python3 finalize_meshy_weapon.py <entrée.glb> <sortie.glb> <longueur_m> <flip 0|1> \
        <muzzle fx,fz> <sight fx,fz> <hand_r fx,fz> <hand_l fx,fz>
fx, fz : position relative dans la boîte APRÈS retournement (0 = arrière / bas, 1 = avant / haut)."""
import sys, math
import bpy
from mathutils import Vector, Matrix

src, out, length, flip = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4] == "1"
marks = {n: tuple(float(v) for v in a.split(",")) for n, a in zip(("muzzle", "sight", "hand_r", "hand_l"), sys.argv[5:9])}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2
import os
k = length / ((mx.z - mn.z) if os.environ.get("AXIS") == "z" else (mx.x - mn.x))   # AXIS=z : hache (manche vertical)
m = Matrix.Scale(k, 4) @ (Matrix.Rotation(math.pi, 4, "Z") if flip else Matrix.Identity(4)) @ Matrix.Translation(-c)
for o in meshes:
    o.data.transform(m)
pts = [v.co for o in meshes for v in o.data.vertices]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
print("boîte", tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx))
for n, (fx, fz) in marks.items():
    e = bpy.data.objects.new(n, None)
    bpy.context.collection.objects.link(e)
    e.location = (mn.x + fx * (mx.x - mn.x), 0.0, mn.z + fz * (mx.z - mn.z))
    print(n, tuple(round(v, 3) for v in e.location))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_image_quality=90)
