extends StaticBody3D
## Grand sapin stylisé que l'on peut couper à la hache pour récolter du bois.

const Nature = preload("res://scripts/nature.gd")

const WOOD_PER_HIT := 10
const WOOD_BONUS_FELL := 20

var kind := 0
var tree_scale := 1.0
var main
var max_hp := 100.0
var hp := 100.0
var visual: Node3D
var fallen := false


func _ready() -> void:
	add_to_group("tree")
	collision_layer = 16
	collision_mask = 0
	visual = Node3D.new()
	add_child(visual)
	visual.scale = Vector3.ONE * tree_scale
	visual.rotation.y = randf() * TAU
	var variants := Nature.pines()
	var mi := MeshInstance3D.new()
	mi.mesh = variants[kind % variants.size()]
	visual.add_child(mi)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45 * tree_scale
	cyl.height = 8.0
	shape.shape = cyl
	shape.position.y = 4.0
	add_child(shape)
	hp = max_hp


## Appelé par la hache. Renvoie le bois gagné.
func chop(damage: float) -> int:
	if fallen:
		return 0
	hp -= damage
	Sfx.play_3d("chop", global_position + Vector3.UP, 2.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 0.04, 0.05)
	tw.tween_property(visual, "rotation:z", -0.03, 0.08)
	tw.tween_property(visual, "rotation:z", 0.0, 0.12)
	if main:
		main.spawn_impact(global_position + Vector3.UP * 6.0, Vector3.DOWN, Color(0.15, 0.35, 0.35), 10, 1.0)
	if hp <= 0.0:
		_fall()
		return WOOD_PER_HIT + WOOD_BONUS_FELL
	return WOOD_PER_HIT


func _fall() -> void:
	fallen = true
	remove_from_group("tree")
	collision_layer = 0
	if main and main.has_method("rebuild_obstacles"):
		main.call_deferred("rebuild_obstacles")
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", PI * 0.5 * (1.0 if randf() > 0.5 else -1.0), 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Sfx.play_3d("break", global_position, 6.0, 0.6))
	tw.tween_interval(0.8)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(queue_free)
