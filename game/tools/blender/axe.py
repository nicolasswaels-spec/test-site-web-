"""Hache de garde forestier — manche en bois, poignée de cuir, viroles de laiton,
tête bleu-nuit à barbe avec tranchant d'acier clair et rune turquoise.
Manche le long de Z (haut), tranchant vers +X (l'avant dans le jeu).
Usage : python3 axe.py <dossier_rendus|-> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
P = palette()
edge = mat_metal("edge", (0.72, 0.75, 0.82), 1.0, 0.18)

# --- manche (légèrement galbé), poignée de cuir, pommeau et virole
lathe("handle", [(-0.17, 0.0), (-0.17, 0.024), (0.0, 0.022), (0.2, 0.02), (0.42, 0.022), (0.52, 0.024), (0.52, 0.0)],
      P["wood"], 20, axis="Z", bevel=0.002)
lathe("grip_wrap", [(-0.13, 0.0), (-0.13, 0.03), (0.05, 0.028), (0.05, 0.0)], P["leather"], 20, axis="Z")
for i in range(7):
    z = -0.12 + i * 0.026
    lathe("wrap_ridge", [(z - 0.004, 0.0), (z - 0.004, 0.031), (z + 0.004, 0.031), (z + 0.004, 0.0)], P["leather"], 20, axis="Z")
lathe("pommel", [(-0.2, 0.0), (-0.2, 0.026), (-0.185, 0.036), (-0.165, 0.032), (-0.155, 0.026), (-0.155, 0.0)], P["brass"], 24, axis="Z", bevel=0.002)
lathe("collar", [(0.05, 0.0), (0.05, 0.034), (0.07, 0.034), (0.07, 0.0)], P["brass"], 24, axis="Z", bevel=0.002)
lathe("collar_top", [(0.34, 0.0), (0.34, 0.03), (0.36, 0.03), (0.36, 0.0)], P["brass"], 24, axis="Z", bevel=0.002)

# --- tête : joue et barbe (profil X-Z), poing à l'arrière
head_pts = smooth_pts([(-0.06, 0.43), (-0.06, 0.5), (0.03, 0.51), (0.09, 0.53), (0.16, 0.56), (0.19, 0.5),
                       (0.2, 0.42), (0.18, 0.33), (0.13, 0.36), (0.07, 0.41), (0.03, 0.42)], 3)
head = profile("head", head_pts, 0.03, P["gun"], 0.006, 2)
edge_pts = smooth_pts([(0.17, 0.55), (0.2, 0.57), (0.225, 0.5), (0.225, 0.42), (0.2, 0.32), (0.175, 0.33), (0.19, 0.42), (0.19, 0.5)], 3)
profile("edge", edge_pts, 0.012, edge, 0.003, 2)
box("eye", (0.06, 0.042, 0.09), (0.0, 0, 0.465), P["gun"], 0.008, 2)
box("poll", (0.05, 0.036, 0.06), (-0.07, 0, 0.465), P["dark"], 0.008, 2)
# rune turquoise et clous de laiton
for side in (1, -1):
    profile("rune", smooth_pts([(0.08, 0.45), (0.12, 0.47), (0.15, 0.45), (0.12, 0.43)], 3), 0.003, P["crystal"], 0.0008, 1, y=side * 0.016)
    for z in (0.44, 0.49):
        sphere("rivet", 0.006, (0.0, side * 0.022, z), P["brass"], segs=12)

marker("hand_r", (0.0, 0, -0.04))
marker("muzzle", (0.2, 0, 0.45))
marker("sight", (0.0, 0, 0.5))
marker("hand_l", (0.0, 0, 0.2))

run("axe", 1.15, (0.03, 0, 0.17))
