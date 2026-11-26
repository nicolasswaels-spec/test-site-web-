"""Onde de choc — corne d'os sculptée qui s'évase en pavillon, anneaux de laiton, cœur ambré
lumineux dans une cage, membrane ambrée au fond du pavillon, poignée en bois.
Usage : python3 shock.py <dossier_rendus|-> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
P = palette()
bone = mat_metal("bone", (0.42, 0.36, 0.26), 0.0, 0.6)
amber = mat_glow("amber", (1.0, 0.55, 0.15), 2.6)

Z = 0.06
# --- corne : profil de révolution qui s'évase vers l'avant (pavillon creux)
horn = [(-0.2, 0.0), (-0.2, 0.03), (-0.14, 0.04), (-0.02, 0.045), (0.1, 0.052), (0.2, 0.068), (0.26, 0.088),
        (0.29, 0.1), (0.295, 0.093), (0.27, 0.078), (0.23, 0.058), (0.2, 0.0)]
lathe("horn", horn, bone, 40, z=Z, bevel=0.003)
lathe("membrane", [(0.215, 0.0), (0.215, 0.05), (0.22, 0.0)], amber, 32, z=Z)
# nervures sculptées (anneaux d'os en relief) et bagues de laiton
for x, r in ((-0.1, 0.043), (0.0, 0.047), (0.08, 0.052), (0.16, 0.062)):
    lathe("ridge", [(x - 0.008, 0.0), (x - 0.008, r), (x, r + 0.008), (x + 0.008, r), (x + 0.008, 0.0)], bone, 32, z=Z)
for x, r in ((-0.17, 0.036), (0.04, 0.05), (0.25, 0.082)):
    lathe("brass_ring", [(x - 0.01, 0.0), (x - 0.01, r + 0.004), (x + 0.01, r + 0.004), (x + 0.01, 0.0)], P["brass"], 36, z=Z, bevel=0.002)
# pointes d'os sur la lèvre du pavillon
for i in range(8):
    a = 2 * math.pi * i / 8
    cyl("spike%d" % i, 0.009, 0.035, (0.295, math.cos(a) * 0.1, Z + math.sin(a) * 0.1), bone, r2=0.0,
        rot=(0, 90, 0), verts=10)

# --- cœur ambré dans une cage de laiton, sur le dessus
sphere("core", 0.024, (-0.06, 0, Z + 0.075), amber, segs=24)
for i in range(6):
    a = 2 * math.pi * i / 6
    box("cage%d" % i, (0.005, 0.005, 0.07), (-0.06 + math.cos(a) * 0.034, math.sin(a) * 0.034, Z + 0.075), P["brass"], 0.0015, 1)
lathe("cage_ring", [(-0.004, 0.0), (-0.004, 0.034), (0.004, 0.034), (0.004, 0.0)], P["brass"], 24, axis="Z", x=-0.06, z=Z + 0.075)
cyl("cage_base", 0.03, 0.012, (-0.06, 0, Z + 0.045), P["brass"], rot=(0, 0, 0), verts=24, bevel=0.002)
cyl("cage_top", 0.012, 0.012, (-0.06, 0, Z + 0.111), P["brass"], rot=(0, 0, 0), verts=16, bevel=0.002)

# --- poignée en bois, pontet, crosse en os
grip_pts = smooth_pts([(-0.06, 0.02), (-0.12, 0.02), (-0.15, -0.05), (-0.165, -0.12), (-0.12, -0.135), (-0.095, -0.07), (-0.075, -0.03)], 3)
profile("grip", grip_pts, 0.046, P["wood"], 0.012, 3)
profile("grip_frame", smooth_pts([(-0.16, 0.03), (0.02, 0.03), (0.02, 0.01), (-0.16, 0.01)], 3), 0.05, P["gun"], 0.005, 2)
guard = profile("guard", smooth_pts([(-0.07, 0.02), (0.03, 0.02), (0.025, -0.03), (0.0, -0.045), (-0.05, -0.045), (-0.07, -0.03)], 3), 0.018, P["dark"], 0.004, 2)
cut(guard, profile("guard_hole", smooth_pts([(-0.06, 0.012), (0.018, 0.012), (0.014, -0.025), (-0.005, -0.035), (-0.045, -0.035), (-0.06, -0.025)], 3), 0.05))
box("trigger", (0.007, 0.01, 0.028), (-0.018, 0, -0.005), P["brass"], 0.003, 2, rot=(0, -15, 0))

# --- cristal-viseur ambré sur le dessus de la cage
crystal("sight_crystal", 0.009, 0.03, (-0.06, 0, Z + 0.13), amber)

marker("muzzle", (0.31, 0, Z))
marker("sight", (-0.06, 0, Z + 0.13))
marker("hand_r", (-0.12, 0, -0.04))
marker("hand_l", (0.1, 0.045, Z - 0.04))

run("shock", 0.65, (0.05, 0, 0.04))
