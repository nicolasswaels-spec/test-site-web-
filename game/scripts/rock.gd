extends StaticBody3D
## Rocher : on y récolte de la pierre à la hache (débloqué à la vague 5).

const Nature = preload("res://scripts/nature.gd")

const STONE_PER_HIT := 10
const STONE_BONUS_BREAK := 20

var variant := 1
var rock_scale := 2.0
var main
var radius := 1.0
var max_hp := 200.0
var hp := 200.0
var visual: Node3D
var broken := false


func _ready() -> void:
	add_to_group("rock")
	collision_layer = 16
	collision_mask = 0
	visual = Node3D.new()
	add_child(visual)
	var m := MeshInstance3D.new()
	m.mesh = Nature.rock(variant)
	m.scale = Vector3.ONE * rock_scale
	visual.add_child(m)
	var ab: AABB = m.mesh.get_aabb()
	radius = maxf(ab.size.x, ab.size.z) * 0.5 * rock_scale
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = radius * 0.8
	cs.shape = ss
	cs.position.y = ab.size.y * rock_scale * 0.3
	add_child(cs)
	max_hp = 120.0 * rock_scale
	hp = max_hp


## Appelé par la hache. Renvoie la pierre gagnée (0 si la pierre est verrouillée).
func mine(damage: float) -> int:
	if broken:
		return 0
	Sfx.play_3d("thud", global_position + Vector3.UP, 2.0, 1.3)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.05, 0.95, 1.05), 0.05)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.12)
	if main and not main.stone_unlocked:
		return 0
	hp -= damage
	if hp <= 0.0:
		_break()
		return STONE_PER_HIT + STONE_BONUS_BREAK
	return STONE_PER_HIT


## Frappé par un squelette bloqué.
func smash(damage: float) -> void:
	if broken:
		return
	hp -= damage
	Sfx.play_3d("thud", global_position + Vector3.UP, 0.0, 0.8)
	if hp <= 0.0:
		_break()


func _break() -> void:
	broken = true
	remove_from_group("rock")
	collision_layer = 0
	if main:
		main.spawn_impact(global_position + Vector3.UP * 0.5, Vector3.UP, Color(0.45, 0.45, 0.55), 26, 2.0)
		main.call_deferred("on_rock_broken", self)
	Sfx.play_3d("break", global_position, 4.0, 0.7)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
