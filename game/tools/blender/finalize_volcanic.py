"""Prépare un décor Meshy de la zone volcanique (arbre calciné, rocher magmatique) :
pied posé en z = 0 et centré, mis à la hauteur voulue, texture réduite, et texture d'émission
tirée des veines de lave orange de la texture (elles brillent dans le jeu).
Usage : python3 finalize_volcanic.py <entrée.glb> <sortie.glb> <hauteur_m> [taille_texture]"""
import sys
import bpy
import numpy as np
from mathutils import Vector
from PIL import Image, ImageFilter

src, out, height = sys.argv[1], sys.argv[2], float(sys.argv[3])
tex = int(sys.argv[4]) if len(sys.argv) > 4 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [v.co for o in meshes for v in o.data.vertices]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
k = height / (mx.z - mn.z)
for o in meshes:
    for v in o.data.vertices:
        v.co = Vector(((v.co.x - (mn.x + mx.x) / 2) * k, (v.co.y - (mn.y + mx.y) / 2) * k, (v.co.z - mn.z) * k))
print("taille", tuple(round((mx[i] - mn[i]) * k, 2) for i in range(3)))
for o in meshes:
    for mat in o.data.materials:
        nt = mat.node_tree
        bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
        img = bsdf.inputs["Base Color"].links[0].from_node.image
        if img.size[0] > tex:
            img.scale(tex, tex)
        w, h = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[..., :3]
        r, g, b = px[..., 0], px[..., 1], px[..., 2]
        lava = np.clip(((r - b) - 0.35) * 3.0, 0, 1) * np.clip((r - g - 0.15) * 4.0, 0, 1)
        m = Image.fromarray((lava * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))
        lava = np.asarray(m).astype(np.float32) / 255
        em = np.zeros((h, w, 4), np.float32)
        em[..., 0] = lava * 1.0
        em[..., 1] = lava * 0.42
        em[..., 2] = lava * 0.08
        em[..., 3] = 1.0
        ei = bpy.data.images.new(mat.name + "_emission", w, h)
        ei.pixels[:] = em.ravel()
        ei.pack()
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = ei
        nt.links.new(tn.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 2.5
        print("lave :", round(float((lava > 0.3).mean()) * 100, 1), "% de la texture")
        # textures annexes (normal, rugosité) réduites aussi
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > tex:
                n.image.scale(tex, tex)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_image_format="JPEG", export_image_quality=88)
print("ok", out)
