extends RefCounted
## Utilitaires : matériaux partagés et création rapide de formes.

static var _cache := {}


static func col(c: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var k := "%s_%.2f_%.2f" % [c.to_html(), rough, emit]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_cache[k] = m
	return m


static func box(parent: Node3D, size: Vector3, mat: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, radius: float, mat: Material, pos := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = maxi(segs / 2, 3)
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, top: float, bottom: float, height: float, mat: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segs
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Textures des modèles .glb (Meshy) rebranchées depuis les fichiers du projet : les images
## extraites du .glb (<nom>_Image_0.jpg, <nom>_emission.jpg...) sont chargées explicitement.
## Si la texture d'émission manque, l'émission est coupée : sinon Godot la remplace par du blanc
## (x2 à x3) et le modèle entier devient blanc (constaté sur Mac).
static var _fixed := {}
static func fix_glb_textures(root: Node, glb_path: String) -> void:
	var dir := glb_path.get_base_dir()
	var base := glb_path.get_file().get_basename()
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if f.begins_with(base + "_") and (f.ends_with(".jpg") or f.ends_with(".png")) and not files.has(f):
			# « rifle_god_… » n'appartient pas à « rifle »
			if base.find("_god") < 0 and f.begins_with(base + "_god"):
				continue
			files.append(f)
	var albedo := ""
	var emission := ""
	for f in files:
		if f.find("emission") >= 0:
			emission = dir + "/" + f
		elif f.find("Image_0") >= 0 and albedo == "":
			albedo = dir + "/" + f
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or _fixed.has(m):
				continue
			_fixed[m] = true
			if (m.albedo_texture == null or not ResourceLoader.exists(m.albedo_texture.resource_path)) and albedo != "" and ResourceLoader.exists(albedo):
				m.albedo_texture = load(albedo)
			if m.emission_enabled:
				if emission != "" and ResourceLoader.exists(emission):
					m.emission_texture = load(emission)
					m.emission = Color.BLACK
					m.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
					m.emission_energy_multiplier = minf(m.emission_energy_multiplier, 3.0)
				else:
					m.emission_enabled = false
