extends CharacterBody3D
## Mort-vivant (squelette animé du pack KayKit, CC0) : avance vers la sphère,
## attaque le joueur s'il est proche, et détruit les constructions qui lui barrent la route.

const Mats = preload("res://scripts/mats.gd")
const Upg = preload("res://scripts/upgrades.gd")
const MODELS := [
	preload("res://assets/skeletons/Skeleton_Minion.glb"),
	preload("res://assets/skeletons/Skeleton_Rogue.glb"),
]
const BOSS_MODEL := preload("res://assets/skeletons/Skeleton_Warrior.glb")
const MODEL_HEIGHT := 2.17
const ANIM_WALK := "Walking_D_Skeletons"
const ANIM_SPAWN := "Spawn_Ground_Skeletons"
const ANIM_DEATH := "Death_C_Skeletons"
const ANIM_HIT := "Hit_A"
const SPAWN_SPEED := 2.0

static var _flash_mat: StandardMaterial3D
static var _eye_mats := {}

signal died(zombie)

const CHASE_RANGE_ROGUE := 13.0      # squelettes à capuche : chasseurs
const CHASE_RANGE_MINION := 6.5      # squelettes de base : foncent sur la base
const GRAVITY := 20.0

var max_hp := 80.0
var hp := 80.0
var speed := 2.5
var damage := 10.0
var size_mult := 1.0
var is_boss := false
var kind := "minion"   # minion, rogue, boss
var main
var orb
var player

var head_height := 1.38
var dead := false
var attack_cd := 0.5
var attack_anim := 0.0
var anim_t := 0.0
var rise_t := 0.0
var anim: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var attack_anim_name := "Unarmed_Melee_Attack_Punch_A"
var hit_t := 0.0
var traps := 0          # nombre de barbelés traversés en ce moment
var waypoint := Vector3.ZERO   # point de passage choisi (là où la base est la moins défendue)
var has_waypoint := false
var route_t := 0.0
var route_noise := 0.0
var stuck_t := 0.0
var stuck_check_pos := Vector3.ZERO
var stuck_obstacle = null
const TRAP_SLOW := 0.8
const TRAP_DPS := 6.0
var flash_t := 0.0
var groan_t := 0.0
var blocked_by = null
var blocked_t := 0.0

var visual: Node3D


func _ready() -> void:
	add_to_group("zombie")
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 16 | 32 | 64   # 64 : portes (bloquent les squelettes)
	var s := size_mult
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38 * s
	cap.height = 1.8 * s
	shape.shape = cap
	shape.position.y = 0.9 * s
	add_child(shape)
	head_height = 1.12 * s
	_build_model(s)
	groan_t = randf_range(2.0, 9.0)
	route_t = randf_range(0.0, 1.5)
	route_noise = randf()
	if main:
		main.spawn_impact(global_position + Vector3.UP * 0.2, Vector3.UP, Color(0.35, 0.25, 0.15), 14, 1.3)


func _build_model(s: float) -> void:
	visual = Node3D.new()
	add_child(visual)
	var idx := randi() % MODELS.size()
	var scene: PackedScene = BOSS_MODEL if is_boss else MODELS[idx]
	kind = "boss" if is_boss else ("rogue" if idx == 1 else "minion")
	var model := scene.instantiate() as Node3D
	model.rotation.y = PI   # le modèle regarde vers +Z, le jeu vers -Z
	model.scale = Vector3.ONE * (1.8 / MODEL_HEIGHT) * s
	visual.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
		if mi.name.ends_with("_Eyes"):
			mi.material_override = _eye_material()
	# Animations en boucle (l'import glTF ne les marque pas comme telles)
	var walk := anim.get_animation(ANIM_WALK)
	walk.loop_mode = Animation.LOOP_LINEAR
	if is_boss:
		attack_anim_name = "2H_Melee_Attack_Chop"
	rise_t = anim.get_animation(ANIM_SPAWN).length / SPAWN_SPEED
	anim.play(ANIM_SPAWN, -1, SPAWN_SPEED)


func _eye_material() -> StandardMaterial3D:
	var key := "boss" if is_boss else "normal"
	if not _eye_mats.has(key):
		var m := StandardMaterial3D.new()
		var c := Color(1.0, 0.2, 0.1) if is_boss else Color(1.0, 0.75, 0.2)
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 5.0
		_eye_mats[key] = m
	return _eye_mats[key]


static func _flash() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_color = Color(1, 1, 1, 0.55)
	return _flash_mat


func _physics_process(delta: float) -> void:
	if dead:
		return
	if rise_t > 0.0:
		rise_t -= delta
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	# Choix de la cible : le joueur s'il est proche, sinon la sphère.
	var target = orb
	var target_pos: Vector3 = orb.global_position
	var reach := 1.5 + 0.4 * size_mult   # sphère plus petite
	if player and not player.dead and kind != "boss":
		var dp: float = player.global_position.distance_to(global_position)
		if dp < _chase_range():
			target = player
			target_pos = player.global_position
			reach = 1.3 + 0.4 * size_mult

	# Vers la sphère : on passe de préférence par le côté le moins barricadé
	var steer_pos := target_pos
	if target == orb and main:
		route_t -= delta
		if route_t <= 0.0:
			route_t = randf_range(1.6, 2.4)
			var wp: Vector3 = main.choose_route(global_position, orb.global_position, route_noise)
			has_waypoint = wp.distance_to(orb.global_position) > 0.5
			waypoint = wp
		if has_waypoint:
			var d_wp := Vector2(waypoint.x - global_position.x, waypoint.z - global_position.z).length()
			var d_orb_me := Vector2(orb.global_position.x - global_position.x, orb.global_position.z - global_position.z).length()
			var d_orb_wp := Vector2(orb.global_position.x - waypoint.x, orb.global_position.z - waypoint.z).length()
			if d_wp < 2.5 or d_orb_me <= d_orb_wp + 0.5:
				has_waypoint = false
			else:
				steer_pos = waypoint

	var to := target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	var steer := steer_pos - global_position
	steer.y = 0.0
	var dir := steer / maxf(steer.length(), 0.001)
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
			# sphère : 60 % ; joueur et constructions : moitié pour les squelettes normaux,
			# et le boss frappe les constructions deux fois plus fort
			var dmg := damage
			if attack_target == orb:
				dmg *= 0.6
			elif attack_target == player:
				dmg *= 1.0 if is_boss else 0.5
			else:
				dmg *= 2.0 if is_boss else 0.5
			attack_target.take_damage(dmg)
	else:
		var spd := speed * (_wire_slow() if traps > 0 else 1.0)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	if traps > 0:
		hp -= _wire_dps() * delta
		if hp <= 0.0:
			_die()
			return

	rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)
	move_and_slide()

	# Coincé contre un arbre ou un rocher (surtout le boss, plus large) ? On le détruit.
	if not attack_target and not stuck_obstacle:
		for i in get_slide_collision_count():
			var oc = get_slide_collision(i).get_collider()
			if oc and oc is Node and ((oc as Node).is_in_group("tree") or (oc as Node).is_in_group("rock")):
				stuck_t += delta
				if stuck_t > (0.8 if is_boss else 2.5):
					var moved := Vector2(global_position.x - stuck_check_pos.x, global_position.z - stuck_check_pos.z).length()
					if moved < 1.0:
						stuck_obstacle = oc
					stuck_t = 0.0
					stuck_check_pos = global_position
				break
	if stuck_obstacle:
		if not is_instance_valid(stuck_obstacle) or not (stuck_obstacle.is_in_group("tree") or stuck_obstacle.is_in_group("rock")):
			stuck_obstacle = null
		elif attack_cd <= 0.0:
			attack_cd = 1.0 if is_boss else 1.2
			attack_anim = 1.0
			anim.play(attack_anim_name, 0.15, 1.3)
			stuck_obstacle.smash(damage * (4.0 if is_boss else 1.5))

	# Une construction nous bloque ? On la frappe.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var c := col.get_collider()
		if c and c is Node and (c as Node).has_meta("structure"):
			c = (c as Node).get_meta("structure")   # porte : on frappe le mur qui la porte
		if c and c is Node and is_instance_valid(c) and (c as Node).is_in_group("structure") and col.get_normal().y < 0.6:
			blocked_by = c
			blocked_t = 0.6
			break

	_animate(delta)

	groan_t -= delta
	if groan_t <= 0.0:
		groan_t = randf_range(5.0, 12.0)
		Sfx.play_3d("groan", global_position + Vector3.UP * 1.5, -2.0, 0.7 if is_boss else 1.0)


## Distance à laquelle le squelette délaisse la sphère pour attaquer le joueur.
## Base : courte, et encore réduite quand le joueur s'éloigne de la sphère.
## Capuche : longue (ils traquent le joueur). Boss : jamais (seule la sphère compte).
func _chase_range() -> float:
	match kind:
		"rogue":
			return CHASE_RANGE_ROGUE
		"minion":
			var from_orb: float = player.global_position.distance_to(orb.global_position)
			return CHASE_RANGE_MINION * clampf(1.0 - (from_orb - 12.0) / 30.0, 0.4, 1.0)
	return 0.0


func _animate(delta: float) -> void:
	attack_anim = maxf(attack_anim - delta, 0.0)
	hit_t = maxf(hit_t - delta, 0.0)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			for mi in meshes:
				mi.material_overlay = null
	# L'attaque ou la réaction au coup se termine avant de reprendre la marche
	if anim.is_playing() and anim.current_animation != ANIM_WALK and (attack_anim > 0.0 or hit_t > 0.0):
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if moving:
		if anim.current_animation != ANIM_WALK:
			anim.play(ANIM_WALK, 0.2)
		anim.speed_scale = speed * (_wire_slow() if traps > 0 else 1.0) / 2.2
	elif attack_anim <= 0.0 and anim.current_animation == ANIM_WALK:
		anim.play("Idle_Combat" if anim.has_animation("Idle_Combat") else "Idle", 0.2)


func take_damage(amount: float, headshot := false) -> void:
	if dead:
		return
	hp -= amount
	flash_t = 0.08
	for mi in meshes:
		mi.material_overlay = _flash()
	if hp <= 0.0:
		_die()
	elif headshot and attack_anim <= 0.0 and hit_t <= 0.0 and rise_t <= 0.0 and not is_boss:
		hit_t = 0.35
		anim.speed_scale = 1.0
		anim.play(ANIM_HIT, 0.05, 1.8)


func _wire_slow() -> float:
	if player and "upgrades" in player:
		return Upg.wire_slow(player.upgrades["wire"]["slow"])
	return TRAP_SLOW


func _wire_dps() -> float:
	if player and "upgrades" in player:
		return Upg.wire_dps(player.upgrades["wire"]["damage"])
	return TRAP_DPS


func trap_enter() -> void:
	if is_boss:
		return   # le boss ignore les barbelés
	traps += 1


func trap_exit() -> void:
	if is_boss:
		return
	traps = maxi(traps - 1, 0)


func _die() -> void:
	dead = true
	remove_from_group("zombie")
	collision_layer = 0
	collision_mask = 0
	for mi in meshes:
		mi.material_overlay = null
	died.emit(self)
	Sfx.play_3d("zdie", global_position + Vector3.UP, 0.0, 0.7 if is_boss else 1.0)
	anim.speed_scale = 1.0
	anim.play(ANIM_DEATH, 0.1, 1.4)
	var tw := create_tween()
	tw.tween_interval(1.9)
	tw.tween_property(visual, "position:y", -1.2 * size_mult, 0.9)
	tw.tween_callback(queue_free)
