"""Pistolet de garde forestier — modélisé par script (bpy).
Culasse métal bleu-nuit, crosse en bois chaud, accents de laiton, cœur de cristal turquoise
(rappel de la sphère) visible par une fenêtre, cristal-viseur à l'arrière, feuille de laiton gravée.
Usage : python3 pistol.py <dossier_rendus> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from common import *

reset()
gun = mat_metal("gunmetal", (0.05, 0.055, 0.09), 0.9, 0.3)
dark = mat_metal("dark", (0.025, 0.025, 0.035), 0.7, 0.45)
brass = mat_metal("brass", (0.8, 0.52, 0.24), 1.0, 0.3)
wood = mat_wood("wood", light=(0.24, 0.1, 0.035), dark=(0.075, 0.028, 0.01))
glow = mat_glow("crystal", (0.1, 0.85, 0.75), 1.4)
core_m = mat_glow("core", (0.08, 0.8, 0.7), 2.2)

# --- culasse : silhouette avec avant fuyant et arrière chanfreiné
slide_pts = [(-0.092, 0.052), (-0.092, 0.088), (-0.084, 0.098), (0.088, 0.098), (0.118, 0.090),
             (0.126, 0.076), (0.126, 0.056), (0.118, 0.052)]
slide = profile("slide", slide_pts, 0.034, gun, 0.0045, 3)
# stries arrière
for i in range(6):
    c = box("serr%d" % i, (0.0032, 0.05, 0.03), (-0.074 + i * 0.0075, 0, 0.076), None, 0)
    cut(slide, c)
# fenêtre sur le cœur de cristal
win = profile("win", smooth_pts([(0.02, 0.064), (0.095, 0.064), (0.095, 0.082), (0.02, 0.082)], 3), 0.05)
cut(slide, win)
cyl("core", 0.0085, 0.085, (0.058, 0, 0.073), core_m, rot=(0, 90, 0), verts=20)
for x in (0.038, 0.058, 0.078):
    box("bar", (0.004, 0.037, 0.022), (x, 0, 0.073), brass, 0.0012, 2)
# nervure de visée
box("rib", (0.17, 0.011, 0.005), (0.005, 0, 0.1), dark, 0.002, 2)
# canon et bouche en laiton
cyl("barrel", 0.0085, 0.02, (0.13, 0, 0.074), dark, verts=24, bevel=0.0012)
cyl("muzzle", 0.0115, 0.009, (0.138, 0, 0.074), brass, verts=32, bevel=0.0018)
cyl("bore", 0.0055, 0.012, (0.141, 0, 0.074), mat_metal("bore", (0.005, 0.005, 0.01), 0.2, 0.9), verts=16)

# --- carcasse + pontet (une seule silhouette, trou découpé)
frame_pts = [(-0.07, 0.052), (0.118, 0.052), (0.118, 0.036), (0.08, 0.032), (0.074, 0.012), (0.066, 0.0),
             (0.05, -0.006), (0.022, -0.006), (0.012, 0.004), (0.006, 0.03), (-0.02, 0.03), (-0.058, 0.036)]
frame = profile("frame", smooth_pts(frame_pts, 3), 0.028, dark, 0.004, 3)
hole = profile("guard_hole", smooth_pts([(0.018, 0.026), (0.07, 0.028), (0.064, 0.008), (0.05, 0.0), (0.026, 0.0), (0.018, 0.01)], 3), 0.05)
cut(frame, hole)
box("trigger", (0.0055, 0.008, 0.02), (0.034, 0, 0.014), brass, 0.0022, 2, rot=(0, -18, 0))
box("rail", (0.05, 0.029, 0.003), (0.085, 0, 0.034), gun, 0.001, 1)

# --- crosse en bois : galbe de paume, creux des doigts, embase de laiton
grip_pts = [(0.004, 0.034), (-0.056, 0.046), (-0.074, 0.03), (-0.084, -0.005), (-0.09, -0.045), (-0.088, -0.078),
            (-0.04, -0.084), (-0.034, -0.062), (-0.026, -0.05), (-0.03, -0.036), (-0.02, -0.022),
            (-0.024, -0.008), (-0.012, 0.006), (-0.008, 0.02)]
grip = profile("grip", smooth_pts(grip_pts, 6), 0.036, wood, 0.011, 4)
cap_pts = [(-0.092, -0.074), (-0.036, -0.081), (-0.036, -0.092), (-0.093, -0.087)]
profile("grip_cap", cap_pts, 0.038, brass, 0.002, 2)
# médaillon de laiton serti d'un petit cristal, de chaque côté de la crosse
for side in (1, -1):
    cyl("medal", 0.011, 0.004, (-0.052, side * 0.019, -0.026), brass, rot=(90, 0, 0), verts=24, bevel=0.0012)
    sphere("gem", 0.0055, (-0.052, side * 0.0215, -0.026), glow, scale=(1, 0.6, 1), segs=16)
box("backstrap", (0.014, 0.03, 0.026), (-0.078, 0, 0.047), dark, 0.004, 2)
box("hammer", (0.011, 0.012, 0.018), (-0.093, 0, 0.09), dark, 0.0035, 2, rot=(0, -22, 0))

# feuille de laiton gravée sur la culasse (rappel de la forêt)
leaf = [(0, 0), (0.006, 0.004), (0.014, 0.004), (0.022, 0), (0.014, -0.004), (0.006, -0.004)]
for side in (1, -1):
    lf = profile("leaf", smooth_pts([(x - 0.026, z + 0.062) for (x, z) in leaf], 3), 0.002, brass, 0.0005, 1, y=side * 0.0175)

# --- visée : guidon de laiton, cristal-viseur à l'arrière
box("front_sight", (0.007, 0.006, 0.009), (0.082, 0, 0.106), brass, 0.002, 2)
cyl("sight_mount", 0.0085, 0.008, (-0.07, 0, 0.102), brass, rot=(0, 0, 0), verts=6, bevel=0.0015)
crystal("sight_crystal", 0.0075, 0.026, (-0.07, 0, 0.113), glow)

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
preview_setup()
dusk_lights(1.0)
views = {
    "pistol_side": ((0.02, -0.62, 0.03), (0.02, 0, 0.005), 55),
    "pistol_34": ((0.4, -0.44, 0.18), (0.015, 0, 0.005), 55),
    "pistol_back": ((-0.42, -0.36, 0.24), (0.02, 0, 0.01), 55),
}
for n, (loc, tgt, lens) in views.items():
    camera(loc, tgt, lens)
    render(os.path.join(out, n + ".png"))
if len(sys.argv) > 2:
    bpy.ops.export_scene.gltf(filepath=sys.argv[2], export_format="GLB", export_apply=True)
