"""Icônes d'inventaire des armes rendues depuis les modèles du jeu (Cycles, fond transparent,
vue de trois quarts, éclairage clé + contre-jour + liseré), 512 px puis réduites à 256.
Usage : python3 render_weapon_icons.py <dossier armes> <dossier ui>"""
import sys, os, math
import bpy
from mathutils import Vector

src, out = sys.argv[1], sys.argv[2]
for name in ["pistol", "rifle", "cryo", "shock", "sniper", "zeus", "axe"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + ".glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        if o.type == "EMPTY" and o.name in ("muzzle", "sight", "hand_r", "hand_l"):
            o.hide_render = True
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    size = max((mx - mn).x, (mx - mn).z, (mx - mn).y)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.33, 0.5, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    cd = bpy.data.cameras.new("c")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam)
    # arme : X = avant. Vue de trois quarts : un peu de côté (-Y), un peu au-dessus ; canon vers la droite
    d = Vector((0.25, -1.0, 0.32)).normalized() if name != "axe" else Vector((0.0, -1.0, 0.15)).normalized()
    cam.location = c + d * size * 3
    cam.rotation_euler = (-d).to_track_quat("-Z", "Z").to_euler()
    if name != "axe":
        # canon incliné vers le haut à droite (diagonale de l'icône)
        cam.rotation_euler.rotate_axis("Z", math.radians(-28))
    cd.ortho_scale = size * (1.08 if name != "axe" else 1.02)
    sc.camera = cam

    def light(kind, rot, energy, color, size=1.0):
        ld = bpy.data.lights.new(kind, "AREA")
        ld.energy = energy
        ld.color = color
        ld.size = size * 3
        o = bpy.data.objects.new(kind, ld)
        sc.collection.objects.link(o)
        o.location = c + rot * size * 3
        o.rotation_euler = (-rot).to_track_quat("-Z", "Y").to_euler()
    light("key", Vector((0.6, -0.8, 0.9)).normalized(), 300 * size * size, (1.0, 0.92, 0.82), size)
    light("rim", Vector((-0.5, 0.9, 0.5)).normalized(), 500 * size * size, (0.55, 0.75, 1.0), size)
    light("fill", Vector((-0.8, -0.6, -0.2)).normalized(), 80 * size * size, (0.8, 0.6, 1.0), size)
    sc.render.filepath = os.path.join(out, "w_%s_512.png" % name)
    bpy.ops.render.render(write_still=True)
    print("rendu", name)
