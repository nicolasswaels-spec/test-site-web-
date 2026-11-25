extends RefCounted
## Modèles 3D du pack « Ultimate Stylized Nature » de Quaternius (licence CC0),
## convertis à l'import puis recolorés en code dans la palette crépusculaire du jeu.

const DIR := "res://assets/nature/"

const LEAF_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert_wrap;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint_dark : source_color = vec3(0.02, 0.05, 0.10);
uniform vec3 tint_light : source_color = vec3(0.08, 0.26, 0.28);
uniform float height_ref = 14.0;
uniform float sway = 0.12;
uniform vec3 glow : source_color = vec3(0.0);   // lueur (arbres magiques)
varying float hfac;
void vertex() {
	hfac = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.1 + origin.x * 0.23 + origin.z * 0.19 + VERTEX.y * 0.2);
	VERTEX.x += s * sway * hfac * height_ref * 0.06;
	VERTEX.z += s * sway * hfac * height_ref * 0.035;
}
void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) { discard; }
	float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(tint_dark, tint_light, clamp(lum * 1.1 + hfac * 0.35, 0.0, 1.0));
	EMISSION = glow * (0.4 + lum * 1.2) * (0.75 + 0.25 * sin(TIME * 2.0 + hfac * 6.0));
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert_wrap;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 base_col : source_color = vec3(0.01, 0.03, 0.06);
uniform vec3 tip_col : source_color = vec3(0.08, 0.32, 0.30);
uniform vec3 tip_col2 : source_color = vec3(0.17, 0.38, 0.24);
varying float h;
varying float var_c;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = clamp(VERTEX.y / 0.5, 0.0, 1.0);
	var_c = fract(sin(dot(floor(wp.xz * 0.4), vec2(12.9, 78.2))) * 43758.5);
	float w = sin(TIME * 1.5 + wp.x * 0.35 + wp.z * 0.22) * 0.6 + sin(TIME * 2.8 + wp.x * 1.1 + wp.z * 0.7) * 0.25;
	VERTEX.x += w * h * h * 0.12;
	VERTEX.z += w * h * h * 0.06;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	float lum = dot(texture(tex, UV).rgb, vec3(0.3, 0.59, 0.11));
	float g = clamp(max(h, smoothstep(0.12, 0.5, lum)), 0.0, 1.0);
	ALBEDO = mix(base_col, mix(tip_col, tip_col2, var_c), pow(g, 1.3));
}
"""

static var _cache := {}
static var _leaf_shader: Shader
static var _grass_shader: Shader
static var _tex := {}


static func _texture(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = load(DIR + file)
	return _tex[file]


## Charge un modèle FBX, applique la correction d'axes/échelle de l'import
## et renvoie une ArrayMesh autonome (utilisable dans une MultiMesh).
static func _bake(model: String, target_height := 0.0, scale := 1.0) -> ArrayMesh:
	var ps: PackedScene = load(DIR + model + ".fbx")
	var root := ps.instantiate()
	var mi: MeshInstance3D = null
	for c in root.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	var src: Mesh = mi.mesh
	var s := scale * mi.scale.x
	if target_height > 0.0:
		s = target_height / src.get_aabb().size.y
	var out := ArrayMesh.new()
	for i in src.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(src, i, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO))
		st.commit(out)
	root.free()
	return out


## Certains modèles ont leur tronc décalé de l'origine (jusqu'à ~1 m) : on recentre le
## maillage sur le pied du tronc pour que la collision et la hache tombent pile dessus.
## Le rayon du tronc est mémorisé dans la méta "trunk_radius".
static func _recenter_on_trunk(m: ArrayMesh) -> ArrayMesh:
	var verts: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sum := Vector2.ZERO
	var n := 0
	for v in verts:
		if v.y < 1.0:
			sum += Vector2(v.x, v.z)
			n += 1
	var c := sum / maxf(n, 1)
	var radius := 0.0
	for v in verts:
		if v.y > 0.8 and v.y < 1.6:
			radius = maxf(radius, Vector2(v.x, v.z).distance_to(c))
	var out := ArrayMesh.new()
	for i in m.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(m, i, Transform3D(Basis(), Vector3(-c.x, 0.0, -c.y)))
		st.commit(out)
	out.set_meta("trunk_radius", clampf(radius, 0.2, 0.6))
	return out


static func leaf_material(tex_file: String, dark: Color, light: Color, height_ref: float, sway := 0.12) -> ShaderMaterial:
	if _leaf_shader == null:
		_leaf_shader = Shader.new()
		_leaf_shader.code = LEAF_SHADER
	var m := ShaderMaterial.new()
	m.shader = _leaf_shader
	m.set_shader_parameter("tex", _texture(tex_file))
	m.set_shader_parameter("tint_dark", dark)
	m.set_shader_parameter("tint_light", light)
	m.set_shader_parameter("height_ref", height_ref)
	m.set_shader_parameter("sway", sway)
	return m


static func bark_material() -> StandardMaterial3D:
	if not _cache.has("bark_mat"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _texture("PineTree_Bark.png")
		m.albedo_color = Color(0.22, 0.18, 0.30)
		m.roughness = 1.0
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_cache["bark_mat"] = m
	return _cache["bark_mat"]


# ------------------------------------------------------------------ modèles prêts à l'emploi

static func pines() -> Array[ArrayMesh]:
	if not _cache.has("pines"):
		var arr: Array[ArrayMesh] = []
		var leaves := leaf_material("PineTree_Leaves.png", Color(0.015, 0.04, 0.09), Color(0.07, 0.24, 0.27), 14.0)
		var heights := [13.0, 16.0, 11.0, 14.5, 12.5]
		for i in 5:
			var m := _recenter_on_trunk(_bake("PineTree_%d" % (i + 1), heights[i]))
			m.surface_set_material(0, bark_material())
			m.surface_set_material(1, leaves)
			arr.append(m)
		_cache["pines"] = arr
	return _cache["pines"]


static func _tree_species(key: String, models: Array, heights: Array, bark_tex: String, bark_tint: Color, leaf_tex: String, dark: Color, light: Color) -> Array[ArrayMesh]:
	if not _cache.has(key):
		var arr: Array[ArrayMesh] = []
		var bark := StandardMaterial3D.new()
		bark.albedo_texture = _texture(bark_tex)
		bark.albedo_color = bark_tint
		bark.roughness = 1.0
		bark.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		var href: float = heights.max()
		var leaves := leaf_material(leaf_tex, dark, light, href, 0.08)
		for i in models.size():
			var m := _recenter_on_trunk(_bake(models[i], heights[i]))
			m.surface_set_material(0, bark)
			m.surface_set_material(1, leaves)
			arr.append(m)
		_cache[key] = arr
	return _cache[key]


## Biome 2 : érables pourpres.
static func maples() -> Array[ArrayMesh]:
	return _tree_species("maples", ["MapleTree_1", "MapleTree_2", "MapleTree_3", "MapleTree_5"], [11.0, 10.0, 12.0, 11.5],
		"MapleTree_Bark.png", Color(0.30, 0.20, 0.28), "MapleTree_Leaves.png", Color(0.20, 0.02, 0.07), Color(0.92, 0.22, 0.30))


## Biome 2 : bouleaux dorés.
static func birches() -> Array[ArrayMesh]:
	return _tree_species("birches", ["BirchTree_1", "BirchTree_2"], [10.0, 12.0],
		"BirchTree_Bark.png", Color(0.80, 0.74, 0.86), "BirchTree_Leaves.png", Color(0.30, 0.12, 0.03), Color(1.0, 0.72, 0.25))


## Matériau d'herbe recoloré (pour le biome 2).
static func grass_material(base: Color, tip: Color, tip2: Color) -> ShaderMaterial:
	grass()
	var mat := ShaderMaterial.new()
	mat.shader = _grass_shader
	mat.set_shader_parameter("tex", _texture("Grass.png"))
	mat.set_shader_parameter("base_col", base)
	mat.set_shader_parameter("tip_col", tip)
	mat.set_shader_parameter("tip_col2", tip2)
	return mat


static func grass() -> ArrayMesh:
	if not _cache.has("grass"):
		var m := _bake("Grass_Large", 0.0, 1.5)
		if _grass_shader == null:
			_grass_shader = Shader.new()
			_grass_shader.code = GRASS_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = _grass_shader
		mat.set_shader_parameter("tex", _texture("Grass.png"))
		m.surface_set_material(0, mat)
		_cache["grass"] = m
	return _cache["grass"]


## Plante à longues feuilles, teintée rouge vif.
static func red_plant(variant: int) -> ArrayMesh:
	var k := "plant%d" % variant
	if not _cache.has(k):
		var m := _bake("Plant_%d" % variant, 0.0, 1.0)
		m.surface_set_material(0, leaf_material("Flowers.png", Color(0.16, 0.01, 0.05), Color(0.72, 0.10, 0.18), 0.8, 0.05))
		_cache[k] = m
	return _cache[k]


## Buisson bleu nuit.
static func bush(large: bool) -> ArrayMesh:
	var k := "bush_large" if large else "bush"
	if not _cache.has(k):
		var m := _bake("Bush_Large" if large else "Bush", 0.0, 1.0)
		m.surface_set_material(0, leaf_material("Bush_Leaves.png", Color(0.02, 0.02, 0.09), Color(0.13, 0.15, 0.45), 1.2, 0.04))
		_cache[k] = m
	return _cache[k]


static func rock(variant: int) -> ArrayMesh:
	var k := "rock%d" % variant
	if not _cache.has(k):
		var m := _bake("Rock_%d" % variant, 0.0, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _texture("Rocks_Violet.png")
		mat.albedo_color = Color(0.45, 0.45, 0.62)
		mat.roughness = 0.95
		m.surface_set_material(0, mat)
		_cache[k] = m
	return _cache[k]


## Arbre mort bleu pâle (comme dans les images de référence).
static func dead_tree(variant: int) -> ArrayMesh:
	var k := "dead%d" % variant
	if not _cache.has(k):
		var m := _bake("DeadTree_%d" % variant, 9.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.8, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.65, 0.8)
		mat.emission_energy_multiplier = 0.35
		m.surface_set_material(0, mat)
		_cache[k] = m
	return _cache[k]


## Zone volcanique : sapins calcinés (écorce noire, aiguilles couleur braise).
static func ash_pines() -> Array[ArrayMesh]:
	return _tree_species("ash_pines", ["PineTree_1", "PineTree_2", "PineTree_3", "PineTree_4", "PineTree_5"], [13.0, 16.0, 11.0, 14.5, 12.5],
		"PineTree_Bark.png", Color(0.13, 0.10, 0.10), "PineTree_Leaves.png", Color(0.03, 0.01, 0.01), Color(0.32, 0.10, 0.05))


## Matériaux d'un arbre magique : simple skin différent (écorce pâle argentée, feuillage
## turquoise clair), sans émission ; la lueur vient d'un halo autour (voir glow_halo).
## species : 0 sapin, 1 érable, 2 bouleau, 3 sapin calciné.
static func magic_tree_materials(species: int) -> Array:
	var k := "magic_tree_%d" % species
	if not _cache.has(k):
		var bark := StandardMaterial3D.new()
		bark.albedo_texture = _texture(["PineTree_Bark.png", "MapleTree_Bark.png", "BirchTree_Bark.png", "PineTree_Bark.png"][species])
		bark.albedo_color = Color(0.62, 0.70, 0.78)
		bark.roughness = 1.0
		bark.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		var leaf_tex: String = ["PineTree_Leaves.png", "MapleTree_Leaves.png", "BirchTree_Leaves.png", "PineTree_Leaves.png"][species]
		var leaves := leaf_material(leaf_tex, Color(0.03, 0.10, 0.14), Color(0.30, 0.78, 0.72), 14.0, 0.1)
		_cache[k] = [bark, leaves]
	return _cache[k]


## Halo lumineux diffus (sprite toujours face à la caméra, fondu près des surfaces).
static func glow_halo(parent: Node3D, color: Color, size: float, pos: Vector3) -> MeshInstance3D:
	var k := "halo_" + color.to_html()
	if not _cache.has(k):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = gt
		m.albedo_color = color
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.8
		m.disable_receive_shadows = true
		_cache[k] = m
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = _cache[k]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi


## Rocher volcanique (basalte sombre) ou magique (violet, lumineux).
static func rock_material(kind: String) -> StandardMaterial3D:
	var k := "rockmat_" + kind
	if not _cache.has(k):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _texture("Rocks_Violet.png")
		mat.roughness = 0.95
		match kind:
			"volcanic":
				mat.albedo_color = Color(0.22, 0.17, 0.17)
			"magic":
				mat.albedo_color = Color(0.55, 0.50, 0.85)
		_cache[k] = mat
	return _cache[k]


## Arbre mort calciné (décor de la zone volcanique).
static func burnt_tree(variant: int) -> ArrayMesh:
	var k := "burnt%d" % variant
	if not _cache.has(k):
		var m := _bake("DeadTree_%d" % variant, 9.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.06, 0.06)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.05)
		mat.emission_energy_multiplier = 0.12
		m.surface_set_material(0, mat)
		_cache[k] = m
	return _cache[k]
