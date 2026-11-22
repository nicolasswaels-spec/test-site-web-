extends CharacterBody3D
## Zombie : avance vers la sphère, attaque le joueur s'il est proche,
## et détruit les constructions qui lui barrent la route.

const Mats = preload("res://scripts/mats.gd")

signal died(zombie)

const CHASE_RANGE := 13.0
const GRAVITY := 20.0
const RISE_TIME := 0.9

var max_hp := 80.0
var hp := 80.0
var speed := 2.5
var damage := 10.0
var size_mult := 1.0
var is_boss := false
var main
var orb
var player

var head_height := 1.38
var dead := false
var attack_cd := 0.5
var attack_anim := 0.0
var anim_t := 0.0
var rise_t := RISE_TIME
var flash_t := 0.0
var groan_t := 0.0
var blocked_by = null
var blocked_t := 0.0

var visual: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var skin_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("zombie")
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 16 | 32
	var s := size_mult
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38 * s
	cap.height = 1.8 * s
	shape.shape = cap
	shape.position.y = 0.9 * s
	add_child(shape)
	head_height = 1.42 * s
	_build_model(s)
	anim_t = randf() * 10.0
	groan_t = randf_range(2.0, 9.0)
	visual.position.y = -2.0 * s
	if main:
		main.spawn_impact(global_position + Vector3.UP * 0.2, Vector3.UP, Color(0.35, 0.25, 0.15), 14, 1.3)


func _build_model(s: float) -> void:
	visual = Node3D.new()
	add_child(visual)
	skin_mat = StandardMaterial3D.new()
	skin_mat.roughness = 0.8
	if is_boss:
		skin_mat.albedo_color = Color(0.55, 0.35, 0.65)
	else:
		skin_mat.albedo_color = Color(0.42, 0.68, 0.32).lerp(Color(0.55, 0.72, 0.4), randf())
	var shirts := [Color(0.55, 0.2, 0.6), Color(0.2, 0.35, 0.7), Color(0.6, 0.35, 0.15), Color(0.75, 0.2, 0.2), Color(0.25, 0.5, 0.45)]
	var shirt := Mats.col(Color(0.15, 0.12, 0.12) if is_boss else shirts[randi() % shirts.size()])
	var pants := Mats.col(Color(0.18, 0.2, 0.32) if randf() > 0.4 else Color(0.32, 0.25, 0.18))
	var eye := Mats.col(Color(1.0, 0.15, 0.1) if is_boss else Color(1.0, 0.9, 0.2), 0.3, 4.0)
	var dark := Mats.col(Color(0.12, 0.05, 0.05))

	Mats.box(visual, Vector3(0.62, 0.72, 0.36) * s, shirt, Vector3(0, 1.08, 0) * s)
	Mats.box(visual, Vector3(0.5, 0.2, 0.3) * s, skin_mat, Vector3(0.02, 0.8, 0.0) * s)  # ventre
	var head := Node3D.new()
	head.position = Vector3(0, 1.66, -0.04) * s
	head.rotation_degrees = Vector3(12, 0, randf_range(-12, 12))
	visual.add_child(head)
	Mats.box(head, Vector3(0.46, 0.46, 0.46) * s, skin_mat)
	Mats.box(head, Vector3(0.1, 0.07, 0.03) * s, eye, Vector3(-0.11, 0.05, -0.235) * s)
	Mats.box(head, Vector3(0.1, 0.07, 0.03) * s, eye, Vector3(0.11, 0.05, -0.235) * s)
	Mats.box(head, Vector3(0.26, 0.08, 0.03) * s, dark, Vector3(0, -0.12, -0.235) * s)
	if is_boss:
		Mats.box(visual, Vector3(0.3, 0.25, 0.35) * s, dark, Vector3(-0.45, 1.5, 0) * s, Vector3(0, 0, 20))
		Mats.box(visual, Vector3(0.3, 0.25, 0.35) * s, dark, Vector3(0.45, 1.5, 0) * s, Vector3(0, 0, -20))

	arm_l = _limb(Vector3(-0.42, 1.38, 0) * s, Vector3(0.2, 0.7, 0.2) * s, skin_mat)
	arm_r = _limb(Vector3(0.42, 1.38, 0) * s, Vector3(0.2, 0.7, 0.2) * s, skin_mat)
	leg_l = _limb(Vector3(-0.16, 0.74, 0) * s, Vector3(0.25, 0.74, 0.27) * s, pants)
	leg_r = _limb(Vector3(0.16, 0.74, 0) * s, Vector3(0.25, 0.74, 0.27) * s, pants)


func _limb(pivot: Vector3, size: Vector3, mat: Material) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	visual.add_child(p)
	Mats.box(p, size, mat, Vector3(0, -size.y * 0.5, 0))
	return p


func _physics_process(delta: float) -> void:
	if dead:
		return
	if rise_t > 0.0:
		rise_t -= delta
		visual.position.y = lerpf(0.0, -2.0 * size_mult, maxf(rise_t, 0.0) / RISE_TIME)
		return
	visual.position.y = 0.0

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	# Choix de la cible : le joueur s'il est proche, sinon la sphère.
	var target = orb
	var target_pos: Vector3 = orb.global_position
	var reach := 2.4 + 0.4 * size_mult
	if player and not player.dead:
		var dp: float = player.global_position.distance_to(global_position)
		if dp < CHASE_RANGE:
			target = player
			target_pos = player.global_position
			reach = 1.3 + 0.4 * size_mult

	var to := target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if main:
		dir += main.avoidance(self)
	dir.y = 0.0
	dir = dir.normalized()

	attack_cd -= delta
	blocked_t -= delta
	var attack_target = null
	if dist <= reach and (target != player or absf(target_pos.y - global_position.y) < 2.5):
		attack_target = target
	elif blocked_t > 0.0 and is_instance_valid(blocked_by) and not blocked_by.is_queued_for_deletion():
		attack_target = blocked_by

	var face := dir
	if attack_target:
		velocity.x = 0.0
		velocity.z = 0.0
		var ft: Vector3 = attack_target.global_position - global_position
		ft.y = 0.0
		if ft.length() > 0.01:
			face = ft.normalized()
		if attack_cd <= 0.0:
			attack_cd = 1.1 if not is_boss else 1.6
			attack_anim = 1.0
			# la sphère encaisse un peu moins que le joueur ou les murs
			attack_target.take_damage(damage * (0.6 if attack_target == orb else 1.0))
	else:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

	rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)
	move_and_slide()

	# Une construction nous bloque ? On la frappe.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var c := col.get_collider()
		if c and c is Node and (c as Node).is_in_group("structure") and col.get_normal().y < 0.6:
			blocked_by = c
			blocked_t = 0.6
			break

	_animate(delta)

	groan_t -= delta
	if groan_t <= 0.0:
		groan_t = randf_range(5.0, 12.0)
		Sfx.play_3d("groan", global_position + Vector3.UP * 1.5, -2.0, 0.7 if is_boss else 1.0)


func _animate(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if moving:
		anim_t += delta * speed * 2.4
		leg_l.rotation.x = sin(anim_t) * 0.6
		leg_r.rotation.x = -sin(anim_t) * 0.6
	else:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 10.0 * delta)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 10.0 * delta)
	attack_anim = maxf(attack_anim - delta * 3.0, 0.0)
	var lunge := sin(attack_anim * PI) * 0.9
	arm_l.rotation.x = 1.4 + sin(anim_t * 0.5) * 0.12 + lunge
	arm_r.rotation.x = 1.4 - sin(anim_t * 0.5) * 0.12 + lunge
	visual.rotation.z = sin(anim_t * 0.5) * 0.08
	visual.rotation.x = -lunge * 0.25
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			skin_mat.emission_enabled = false


func take_damage(amount: float, headshot := false) -> void:
	if dead:
		return
	hp -= amount
	flash_t = 0.08
	skin_mat.emission_enabled = true
	skin_mat.emission = Color(1, 1, 1)
	skin_mat.emission_energy_multiplier = 1.5 if headshot else 0.8
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("zombie")
	collision_layer = 0
	collision_mask = 0
	skin_mat.emission_enabled = false
	died.emit(self)
	Sfx.play_3d("zdie", global_position + Vector3.UP, 0.0, 0.7 if is_boss else 1.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.8)
	tw.tween_property(visual, "position:y", -1.2 * size_mult, 0.8)
	tw.tween_callback(queue_free)
