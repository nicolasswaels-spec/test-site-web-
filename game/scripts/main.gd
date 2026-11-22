extends Node3D
## Scène de jeu : construit la plaine, les arbres, la sphère, et gère les 10 vagues.

const Mats = preload("res://scripts/mats.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const TreeScript = preload("res://scripts/tree.gd")
const OrbScript = preload("res://scripts/orb.gd")
const StructureScript = preload("res://scripts/structure.gd")
const HudScript = preload("res://scripts/hud.gd")

const MAP_RADIUS := 70.0
const SPAWN_RADIUS := 63.0
const TOTAL_WAVES := 10
const BREAK_TIME := 25.0
const RESPAWN_TIME := 5.0
const TREE_COUNT := 120

const GROUND_SHADER := """
shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float n = noise(wpos.xz * 0.06) * 0.55 + noise(wpos.xz * 0.35) * 0.3 + noise(wpos.xz * 2.5) * 0.15;
	vec3 grass = mix(vec3(0.20, 0.48, 0.10), vec3(0.36, 0.66, 0.16), n);
	float r = length(wpos.xz);
	float dirt_n = noise(wpos.xz * 0.8) * 1.5;
	vec3 dirt = mix(vec3(0.45, 0.33, 0.20), vec3(0.56, 0.42, 0.27), noise(wpos.xz * 3.0));
	vec3 c = mix(dirt, grass, smoothstep(5.0, 7.5, r + dirt_n));
	float edge = smoothstep(67.0, 70.0, r);
	c = mix(c, c * vec3(0.75, 0.7, 1.0), edge);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""

const STORM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.55, 0.3, 1.0, 1.0);
varying float h;
void vertex() { h = VERTEX.y; }
void fragment() {
	float stripes = 0.5 + 0.5 * sin(UV.x * 500.0 + h * 1.5 - TIME * 3.0);
	float fade = smoothstep(15.0, -15.0, h);
	ALBEDO = color.rgb * (0.25 + 0.35 * stripes) * fade;
	ALPHA = fade;
}
"""

var player
var orb
var hud
var structures := {}
var obstacle_pos: Array[Vector3] = []
var obstacle_rad: Array[float] = []
var zombie_cache: Array[Node] = []
var rocks: Array[Node3D] = []
var clouds: Node3D
var tracer_mat: StandardMaterial3D

var state := "idle"   # idle, break, wave, won, lost
var wave := 0
var to_spawn := 0
var bosses_left := 0
var spawn_timer := 0.0
var spawn_interval := 1.0
var countdown := 0.0
var respawn_t := 0.0
var spawn_angles: Array[float] = []
var spawn_markers: Array[Node3D] = []
var orb_alert_t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	get_tree().paused = false
	tracer_mat = StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.9, 0.5)
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_build_environment()
	_build_ground()
	_build_storm_wall()
	_build_scenery()
	_spawn_trees()
	rebuild_obstacles()

	orb = OrbScript.new()
	add_child(orb)
	orb.damaged.connect(_on_orb_damaged)
	orb.destroyed.connect(_on_orb_destroyed)

	hud = HudScript.new()
	add_child(hud)
	hud.menu_pressed.connect(_to_menu)
	hud.retry_pressed.connect(_retry)

	player = PlayerScript.new()
	player.main = self
	player.hud = hud
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	player.died.connect(_on_player_died)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_center("ZONE ZÉRO", "Coupe du bois (2), construis (3), puis active la sphère (E)", 4.0)


# ------------------------------------------------------------------ décor

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.18, 0.42, 0.92)
	sm.sky_horizon_color = Color(0.62, 0.8, 1.0)
	sm.ground_horizon_color = Color(0.62, 0.8, 1.0)
	sm.ground_bottom_color = Color(0.25, 0.4, 0.25)
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.78, 1.0)
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(420, 420)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	mat.shader = sh
	mi.material_override = mat
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(420, 2, 420)
	cs.shape = bs
	cs.position.y = -1.0
	ground.add_child(cs)

	# Touffes d'herbe et fleurs (MultiMesh = très peu coûteux)
	var blade := PrismMesh.new()
	blade.size = Vector3(0.14, 0.36, 0.04)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.9
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material = bm
	_scatter(blade, 5000, 0.25, 0.6, 1.5, [Color(0.3, 0.62, 0.18), Color(0.42, 0.75, 0.22), Color(0.35, 0.68, 0.2)])
	var flower := SphereMesh.new()
	flower.radius = 0.09
	flower.height = 0.18
	flower.radial_segments = 6
	flower.rings = 3
	var fm := bm.duplicate() as StandardMaterial3D
	flower.material = fm
	_scatter(flower, 700, 0.18, 0.8, 1.3, [Color(1, 0.3, 0.35), Color(1, 0.9, 0.2), Color(1, 1, 1), Color(0.7, 0.4, 1.0)])


func _scatter(mesh: Mesh, count: int, y: float, smin: float, smax: float, colors: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var r := sqrt(rng.randf()) * (MAP_RADIUS + 20.0)
		if r < 7.0:
			r += 7.0
		var a := rng.randf() * TAU
		var s := rng.randf_range(smin, smax)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * r, y * s, sin(a) * r)))
		mm.set_instance_color(i, colors[rng.randi() % colors.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_storm_wall() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = MAP_RADIUS
	cm.bottom_radius = MAP_RADIUS
	cm.height = 30.0
	cm.radial_segments = 128
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = STORM_SHADER
	mat.shader = sh
	mi.material_override = mat
	mi.position.y = 15.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_scenery() -> void:
	# Collines au loin
	var hill_colors := [Color(0.3, 0.6, 0.25), Color(0.36, 0.66, 0.3), Color(0.28, 0.55, 0.3)]
	for i in 46:
		var a := TAU * i / 46.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(100.0, 170.0)
		var rad := rng.randf_range(18.0, 40.0)
		var h := Mats.sphere(self, rad, Mats.col(hill_colors[i % 3], 0.95), Vector3(cos(a) * r, -rad * 0.45, sin(a) * r), 20)
		h.scale = Vector3(1.0, rng.randf_range(0.5, 0.9), 1.0)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Montagnes enneigées encore plus loin
	for i in 10:
		var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(210.0, 240.0)
		var hgt := rng.randf_range(50.0, 85.0)
		var m := Mats.cylinder(self, 0.0, hgt * 0.8, hgt, Mats.col(Color(0.45, 0.5, 0.62), 0.9), Vector3(cos(a) * r, hgt * 0.5 - 5.0, sin(a) * r), Vector3.ZERO, 7)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var snow := Mats.cylinder(self, 0.0, hgt * 0.24, hgt * 0.3, Mats.col(Color(0.95, 0.97, 1.0), 0.8), Vector3(cos(a) * r, hgt * 0.85 - 5.0, sin(a) * r), Vector3.ZERO, 7)
		snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Nuages
	clouds = Node3D.new()
	add_child(clouds)
	var cloud_mat := Mats.col(Color(1, 1, 1), 1.0, 0.25)
	for i in 22:
		var c := Node3D.new()
		var a := rng.randf() * TAU
		var r := rng.randf_range(30.0, 160.0)
		c.position = Vector3(cos(a) * r, rng.randf_range(45.0, 70.0), sin(a) * r)
		clouds.add_child(c)
		for j in rng.randi_range(3, 5):
			var s := Mats.sphere(c, rng.randf_range(4.0, 7.0), cloud_mat, Vector3(j * 4.5 - 9.0, rng.randf_range(-1, 1.5), rng.randf_range(-2, 2)), 12)
			s.scale.y = 0.6
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rochers
	var rock_mat := Mats.col(Color(0.58, 0.58, 0.62), 0.9)
	for i in 28:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.0, MAP_RADIUS - 4.0)
		var rad := rng.randf_range(0.6, 1.4)
		var body := StaticBody3D.new()
		body.collision_layer = 16
		body.collision_mask = 0
		body.position = Vector3(cos(a) * r, 0, sin(a) * r)
		add_child(body)
		var m := Mats.sphere(body, rad, rock_mat, Vector3(0, rad * 0.3, 0), 7)
		m.scale = Vector3(1.0, 0.7, rng.randf_range(0.8, 1.2))
		m.rotation.y = rng.randf() * TAU
		var cs := CollisionShape3D.new()
		var ss := SphereShape3D.new()
		ss.radius = rad * 0.85
		cs.shape = ss
		cs.position.y = rad * 0.3
		body.add_child(cs)
		rocks.append(body)
		body.set_meta("radius", rad)


func _spawn_trees() -> void:
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < TREE_COUNT and tries < 5000:
		tries += 1
		var r := sqrt(rng.randf_range(0.02, 1.0)) * (MAP_RADIUS - 5.0)
		if r < 11.0:
			continue
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for q in placed:
			if q.distance_to(p) < 4.5:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var t := TreeScript.new()
		t.kind = 0 if rng.randf() < 0.6 else 1
		t.tree_scale = rng.randf_range(0.85, 1.3)
		t.main = self
		t.position = p
		add_child(t)


func rebuild_obstacles() -> void:
	obstacle_pos.clear()
	obstacle_rad.clear()
	for t in get_tree().get_nodes_in_group("tree"):
		obstacle_pos.append(t.global_position)
		obstacle_rad.append(0.45 * t.tree_scale + 1.4)
	for r in rocks:
		obstacle_pos.append(r.global_position)
		obstacle_rad.append(float(r.get_meta("radius")) + 1.2)


## Force de répulsion pour que les zombies contournent arbres, rochers et congénères.
func avoidance(z: Node3D) -> Vector3:
	var push := Vector3.ZERO
	var p := z.global_position
	for i in obstacle_pos.size():
		var d := p - obstacle_pos[i]
		d.y = 0.0
		var l := d.length()
		var rad := obstacle_rad[i]
		if l < rad and l > 0.01:
			var n := d / l
			var tangent := Vector3(-n.z, 0.0, n.x)
			push += (n + tangent * 0.9) * (rad - l) / rad * 1.6
	for o in zombie_cache:
		if o == z or not is_instance_valid(o):
			continue
		var d: Vector3 = p - (o as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.1 and l > 0.01:
			push += d / l * (1.1 - l) * 1.2
	return push


# ------------------------------------------------------------------ effets

func spawn_impact(pos: Vector3, normal: Vector3, color: Color, amount := 8, size := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.07 * size
	m.material = Mats.col(color, 0.7, 0.3)
	p.mesh = m
	p.direction = normal if normal.length() > 0.1 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.0 * size
	p.initial_velocity_max = 5.0 * size
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


func spawn_tracer(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, length)
	mi.mesh = bm
	mi.material_override = tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	mi.look_at(b, up)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), 0.06)
	tw.tween_callback(mi.queue_free)


func place_structure(piece: int, xform: Transform3D, key: String) -> void:
	var s := StructureScript.new()
	s.piece = piece
	s.key = key
	s.main = self
	s.transform = xform
	add_child(s)
	structures[key] = s
	Sfx.play("build", -6.0)


# ------------------------------------------------------------------ boucle de jeu

func _physics_process(_delta: float) -> void:
	zombie_cache = get_tree().get_nodes_in_group("zombie")


func _process(delta: float) -> void:
	clouds.rotation.y += delta * 0.004
	hud.update_player(player)
	hud.set_orb(orb.hp, orb.max_hp)

	var near_orb: bool = not player.dead and player.global_position.distance_to(orb.global_position) < 5.5
	var prompt := ""
	match state:
		"idle":
			hud.set_wave("PRÉPARATION", "Approche-toi de la sphère et appuie sur E pour lancer le combat")
			if near_orb:
				prompt = "[E] LANCER LE COMBAT"
				if Input.is_action_just_pressed("interact"):
					_start_wave(1)
		"break":
			countdown -= delta
			hud.set_wave("VAGUE %d/%d DANS %d s" % [wave + 1, TOTAL_WAVES, int(ceil(countdown))], "Coupe du bois et renforce tes défenses !")
			if near_orb:
				prompt = "[E] LANCER LA VAGUE SUIVANTE"
				if Input.is_action_just_pressed("interact"):
					countdown = 0.0
			if countdown <= 0.0:
				_start_wave(wave + 1)
		"wave":
			_update_spawning(delta)
			var alive := get_tree().get_nodes_in_group("zombie").size()
			var remaining := alive + to_spawn + bosses_left
			hud.set_wave("VAGUE %d/%d" % [wave, TOTAL_WAVES], "Zombies restants : %d" % remaining)
			if remaining == 0:
				_end_wave()

	if player.dead and state != "won" and state != "lost":
		respawn_t -= delta
		prompt = "Réapparition dans %d..." % int(ceil(respawn_t))
		if respawn_t <= 0.0:
			player.respawn(Vector3(rng.randf_range(-2, 2), 0.5, 6.0))
	hud.set_prompt(prompt)

	orb_alert_t -= delta
	hud.set_alert("⚠ LA SPHÈRE EST ATTAQUÉE !" if orb_alert_t > 0.0 and fmod(orb_alert_t, 0.5) > 0.2 else "")


func _start_wave(n: int) -> void:
	wave = n
	state = "wave"
	to_spawn = 6 + (n - 1) * 4
	bosses_left = n / 5   # mini-boss à la vague 5, deux boss à la vague 10
	spawn_interval = maxf(0.35, 1.3 - n * 0.09)
	spawn_timer = 1.5

	# Directions d'arrivée (1 à 3 selon la vague), bien espacées
	spawn_angles.clear()
	var dirs := 1 if n <= 2 else (2 if n <= 6 else 3)
	var base := rng.randf() * TAU
	for i in dirs:
		spawn_angles.append(base + TAU * i / dirs + rng.randf_range(-0.3, 0.3))
	for a in spawn_angles:
		var marker := _make_spawn_marker()
		marker.position = Vector3(cos(a) * SPAWN_RADIUS, 0, sin(a) * SPAWN_RADIUS)
		add_child(marker)
		spawn_markers.append(marker)

	Sfx.play("horn", -2.0)
	var sub := "Protège la sphère !"
	if bosses_left > 0:
		sub = "Attention : %s en approche !" % ("un BOSS" if bosses_left == 1 else "deux BOSS")
	hud.show_center("VAGUE %d" % n, sub, 2.5)


func _make_spawn_marker() -> Node3D:
	var n := Node3D.new()
	var beam := Mats.cylinder(n, 0.9, 0.9, 90.0, null, Vector3(0, 45, 0), Vector3.ZERO, 12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.15, 0.1, 0.55)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.2, 0.1)
	l.light_energy = 3.0
	l.omni_range = 10.0
	l.position.y = 1.5
	n.add_child(l)
	return n


func _update_spawning(delta: float) -> void:
	if to_spawn <= 0 and bosses_left <= 0:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = spawn_interval
	if to_spawn > 0:
		to_spawn -= 1
		_spawn_zombie(false)
	else:
		bosses_left -= 1
		_spawn_zombie(true)


func _spawn_zombie(boss: bool) -> void:
	var z := ZombieScript.new()
	var n := wave
	z.max_hp = 60.0 + (n - 1) * 14.0
	z.speed = minf(2.3 + n * 0.17, 4.1)
	z.damage = 8.0 + n
	if boss:
		z.is_boss = true
		z.size_mult = 1.9
		z.max_hp *= 14.0
		z.speed *= 0.75
		z.damage *= 3.0
	z.hp = z.max_hp
	z.main = self
	z.orb = orb
	z.player = player
	var a: float = spawn_angles[rng.randi() % spawn_angles.size()] + rng.randf_range(-0.18, 0.18)
	var r := SPAWN_RADIUS + rng.randf_range(-2.5, 2.5)
	z.position = Vector3(cos(a) * r, 0.05, sin(a) * r)
	add_child(z)
	if boss:
		hud.flash_message("UN BOSS EST APPARU !")


func _end_wave() -> void:
	for m in spawn_markers:
		m.queue_free()
	spawn_markers.clear()
	if wave >= TOTAL_WAVES:
		_finish(true)
		return
	state = "break"
	countdown = BREAK_TIME
	player.wood = mini(player.wood + 50, 999)
	if not player.dead:
		player.hp = player.MAX_HP
	orb.repair(150.0)
	hud.show_center("VAGUE %d TERMINÉE" % wave, "+50 bois · vie restaurée · sphère réparée (+150)", 3.0)


func _on_orb_damaged(_amount: float) -> void:
	orb_alert_t = 2.0


func _on_orb_destroyed() -> void:
	_finish(false)


func _on_player_died() -> void:
	respawn_t = RESPAWN_TIME
	hud.show_center("ÉLIMINÉ", "La sphère tient toujours... pour l'instant.", 2.0)


func _finish(victory: bool) -> void:
	if state == "won" or state == "lost":
		return
	state = "won" if victory else "lost"
	if victory:
		Sfx.play("win")
		hud.show_end("VICTOIRE !", "Les 10 vagues ont été repoussées. La sphère est sauve.")
	else:
		Sfx.play("lose")
		hud.show_end("DÉFAITE", "La sphère a été détruite à la vague %d." % wave)
	get_tree().paused = true


func _retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
