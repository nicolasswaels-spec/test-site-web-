"""Fusil d'assaut de garde forestier — même famille que le pistolet.
Boîtier bleu-nuit avec fenêtre sur le cœur de cristal, garde-main et crosse en bois avec
bandes de cuir, chargeur incurvé à semelle de laiton, cristal-viseur sur le dessus.
Usage : python3 rifle.py <dossier_rendus|-> [export.glb]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
P = palette()

# --- boîtier
rec_pts = [(-0.13, 0.0), (-0.13, 0.07), (-0.115, 0.088), (0.2, 0.088), (0.215, 0.075), (0.215, 0.0)]
rec = profile("receiver", rec_pts, 0.06, P["gun"], 0.006, 3)
for i in range(5):
    cut(rec, box("serr%d" % i, (0.004, 0.08, 0.035), (-0.105 + i * 0.01, 0, 0.055)))
win = profile("win", smooth_pts([(0.02, 0.03), (0.17, 0.03), (0.17, 0.058), (0.02, 0.058)], 3), 0.08)
cut(rec, win)
cyl("core", 0.013, 0.16, (0.095, 0, 0.044), P["core"], verts=20)
for x in (0.045, 0.095, 0.145):
    box("bar", (0.006, 0.066, 0.034), (x, 0, 0.044), P["brass"], 0.0015, 2)
box("brass_band", (0.34, 0.064, 0.012), (0.04, 0, 0.006), P["brass"], 0.002, 2)
box("rail", (0.26, 0.022, 0.008), (0.07, 0, 0.092), P["dark"], 0.002, 2)
for i in range(8):
    box("rail_t", (0.008, 0.026, 0.006), (-0.04 + i * 0.03, 0, 0.097), P["dark"], 0.0015, 1)

# --- cristal-viseur sur son support de laiton
cyl("sight_mount", 0.016, 0.014, (-0.06, 0, 0.104), P["brass"], rot=(0, 0, 0), verts=6, bevel=0.002)
crystal("sight_crystal", 0.013, 0.045, (-0.06, 0, 0.122), P["crystal"])

# --- garde-main en bois, bandes de cuir
hg_pts = smooth_pts([(0.215, 0.006), (0.215, 0.08), (0.44, 0.076), (0.46, 0.06), (0.46, 0.018), (0.44, 0.004)], 3)
profile("handguard", hg_pts, 0.07, P["wood"], 0.012, 3)
for x in (0.27, 0.40):
    box("wrap", (0.026, 0.074, 0.08), (x, 0, 0.042), P["leather"], 0.006, 2)
cyl("hg_ring", 0.044, 0.014, (0.462, 0, 0.044), P["brass"], verts=24, bevel=0.002)

# --- canon, tube de gaz, frein de bouche
cyl("barrel", 0.016, 0.2, (0.56, 0, 0.044), P["gun"], verts=20, bevel=0.002)
cyl("gas", 0.009, 0.16, (0.52, 0, 0.074), P["dark"], verts=12, bevel=0.0015)
cyl("gas_ring", 0.022, 0.012, (0.56, 0, 0.06), P["brass"], verts=20, bevel=0.002)
box("front_sight", (0.01, 0.008, 0.03), (0.58, 0, 0.088), P["brass"], 0.002, 2)
brake = lathe("brake", [(0.64, 0.0), (0.64, 0.022), (0.69, 0.024), (0.70, 0.02), (0.70, 0.0)], P["dark"], 24, z=0.044, bevel=0.002)
for x in (0.655, 0.675):
    cut(brake, box("slot", (0.006, 0.08, 0.012), (x, 0, 0.044)))
cyl("muzzle_ring", 0.026, 0.01, (0.637, 0, 0.044), P["brass"], verts=24, bevel=0.002)

# --- chargeur incurvé
mag_pts = smooth_pts([(0.07, 0.005), (0.15, 0.005), (0.15, -0.06), (0.17, -0.15), (0.19, -0.2), (0.12, -0.215), (0.1, -0.16), (0.075, -0.07)], 3)
profile("mag", mag_pts, 0.042, P["dark"], 0.006, 3)
profile("mag_base", smooth_pts([(0.115, -0.208), (0.195, -0.195), (0.2, -0.212), (0.118, -0.228)], 3), 0.05, P["brass"], 0.003, 2)

# --- carcasse, pontet, détente
fr_pts = [(-0.11, 0.0), (0.07, 0.0), (0.06, -0.02), (-0.02, -0.025), (-0.06, -0.012)]
frame = profile("lower", smooth_pts(fr_pts, 3), 0.05, P["gun"], 0.005, 2)
guard = profile("guard", smooth_pts([(-0.04, -0.01), (0.06, -0.01), (0.055, -0.05), (0.03, -0.065), (-0.02, -0.065), (-0.04, -0.05)], 3), 0.018, P["dark"], 0.004, 2)
cut(guard, profile("guard_hole", smooth_pts([(-0.03, -0.012), (0.048, -0.012), (0.044, -0.045), (0.025, -0.055), (-0.015, -0.055), (-0.03, -0.045)], 3), 0.05))
box("trigger", (0.007, 0.01, 0.028), (0.018, 0, -0.03), P["brass"], 0.003, 2, rot=(0, -15, 0))

# --- poignée-pistolet en bois
grip_pts = smooth_pts([(-0.04, 0.0), (-0.1, 0.0), (-0.13, -0.06), (-0.15, -0.13), (-0.11, -0.145), (-0.085, -0.09), (-0.06, -0.05)], 3)
profile("grip", grip_pts, 0.044, P["wood"], 0.012, 3)

# --- crosse en bois, plaque de couche en cuir, médaillon
st_pts = smooth_pts([(-0.12, 0.085), (-0.44, 0.078), (-0.46, 0.06), (-0.46, -0.07), (-0.42, -0.075), (-0.22, -0.01), (-0.12, 0.0)], 3)
profile("stock", st_pts, 0.058, P["wood"], 0.014, 3)
profile("butt", smooth_pts([(-0.46, 0.074), (-0.48, 0.072), (-0.48, -0.078), (-0.46, -0.08)], 3), 0.066, P["leather"], 0.006, 2)
for side in (1, -1):
    cyl("medal", 0.017, 0.005, (-0.3, side * 0.03, 0.03), P["brass"], rot=(90, 0, 0), verts=24, bevel=0.0015)
    sphere("gem", 0.008, (-0.3, side * 0.033, 0.03), P["crystal"], scale=(1, 0.6, 1), segs=16)
box("stock_band", (0.022, 0.062, 0.09), (-0.14, 0, 0.042), P["brass"], 0.003, 2)

# repères pour le jeu
marker("muzzle", (0.71, 0, 0.044))
marker("sight", (-0.06, 0, 0.122))
marker("hand_r", (-0.1, 0, -0.06))
marker("hand_l", (0.33, 0.035, 0.0))

run("rifle", 1.2, (0.1, 0, 0.0))
