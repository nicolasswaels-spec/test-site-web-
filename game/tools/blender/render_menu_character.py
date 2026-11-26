"""Rendu du voyageur pour l'illustration animée du menu principal (1920×1080, fond transparent,
ombre portée sur l'herbe gardée dans l'alpha) + un calque « lueur des yeux » à part, que le menu
fait pulser. Éclairage calé sur la keyart : soleil couchant orange derrière, lueur turquoise de la
sphère devant, ambiance violette.
Usage : python3 render_menu_character.py <traveler.glb> <dossier de sortie>"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector

src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
ad = arm.animation_data
for tr in ad.nla_tracks:
    tr.mute = True
act = bpy.data.actions["Idle"]
ad.action = act
if hasattr(ad, "action_slot") and act.slots:
    ad.action_slot = act.slots[0]
sc = bpy.context.scene
sc.frame_set(30)
# orientation : on mesure où regarde la tête (os « headfront ») dans l'animation, puis on tourne
# le personnage pour qu'il regarde de trois quarts vers la gauche de l'image (vers la sphère)
bpy.context.view_layer.update()
pb = arm.pose.bones
look = (arm.matrix_world @ pb["headfront"].head) - (arm.matrix_world @ pb["Head"].head)
look.z = 0
want = Vector((-0.75, -0.66, 0))       # vers la caméra et la gauche
pivot = bpy.data.objects.new("pivot", None)
sc.collection.objects.link(pivot)
mw = arm.matrix_world.copy()
arm.parent = pivot
arm.matrix_world = mw
pivot.rotation_euler.z = math.atan2(want.y, want.x) - math.atan2(look.y, look.x) + math.radians(50)   # correction mesurée : headfront pointe de côté
bpy.context.view_layer.update()
print("rotation appliquée (°) :", math.degrees(pivot.rotation_euler.z))

# sol « attrape-ombre »
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
ground = bpy.context.object
ground.is_shadow_catcher = True

sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 128
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.render.film_transparent = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.18, 0.12, 0.32, 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.15


def light(name, kind, loc, rot, color, energy, size=1.0):
    ld = bpy.data.lights.new(name, kind)
    ld.color = color
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    if kind == "SUN":
        ld.angle = math.radians(3)
    o = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


# soleil couchant : derrière le personnage, un peu à gauche, rasant (contre-jour orange)
light("sun", "SUN", (0, 0, 0), (80, 0, 160), (1.0, 0.55, 0.28), 5.0)
# sphère turquoise : devant-gauche
light("orb", "AREA", (-2.6, -2.2, 1.3), (70, 0, -50), (0.25, 0.95, 0.9), 120, 1.2)
# ciel violet : douche douce au-dessus
light("sky", "AREA", (0.5, -1.0, 4.0), (10, 0, 0), (0.55, 0.45, 1.0), 22, 4.0)

cd = bpy.data.cameras.new("cam")
cd.lens = 35
cam = bpy.data.objects.new("cam", cd)
sc.collection.objects.link(cam)
# personnage dans le tiers droit, pieds vers le bas de l'image, ~55 % de la hauteur
cam.location = (-2.05, -5.55, 1.15)
d = Vector((-2.05, 0, 1.24)) - cam.location
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
sc.camera = cam

sc.render.filepath = os.path.join(out, "menu_character.png")
bpy.ops.render.render(write_still=True)

# calque des yeux : pixels turquoise lumineux de l'image, flous (lueur additive)
from PIL import Image, ImageFilter
im = np.asarray(Image.open(sc.render.filepath).convert("RGBA")).astype(np.float32) / 255.0
r, g, b, a = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
mask = (g > 0.35) & (b > 0.35) & (r < 0.55 * g) & (g - r > 0.25) & (a > 0.5)
ys, xs = np.nonzero(mask)
print("yeux :", len(xs), "pixels, centre", (xs.mean() if len(xs) else -1), (ys.mean() if len(ys) else -1))
glow = np.zeros_like(im)
glow[mask] = [0.3, 1.0, 0.95, 1.0]
gi = Image.fromarray((glow * 255).astype(np.uint8), "RGBA")
big = gi.filter(ImageFilter.GaussianBlur(10))
small = gi.filter(ImageFilter.GaussianBlur(3))
big.alpha_composite(small)
big.save(os.path.join(out, "menu_character_eyes.png"))
