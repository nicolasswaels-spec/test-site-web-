"""Outils communs pour modéliser les armes du jeu dans Blender (bpy), par script.
Unités : mètres. Axe X = avant de l'arme, Z = haut, Y = côté."""
import bpy, bmesh, math
from mathutils import Vector, Euler


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat_metal(name, color, metallic=0.85, rough=0.35):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    return m


def mat_wood(name, light=(0.50, 0.29, 0.14), dark=(0.26, 0.13, 0.06)):
    """Bois chaud avec veinage procédural (sera « cuit » en texture pour Godot)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.62
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (90.0, 90.0, 12.0)
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 1.0
    wave.wave_type = "RINGS"
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 3.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


def mat_glow(name, color, strength=5.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Roughness"].default_value = 0.15
    return m


def _finish(obj, mat, bevel, segments):
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        md = obj.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = segments
        md.limit_method = "ANGLE"
        md.harden_normals = True
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def box(name, size, loc, mat=None, bevel=0.0, segments=3, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=[math.radians(a) for a in rot])
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, mat, bevel, segments)


def cyl(name, r, depth, loc, mat=None, rot=(0, 90, 0), verts=24, bevel=0.0, segments=2, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=loc, rotation=[math.radians(a) for a in rot])
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, vertices=verts, location=loc, rotation=[math.radians(a) for a in rot])
    o = bpy.context.object
    o.name = name
    return _finish(o, mat, bevel, segments)


def sphere(name, r, loc, mat=None, scale=(1, 1, 1), segs=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segs, ring_count=segs // 2)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, mat, 0, 0)


def crystal(name, r, h, loc, mat, rot=(0, 0, 0), sides=6):
    """Cristal taillé : bipyramide hexagonale allongée."""
    bm = bmesh.new()
    ring = [bm.verts.new((r * math.cos(2 * math.pi * i / sides), r * math.sin(2 * math.pi * i / sides), 0)) for i in range(sides)]
    top = bm.verts.new((0, 0, h * 0.62))
    bot = bm.verts.new((0, 0, -h * 0.38))
    for i in range(sides):
        a, b = ring[i], ring[(i + 1) % sides]
        bm.faces.new((a, b, top))
        bm.faces.new((b, a, bot))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    o.data.materials.append(mat)
    return o


def cut(target, cutter):
    """Soustraction booléenne puis suppression de l'outil."""
    md = target.modifiers.new("cut_" + cutter.name, "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.object = cutter
    md.solver = "EXACT"
    # le biseau doit s'appliquer après la découpe
    if "bevel" in target.modifiers:
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.modifier_move_to_index(modifier=md.name, index=0)
    cutter.hide_render = True
    cutter.hide_viewport = True
    return md


def preview_setup(res=(1200, 800), samples=96):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.07, 0.20, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25


def light(name, kind, loc, rot, color, energy, size=0.3):
    ld = bpy.data.lights.new(name, kind)
    ld.color = color
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    o = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


def dusk_lights(scale=1.0):
    """Éclairage du jeu : soleil couchant orangé, ciel bleu-violet, contre-jour froid."""
    light("key", "AREA", (0.35 * scale, -0.45 * scale, 0.45 * scale), (55, 0, 35), (1.0, 0.62, 0.38), 28 * scale * scale, 0.35 * scale)
    light("fill", "AREA", (-0.2 * scale, 0.5 * scale, 0.25 * scale), (65, 0, 200), (0.45, 0.5, 1.0), 9 * scale * scale, 0.5 * scale)
    light("rim", "AREA", (-0.45 * scale, -0.1 * scale, 0.35 * scale), (60, 0, -100), (0.75, 0.6, 1.0), 26 * scale * scale, 0.25 * scale)


def camera(loc, target, lens=70):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    o = bpy.data.objects.new("cam", cd)
    bpy.context.collection.objects.link(o)
    o.location = loc
    d = Vector(target) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = o
    return o


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def profile(name, pts, width, mat=None, bevel=0.0, segments=3, y=0.0):
    """Silhouette 2D (liste de (x, z)) extrudée sur l'épaisseur `width` (axe Y), puis arrondie."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -width / 2 + y, z)) for (x, z) in pts]
    f = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, width, 0), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return _finish(o, mat, bevel, segments)


def smooth_pts(pts, n=6):
    """Arrondit une polyligne fermée (Chaikin) : silhouettes plus organiques."""
    for _ in range(n // 3 or 1):
        out = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        pts = out
    return pts
