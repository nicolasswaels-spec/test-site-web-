extends RefCounted
## Zone volcanique : matériaux (basalte à fissures de lave, volcan à coulées, bois calciné) et
## coulées de lave animées (ruban qui serpente au sol, bordé de bourrelets de roche refroidie).
## Les formes des rochers et du volcan viennent de tools/blender/volcanic_props.py.

const Mats = preload("res://scripts/mats.gd")
const ROCKS := ["rock_block", "rock_spire", "rock_slab", "rock_crag"]

const NOISE := """
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
// distance au bord de cellule de Voronoï (F2 - F1) : réseau de fissures
float cracks3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	float f1 = 8.0; float f2 = 8.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 r = g + hash33(i + g) - f;
		float d = dot(r, r);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return sqrt(f2) - sqrt(f1);
}
"""

## Basalte : sombre, cendres claires sur le dessus, fissures orange qui rougeoient près du sol.
const ROCK_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform float crack_amount = 1.0;
uniform float crack_scale = 0.55;
uniform float ash_amount = 1.0;
uniform float heat_height = 2.5;
uniform float crack_mask = 0.62;   // plus haut = moins de fissures
uniform vec3 base_dark : source_color = vec3(0.045, 0.035, 0.04);
uniform vec3 base_light : source_color = vec3(0.14, 0.115, 0.11);
varying vec3 wp;
varying vec3 wn;
""" + NOISE + """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float n = vnoise(wp * 1.7) * 0.6 + vnoise(wp * 5.0) * 0.4;
	vec3 col = mix(base_dark, base_light, n);
	// cendres sur les faces tournées vers le ciel
	float ash = smoothstep(0.45, 0.85, wn.y + (vnoise(wp * 2.3) - 0.5) * 0.5) * ash_amount;
	col = mix(col, vec3(0.30, 0.28, 0.27), ash * 0.85);
	// fissures de lave
	// fissures irrégulières : position déformée par du bruit, largeur variable, réseau incomplet,
	// plus de fines craquelures secondaires
	vec3 q = wp * crack_scale;
	q += (vec3(vnoise(q * 0.7), vnoise(q * 0.7 + 7.3), vnoise(q * 0.7 + 13.1)) - 0.5) * 1.1;
	float wdt = 0.025 + 0.06 * vnoise(wp * 1.3 + 5.0);
	float c = 1.0 - smoothstep(0.0, wdt, cracks3(q));
	c *= smoothstep(crack_mask - 0.12, crack_mask + 0.12, vnoise(wp * 0.45 + 3.1));
	float c2 = (1.0 - smoothstep(0.0, 0.025, cracks3(q * 2.7 + 4.0))) * smoothstep(0.55, 0.75, vnoise(wp * 0.9 + 1.7));
	c = max(c, c2 * 0.6);
	float heat = clamp(1.0 - wp.y / heat_height, 0.0, 1.0) * (1.0 - ash * 0.8) * crack_amount;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.6 + wp.x * 0.7 + wp.z * 0.4);
	vec3 hot = mix(vec3(1.0, 0.22, 0.03), vec3(1.0, 0.6, 0.15), c);
	col = mix(col, hot * 0.6, c * heat);
	ALBEDO = col;
	EMISSION = hot * c * heat * 2.2 * pulse;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
"""

## Volcan : flancs de basalte et de cendres, cratère en fusion, coulées qui descendent du rebord
## (UV.x = angle autour du sommet, UV.y = distance au centre, 0..1).
const VOLCANO_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap;
varying vec3 wp;
""" + NOISE + """
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float ang = UV.x;
	float r = UV.y;
	float n = vnoise(wp * 0.15) * 0.6 + vnoise(wp * 0.6) * 0.4;
	vec3 col = mix(vec3(0.05, 0.04, 0.045), vec3(0.17, 0.14, 0.13), n);
	// bandes de cendres sur le haut des flancs
	col = mix(col, vec3(0.30, 0.27, 0.26), smoothstep(0.55, 0.8, vnoise(vec3(ang * 40.0, r * 6.0, 0.0))) * smoothstep(0.9, 0.3, r) * 0.6);
	// coulées : quelques rubans qui serpentent du rebord vers le bas
	float wob = (vnoise(vec3(r * 6.0, ang * 3.0, 1.0)) - 0.5) * 0.05;
	float k = fract((ang + wob) * 7.0);
	float rib = 1.0 - smoothstep(0.0, 0.05 + 0.03 * (1.0 - r), abs(k - 0.5));
	rib *= step(0.45, hash3(vec3(floor((ang + wob) * 7.0), 3.0, 1.0)));   // pas sur tous les flancs
	rib *= smoothstep(0.95, 0.5, r + vnoise(vec3(ang * 20.0, 2.0, 0.0)) * 0.3);
	float flow = 0.7 + 0.3 * sin(r * 60.0 - TIME * 1.5 + ang * 30.0);
	float crater = 1.0 - smoothstep(0.09, 0.14, r);
	float lava = max(rib * flow, crater);
	vec3 hot = mix(vec3(1.0, 0.25, 0.03), vec3(1.0, 0.65, 0.2), vnoise(wp * 0.4 + TIME * 0.3));
	ALBEDO = mix(col, hot * 0.5, lava);
	EMISSION = hot * lava * 3.0;
	ROUGHNESS = 0.95;
}
"""

## Lave en mouvement : plaques de croûte noire qui dérivent, fentes et centre en fusion.
## UV.x = position en travers (m), UV.y = position le long (m) ; UV2.x = travers normalisé (-1..1).
## Lave en fusion : texture peinte OpenArt (tex_lava) qui coule le long de la coulée, en deux
## couches de vitesse et d'échelle différentes (le courant semble tourbillonner), plus chaude au
## centre, assombrie contre les berges. UV.x = travers (m), UV.y = long (m) ; UV2.x = travers -1..1.
const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D lava_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float speed = 0.45;
uniform float tile = 7.0;     // mètres par répétition de la texture
void fragment() {
	float side = abs(UV2.x);
	vec2 uv = vec2(UV.x, UV.y) / tile;
	vec3 a = texture(lava_tex, uv + vec2(0.0, -TIME * speed / tile)).rgb;
	vec3 b = texture(lava_tex, uv * 0.63 + vec2(0.31, -TIME * speed * 0.55 / tile)).rgb;
	vec3 col = mix(a, b, 0.4);
	col = max(col, a * 0.9);
	// plus chaud et clair au centre, plus rouge et sombre contre les berges
	col *= mix(1.15, 0.7, smoothstep(0.35, 1.0, side));
	col = mix(col, vec3(0.45, 0.08, 0.02), smoothstep(0.88, 1.0, side) * 0.8);
	col *= 0.95 + 0.08 * sin(TIME * 2.0 + UV.y * 0.5);
	ALBEDO = col;
}
"""

## Croûte de lave refroidie (berges, dalles, plaques qui flottent) : texture peinte OpenArt
## (tex_crust) projetée du dessus, les fentes orange de la texture brillent.
const CRUST_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform sampler2D crust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile = 3.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	// projection sur trois axes (faces du dessus et côtés des dalles)
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 c = texture(crust_tex, wp.zy / tile).rgb * bw.x + texture(crust_tex, wp.xz / tile).rgb * bw.y + texture(crust_tex, wp.xy / tile).rgb * bw.z;
	float glow = smoothstep(0.25, 0.5, c.r - c.b);
	ALBEDO = c;
	EMISSION = c * glow * 1.6 * (0.85 + 0.25 * sin(TIME * 1.5 + wp.x * 0.4));
	ROUGHNESS = 0.9;
}
"""

## Plaques de croûte noire qui flottent et dérivent le long d'une coulée (en boucle).
class FlowSlabs extends Node3D:
	var pts: PackedVector3Array
	var half: PackedFloat32Array
	var cum: PackedFloat32Array
	var total := 1.0
	var slabs: Array = []   # [noeud, distance de départ, décalage en travers (-1..1), vitesse]
	func setup(p: PackedVector3Array, h: PackedFloat32Array, mesh: Mesh, mat: Material, n: int) -> void:
		pts = p
		half = h
		cum.resize(p.size())
		cum[0] = 0.0
		for i in range(1, p.size()):
			cum[i] = cum[i - 1] + p[i].distance_to(p[i - 1])
		total = maxf(cum[p.size() - 1], 1.0)
		for k in n:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var sc := randf_range(0.35, 0.8)
			mi.scale = Vector3(sc * randf_range(1.0, 1.6), sc * 0.18, sc)
			add_child(mi)
			slabs.append([mi, randf() * total, randf_range(-0.55, 0.55), randf_range(0.35, 0.6), randf() * TAU])
	func _process(_d: float) -> void:
		var t := Time.get_ticks_msec() * 0.001
		for s in slabs:
			var d := fmod(s[1] + t * s[3], total)
			var i := 1
			while i < cum.size() - 1 and cum[i] < d:
				i += 1
			var k := clampf((d - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.001), 0.0, 1.0)
			var c := pts[i - 1].lerp(pts[i], k)
			var dir := (pts[i] - pts[i - 1]).normalized()
			var side := Vector3(-dir.z, 0, dir.x)
			var w := lerpf(half[i - 1], half[i], k)
			var mi: MeshInstance3D = s[0]
			mi.position = Vector3(c.x, 0.06, c.z) + side * s[2] * w
			mi.rotation.y = s[4] + t * 0.15
			# apparition / disparition douce aux extrémités de la coulée
			var e := minf(d, total - d)
			mi.visible = e > 1.0

static var _cache := {}


static func _shader(code: String) -> Shader:
	if not _cache.has(code):
		var s := Shader.new()
		s.code = code
		_cache[code] = s
	return _cache[code]


static func rock_material() -> ShaderMaterial:
	if not _cache.has("rock_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader(ROCK_SHADER)
		_cache["rock_mat"] = m
	return _cache["rock_mat"]


## Bois calciné : charbon, braises dans les crevasses de l'écorce, un peu de cendre.
static func charred_material() -> ShaderMaterial:
	if not _cache.has("char_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader(ROCK_SHADER)
		m.set_shader_parameter("crack_scale", 2.2)
		m.set_shader_parameter("crack_amount", 0.8)
		m.set_shader_parameter("ash_amount", 0.5)
		m.set_shader_parameter("heat_height", 4.0)
		m.set_shader_parameter("base_dark", Color(0.03, 0.025, 0.025))
		m.set_shader_parameter("base_light", Color(0.09, 0.07, 0.065))
		_cache["char_mat"] = m
	return _cache["char_mat"]


## Rocher magmatique (à miner) : basalte noir parcouru de larges veines de lave sur toute sa hauteur.
static func magma_material() -> ShaderMaterial:
	if not _cache.has("magma_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader(ROCK_SHADER)
		m.set_shader_parameter("crack_scale", 1.3)
		m.set_shader_parameter("crack_amount", 1.4)
		m.set_shader_parameter("crack_mask", 0.4)
		m.set_shader_parameter("ash_amount", 0.35)
		m.set_shader_parameter("heat_height", 6.0)
		m.set_shader_parameter("base_dark", Color(0.03, 0.022, 0.022))
		m.set_shader_parameter("base_light", Color(0.11, 0.08, 0.07))
		_cache["magma_mat"] = m
	return _cache["magma_mat"]


## Bourrelets de lave refroidie au bord des coulées : sans cendre, fissures chaudes.
static func bank_material() -> ShaderMaterial:
	if not _cache.has("bank_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader(CRUST_SHADER)
		m.set_shader_parameter("crust_tex", load("res://assets/nature/volcanic/tex_crust.jpg"))
		_cache["bank_mat"] = m
	return _cache["bank_mat"]


static func volcano_material() -> ShaderMaterial:
	if not _cache.has("volc_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader(VOLCANO_SHADER)
		_cache["volc_mat"] = m
	return _cache["volc_mat"]


static func lava_material() -> ShaderMaterial:
	if not _cache.has("lava_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader(LAVA_SHADER)
		m.set_shader_parameter("lava_tex", load("res://assets/nature/volcanic/tex_lava.jpg"))
		_cache["lava_mat"] = m
	return _cache["lava_mat"]


## Maillage d'un modèle (premier MeshInstance3D du .glb).
static func mesh(name: String) -> Mesh:
	var k := "mesh_" + name
	if not _cache.has(k):
		var ps: PackedScene = load("res://assets/nature/volcanic/%s.glb" % name)
		var inst := ps.instantiate()
		Mats.fix_glb_textures(inst, "res://assets/nature/volcanic/%s.glb" % name)
		var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_cache[k] = mi.mesh
		inst.free()
	return _cache[k]


## Coulée de lave le long d'une ligne au sol. pts : points du tracé (y ignoré), half : demi-largeurs.
## Renvoie des cercles [centre, rayon] qui servent de zone de dégâts.
static func build_flow(parent: Node3D, pts: PackedVector3Array, half: PackedFloat32Array) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank := SurfaceTool.new()
	bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var prev_l := PackedVector3Array()
	var prev_b := []
	var prev_v := 0.0
	var circles: Array = []
	for i in pts.size():
		var pa := pts[maxi(i - 1, 0)]
		var pb := pts[mini(i + 1, pts.size() - 1)]
		var t := Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
		var s := Vector3(-t.z, 0, t.x)
		var c := Vector3(pts[i].x, 0, pts[i].z)
		if i > 0:
			along += c.distance_to(Vector3(pts[i - 1].x, 0, pts[i - 1].z))
		var w := half[i]
		# surface de lave : 5 sommets en travers (légèrement bombée au centre)
		var row := PackedVector3Array()
		for k in 5:
			var u := -1.0 + k * 0.5
			row.append(c + s * (u * w) + Vector3.UP * (0.07 + 0.03 * (1.0 - u * u)))
		# bourrelets de roche refroidie de chaque côté : bord de lave -> crête -> sol
		var brow := []
		for sg in [-1.0, 1.0]:
			brow.append([c + s * sg * w + Vector3.UP * 0.05, c + s * sg * (w + 0.5) + Vector3.UP * 0.14, c + s * sg * (w + 1.3) + Vector3.UP * -0.02])
		if i > 0:
			for k in 4:
				var u0 := -1.0 + k * 0.5
				var u1 := u0 + 0.5
				var q0 := [prev_l[k], Vector2(u0 * w, prev_v), u0]
				var q1 := [row[k], Vector2(u0 * w, along), u0]
				var q2 := [row[k + 1], Vector2(u1 * w, along), u1]
				var q3 := [prev_l[k + 1], Vector2(u1 * w, prev_v), u1]
				_tri(st, q0, q1, q2)
				_tri(st, q0, q2, q3)
			for side in 2:
				var a: Array = prev_b[side]
				var b: Array = brow[side]
				for k in 2:
					_tri(bank, [a[k]], [b[k]], [b[k + 1]])
					_tri(bank, [a[k]], [b[k + 1]], [a[k + 1]])
		prev_l = row
		prev_b = brow
		prev_v = along
		if i % 2 == 0:
			circles.append([c, w * 0.95])
	var lava := MeshInstance3D.new()
	lava.mesh = st.commit()
	lava.material_override = lava_material()
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lava)
	var bm := MeshInstance3D.new()
	bm.mesh = bank.commit()
	bm.material_override = bank_material()
	parent.add_child(bm)
	# berges : dalles de basalte plates posées le long des bords (comme sur le visuel)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var tfs: Array[Transform3D] = []
	var acc := 0.0
	for i in range(1, pts.size()):
		acc += pts[i].distance_to(pts[i - 1])
		if acc < 2.2:
			continue
		acc = 0.0
		var dir := (pts[i] - pts[i - 1]).normalized()
		var sd := Vector3(-dir.z, 0, dir.x)
		for sg in [-1.0, 1.0]:
			if randf() < 0.25:
				continue
			var sc := randf_range(0.7, 1.3)
			var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(sc * randf_range(1.2, 2.0), sc * randf_range(0.25, 0.5), sc * randf_range(1.0, 1.6)))
			tfs.append(Transform3D(b, Vector3(pts[i].x, -0.08, pts[i].z) + sd * sg * (half[i] + randf_range(0.2, 0.9))))
	mm.mesh = mesh("rock_slab")
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = bank_material()
	parent.add_child(mmi)
	# croûte noire qui flotte et dérive
	var fs := FlowSlabs.new()
	parent.add_child(fs)
	fs.setup(pts, half, mesh("rock_slab"), bank_material(), maxi(4, int(pts.size() / 4.0)))
	# quelques lumières le long de la coulée
	var step := maxi(1, int(pts.size() / 3.0))
	for i in range(step / 2, pts.size(), step):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.42, 0.1)
		l.light_energy = 2.2
		l.omni_range = half[i] * 3.5 + 4.0
		l.position = Vector3(pts[i].x, 1.2, pts[i].z)
		parent.add_child(l)
	return circles


## Triangle orienté vers le haut (Godot : face avant = sens horaire vue de devant), normale plate.
## Chaque sommet : [position, uv?, travers?].
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var n: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	if n.y > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var up := (-n).normalized()
	for v in [a, b, c]:
		st.set_normal(up)
		if v.size() > 1:
			st.set_uv(v[1])
			st.set_uv2(Vector2(v[2], 0))
		st.add_vertex(v[0])


## Tache ronde aux bords doux (fumée, braises).
static func soft_dot() -> Texture2D:
	if not _cache.has("dot"):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_cache["dot"] = gt
	return _cache["dot"]
