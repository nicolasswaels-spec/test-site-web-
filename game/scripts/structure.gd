extends StaticBody3D
## Pièce de construction (mur, sol, rampe) en bois ou en pierre, sur une grille de 4 m.
## Peut être réparée et améliorée (×3 PV). Sa vie s'affiche au-dessus d'elle.

const Mats = preload("res://scripts/mats.gd")

enum { WALL, FLOOR, RAMP }
enum { WOOD, STONE }
const SIZES := [Vector3(4.0, 4.0, 0.22), Vector3(4.0, 0.22, 4.0), Vector3(4.0, 0.22, 5.66)]
const BASE_HP := [220.0, 150.0, 150.0]
const STONE_MULT := 2.0
const UPGRADE_MULT := 3.0
const UPGRADE_COST := 50
const BUILD_TIME := 1.5
const PIECE_NAMES := ["MUR", "SOL", "RAMPE"]
const MAT_NAMES := ["BOIS", "PIERRE"]

const SHADER := """
shader_type spatial;
uniform float damage = 0.0;
uniform float flash = 0.0;
uniform int axis = 0;
uniform int stone = 0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
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

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = SIZES[piece]
	cs.shape = bs
	add_child(cs)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.006
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color(0.6, 1.0, 0.5)
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.render_priority = 10
	label.outline_render_priority = 9
	label.top_level = true
	add_child(label)
	label.global_position = global_position + Vector3.UP * (2.6 if piece == WALL else 1.0)
	label.visible = false

	visual.scale = Vector3(0.3, 0.3, 0.3)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _compute_max_hp() -> float:
	var v: float = BASE_HP[piece]
	if material_type == STONE:
		v *= STONE_MULT
	if level > 0:
		v *= UPGRADE_MULT
	return v


func _rebuild_visual() -> void:
	for c in visual.get_children():
		c.queue_free()
	mat.set_shader_parameter("stone", material_type)
	var size: Vector3 = SIZES[piece]
	Mats.box(visual, size, mat)
	var frame := Mats.col(Color(0.30, 0.18, 0.10)) if material_type == WOOD else Mats.col(Color(0.22, 0.22, 0.28))
	var hx := size.x * 0.5
	if piece == WALL:
		var hy := size.y * 0.5
		Mats.box(visual, Vector3(size.x, 0.22, 0.3), frame, Vector3(0, hy - 0.11, 0))
		Mats.box(visual, Vector3(size.x, 0.22, 0.3), frame, Vector3(0, -hy + 0.11, 0))
		Mats.box(visual, Vector3(0.22, size.y, 0.3), frame, Vector3(hx - 0.11, 0, 0))
		Mats.box(visual, Vector3(0.22, size.y, 0.3), frame, Vector3(-hx + 0.11, 0, 0))
		if material_type == WOOD:
			Mats.box(visual, Vector3(0.18, size.y * 1.3, 0.26), frame, Vector3.ZERO, Vector3(0, 0, 45))
	else:
		var hz := size.z * 0.5
		Mats.box(visual, Vector3(0.22, 0.3, size.z), frame, Vector3(hx - 0.11, 0, 0))
		Mats.box(visual, Vector3(0.22, 0.3, size.z), frame, Vector3(-hx + 0.11, 0, 0))
		Mats.box(visual, Vector3(size.x, 0.3, 0.22), frame, Vector3(0, 0, hz - 0.11))
		Mats.box(visual, Vector3(size.x, 0.3, 0.22), frame, Vector3(0, 0, -hz + 0.11))
	if level > 0:
		# renforts en fer riveté
		var iron := Mats.col(Color(0.16, 0.17, 0.20), 0.4)
		var rivet := Mats.col(Color(0.75, 0.6, 0.35), 0.3)
		if piece == WALL:
			for y in [-1.0, 1.0]:
				Mats.box(visual, Vector3(size.x - 0.3, 0.26, 0.36), iron, Vector3(0, y, 0))
				for x in [-1.4, -0.47, 0.47, 1.4]:
					Mats.box(visual, Vector3(0.08, 0.08, 0.42), rivet, Vector3(x, y, 0))
		else:
			for x in [-1.0, 1.0]:
				Mats.box(visual, Vector3(0.26, 0.34, size.z - 0.3), iron, Vector3(x, 0, 0))
				for z in [-1.6, -0.5, 0.5, 1.6]:
					Mats.box(visual, Vector3(0.08, 0.4, 0.08), rivet, Vector3(x, 0, z * size.z / 4.0))


func _process(delta: float) -> void:
	if building:
		hp = minf(hp + max_hp * 0.7 / BUILD_TIME * delta, max_hp)
		if hp >= max_hp:
			building = false
	if flash > 0.0:
		flash = maxf(flash - delta * 6.0, 0.0)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("damage", 1.0 - hp / max_hp)
	_update_label()


func _update_label() -> void:
	var p = main.player if main else null
	var d := 999.0
	if p:
		d = p.global_position.distance_to(global_position)
	var damaged := hp < max_hp - 0.5
	label.visible = d < 12.0 or (damaged and d < 35.0)
	if not label.visible:
		return
	var h := int(ceil(hp))
	if h == shown_hp:
		return
	shown_hp = h
	var ratio := hp / max_hp
	var bars := int(round(ratio * 10.0))
	label.text = "%s%s\n%d / %d" % ["|".repeat(bars), ".".repeat(10 - bars), h, int(max_hp)]
	label.modulate = Color(1.0, 0.3, 0.25).lerp(Color(0.55, 1.0, 0.45), ratio)


func describe() -> String:
	return "%s EN %s%s" % [PIECE_NAMES[piece], MAT_NAMES[material_type], " (AMÉLIORÉ)" if level > 0 else ""]


## Coût de réparation (dans le matériau de la pièce) pour revenir à 100 %.
func repair_cost() -> int:
	var missing := max_hp - hp
	if missing < 0.5:
		return 0
	return maxi(1, int(ceil(missing / max_hp * 10.0)))


func repair() -> void:
	hp = max_hp
	building = false
	flash = 0.6
	Sfx.play_3d("build", global_position, 0.0, 0.8)


func can_upgrade() -> bool:
	return level == 0


func upgrade() -> void:
	if level > 0:
		return
	var ratio := hp / max_hp
	level = 1
	max_hp = _compute_max_hp()
	hp = max_hp * ratio
	if building:
		hp = max_hp * maxf(ratio, 0.3)
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
	Sfx.play_3d("chop" if material_type == WOOD else "thud", global_position, -6.0, 0.8)
	if hp <= 0.0:
		_break()


func _break() -> void:
	if main:
		if main.structures.get(key) == self:
			main.structures.erase(key)
		var c := Color(0.6, 0.4, 0.2) if material_type == WOOD else Color(0.45, 0.45, 0.52)
		main.spawn_impact(global_position, Vector3.UP, c, 24, 2.0)
	Sfx.play_3d("break", global_position, 2.0)
	queue_free()
