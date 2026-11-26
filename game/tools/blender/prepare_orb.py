"""Socle de la sphère (modèle Meshy d'après le menu) : la boule est séparée en objet « ball » (centrée,
animée par le jeu), on pose la base à z = 0, centrée, à la hauteur voulue, runes lumineuses.
Usage : python3 prepare_orb.py <orb_meshy.glb> <sortie.glb> [hauteur_totale_m]
Affiche la hauteur et le rayon de la boule retirée (à reporter dans orb.gd)."""
import sys, subprocess, os
import bpy, bmesh
from mathutils import Vector, Matrix

src, out = sys.argv[1], sys.argv[2]
total = float(sys.argv[3]) if len(sys.argv) > 3 else 2.2
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [o for o in bpy.data.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
P = [v.co.copy() for v in o.data.vertices]
z0 = min(p.z for p in P); z1 = max(p.z for p in P); H = z1 - z0
cut = z0 + 0.59 * H
ball = [p for p in P if p.z > cut]
bc = sum(ball, Vector()) / len(ball)
br = max((p - bc).length for p in ball)
base = [p for p in P if p.z < z0 + 0.1 * H]
cx = (min(p.x for p in base) + max(p.x for p in base)) / 2
cy = (min(p.y for p in base) + max(p.y for p in base)) / 2
k = total / H
# la boule devient un objet à part (« ball », centrée sur son origine) : le jeu l'anime
ball_o = o.copy()
ball_o.data = o.data.copy()
ball_o.name = "ball"
bpy.context.collection.objects.link(ball_o)
for obj, keep_top in ((o, False), (ball_o, True)):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co.z > cut) != keep_top], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
o.name = "altar"
o.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(Vector((-cx, -cy, -z0))))
ball_o.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(-bc))
print("boule : centre à %.3f m, rayon %.3f m ; socle %.3f m de haut" % ((bc.z - z0) * k, br * k, (cut - z0) * k))
bpy.ops.object.select_all(action="SELECT")
tmp = out + ".tmp.glb"
bpy.ops.export_scene.gltf(filepath=tmp, export_format="GLB", export_image_format="JPEG", export_image_quality=90)
here = os.path.dirname(os.path.abspath(__file__))
subprocess.run([sys.executable, os.path.join(here, "glow_weapon.py"), tmp, out, "2", "nocracks"], check=True)
os.remove(tmp)
