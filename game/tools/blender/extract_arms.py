"""Découpe les bras (manche, brassard, gant) du personnage Meshy pour la vue à la 1re personne.
Chaque bras est réorienté : poignet à l'origine, épaule sur +Z (Blender) ; export en GLB.
Usage : python3 extract_arms.py <rig.glb Meshy> <dossier de sortie>"""
import sys, os
import bpy, bmesh
from mathutils import Vector, Matrix

src, outdir = sys.argv[1], sys.argv[2]
for side, pre in (("r", "Right"), ("l", "Left")):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    body = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm][0]
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o)
    mw = arm.matrix_world
    elbow = mw @ arm.data.bones[pre + "Arm"].head_local      # épaule (le bras reste tendu)
    wrist = mw @ arm.data.bones[pre + "Hand"].head_local
    # sommets dont le poids va surtout à l'avant-bras et à la main
    groups = {g.index: g.name for g in body.vertex_groups}
    keep = set()
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if groups[g.group] in (pre + "Arm", pre + "ForeArm", pre + "Hand"))
        if w > 0.5:
            # pas de morceaux de pèlerine : seulement près de l'axe épaule -> poignet (et la main)
            pw = body.matrix_world @ v.co
            seg = elbow - wrist
            t = max(0.0, min(1.0, (pw - wrist).dot(seg) / seg.length_squared))
            if (pw - (wrist + seg * t)).length < 0.085 or (pw - wrist).dot(seg) < 0:
                keep.add(v.index)
    # maillage en pose de repos, coordonnées monde
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    for md in list(body.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    mwb = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = mwb
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    # repère : poignet -> origine, coude -> +Z ; X = direction « dos de la main » approximative
    z = (elbow - wrist).normalized()
    x = Vector((0, 0, 1)).cross(z).normalized() if abs(z.z) < 0.95 else Vector((1, 0, 0))
    y = z.cross(x)
    rot = Matrix((x, y, z))          # lignes = nouveaux axes
    for v in bm.verts:
        v.co = rot @ (v.co - wrist)
    bm.to_mesh(body.data)
    bm.free()
    bpy.data.objects.remove(arm)
    body.name = "fp_arm_" + side
    cs = [v.co for v in body.data.vertices]
    print(side, "sommets", len(cs), "longueur", (elbow - wrist).length,
          "z", min(c.z for c in cs), max(c.z for c in cs), "x", min(c.x for c in cs), max(c.x for c in cs))
    for im in bpy.data.images:
        if im.size[0] > 1024:
            im.scale(1024, 1024)
            im.pack()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(outdir, "fp_arm_%s.glb" % side), export_format="GLB",
                              export_animations=False, export_skins=False, export_image_format="JPEG", export_image_quality=88)
