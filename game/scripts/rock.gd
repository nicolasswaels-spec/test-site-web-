extends StaticBody3D
## Rocher : on y récolte de la pierre à la hache (débloqué à la vague 5).

const Nature = preload("res://scripts/nature.gd")
const Harvest = preload("res://scripts/harvest.gd")

const STONE_PER_HIT := 10
const STONE_BREAK := 30       # pierre du dernier coup, multipliée par le bonus des cibles (+60 % par cible touchée, jusqu'à ×2,8)

var variant := 1
var rock_scale := 2.0
var main
var radius := 1.0
var max_hp := 200.0
var hp := 200.0
var visual: Node3D
var broken := false
var harvest := Harvest.new()
var col_center := Vector3.ZERO
var col_radius := 1.0
var last_target_hit := false


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
	# collision = enveloppe convexe du rocher (suit sa vraie forme : coups et cibles sur la surface)
	var cs := CollisionShape3D.new()
	var hull := m.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
	var pts := PackedVector3Array()
	for v in hull.points:
		pts.append(v * rock_scale)
	hull.points = pts
	cs.shape = hull
	add_child(cs)
	col_center = Vector3(0, ab.size.y * rock_scale * 0.4, 0)
	col_radius = radius
	max_hp = 120.0 * rock_scale
	hp = max_hp


## Appelé par la hache. Renvoie la pierre gagnée (0 si la pierre est verrouillée).
func mine(damage: float, hit_pos := Vector3.INF) -> int:
	if broken:
		return 0
	Sfx.play_3d("thud", global_position + Vector3.UP, 2.0, 1.3)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.05, 0.95, 1.05), 0.05)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.12)
	if main and not main.stone_unlocked:
		return 0
	last_target_hit = harvest.register_hit(hit_pos)
	hp -= damage
	if hp <= 0.0:
		var bonus := int(round(STONE_BREAK * harvest.final_mult()))
		harvest.clear()
		_break()
		return bonus
	# 1er coup : 3 cibles d'un coup, posées sur la surface réelle du rocher (lancers de rayon)
	if harvest.needs_spots():
		var center := global_position + col_center
		var base := randf() * TAU
		if hit_pos != Vector3.INF:
			var hd := hit_pos - center
			base = atan2(hd.z, hd.x)
		for k in harvest.SPOT_COUNT:
			for attempt in 8:
				var a := base + deg_to_rad([0.0, -70.0, 70.0][k] + randf_range(-20.0, 20.0))
				var d := Vector3(cos(a), randf_range(0.1, 0.7), sin(a)).normalized()
				var q := PhysicsRayQueryParameters3D.create(center + d * (col_radius * 3.0 + 2.0), center, 16)
				var r := get_world_3d().direct_space_state.intersect_ray(q)
				if not r.is_empty() and r.collider == self:
					harvest.add_spot(self, r.position + r.normal * 0.05, r.normal)
					break
	return int(round(STONE_PER_HIT * (harvest.HIT_BONUS if last_target_hit else 1.0)))


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
