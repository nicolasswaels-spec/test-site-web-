"""Bras à la 1re personne : modèle Meshy (bras droit, main ouverte, doigts écartés) -> squelette
complet doigt par doigt, posé par script.
Repère après normalisation : X = vers le bout des doigts (0 = bout de la manche, 0,6 m au total),
paume tournée vers -Y, pouce vers -Z.
Os : arm (manche) -> forearm -> hand -> thumb_1..3 et index/middle/ring/pinky_1..3.
Influences : chaque doigt (composante connexe du maillage au-delà des jointures) ne suit que sa
propre chaîne (+ la main) ; le reste suit les os les plus proches (inverse de la distance).
Usage : python3 rig_fp_arm.py <arm_meshy.glb> <sortie.glb> [dossier_test_rendus]"""
import sys, os, math
import bpy, bmesh
import numpy as np
from mathutils import Vector

src, out = sys.argv[1], sys.argv[2]
test_dir = sys.argv[3] if len(sys.argv) > 3 else None
LENGTH = 0.6
KNUCKLE_X = 0.505       # au-delà : doigts séparés
WRIST_X = 0.39

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
body = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o != body:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = body.data
P = np.array([v.co[:] for v in me.vertices])
k = LENGTH / (P[:, 0].max() - P[:, 0].min())
off = np.array([-P[:, 0].min(), 0.0, 0.0])
for v in me.vertices:
    v.co = (Vector(v.co) * k) + Vector(off * k)
me.update()
# l'import coupe le maillage le long des coutures de texture : on refusionne les sommets confondus
# (sinon deux points au même endroit suivent des os différents et le cuir se déchire)
bm = bmesh.new()
bm.from_mesh(me)
n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
print("sommets fusionnés :", n0 - len(bm.verts))
bm.to_mesh(me)
bm.free()
me.update()
P = np.array([v.co[:] for v in me.vertices])
N = len(P)

# ------------------------------------------------------------------ doigts : composantes connexes
adj = [[] for _ in range(N)]
for e in me.edges:
    a, b = e.vertices
    adj[a].append(b)
    adj[b].append(a)


def components(mask):
    comp = -np.ones(N, int)
    cid = 0
    for s in np.nonzero(mask)[0]:
        if comp[s] >= 0:
            continue
        stack = [s]
        comp[s] = cid
        while stack:
            u = stack.pop()
            for w in adj[u]:
                if mask[w] and comp[w] < 0:
                    comp[w] = cid
                    stack.append(w)
        cid += 1
    return comp, cid


# bouts des doigts (bien séparés) -> 4 graines ; puis chaque sommet de la zone des doigts va au doigt
# dont l'axe est le plus proche (les doigts se touchent près des jointures)
def axis_line(pts):
    c = pts.mean(0)
    u, s_, vt = np.linalg.svd(pts - c)
    d = vt[0] if vt[0][0] > 0 else -vt[0]
    return c, d


tip_mask = (P[:, 0] > 0.535) & (P[:, 2] > -0.045)
comp, nc = components(tip_mask)
sizes = sorted([(int((comp == c).sum()), c) for c in range(nc)], reverse=True)
seeds = [c for (n, c) in sizes[:4]]
print("bouts de doigts :", [n for n, c in sizes[:6]])
seeds.sort(key=lambda c: P[comp == c][:, 2].mean())
names = ["index", "middle", "ring", "pinky"]
seed_z = np.array([P[comp == c][:, 2].mean() for c in seeds])
tmask = (P[:, 0] > 0.41) & (P[:, 2] < -0.045)
tcomp, tnc = components(tmask)
tsz = sorted([(int((tcomp == c).sum()), c) for c in range(tnc)], reverse=True)
thumb_ids = np.nonzero(tcomp == tsz[0][1])[0]
print("pouce :", len(thumb_ids), "sommets")
fz = (P[:, 0] > KNUCKLE_X) & ~np.isin(np.arange(N), thumb_ids)
# 1er passage : par la hauteur (z) des bouts ; puis axe de chaque doigt sur toute sa longueur,
# et 2e passage par distance à ces axes
near = np.abs(P[:, 2][:, None] - seed_z[None]).argmin(1)
lines = {}
for i, nm in enumerate(names):
    c, d = axis_line(P[fz & (near == i)])
    if d[0] < 0.6:                       # axe aberrant : on retombe sur l'axe X
        d = np.array([1.0, 0.0, 0.0])
    lines[nm] = (c, d)
dist = np.stack([np.linalg.norm(np.cross(P - c, d), axis=1) for (c, d) in lines.values()], 1)
near = dist.argmin(1)
hand_center = P[(P[:, 0] > 0.42) & (P[:, 0] < 0.48)].mean(0)
chains = {}
for i, nm in enumerate(names):
    ids = np.nonzero(fz & (near == i))[0]
    c, d = lines[nm]
    tip = c + d * ((P[ids] - c) @ d).max()
    tb = (KNUCKLE_X - 0.03 - c[0]) / d[0]       # point de l'axe à la jointure (dans la paume)
    chains[nm] = (ids, c + d * tb, tip)
def axis_of(ids, root_hint):
    """Axe principal d'un doigt : base (côté main) -> bout."""
    c, d = axis_line(P[ids])
    proj = (P[ids] - c) @ d
    a, b = c + d * proj.min(), c + d * proj.max()
    if np.linalg.norm(b - root_hint) < np.linalg.norm(a - root_hint):
        a, b = b, a
    return a, b


a, b = axis_of(thumb_ids, hand_center)
chains["thumb"] = (thumb_ids, a - (b - a) / np.linalg.norm(b - a) * 0.02, b)

tips_y = np.mean([chains[n][2][1] - chains[n][1][1] for n in names])
palm_y = np.sign(tips_y) or -1.0      # les doigts au repos s'incurvent légèrement vers la paume
print("pouce côté y %+.0f ; bouts des doigts : dy %.4f" % (palm_y, tips_y))
PALM_N = np.array([0.0, palm_y, 0.0])

# ------------------------------------------------------------------ squelette
axis_pts = lambda x: P[(P[:, 0] > x - 0.01) & (P[:, 0] < x + 0.01)].mean(0)
arm_data = bpy.data.armatures.new("fp_rig")
rig = bpy.data.objects.new("fp_rig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones


def bone(name, h, t, parent=None):
    b = eb.new(name)
    b.head, b.tail = Vector(h), Vector(t)
    b.roll = 0.0
    if parent:
        b.parent = eb[parent]
    return name


bone("arm", axis_pts(0.02), axis_pts(0.2))
bone("forearm", axis_pts(0.2), axis_pts(WRIST_X), "arm")
bone("hand", axis_pts(WRIST_X), hand_center + np.array([0.05, 0, 0]), "forearm")
segs = {}
for nm, (ids, base, tip) in chains.items():
    pts = [base + (tip - base) * f for f in (0.0, 0.42, 0.72, 1.0)]
    for i in range(3):
        bone("%s_%d" % (nm, i + 1), pts[i], pts[i + 1], "hand" if i == 0 else "%s_%d" % (nm, i))
    segs[nm] = pts
bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ influences (poids)
bones = {b.name: (np.array(b.head_local), np.array(b.tail_local)) for b in arm_data.bones}


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a[None] + t[:, None] * ab[None]), axis=1)


D = {n: seg_dist(P, a, b) for n, (a, b) in bones.items()}
allowed = np.zeros((N, len(bones)), bool)
bnames = list(bones)
idx = {n: i for i, n in enumerate(bnames)}
owner = np.full(N, "", object)
for nm, (ids, base, tip) in chains.items():
    owner[ids] = nm
for i in range(N):
    own = owner[i]
    if own:
        for j in (1, 2, 3):
            allowed[i, idx["%s_%d" % (own, j)]] = True
        allowed[i, idx["hand"]] = True
    else:
        for n in ("arm", "forearm", "hand"):
            allowed[i, idx[n]] = True
        if P[i, 0] > 0.44:      # paume près des jointures : les 1res phalanges tirent un peu
            for nm in chains:
                allowed[i, idx[nm + "_1"]] = True
Dm = np.stack([D[n] for n in bnames], 1)
W = np.where(allowed, 1.0 / np.maximum(Dm, 0.002) ** 4, 0.0)
W /= W.sum(1, keepdims=True)
# lissage des influences le long des arêtes du maillage (évite les déchirures aux jointures)
nb = [np.array(x, int) for x in adj]
for it in range(int(os.environ.get("SMOOTH", "12"))):
    avg = np.stack([W[n].mean(0) if len(n) else W[i] for i, n in enumerate(nb)])
    W = np.where(allowed, 0.5 * W + 0.5 * avg, 0.0)
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
W[W < 0.02] = 0
W /= W.sum(1, keepdims=True)
for n in bnames:
    vg = body.vertex_groups.new(name=n)
    col = W[:, idx[n]]
    for i in np.nonzero(col > 0)[0]:
        vg.add([int(i)], float(col[i]), "REPLACE")
body.parent = rig
md = body.modifiers.new("rig", "ARMATURE")
md.object = rig
print("squelette :", len(bnames), "os")

# ------------------------------------------------------------------ pose test : poing fermé
CURL = {"_1": 70, "_2": 85, "_3": 60}
FIST_SIGN = float(os.environ.get("FIST_SIGN", "1"))


def pose_fist(amount, sign=1.0):
    """Ferme la main : chaque phalange tourne autour de (direction de l'os x normale de la paume)."""
    from mathutils import Quaternion
    n = Vector(PALM_N.tolist())
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        for suf, ang in CURL.items():
            if pb.name.endswith(suf):
                rest = pb.bone.matrix_local.to_3x3()
                d = (rest @ Vector((0, 1, 0))).normalized()
                axis_w = d.cross(n).normalized() * sign
                axis_l = (rest.inverted() @ axis_w).normalized()
                k = 0.7 if pb.name.startswith("thumb") else 1.0
                pb.rotation_quaternion = Quaternion(axis_l, math.radians(ang * amount * k))
    bpy.context.view_layer.update()


if test_dir:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from common import preview_setup, light, camera, render
    preview_setup((1000, 700), 48)
    light("key", "SUN", (0, 0, 0), (50, 0, 30), (1.0, 0.8, 0.6), 3.0)
    light("fill", "SUN", (0, 0, 0), (60, 0, 210), (0.6, 0.65, 1.0), 1.0)
    hc = Vector(hand_center.tolist())
    cams = {"face": ((hc.x + 0.05, hc.y - 0.35, hc.z + 0.12), (hc.x + 0.03, hc.y, hc.z)),
            "profil": ((hc.x + 0.06, hc.y - 0.05, hc.z + 0.38), (hc.x + 0.06, hc.y - 0.02, hc.z)),
            "34": ((hc.x + 0.3, hc.y - 0.25, hc.z + 0.2), (hc.x + 0.04, hc.y - 0.02, hc.z))}
    for amt in (0.5, 1.0):
        pose_fist(amt, FIST_SIGN)
        for cn, (loc, tgt) in cams.items():
            camera(loc, tgt, 50)
            render(os.path.join(test_dir, "fist_%d_%s.png" % (int(amt * 100), cn)))
    pose_fist(0.0)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_image_quality=88)
print("OK")
