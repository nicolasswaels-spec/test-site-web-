extends CharacterBody3D
## Joueur à la première personne : fusil d'assaut, hache et construction.

const Mats = preload("res://scripts/mats.gd")
const Structure = preload("res://scripts/structure.gd")

signal died

enum W { RIFLE, AXE, BUILD }
const PIECE_NAMES := ["MUR", "SOL", "RAMPE"]

const WALK_SPEED := 6.5
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MOUSE_SENS := 0.0025
const MAG_SIZE := 30
const FIRE_INTERVAL := 0.1
const RELOAD_TIME := 1.6
const RIFLE_DAMAGE := 24.0
const AXE_TREE_DAMAGE := 25.0
const AXE_ZOMBIE_DAMAGE := 45.0
const CELL := 4.0
const BUILD_COST := 10
const MAX_HP := 100.0
const MASK_SHOOT := 1 | 4 | 8 | 16 | 32

const HIP_POS := Vector3(0.24, -0.24, -0.6)
const ADS_POS := Vector3(0.0, -0.1, -0.42)
const AXE_POS := Vector3(0.34, -0.32, -0.55)

var main
var hud

var head: Node3D
var cam: Camera3D
var viewmodel: Node3D
var rifle: Node3D
var muzzle: Marker3D
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var axe: Node3D
var axe_pivot: Node3D
var ghost: MeshInstance3D
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var piece_meshes: Array[BoxMesh] = []

var weapon := W.RIFLE
var build_piece := 0
var ammo := MAG_SIZE
var reloading := false
var reload_t := 0.0
var fire_cd := 0.0
var swing_cd := 0.0
var build_cd := 0.0
var aiming := false
var recoil := 0.0
var flash_t := 0.0
var bob_t := 0.0
var equip_t := 0.0
var hp := MAX_HP
var wood := 60
var dead := false
var invuln_t := 0.0
var ghost_valid := false
var ghost_info := {}


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16 | 32
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.03
	cam.far = 500.0
	head.add_child(cam)
	cam.current = true
	viewmodel = Node3D.new()
	cam.add_child(viewmodel)

	_build_rifle()
	_build_axe()
	_build_ghost()
	_select_weapon(W.RIFLE, true)


# ------------------------------------------------------------------ modèles

func _build_rifle() -> void:
	rifle = Node3D.new()
	rifle.position = HIP_POS
	rifle.scale = Vector3.ONE * 0.82
	viewmodel.add_child(rifle)
	var body := Mats.col(Color(0.18, 0.19, 0.22), 0.5)
	var dark := Mats.col(Color(0.09, 0.09, 0.1), 0.6)
	var accent := Mats.col(Color(0.2, 0.55, 1.0), 0.4)   # "rare" bleu
	Mats.box(rifle, Vector3(0.09, 0.12, 0.5), body, Vector3(0, 0, 0))
	Mats.box(rifle, Vector3(0.05, 0.03, 0.36), dark, Vector3(0, 0.075, -0.02))
	Mats.box(rifle, Vector3(0.105, 0.095, 0.24), accent, Vector3(0, -0.005, -0.3))
	Mats.cylinder(rifle, 0.018, 0.018, 0.28, dark, Vector3(0, 0.01, -0.52), Vector3(90, 0, 0), 8)
	Mats.box(rifle, Vector3(0.065, 0.2, 0.095), dark, Vector3(0, -0.15, -0.08), Vector3(14, 0, 0))
	Mats.box(rifle, Vector3(0.055, 0.15, 0.07), body, Vector3(0, -0.12, 0.13), Vector3(-18, 0, 0))
	Mats.box(rifle, Vector3(0.075, 0.11, 0.2), accent, Vector3(0, -0.02, 0.33))
	# viseur point rouge
	Mats.box(rifle, Vector3(0.06, 0.06, 0.08), dark, Vector3(0, 0.12, 0.02))
	Mats.box(rifle, Vector3(0.012, 0.012, 0.01), Mats.col(Color(1, 0.1, 0.1), 0.2, 6.0), Vector3(0, 0.122, -0.021))
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.01, -0.68)
	rifle.add_child(muzzle)
	muzzle_flash = Mats.sphere(muzzle, 0.07, Mats.col(Color(1.0, 0.8, 0.3), 0.2, 8.0), Vector3.ZERO, 6)
	muzzle_flash.visible = false
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	muzzle_light.omni_range = 6.0
	muzzle_light.light_energy = 0.0
	muzzle.add_child(muzzle_light)


func _build_axe() -> void:
	axe = Node3D.new()
	axe.position = AXE_POS
	viewmodel.add_child(axe)
	axe_pivot = Node3D.new()
	axe.add_child(axe_pivot)
	var handle := Mats.col(Color(0.5, 0.3, 0.16))
	var metal := Mats.col(Color(0.7, 0.72, 0.78), 0.3)
	var edge := Mats.col(Color(0.92, 0.94, 1.0), 0.2)
	var grip := Mats.col(Color(0.75, 0.15, 0.15))
	var h := Node3D.new()
	h.rotation_degrees = Vector3(-25, 0, 18)
	axe_pivot.add_child(h)
	Mats.cylinder(h, 0.025, 0.03, 0.62, handle, Vector3(0, 0.18, 0), Vector3.ZERO, 8)
	Mats.cylinder(h, 0.034, 0.034, 0.14, grip, Vector3(0, -0.05, 0), Vector3.ZERO, 8)
	Mats.box(h, Vector3(0.05, 0.16, 0.22), metal, Vector3(0, 0.44, -0.09))
	Mats.box(h, Vector3(0.03, 0.22, 0.05), edge, Vector3(0, 0.44, -0.215))
	Mats.box(h, Vector3(0.06, 0.08, 0.08), metal, Vector3(0, 0.44, 0.05))


func _build_ghost() -> void:
	for s in Structure.SIZES:
		var m := BoxMesh.new()
		m.size = s
		piece_meshes.append(m)
	ghost_ok_mat = StandardMaterial3D.new()
	ghost_ok_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_ok_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.35)
	ghost_ok_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_bad_mat = ghost_ok_mat.duplicate()
	ghost_bad_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.35)
	ghost = MeshInstance3D.new()
	ghost.top_level = true
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.mesh = piece_meshes[0]
	ghost.material_override = ghost_ok_mat
	add_child(ghost)


# ------------------------------------------------------------------ entrées

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * (0.55 if aiming else 1.0)
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_weapon((weapon + 2) % 3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_weapon((weapon + 1) % 3)
	if event.is_action_pressed("weapon_1"):
		_select_weapon(W.RIFLE)
	elif event.is_action_pressed("weapon_2"):
		_select_weapon(W.AXE)
	elif event.is_action_pressed("weapon_3"):
		_select_weapon(W.BUILD)
	elif event.is_action_pressed("cycle_piece"):
		if weapon == W.BUILD:
			build_piece = (build_piece + 1) % 3
			Sfx.play("equip", -8.0)
		else:
			_select_weapon(W.BUILD)
	elif event.is_action_pressed("piece_wall"):
		_pick_piece(0)
	elif event.is_action_pressed("piece_floor"):
		_pick_piece(1)
	elif event.is_action_pressed("piece_ramp"):
		_pick_piece(2)
	elif event.is_action_pressed("reload") and weapon == W.RIFLE:
		_start_reload()


func _pick_piece(p: int) -> void:
	build_piece = p
	_select_weapon(W.BUILD)


func _select_weapon(w: int, force := false) -> void:
	if w == weapon and not force:
		return
	weapon = w
	reloading = false
	rifle.visible = w == W.RIFLE
	axe.visible = w == W.AXE
	ghost.visible = w == W.BUILD
	equip_t = 1.0
	if not force:
		Sfx.play("equip", -8.0)


# ------------------------------------------------------------------ boucle

func _physics_process(delta: float) -> void:
	invuln_t -= delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var spd := WALK_SPEED
	if Input.is_action_pressed("sprint") and input.y < 0.0 and not aiming:
		spd = SPRINT_SPEED
	if aiming:
		spd *= 0.6
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var accel := 14.0 if is_on_floor() else 4.0
	velocity.x = lerpf(velocity.x, dir.x * spd, minf(accel * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * spd, minf(accel * delta, 1.0))
	move_and_slide()

	# limites de la zone
	if main:
		var flat := Vector2(position.x, position.z)
		var lim: float = main.MAP_RADIUS - 1.5
		if flat.length() > lim:
			flat = flat.normalized() * lim
			position.x = flat.x
			position.z = flat.y
	if position.y < -30.0:
		position = Vector3(0, 2, 7)
		velocity = Vector3.ZERO

	_update_weapons(delta)


func _update_weapons(delta: float) -> void:
	fire_cd -= delta
	swing_cd -= delta
	build_cd -= delta
	aiming = Input.is_action_pressed("aim") and weapon == W.RIFLE and not reloading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			ammo = MAG_SIZE

	var firing := Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	match weapon:
		W.RIFLE:
			if firing and fire_cd <= 0.0 and not reloading:
				if ammo > 0:
					_shoot()
				else:
					_start_reload()
		W.AXE:
			if firing and swing_cd <= 0.0:
				_swing()
		W.BUILD:
			_update_ghost()
			if firing and build_cd <= 0.0:
				_place()


func _process(delta: float) -> void:
	# Animations de l'arme en main (balancement, recul, visée)
	cam.fov = lerpf(cam.fov, 55.0 if aiming else 80.0, minf(14.0 * delta, 1.0))
	var speed2 := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed2 > 0.5:
		bob_t += delta * speed2 * 1.6
	var bob := Vector3(sin(bob_t) * 0.012, -absf(cos(bob_t)) * 0.014, 0.0) * (0.25 if aiming else 1.0)
	equip_t = maxf(equip_t - delta * 4.0, 0.0)
	recoil = lerpf(recoil, 0.0, minf(14.0 * delta, 1.0))
	var equip_off := Vector3(0, -0.35 * equip_t * equip_t, 0)

	var target_pos := ADS_POS if aiming else HIP_POS
	var target_rot := Vector3.ZERO
	if reloading:
		target_pos = HIP_POS + Vector3(-0.05, -0.08, 0.05)
		target_rot = Vector3(-0.5, 0.3, 0.5)
	rifle.position = rifle.position.lerp(target_pos + bob + equip_off + Vector3(0, 0, recoil * 0.06), minf(16.0 * delta, 1.0))
	rifle.rotation = rifle.rotation.lerp(target_rot + Vector3(recoil * 0.1, 0, 0), minf(14.0 * delta, 1.0))
	axe.position = AXE_POS + bob * 1.5 + equip_off

	flash_t -= delta
	muzzle_flash.visible = flash_t > 0.0
	muzzle_light.light_energy = 3.0 if flash_t > 0.0 else 0.0
	if muzzle_flash.visible:
		muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.6)


# ------------------------------------------------------------------ fusil

func _start_reload() -> void:
	if reloading or ammo >= MAG_SIZE:
		return
	reloading = true
	reload_t = RELOAD_TIME
	Sfx.play("reload", -2.0)


func _shoot() -> void:
	ammo -= 1
	fire_cd = FIRE_INTERVAL
	flash_t = 0.04
	recoil = 1.0
	Sfx.play("shot", -5.0)

	var spread := 0.004 if aiming else 0.022
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		spread += 0.012
	if not is_on_floor():
		spread += 0.03
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * randf_range(-spread, spread) + b.y * randf_range(-spread, spread)).normalized()
	var from := cam.global_position
	var to := from + dir * 250.0
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SHOOT)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not r.is_empty():
		end = r.position
		var c = r.collider
		if c and c.is_in_group("zombie"):
			var is_head: bool = r.position.y > c.global_position.y + c.head_height
			c.take_damage(RIFLE_DAMAGE * (2.0 if is_head else 1.0), is_head)
			if hud:
				hud.hitmarker(is_head)
			Sfx.play("headshot" if is_head else "hit", -6.0)
			main.spawn_impact(end, r.normal, Color(0.35, 0.85, 0.2), 10, 1.0)
		else:
			main.spawn_impact(end, r.normal, Color(1.0, 0.85, 0.55), 6, 0.6)
	main.spawn_tracer(muzzle.global_position, end)

	head.rotation.x = clampf(head.rotation.x + (0.005 if aiming else 0.011), -1.5, 1.5)
	rotate_y(randf_range(-0.004, 0.004))


# ------------------------------------------------------------------ hache

func _swing() -> void:
	swing_cd = 0.5
	Sfx.play("swing", -6.0)
	var tw := create_tween()
	tw.tween_property(axe_pivot, "rotation", Vector3(-1.3, 0.35, 0.5), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(axe_pivot, "rotation", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.11, false).timeout.connect(_axe_impact)


func _axe_impact() -> void:
	if dead or weapon != W.AXE:
		return
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 3.3
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8 | 16 | 32)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var c = r.collider
	if c and c.is_in_group("tree"):
		var gained: int = c.chop(AXE_TREE_DAMAGE)
		wood = mini(wood + gained, 999)
		if hud and gained > 0:
			hud.wood_gain(gained)
		main.spawn_impact(r.position, r.normal, Color(0.65, 0.45, 0.25), 10, 1.0)
	elif c and c.is_in_group("zombie"):
		c.take_damage(AXE_ZOMBIE_DAMAGE, false)
		if hud:
			hud.hitmarker(false)
		Sfx.play("thud", 0.0)
		main.spawn_impact(r.position, r.normal, Color(0.35, 0.85, 0.2), 12, 1.0)
	else:
		Sfx.play("thud", -4.0)
		main.spawn_impact(r.position, r.normal, Color(0.8, 0.8, 0.8), 6, 0.6)


# ------------------------------------------------------------------ construction

func _compute_build() -> Dictionary:
	var fwd := -cam.global_transform.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	if flat.length() < 0.05:
		flat = -global_transform.basis.z
	flat = flat.normalized()
	var d := Vector3(signf(flat.x), 0, 0) if absf(flat.x) > absf(flat.z) else Vector3(0, 0, signf(flat.z))
	var pitch := head.rotation.x
	var level := floori((global_position.y + 0.6) / CELL)
	var xf := Transform3D()
	var key := ""
	match build_piece:
		0:  # mur, sur l'arête de la case devant soi
			if pitch > 0.6:
				level += 1
			var p := global_position + flat * 1.2
			var cx := floori(p.x / CELL)
			var cz := floori(p.z / CELL)
			var c := Vector3((cx + 0.5) * CELL, level * CELL + CELL * 0.5, (cz + 0.5) * CELL) + d * CELL * 0.5
			var bs := Basis() if d.x == 0.0 else Basis(Vector3.UP, PI * 0.5)
			xf = Transform3D(bs, c)
			key = "W%d_%d_%d" % [roundi(c.x * 0.5), level, roundi(c.z * 0.5)]
		1:  # sol
			if pitch > 0.35:
				level += 1
			var p := global_position + flat * (0.0 if pitch < -0.9 else 2.6)
			var cx := floori(p.x / CELL)
			var cz := floori(p.z / CELL)
			var c := Vector3((cx + 0.5) * CELL, level * CELL, (cz + 0.5) * CELL)
			xf = Transform3D(Basis(), c)
			key = "F%d_%d_%d" % [cx, level, cz]
		2:  # rampe qui monte dans la direction du regard
			if pitch > 0.6:
				level += 1
			var p := global_position + flat * 2.6
			var cx := floori(p.x / CELL)
			var cz := floori(p.z / CELL)
			var c := Vector3((cx + 0.5) * CELL, level * CELL + CELL * 0.5, (cz + 0.5) * CELL)
			var z_axis := (d + Vector3.UP).normalized()
			var x_axis := Vector3.UP.cross(d).normalized()
			var y_axis := z_axis.cross(x_axis)
			xf = Transform3D(Basis(x_axis, y_axis, z_axis), c)
			key = "R%d_%d_%d" % [cx, level, cz]
	return {"xform": xf, "key": key}


func _update_ghost() -> void:
	ghost_info = _compute_build()
	ghost.mesh = piece_meshes[build_piece]
	ghost.global_transform = ghost_info["xform"]
	ghost_valid = wood >= BUILD_COST and not main.structures.has(ghost_info["key"])
	ghost.material_override = ghost_ok_mat if ghost_valid else ghost_bad_mat


func _place() -> void:
	if ghost_info.is_empty():
		return
	if not ghost_valid:
		if wood < BUILD_COST and hud:
			hud.flash_message("Pas assez de bois ! Coupe des arbres (2)")
		build_cd = 0.4
		return
	wood -= BUILD_COST
	build_cd = 0.15
	main.place_structure(build_piece, ghost_info["xform"], ghost_info["key"])


# ------------------------------------------------------------------ santé

func take_damage(amount: float) -> void:
	if dead or invuln_t > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	Sfx.play("hurt", 0.0)
	if hud:
		hud.damage_flash()
	if hp <= 0.0:
		dead = true
		ghost.visible = false
		viewmodel.visible = false
		var tw := create_tween()
		tw.tween_property(head, "position:y", 0.35, 0.5)
		tw.parallel().tween_property(head, "rotation:z", 0.6, 0.5)
		died.emit()


func respawn(pos: Vector3) -> void:
	dead = false
	invuln_t = 3.0
	hp = MAX_HP
	ammo = MAG_SIZE
	reloading = false
	position = pos
	velocity = Vector3.ZERO
	head.position.y = 1.6
	head.rotation = Vector3.ZERO
	viewmodel.visible = true
	_select_weapon(weapon, true)
