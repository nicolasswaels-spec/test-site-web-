"""Ajoute une texture d'émission (lumière) à un modèle Meshy d'après sa couleur de base :
- fissures claires (pixels nettement plus clairs que le marbre autour, peu saturés) -> lumière blanche ;
- cristaux / éclairs (bleu clair saturé) -> lumière bleutée.
Puis réduit les textures et réexporte. Usage :
python3 glow_weapon.py <entrée.glb> <sortie.glb> [force_émission] [nocracks]"""
import sys
import bpy
import numpy as np
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
strength = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0
with_cracks = not (len(sys.argv) > 4 and sys.argv[4] == "nocracks")   # version classique : cristaux seulement
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
body = [o for o in bpy.data.objects if o.type == "MESH"][0]
mat = body.data.materials[0]
nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
img = bsdf.inputs["Base Color"].links[0].from_node.image
w, h = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[..., :3]
lum = px.mean(axis=2)
sat = px.max(axis=2) - px.min(axis=2)
blur = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
cracks = (lum - blur > 0.07) & (sat < 0.12) & (lum > 0.75) & with_cracks
import os
cmin = float(os.environ.get("CRYSTAL_MIN", "0.12"))     # écart bleu-rouge minimal (cryo : plus strict)
crystal = (px[..., 2] > 0.75) & (px[..., 2] - px[..., 0] > cmin) & (lum > 0.6)
amber = np.zeros_like(crystal)
if os.environ.get("AMBER") == "1":                       # cœur / membrane ambrés (onde de choc)
    amber = (px[..., 0] > 0.9) & (px[..., 1] > 0.5) & (px[..., 2] < 0.4) & (px[..., 0] - px[..., 2] > 0.6)
print("fissures :", int(cracks.sum()), "cristal :", int(crystal.sum()), "sur", w * h)
em = np.zeros((h, w, 4), np.float32)
em[..., 3] = 1
em[cracks, :3] = (1.0, 0.98, 0.92)
em[crystal, :3] = (0.55, 0.8, 1.0)
em[amber, :3] = (1.0, 0.6, 0.2)
print("ambre :", int(amber.sum()))
# léger halo autour des fissures (la lumière « bave » un peu sur le marbre)
halo = np.asarray(Image.fromarray((cracks * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255
em[..., :3] = np.maximum(em[..., :3], halo[..., None] * 0.55)
eimg = bpy.data.images.new("emission", w, h)
eimg.pixels[:] = em.ravel()
eimg.pack()
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = eimg
nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
bsdf.inputs["Emission Strength"].default_value = strength
for im in bpy.data.images:
    if im.size[0] > 1024:
        im.scale(1024, 1024)
        im.pack()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_image_quality=90)
