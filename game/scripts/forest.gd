extends RefCounted
## Génère (une seule fois, puis met en cache) les ressources de la forêt stylisée :
## texture de branche de sapin, sapins, touffes d'herbe, plantes, et leurs shaders.

const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert_wrap;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 col_dark : source_color = vec3(0.04, 0.10, 0.16);
uniform vec3 col_light : source_color = vec3(0.10, 0.30, 0.32);
uniform vec3 col_warm : source_color = vec3(0.30, 0.32, 0.22);
void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 0.9 + origin.x * 0.21 + origin.z * 0.17 + VERTEX.y * 0.15);
	float amount = (1.0 - UV.y) * 0.18 * clamp(VERTEX.y * 0.08, 0.0, 1.0);
	VERTEX.x += s * amount;
	VERTEX.z += s * amount * 0.6;
}
void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) { discard; }
	float h = COLOR.r;
	vec3 c = mix(col_dark, col_light, clamp(h * 0.7 + (1.0 - UV.y) * 0.35, 0.0, 1.0));
	c = mix(c, col_warm, COLOR.g * 0.25 * h);
	ALBEDO = c * (0.75 + 0.25 * t.r);
	BACKLIGHT = c * 0.6;
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert_wrap;
uniform vec3 base_col : source_color = vec3(0.02, 0.07, 0.08);
uniform vec3 tip_col : source_color = vec3(0.12, 0.42, 0.36);
uniform vec3 tip_col2 : source_color = vec3(0.22, 0.48, 0.30);
uniform float sway = 0.18;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = COLOR.r;
	float w = sin(TIME * 1.5 + wp.x * 0.35 + wp.z * 0.22) * 0.6 + sin(TIME * 2.8 + wp.x * 1.1 + wp.z * 0.7) * 0.25;
	VERTEX.x += w * h * h * sway;
	VERTEX.z += w * h * h * sway * 0.5;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	vec3 tip = mix(tip_col, tip_col2, COLOR.g);
	vec3 c = mix(base_col, tip, pow(COLOR.r, 1.2));
	ALBEDO = c;
	BACKLIGHT = c * 0.5;
}
"""

static var _branch_tex: ImageTexture
static var _foliage_mat: ShaderMaterial
static var _trunk_mat: StandardMaterial3D
static var _grass_shader: Shader
static var _pines: Array[ArrayMesh] = []
static var _dead_tree: ArrayMesh
static var _grass: ArrayMesh
static var _plant: ArrayMesh
static var _bush: ArrayMesh


# ------------------------------------------------------------------ matériaux

static func trunk_material() -> StandardMaterial3D:
	if _trunk_mat == null:
		_trunk_mat = StandardMaterial3D.new()
		_trunk_mat.albedo_color = Color(0.11, 0.09, 0.14)
		_trunk_mat.roughness = 1.0
		_trunk_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return _trunk_mat


static func foliage_material() -> ShaderMaterial:
	if _foliage_mat == null:
		var sh := Shader.new()
		sh.code = FOLIAGE_SHADER
		_foliage_mat = ShaderMaterial.new()
		_foliage_mat.shader = sh
		_foliage_mat.set_shader_parameter("tex", branch_texture())
	return _foliage_mat


static func grass_material(base: Color, tip: Color, tip2: Color, sway := 0.18) -> ShaderMaterial:
	if _grass_shader == null:
		_grass_shader = Shader.new()
		_grass_shader.code = GRASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = _grass_shader
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("tip_col", tip)
	m.set_shader_parameter("tip_col2", tip2)
	m.set_shader_parameter("sway", sway)
	return m


# ------------------------------------------------------------------ texture de branche

static func branch_texture() -> ImageTexture:
	if _branch_tex:
		return _branch_tex
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cx := w * 0.5
	# tige centrale : v=1 (bas de l'image) contre le tronc, v=0 (haut) à la pointe
	_line(img, Vector2(cx, h - 1), Vector2(cx, 6), 3.0, 0.55)
	# aiguilles (petites branches dentelées) de chaque côté
	var y := float(h - 4)
	while y > 10.0:
		var v := y / h
		for side in [-1.0, 1.0]:
			var length := lerpf(10.0, 60.0, v) * rng.randf_range(0.7, 1.05)
			var ang := deg_to_rad(rng.randf_range(28.0, 48.0))
			var start := Vector2(cx + side * 1.5, y)
			var end := start + Vector2(side * sin(ang + 0.35) * length, -cos(ang + 0.35) * length * 0.75)
			_line(img, start, end, 2.0, rng.randf_range(0.7, 1.0))
			# sous-aiguilles pour un bord bien découpé
			var n := int(length / 7.0)
			for k in range(1, n):
				var p := start.lerp(end, float(k) / n)
				var l2 := length * 0.22 * (1.0 - float(k) / n * 0.5)
				_line(img, p, p + Vector2(side * l2 * 0.5, -l2), 1.4, rng.randf_range(0.8, 1.0))
		y -= rng.randf_range(4.0, 6.5)
	img.generate_mipmaps()
	_branch_tex = ImageTexture.create_from_image(img)
	return _branch_tex


static func _line(img: Image, a: Vector2, b: Vector2, thick: float, shade: float) -> void:
	var steps := int(maxf(a.distance_to(b), 1.0) * 1.5)
	var r := int(ceil(thick * 0.5))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var t := thick * (1.0 - 0.5 * float(i) / steps)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if Vector2(dx, dy).length() <= t * 0.5 + 0.3:
					var x := int(p.x) + dx
					var y := int(p.y) + dy
					if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
						img.set_pixel(x, y, Color(shade, shade, shade, 1.0))


# ------------------------------------------------------------------ sapins

static func pine_variants() -> Array[ArrayMesh]:
	if _pines.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 4:
			_pines.append(_build_pine(rng, rng.randf_range(11.0, 17.0)))
	return _pines


static func _build_pine(rng: RandomNumberGenerator, height: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.42
	cyl.height = height
	cyl.radial_segments = 7
	cyl.rings = 1
	st.append_from(cyl, 0, Transform3D(Basis(), Vector3(0, height * 0.5, 0)))
	st.commit(mesh)
	mesh.surface_set_material(0, trunk_material())

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := height * rng.randf_range(0.3, 0.42)
	var layers := int(height * 0.85)
	for i in layers:
		var t := float(i) / float(layers - 1)
		var y := lerpf(start, height - 0.6, t) + rng.randf_range(-0.2, 0.2)
		var length := lerpf(4.2, 0.9, pow(t, 0.9)) * rng.randf_range(0.8, 1.15)
		var count := 5 if t < 0.6 else 4
		var off := rng.randf() * TAU
		for k in count:
			var a := off + TAU * k / count + rng.randf_range(-0.35, 0.35)
			var out := Vector3(cos(a), 0.0, sin(a))
			var droop := lerpf(0.55, 0.15, t) * rng.randf_range(0.7, 1.3)
			_branch(st, Vector3(0, y, 0), out, length, length * 0.6, droop, t, rng.randf())
	# cime
	_card(st, Vector3(0, height - 1.2, 0), Vector3.UP, Vector3.RIGHT, 1.8, 0.9, 1.0, 0.5)
	_card(st, Vector3(0, height - 1.2, 0), Vector3.UP, Vector3.BACK, 1.8, 0.9, 1.0, 0.5)
	st.commit(mesh)
	mesh.surface_set_material(1, foliage_material())
	return mesh


static func _branch(st: SurfaceTool, base: Vector3, out: Vector3, length: float, width: float, droop: float, t: float, g: float) -> void:
	var side := Vector3(-out.z, 0.0, out.x)
	var d1 := (out + Vector3.DOWN * droop * 0.4).normalized()
	var d2 := (out + Vector3.DOWN * droop * 1.5).normalized()
	var nrm := (out * 0.7 + Vector3.UP).normalized()
	_strip(st, base, d1, d2, side, length, width, t, g, nrm)
	var vside := d1.cross(side).normalized()
	_strip(st, base, d1, d2, vside, length, width * 0.6, t, g, nrm)


static func _strip(st: SurfaceTool, base: Vector3, d1: Vector3, d2: Vector3, side: Vector3, length: float, width: float, t: float, g: float, nrm: Vector3) -> void:
	var hw := width * 0.5
	var mid := base + d1 * length * 0.5
	var tip := mid + d2 * length * 0.5
	var rows := [[base, 1.0], [mid, 0.5], [tip, 0.0]]
	for r in 2:
		var p0: Vector3 = rows[r][0]
		var p1: Vector3 = rows[r + 1][0]
		var v0: float = rows[r][1]
		var v1: float = rows[r + 1][1]
		var a := p0 - side * hw
		var b := p0 + side * hw
		var c := p1 + side * hw
		var d := p1 - side * hw
		_v(st, a, Vector2(0, v0), t, g, nrm)
		_v(st, b, Vector2(1, v0), t, g, nrm)
		_v(st, c, Vector2(1, v1), t, g, nrm)
		_v(st, a, Vector2(0, v0), t, g, nrm)
		_v(st, c, Vector2(1, v1), t, g, nrm)
		_v(st, d, Vector2(0, v1), t, g, nrm)


static func _card(st: SurfaceTool, base: Vector3, out: Vector3, side: Vector3, length: float, width: float, t: float, g: float) -> void:
	_strip(st, base, out, out, side, length, width, t, g, Vector3.UP)


static func _v(st: SurfaceTool, p: Vector3, uv: Vector2, t: float, g: float, nrm: Vector3) -> void:
	st.set_normal(nrm)
	st.set_color(Color(t, g, 0.0))
	st.set_uv(uv)
	st.add_vertex(p)


# ------------------------------------------------------------------ arbre mort (bleu pâle)

static func dead_tree() -> ArrayMesh:
	if _dead_tree:
		return _dead_tree
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_twig(st, rng, Vector3.ZERO, Vector3.UP, 9.0, 0.22, 3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.8, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 0.85)
	mat.emission_energy_multiplier = 0.4
	st.set_material(mat)
	_dead_tree = st.commit()
	return _dead_tree


static func _twig(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, dir: Vector3, length: float, radius: float, depth: int) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.5
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 5
	cyl.rings = 1
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	st.append_from(cyl, 0, Transform3D(Basis(x, y, z), base + y * length * 0.5))
	if depth <= 0:
		return
	var n := 4 if depth == 3 else 3
	for i in n:
		var f := rng.randf_range(0.35, 0.95)
		var p := base + y * length * f
		var a := rng.randf() * TAU
		var nd := (y * 0.9 + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.5, 1.0)).normalized()
		_twig(st, rng, p, nd, length * rng.randf_range(0.3, 0.5), radius * 0.45, depth - 1)


# ------------------------------------------------------------------ herbe et plantes

static func grass_clump() -> ArrayMesh:
	if _grass:
		return _grass
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 11:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.4
		var base := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var h := rng.randf_range(0.45, 1.0)
		var w := rng.randf_range(0.05, 0.09)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0.0, sin(face))
		var lean := Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(0.15, 0.45)
		_blade(st, base, side, lean, h, w, rng.randf())
	_grass = st.commit()
	return _grass


static func _blade(st: SurfaceTool, base: Vector3, side: Vector3, lean: Vector3, h: float, w: float, g: float) -> void:
	var segs := 3
	var pts: Array[Vector3] = []
	var widths: Array[float] = []
	for k in segs + 1:
		var f := float(k) / segs
		pts.append(base + Vector3.UP * h * f + lean * h * f * f)
		widths.append(w * (1.0 - f))
	for k in segs:
		var f0 := float(k) / segs
		var f1 := float(k + 1) / segs
		var a := pts[k] - side * widths[k]
		var b := pts[k] + side * widths[k]
		var c := pts[k + 1] + side * widths[k + 1]
		var d := pts[k + 1] - side * widths[k + 1]
		for v in [[a, f0], [b, f0], [c, f1], [a, f0], [c, f1], [d, f1]]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(v[1], g, 0.0))
			st.add_vertex(v[0])


static func _leaf(st: SurfaceTool, base: Vector3, dir: Vector3, side: Vector3, length: float, width: float, g: float) -> void:
	var tip := base + dir * length
	var mid := base + dir * length * 0.4
	var l := mid - side * width
	var r := mid + side * width
	var h0 := base.y
	var hn := func(p: Vector3) -> float: return clampf((p.y - h0) / maxf(length, 0.01), 0.0, 1.0)
	for p in [base, r, tip, base, tip, l]:
		st.set_normal(Vector3.UP)
		st.set_color(Color(hn.call(p), g, 0.0))
		st.add_vertex(p)


## Plante haute à feuilles fines (les touffes rouges des images).
static func plant() -> ArrayMesh:
	if _plant:
		return _plant
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in 4:
		var a := rng.randf() * TAU
		var stem_base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.25)
		var stem_h := rng.randf_range(0.8, 1.4)
		var g := rng.randf()
		for i in 9:
			var f := float(i) / 9.0
			var la := rng.randf() * TAU
			var out := Vector3(cos(la), 0, sin(la))
			var base := stem_base + Vector3.UP * stem_h * f
			var dir := (out * (1.0 - f * 0.6) + Vector3.UP * (0.8 + f)).normalized()
			_leaf(st, base, dir, Vector3(-out.z, 0, out.x), lerpf(0.45, 0.2, f), lerpf(0.07, 0.04, f), g)
	_plant = st.commit()
	return _plant


## Buisson à larges feuilles sombres.
static func bush() -> ArrayMesh:
	if _bush:
		return _bush
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 14:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var dir := (out + Vector3.UP * rng.randf_range(0.6, 1.6)).normalized()
		_leaf(st, out * 0.05, dir, Vector3(-out.z, 0, out.x), rng.randf_range(0.6, 1.0), rng.randf_range(0.14, 0.22), rng.randf())
	_bush = st.commit()
	return _bush
