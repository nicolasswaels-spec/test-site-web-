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
## Niveau du squelette : PV (fort), vitesse (faible), dégâts aux constructions (fort),
## dégâts au joueur (faible : 2 à 10 PV par coup). Vague 1 de la zone 1 = niveau 1.
var level := 1
# brûlure (boule de feu) : dégâts par tic de 0,5 s
var burn_t := 0.0
var burn_dps := 0.0
var burn_by = null
var _burn_tick := 0.0
var player_damage := 2.0
var struct_damage := 4.5
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
## Arme cryogénique : ralenti (70 % de la vitesse) et vulnérable (+10 % de dégâts) pendant 3 s
## Statut de glace (canon cryo) : de 0 à 10. Chaque tic du rayon en ajoute, et on en perd
## un toutes les `frost_step` secondes. Ralentissement et vulnérabilité sont proportionnels
## au nombre de statuts (maximum à 10).
const FROST_MAX_STACKS := 10.0
var frost_stacks := 0.0
var frost_decay_t := 0.0
var frost_step := 1.0          # durée d'un statut (s)
var frost_max_slow := 0.30     # ralentissement à 10 statuts
var frost_max_vuln := 0.10     # vulnérabilité à 10 statuts
static var _frost_mat: StandardMaterial3D
## Gardien de coffre : immobile jusqu'à ce qu'un joueur approche ou l'attaque, puis il le poursuit.
var guard := false
var archer := false        # archer (3e sphère) : reste à distance et tire sur les joueurs
const ARCHER_RANGE := 24.0
const ARCHER_MIN := 9.0
const ARCHER_KEEP := 16.0
const ARROW_DAMAGE := 4.0
const ARROW_CD := 3.8
const ARROW_SPEED := 26.0
var shoot_cd := 2.5
var angel := false         # ange squelette (4e sphère) : vole et tire ; beaucoup de PV, très vulnérable à la tête
var wings: Array[Node3D] = []
var fly_t := 0.0
var summoned := false      # invoqué par le titan : sort de terre et traque les joueurs
var guard_group = null     # coffre gardé (les gardiens d'un même coffre réagissent ensemble)
var charging := false
const GUARD_CHARGE_SPEED := 5.5
var awake := true
const GUARD_WAKE_RANGE := 9.0
var waypoint := Vector3.ZERO   # point de passage choisi (là où la base est la moins défendue)
var has_waypoint := false
var route_t := 0.0
var route_noise := 0.0
var stuck_t := 0.0
var knock_t := 0.0
var knock_vel := Vector3.ZERO
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
	var idx := 0 if archer else randi() % MODELS.size()
	var scene: PackedScene = BOSS_MODEL if is_boss else MODELS[idx]
	kind = "boss" if is_boss else ("angel" if angel else ("archer" if archer else ("rogue" if idx == 1 else "minion")))
	var model := scene.instantiate() as Node3D
	model.rotation.y = PI   # le modèle regarde vers +Z, le jeu vers -Z
	model.scale = Vector3.ONE * (1.8 / MODEL_HEIGHT) * s
	visual.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
		if mi.name.ends_with("_Eyes"):
			mi.material_override = _eye_material()
	if archer:
		_add_bow(model)
	if angel:
		_add_wings(model)
	# Animations en boucle (l'import glTF ne les marque pas comme telles)
	var walk := anim.get_animation(ANIM_WALK)
	walk.loop_mode = Animation.LOOP_LINEAR
	if is_boss:
		attack_anim_name = "2H_Melee_Attack_Chop"
	rise_t = anim.get_animation(ANIM_SPAWN).length / SPAWN_SPEED
	if guard and not summoned:
		awake = false
		rise_t = 0.0
		anim.play("Skeletons_Inactive_Standing_Pose" if anim.has_animation("Skeletons_Inactive_Standing_Pose") else "Idle")
	else:
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

	if angel:
		pass   # vole : l'altitude est gérée dans _archer_logic
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	if frost_stacks > 0.0:
		frost_decay_t -= delta
		if frost_decay_t <= 0.0:
			frost_stacks = maxf(floorf(frost_stacks) - 1.0, 0.0)   # un statut de perdu
			frost_decay_t = frost_step
	if not is_frozen() and flash_t <= 0.0 and meshes.size() > 0 and meshes[0].material_overlay == _frost():
		for mi in meshes:
			mi.material_overlay = null

	if burn_t > 0.0:
		burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			if main:
				main.spawn_impact(global_position + Vector3.UP * 1.2, Vector3.UP, Color(1.0, 0.45, 0.1), 4, 0.5)
			if is_instance_valid(burn_by):
				burn_by.deal_damage(self, burn_dps * 0.5 / burn_by.dmg_mult("fire"), false, "fire")
			else:
				take_damage(burn_dps * 0.5)
			if dead:
				return

	# repoussé (retour d'un joueur) : on glisse en arrière sans rien faire d'autre
	if knock_t > 0.0:
		knock_t -= delta
		velocity.x = knock_vel.x
		velocity.z = knock_vel.z
		knock_vel *= 0.9
		move_and_slide()
		return

	# Gardien endormi : il attend qu'on approche
	if guard and not awake:
		var near = main.nearest_player(global_position) if main else null
		if near and not near.dead and near.global_position.distance_to(global_position) < GUARD_WAKE_RANGE:
			wake_up()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if archer:
		_archer_logic(delta)
		return

	# Choix de la cible : le joueur le plus proche s'il est assez près, sinon la sphère.
	if main and main.has_method("nearest_player"):
		player = main.nearest_player(global_position)
	# un gardien sans joueur vivant à poursuivre reste sur place
	if guard and (player == null or player.dead):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_animate(delta)
		return
	var target = orb
	var target_pos: Vector3 = orb.global_position
	var reach := 1.5 + 0.4 * size_mult   # sphère plus petite
	if player and not player.dead and (kind != "boss" or guard):
		var dp: float = player.global_position.distance_to(global_position)
		if guard or dp < _chase_range():
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
				dmg = damage if is_boss else player_damage
			else:
				dmg = damage * 2.0 if is_boss else struct_damage
			attack_target.take_damage(dmg)
	else:
		var spd := speed * (_wire_slow() if traps > 0 else 1.0) * frost_speed_mult()
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


# ------------------------------------------------------------------ archer

## Arc tenu dans la main gauche (os « handslot.l » du squelette KayKit).
func _add_bow(model: Node3D) -> void:
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "handslot.l"
	sk.add_child(ba)
	var wood := Mats.col(Color(0.35, 0.2, 0.12))
	var bow := Node3D.new()
	bow.rotation_degrees = Vector3(0, 90, 0)
	ba.add_child(bow)
	for i in 7:
		var a := deg_to_rad(-60.0 + i * 20.0)
		var seg := Mats.box(bow, Vector3(0.06, 0.24, 0.06), wood, Vector3(-cos(a) * 0.55 + 0.45, sin(a) * 0.62, 0))
		seg.rotation.z = a
	Mats.box(bow, Vector3(0.015, 1.1, 0.015), Mats.col(Color(0.85, 0.85, 0.8)), Vector3(0.18, 0, 0))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.ends_with("_Eyes"):
			mi.material_override = Mats.col(Color(0.4, 1.0, 0.4), 0.3, 5.0)


## Archer : se tient à distance des joueurs (ni sphère ni constructions), tire lentement.
func _archer_logic(delta: float) -> void:
	player = main.nearest_player(global_position) if main else null
	var dir := Vector3.ZERO
	var face := -global_transform.basis.z
	if player and not player.dead:
		var to: Vector3 = player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		var n := to / maxf(d, 0.01)
		face = n
		if d > ARCHER_KEEP:
			dir = n
		elif d < ARCHER_MIN:
			dir = -n
		shoot_cd -= delta
		if shoot_cd <= 0.0 and d < ARCHER_RANGE and _clear_shot(player):
			shoot_cd = ARROW_CD + randf_range(0.0, 1.0)
			attack_anim = 0.9
			var shot := "1H_Ranged_Shoot" if anim.has_animation("1H_Ranged_Shoot") else "Throw"
			anim.play(shot, 0.1, 1.2)
			var tw := create_tween()
			tw.tween_interval(0.35)
			tw.tween_callback(_shoot_arrow)
	if angel:
		# vol stationnaire à ~6 m au-dessus de l'île, ailes qui battent
		fly_t += delta
		var alt: float = (main.SKY_Y if main and main.get("sky_unlocked") else 0.0) + 6.0 + sin(fly_t * 1.3) * 0.8
		velocity.y = (alt - global_position.y) * 1.8
		for i in wings.size():
			wings[i].rotation.y = (0.35 + sin(fly_t * 9.0) * 0.55) * (1.0 if i == 0 else -1.0)
	if dir != Vector3.ZERO and attack_anim <= 0.0:
		dir += main.avoidance(self) * 0.6
		dir.y = 0.0
		dir = dir.normalized()
		var spd := speed * 0.8 * (_wire_slow() if traps > 0 else 1.0) * frost_speed_mult()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if traps > 0:
		hp -= _wire_dps() * delta
		if hp <= 0.0:
			_die()
			return
	rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)
	move_and_slide()
	_animate(delta)


## Ange : deux grandes ailes blanches dans le dos et une auréole dorée.
func _add_wings(model: Node3D) -> void:
	var feather := Mats.col(Color(0.95, 0.96, 1.0), 0.8, 0.25)
	var gold := Mats.col(Color(1.0, 0.82, 0.35), 0.3, 2.5)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.12, 1.25, 0.18)
		model.add_child(pivot)
		var w := Node3D.new()
		w.position = Vector3(side * 0.55, 0.1, 0)
		pivot.add_child(w)
		for k in 4:
			Mats.box(w, Vector3(0.95 - k * 0.15, 0.12, 0.05), feather, Vector3(side * k * 0.08, 0.25 - k * 0.2, 0.0), Vector3(0, 0, side * (10 + k * 12)))
		wings.append(pivot)
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.24
	halo.mesh = tm
	halo.material_override = gold
	halo.position = Vector3(0, 2.25, 0)
	model.add_child(halo)


func _clear_shot(p) -> bool:
	var from := global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(from, p.global_position + Vector3.UP * 1.2, 1 | 8)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _shoot_arrow() -> void:
	if dead or main == null or player == null or player.dead:
		return
	var from := global_position + Vector3.UP * 1.45 - global_transform.basis.z * 0.5
	var aim: Vector3 = player.global_position + Vector3.UP * 1.1
	aim += player.velocity * (from.distance_to(aim) / ARROW_SPEED) * 0.5
	aim += Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3), randf_range(-0.6, 0.6))
	var ar := Arrow.new()
	ar.main = main
	ar.damage = 6.0 if angel else ARROW_DAMAGE
	ar.velocity = (aim - from).normalized() * ARROW_SPEED
	main.add_child(ar)
	ar.global_position = from
	Sfx.play_3d("shot", from, -14.0, 1.8)


class Arrow extends Node3D:
	var main
	var damage := 4.0
	var velocity := Vector3.ZERO
	var life := 3.0
	var stuck := false

	func _ready() -> void:
		var m := Mats.box(self, Vector3(0.04, 0.04, 0.75), Mats.col(Color(0.45, 0.3, 0.18)))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Mats.box(self, Vector3(0.07, 0.07, 0.12), Mats.col(Color(0.7, 0.72, 0.8), 0.4), Vector3(0, 0, -0.4))
		Mats.box(self, Vector3(0.12, 0.01, 0.14), Mats.col(Color(0.9, 0.9, 0.85)), Vector3(0, 0, 0.32))
		_orient()

	func _orient() -> void:
		if velocity.length() > 0.1:
			look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if stuck:
			return
		velocity.y -= 4.0 * delta
		var from := global_position
		var to := from + velocity * delta
		for p in main.players:
			if p.dead:
				continue
			var c: Vector3 = p.global_position + Vector3.UP * 1.0
			var ab := to - from
			var t := clampf((c - from).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if (from + ab * t).distance_to(c) < 0.75:
				p.take_damage(damage)
				queue_free()
				return
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 16)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			global_position = r.position
			stuck = true      # la flèche reste plantée (sans abîmer les constructions)
			life = 2.0
			return
		global_position = to
		_orient()


# ------------------------------------------------------------------ niveaux

static func level_hp(lvl: int) -> float:
	if lvl <= 10:
		return 40.0 + (186.0 - 40.0) * (lvl - 1) / 9.0     # zone 1 : 40 -> 186
	var hp := (4.0 + 14.0 * lvl) * 1.4                      # niveau 11 = 221 PV, niveau 20 = 398 PV
	if lvl > 40:
		hp *= pow(1.07, lvl - 40)   # défense sans fin : les PV finissent par exploser
	return hp


static func level_speed(lvl: int) -> float:
	if lvl <= 10:
		return 2.0 + 0.14 * lvl                 # zone 1 : 2,1 -> 3,4 m/s
	return 3.4 + 0.06 * (lvl - 10)              # ensuite : +0,06 m/s par niveau


static func level_struct_damage(lvl: int) -> float:
	return 4.5 * 1.3 * pow(1.08, lvl - 1)                     # +8 % par niveau (×1,3 : squelettes moins nombreux)


static func level_player_damage(lvl: int) -> float:
	return clampf(2.0 + 8.0 * (lvl - 1) / 24.0, 2.0, 10.0)   # niveau 1 : 2 PV, niveau 25 : 10 PV


## Applique les caractéristiques d'un niveau (PV, vitesse, dégâts).
func set_level(lvl: int) -> void:
	level = maxi(lvl, 1)
	max_hp = level_hp(level)
	hp = max_hp
	speed = level_speed(level)
	damage = 8.0 + level            # base : dégâts à la sphère (×0,6) et des boss
	struct_damage = level_struct_damage(level)
	player_damage = level_player_damage(level)


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
				mi.material_overlay = _frost() if is_frozen() else null
	# L'attaque ou la réaction au coup se termine avant de reprendre la marche
	if anim.is_playing() and anim.current_animation != ANIM_WALK and (attack_anim > 0.0 or hit_t > 0.0):
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if moving:
		if anim.current_animation != ANIM_WALK:
			anim.play(ANIM_WALK, 0.2)
		anim.speed_scale = speed * (_wire_slow() if traps > 0 else 1.0) * frost_speed_mult() / 2.2
	elif attack_anim <= 0.0 and anim.current_animation == ANIM_WALK:
		anim.play("Idle_Combat" if anim.has_animation("Idle_Combat") else "Idle", 0.2)


func is_frozen() -> bool:
	return frost_stacks >= 1.0


func frost_level() -> int:
	return int(floorf(frost_stacks))


## Vitesse restante selon le nombre de statuts (ex. 10 statuts, ralentissement 30 % -> 70 %).
func frost_speed_mult() -> float:
	return 1.0 - frost_max_slow * frost_level() / FROST_MAX_STACKS


func vuln_mult() -> float:
	return 1.0 + frost_max_vuln * frost_level() / FROST_MAX_STACKS


## Touché par un tic du rayon cryogénique : ajoute du statut de glace (max 10) et
## relance le compte à rebours du statut. Les valeurs max dépendent des améliorations du tireur.
func apply_frost(stack_gain: float, max_slow: float, max_vuln: float, step: float) -> void:
	frost_stacks = minf(frost_stacks + stack_gain, FROST_MAX_STACKS)
	frost_max_slow = max_slow
	frost_max_vuln = max_vuln
	frost_step = step
	frost_decay_t = step
	if is_frozen() and flash_t <= 0.0:
		for mi in meshes:
			mi.material_overlay = _frost()


static func _frost() -> StandardMaterial3D:
	if _frost_mat == null:
		_frost_mat = StandardMaterial3D.new()
		_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_frost_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.4)
	return _frost_mat


## Charge à vitesse maximale (tout le groupe quand l'un d'eux est touché).
func charge() -> void:
	if charging:
		return
	charging = true
	speed = maxf(speed, GUARD_CHARGE_SPEED)
	wake_up()


func wake_up() -> void:
	if awake:
		return
	awake = true
	attack_cd = 0.6
	if anim.has_animation("Skeletons_Awaken_Standing"):
		rise_t = 0.8
		anim.play("Skeletons_Awaken_Standing", 0.1, 1.8)
	Sfx.play_3d("groan", global_position + Vector3.UP * 1.5, 0.0, 0.9)


func take_damage(amount: float, headshot := false) -> void:
	if dead:
		return
	if guard and not summoned and not charging and main and main.has_method("alert_guards"):
		main.alert_guards(guard_group)
	if is_frozen():
		amount *= vuln_mult()
	if angel and headshot:
		amount *= 2.5      # ange : tir à la tête très efficace (×5 au total avec le ×2 de base)
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
	if main and main.has_method("wire_level"):
		return Upg.wire_slow(main.wire_level("slow"))
	return TRAP_SLOW


func _wire_dps() -> float:
	if main and main.has_method("wire_level"):
		return Upg.wire_dps(main.wire_level("damage"))
	return TRAP_DPS


## Brûlure : dps pendant t secondes (la plus forte remplace l'ancienne).
func ignite(t: float, dps: float, by) -> void:
	burn_t = t
	burn_dps = maxf(dps, burn_dps if burn_t > 0.0 else 0.0)
	burn_by = by


func knockback(v: Vector3) -> void:
	knock_vel = v
	knock_t = 0.45 if not is_boss else 0.2


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
	if main and main.has_method("drop_bones"):
		main.drop_bones(self)
	Sfx.play_3d("zdie", global_position + Vector3.UP, 0.0, 0.7 if is_boss else 1.0)
	anim.speed_scale = 1.0
	anim.play(ANIM_DEATH, 0.1, 1.4)
	var tw := create_tween()
	tw.tween_interval(1.9)
	tw.tween_property(visual, "position:y", -1.2 * size_mult, 0.9)
	tw.tween_callback(queue_free)
