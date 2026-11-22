extends StaticBody3D
## Arbre que l'on peut couper à la hache pour récolter du bois.

const Mats = preload("res://scripts/mats.gd")

const WOOD_PER_HIT := 10
const WOOD_BONUS_FELL := 20

var kind := 0          # 0 = feuillu arrondi, 1 = sapin
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

	var trunk_mat := Mats.col(Color(0.45, 0.28, 0.15))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45 * tree_scale
	cyl.height = 4.0 * tree_scale
	shape.shape = cyl
	shape.position.y = 2.0 * tree_scale
	add_child(shape)

	if kind == 0:
		Mats.cylinder(visual, 0.22, 0.38, 3.0, trunk_mat, Vector3(0, 1.5, 0))
		var greens := [Color(0.30, 0.68, 0.20), Color(0.38, 0.76, 0.24), Color(0.26, 0.60, 0.18)]
		var g: Color = greens[randi() % greens.size()]
		Mats.sphere(visual, 1.6, Mats.col(g, 0.9), Vector3(0, 3.9, 0))
		Mats.sphere(visual, 1.2, Mats.col(g.lightened(0.08), 0.9), Vector3(0.9, 3.4, 0.4))
		Mats.sphere(visual, 1.15, Mats.col(g.darkened(0.08), 0.9), Vector3(-0.8, 3.5, -0.5))
		Mats.sphere(visual, 1.0, Mats.col(g.lightened(0.15), 0.9), Vector3(0.1, 4.9, 0.2))
	else:
		Mats.cylinder(visual, 0.18, 0.32, 2.2, trunk_mat, Vector3(0, 1.1, 0))
		var pine := Mats.col(Color(0.13, 0.45, 0.22), 0.9)
		var pine2 := Mats.col(Color(0.17, 0.52, 0.26), 0.9)
		Mats.cylinder(visual, 0.0, 1.9, 2.4, pine, Vector3(0, 2.6, 0), Vector3.ZERO, 10)
		Mats.cylinder(visual, 0.0, 1.5, 2.1, pine2, Vector3(0, 3.7, 0), Vector3.ZERO, 10)
		Mats.cylinder(visual, 0.0, 1.05, 1.8, pine, Vector3(0, 4.8, 0), Vector3.ZERO, 10)
	hp = max_hp


## Appelé par la hache. Renvoie le bois gagné.
func chop(damage: float) -> int:
	if fallen:
		return 0
	hp -= damage
	Sfx.play_3d("chop", global_position + Vector3.UP, 2.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 0.07, 0.05)
	tw.tween_property(visual, "rotation:z", -0.05, 0.08)
	tw.tween_property(visual, "rotation:z", 0.0, 0.1)
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
	tw.tween_property(visual, "rotation:x", PI * 0.5 * (1.0 if randf() > 0.5 else -1.0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Sfx.play_3d("thud", global_position, 4.0))
	tw.tween_interval(0.6)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)
