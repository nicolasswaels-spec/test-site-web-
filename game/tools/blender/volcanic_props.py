"""Décor de la zone volcanique, modélisé par script (bpy) : 3 rochers de basalte à facettes
(bloc, aiguille, dalle), un éperon rocheux et un volcan à cratère. Les couleurs, fissures de lave
et coulées sont faites dans Godot par shader (scripts/volcanic.gd) : on n'exporte que la forme
et, pour le volcan, des UV (angle autour du sommet, distance au sommet) qui guident les coulées.
Usage : python3 volcanic_props.py <dossier de sortie>"""
import sys, os, math, random
import bpy, bmesh
from mathutils import Vector, noise

out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(obj, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB", use_selection=True,
                              export_normals=True, export_materials="NONE")
    print("exporté", name, len(obj.data.vertices), "sommets")


def rock(name, seed, stretch, amp, flat_bottom=-0.25, subdiv=3, spikes=0.0):
    reset()
    random.seed(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((seed * 7.3, seed * 1.7, seed * 3.1))
    for v in bm.verts:
        p = v.co.copy()
        d = noise.fractal(p * 1.3 + off, 0.6, 2.1, 4) * amp
        d += noise.noise(p * 3.5 + off) * amp * 0.35
        if spikes:
            d += max(0.0, noise.noise(p * 2.2 + off * 2)) * spikes
        v.co = p * (1.0 + d)
        v.co.x *= stretch[0]
        v.co.y *= stretch[1]
        v.co.z *= stretch[2]
        if v.co.z < flat_bottom * stretch[2]:
            v.co.z = flat_bottom * stretch[2] - 0.05 * random.random()
    # facettes nettes : on fusionne les petites faces, puis normales plates
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(9), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for f in me.polygons:
        f.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    # base posée à z = 0
    zmin = min(v.co.z for v in me.vertices)
    for v in me.vertices:
        v.co.z -= zmin
    export(ob, name)


def volcano(name, seed=3):
    """Cône concave à cratère, ravines rayonnantes. Hauteur 1, rayon 1 ; UV = (angle, r)."""
    reset()
    rings, segs = 48, 96
    rim = 0.13
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new()
    off = Vector((seed, seed * 2.0, 0))
    grid = []
    for i in range(rings + 1):
        r = i / rings
        row = []
        for j in range(segs):
            a = j / segs * math.tau
            if r < rim:
                h = 0.97 - (rim - r) / rim * 0.22            # cratère
            else:
                t = (r - rim) / (1 - rim)
                h = 0.97 * (1 - t) ** 1.7                     # flanc concave
            gully = noise.noise(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, r * 5.0)) + off)
            h *= 1.0 + 0.07 * gully
            rr = r * (1.0 + 0.06 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, 7.0)) + off))
            # rebord du cratère irrégulier
            if abs(r - rim) < 0.03:
                h += 0.03 * noise.noise(Vector((math.cos(a) * 6, math.sin(a) * 6, 1.0)) + off)
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, h)))
        grid.append(row)
    for i in range(rings):
        for j in range(segs):
            j2 = (j + 1) % segs
            f = bm.faces.new((grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]))
            for l in f.loops:
                v = l.vert
                a = math.atan2(v.co.y, v.co.x) / math.tau % 1.0
                # couture : le dernier segment reprend à 1.0 plutôt qu'à 0.0
                if j == segs - 1 and a < 0.5:
                    a += 1.0
                l[uv_layer].uv = (a, math.hypot(v.co.x, v.co.y))
    # fond du cratère
    centre = bm.verts.new((0, 0, 0.97 - 0.22))
    for j in range(segs):
        f = bm.faces.new((grid[0][(j + 1) % segs], grid[0][j], centre))
        for l in f.loops:
            l[uv_layer].uv = (j / segs, 0.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for f in me.polygons:
        f.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    export(ob, name)


rock("rock_block", 1, (1.25, 1.0, 0.8), 0.32)
rock("rock_spire", 2, (0.55, 0.5, 1.9), 0.28, flat_bottom=-0.6, spikes=0.25)
rock("rock_slab", 3, (1.6, 1.2, 0.45), 0.25, flat_bottom=-0.1)
rock("rock_crag", 4, (1.1, 0.9, 1.3), 0.45, subdiv=4, spikes=0.35)
volcano("volcano")
