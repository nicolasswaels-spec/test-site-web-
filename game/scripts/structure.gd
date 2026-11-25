extends StaticBody3D
## Pièce de construction (mur, sol, rampe) en bois ou en pierre, sur une grille de 4 m.
## Peut être réparée et améliorée (×3 PV). Sa vie s'affiche au-dessus d'elle.

const Mats = preload("res://scripts/mats.gd")

enum { WALL, FLOOR, RAMP }
enum { WOOD, STONE, MAGIC_WOOD, MAGIC_STONE, CLOUD }
## Nuage : 3× les PV d'une pièce en pierre de base (même système d'amélioration, payé en nuages).
const CLOUD_MULT := 3.0
const SIZES := [Vector3(4.0, 4.0, 0.22), Vector3(4.0, 0.22, 4.0), Vector3(4.0, 0.22, 5.66)]
const BASE_HP := [220.0, 150.0, 150.0]
const STONE_MULT := 2.0
## Pièce magique : 5× les PV d'une pièce du même matériau améliorée au maximum ; non améliorable,
## réparée avec beaucoup de bois / pierre (1000 pour une pièce à 1 PV).
const MAGIC_MULT := 5.0
const MAGIC_REPAIR_FULL := 1000
## Améliorations : niveau 1 = PV ×3 (50), niveau 2 = ×2 de plus (150), niveau 3 = ×4 de plus (1000)
const UPGRADE_MULTS := [1.0, 3.0, 6.0, 24.0]
const UPGRADE_COSTS := [50, 150, 1000]
const MAX_LEVEL := 3
const REPAIR_TIME := 5.0
const BAR_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform float ratio = 1.0;
uniform float repair = 0.0;       // part de la barre qui sera réparée (bleu)
uniform float level = 0.0;
void vertex() {
	// toujours face à la caméra, taille constante à l'écran
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float dist = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	VERTEX *= clamp(dist, 2.0, 60.0) * 0.11;
}
void fragment() {
	vec2 uv = UV;
	float border = step(uv.x, 0.015) + step(0.985, uv.x) + step(uv.y, 0.12) + step(0.88, uv.y);
	vec3 good = vec3(0.35, 0.95, 0.35);
	vec3 bad = vec3(1.0, 0.25, 0.2);
	vec3 col = vec3(0.08, 0.08, 0.1);
	if (uv.x < ratio) {
		col = mix(bad, good, ratio) * (1.0 - 0.25 * uv.y);
	} else if (uv.x < ratio + repair) {
		col = vec3(0.3, 0.6, 1.0) * (0.75 + 0.25 * sin(TIME * 8.0));
	}
	// graduations par tranche de 10 %
	col *= 1.0 - 0.35 * step(0.96, fract(uv.x * 10.0));
	col = mix(col, vec3(0.0), clamp(border, 0.0, 1.0));
	ALBEDO = col;
}
"""
const BUILD_TIME := 1.5
const PIECE_NAMES := ["MUR", "SOL", "RAMPE"]
const MAT_NAMES := ["BOIS", "PIERRE", "BOIS MAGIQUE", "PIERRE MAGIQUE", "NUAGE"]

const SHADER := """
shader_type spatial;
uniform float damage = 0.0;
uniform float flash = 0.0;
uniform int axis = 0;
uniform int stone = 0;
uniform int magic = 0;
uniform int cloud = 0;
uniform mat4 to_local = mat4(1.0);
varying vec3 lp;
void vertex() { lp = (to_local * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float cloud_h(vec2 p) {
	float big = vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.28 + vnoise(p * 4.3 + 9.1) * 0.12;
	float balls = smoothstep(0.45, 0.8, vnoise(p * 1.3 + 1.3)) + smoothstep(0.5, 0.85, vnoise(p * 2.6 + 7.7)) * 0.5;
	return big * 0.75 + balls * 0.3;
}
void fragment() {
	float coord = axis == 0 ? lp.y : lp.x;
	float along = axis == 0 ? lp.x : lp.z;
	vec3 c;
	if (stone == 0) {
		float idx = floor(coord * 2.0);
		float f = fract(coord * 2.0);
		float seam = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
		vec3 wood = mix(vec3(0.50, 0.32, 0.18), vec3(0.64, 0.44, 0.26), hash(idx + 3.1));
		float grain = 0.88 + 0.12 * sin(along * 18.0 + hash(idx) * 20.0 + sin(along * 3.0) * 2.0);
		c = wood * grain * mix(0.45, 1.0, seam);
	} else {
		// briques de pierre décalées
		float row = floor(coord * 2.5);
		float off = mod(row, 2.0) * 0.5;
		vec2 cell = vec2(floor(along * 1.25 + off), row);
		vec2 f = vec2(fract(along * 1.25 + off), fract(coord * 2.5));
		float mortar = smoothstep(0.0, 0.06, f.x) * smoothstep(1.0, 0.94, f.x) * smoothstep(0.0, 0.08, f.y) * smoothstep(1.0, 0.92, f.y);
		vec3 rock = mix(vec3(0.36, 0.36, 0.44), vec3(0.50, 0.49, 0.58), hash2(cell));
		c = mix(vec3(0.14, 0.14, 0.18), rock, mortar);
	}
	if (magic == 1) {
		// mousse lumineuse : plaques vertes, plus denses en haut et sur les joints
		float n = hash2(floor(vec2(along, coord) * 3.0)) * 0.6 + hash2(floor(vec2(along, coord) * 7.0)) * 0.4;
		float moss = smoothstep(0.45, 0.7, n + coord * 0.12);
		vec3 moss_col = mix(vec3(0.10, 0.35, 0.12), vec3(0.25, 0.65, 0.22), hash2(floor(vec2(along, coord) * 13.0)));
		c = mix(c, moss_col, moss * 0.85);
		EMISSION = vec3(0.10, 0.85, 0.45) * moss * 0.25 * (0.7 + 0.3 * sin(TIME * 1.5 + along));
	}
	if (cloud == 1) {
		// nuage : boules cotonneuses en relief (ombres bleutées dans les creux), qui dérivent doucement
		vec2 q = vec2(along, coord) * 1.0 + vec2(TIME * 0.05, TIME * 0.02);
		float h = cloud_h(q);
		float e = 0.04;
		float gx = (cloud_h(q + vec2(e, 0.0)) - h) / e;
		float gy = (cloud_h(q + vec2(0.0, e)) - h) / e;
		float light = clamp(0.78 - gx * 0.18 + gy * 0.28, 0.45, 1.15);   // lumière venant d'en haut
		vec3 base = mix(vec3(0.55, 0.61, 0.84), vec3(0.98, 0.98, 1.0), smoothstep(0.25, 0.8, h));
		c = base * light;
		EMISSION = vec3(0.07, 0.08, 0.12) * (0.4 + h);
	}
	// fissures avec les dégâts
	float crack = step(0.985 - damage * 0.12, hash2(floor(vec2(along, coord) * 9.0)));
	c *= 1.0 - damage * 0.45;
	c = mix(c, vec3(0.05), crack * damage);
	c = mix(c, vec3(1.0, 0.95, 0.8), flash * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

static var _shader: Shader

var piece := WALL
var material_type := WOOD
var level := 0
## Modification façon Fortnite : mur 0 plein / 1 porte / 2 fenêtre ; sol 0 plein / 1 trappe.
var variant := 0
var shapes: Array[CollisionShape3D] = []
var door_blocker: StaticBody3D
var trap: Area3D   # barbelés posés sur un sol
const TRAP_COST := 2
var key := ""
var main
var max_hp := 150.0
var hp := 150.0
var building := true
var visual: Node3D
var mat: ShaderMaterial
var flash := 0.0
var label: Label3D
var shown_hp := -1
var bar: MeshInstance3D
var bar_mat: ShaderMaterial
static var _bar_shader: Shader
var repair_t := 0.0          # temps de réparation restant
var repair_rate := 0.0       # PV rendus par seconde pendant la réparation
var repair_icon: Label3D


func _ready() -> void:
	add_to_group("structure")
	collision_layer = 8
	collision_mask = 0
	max_hp = _compute_max_hp()
	hp = max_hp * 0.3

	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("axis", 0 if piece == WALL else 1)

	visual = Node3D.new()
	add_child(visual)
	_rebuild_visual()
	_rebuild_collision()

	# Barre de vie (billboard, taille constante) + chiffres + symbole de réparation
	if _bar_shader == null:
		_bar_shader = Shader.new()
		_bar_shader.code = BAR_SHADER
	bar_mat = ShaderMaterial.new()
	bar_mat.shader = _bar_shader
	bar_mat.render_priority = 10
	bar = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.4, 0.28)
	bar.mesh = qm
	bar.material_override = bar_mat
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.top_level = true
	add_child(bar)
	bar.global_position = global_position + Vector3.UP * (2.75 if piece == WALL else 1.1)
	bar.visible = false
	repair_icon = Label3D.new()
	repair_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	repair_icon.no_depth_test = true
	repair_icon.fixed_size = true
	repair_icon.pixel_size = 0.0007
	repair_icon.font_size = 64
	repair_icon.outline_size = 14
	repair_icon.modulate = Color(0.4, 0.75, 1.0)
	repair_icon.text = "+ RÉPARATION"
	repair_icon.render_priority = 11
	repair_icon.outline_render_priority = 10
	repair_icon.top_level = true
	add_child(repair_icon)
	repair_icon.global_position = global_position + Vector3.UP * (3.2 if piece == WALL else 1.6)
	repair_icon.visible = false

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true   # même taille à l'écran quelle que soit la distance
	label.pixel_size = 0.0007
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color(0.6, 1.0, 0.5)
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.render_priority = 10
	label.outline_render_priority = 9
	label.top_level = true
	add_child(label)
	label.global_position = global_position + Vector3.UP * (2.35 if piece == WALL else 0.75)
	label.visible = false

	mat.set_shader_parameter("to_local", Projection(global_transform.affine_inverse()))
	visual.scale = Vector3(0.3, 0.3, 0.3)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _compute_max_hp() -> float:
	var v: float = BASE_HP[piece]
	if material_type == STONE or material_type == MAGIC_STONE:
		v *= STONE_MULT
	if material_type == CLOUD:
		v *= STONE_MULT * CLOUD_MULT
	if is_magic():
		return v * UPGRADE_MULTS[MAX_LEVEL] * MAGIC_MULT
	return v * UPGRADE_MULTS[level]


func is_magic() -> bool:
	return material_type == MAGIC_WOOD or material_type == MAGIC_STONE


## Matériau utilisé pour réparer / améliorer (index du joueur : 0 bois, 1 pierre, 4 nuage).
func repair_material() -> int:
	return [0, 1, 0, 1, 4][material_type]


## Famille visuelle / sonore : 0 bois, 1 pierre, 2 nuage.
func family() -> int:
	return [0, 1, 0, 1, 2][material_type]


## Les blocs pleins de la pièce selon sa modification : liste de [centre, taille] en local.
func _blocks() -> Array:
	var size: Vector3 = SIZES[piece]
	var t := size.z if piece == WALL else size.y
	if piece == WALL and variant == 1:   # porte 1,6 × 2,8 m
		return [_blk(-2.0, -0.8, -2.0, 2.0, t), _blk(0.8, 2.0, -2.0, 2.0, t), _blk(-0.8, 0.8, 0.8, 2.0, t)]
	if piece == WALL and variant == 2:   # fenêtre 1,8 × 2,4 m, à 0,8 m du sol : on saute au travers
		return [_blk(-2.0, -0.9, -2.0, 2.0, t), _blk(0.9, 2.0, -2.0, 2.0, t),
			_blk(-0.9, 0.9, 1.2, 2.0, t), _blk(-0.9, 0.9, -2.0, -1.2, t)]
	if piece == FLOOR and variant == 1:  # trappe 1,6 × 1,6 m
		return [_flr(-2.0, -0.8, -2.0, 2.0, t), _flr(0.8, 2.0, -2.0, 2.0, t),
			_flr(-0.8, 0.8, 0.8, 2.0, t), _flr(-0.8, 0.8, -2.0, -0.8, t)]
	return [[Vector3.ZERO, size]]


func _blk(x0: float, x1: float, y0: float, y1: float, t: float) -> Array:
	return [Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0), Vector3(x1 - x0, y1 - y0, t)]


func _flr(x0: float, x1: float, z0: float, z1: float, t: float) -> Array:
	return [Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5), Vector3(x1 - x0, t, z1 - z0)]


func _rebuild_collision() -> void:
	for cs in shapes:
		cs.queue_free()
	shapes.clear()
	for b in _blocks():
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.position = b[0]
		add_child(cs)
		shapes.append(cs)
	# La porte laisse passer le joueur mais pas les squelettes (couche 7)
	if door_blocker:
		door_blocker.queue_free()
		door_blocker = null
	if piece == WALL and variant == 1:
		door_blocker = StaticBody3D.new()
		door_blocker.collision_layer = 64
		door_blocker.collision_mask = 0
		door_blocker.set_meta("structure", self)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.6, 2.8, 0.22)
		cs.shape = bs
		cs.position = Vector3(0, -0.6, 0)
		door_blocker.add_child(cs)
		add_child(door_blocker)


func _rebuild_visual() -> void:
	for c in visual.get_children():
		c.queue_free()
	mat.set_shader_parameter("stone", 1 if family() == 1 else 0)
	mat.set_shader_parameter("cloud", 1 if family() == 2 else 0)
	mat.set_shader_parameter("magic", 1 if is_magic() else 0)
	if is_inside_tree():
		mat.set_shader_parameter("to_local", Projection(global_transform.affine_inverse()))
	var size: Vector3 = SIZES[piece]
	for b in _blocks():
		Mats.box(visual, b[1], mat, b[0])
	var frame: StandardMaterial3D = [Mats.col(Color(0.30, 0.18, 0.10)), Mats.col(Color(0.22, 0.22, 0.28)), Mats.col(Color(0.85, 0.9, 1.0), 0.9, 0.2)][family()]
	if is_magic():
		frame = Mats.col(Color(0.16, 0.42, 0.20), 0.9, 0.25)
	var hx := size.x * 0.5
	if family() == 2:
		_cloud_trim(size)
		return
	if piece == WALL:
		var hy := size.y * 0.5
		Mats.box(visual, Vector3(size.x, 0.22, 0.3), frame, Vector3(0, hy - 0.11, 0))
		if variant != 1:
			Mats.box(visual, Vector3(size.x, 0.22, 0.3), frame, Vector3(0, -hy + 0.11, 0))
		Mats.box(visual, Vector3(0.22, size.y, 0.3), frame, Vector3(hx - 0.11, 0, 0))
		Mats.box(visual, Vector3(0.22, size.y, 0.3), frame, Vector3(-hx + 0.11, 0, 0))
		if variant == 1:  # encadrement de porte
			Mats.box(visual, Vector3(0.16, 2.8, 0.3), frame, Vector3(-0.88, -0.6, 0))
			Mats.box(visual, Vector3(0.16, 2.8, 0.3), frame, Vector3(0.88, -0.6, 0))
			Mats.box(visual, Vector3(1.9, 0.16, 0.3), frame, Vector3(0, 0.88, 0))
		elif variant == 2:  # encadrement de fenêtre
			Mats.box(visual, Vector3(2.0, 0.14, 0.3), frame, Vector3(0, 1.27, 0))
			Mats.box(visual, Vector3(2.0, 0.14, 0.3), frame, Vector3(0, -1.27, 0))
		if family() == 0 and variant == 0:
			Mats.box(visual, Vector3(0.18, size.y * 1.3, 0.26), frame, Vector3.ZERO, Vector3(0, 0, 45))
	else:
		var hz := size.z * 0.5
		Mats.box(visual, Vector3(0.22, 0.3, size.z), frame, Vector3(hx - 0.11, 0, 0))
		Mats.box(visual, Vector3(0.22, 0.3, size.z), frame, Vector3(-hx + 0.11, 0, 0))
		Mats.box(visual, Vector3(size.x, 0.3, 0.22), frame, Vector3(0, 0, hz - 0.11))
		Mats.box(visual, Vector3(size.x, 0.3, 0.22), frame, Vector3(0, 0, -hz + 0.11))
	if level >= 3:
		# niveau max : runes turquoise lumineuses
		var rune := Mats.col(Color(0.3, 0.95, 0.9), 0.2, 3.0)
		if piece == WALL:
			for x in [-1.8, 1.8]:
				Mats.box(visual, Vector3(0.06, 3.4, 0.4), rune, Vector3(x, 0, 0))
		else:
			for x in [-1.75, 1.75]:
				Mats.box(visual, Vector3(0.06, 0.38, size.z - 0.4), rune, Vector3(x, 0, 0))
	if level >= 2:
		# plaques d'acier aux coins
		var plate := Mats.col(Color(0.30, 0.32, 0.38), 0.35)
		if piece == WALL:
			for cx in [-1.55, 1.55]:
				for cy in [-1.55, 1.55]:
					if variant == 1 and cy < 0.0 and absf(cx) < 0.9:
						continue
					Mats.box(visual, Vector3(0.6, 0.6, 0.34), plate, Vector3(cx, cy, 0))
		else:
			for cx in [-1.55, 1.55]:
				for cz in [-1.55, 1.55]:
					Mats.box(visual, Vector3(0.6, 0.32, 0.6), plate, Vector3(cx, 0, cz * size.z / 4.0))
	if level > 0:
		# renforts en fer riveté
		var iron := Mats.col(Color(0.16, 0.17, 0.20), 0.4)
		var rivet := Mats.col(Color(0.75, 0.6, 0.35), 0.3)
		if piece == WALL:
			for y in [-1.5, 1.5]:
				var segs := [[-1.85, 1.85]]
				if variant == 1 and y < 0.0:
					segs = [[-1.85, -0.8], [0.8, 1.85]]
				for sg in segs:
					Mats.box(visual, Vector3(sg[1] - sg[0], 0.26, 0.36), iron, Vector3((sg[0] + sg[1]) * 0.5, y, 0))
				for x in [-1.4, 1.4]:
					Mats.box(visual, Vector3(0.08, 0.08, 0.42), rivet, Vector3(x, y, 0))
		else:
			for x in [-1.3, 1.3]:
				Mats.box(visual, Vector3(0.26, 0.34, size.z - 0.3), iron, Vector3(x, 0, 0))
				for z in [-1.6, -0.5, 0.5, 1.6]:
					Mats.box(visual, Vector3(0.08, 0.4, 0.08), rivet, Vector3(x, 0, z * size.z / 4.0))


func _process(delta: float) -> void:
	if building:
		hp = minf(hp + max_hp * 0.7 / BUILD_TIME * delta, max_hp)
		if hp >= max_hp:
			building = false
	if repair_t > 0.0:
		var dt := minf(delta, repair_t)
		repair_t -= dt
		hp = minf(hp + repair_rate * dt, max_hp)
		repair_icon.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
		if repair_t <= 0.0:
			repair_icon.visible = false
	if flash > 0.0:
		flash = maxf(flash - delta * 6.0, 0.0)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("damage", 1.0 - hp / max_hp)
	_update_label()


func _update_label() -> void:
	var d := 999.0
	if main:
		for p in main.players:
			d = minf(d, p.global_position.distance_to(global_position))
	var damaged := hp < max_hp - 0.5
	var show := d < 12.0 or (damaged and d < 35.0) or repair_t > 0.0
	bar.visible = show
	label.visible = show and d < 14.0
	if not show:
		return
	var ratio := hp / max_hp
	bar_mat.set_shader_parameter("ratio", ratio)
	bar_mat.set_shader_parameter("repair", (repair_rate * repair_t) / max_hp if repair_t > 0.0 else 0.0)
	var h := int(ceil(hp))
	if h == shown_hp:
		return
	shown_hp = h
	label.text = "%d / %d%s" % [h, int(max_hp), ("   NIV %d" % level) if level > 0 else ""]


func describe() -> String:
	return "%s EN %s%s" % [PIECE_NAMES[piece], MAT_NAMES[material_type], (" · NIVEAU %d" % level) if level > 0 else ""]


## Coût de réparation (dans le matériau de la pièce) pour revenir à 100 %.
func repair_cost() -> int:
	if repair_t > 0.0:
		return 0
	var missing := max_hp - hp
	if missing < 0.5:
		return 0
	if is_magic():
		return maxi(1, int(ceil(missing / max_hp * MAGIC_REPAIR_FULL)))
	return maxi(1, int(ceil(missing / max_hp * 10.0)))


func is_repairing() -> bool:
	return repair_t > 0.0


## Réparation en 5 s : ne rend que les PV qui manquaient au début ; la pièce peut
## continuer à prendre des dégâts pendant ce temps.
func repair() -> void:
	if repair_t > 0.0:
		return
	if building:
		building = false
	var missing := max_hp - hp
	repair_rate = missing / REPAIR_TIME
	repair_t = REPAIR_TIME
	repair_icon.visible = true
	Sfx.play_3d("build", global_position, 0.0, 0.8)


## Modifie la forme de la pièce (cycle) : mur plein → porte → fenêtre ; sol plein → trappe ;
## rampe : retournée de 180°.
func cycle_edit() -> String:
	if piece == WALL:
		variant = (variant + 1) % 3
	elif piece == FLOOR:
		variant = (variant + 1) % 2
		if variant == 1 and trap:   # une trappe ne peut pas porter de barbelés
			trap.queue_free()
			trap = null
	else:
		var p := global_position
		global_transform = Transform3D(Basis(Vector3.UP, PI) * global_transform.basis, p)
	_rebuild_visual()
	_rebuild_collision()
	Sfx.play_3d("build", global_position, 0.0, 1.2)
	return edit_name()


func edit_name() -> String:
	if piece == WALL:
		return ["MUR PLEIN", "PORTE", "FENÊTRE"][variant]
	if piece == FLOOR:
		return ["SOL PLEIN", "TRAPPE"][variant]
	return "RAMPE RETOURNÉE"


func next_edit_label() -> String:
	if piece == WALL:
		return ["porte", "fenêtre", "mur plein"][variant]
	if piece == FLOOR:
		return ["trappe", "sol plein"][variant]
	return "retourner"


func can_have_trap() -> bool:
	return piece == FLOOR and variant == 0 and trap == null


## Barbelés : ralentissent les squelettes (80 % de leur vitesse, 60 % une fois amélioré) et les blessent un peu.
func add_trap() -> void:
	if not can_have_trap():
		return
	trap = Area3D.new()
	trap.collision_layer = 0
	trap.collision_mask = 4   # squelettes
	trap.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.9, 1.6, 3.9)
	cs.shape = bs
	cs.position = Vector3(0, 0.9, 0)
	trap.add_child(cs)
	add_child(trap)
	trap.body_entered.connect(func(b): if b.has_method("trap_enter"): b.trap_enter())
	trap.body_exited.connect(func(b): if b.has_method("trap_exit"): b.trap_exit())
	# visuel : trois rouleaux de fil barbelé et des piquets en bois
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.42, 0.42, 0.46)
	wire.metallic = 0.8
	wire.roughness = 0.4
	var stake := Mats.col(Color(0.30, 0.18, 0.10))
	var deco := Node3D.new()
	trap.add_child(deco)
	for z in [-1.25, 0.0, 1.25]:
		for i in 9:
			var x := -1.6 + i * 0.4
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.26
			tm.outer_radius = 0.285
			tm.rings = 12
			tm.ring_segments = 4
			ring.mesh = tm
			ring.material_override = wire
			ring.position = Vector3(x, 0.38, z + sin(i * 1.7) * 0.05)
			ring.rotation = Vector3(randf_range(-0.25, 0.25), 0.0, PI * 0.5 + randf_range(-0.2, 0.2))
			deco.add_child(ring)
			# pointes
			Mats.box(deco, Vector3(0.02, 0.12, 0.02), wire, Vector3(x + 0.1, 0.66, z), Vector3(0, 0, 35))
		Mats.cylinder(deco, 0.04, 0.05, 0.9, stake, Vector3(-1.85, 0.45, z), Vector3.ZERO, 6)
		Mats.cylinder(deco, 0.04, 0.05, 0.9, stake, Vector3(1.85, 0.45, z), Vector3.ZERO, 6)
	deco.scale = Vector3(1, 0.1, 1)
	create_tween().tween_property(deco, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play_3d("reload", global_position, 0.0, 0.8)


func can_upgrade() -> bool:
	return level < MAX_LEVEL and not is_magic()


func upgrade_cost() -> int:
	return UPGRADE_COSTS[level] if level < MAX_LEVEL else 0


## Multiplicateur de PV apporté par la prochaine amélioration (×3, ×2, ×4).
func next_upgrade_mult() -> float:
	return UPGRADE_MULTS[level + 1] / UPGRADE_MULTS[level] if level < MAX_LEVEL else 1.0


func upgrade() -> void:
	if level >= MAX_LEVEL:
		return
	var ratio := hp / max_hp
	var old_max := max_hp
	level += 1
	max_hp = _compute_max_hp()
	hp = max_hp * ratio
	if building:
		hp = max_hp * maxf(ratio, 0.3)
	repair_rate *= max_hp / old_max
	shown_hp = -1
	_rebuild_visual()
	flash = 1.0
	visual.scale = Vector3.ONE * 1.08
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play_3d("build", global_position, 2.0, 0.6)


func take_damage(amount: float) -> void:
	if is_queued_for_deletion():
		return
	hp -= amount
	flash = 1.0
	Sfx.play_3d("chop" if family() == 0 else "thud", global_position, -6.0, 0.8 if family() != 2 else 1.4)
	if hp <= 0.0:
		_break()


func _break() -> void:
	if main:
		if main.structures.get(key) == self:
			main.structures.erase(key)
		var c: Color = [Color(0.6, 0.4, 0.2), Color(0.45, 0.45, 0.52), Color(0.95, 0.97, 1.0)][family()]
		main.spawn_impact(global_position, Vector3.UP, c, 24, 2.0)
	Sfx.play_3d("break", global_position, 2.0)
	queue_free()


## Pièce en nuage : bords en boules cotonneuses au lieu du cadre (les niveaux restent visibles par la barre).
func _cloud_trim(size: Vector3) -> void:
	var puff := Mats.col(Color(0.92, 0.94, 1.0), 1.0, 0.12)
	var shade := Mats.col(Color(0.78, 0.82, 0.96), 1.0, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var hx := size.x * 0.5
	if piece == WALL:
		var hy := size.y * 0.5
		var pts: Array[Vector3] = []
		for i in 9:
			var t := -hx + i * size.x / 8.0
			pts.append(Vector3(t, hy, 0))
			if variant != 1:
				pts.append(Vector3(t, -hy, 0))
		for i in range(1, 8):
			var t := -hy + i * size.y / 8.0
			pts.append(Vector3(hx, t, 0))
			pts.append(Vector3(-hx, t, 0))
		for pt in pts:
			var r := rng.randf_range(0.28, 0.42)
			Mats.sphere(visual, r, puff if rng.randf() < 0.7 else shade, pt + Vector3(0, 0, rng.randf_range(-0.05, 0.05)), 8)
	else:
		var hz := size.z * 0.5
		for i in 9:
			var t := -hx + i * size.x / 8.0
			for z in [-hz, hz]:
				Mats.sphere(visual, rng.randf_range(0.22, 0.34), puff if rng.randf() < 0.7 else shade, Vector3(t, 0.05, z), 8)
		for i in range(1, 8):
			var t := -hz + i * size.z / 8.0
			for x in [-hx, hx]:
				Mats.sphere(visual, rng.randf_range(0.22, 0.34), puff if rng.randf() < 0.7 else shade, Vector3(x, 0.05, t), 8)
