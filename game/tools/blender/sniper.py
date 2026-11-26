"""Fusil de précision — crosse pleine en bois sculpté avec incrustation d'os en flèche,
boîtier bleu-nuit, long canon à bouche de laiton, lunette à bagues de laiton et lentilles bleues,
levier de culasse à pommeau de laiton.
Usage : python3 sniper.py <dossier_rendus|-> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
P = palette()
bone = mat_metal("bone", (0.42, 0.36, 0.26), 0.0, 0.6)
lens = mat_glow("lens", (0.25, 0.6, 1.0), 1.8)

# --- crosse pleine en bois (du talon jusque sous le canon), poignée en col de cygne
stock_pts = smooth_pts([(-0.55, 0.07), (-0.3, 0.075), (-0.18, 0.06), (-0.12, 0.07), (0.42, 0.06), (0.46, 0.045),
                        (0.46, 0.015), (0.0, 0.0), (-0.08, -0.01), (-0.12, -0.1), (-0.16, -0.11), (-0.17, -0.03),
                        (-0.3, -0.04), (-0.53, -0.09), (-0.56, -0.08)], 3)
stock = profile("stock", stock_pts, 0.06, P["wood"], 0.014, 3)
profile("butt", smooth_pts([(-0.56, 0.072), (-0.58, 0.07), (-0.58, -0.09), (-0.555, -0.092)], 3), 0.066, P["leather"], 0.006, 2)
# incrustation d'os en flèche sur les flancs
arrow = [(-0.46, 0.0), (-0.24, 0.0), (-0.24, -0.012), (-0.2, 0.01), (-0.24, 0.032), (-0.24, 0.02), (-0.46, 0.02)]
for side in (1, -1):
    profile("bone_inlay", [(x, z + 0.012) for (x, z) in arrow], 0.004, bone, 0.001, 1, y=side * 0.03)
for x in (0.12, 0.34):
    box("stock_band", (0.02, 0.064, 0.066), (x, 0, 0.032), P["brass"], 0.003, 2)

# --- boîtier et culasse
rec = profile("receiver", smooth_pts([(-0.13, 0.05), (-0.13, 0.1), (0.12, 0.1), (0.14, 0.085), (0.14, 0.05)], 3), 0.05, P["gun"], 0.006, 2)
cyl("bolt", 0.01, 0.06, (-0.06, -0.03, 0.085), P["gun"], rot=(90, 0, 0), verts=16, bevel=0.002)
sphere("bolt_knob", 0.014, (-0.06, -0.065, 0.085), P["brass"], segs=20)
guard = profile("guard", smooth_pts([(-0.1, 0.005), (0.0, 0.005), (-0.005, -0.04), (-0.03, -0.055), (-0.08, -0.055), (-0.1, -0.04)], 3), 0.018, P["dark"], 0.004, 2)
cut(guard, profile("guard_hole", smooth_pts([(-0.09, 0.0), (-0.012, 0.0), (-0.016, -0.035), (-0.035, -0.045), (-0.075, -0.045), (-0.09, -0.035)], 3), 0.05))
box("trigger", (0.007, 0.01, 0.028), (-0.045, 0, -0.015), P["brass"], 0.003, 2, rot=(0, -15, 0))

# --- canon long, bouche de laiton
cyl("barrel", 0.015, 0.62, (0.44, 0, 0.075), P["gun"], verts=20, bevel=0.002)
lathe("muzzle_brake", [(0.74, 0.0), (0.74, 0.024), (0.8, 0.024), (0.81, 0.018), (0.81, 0.0)], P["brass"], 28, z=0.075, bevel=0.002)
cyl("bore", 0.008, 0.02, (0.806, 0, 0.075), mat_metal("bore", (0.005, 0.005, 0.01), 0.2, 0.9), verts=16)

# --- lunette
SZ = 0.15
lathe("scope", [(-0.17, 0.0), (-0.17, 0.03), (-0.12, 0.03), (-0.09, 0.02), (0.1, 0.02), (0.14, 0.034), (0.2, 0.034), (0.2, 0.0)],
      P["gun"], 32, z=SZ, bevel=0.002)
for x in (-0.15, -0.1, 0.12, 0.185):
    cyl("scope_ring", 0.036 if x > 0 else 0.032, 0.008, (x, 0, SZ), P["brass"], verts=32, bevel=0.0015)
cyl("lens_front", 0.03, 0.004, (0.2, 0, SZ), lens, verts=32)
cyl("sight_crystal", 0.026, 0.004, (-0.171, 0, SZ), lens, verts=32)
cyl("turret", 0.013, 0.03, (0.0, 0, SZ + 0.03), P["brass"], rot=(0, 0, 0), verts=20, bevel=0.002)
cyl("turret_side", 0.012, 0.026, (0.0, -0.028, SZ), P["brass"], rot=(90, 0, 0), verts=20, bevel=0.002)
for x in (-0.07, 0.07):
    box("mount", (0.022, 0.03, 0.05), (x, 0, 0.12), P["dark"], 0.004, 2)

marker("muzzle", (0.82, 0, 0.075))
marker("sight", (-0.17, 0, SZ))
marker("hand_r", (-0.13, 0, -0.06))
marker("hand_l", (0.3, 0.04, 0.0))

run("sniper", 1.4, (0.12, 0, 0.03))
