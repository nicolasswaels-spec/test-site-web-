"""Éclair de Zeus — arme céleste : corps de marbre blanc veiné d'or, trois griffes dorées qui
tiennent un éclair de cristal bleu, petites ailes dorées, poignée en bois.
Usage : python3 zeus.py <dossier_rendus|-> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
P = palette()
marble = mat_metal("marble", (0.5, 0.52, 0.6), 0.0, 0.3)
gold = mat_metal("gold", (1.0, 0.72, 0.28), 1.0, 0.22)
bolt_m = mat_glow("bolt", (0.3, 0.65, 1.0), 2.6)

Z = 0.06
# --- corps de marbre (révolution) avec bagues d'or
lathe("body", [(-0.22, 0.0), (-0.22, 0.03), (-0.18, 0.045), (-0.05, 0.05), (0.08, 0.044), (0.16, 0.036), (0.18, 0.0)],
      marble, 36, z=Z, bevel=0.003)
for x, r in ((-0.2, 0.04), (-0.07, 0.052), (0.06, 0.047), (0.165, 0.04)):
    lathe("gold_ring", [(x - 0.008, 0.0), (x - 0.008, r), (x + 0.008, r), (x + 0.008, 0.0)], gold, 36, z=Z, bevel=0.0015)
lathe("pommel", [(-0.26, 0.0), (-0.26, 0.018), (-0.24, 0.03), (-0.22, 0.026), (-0.22, 0.0)], gold, 28, z=Z, bevel=0.002)

# --- trois griffes dorées vers l'avant
for i in range(3):
    a = 2 * math.pi * i / 3 + math.pi / 2
    claw = [(0.15, 0.0), (0.3, 0.012), (0.36, 0.03), (0.34, 0.042), (0.3, 0.03), (0.15, 0.02)]
    o = profile("claw%d" % i, smooth_pts(claw, 3), 0.012, gold, 0.003, 2)
    o.location = (0, 0, Z)
    o.rotation_euler = (a - math.pi / 2, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")

# --- éclair de cristal entre les griffes (zigzag extrudé)
bolt = [(0.17, 0.006), (0.25, 0.022), (0.24, 0.004), (0.33, 0.02), (0.31, 0.0), (0.42, 0.012),
        (0.32, -0.012), (0.335, 0.006), (0.25, -0.014), (0.26, 0.004)]
profile("bolt", [(x, z * 1.4 + Z) for (x, z) in bolt], 0.018, bolt_m, 0.002, 1)
sphere("bolt_core", 0.02, (0.18, 0, Z), bolt_m, segs=20)

# --- petites ailes dorées de chaque côté (rappel du ciel)
wing = smooth_pts([(-0.17, 0.035), (-0.06, 0.04), (-0.02, 0.1), (-0.06, 0.092), (-0.09, 0.11), (-0.12, 0.085), (-0.16, 0.09)], 3)
for side in (1, -1):
    w = profile("wing", wing, 0.006, gold, 0.002, 1)
    w.location = (0, 0, Z)
    w.rotation_euler = (math.radians(side * 70), 0, 0)
# --- poignée en bois, détente dorée
grip_pts = smooth_pts([(-0.09, 0.03), (-0.15, 0.03), (-0.18, -0.04), (-0.19, -0.11), (-0.145, -0.125), (-0.12, -0.06), (-0.1, -0.02)], 3)
profile("grip", grip_pts, 0.044, P["wood"], 0.012, 3)
guard = profile("guard", smooth_pts([(-0.1, 0.03), (0.0, 0.03), (-0.005, -0.02), (-0.03, -0.035), (-0.08, -0.035), (-0.1, -0.02)], 3), 0.016, gold, 0.004, 2)
cut(guard, profile("guard_hole", smooth_pts([(-0.09, 0.022), (-0.012, 0.022), (-0.016, -0.015), (-0.035, -0.025), (-0.075, -0.025), (-0.09, -0.015)], 3), 0.05))
box("trigger", (0.007, 0.01, 0.026), (-0.045, 0, 0.004), gold, 0.003, 2, rot=(0, -15, 0))

# --- cristal-viseur
cyl("sight_mount", 0.012, 0.012, (-0.12, 0, Z + 0.05), gold, rot=(0, 0, 0), verts=6, bevel=0.002)
crystal("sight_crystal", 0.01, 0.035, (-0.12, 0, Z + 0.066), bolt_m)

marker("muzzle", (0.42, 0, Z))
marker("sight", (-0.12, 0, Z + 0.066))
marker("hand_r", (-0.15, 0, -0.04))
marker("hand_l", (0.0, 0.05, Z - 0.04))

run("zeus", 0.75, (0.08, 0, 0.04))
