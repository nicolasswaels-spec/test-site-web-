extends StaticBody3D
## Pièce de construction en bois (mur, sol, rampe) posée sur une grille de 4 m.

const Mats = preload("res://scripts/mats.gd")

enum { WALL, FLOOR, RAMP }
const SIZES := [Vector3(4.0, 4.0, 0.22), Vector3(4.0, 0.22, 4.0), Vector3(4.0, 0.22, 5.66)]
const MAX_HP := [220.0, 150.0, 150.0]
const BUILD_TIME := 1.5

const PLANK_SHADER := """
shader_type spatial;
uniform float damage = 0.0;
uniform float flash = 0.0;
uniform int axis = 0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void fragment() {
	float coord = axis == 0 ? lp.y : lp.x;
	float along = axis == 0 ? lp.x : lp.z;
	float idx = floor(coord * 2.0);
	float f = fract(coord * 2.0);
	float seam = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
	vec3 wood = mix(vec3(0.62, 0.40, 0.22), vec3(0.78, 0.55, 0.32), hash(idx + 3.1));
	float grain = 0.88 + 0.12 * sin(along * 18.0 + hash(idx) * 20.0 + sin(along * 3.0) * 2.0);
	vec3 c = wood * grain * mix(0.45, 1.0, seam);
	c *= 1.0 - damage * 0.55;
	c = mix(c, vec3(1.0, 0.95, 0.8), flash * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

static var _shader: Shader

var piece := WALL
var key := ""
var main
var max_hp := 150.0
var hp := 150.0
var building := true
var visual: Node3D
var mat: ShaderMaterial
var flash := 0.0


func _ready() -> void:
	add_to_group("structure")
	collision_layer = 8
	collision_mask = 0
	var size: Vector3 = SIZES[piece]
	max_hp = MAX_HP[piece]
	hp = max_hp * 0.3

	if _shader == null:
		_shader = Shader.new()
		_shader.code = PLANK_SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("axis", 0 if piece == WALL else 1)

	visual = Node3D.new()
	add_child(visual)
	Mats.box(visual, size, mat)

	# Cadre plus sombre sur les bords
	var frame := Mats.col(Color(0.36, 0.22, 0.12))
	var hx := size.x * 0.5
	if piece == WALL:
		var hy := size.y * 0.5
		Mats.box(visual, Vector3(size.x, 0.22, 0.3), frame, Vector3(0, hy - 0.11, 0))
		Mats.box(visual, Vector3(size.x, 0.22, 0.3), frame, Vector3(0, -hy + 0.11, 0))
		Mats.box(visual, Vector3(0.22, size.y, 0.3), frame, Vector3(hx - 0.11, 0, 0))
		Mats.box(visual, Vector3(0.22, size.y, 0.3), frame, Vector3(-hx + 0.11, 0, 0))
		Mats.box(visual, Vector3(0.18, size.y * 1.3, 0.26), frame, Vector3.ZERO, Vector3(0, 0, 45))
	else:
		var hz := size.z * 0.5
		Mats.box(visual, Vector3(0.22, 0.3, size.z), frame, Vector3(hx - 0.11, 0, 0))
		Mats.box(visual, Vector3(0.22, 0.3, size.z), frame, Vector3(-hx + 0.11, 0, 0))
		Mats.box(visual, Vector3(size.x, 0.3, 0.22), frame, Vector3(0, 0, hz - 0.11))
		Mats.box(visual, Vector3(size.x, 0.3, 0.22), frame, Vector3(0, 0, -hz + 0.11))

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)

	visual.scale = Vector3(0.3, 0.3, 0.3)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if building:
		hp = minf(hp + max_hp * 0.7 / BUILD_TIME * delta, max_hp)
		if hp >= max_hp:
			building = false
	if flash > 0.0:
		flash = maxf(flash - delta * 6.0, 0.0)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("damage", 1.0 - hp / max_hp)


func take_damage(amount: float) -> void:
	if is_queued_for_deletion():
		return
	hp -= amount
	flash = 1.0
	Sfx.play_3d("chop", global_position, -6.0, 0.8)
	if hp <= 0.0:
		_break()


func _break() -> void:
	if main:
		if main.structures.get(key) == self:
			main.structures.erase(key)
		main.spawn_impact(global_position, Vector3.UP, Color(0.6, 0.4, 0.2), 24, 2.0)
	Sfx.play_3d("break", global_position, 2.0)
	queue_free()
