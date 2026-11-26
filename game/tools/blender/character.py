"""Personnage joueur — voyageur encapuchonné (inspiré d'un croquis fourni par l'utilisateur) :
capuche et tunique sable, sangles et brassards en cuir fauve, pantalon bouffant brun, bottes et
gants en cuir sombre, visage dans l'ombre avec des yeux turquoise lumineux en fentes.
Construit en pièces rigides attachées à un squelette (os), avec 4 animations :
Idle, Walking_A, Running_A, Jump_Idle (mêmes noms que l'ancien modèle KayKit).
Blender : Z = haut, le personnage regarde vers -Y (→ +Z dans Godot, comme KayKit).
Usage : python3 character.py <dossier_aperçus|-> [export.glb]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion
from common import *

reset()

# ------------------------------------------------------------------ matériaux (procéduraux, cuits à l'export)
def _nodes(m):
    m.use_nodes = True
    nt = m.node_tree
    return nt, nt.nodes["Principled BSDF"]


def mat_cloth(name, base, dark, rough=0.85, scale=60.0):
    """Tissu : variations de teinte + fin tissage en relief."""
    m = bpy.data.materials.new(name)
    nt, b = _nodes(m)
    b.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 6.0
    noise.inputs["Detail"].default_value = 4.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*base, 1)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.7
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    weave = nt.nodes.new("ShaderNodeTexWave")
    weave.inputs["Scale"].default_value = scale
    weave.inputs["Distortion"].default_value = 1.5
    weave2 = nt.nodes.new("ShaderNodeTexWave")
    weave2.inputs["Scale"].default_value = scale
    weave2.bands_direction = "Y"
    mix = nt.nodes.new("ShaderNodeMath")
    mix.operation = "MULTIPLY"
    nt.links.new(tc.outputs["Object"], weave.inputs["Vector"])
    nt.links.new(tc.outputs["Object"], weave2.inputs["Vector"])
    nt.links.new(weave.outputs["Fac"], mix.inputs[0])
    nt.links.new(weave2.outputs["Fac"], mix.inputs[1])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.002
    nt.links.new(mix.outputs["Value"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_leather(name, base, dark, rough=0.55):
    """Cuir : grain (cellules de Voronoï en relief), plis doux, patine plus sombre par endroits."""
    m = bpy.data.materials.new(name)
    nt, b = _nodes(m)
    b.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9.0
    noise.inputs["Detail"].default_value = 6.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*base, 1)
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.65
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 260.0
    vor.feature = "DISTANCE_TO_EDGE"
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    wr = nt.nodes.new("ShaderNodeTexNoise")
    wr.inputs["Scale"].default_value = 22.0
    wr.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], wr.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(vor.outputs["Distance"], add.inputs[0])
    nt.links.new(wr.outputs["Fac"], add.inputs[1])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.003
    nt.links.new(add.outputs["Value"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


SAND = mat_cloth("cloth_sand", (0.55, 0.43, 0.28), (0.40, 0.30, 0.19))
SAND_DARK = mat_cloth("cloth_sand_dark", (0.40, 0.31, 0.2), (0.28, 0.21, 0.13))
PANTS = mat_cloth("cloth_brown", (0.13, 0.085, 0.055), (0.08, 0.05, 0.03))
LEATHER = mat_leather("leather", (0.50, 0.29, 0.13), (0.30, 0.16, 0.07))
LEATHER_DARK = mat_leather("leather_dark", (0.20, 0.11, 0.06), (0.10, 0.055, 0.03))
BRASS = mat_metal("brass", (0.8, 0.52, 0.24), 1.0, 0.3)
FACE = mat_metal("face", (0.005, 0.006, 0.01), 0.0, 0.95)
EYES = mat_glow("eyes", (0.15, 0.95, 0.85), 4.0)
PROCEDURAL = ("cloth_sand", "cloth_sand_dark", "cloth_brown", "leather", "leather_dark")

# ------------------------------------------------------------------ squelette
J = {
    "hips": ((0, 0, 0.9), (0, 0, 1.02)),
    "spine": ((0, 0, 1.02), (0, 0, 1.2)),
    "chest": ((0, 0, 1.2), (0, 0, 1.36)),
    "neck": ((0, 0, 1.36), (0, 0, 1.43)),
    "head": ((0, 0, 1.43), (0, 0, 1.72)),
}
for s, sx in (("L", 1), ("R", -1)):
    J["upper_arm." + s] = ((0.19 * sx, 0, 1.33), (0.25 * sx, 0.01, 1.08))
    J["forearm." + s] = ((0.25 * sx, 0.01, 1.08), (0.29 * sx, -0.02, 0.86))
    J["hand." + s] = ((0.29 * sx, -0.02, 0.86), (0.3 * sx, -0.03, 0.76))
    J["thigh." + s] = ((0.1 * sx, 0, 0.88), (0.1 * sx, -0.01, 0.48))
    J["shin." + s] = ((0.1 * sx, -0.01, 0.48), (0.1 * sx, 0.01, 0.1))
    J["foot." + s] = ((0.1 * sx, 0.01, 0.1), (0.1 * sx, -0.14, 0.04))
PARENT = {"spine": "hips", "chest": "spine", "neck": "chest", "head": "neck"}
for s in ("L", "R"):
    PARENT.update({"upper_arm." + s: "chest", "forearm." + s: "upper_arm." + s, "hand." + s: "forearm." + s,
                   "thigh." + s: "hips", "shin." + s: "thigh." + s, "foot." + s: "shin." + s})

parts = []   # (objet, os)


def part(o, bone):
    parts.append((o, bone))
    return o


def limb(name, a, b, prof, mat, bone, segs=20, sy=1.0, bevel=0.0):
    """Pièce de révolution le long du segment a→b ; prof = [(t de 0 à 1, rayon)] ; sy aplatit (profondeur)."""
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    o = lathe(name, [(t * L, r) for (t, r) in prof], mat, segs, axis="Z", bevel=bevel)
    o.scale = (1, sy, 1)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    o.matrix_world = Matrix.Translation(a) @ q.to_matrix().to_4x4()
    return part(o, bone)


def solid(o, bone):
    return part(o, bone)


# ------------------------------------------------------------------ jambes : pantalon bouffant, bottes
for s, sx in (("L", 1), ("R", -1)):
    x = 0.1 * sx
    limb("thigh_" + s, (x, 0, 0.92), (x, -0.01, 0.47), [(0, 0.0), (0, 0.115), (0.4, 0.125), (0.8, 0.11), (1.0, 0.095), (1.0, 0.0)], PANTS, "thigh." + s, sy=0.95)
    limb("shin_" + s, (x, -0.01, 0.5), (x, 0.01, 0.2), [(0, 0.0), (0, 0.095), (0.45, 0.112), (0.85, 0.09), (1.0, 0.07), (1.0, 0.0)], PANTS, "shin." + s)
    # bottes : tige, revers, pied, semelle, sangle à boucle
    limb("boot_shaft_" + s, (x, 0.005, 0.27), (x, 0.01, 0.06), [(0, 0.0), (0, 0.083), (0.15, 0.078), (1.0, 0.072), (1.0, 0.0)], LEATHER_DARK, "shin." + s, bevel=0.004)
    limb("boot_cuff_" + s, (x, 0.005, 0.3), (x, 0.005, 0.25), [(0, 0.0), (0, 0.092), (1.0, 0.09), (1.0, 0.0)], LEATHER, "shin." + s, bevel=0.004)
    foot = profile("boot_foot_" + s, smooth_pts([(0.07, 0.0), (0.07, 0.1), (0.0, 0.11), (-0.1, 0.08), (-0.17, 0.05), (-0.18, 0.0)], 3), 0.12, LEATHER_DARK, 0.02, 3)
    foot.rotation_euler = (0, 0, math.radians(90))
    foot.location = (x, 0.0, 0.0)
    solid(foot, "foot." + s)
    sole = profile("boot_sole_" + s, smooth_pts([(0.075, 0.0), (0.075, 0.025), (-0.185, 0.025), (-0.185, 0.0)], 3), 0.13, mat_metal("sole", (0.05, 0.035, 0.025), 0.0, 0.8), 0.006, 2)
    sole.rotation_euler = (0, 0, math.radians(90))
    sole.location = (x, 0.0, 0.0)
    solid(sole, "foot." + s)
    limb("boot_strap_" + s, (x, 0.005, 0.17), (x, 0.005, 0.15), [(0, 0.0), (0, 0.077), (1.0, 0.077), (1.0, 0.0)], LEATHER, "shin." + s)
    solid(box("buckle_" + s, (0.03, 0.01, 0.028), (x + 0.0 * sx, -0.077, 0.16), BRASS, 0.003, 2), "shin." + s)

# ------------------------------------------------------------------ bassin, ceinture, sangles pendantes
pelvis = lathe("pelvis", [(0.84, 0.0), (0.84, 0.15), (0.92, 0.175), (1.04, 0.165), (1.04, 0.0)], PANTS, 24, axis="Z")
pelvis.scale = (1, 0.78, 1)
solid(pelvis, "hips")
belt = lathe("belt", [(0.97, 0.0), (0.97, 0.178), (1.03, 0.178), (1.03, 0.0)], LEATHER, 28, axis="Z", bevel=0.004)
belt.scale = (1, 0.8, 1)
solid(belt, "hips")
solid(box("belt_buckle", (0.06, 0.012, 0.05), (0.0, -0.145, 1.0), BRASS, 0.004, 2), "hips")
for sx in (1, -1):
    solid(box("strap_hang", (0.03, 0.008, 0.2), (0.07 * sx, -0.14, 0.88), LEATHER, 0.003, 2, rot=(-8, 0, 0)), "hips")
    solid(box("strap_loop", (0.04, 0.012, 0.02), (0.07 * sx, -0.143, 0.81), BRASS, 0.003, 2), "hips")
# pan de tunique noué sur la hanche gauche (rappel de l'écharpe du croquis)
solid(box("sash_tail", (0.05, 0.01, 0.22), (0.17, -0.06, 0.88), SAND_DARK, 0.004, 2, rot=(0, -12, -20)), "hips")

# ------------------------------------------------------------------ torse : tunique croisée, sangles de cuir
torso = lathe("torso", [(1.0, 0.0), (1.0, 0.15), (1.12, 0.155), (1.26, 0.172), (1.34, 0.16), (1.4, 0.1), (1.4, 0.0)], SAND, 28, axis="Z")
torso.scale = (1, 0.74, 1)
solid(torso, "chest")
# rabat croisé de la tunique (revers en biais)
solid(box("lapel", (0.03, 0.01, 0.24), (0.03, -0.124, 1.22), SAND_DARK, 0.004, 2, rot=(0, 30, 0)), "chest")
for sgn in (1, -1):
    st = box("cross_strap", (0.042, 0.012, 0.36), (0.0, -0.132, 1.17), LEATHER, 0.004, 2, rot=(0, 36 * sgn, 0))
    solid(st, "chest")
solid(box("strap_ring", (0.035, 0.014, 0.035), (0.0, -0.14, 1.17), BRASS, 0.004, 2, rot=(0, 45, 0)), "chest")
# manches (épaules) et col-écharpe
solid(lathe("cowl", [(1.4, 0.0), (1.4, 0.12), (1.47, 0.105), (1.47, 0.0)], SAND_DARK, 28, axis="Z"), "chest")

# ------------------------------------------------------------------ tête : capuche, visage dans l'ombre, yeux lumineux
# visage : sphère noire très en retrait (le fond de la capuche reste dans l'ombre)
head = sphere("head", 0.125, (0, 0.02, 1.55), FACE, scale=(1, 0.95, 1.05), segs=32)
solid(head, "head")
# capuche : coque ouverte devant, ample, avec une longue pointe qui retombe en arrière
hood = sphere("hood", 0.2, (0, 0.03, 1.57), SAND, scale=(0.96, 1.12, 1.08), segs=40)
cut(hood, sphere("hood_hole", 0.17, (0, -0.17, 1.53), None, scale=(0.78, 0.9, 1.05), segs=32))
md = hood.modifiers.new("solid", "SOLIDIFY")
md.thickness = 0.014
solid(hood, "head")
# bord épais de l'ouverture
bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.02, major_segments=40, minor_segments=10,
                                 location=(0, -0.118, 1.535), rotation=(math.radians(78), 0, 0))
rim = bpy.context.object
rim.name = "hood_rim"
rim.scale = (0.82, 1.22, 1.0)
rim.data.materials.append(SAND_DARK)
for pg in rim.data.polygons:
    pg.use_smooth = True
solid(rim, "head")
# pointe : cône courbé en deux segments
tip = lathe("hood_tip", [(0.0, 0.0), (0.0, 0.15), (0.1, 0.12), (0.2, 0.075), (0.28, 0.03), (0.32, 0.0)], SAND, 28, axis="Z")
tip.scale = (0.75, 1.0, 1.0)
tip.rotation_euler = (math.radians(-75), 0, 0)
tip.location = (0, 0.07, 1.64)
solid(tip, "head")
# pèlerine : la capuche retombe sur les épaules
capelet = lathe("capelet", [(1.27, 0.0), (1.27, 0.215), (1.31, 0.205), (1.38, 0.17), (1.45, 0.12), (1.45, 0.0)], SAND, 32, axis="Z")
capelet.scale = (1.0, 0.85, 1.0)
solid(capelet, "chest")
# yeux : trois fentes verticales en losange + un trait horizontal
for i, x in enumerate((-0.045, 0.0, 0.045)):
    h = 0.085 if i == 1 else 0.07
    e = profile("eye%d" % i, [(x, 1.555 + h / 2), (x + 0.01, 1.555), (x, 1.555 - h * 0.75), (x - 0.01, 1.555)], 0.006, EYES, 0, 1, y=-0.128)
    solid(e, "head")
solid(box("eye_line", (0.12, 0.006, 0.006), (0, -0.129, 1.56), EYES, 0, 1), "head")

# ------------------------------------------------------------------ bras : manches, brassards de cuir, gants
for s, sx in (("L", 1), ("R", -1)):
    sh, el, wr, hd = J["upper_arm." + s][0], J["forearm." + s][0], J["hand." + s][0], J["hand." + s][1]
    solid(sphere("shoulder_" + s, 0.07, (0.19 * sx, 0.0, 1.31), SAND, segs=24), "upper_arm." + s)
    limb("upper_" + s, sh, el, [(0, 0.0), (0, 0.066), (0.5, 0.062), (1.0, 0.056), (1.0, 0.0)], SAND, "upper_arm." + s)
    limb("sleeve_band_" + s, Vector(sh).lerp(Vector(el), 0.45), Vector(sh).lerp(Vector(el), 0.6), [(0, 0.0), (0, 0.067), (1, 0.066), (1, 0.0)], SAND_DARK, "upper_arm." + s)
    limb("fore_" + s, el, wr, [(0, 0.0), (0, 0.062), (1.0, 0.052), (1.0, 0.0)], SAND, "forearm." + s)
    limb("bracer_" + s, Vector(el).lerp(Vector(wr), 0.3), Vector(el).lerp(Vector(wr), 0.98), [(0, 0.0), (0, 0.07), (0.1, 0.073), (0.9, 0.064), (1.0, 0.061), (1.0, 0.0)], LEATHER, "forearm." + s, bevel=0.003)
    for t in (0.45, 0.8):
        limb("bracer_strap_" + s, Vector(el).lerp(Vector(wr), t), Vector(el).lerp(Vector(wr), t + 0.06), [(0, 0.0), (0, 0.075), (1, 0.074), (1, 0.0)], LEATHER_DARK, "forearm." + s)
    # gant : paume, doigts repliés, pouce, manchette
    limb("glove_cuff_" + s, Vector(wr) + Vector((0, 0, 0.03)), Vector(wr) - Vector((0, 0, 0.02)), [(0, 0.0), (0, 0.058), (1, 0.055), (1, 0.0)], LEATHER_DARK, "hand." + s, bevel=0.003)
    hc = Vector(hd).lerp(Vector(wr), 0.45)
    solid(box("palm_" + s, (0.07, 0.085, 0.085), tuple(hc), LEATHER_DARK, 0.02, 3), "hand." + s)
    solid(box("fingers_" + s, (0.065, 0.06, 0.05), tuple(hc + Vector((0.005 * sx, -0.025, -0.06))), LEATHER_DARK, 0.02, 3), "hand." + s)
    solid(box("thumb_" + s, (0.025, 0.05, 0.025), tuple(hc + Vector((-0.04 * sx, -0.03, -0.005))), LEATHER_DARK, 0.01, 2, rot=(20, 0, 0)), "hand." + s)

# ------------------------------------------------------------------ assemblage : une seule maille, un os par pièce
arm_data = bpy.data.armatures.new("rig")
rig = bpy.data.objects.new("rig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for n, (h, t) in J.items():
    b = arm_data.edit_bones.new(n)
    b.head, b.tail = h, t
    b.roll = 0.0
    eb[n] = b
for n, p in PARENT.items():
    eb[n].parent = eb[p]
    eb[n].use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

for o, bone in parts:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and o.hide_render:
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
for o, _ in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0][0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "body"
body.parent = rig
mdf = body.modifiers.new("rig", "ARMATURE")
mdf.object = rig

# ------------------------------------------------------------------ animations (rotations d'os, en degrés)
FPS = 24
bpy.context.scene.render.fps = FPS
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"


def anim(name, length, keys):
    """keys : {frame: {os: (rx, ry, rz) ou ("loc", (x, y, z))}} — boucle : la dernière clé = la première."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for f, poses in keys.items():
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        for bn, v in poses.items():
            pb = rig.pose.bones[bn]
            if v[0] == "loc":
                pb.location = v[1]
            else:
                pb.rotation_euler = [math.radians(a) for a in v]
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_euler", frame=f)
            pb.keyframe_insert("location", frame=f)
    act.frame_range = (0, length)
    return act


def cycle(swing, knee, arm, elbow, bob, lean, length):
    """Cycle de marche / course : jambes opposées aux bras ; 4 temps."""
    k = {}
    for i, f in enumerate((0, length // 4, length // 2, 3 * length // 4, length)):
        ph = [1, 0, -1, 0, 1][i]          # +1 : jambe gauche en avant
        up = [0, 1, 0, 1, 0][i]           # temps de passage : corps plus haut
        p = {
            "hips": ("loc", (0, bob * up, 0)),
            "spine": (lean, 0, 6 * ph),
            "thigh.L": (swing * ph, 0, 0), "thigh.R": (-swing * ph, 0, 0),
            # genou plié quand la jambe est derrière ou repasse sous le corps
            "shin.L": (-knee * (1.0 if (ph < 0 or up) else 0.15), 0, 0),
            "shin.R": (-knee * (1.0 if (ph > 0 or up) else 0.15), 0, 0),
            "upper_arm.L": (-arm * ph, 0, 0), "upper_arm.R": (arm * ph, 0, 0),
            "forearm.L": (elbow, 0, 0), "forearm.R": (elbow, 0, 0),
        }
        k[f] = p
    return k


anim("Idle", 48, {
    0: {"chest": (0, 0, 0), "upper_arm.L": (0, 0, 4), "upper_arm.R": (0, 0, -4), "head": (0, 0, 0)},
    24: {"chest": (3, 0, 0), "upper_arm.L": (2, 0, 6), "upper_arm.R": (2, 0, -6), "head": (-2, 0, 3), "hips": ("loc", (0, -0.006, 0))},
    48: {"chest": (0, 0, 0), "upper_arm.L": (0, 0, 4), "upper_arm.R": (0, 0, -4), "head": (0, 0, 0)},
})
anim("Walking_A", 32, cycle(28, 40, 22, 18, 0.025, 4, 32))
anim("Running_A", 20, cycle(48, 85, 45, 70, 0.05, 14, 20))
anim("Jump_Idle", 24, {
    0: {"thigh.L": (45, 0, 0), "thigh.R": (25, 0, 0), "shin.L": (-70, 0, 0), "shin.R": (-50, 0, 0),
        "upper_arm.L": (-30, 0, 25), "upper_arm.R": (-30, 0, -25), "forearm.L": (40, 0, 0), "forearm.R": (40, 0, 0), "spine": (8, 0, 0)},
    12: {"thigh.L": (40, 0, 0), "thigh.R": (30, 0, 0), "shin.L": (-65, 0, 0), "shin.R": (-55, 0, 0),
         "upper_arm.L": (-35, 0, 28), "upper_arm.R": (-35, 0, -28), "forearm.L": (45, 0, 0), "forearm.R": (45, 0, 0), "spine": (6, 0, 0)},
    24: {"thigh.L": (45, 0, 0), "thigh.R": (25, 0, 0), "shin.L": (-70, 0, 0), "shin.R": (-50, 0, 0),
         "upper_arm.L": (-30, 0, 25), "upper_arm.R": (-30, 0, -25), "forearm.L": (40, 0, 0), "forearm.R": (40, 0, 0), "spine": (8, 0, 0)},
})

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
if out != "-":
    preview_setup((900, 1200))
    # soleils (indépendants de la distance) : couchant orangé, ciel bleuté, contre-jour lavande
    light("key", "SUN", (0, 0, 0), (55, 0, 40), (1.0, 0.7, 0.45), 2.6)
    light("fill", "SUN", (0, 0, 0), (60, 0, 210), (0.5, 0.55, 1.0), 0.7)
    light("rim", "SUN", (0, 0, 0), (70, 0, 150), (0.8, 0.6, 1.0), 1.6)
    rig.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_set(0)
    for n, loc in (("char_front", (0.9, -3.2, 1.3)), ("char_34", (2.4, -2.4, 1.4)), ("char_back", (-1.6, 2.8, 1.5))):
        camera(loc, (0, 0, 0.92), 50)
        render(os.path.join(out, n + ".png"))
    # planche d'animation : 4 poses de marche et 2 de course, de profil
    camera((3.4, -0.4, 1.0), (0, 0, 0.85), 50)
    for an, frames in (("Walking_A", (0, 8)), ("Running_A", (5,)), ("Jump_Idle", (0,))):
        rig.animation_data.action = bpy.data.actions[an]
        for f in frames:
            bpy.context.scene.frame_set(f)
            render(os.path.join(out, "char_%s_%02d.png" % (an, f)))
