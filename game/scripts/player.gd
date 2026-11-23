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
const MAT_NAMES := ["BOIS", "PIERRE"]
const MAX_HP := 100.0
const MASK_SHOOT := 1 | 4 | 8 | 16 | 32

const HIP_POS := Vector3(0.25, -0.22, -0.64)
const ADS_POS := Vector3(0.0, -0.105, -0.40)
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
var sprint_toggle := false
const STICK_LOOK_SPEED := 3.2
var rifle_rest_rot := Vector3.ZERO
var flash_t := 0.0
var bob_t := 0.0
var equip_t := 0.0
var hp := MAX_HP
var wood := 60
var stone := 0
var build_mat := 0   # 0 bois, 1 pierre
var build_target = null
var crystal_mat: StandardMaterial3D
var sight_glow: OmniLight3D
var ads_t := 0.0
var shake_t := 0.0
var shake_amp := 0.0
var swinging := false
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

const WOOD_SHADER := """
shader_type spatial;
uniform vec3 light_wood : source_color = vec3(0.55, 0.30, 0.16);
uniform vec3 dark_wood : source_color = vec3(0.26, 0.12, 0.07);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float grain = sin(lp.z * 9.0 + sin(lp.y * 60.0 + lp.x * 40.0) * 1.6) * 0.5 + 0.5;
	float rings = smoothstep(0.55, 1.0, sin((lp.y * 80.0 + lp.x * 50.0) + lp.z * 6.0) * 0.5 + 0.5);
	ALBEDO = mix(dark_wood, light_wood, grain * 0.7 + 0.15) * (1.0 - rings * 0.25);
	ROUGHNESS = 0.55;
	SPECULAR = 0.4;
}
"""


## Fusil d'assaut dans l'esprit « forêt au crépuscule » : bois sculpté, acier bleui,
## laiton, cuir, et un cristal turquoise lumineux qui rappelle la sphère.
func _build_rifle() -> void:
	rifle = Node3D.new()
	rifle.position = HIP_POS
	rifle.scale = Vector3.ONE * 0.82
	viewmodel.add_child(rifle)
	rifle_rest_rot = Vector3(0.0, deg_to_rad(6.0), 0.0)

	var wood := ShaderMaterial.new()
	var wsh := Shader.new()
	wsh.code = WOOD_SHADER
	wood.shader = wsh
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.10, 0.11, 0.15)
	steel.metallic = 0.35
	steel.roughness = 0.55
	var steel_dark := steel.duplicate() as StandardMaterial3D
	steel_dark.albedo_color = Color(0.05, 0.05, 0.07)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.56, 0.26)
	brass.metallic = 0.6
	brass.roughness = 0.4
	var leather := Mats.col(Color(0.20, 0.10, 0.07), 0.9)
	var crystal := Mats.col(Color(0.30, 0.95, 0.90), 0.1, 4.0)
	# matériau propre au cristal-viseur : il s'estompe quand on vise
	crystal_mat = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.30, 0.95, 0.90, 1.0)
	crystal_mat.roughness = 0.1
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.30, 0.95, 0.90)
	crystal_mat.emission_energy_multiplier = 4.0
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# boîtier et capot
	Mats.box(rifle, Vector3(0.08, 0.10, 0.34), steel, Vector3(0, 0, 0))
	Mats.cylinder(rifle, 0.041, 0.041, 0.30, steel, Vector3(0, 0.045, 0.0), Vector3(90, 0, 0), 10)
	Mats.box(rifle, Vector3(0.084, 0.02, 0.34), brass, Vector3(0, -0.04, 0))
	# runes lumineuses sur les flancs
	Mats.box(rifle, Vector3(0.004, 0.012, 0.18), crystal, Vector3(0.041, 0.005, 0.02))
	Mats.box(rifle, Vector3(0.004, 0.012, 0.18), crystal, Vector3(-0.041, 0.005, 0.02))
	# cristal-viseur en losange sur le dessus
	var holder := Mats.box(rifle, Vector3(0.05, 0.03, 0.07), steel_dark, Vector3(0, 0.09, 0.03))
	holder.name = "SightHolder"
	Mats.box(rifle, Vector3(0.032, 0.032, 0.032), crystal_mat, Vector3(0, 0.122, 0.03), Vector3(45, 45, 0))
	var glow := OmniLight3D.new()
	sight_glow = glow
	glow.light_color = Color(0.3, 0.95, 0.9)
	glow.light_energy = 0.2
	glow.omni_range = 0.45
	glow.position = Vector3(0, 0.12, 0.03)
	rifle.add_child(glow)

	# garde-main en bois avec bandes de cuir
	Mats.box(rifle, Vector3(0.092, 0.082, 0.27), wood, Vector3(0, -0.005, -0.31))
	for z in [-0.22, -0.40]:
		Mats.box(rifle, Vector3(0.098, 0.088, 0.025), leather, Vector3(0, -0.005, z))
	# canon, tube de gaz, bagues en laiton, frein de bouche
	Mats.cylinder(rifle, 0.017, 0.017, 0.36, steel, Vector3(0, 0.0, -0.56), Vector3(90, 0, 0), 10)
	Mats.cylinder(rifle, 0.011, 0.011, 0.22, steel_dark, Vector3(0, 0.038, -0.48), Vector3(90, 0, 0), 8)
	Mats.cylinder(rifle, 0.026, 0.026, 0.022, brass, Vector3(0, 0.012, -0.47), Vector3(90, 0, 0), 10)
	Mats.cylinder(rifle, 0.027, 0.024, 0.08, steel_dark, Vector3(0, 0.0, -0.76), Vector3(90, 0, 0), 8)
	Mats.cylinder(rifle, 0.029, 0.029, 0.014, brass, Vector3(0, 0.0, -0.725), Vector3(90, 0, 0), 10)
	Mats.box(rifle, Vector3(0.008, 0.035, 0.012), steel_dark, Vector3(0, 0.045, -0.66))
	# chargeur incurvé (deux segments) avec semelle en laiton
	Mats.box(rifle, Vector3(0.05, 0.12, 0.08), steel_dark, Vector3(0, -0.105, -0.08), Vector3(10, 0, 0))
	Mats.box(rifle, Vector3(0.05, 0.10, 0.075), steel_dark, Vector3(0, -0.205, -0.055), Vector3(24, 0, 0))
	Mats.box(rifle, Vector3(0.056, 0.014, 0.082), brass, Vector3(0, -0.255, -0.035), Vector3(24, 0, 0))
	# poignée-pistolet en bois, pontet
	Mats.box(rifle, Vector3(0.048, 0.14, 0.062), wood, Vector3(0, -0.11, 0.13), Vector3(-18, 0, 0))
	Mats.box(rifle, Vector3(0.012, 0.012, 0.09), steel_dark, Vector3(0, -0.085, 0.06))
	# crosse en bois : corps, busc, plaque de couche
	Mats.box(rifle, Vector3(0.062, 0.10, 0.26), wood, Vector3(0, -0.03, 0.31), Vector3(6, 0, 0))
	Mats.box(rifle, Vector3(0.058, 0.03, 0.16), wood, Vector3(0, 0.03, 0.30))
	Mats.box(rifle, Vector3(0.068, 0.125, 0.022), leather, Vector3(0, -0.045, 0.445), Vector3(6, 0, 0))
	Mats.box(rifle, Vector3(0.066, 0.016, 0.03), brass, Vector3(0, -0.01, 0.2))

	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.0, -0.82)
	rifle.add_child(muzzle)
	muzzle_flash = Mats.sphere(muzzle, 0.07, Mats.col(Color(1.0, 0.75, 0.35), 0.2, 8.0), Vector3.ZERO, 6)
	muzzle_flash.visible = false
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.7, 0.4)
	muzzle_light.omni_range = 7.0
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
	elif event.is_action_pressed("repair"):
		_try_repair()
	elif event.is_action_pressed("upgrade"):
		_try_upgrade()
	elif event.is_action_pressed("build_material"):
		_toggle_material()
	elif event.is_action_pressed("weapon_next") and weapon != W.BUILD:
		_select_weapon((weapon + 1) % 3)
	elif event.is_action_pressed("weapon_prev"):
		_select_weapon((weapon + 2) % 3)
	elif event.is_action_pressed("weapon_swap"):
		if weapon == W.BUILD:
			_toggle_material()
		else:
			_select_weapon(W.AXE if weapon == W.RIFLE else W.RIFLE)
	elif event.is_action_pressed("build_toggle"):
		_select_weapon(W.RIFLE if weapon == W.BUILD else W.BUILD)
	elif event.is_action_pressed("piece_next"):
		_pick_piece((build_piece + 1) % 3)
	elif event.is_action_pressed("piece_prev"):
		_pick_piece((build_piece + 2) % 3)
	elif event.is_action_pressed("sprint_toggle"):
		sprint_toggle = true


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
	if input.length() < 0.3:
		sprint_toggle = false
	if (Input.is_action_pressed("sprint") or sprint_toggle) and input.y < 0.0 and not aiming:
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
	# Souris : on n'agit que si elle est capturée (le clic qui la capture ne doit pas tirer).
	# Manette : toujours actif.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	aiming = Input.is_action_pressed("aim") and weapon == W.RIFLE and not reloading \
		and (captured or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))

	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			ammo = MAG_SIZE

	var firing := Input.is_action_pressed("fire") and (captured or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
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
			# Manette : RT = mur, LT = sol, RB = rampe. Souris : clic gauche = pièce choisie.
			var want := -1
			if Input.is_action_pressed("pad_build_wall"):
				want = 0
			elif Input.is_action_pressed("pad_build_floor"):
				want = 1
			elif Input.is_action_pressed("pad_build_ramp"):
				want = 2
			elif captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				want = build_piece
			if want >= 0 and want != build_piece:
				build_piece = want
			_update_ghost()
			if want >= 0 and build_cd <= 0.0:
				_place()


func _process(delta: float) -> void:
	# Visée au stick droit (courbe quadratique pour la précision)
	if not dead and not get_tree().paused:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.0:
			look = look * look.length()
			var spd := STICK_LOOK_SPEED * (0.45 if aiming else 1.0)
			rotate_y(-look.x * spd * delta)
			head.rotation.x = clampf(head.rotation.x - look.y * spd * 0.75 * delta, -1.5, 1.5)
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
	var target_rot := Vector3.ZERO if aiming else rifle_rest_rot
	if reloading:
		target_pos = HIP_POS + Vector3(-0.05, -0.08, 0.05)
		target_rot = Vector3(-0.5, 0.3, 0.5)
	rifle.position = rifle.position.lerp(target_pos + bob + equip_off + Vector3(0, 0, recoil * 0.06), minf(16.0 * delta, 1.0))
	rifle.rotation = rifle.rotation.lerp(target_rot + Vector3(recoil * 0.1, 0, 0), minf(14.0 * delta, 1.0))
	if not swinging:
		axe.position = AXE_POS + bob * 1.5 + equip_off

	# Le cristal-viseur s'estompe quand on vise pour voir la cible au travers
	ads_t = move_toward(ads_t, 1.0 if aiming else 0.0, delta * 6.0)
	crystal_mat.albedo_color.a = lerpf(1.0, 0.18, ads_t)
	crystal_mat.emission_energy_multiplier = lerpf(4.0, 0.25, ads_t)
	sight_glow.light_energy = lerpf(0.2, 0.0, ads_t)

	# Tremblement de caméra (impacts de hache)
	if shake_t > 0.0:
		shake_t -= delta
		var k := shake_amp * clampf(shake_t / 0.15, 0.0, 1.0)
		cam.h_offset = randf_range(-k, k)
		cam.v_offset = randf_range(-k, k)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	_update_build_target()

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

## Coup de hache en 4 temps : armé (on lève la hache en arrière), frappe rapide en arc,
## impact (petit arrêt + tremblement), puis retour en position.
func _swing() -> void:
	swing_cd = 0.62
	swinging = true
	var tw := create_tween()
	# 1. armé : la hache recule et monte au-dessus de l'épaule
	tw.tween_property(axe, "position", AXE_POS + Vector3(0.06, 0.16, 0.12), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(axe_pivot, "rotation", Vector3(0.75, -0.25, -0.35), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "rotation:z", -0.025, 0.16)
	tw.tween_callback(func(): Sfx.play("swing", -4.0))
	# 2. frappe : arc rapide vers le bas et vers le centre
	tw.tween_property(axe, "position", AXE_POS + Vector3(-0.16, -0.05, -0.18), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(axe_pivot, "rotation", Vector3(-1.45, 0.45, 0.65), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(cam, "rotation:z", 0.035, 0.09)
	# 3. impact
	tw.tween_callback(_axe_impact)
	tw.tween_interval(0.06)
	# 4. accompagnement puis retour
	tw.tween_property(axe_pivot, "rotation", Vector3(-1.6, 0.55, 0.75), 0.06)
	tw.tween_property(axe, "position", AXE_POS, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(axe_pivot, "rotation", Vector3.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "rotation:z", 0.0, 0.2)
	tw.tween_callback(func(): swinging = false)


func _shake(amount: float) -> void:
	shake_amp = amount
	shake_t = 0.15


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
	_shake(0.012)
	if c and c.is_in_group("rock"):
		var got: int = c.mine(AXE_TREE_DAMAGE)
		if got > 0:
			stone = mini(stone + got, 999)
			if hud:
				hud.stone_gain(got)
		elif hud and main and not main.stone_unlocked:
			hud.flash_message("La pierre se débloque à la vague %d" % main.STONE_WAVE)
		main.spawn_impact(r.position, r.normal, Color(0.5, 0.5, 0.6), 10, 1.0)
		_shake(0.02)
	elif c and c.is_in_group("tree"):
		var gained: int = c.chop(AXE_TREE_DAMAGE)
		wood = mini(wood + gained, 999)
		if hud and gained > 0:
			hud.wood_gain(gained)
		_shake(0.018)
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
	ghost_valid = _material_count(build_mat) >= BUILD_COST and not main.structures.has(ghost_info["key"])
	ghost_ok_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.35) if build_mat == 0 else Color(0.75, 0.7, 1.0, 0.4)
	ghost.material_override = ghost_ok_mat if ghost_valid else ghost_bad_mat


func _place() -> void:
	if ghost_info.is_empty():
		return
	if not ghost_valid:
		if _material_count(build_mat) < BUILD_COST and hud:
			hud.flash_message("Pas assez de bois ! Coupe des arbres (hache)" if build_mat == 0 else "Pas assez de pierre ! Casse des rochers (hache)")
		build_cd = 0.4
		return
	_spend(build_mat, BUILD_COST)
	build_cd = 0.15
	main.place_structure(build_piece, ghost_info["xform"], ghost_info["key"], build_mat)


func _material_count(m: int) -> int:
	return wood if m == 0 else stone


func _spend(m: int, amount: int) -> void:
	if m == 0:
		wood -= amount
	else:
		stone -= amount


func _toggle_material() -> void:
	if main and not main.stone_unlocked:
		if hud:
			hud.flash_message("La pierre se débloque à la vague %d" % main.STONE_WAVE)
		return
	build_mat = 1 - build_mat
	Sfx.play("equip", -6.0)
	if weapon != W.BUILD:
		_select_weapon(W.BUILD)


# ------------------------------------------------------------------ réparation / amélioration

## La construction visée (jusqu'à 6 m), sinon la plus proche à moins de 3,5 m.
func _update_build_target() -> void:
	build_target = null
	if dead or main == null:
		return
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 6.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 8)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r.collider and r.collider.is_in_group("structure"):
		build_target = r.collider
	else:
		var best := 3.5
		for st in get_tree().get_nodes_in_group("structure"):
			var d: float = st.global_position.distance_to(global_position + Vector3.UP)
			if d < best:
				best = d
				build_target = st


func _try_repair() -> void:
	if build_target == null or not is_instance_valid(build_target):
		return
	var cost: int = build_target.repair_cost()
	if cost == 0:
		hud.flash_message("Cette construction est intacte")
		return
	var m: int = build_target.material_type
	if _material_count(m) < cost:
		hud.flash_message("Il faut %d %s pour réparer" % [cost, MAT_NAMES[m].to_lower()])
		return
	_spend(m, cost)
	build_target.repair()


func _try_upgrade() -> void:
	if build_target == null or not is_instance_valid(build_target):
		return
	if not build_target.can_upgrade():
		hud.flash_message("Déjà améliorée")
		return
	var m: int = build_target.material_type
	var cost: int = build_target.UPGRADE_COST
	if _material_count(m) < cost:
		hud.flash_message("Il faut %d %s pour améliorer" % [cost, MAT_NAMES[m].to_lower()])
		return
	_spend(m, cost)
	build_target.upgrade()


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
