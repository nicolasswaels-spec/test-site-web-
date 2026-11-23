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
