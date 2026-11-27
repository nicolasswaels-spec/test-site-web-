"""Arbres calcinés de la zone volcanique (ceux qu'on coupe à la hache), modélisés par script :
tronc noueux à racines évasées et écorce crevassée, cime cassée en éclats, branches mortes
tordues dont certaines brisées. Pas de feuillage. Couleur, braises et cendres : shader dans Godot
(scripts/volcanic.gd). Pied du tronc en (0, 0, 0), hauteur ~9 m, rayon du tronc ~0.42 m.
Usage : python3 charred_trees.py <dossier de sortie>"""
import sys, os, math, random
import bpy, bmesh
from mathutils import Vector, Matrix, noise

out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def sweep(bm, path, radii, segs, groove=0.0, seed=0.0, jag_top=0.0):
    """Tube le long d'un chemin (liste de Vector), rayons par point. groove : crevasses verticales."""
    rings = []
    prev_n = None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        # repère stable le long du tube
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        n = prev_n if prev_n is not None else t.cross(ref).normalized()
        n = (n - t * n.dot(t)).normalized()
        b = t.cross(n)
        prev_n = n
        ring = []
        for j in range(segs):
            a = j / segs * math.tau
            r = radii[i]
            if groove:
                r *= 1.0 + groove * (math.sin(a * 7 + noise.noise(Vector((p.z * 0.6, seed, a))) * 2.5) * 0.5
                                     + noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, p.z * 1.5 + seed))) * 0.6)
            q = p + (n * math.cos(a) + b * math.sin(a)) * r
            if jag_top and i == len(path) - 1:
                q += t * jag_top * (0.3 + random.random())     # bout cassé en éclats
            ring.append(bm.verts.new(q))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            bm.faces.new((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
    # bout : on referme en éventail (pointe)
    tip = bm.verts.new(path[-1] + (path[-1] - path[-2]).normalized() * radii[-1] * 0.6)
    for j in range(segs):
        bm.faces.new((rings[-1][j], rings[-1][(j + 1) % segs], tip))
    return rings


def bent_path(start, direction, length, steps, wobble, up_pull, seed):
    pts = [start.copy()]
    d = direction.normalized()
    p = start.copy()
    for i in range(steps):
        k = Vector((noise.noise(Vector((i * 0.7, seed, 0.0))), noise.noise(Vector((seed, i * 0.7, 1.0))), 0.0))
        d = (d + k * wobble + Vector((0, 0, up_pull))).normalized()
        p = p + d * (length / steps)
        pts.append(p.copy())
    return pts


def tree(name, seed, height=9.0, base_r=0.42, lean=0.08, n_branches=5):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(seed)
    bm = bmesh.new()
    # tronc : légèrement tordu, racines évasées, s'affine vers une cime cassée
    steps = 16
    lean_dir = Vector((math.cos(seed), math.sin(seed), 0)) * lean
    path = []
    for i in range(steps + 1):
        t = i / steps
        off = lean_dir * t * height * 0.3 + Vector((noise.noise(Vector((t * 3, seed, 0))), noise.noise(Vector((seed, t * 3, 0))), 0)) * 0.25 * t
        path.append(Vector((0, 0, -0.3 + t * (height + 0.3))) + off)
    radii = []
    for i in range(steps + 1):
        t = i / steps
        r = base_r * (1.0 - 0.7 * t) + base_r * 0.9 * (max(0.0, 0.14 - t) / 0.14) ** 2
        radii.append(r)
    sweep(bm, path, radii, 18, groove=0.38, seed=seed, jag_top=1.2)
    # racines apparentes
    for k in range(6):
        a = k / 6 * math.tau + random.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), -0.55))
        rp = bent_path(Vector((math.cos(a), math.sin(a), 0)) * base_r * 0.3 + Vector((0, 0, 0.9)), d, random.uniform(1.4, 2.2), 5, 0.3, 0.06, seed + k)
        rp = [Vector((q.x, q.y, max(q.z, -0.1))) for q in rp]
        sweep(bm, rp, [base_r * 0.55 * (1 - 0.85 * i / 5) + 0.03 for i in range(len(rp))], 8, groove=0.15, seed=seed + k)
    # branches mortes, tordues, vers le haut ; certaines cassées net
    for k in range(n_branches):
        h = random.uniform(0.3, 0.88)
        idx = int(h * steps)
        a = random.uniform(0, math.tau)
        start = path[idx]
        d = Vector((math.cos(a), math.sin(a), random.uniform(0.4, 1.1)))
        ln = random.uniform(2.2, 4.0) * (1.25 - h * 0.6)
        broken = random.random() < 0.4
        if broken:
            ln *= 0.45
        bp = bent_path(start, d, ln, 6, 0.35, 0.12, seed * 10 + k)
        r0 = radii[idx] * random.uniform(0.4, 0.58)
        sweep(bm, bp, [r0 * (1 - 0.75 * i / 6) + 0.015 for i in range(len(bp))], 7, jag_top=0.25 if broken else 0.0)
        # rameau secondaire
        if not broken and random.random() < 0.7:
            j = random.randint(2, 4)
            d2 = (bp[j + 1] - bp[j]).normalized() + Vector((random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), 0.5))
            sp = bent_path(bp[j], d2, ln * 0.45, 4, 0.4, 0.1, seed * 20 + k)
            sweep(bm, sp, [r0 * 0.45 * (1 - 0.7 * i / 4) + 0.01 for i in range(len(sp))], 5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for f in me.polygons:
        f.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB", use_selection=True,
                              export_materials="NONE")
    print("exporté", name, len(me.vertices), "sommets")


tree("charred_1", 1, height=9.5, n_branches=8)
tree("charred_2", 2, height=8.0, base_r=0.46, n_branches=6, lean=0.15)
tree("charred_3", 3, height=10.5, base_r=0.42, n_branches=9)
tree("charred_4", 4, height=6.5, base_r=0.5, n_branches=4, lean=0.2)
