"""Assemble le personnage généré par Meshy (modèle squeletté + animations séparées) en un seul GLB
pour Godot : animations renommées comme l'ancien modèle KayKit (Idle, Walking_A, Running_A,
Jump_Idle), yeux rendus lumineux (masque des pixels turquoise de la texture), textures réduites.
Usage : python3 assemble_character.py <dossier des GLB Meshy> <sortie.glb>
Le dossier contient rig.glb (modèle + squelette), idle.glb, walk.glb, run.glb, fall.glb, death.glb."""
import sys, os
import bpy
import numpy as np

src, out = sys.argv[1], sys.argv[2]
TEX = 1024
ANIMS = [("idle.glb", "Idle"), ("walk.glb", "Walking_A"), ("run.glb", "Running_A"), ("fall.glb", "Jump_Idle"), ("death.glb", "Death_A")]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(src, "rig.glb"))
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
body = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm][0]
for o in list(bpy.data.objects):
    if o not in (arm, body):
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
keep_imgs = set(bpy.data.images)

actions = []
for f, name in ANIMS:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, f))
    act = [a for a in bpy.data.actions if a not in actions][0]
    act.name = name
    act.use_fake_user = True
    actions.append(act)
    for o in list(bpy.data.objects):
        if o not in before:
            bpy.data.objects.remove(o)
for im in list(bpy.data.images):
    if im not in keep_imgs:
        bpy.data.images.remove(im)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)
for m in list(bpy.data.materials):
    if m.users == 0:
        bpy.data.materials.remove(m)

# animations : chaque action est liée au squelette (slot) puis exportée en mode « ACTIONS »
ad = arm.animation_data_create()
for act in actions:
    ad.action = act
    if act.slots:
        ad.action_slot = act.slots[0]
ad.action = None

# yeux lumineux : pixels turquoise vifs de la couleur de base -> texture d'émission
mat = body.data.materials[0]
nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
base_img = bsdf.inputs["Base Color"].links[0].from_node.image
w, h = base_img.size
px = np.array(base_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
r, g, b = px[..., 0], px[..., 1], px[..., 2]
mask = (g > 0.35) & (b > 0.35) & (r < 0.5 * g) & ((g + b) - 2 * r > 0.5)
print("pixels yeux :", int(mask.sum()))
em = np.zeros_like(px)
em[..., 3] = 1.0
em[mask, 0:3] = px[mask, 0:3]
em_img = bpy.data.images.new("emission", w, h)
em_img.pixels[:] = em.ravel()
em_img.pack()
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = em_img
nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
bsdf.inputs["Emission Strength"].default_value = 4.0

# textures réduites (poids du jeu)
for im in bpy.data.images:
    if im.size[0] > TEX:
        im.scale(TEX, TEX)
        im.pack()

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="ACTIONS",
                          export_image_format="JPEG", export_image_quality=88)
print("OK", out, [a.name for a in actions])
