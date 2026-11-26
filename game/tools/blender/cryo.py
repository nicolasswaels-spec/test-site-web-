"""Canon cryogénique — même famille (laiton, bois, métal bleu-nuit) avec une coque émaillée
givrée, un cœur de glace lumineux tenu dans une cage de laiton, un émetteur à ailettes
et des cristaux de glace qui poussent autour de la bouche.
Usage : python3 cryo.py <dossier_rendus|-> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
P = palette()
shell = mat_metal("frost_shell", (0.3, 0.4, 0.5), 0.35, 0.35)
ice = mat_glow("ice", (0.25, 0.7, 1.0), 2.4)

# --- corps émaillé
body_pts = smooth_pts([(-0.16, 0.0), (-0.16, 0.08), (-0.13, 0.1), (0.2, 0.1), (0.25, 0.075), (0.26, 0.02), (0.22, 0.0)], 3)
profile("body", body_pts, 0.085, shell, 0.012, 3)
box("band", (0.42, 0.09, 0.014), (0.04, 0, 0.012), P["brass"], 0.003, 2)
for x in (-0.1, 0.16):
    box("ring", (0.018, 0.092, 0.1), (x, 0, 0.05), P["gun"], 0.004, 2)
# fentes d'aération givrées
for i in range(4):
    box("vent", (0.012, 0.09, 0.006), (0.0 + i * 0.03, 0, 0.07), ice, 0.002, 1)

# --- réservoir : cœur de glace lumineux tenu par une cage de laiton
cyl("ice_core", 0.026, 0.23, (0.01, 0, 0.14), ice, verts=24)
for i in range(6):
    a = 2 * math.pi * i / 6
    cyl("cage_bar", 0.0045, 0.23, (0.01, math.cos(a) * 0.033, 0.14 + math.sin(a) * 0.033), P["gun"], verts=8)
for x in (-0.11, 0.13):
    cyl("tank_cap", 0.042, 0.022, (x, 0, 0.14), P["brass"], verts=24, bevel=0.003)
cyl("tank_mid", 0.037, 0.01, (0.01, 0, 0.14), P["brass"], verts=24, bevel=0.002)
box("tank_mount", (0.16, 0.03, 0.03), (0.01, 0, 0.105), P["gun"], 0.004, 2)

# --- émetteur : cône, ailettes, cristaux de glace autour de la bouche
lathe("emitter", [(0.24, 0.0), (0.24, 0.042), (0.36, 0.03), (0.44, 0.034), (0.46, 0.042), (0.47, 0.0)], P["gun"], 28, z=0.05, bevel=0.003)
for x in (0.3, 0.4):
    cyl("emit_ring", 0.04, 0.012, (x, 0, 0.05), P["brass"], verts=28, bevel=0.002)
for i in range(3):
    a = 2 * math.pi * i / 3 + math.pi / 2
    fin = profile("fin%d" % i, smooth_pts([(0.35, 0.028), (0.45, 0.028), (0.47, 0.068), (0.42, 0.064)], 3), 0.008, shell, 0.002, 1)
    fin.location = (0, 0, 0.05)
    fin.rotation_euler = (a, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
sphere("muzzle_ice", 0.026, (0.47, 0, 0.05), ice, segs=20)
for i in range(5):
    a = 2 * math.pi * i / 5
    crystal("frost%d" % i, 0.008, 0.045, (0.455, math.cos(a) * 0.036, 0.05 + math.sin(a) * 0.036), ice,
            rot=(math.degrees(a) - 90, 60, 0))

# --- poignée en bois, pontet, crosse courte
grip_pts = smooth_pts([(-0.06, 0.0), (-0.12, 0.0), (-0.15, -0.07), (-0.165, -0.14), (-0.12, -0.155), (-0.095, -0.09), (-0.075, -0.05)], 3)
profile("grip", grip_pts, 0.046, P["wood"], 0.012, 3)
guard = profile("guard", smooth_pts([(-0.07, 0.0), (0.04, 0.0), (0.035, -0.05), (0.01, -0.065), (-0.05, -0.065), (-0.07, -0.05)], 3), 0.018, P["dark"], 0.004, 2)
cut(guard, profile("guard_hole", smooth_pts([(-0.06, -0.004), (0.028, -0.004), (0.024, -0.045), (0.005, -0.055), (-0.045, -0.055), (-0.06, -0.045)], 3), 0.05))
box("trigger", (0.007, 0.01, 0.028), (-0.01, 0, -0.025), P["brass"], 0.003, 2, rot=(0, -15, 0))
st_pts = smooth_pts([(-0.16, 0.09), (-0.34, 0.08), (-0.36, 0.06), (-0.36, -0.04), (-0.32, -0.045), (-0.2, 0.0), (-0.16, 0.0)], 3)
profile("stock", st_pts, 0.06, P["wood"], 0.014, 3)
profile("butt", smooth_pts([(-0.36, 0.078), (-0.375, 0.076), (-0.375, -0.046), (-0.36, -0.048)], 3), 0.066, P["brass"], 0.004, 2)

# --- cristal-viseur (glace) à l'arrière du réservoir
cyl("sight_mount", 0.014, 0.012, (-0.1, 0, 0.183), P["brass"], rot=(0, 0, 0), verts=6, bevel=0.002)
crystal("sight_crystal", 0.011, 0.04, (-0.1, 0, 0.2), P["crystal"])

marker("muzzle", (0.49, 0, 0.05))
marker("sight", (-0.1, 0, 0.2))
marker("hand_r", (-0.12, 0, -0.06))
marker("hand_l", (0.3, 0.04, 0.0))

run("cryo", 0.9, (0.05, 0, 0.03))
