extends StaticBody3D
## Titan de lave : boss géant et immobile de la zone volcanique (squelette guerrier KayKit
## agrandi, recouvert de lave). Énormément de PV. Trois attaques :
##   1. Boules de feu : salves tirées sur les joueurs ; elles explosent sur les constructions
##      (s'abriter derrière un mur fonctionne, mais le mur encaisse).
##   2. Onde de choc : il frappe le sol, un anneau de feu s'étend ; sauter ou être en hauteur
##      l'évite, un mur entre lui et toi la bloque.
##   3. Éruptions : des cercles rouges apparaissent sous les joueurs, puis la lave jaillit.
##   4. Invocation : des squelettes sortent de terre autour de lui et traquent les joueurs.
## Sous 50 % de PV, il enchaîne plus vite et tire davantage.
## Il est dans le groupe « zombie » pour que les armes, le viseur et la mini-carte le gèrent.

const Mats = preload("res://scripts/mats.gd")
const MODEL := preload("res://assets/skeletons/Skeleton_Warrior.glb")
const MODEL_HEIGHT := 2.17
const HEIGHT := 10.5
const BASE_HP := 30000.0
const COOP_HP_MULT := 1.6
const RANGE := 75.0              # il n'attaque que les joueurs à cette distance
const FIREBALL_SPEED := 24.0
const FIREBALL_DAMAGE := 22.0
const FIREBALL_STRUCT_DAMAGE := 260.0
const SLAM_DAMAGE := 32.0
const SLAM_SPEED := 17.0
const SLAM_MAX_R := 62.0
const ERUPT_DAMAGE := 40.0
const ERUPT_STRUCT_DAMAGE := 450.0
const ERUPT_RADIUS := 2.8
const ERUPT_WARN := 1.6
const FROST_MAX_STACKS := 10.0
const SUMMON_COUNT := 3          # 5 sous 50 % de PV
const SUMMON_MAX_ALIVE := 8
const ZombieScript = preload("res://scripts/zombie.gd")

signal defeated

var main
var max_hp := BASE_HP
var hp := BASE_HP
var kind := "titan"
var is_boss := true
var guard := false
var charging := false
var dead := false
var size_mult := 4.0
var head_height := 8.4
var awake := false
var attack_cd := 3.0
var last_attack := -1
var busy_t := 0.0
var visual: Node3D
var anim: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var flash_t := 0.0
var frost_stacks := 0.0
var frost_max_vuln := 0.1
var frost_decay_t := 0.0
var frost_step := 1.0
var target: Node3D
static var _lava_mat: StandardMaterial3D
static var _flash_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("zombie")
	add_to_group("titan")
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.9
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	var model := MODEL.instantiate() as Node3D
	model.rotation.y = PI
	model.scale = Vector3.ONE * HEIGHT / MODEL_HEIGHT
	visual.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for n in ["Idle_Combat", "Spellcasting"]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
		mi.material_overlay = _lava()
		if mi.name.ends_with("_Eyes"):
			mi.material_override = Mats.col(Color(1.0, 0.5, 0.1), 0.3, 8.0)
	anim.play("Skeleton_Inactive_Standing_Pose" if anim.has_animation("Skeleton_Inactive_Standing_Pose") else "Idle")
	# socle de basalte fissuré + lueur
	var rock := Mats.col(Color(0.12, 0.09, 0.09), 1.0)
	Mats.cylinder(self, 3.6, 4.6, 0.8, rock, Vector3(0, 0.1, 0), Vector3.ZERO, 10)
	Mats.cylinder(self, 3.9, 3.9, 0.12, Mats.col(Color(1.0, 0.4, 0.08), 0.5, 3.0), Vector3(0, 0.05, 0), Vector3.ZERO, 24)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.15)
	l.light_energy = 4.0
	l.omni_range = 22.0
	l.position = Vector3(0, 6.0, 1.5)
	add_child(l)
	# braises qui s'échappent du corps
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.6, HEIGHT * 0.4, 1.0)
	p.position.y = HEIGHT * 0.55
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 1.0, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.8
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.15)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(1.0, 0.55, 0.15)
	q.material = pm
	p.mesh = q
	add_child(p)


static func _lava() -> StandardMaterial3D:
	if _lava_mat == null:
		_lava_mat = StandardMaterial3D.new()
		_lava_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lava_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_lava_mat.albedo_color = Color(0.55, 0.13, 0.02)
	return _lava_mat


static func _flash() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_color = Color(1, 1, 1, 0.5)
	return _flash_mat


## Réveil (joueur proche ou fin du compte à rebours).
func wake() -> void:
	if awake or dead:
		return
	awake = true
	attack_cd = 3.5
	busy_t = 2.5
	if anim.has_animation("Skeletons_Awaken_Standing"):
		anim.play("Skeletons_Awaken_Standing", 0.1, 1.2)
		anim.queue("Taunt")
		anim.queue("Idle_Combat")
	Sfx.play("horn", 0.0, 0.6)
	if main:
		main.spawn_impact(global_position + Vector3.UP, Vector3.UP, Color(1.0, 0.4, 0.1), 40, 3.0)


func _process(delta: float) -> void:
	if dead:
		return
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			for mi in meshes:
				mi.material_overlay = _lava()
	if frost_stacks > 0.0:
		frost_decay_t -= delta
		if frost_decay_t <= 0.0:
			frost_stacks = maxf(frost_stacks - 1.0, 0.0)
			frost_decay_t = frost_step
	if not awake:
		return
	target = _pick_target()
	if target:
		# se tourne lentement vers sa cible
		var d: Vector3 = target.global_position - global_position
		var want := atan2(-d.x, -d.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, want + PI, minf(delta * 1.5, 1.0))
	busy_t -= delta
	attack_cd -= delta
	if busy_t <= 0.0 and not anim.is_playing():
		anim.play("Idle_Combat", 0.2)
	if attack_cd <= 0.0 and busy_t <= 0.0 and target:
		_attack()


func _pick_target() -> Node3D:
	var best: Node3D = null
	var bd := RANGE
	if main == null:
		return null
	for p in main.players:
		if p.dead:
			continue
		var d: float = p.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = p
	return best


func phase2() -> bool:
	return hp < max_hp * 0.5


func _attack() -> void:
	var near: bool = target.global_position.distance_to(global_position) < 14.0
	var choice := randi() % 4
	if near and randf() < 0.6:
		choice = 1
	if choice == 3 and _summoned_alive() >= SUMMON_MAX_ALIVE:
		choice = randi() % 3
	if choice == last_attack:
		choice = (choice + 1 + randi() % 3) % 4
		if choice == 3 and _summoned_alive() >= SUMMON_MAX_ALIVE:
			choice = 0
	last_attack = choice
	attack_cd = (2.0 if phase2() else 3.0) + randf_range(0.0, 1.0)
	match choice:
		0: _fireballs()
		1: _slam()
		2: _eruptions()
		3: _summon()


# ------------------------------------------------------------------ attaque 1 : boules de feu

func _fireballs() -> void:
	busy_t = 1.6
	anim.play("Spellcast_Shoot" if anim.has_animation("Spellcast_Shoot") else "1H_Ranged_Shoot", 0.15, 0.9)
	var n := 5 if phase2() else 3
	var tw := create_tween()
	tw.tween_interval(0.55)
	for i in n:
		tw.tween_callback(_launch_fireball)
		tw.tween_interval(0.22)


func _launch_fireball() -> void:
	if dead or main == null:
		return
	var t := _pick_target()
	if t == null:
		return
	var fwd := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var from := global_position + Vector3.UP * (HEIGHT * 0.72) + fwd * 1.8
	var aim: Vector3 = t.global_position + Vector3.UP * 1.0
	var tv: Vector3 = t.velocity if "velocity" in t else Vector3.ZERO
	aim += tv * (from.distance_to(aim) / FIREBALL_SPEED) * 0.6
	aim += Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 0.8), randf_range(-1.5, 1.5))
	var fb := Fireball.new()
	fb.main = main
	fb.velocity = (aim - from).normalized() * FIREBALL_SPEED
	main.add_child(fb)
	fb.global_position = from
	Sfx.play_3d("orb_hit", from, 4.0, 0.5)


class Fireball extends Node3D:
	var main
	var velocity := Vector3.ZERO
	var life := 5.0

	func _ready() -> void:
		Mats.sphere(self, 0.55, Mats.col(Color(1.0, 0.45, 0.1), 0.5, 6.0), Vector3.ZERO, 10)
		Mats.sphere(self, 0.85, _halo(), Vector3.ZERO, 10)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.15)
		l.light_energy = 3.0
		l.omni_range = 7.0
		add_child(l)

	static func _halo() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(0.6, 0.18, 0.03)
		return m

	func _physics_process(delta: float) -> void:
		life -= delta
		var from := global_position
		var to := from + velocity * delta
		# joueurs touchés directement
		for p in main.players:
			if not p.dead and _seg_dist(from, to, p.global_position + Vector3.UP) < 1.2:
				p.take_damage(FIREBALL_DAMAGE)
				_explode(to, null)
				return
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			var c = r.collider
			if c and c.has_meta("structure"):
				c = c.get_meta("structure")
			_explode(r.position, c if (c and is_instance_valid(c) and c.is_in_group("structure")) else null)
			return
		global_position = to
		if life <= 0.0 or to.y < -2.0:
			queue_free()

	func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return (a + ab * t).distance_to(p)

	func _explode(pos: Vector3, structure) -> void:
		if structure:
			structure.take_damage(FIREBALL_STRUCT_DAMAGE)
		# éclaboussures
		for p in main.players:
			if not p.dead and p.global_position.distance_to(pos) < 2.6:
				p.take_damage(FIREBALL_DAMAGE * 0.5)
		main.spawn_impact(pos, Vector3.UP, Color(1.0, 0.45, 0.1), 18, 1.6)
		Sfx.play_3d("break", pos, 0.0, 1.5)
		queue_free()


# ------------------------------------------------------------------ attaque 2 : onde de choc

func _slam() -> void:
	busy_t = 2.0
	anim.play("2H_Melee_Attack_Chop" if anim.has_animation("2H_Melee_Attack_Chop") else "1H_Melee_Attack_Chop", 0.15, 0.7)
	var tw := create_tween()
	tw.tween_interval(0.95)
	tw.tween_callback(_spawn_shockwave)
	if phase2():
		tw.tween_interval(1.1)
		tw.tween_callback(_spawn_shockwave)


func _spawn_shockwave() -> void:
	if dead or main == null:
		return
	var sw := Shockwave.new()
	sw.main = main
	sw.center = global_position
	main.add_child(sw)
	sw.global_position = global_position + Vector3.UP * 0.3
	Sfx.play_3d("break", global_position, 8.0, 0.4)
	main.spawn_impact(global_position + Vector3.UP * 0.5, Vector3.UP, Color(0.35, 0.25, 0.2), 40, 3.0)


class Shockwave extends Node3D:
	var main
	var center := Vector3.ZERO
	var r := 4.0
	var hit := {}
	var ring: MeshInstance3D

	func _ready() -> void:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.93
		tm.outer_radius = 1.0
		tm.rings = 96
		tm.ring_segments = 6
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.4, 0.08)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_update_ring()

	func _update_ring() -> void:
		ring.scale = Vector3(r, 8.0, r)

	func _physics_process(delta: float) -> void:
		r += SLAM_SPEED * delta
		_update_ring()
		for p in main.players:
			if p.dead or hit.has(p):
				continue
			var d := Vector2(p.global_position.x - center.x, p.global_position.z - center.z).length()
			if absf(d - r) < 1.3:
				hit[p] = true
				# sauter ou être en hauteur évite l'onde ; un mur entre le titan et toi la bloque
				if p.global_position.y > 0.9 or not p.is_on_floor():
					continue
				var q := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.6, p.global_position + Vector3.UP * 0.6, 8)
				if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					continue
				p.take_damage(SLAM_DAMAGE)
				var push := Vector3(p.global_position.x - center.x, 0, p.global_position.z - center.z).normalized()
				p.velocity += push * 9.0 + Vector3.UP * 6.0
		if r > SLAM_MAX_R:
			queue_free()


# ------------------------------------------------------------------ attaque 3 : éruptions

func _eruptions() -> void:
	busy_t = 1.8
	anim.play("Spellcast_Raise" if anim.has_animation("Spellcast_Raise") else "Spellcast_Summon", 0.15, 1.0)
	var per := 5 if phase2() else 3
	for p in main.players:
		if p.dead or p.global_position.distance_to(global_position) > RANGE:
			continue
		for i in per:
			var off := Vector3.ZERO
			if i > 0:
				var a := randf() * TAU
				off = Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 7.0)
			var pos: Vector3 = p.global_position + off
			pos.y = 0.0
			if Vector2(pos.x - global_position.x, pos.z - global_position.z).length() < 5.0:
				continue
			var e := Eruption.new()
			e.main = main
			e.delay = ERUPT_WARN + i * 0.15
			main.add_child(e)
			e.global_position = main.clamp_to_area(pos)


class Eruption extends Node3D:
	var main
	var delay := 1.6
	var t := 0.0
	var warn: MeshInstance3D
	var warn_mat: StandardMaterial3D
	var done := false

	func _ready() -> void:
		warn_mat = StandardMaterial3D.new()
		warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		warn_mat.albedo_color = Color(1.0, 0.15, 0.05, 0.35)
		warn = Mats.cylinder(self, ERUPT_RADIUS, ERUPT_RADIUS, 0.05, warn_mat, Vector3(0, 0.06, 0), Vector3.ZERO, 24)
		warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(delta: float) -> void:
		t += delta
		if not done:
			warn_mat.albedo_color.a = 0.25 + 0.3 * (0.5 + 0.5 * sin(t * (8.0 + t * 10.0)))
			if t >= delay:
				_erupt()
		elif t > delay + 0.9:
			queue_free()

	func _erupt() -> void:
		done = true
		warn.visible = false
		var col := Mats.cylinder(self, ERUPT_RADIUS * 0.7, ERUPT_RADIUS, 9.0, Mats.col(Color(1.0, 0.4, 0.05), 0.5, 5.0), Vector3(0, 4.5, 0), Vector3.ZERO, 12)
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		col.scale = Vector3(1, 0.05, 1)
		var tw := create_tween()
		tw.tween_property(col, "scale", Vector3(1, 1, 1), 0.15)
		tw.tween_interval(0.35)
		tw.tween_property(col, "scale", Vector3(0.2, 1.0, 0.2), 0.3)
		var pos := global_position
		for p in main.players:
			if p.dead:
				continue
			var d := Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
			if d < ERUPT_RADIUS and p.global_position.y < 3.5:
				p.take_damage(ERUPT_DAMAGE)
				p.velocity.y = 9.0
		for st in main.structures.values():
			if is_instance_valid(st) and st.global_position.distance_to(pos + Vector3.UP) < ERUPT_RADIUS + 1.5:
				st.take_damage(ERUPT_STRUCT_DAMAGE)
		main.spawn_impact(pos + Vector3.UP * 0.5, Vector3.UP, Color(1.0, 0.45, 0.1), 26, 2.2)
		Sfx.play_3d("break", pos, 3.0, 0.6)


# ------------------------------------------------------------------ attaque 4 : invocation

func _summoned_alive() -> int:
	var n := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if z != self and z.get("summoned"):
			n += 1
	return n


func _summon() -> void:
	busy_t = 2.0
	anim.play("Spellcast_Summon" if anim.has_animation("Spellcast_Summon") else "Spellcast_Raise", 0.15, 0.9)
	Sfx.play("horn", -4.0, 0.8)
	var n := mini(SUMMON_COUNT + (2 if phase2() else 0), SUMMON_MAX_ALIVE - _summoned_alive())
	var base := randf() * TAU
	for i in n:
		var z := ZombieScript.new()
		z.summoned = true
		z.guard = true            # traque les joueurs, ignore les sphères
		z.max_hp = 260.0
		z.hp = z.max_hp
		z.speed = 3.4
		z.damage = 14.0
		z.main = main
		z.orb = main.orb
		var a := base + TAU * i / n + randf_range(-0.3, 0.3)
		z.position = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 9.0) + Vector3(0, 0.05, 0)
		main.add_child(z)
		main.spawn_impact(z.position + Vector3.UP * 0.3, Vector3.UP, Color(1.0, 0.4, 0.1), 14, 1.2)


## Les squelettes invoqués s'effondrent avec leur maître.
func _kill_summons() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if z != self and z.get("summoned") and not z.dead:
			z.take_damage(99999.0)


# ------------------------------------------------------------------ dégâts / glace

func take_damage(amount: float, _headshot := false) -> void:
	if dead:
		return
	if not awake:
		wake()
	if is_frozen():
		amount *= vuln_mult()
	hp -= amount
	flash_t = 0.06
	for mi in meshes:
		mi.material_overlay = _flash()
	if hp <= 0.0:
		die()


func knockback(_v: Vector3) -> void:
	pass   # immobile


func is_frozen() -> bool:
	return frost_stacks >= 1.0


func frost_level() -> int:
	return int(floorf(frost_stacks))


func vuln_mult() -> float:
	return 1.0 + frost_max_vuln * frost_level() / FROST_MAX_STACKS


## Le rayon cryogénique rend le titan vulnérable (il est immobile : pas de ralentissement).
func apply_frost(stack_gain: float, _max_slow: float, max_vuln: float, step: float) -> void:
	frost_stacks = minf(frost_stacks + stack_gain, FROST_MAX_STACKS)
	frost_max_vuln = max_vuln
	frost_step = step
	frost_decay_t = step


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	remove_from_group("zombie")
	collision_layer = 0
	_kill_summons()
	for mi in meshes:
		mi.material_overlay = _lava()
	anim.play("Death_A" if anim.has_animation("Death_A") else "Death_C_Skeletons", 0.1, 0.6)
	Sfx.play("win")
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func():
		if main:
			main.spawn_impact(global_position + Vector3.UP * 2.0, Vector3.UP, Color(1.0, 0.45, 0.1), 60, 4.0))
	tw.tween_property(visual, "position:y", -HEIGHT * 0.6, 2.0)
	tw.tween_callback(queue_free)
	defeated.emit()
