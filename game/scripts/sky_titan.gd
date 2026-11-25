extends "res://scripts/titan.gd"
## Colosse des nuées : boss de l'île céleste, avant la 4e sphère. Squelette géant immobile
## (il se tourne vers sa cible), le corps rempli et couvert de nuages. Quatre attaques :
##   1. Grêle : grêlons lents tirés sur le joueur visé (comme les boules de feu du titan).
##   2. Éclairs : cercles bleus sous le joueur visé, puis la foudre tombe 2,2 s après.
##   3. Bourrasque : un mur de vent part vers le joueur visé ; il repousse fort et blesse un peu.
##      Un mur construit entre le colosse et toi l'arrête.
##   4. Tempête (UNIQUEMENT sous 30 % de PV) : pendant 6 s, la foudre tombe partout autour des joueurs.
## Il invoque aussi 2 anges squelettes, rarement (toutes les ~35 s, 4 au maximum en vie).
## À sa mort : 3 tas d'os imposants.

const SKY_HP := 45000.0
const WIND_SPEED := 9.0
const WIND_DAMAGE := 14.0
const WIND_PUSH := 15.0
const STORM_TIME := 6.0
const ANGEL_EVERY := 35.0
const ANGEL_MAX := 4

var angel_cd := 25.0
var storm_t := 0.0
var storm_tick := 0.0
static var _cloud_skin: StandardMaterial3D


func _init() -> void:
	kind = "sky_titan"
	max_hp = SKY_HP
	hp = SKY_HP


func _skin() -> StandardMaterial3D:
	if _cloud_skin == null:
		_cloud_skin = StandardMaterial3D.new()
		_cloud_skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cloud_skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_cloud_skin.albedo_color = Color(0.22, 0.28, 0.42)
	return _cloud_skin


func _eye_color() -> Color:
	return Color(0.55, 0.85, 1.0)


func _tint() -> Color:
	return Color(0.7, 0.88, 1.0)


## Socle de nuage, nuages accrochés au corps (épaules, tête, cage thoracique), brume et lumière froide.
func _decorate(model: Node3D) -> void:
	var cm := Mats.col(Color(0.9, 0.93, 1.0), 1.0, 0.25)
	var shade := Mats.col(Color(0.72, 0.78, 0.95), 1.0, 0.15)
	for i in 10:
		var a := TAU * i / 10.0
		Mats.sphere(self, randf_range(1.4, 2.2), cm if i % 3 else shade, Vector3(cos(a) * 3.6, 0.2, sin(a) * 3.6), 10).scale = Vector3(1, 0.6, 1)
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		for bone in [["chest", 0.55, 5], ["head", 0.45, 4], ["upperarm.l", 0.35, 3], ["upperarm.r", 0.35, 3], ["hips", 0.4, 3]]:
			var ba := BoneAttachment3D.new()
			ba.bone_name = bone[0]
			sk.add_child(ba)
			for k in bone[2]:
				var off := Vector3(randf_range(-0.25, 0.25), randf_range(-0.1, 0.35), randf_range(-0.2, 0.2))
				Mats.sphere(ba, bone[1] * randf_range(0.6, 1.0), cm if k % 2 == 0 else shade, off, 8)
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.85, 1.0)
	l.light_energy = 3.0
	l.omni_range = 24.0
	l.position = Vector3(0, 7.0, 2.0)
	add_child(l)
	# brume qui s'échappe du corps
	var p := CPUParticles3D.new()
	p.amount = 50
	p.lifetime = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.8, HEIGHT * 0.4, 1.2)
	p.position.y = HEIGHT * 0.55
	p.direction = Vector3.UP
	p.spread = 40.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = Color(0.92, 0.95, 1.0, 0.5)
	q.material = pm
	p.mesh = q
	add_child(p)


func low_hp() -> bool:
	return hp < max_hp * 0.3


func _process(delta: float) -> void:
	super._process(delta)
	if dead or not awake:
		return
	# invocation d'anges : rare, indépendante des autres attaques
	angel_cd -= delta
	if angel_cd <= 0.0:
		angel_cd = ANGEL_EVERY + randf_range(0.0, 8.0)
		_summon_angels()
	# tempête en cours
	if storm_t > 0.0:
		storm_t -= delta
		storm_tick -= delta
		if storm_tick <= 0.0:
			storm_tick = 0.35
			for pl in main.players:
				if pl.dead:
					continue
				var a := randf() * TAU
				var pos: Vector3 = pl.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 9.0)
				_make_eruption(pos, 1.6, true)


func _attack() -> void:
	attack_target = _pick_attack_target()
	if attack_target == null:
		return
	var choices := [0, 1, 2]
	if low_hp() and storm_t <= 0.0:
		choices.append(3)
		choices.append(3)   # sous 30 % : la tempête revient souvent
	var choice: int = choices[randi() % choices.size()]
	if choice == last_attack and choice != 3:
		choice = (choice + 1) % 3
	last_attack = choice
	attack_cd = (4.0 if phase2() else 5.5) + randf_range(0.0, 1.5)
	match choice:
		0: _fireballs()       # grêle (projectiles de la couleur du colosse)
		1: _lightning()
		2: _gust()
		3: _storm()


## Éclairs ciblés : 3 (4 sous 50 %) cercles autour du joueur visé.
func _lightning() -> void:
	busy_t = 2.4
	anim.play("Spellcast_Raise" if anim.has_animation("Spellcast_Raise") else "Spellcast_Summon", 0.15, 0.8)
	var per := 4 if phase2() else 3
	for i in per:
		var off := Vector3.ZERO
		if i > 0:
			var a := randf() * TAU
			off = Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 7.0)
		_make_eruption(attack_target.global_position + off, ERUPT_WARN + i * 0.2, true)


## Bourrasque : mur de vent lancé vers le joueur visé.
func _gust() -> void:
	busy_t = 2.2
	anim.play("2H_Melee_Attack_Slice" if anim.has_animation("2H_Melee_Attack_Slice") else "1H_Melee_Attack_Chop", 0.15, 0.6)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(_launch_gust)


func _launch_gust() -> void:
	if dead or main == null or not is_instance_valid(attack_target):
		return
	var d: Vector3 = attack_target.global_position - global_position
	d.y = 0.0
	var g := Gust.new()
	g.main = main
	g.origin = global_position
	g.dir = d.normalized()
	main.add_child(g)
	g.global_position = global_position + g.dir * 4.0 + Vector3.UP * 0.1
	Sfx.play_3d("orb_hit", global_position, 6.0, 0.4)


## Tempête : uniquement sous 30 % de PV.
func _storm() -> void:
	busy_t = 2.0
	storm_t = STORM_TIME
	storm_tick = 0.6
	anim.play("Spellcasting" if anim.has_animation("Spellcasting") else "Spellcast_Long", 0.2, 1.0)
	if main:
		main.hud.flash_message("LA TEMPÊTE SE DÉCHAÎNE !")
	Sfx.play("horn", -2.0, 1.3)


## 2 anges squelettes autour de lui (4 au maximum en vie).
func _summon_angels() -> void:
	var alive := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if z != self and z.get("summoned") and z.get("angel"):
			alive += 1
	var n := mini(2, ANGEL_MAX - alive)
	if n <= 0:
		return
	anim.play("Spellcast_Summon" if anim.has_animation("Spellcast_Summon") else "Spellcast_Raise", 0.15, 0.9)
	busy_t = maxf(busy_t, 1.8)
	main.hud.flash_message("LE COLOSSE APPELLE DES ANGES !")
	for i in n:
		var z := ZombieScript.new()
		z.summoned = true
		z.archer = true
		z.angel = true
		z.set_level(30)
		z.max_hp *= 4.0
		z.hp = z.max_hp
		z.main = main
		z.orb = main.orb
		var a := randf() * TAU
		z.position = global_position + Vector3(cos(a), 0, sin(a)) * 8.0 + Vector3(0, 8.0, 0)
		main.add_child(z)
		main.spawn_impact(z.position, Vector3.UP, Color(0.9, 0.95, 1.0), 20, 1.6)


func _drop_loot() -> void:
	for i in 3:
		var a := TAU * i / 3.0
		main.spawn_resource_drop("bone_pile", 1, global_position + Vector3(cos(a), 0, sin(a)) * 6.0, null)


class Gust extends Node3D:
	var main
	var origin := Vector3.ZERO
	var dir := Vector3.FORWARD
	var dist := 4.0
	var hit := {}
	var band: MeshInstance3D
	var mat: StandardMaterial3D

	func _ready() -> void:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.7, 0.8, 1.0, 0.6)
		band = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(14.0, 3.5, 0.6)
		band.mesh = bm
		band.material_override = mat
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		band.position.y = 1.75
		add_child(band)
		look_at(global_position + dir, Vector3.UP)

	func _physics_process(delta: float) -> void:
		dist += WIND_SPEED * delta
		global_position = Vector3(origin.x, global_position.y, origin.z) + dir * dist
		mat.albedo_color.a = 0.35 + 0.25 * sin(dist * 2.0)
		var right := dir.cross(Vector3.UP).normalized()
		for p in main.players:
			if p.dead or hit.has(p):
				continue
			var rel: Vector3 = p.global_position - global_position
			if absf(rel.dot(dir)) < 1.0 and absf(rel.dot(right)) < 7.0 and rel.y < 4.0 and rel.y > -2.0:
				hit[p] = true
				# un mur entre le colosse et toi arrête le vent
				var q := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 1.0, p.global_position + Vector3.UP * 1.0, 8)
				if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					continue
				p.take_damage(WIND_DAMAGE)
				p.velocity += dir * WIND_PUSH + Vector3.UP * 5.0
		if dist > 70.0:
			queue_free()
