extends Node3D
## Scène de jeu : construit la plaine, les arbres, la sphère, et gère les 10 vagues.

const Mats = preload("res://scripts/mats.gd")
const Nature = preload("res://scripts/nature.gd")
const Volcanic = preload("res://scripts/volcanic.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const TreeScript = preload("res://scripts/tree.gd")
const OrbScript = preload("res://scripts/orb.gd")
const StructureScript = preload("res://scripts/structure.gd")
const RockScript = preload("res://scripts/rock.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const HudScript = preload("res://scripts/hud.gd")
const HudGroup = preload("res://scripts/hud_group.gd")
const RouterScript = preload("res://scripts/input_router.gd")
const DropScript = preload("res://scripts/resource_drop.gd")
const ChestScript = preload("res://scripts/chest.gd")
const TitanScript = preload("res://scripts/titan.gd")
const SkyTitanScript = preload("res://scripts/sky_titan.gd")
const CloudResScript = preload("res://scripts/cloud_res.gd")
const CHESTS_PER_ZONE := 2

const MAP_RADIUS := 70.0
const SPAWN_RADIUS := 63.0
const TOTAL_WAVES := 10
const BREAK_TIME := 60.0
const RESPAWN_TIME := 5.0
const TREE_COUNT := 140
# Zone 2 (biome des érables), débloquée après les 10 vagues de la 1re sphère
const ZONE2_CENTER := Vector3(0, 0, -160)
const ZONE2_RADIUS := 58.0
const CORRIDOR_HALF := 7.0
const CORRIDOR_Z := Vector2(-104.0, -66.0)   # z min / z max du couloir
const ZONE2_DIFFICULTY_OFFSET := 7           # vague 1 de la sphère 2 = vague 8 de la sphère 1
const ZONE2_TREE_COUNT := 95
const PICKUPS_PER_ZONE := 30
# Zone volcanique (à l'ouest de la zone 2) : titan de lave, puis 3e sphère au même endroit
const ZONE3_CENTER := Vector3(-170, 0, -160)
const ZONE3_RADIUS := 58.0
const CORRIDOR2_HALF := 7.0
const CORRIDOR2_X := Vector2(-116.0, -54.0)   # x min / x max du couloir zone 2 -> zone 3 (le long de z = -160)
const ZONE3_TREE_COUNT := 60
const ZONE4_DIFFICULTY_OFFSET := 12          # vague 1 de la sphère 3 = vague 13 de la sphère 1
const BOSS_TRAVEL_TIME := 60.0               # temps pour rejoindre le titan
const ZONE4_TIME := 180.0                    # titan vaincu -> défense de la 3e sphère
# Zone céleste (après la 3e sphère) : île de nuages en hauteur, au nord du volcan, reliée par
# un escalier de nuages en spirale puis une passerelle. 4e sphère au centre.
const SKY_Y := 32.0                         # sol de l'île (multiple de 4 : grille de construction)
const SKY_CENTER := Vector3(-170, 32, -290)
const SKY_RADIUS := 50.0
const STAIR_CENTER := Vector3(-170, 0, -205) # axe de l'escalier en spirale (dans la zone volcanique)
const STAIR_RADIUS := 9.0
const BRIDGE_Z := Vector2(-246.0, -212.0)    # passerelle : z min / z max (x = -170)
const BRIDGE_HALF := 2.5
const SKY_TIME := 150.0                      # 3e sphère terminée -> défense de la 4e sphère
const ZONE5_DIFFICULTY_OFFSET := 15
const CLOUD_GROUND := 45
const CLOUD_AIR := 25
const MAGIC_PER_ZONE := 4                    # arbres magiques et rochers magiques par zone
const LAVA_DPS := 16.0
# sphères 2 et 3 : 1/3 de squelettes en moins (les PV et dégâts viennent du niveau des squelettes),
# puis encore -20 % (et -35 % sur l'île des nuages), compensés par des dégâts aux constructions ×1,3
const LATE_COUNT_MULT := 2.0 / 3.0
const FEWER_MULT := 0.8
const SKY_COUNT_MULT := 0.65
## Les sphères sont au centre d'une case de construction (grille de 4 m) :
## un sol posé au pied de la sphère la centre, et 4 murs suffisent à l'entourer.
const ORB_OFFSET := Vector3(2, 0, 2)


## Centre de la case de construction (grille de 4 m, cases centrées sur 2 + 4k) la plus proche d'un point
## décalé de ORB_OFFSET : la sphère est toujours au milieu d'un sol, jamais au croisement de murs.
static func orb_cell(center: Vector3) -> Vector3:
	var p := center + ORB_OFFSET
	return Vector3((floorf(p.x / 4.0) + 0.5) * 4.0, p.y, (floorf(p.z / 4.0) + 0.5) * 4.0)

const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float n = noise(wpos.xz * 0.05) * 0.55 + noise(wpos.xz * 0.3) * 0.3 + noise(wpos.xz * 2.0) * 0.15;
	vec3 grass = mix(vec3(0.03, 0.10, 0.10), vec3(0.08, 0.22, 0.18), n);
	float r = length(wpos.xz);
	float dirt_n = noise(wpos.xz * 0.8) * 1.5;
	vec3 dirt = mix(vec3(0.14, 0.11, 0.15), vec3(0.22, 0.17, 0.20), noise(wpos.xz * 3.0));
	// biome 2 (érables) : sol mauve autour de la 2e sphère
	vec2 c2 = vec2(0.0, -160.0);
	float r2 = length(wpos.xz - c2);
	float b2 = smoothstep(72.0, 58.0, r2 + noise(wpos.xz * 0.1) * 8.0);
	vec3 grass2 = mix(vec3(0.12, 0.04, 0.10), vec3(0.26, 0.10, 0.20), n);
	grass = mix(grass, grass2, b2);
	// biome 3 (volcan) : basalte sombre parcouru de fissures de lave
	vec2 c3 = vec2(-170.0, -160.0);
	float r3 = length(wpos.xz - c3);
	float b3 = smoothstep(74.0, 56.0, r3 + noise(wpos.xz * 0.1) * 8.0);
	vec3 basalt = mix(vec3(0.045, 0.042, 0.05), vec3(0.11, 0.105, 0.12), n) + vec3(0.08, 0.08, 0.09) * smoothstep(0.55, 0.85, noise(wpos.xz * 0.5));   // cendre volcanique gris-violet
	float crack = smoothstep(0.008, 0.0, abs(noise(wpos.xz * 0.32) - 0.5)) * smoothstep(0.55, 0.75, noise(wpos.xz * 0.07));
	grass = mix(grass, basalt, b3);
	dirt = mix(dirt, vec3(0.20, 0.12, 0.09), b3);
	r = min(min(r, r2), r3);
	ALBEDO = mix(dirt, grass, smoothstep(4.5, 7.0, r + dirt_n));
	// volcan : sol de cendre sans grandes fissures (la lave est dans les coulées)
	crack *= 0.0;
	ROUGHNESS = 1.0;
}
"""

const LAVA_SHADER_OLD := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = noise(wp.xz * 0.8 + vec2(TIME * 0.15, TIME * 0.1)) * 0.6 + noise(wp.xz * 2.2 - TIME * 0.2) * 0.4;
	vec3 c = mix(vec3(0.55, 0.06, 0.0), vec3(1.0, 0.55, 0.08), smoothstep(0.3, 0.8, n));
	ALBEDO = c * 1.6;
}
"""

const CLOUD_GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
// « hauteur » du nuage : gros bourrelets arrondis + petites boules, qui dérivent lentement
float puffy(vec2 p) {
	vec2 w = vec2(fbm(p * 0.6 + TIME * 0.015), fbm(p * 0.6 + vec2(5.2, 1.3) - TIME * 0.012));
	float big = fbm(p * 0.55 + w * 1.4);
	float balls = 1.0 - abs(noise(p * 2.2 + w * 2.0) * 2.0 - 1.0);
	return big * 0.75 + balls * balls * 0.35;
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * 0.16;
	float h = puffy(p);
	float e = 0.05;
	float hx = puffy(p + vec2(e, 0.0));
	float hz = puffy(p + vec2(0.0, e));
	// relief simulé : la normale suit les bosses du nuage
	vec3 n = normalize(vec3(-(hx - h) / e * 0.9, 1.0, -(hz - h) / e * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 hollow = vec3(0.52, 0.58, 0.82);   // creux bleutés / lavande
	vec3 top = vec3(0.98, 0.97, 1.0);
	vec3 c = mix(hollow, top, smoothstep(0.32, 0.78, h));
	c = mix(c, vec3(1.0, 0.95, 0.9), smoothstep(0.7, 0.95, h) * 0.35);   // reflets chauds sur les sommets
	ALBEDO = c;
	EMISSION = vec3(0.06, 0.07, 0.11) * (0.5 + h);
	ROUGHNESS = 1.0;
}
"""

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_col : source_color = vec3(0.07, 0.07, 0.22);
uniform vec3 mid_col : source_color = vec3(0.38, 0.26, 0.55);
uniform vec3 hor_col : source_color = vec3(1.0, 0.60, 0.42);
uniform vec3 glow_col : source_color = vec3(1.0, 0.72, 0.42);
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 c = mix(hor_col, mid_col, smoothstep(0.0, 0.22, y));
	c = mix(c, top_col, smoothstep(0.18, 0.65, y));
	if (y < 0.0) {
		c = mix(hor_col * 0.7, vec3(0.06, 0.06, 0.16), smoothstep(0.0, -0.25, y));
	}
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	c += glow_col * (pow(sd, 6.0) * 0.5 + pow(sd, 60.0) * 0.8 + pow(sd, 900.0) * 6.0);
	if (!AT_CUBEMAP_PASS) {
		vec3 cell = floor(d * 260.0);
		float h = hash(cell);
		float star = step(0.9965, h) * smoothstep(0.12, 0.5, y);
		c += vec3(0.9, 0.9, 1.0) * star * (0.5 + 0.5 * sin(TIME * 2.0 + h * 80.0));
	}
	COLOR = c;
}
"""

const STORM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(0.25, 0.55, 1.0, 1.0);
uniform float gap = 0.0;   // ouverture du couloir vers la zone 2
uniform float gap2 = 0.0;  // ouverture du couloir zone 2 -> zone volcanique
varying float h;
varying vec3 wp;
void vertex() { h = VERTEX.y; wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (gap > 0.0 && abs(wp.x) < gap && wp.z < -60.0 && wp.z > -108.0) { discard; }
	if (gap2 > 0.0 && abs(wp.z + 160.0) < gap2 && wp.x < -50.0 && wp.x > -120.0) { discard; }
	float stripes = 0.5 + 0.5 * sin(UV.x * 500.0 + h * 1.5 - TIME * 2.0);
	float fade = smoothstep(6.0, -15.0, h);
	ALBEDO = color.rgb * (0.08 + 0.12 * stripes) * fade;
	ALPHA = fade;
}
"""

var player                 # joueur 1 (raccourci)
var players: Array = []    # joueurs (1 ou 2, écran scindé)
var huds: Array = []
var views: Array = []      # par joueur : {container, viewport, camera}
var view_root: Control
var router
var orb
var hud
var structures := {}
var obstacle_pos: Array[Vector3] = []
var obstacle_rad: Array[float] = []
var zombie_cache: Array[Node] = []
var rocks: Array[Node3D] = []
var zone := 1                 # sphère défendue : 1 puis 2
var zone2_unlocked := false
var orb1
var orb2
var orb2_beacon: Node3D   # colonne de lumière vers l'objectif suivant
var orb3
var zone3_unlocked := false
var zone3_blockers: Array[Node] = []
var titan
var lava_pools: Array = []   # [position, rayon]
var world_env: Environment
var sun_light: DirectionalLight3D
var embers: CPUParticles3D
var ash: CPUParticles3D
var sky_unlocked := false
var orb4
var angels_left := 0   # anges squelettes (4e sphère seulement, 3 maximum)
# défense sans fin (après la 4e sphère)
const ENDLESS_PREP := 60.0
const ENDLESS_START_LEVEL := 36
const ENDLESS_LEVEL_EVERY := 12.0    # +1 niveau toutes les 12 s
var endless_t := 0.0                 # temps tenu
var endless_spawn_t := 0.0
var endless_boss_t := 0.0
var endless_dir_t := 0.0
var storm_mats: Array[ShaderMaterial] = []
var zone2_blockers: Array[Node] = []   # forêt et pics qui occupent la zone 2 avant son ouverture
var spires: Array[Node3D] = []
var fireflies: CPUParticles3D
var high := true
var tracer_mat: StandardMaterial3D

var state := "idle"   # idle, break, wave, explore (sphère suivante), to_boss, boss, free (tout fini), lost
var wave := 0
var to_spawn := 0
var bosses_left := 0
var archers_left := 0   # archers (3e sphère seulement)
var wave_levels: Array = []   # niveaux des squelettes restant à faire apparaître
var spawn_timer := 0.0
var spawn_interval := 1.0
var countdown := 0.0
var carry_time := 0.0   # temps de préparation non utilisé, reporté à la pause suivante
const START_TIME := 90.0       # mode classique : la défense démarre seule au bout de 1 min 30
const ZONE2_TIME := 120.0      # temps entre les 2 sphères (+ report éventuel)
const CARRY_RATIO := 0.5       # part du temps restant reportée quand on lance la vague en avance
const REVIVE_INVULN := 5.0
const OUT_WAIT_BASE := 5.0     # sans vie : attente de base, +2 s à chaque nouvelle mort
const OUT_WAIT_STEP := 2.0
const OUT_RESPAWN_DIST := 25.0
var rifle_craftable := false
var respawn_t := 0.0
var spawn_angles: Array[float] = []
var spawn_markers: Array[Node3D] = []
var orb_alert_t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	get_tree().paused = false
	high = Settings.high_quality
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
	# Rochers (récoltables à partir de la vague 5), placés à l'écart des arbres
	for i in 34:
		spawn_rock(_random_free_spot(12.0))
		rebuild_obstacles()
	_spawn_magic(1)

	orb = OrbScript.new()
	orb.position = ORB_OFFSET
	add_child(orb)
	orb.damaged.connect(_on_orb_damaged)
	orb.destroyed.connect(_on_orb_destroyed)
	orb1 = orb

	# Rendu par « vues » (une par joueur) qui partagent le même monde 3D ;
	# la fenêtre principale n'affiche plus la 3D elle-même.
	process_priority = 100       # après les joueurs : caméras synchronisées sans décalage
	get_viewport().disable_3d = true
	GameInput.set_builtin_ui_nav(false)
	hud = HudGroup.new()
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	view_root = Control.new()
	view_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(view_root)
	if Settings.coop:
		var pads := Input.get_connected_joypads()
		if pads.size() >= 2:
			add_player(true, pads[0])
			add_player(false, pads[1])
		elif pads.size() == 1:
			add_player(true, -1)
			add_player(false, pads[0])
		else:
			add_player(true, -2)
			hud.show_notice("Branche une manette pour le joueur 2,\npuis appuie sur Start pour le faire entrer.", 6.0)
	else:
		add_player(true, -2)
	player = players[0]
	router = RouterScript.new()
	router.main = self
	add_child(router)

	for i in PICKUPS_PER_ZONE:
		spawn_pickup(1)
	for i in CHESTS_PER_ZONE:
		_spawn_chest(Vector3.ZERO, MAP_RADIUS, false, 1)

	refresh_mouse()
	countdown = START_TIME
	Music.play_region("game", music_region())
	if Settings.test_mode:
		hud.show_notice("MODE TEST : toutes les armes (inventaire pour choisir les 2 équipées)\net ressources illimitées.", 6.0)
	hud.show_center("ZONE ZÉRO", "Coupe du bois (2), construis (3), puis active la sphère (E)", 4.0)


# ------------------------------------------------------------------ décor

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.22, 0.24, 0.5)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = false
	env.ssao_intensity = 1.2
	# Brouillard coloré : bleu-violet dans l'ombre, orangé face au soleil
	env.fog_enabled = true
	env.fog_light_color = Color(0.17, 0.17, 0.38)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.011
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.25
	env.fog_height = 1.5
	env.fog_height_density = 0.0
	# Brouillard volumétrique : rayons de lumière entre les arbres
	if high:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.005
		env.volumetric_fog_albedo = Color(0.85, 0.85, 1.0)
		env.volumetric_fog_emission = Color(0.05, 0.04, 0.12)
		env.volumetric_fog_emission_energy = 0.3
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 70.0
		env.volumetric_fog_ambient_inject = 0.1
		env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	world_env = env
	add_child(we)

	# Soleil couchant, bas sur l'horizon
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, 150, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.68, 0.42)
	sun.light_volumetric_fog_energy = 2.5
	sun_light = sun
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0 if high else 40.0
	add_child(sun)
	# Lumière de remplissage froide (ciel)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, -30, 0)
	fill.light_energy = 0.25
	fill.light_color = Color(0.45, 0.5, 1.0)
	fill.light_volumetric_fog_energy = 0.0
	add_child(fill)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	mat.shader = sh
	mi.material_override = mat
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(500, 2, 500)
	cs.shape = bs
	cs.position.y = -1.0
	ground.add_child(cs)

	# Herbe haute (par morceaux de 16 m pour que le moteur n'affiche que ce qui est proche)
	_scatter_chunks(Nature.grass(), null, 1.3 if high else 0.55, MAP_RADIUS + 12.0, 5.0, 0.8, 1.3, 60.0 if high else 40.0)
	# Plantes rouges et buissons bleu nuit, en petits groupes
	for v in [1, 2]:
		_scatter_chunks(Nature.red_plant(v), null, 0.018, MAP_RADIUS + 12.0, 7.0, 0.6, 1.1, 80.0, true)
	_scatter_chunks(Nature.bush(false), null, 0.015, MAP_RADIUS + 12.0, 7.0, 1.0, 2.0, 80.0, true)
	_scatter_chunks(Nature.bush(true), null, 0.01, MAP_RADIUS + 12.0, 7.0, 1.0, 1.8, 80.0, true)
	var flower := SphereMesh.new()
	flower.radius = 0.05
	flower.height = 0.1
	flower.radial_segments = 5
	flower.rings = 3
	_scatter_chunks(flower, Mats.col(Color(0.9, 0.92, 1.0), 0.8, 0.6), 0.05, MAP_RADIUS, 6.0, 0.8, 1.4, 45.0, false, 0.55)


func _scatter_chunks(mesh: Mesh, mat: Material, density: float, radius: float, clear_r: float, smin: float, smax: float, vis_end: float, clustered := false, y_off := 0.0, center := Vector3.ZERO, filter := Callable()) -> void:
	var chunk := 16.0
	var n := int(ceil(radius / chunk))
	for cx in range(-n, n):
		for cz in range(-n, n):
			var origin := center + Vector3((cx + 0.5) * chunk, 0.0, (cz + 0.5) * chunk)
			var xforms: Array[Transform3D] = []
			var count := int(density * chunk * chunk)
			var centers: Array[Vector3] = []
			if clustered:
				for k in 3:
					centers.append(Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
			for i in count:
				var local := Vector3(rng.randf_range(-8, 8), 0.0, rng.randf_range(-8, 8))
				if clustered:
					local = centers[i % 3] + Vector3(rng.randfn(0.0, 1.6), 0.0, rng.randfn(0.0, 1.6))
				var world := origin + local
				var r := Vector2(world.x - center.x, world.z - center.z).length()
				if r > radius or r < clear_r:
					continue
				if filter.is_valid() and not filter.call(world):
					continue
				var s := rng.randf_range(smin, smax)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
				xforms.append(Transform3D(b, local + Vector3(0, y_off * s, 0)))
			if xforms.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if mat:
				mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = vis_end
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mmi.position = origin
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
	storm_mats.append(mat)


func _build_scenery() -> void:
	# Forêt dense autour de la zone (non interactive, une MultiMesh par variante)
	# Les arbres qui se trouvent sur la future zone 2 / le couloir vont dans des MultiMesh
	# à part, supprimées à l'ouverture de la zone 2.
	var variants := Nature.pines()
	var keep: Array = []
	var block: Array = []
	for i in 620:
		var a := rng.randf() * TAU
		var r := MAP_RADIUS + 3.0 + pow(rng.randf(), 0.8) * 95.0
		var s := rng.randf_range(0.9, 1.7) * (1.0 + (r - MAP_RADIUS) / 120.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		var entry := [rng.randi() % variants.size(), Transform3D(b, pos)]
		if _in_zone2_footprint(pos, 6.0):
			block.append(entry)
		else:
			keep.append(entry)
	_add_forest(variants, keep)
	zone2_blockers.append_array(_add_forest(variants, block))

	# Quelques arbres morts bleu pâle, comme dans les références
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(25.0, MAP_RADIUS + 15.0)
		var mi := MeshInstance3D.new()
		mi.mesh = Nature.dead_tree(1 + i % 3)
		mi.position = Vector3(cos(a) * r, 0, sin(a) * r)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		add_child(mi)

	# Pics rocheux lointains (silhouettes dans le brouillard)
	var spire_mat := Mats.col(Color(0.20, 0.17, 0.30), 1.0)
	for i in 14:
		var a := TAU * i / 14.0 + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(190.0, 240.0)
		var hgt := rng.randf_range(45.0, 110.0)
		var m := Mats.cylinder(self, rng.randf_range(1.0, 6.0), hgt * 0.32, hgt, spire_mat, Vector3(cos(a) * r, hgt * 0.5 - 4.0, sin(a) * r), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 5)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if Vector2(m.position.x - ZONE2_CENTER.x, m.position.z - ZONE2_CENTER.z).length() < ZONE2_RADIUS + 40.0:
			zone2_blockers.append(m)
		elif _in_zone3_footprint(m.position, 30.0):
			zone3_blockers.append(m)

	# Lucioles autour du joueur
	fireflies = CPUParticles3D.new()
	fireflies.amount = 140 if high else 60
	fireflies.lifetime = 7.0
	fireflies.preprocess = 7.0
	fireflies.local_coords = false
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(26, 2.5, 26)
	fireflies.direction = Vector3.UP
	fireflies.spread = 180.0
	fireflies.gravity = Vector3(0, 0.05, 0)
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.4
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.vertex_color_use_as_albedo = true
	fm.albedo_color = Color(1.0, 0.9, 0.45)
	q.material = fm
	fireflies.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	fireflies.color_ramp = ramp
	add_child(fireflies)
	# braises de la zone volcanique (actives seulement là-bas)
	# braises orange qui montent en tourbillonnant, lumineuses (mélange additif)
	embers = fireflies.duplicate()
	embers.amount = 150 if high else 70
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_box_extents = Vector3(24, 5, 24)
	var em := fm.duplicate() as StandardMaterial3D
	em.albedo_color = Color(1.0, 0.55, 0.18)
	em.albedo_texture = Volcanic.soft_dot()
	em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var eq := q.duplicate() as QuadMesh
	eq.size = Vector2(0.11, 0.11)
	eq.material = em
	embers.mesh = eq
	embers.gravity = Vector3(0.25, 0.55, 0.1)
	embers.initial_velocity_min = 0.3
	embers.initial_velocity_max = 1.4
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.3
	embers.hue_variation_min = -0.03
	embers.hue_variation_max = 0.03
	embers.emitting = false
	add_child(embers)
	# cendres grises qui tombent doucement
	ash = fireflies.duplicate()
	ash.amount = 160 if high else 70
	ash.lifetime = 8.0
	ash.preprocess = 8.0
	ash.emission_box_extents = Vector3(24, 6, 24)
	var am := fm.duplicate() as StandardMaterial3D
	am.albedo_color = Color(0.55, 0.52, 0.5, 0.8)
	am.albedo_texture = Volcanic.soft_dot()
	var aq := q.duplicate() as QuadMesh
	aq.size = Vector2(0.06, 0.06)
	aq.material = am
	ash.mesh = aq
	ash.direction = Vector3.DOWN
	ash.spread = 40.0
	ash.gravity = Vector3(0.2, -0.35, 0)
	ash.initial_velocity_min = 0.1
	ash.initial_velocity_max = 0.4
	ash.emitting = false
	add_child(ash)


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
		t.kind = rng.randi() % 5
		t.tree_scale = rng.randf_range(0.8, 1.25)
		t.main = self
		t.position = p
		add_child(t)


func _add_forest(variants: Array, entries: Array) -> Array[Node]:
	var created: Array[Node] = []
	for vi in variants.size():
		var arr: Array = []
		for e in entries:
			if e[0] == vi:
				arr.append(e[1])
		if arr.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[vi]
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		created.append(mmi)
	return created


## Vrai si la position est sur la zone 2 ou le couloir (marge en mètres).
func _in_zone2_footprint(p: Vector3, margin: float) -> bool:
	if Vector2(p.x - ZONE2_CENTER.x, p.z - ZONE2_CENTER.z).length() < ZONE2_RADIUS + margin:
		return true
	return absf(p.x) < CORRIDOR_HALF + margin and p.z > CORRIDOR_Z.x - margin and p.z < CORRIDOR_Z.y + margin


## Vrai si la position est sur la zone volcanique ou son couloir (marge en mètres).
func _in_zone3_footprint(p: Vector3, margin: float) -> bool:
	if Vector2(p.x - ZONE3_CENTER.x, p.z - ZONE3_CENTER.z).length() < ZONE3_RADIUS + margin:
		return true
	return absf(p.z - ZONE2_CENTER.z) < CORRIDOR2_HALF + margin and p.x > CORRIDOR2_X.x - margin and p.x < CORRIDOR2_X.y + margin


## Centre et rayon de chaque zone (3 = volcan, où se trouve aussi la 3e sphère : zone 4).
func zone_center(z: int) -> Vector3:
	match z:
		1: return Vector3.ZERO
		2: return ZONE2_CENTER
		5: return SKY_CENTER
	return ZONE3_CENTER


func zone_radius(z: int) -> float:
	match z:
		1: return MAP_RADIUS
		2: return ZONE2_RADIUS
		5: return SKY_RADIUS
	return ZONE3_RADIUS


## Ce que la mini-carte montre comme objectif : la sphère défendue, ou le titan.
func objective_pos() -> Vector3:
	if (zone == 3 or (zone == 5 and orb4 == null)) and titan and is_instance_valid(titan):
		return titan.global_position
	return orb.global_position


## Ramène une position dans la zone jouable (zones et couloirs débloqués).
func clamp_to_area(p: Vector3) -> Vector3:
	if sky_unlocked and p.y > SKY_Y - 6.0:
		# en hauteur : île de nuages ou passerelle (l'escalier lui-même est dans la zone volcanique)
		var sc := Vector2(SKY_CENTER.x, SKY_CENTER.z)
		var f := Vector2(p.x, p.z)
		var bx := clampf(p.x, SKY_CENTER.x - BRIDGE_HALF + 0.4, SKY_CENTER.x + BRIDGE_HALF - 0.4)
		var bz := clampf(p.z, BRIDGE_Z.x, BRIDGE_Z.y)
		if (f - sc).length() <= SKY_RADIUS - 1.5:
			return p
		if bx == p.x and bz == p.z:
			return p
		if f.distance_to(Vector2(STAIR_CENTER.x, STAIR_CENTER.z)) < STAIR_RADIUS + 4.0:
			return p
		var c1 := sc + (f - sc).normalized() * (SKY_RADIUS - 1.5)
		var c2 := Vector2(bx, bz)
		var best := c1 if c1.distance_to(f) < c2.distance_to(f) else c2
		return Vector3(best.x, p.y, best.y)
	var lim1 := MAP_RADIUS - 1.5
	var f1 := Vector2(p.x, p.z)
	if f1.length() <= lim1:
		return p
	var cands: Array[Vector2] = [f1.normalized() * lim1]
	if zone2_unlocked:
		var cor_x := clampf(p.x, -CORRIDOR_HALF + 0.5, CORRIDOR_HALF - 0.5)
		var cor_z := clampf(p.z, CORRIDOR_Z.x, CORRIDOR_Z.y + 6.0)
		if cor_x == p.x and cor_z == p.z:
			return p
		var c2 := Vector2(ZONE2_CENTER.x, ZONE2_CENTER.z)
		var d2 := f1 - c2
		if d2.length() <= ZONE2_RADIUS - 1.5:
			return p
		cands.append(Vector2(cor_x, cor_z))
		cands.append(c2 + d2.normalized() * (ZONE2_RADIUS - 1.5))
	if zone3_unlocked:
		var zc := ZONE2_CENTER.z
		var c2x := clampf(p.x, CORRIDOR2_X.x - 6.0, CORRIDOR2_X.y + 6.0)
		var c2z := clampf(p.z, zc - CORRIDOR2_HALF + 0.5, zc + CORRIDOR2_HALF - 0.5)
		if c2x == p.x and c2z == p.z:
			return p
		var c3 := Vector2(ZONE3_CENTER.x, ZONE3_CENTER.z)
		var d3 := f1 - c3
		if d3.length() <= ZONE3_RADIUS - 1.5:
			return p
		cands.append(Vector2(c2x, c2z))
		cands.append(c3 + d3.normalized() * (ZONE3_RADIUS - 1.5))
	var best: Vector2 = cands[0]
	for c in cands:
		if c.distance_to(f1) < best.distance_to(f1):
			best = c
	return Vector3(best.x, p.y, best.y)


func spawn_pickup(z: int) -> void:
	var pk := PickupScript.new()
	pk.main = self
	pk.zone = z
	pk.position = _random_free_spot(6.0, zone_center(z), zone_radius(z))
	add_child(pk)


func on_pickup_collected(pk: Node) -> void:
	var z: int = pk.zone
	get_tree().create_timer(45.0, false).timeout.connect(func(): spawn_pickup(z))


func _random_free_spot(min_r: float, center := Vector3.ZERO, radius := MAP_RADIUS) -> Vector3:
	for attempt in 30:
		var a := rng.randf() * TAU
		var r := rng.randf_range(min_r, radius - 5.0)
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for i in obstacle_pos.size():
			if p.distance_to(obstacle_pos[i]) < obstacle_rad[i] + 1.5:
				ok = false
				break
		if ok:
			return p
	var a2 := rng.randf() * TAU
	return center + Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(min_r, radius - 5.0)


## Coffre au trésor + gardiens squelettes immobiles qui chargent quand on approche ou qu'on les attaque.
func _spawn_chest(center: Vector3, radius: float, gold: bool, z: int) -> void:
	var pos := center
	for attempt in 40:
		pos = _random_free_spot(25.0, center, radius)
		var ok := true
		for other in get_tree().get_nodes_in_group("chest"):
			if other.global_position.distance_to(pos) < 25.0:
				ok = false
				break
		if ok:
			break
	var ch := ChestScript.new()
	ch.main = self
	ch.gold = gold
	ch.position = pos
	ch.rotation.y = rng.randf() * TAU
	add_child(ch)
	var n := rng.randi_range(5, 8)
	for i in n:
		var g := ZombieScript.new()
		g.guard = true
		g.guard_group = ch
		g.set_level([4, 12, 20][z - 1])
		g.max_hp = [90.0, 220.0, 330.0][z - 1]
		g.hp = g.max_hp
		g.speed = [2.6, 3.2, 3.4][z - 1]
		g.main = self
		g.orb = orb
		var a := TAU * i / n + rng.randf_range(-0.3, 0.3)
		g.position = pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.0, 6.0) + Vector3(0, 0.05, 0)
		g.rotation.y = a + PI * 0.5
		add_child(g)
	call_deferred("rebuild_obstacles")


## Un gardien a été touché : tout son groupe charge le joueur à vitesse maximale.
func alert_guards(group) -> void:
	for g in get_tree().get_nodes_in_group("zombie"):
		if g.guard and g.guard_group == group and not g.dead:
			g.charge()


func spawn_rock(pos: Vector3, z := 1, magic := false) -> void:
	var rk := RockScript.new()
	rk.set_meta("zone", z)
	rk.volcanic = z == 3
	rk.magic = magic
	rk.variant = 1 + rng.randi() % 5
	rk.rock_scale = rng.randf_range(1.5, 3.0)
	rk.main = self
	rk.position = pos
	rk.rotation.y = rng.randf() * TAU
	add_child(rk)
	rocks.append(rk)
	call_deferred("rebuild_obstacles")


func on_rock_broken(rk: Node3D) -> void:
	rocks.erase(rk)
	rebuild_obstacles()
	# un nouveau rocher apparaît ailleurs un peu plus tard
	var z: int = rk.get_meta("zone", 1)
	get_tree().create_timer(40.0, false).timeout.connect(func():
		spawn_rock(_random_free_spot(12.0, zone_center(z), zone_radius(z)), z))


## Arbres et rochers magiques d'une zone (4 de chaque) : lueur, ressources ×2 et 1 bois / pierre magique.
func _spawn_magic(z: int) -> void:
	var c := zone_center(z)
	var rad := zone_radius(z)
	for i in MAGIC_PER_ZONE:
		var t := TreeScript.new()
		t.magic = true
		t.species = [0, 1, 3][z - 1]
		t.kind = rng.randi() % 4
		t.tree_scale = rng.randf_range(1.0, 1.2)
		t.main = self
		t.position = _random_free_spot(16.0, c, rad)
		add_child(t)
		rebuild_obstacles()
	for i in MAGIC_PER_ZONE:
		spawn_rock(_random_free_spot(16.0, c, rad), z, true)
		rebuild_obstacles()


func rebuild_obstacles() -> void:
	obstacle_pos.clear()
	obstacle_rad.clear()
	for t in get_tree().get_nodes_in_group("tree"):
		obstacle_pos.append(t.global_position)
		obstacle_rad.append(t.trunk_radius + 1.4)
	for ch in get_tree().get_nodes_in_group("chest"):
		obstacle_pos.append(ch.global_position)
		obstacle_rad.append(2.4)
	for r in rocks:
		if is_instance_valid(r) and r.is_inside_tree():
			obstacle_pos.append(r.global_position)
			obstacle_rad.append(r.radius + 1.2)


const ROUTE_DETOUR_COST := 12.0   # « coût » d'un mètre de détour, en PV de barricade
var base_radius := 0.0
var base_radius_t := 0.0


## Choisit par où un squelette approche la sphère : il compare le chemin direct et des
## chemins qui contournent (points autour de la base). Coût = PV des constructions à
## traverser + détour. Un peu de hasard pour qu'ils ne s'agglutinent pas tous au même endroit.
## Renvoie un point de passage, ou la position de la sphère pour aller tout droit.
func choose_route(from: Vector3, to: Vector3, noise: float) -> Vector3:
	if structures.is_empty() or base_radius <= 0.0:
		return to
	var rel := Vector2(from.x - to.x, from.z - to.z)
	var dist := rel.length()
	var ring := base_radius + 4.0
	if dist <= ring + 1.0:
		return to
	var bearing := atan2(rel.y, rel.x)
	var best_cost := INF
	var best := to
	var offsets := [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4]
	for i in offsets.size():
		var off: float = offsets[i]
		var a := bearing + off
		var wp := to + Vector3(cos(a), 0, sin(a)) * ring
		var cost := _blocking_hp(wp, to)
		if off != 0.0:
			cost += _blocking_hp(from, wp)
			cost += (from.distance_to(wp) + ring - dist) * ROUTE_DETOUR_COST
		else:
			cost += _blocking_hp(from, wp)
		# préférence, pas obligation : ±20 % de hasard propre à chaque squelette
		cost *= 1.0 + 0.4 * (fmod(noise * 7.13 + i * 0.618, 1.0) - 0.5)
		if cost < best_cost:
			best_cost = cost
			best = to if off == 0.0 else wp
	return best


## Somme des PV des constructions traversées par un segment (à hauteur de squelette).
func _blocking_hp(a: Vector3, b: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var from := Vector3(a.x, 0.5, a.z)
	var to := Vector3(b.x, 0.5, b.z)
	var exclude: Array[RID] = []
	var total := 0.0
	for k in 6:
		var q := PhysicsRayQueryParameters3D.create(from, to, 8 | 64)
		q.exclude = exclude
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var c = r.collider
		exclude.append(r.rid)
		if c.has_meta("structure"):
			c = c.get_meta("structure")
			if is_instance_valid(c):
				exclude.append(c.get_rid())
		if is_instance_valid(c) and c.is_in_group("structure"):
			total += c.hp
	return total


func _update_base_radius(delta: float) -> void:
	base_radius_t -= delta
	if base_radius_t > 0.0:
		return
	base_radius_t = 1.0
	base_radius = 0.0
	if orb == null:
		return
	for st in structures.values():
		if is_instance_valid(st):
			var d := Vector2(st.global_position.x - orb.global_position.x, st.global_position.z - orb.global_position.z).length()
			if d < 35.0:
				base_radius = maxf(base_radius, d + 2.0)


## Force de répulsion pour que les zombies contournent arbres, rochers et congénères.
func avoidance(z: Node3D) -> Vector3:
	var push := Vector3.ZERO
	var p := z.global_position
	for i in obstacle_pos.size():
		var d := p - obstacle_pos[i]
		d.y = 0.0
		var l := d.length()
		var rad: float = obstacle_rad[i] + (z.size_mult - 1.0) * 0.9
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


func place_structure(piece: int, xform: Transform3D, key: String, mat_type := 0) -> void:
	var s := StructureScript.new()
	s.piece = piece
	s.material_type = mat_type
	s.key = key
	s.main = self
	s.transform = xform
	add_child(s)
	structures[key] = s
	Sfx.play("build", -6.0)


# ------------------------------------------------------------------ boucle de jeu

func _physics_process(delta: float) -> void:
	zombie_cache = get_tree().get_nodes_in_group("zombie")
	_update_base_radius(delta)


func _process(delta: float) -> void:
	_sync_views()
	fireflies.global_position = player.global_position + Vector3(0, 1.5, 0)
	for i in players.size():
		huds[i].update_player(players[i])
	if (state == "boss" or state == "to_boss") and titan and is_instance_valid(titan) and titan.awake:
		hud.set_orb(titan.hp, titan.max_hp, "COLOSSE" if zone == 5 else "TITAN")
	else:
		hud.set_orb(orb.hp, orb.max_hp)
	_update_biome(delta)

	# un joueur près de la sphère peut lancer la suite (E / X)
	# E / X près de la sphère : ouvre le menu de la sphère (lancer la vague, création d'arme)
	var near_orb := false
	for p in players:
		if not p.dead and p.global_position.distance_to(orb.global_position) < 5.5:
			near_orb = true
			if Input.is_action_just_pressed(p.a("interact")) and not p.input_blocked():
				p.hud.open_orb_menu(p)
	var prompt := ""
	match state:
		"idle":
			if Settings.test_mode:
				hud.set_wave("PRÉPARATION", "Approche-toi de la sphère et appuie sur E pour lancer le combat")
			else:
				# mode classique : la défense se lance seule au bout de 1 min 30
				countdown -= delta
				hud.set_wave("DÉFENSE DANS %d s" % int(ceil(countdown)), "Coupe du bois, construis autour de la sphère (E pour lancer plus tôt)")
				if countdown <= 0.0:
					_start_wave(1)
			if near_orb and state == "idle":
				prompt = "[E / X] SPHÈRE"
		"break":
			countdown -= delta
			hud.set_wave("%sVAGUE %d/%d DANS %d s" % [_sphere_prefix(), wave + 1, TOTAL_WAVES, int(ceil(countdown))], "Coupe du bois et renforce tes défenses !")
			if near_orb:
				prompt = "[E / X] SPHÈRE"
			if countdown <= 0.0:
				_start_wave(wave + 1)
		"wave":
			_update_spawning(delta)
			var alive := 0
			for zz in get_tree().get_nodes_in_group("zombie"):
				if not zz.guard:
					alive += 1
			var remaining := alive + to_spawn + bosses_left + archers_left + angels_left
			hud.set_wave("%sVAGUE %d/%d" % [_sphere_prefix(), wave, TOTAL_WAVES], "Squelettes restants : %d" % remaining)
			if remaining == 0:
				_end_wave()
		"explore":
			var go := false
			var sn := 2 if zone <= 2 else (3 if zone <= 4 else 4)
			var hint: String = {2: "La forêt s'est ouverte au nord : rejoins la 2e sphère (suis la lumière)",
				3: "Construis autour de la 3e sphère, là où se tenait le titan",
				4: "Monte l'escalier de nuages au nord du volcan : la 4e sphère flotte dans le ciel"}[sn]
			if Settings.test_mode:
				hud.set_wave("EXPLORATION", hint)
			else:
				countdown -= delta
				hud.set_wave("%de SPHÈRE : DÉFENSE DANS %d s" % [sn, int(ceil(countdown))], hint)
				go = countdown <= 0.0 and zone2_unlocked and (zone == 2 or zone == 4 or zone == 5)
			if near_orb and (zone == 2 or zone == 4 or zone == 5):
				prompt = "[E / X] SPHÈRE"
			if go:
				if orb2_beacon:
					orb2_beacon.queue_free()
					orb2_beacon = null
				_start_wave(1)
		"to_boss":
			var sky_boss := zone == 5
			var bname := "COLOSSE DES NUÉES" if sky_boss else "TITAN DE LAVE"
			var bhint := "Monte l'escalier de nuages au nord du volcan, puis la passerelle" if sky_boss else "Rejoins la zone volcanique, à l'ouest de la 2e sphère (suis la lueur rouge)"
			if Settings.test_mode:
				hud.set_wave(bname, bhint + " : approche-toi pour le réveiller")
			else:
				countdown -= delta
				hud.set_wave("%s SE RÉVEILLE DANS %d s" % ["LE COLOSSE" if sky_boss else "LE TITAN", int(ceil(countdown))], bhint)
			var wake := zone3_unlocked and not Settings.test_mode and countdown <= 0.0
			if zone3_unlocked and titan and is_instance_valid(titan):
				for p in players:
					if not p.dead and p.global_position.distance_to(titan.global_position) < 40.0:
						wake = true
				if titan.awake:
					wake = true
			if wake:
				_start_boss()
		"boss":
			if zone == 5:
				hud.set_wave("COLOSSE DES NUÉES", "Grêle : décale-toi · Cercles bleus : bouge · Bourrasque : abrite-toi derrière un mur")
			else:
				hud.set_wave("TITAN DE LAVE", "Boules de feu : abrite-toi · Onde de choc : saute · Cercles rouges : bouge !")
		"pre_endless":
			countdown -= delta
			hud.set_wave("DÉFENSE SANS FIN DANS %d s" % int(ceil(countdown)), "Renforce tes défenses autour de la 4e sphère")
			if near_orb:
				prompt = "[E / X] SPHÈRE"
			if countdown <= 0.0:
				_start_endless()
		"endless":
			_update_endless(delta)
			var best := _best_endless()
			hud.set_wave("SANS FIN  %s" % _fmt_time(endless_t), "Niveau des squelettes : %d%s" % [max_level(), ("   ·   record : %s" % _fmt_time(best)) if best > 0.0 else ""])
		"free":
			hud.set_wave("FORÊT LIBÉRÉE", "Les quatre sphères sont sauves. Explore librement !")

	for i in players.size():
		var p = players[i]
		var pr := prompt if (not p.dead and p.global_position.distance_to(orb.global_position) < 5.5) else ""
		# coffres
		if not p.dead:
			for ch in get_tree().get_nodes_in_group("chest"):
				if not ch.opened and p.global_position.distance_to(ch.global_position) < 2.8:
					pr = "[E / X] OUVRIR LE COFFRE"
					if Input.is_action_just_pressed(p.a("interact")) and not p.input_blocked():
						ch.open(p)
					break
		if p.dead and state != "lost":
			if p.can_revive:
				# il reste des vies : retour immédiat sur place (X / E)
				pr = "[E / X] REVENIR ICI   (%d vie%s)" % [p.lives, "s" if p.lives > 1 else ""]
				if Input.is_action_just_pressed(p.a("interact")) and not p.input_blocked():
					p.lives -= 1
					p.add_stat("revives")
					var spot: Vector3 = p.global_position
					var strong: bool = p.has_skill("D8")
					p.respawn(Vector3(spot.x, maxf(spot.y, 0.0) + 0.3, spot.z), 8.0 if strong else REVIVE_INVULN)
					knockback_around(spot, 10.0 if strong else 7.0, 16.0 if strong else 10.0)
					p.hud.show_center("DE RETOUR !", ("Invulnérable 8 s" if strong else "Invulnérable 5 s") + " · %d vie%s restante%s" % [p.lives, "s" if p.lives > 1 else "", "s" if p.lives > 1 else ""], 2.0)
			else:
				p.respawn_t -= delta
				pr = "Plus de vie · réapparition dans %d..." % int(ceil(p.respawn_t))
				if p.respawn_t <= 0.0:
					var spot := respawn_anchor()
					p.respawn(Vector3(spot.x, spot.y + 0.5, spot.z))
		huds[i].set_prompt(pr)
		_lava_damage(p, delta)
		# tombé dans le vide (bord de l'escalier, de la passerelle...) : retour sur l'île / dans la zone
		if not p.dead and p.global_position.y < -15.0:
			var spot := respawn_anchor()
			p.global_position = Vector3(spot.x, spot.y + 0.6, spot.z)
			p.velocity = Vector3.ZERO

	orb_alert_t -= delta
	hud.set_alert("⚠ LA SPHÈRE EST ATTAQUÉE !" if orb_alert_t > 0.0 and fmod(orb_alert_t, 0.5) > 0.2 else "")


## Niveau de difficulté : vague 1 de la sphère 2 = vague 8 de la sphère 1, et ça continue de monter.
func difficulty() -> int:
	match zone:
		2: return wave + ZONE2_DIFFICULTY_OFFSET
		4: return wave + ZONE4_DIFFICULTY_OFFSET
		5: return wave + ZONE5_DIFFICULTY_OFFSET
	return wave


func _sphere_prefix() -> String:
	match zone:
		2: return "SPHÈRE 2 · "
		4: return "SPHÈRE 3 · "
		5: return "SPHÈRE 4 · "
	return ""


func _spawn_center() -> Vector3:
	return zone_center(zone)


func _spawn_radius() -> float:
	return SPAWN_RADIUS if zone == 1 else zone_radius(zone) - 5.0


## Région musicale de la zone en cours : forêt (« »), volcan (titan + 3e sphère), ciel (colosse + 4e sphère).
func music_region() -> String:
	if zone == 3 or zone == 4:
		return "volcano"
	if zone >= 5:
		return "sky"
	return ""


func _start_wave(n: int) -> void:
	wave = n
	state = "wave"
	Music.play_region("battle", music_region())
	var d := difficulty()
	# zone 1 (au pistolet) : beaucoup moins de squelettes ; sphères 2 et 3 : 1/3 de moins qu'avant
	to_spawn = (3 + (d - 1) * 2) if zone == 1 else int(round((5 + (d - 1) * 3) * LATE_COUNT_MULT * (SKY_COUNT_MULT if zone == 5 else FEWER_MULT)))
	bosses_left = n / 5   # mini-boss à la vague 5, deux boss à la vague 10
	archers_left = 0
	if zone == 2:
		archers_left = 1 + n / 2             # 2e sphère : 1 à 6 archers
	elif zone == 4:
		archers_left = 2 + (n * 6) / 10      # 2 à 8 archers
	elif zone == 5:
		archers_left = 3 + (n * 7) / 10      # île des nuages : 3 à 10 archers
	angels_left = mini(7, 2 + n / 2) if zone == 5 else 0   # anges : 2 à 7
	wave_levels = _wave_levels(to_spawn)
	spawn_interval = maxf(0.3, 1.3 - d * 0.09)
	spawn_timer = 1.5

	# Directions d'arrivée (1 à 3 selon la difficulté), bien espacées
	spawn_angles.clear()
	var dirs := 1 if d <= 2 else (2 if d <= 6 else 3)
	var base := rng.randf() * TAU
	for i in dirs:
		var a := base + TAU * i / dirs + rng.randf_range(-0.3, 0.3)
		if zone == 2 or zone == 4 or zone == 5:
			# pas d'apparition côté couloir (+Z depuis la 2e sphère, +X depuis la 3e, +Z / passerelle pour l'île)
			var diff := wrapf(a - (0.0 if zone == 4 else PI * 0.5), -PI, PI)
			if absf(diff) < 0.6:
				a += 1.2 * (1.0 if diff >= 0.0 else -1.0)
		spawn_angles.append(a)
	for a in spawn_angles:
		var marker := _make_spawn_marker()
		marker.position = _spawn_center() + Vector3(cos(a), 0, sin(a)) * _spawn_radius()
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
	if to_spawn <= 0 and bosses_left <= 0 and archers_left <= 0 and angels_left <= 0:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = spawn_interval
	if angels_left > 0 and (to_spawn <= 0 or rng.randf() < 0.15):
		angels_left -= 1
		_spawn_zombie(false, true, true)
	elif archers_left > 0 and (to_spawn <= 0 or rng.randf() < 0.3):
		archers_left -= 1
		_spawn_zombie(false, true)
	elif to_spawn > 0:
		to_spawn -= 1
		_spawn_zombie(false)
	else:
		bosses_left -= 1
		_spawn_zombie(true)


func _spawn_zombie(boss: bool, archer := false, angel := false) -> void:
	var z := ZombieScript.new()
	z.archer = archer
	z.angel = angel
	# niveau : les boss sont au niveau maximum de la vague ; les autres suivent la liste de la vague
	var lvl := max_level()
	if not boss:
		lvl = wave_levels.pop_back() if not archer and not wave_levels.is_empty() else _roll_level()
	z.set_level(lvl)
	if angel:
		z.max_hp *= 4.0      # anges : beaucoup de PV (mais très vulnérables à la tête)
	elif archer:
		z.max_hp *= 0.6
	if boss:
		z.is_boss = true
		z.size_mult = 1.9
		z.max_hp *= 14.0
		z.speed *= 0.75 * 0.9   # boss ralenti de 10 %
		z.damage *= 3.0
	z.hp = z.max_hp
	z.main = self
	z.orb = orb
	z.player = nearest_player(z.position)
	var a: float = spawn_angles[rng.randi() % spawn_angles.size()] + rng.randf_range(-0.18, 0.18)
	var r := _spawn_radius() + rng.randf_range(-2.5, 2.5)
	z.position = _spawn_center() + Vector3(cos(a) * r, 0.05 + (6.0 if angel else 0.0), sin(a) * r)
	add_child(z)
	if boss:
		hud.flash_message("UN BOSS EST APPARU !")


## Niveau MAXIMUM des squelettes d'une vague (1 ou 2 squelettes l'ont forcément, les autres
## sont nettement plus bas). Il monte à chaque vague et redescend au début de chaque nouvelle sphère :
##   zone 1 : 1, 3, 4, 5, 7, 8, 9, 10, 12, 13 ; 2e sphère : 12 à 21 ; 3e sphère : 21 à 30.
func max_level() -> int:
	if state == "endless":
		return ENDLESS_START_LEVEL + int(endless_t / ENDLESS_LEVEL_EVERY)
	match zone:
		2: return wave + 11
		4: return wave + 20
		5: return wave + 28     # 4e sphère (nuages) : 29 à 38
	return 1 if wave <= 1 else roundi(wave * 1.3)


## Niveaux de tous les squelettes d'une vague (hors boss et archers), mélangés.
func _wave_levels(count: int) -> Array:
	var m := max_level()
	var out := []
	var forced := 2 if count >= 15 else 1
	for i in count:
		out.append(m if i < forced else _roll_level(count >= 20))
	out.shuffle()
	return out


## Niveau d'un squelette sous le maximum : grosse disparité (souvent 1 à 6 niveaux de moins,
## parfois bien plus) ; dans les grosses vagues, de très rares niveaux 1-2.
func _roll_level(big_wave := false) -> int:
	var m := max_level()
	if big_wave and rng.randf() < 0.015:
		return rng.randi_range(1, 2)
	var r := rng.randf()
	var below := 1
	if r < 0.20:
		below = 1
	elif r < 0.40:
		below = 2
	elif r < 0.58:
		below = 3
	elif r < 0.73:
		below = 4
	elif r < 0.85:
		below = 5
	elif r < 0.93:
		below = 6
	else:
		below = rng.randi_range(7, 10)
	return clampi(m - below, 1, m)


func _end_wave() -> void:
	# compétences : 1 jeton par vague terminée (et une vague survécue de plus)
	for p in players:
		p.gain_tokens(1)
		p.add_stat("waves")
	for m in spawn_markers:
		m.queue_free()
	spawn_markers.clear()
	if wave >= TOTAL_WAVES:
		if zone == 1:
			_complete_zone1()
		elif zone == 2:
			_complete_zone2()
		elif zone == 4:
			_complete_zone4()
		else:
			# 4e sphère sauvée : 1 min (+ report) puis la défense sans fin
			state = "pre_endless"
			countdown = ENDLESS_PREP + carry_time
			carry_time = 0.0
			Music.play_region("game", music_region())
			Sfx.play("win")
			for p in players:
				p.gain_tokens(1)
				if not p.dead:
					p.hp = p.max_hp()
			hud.show_center("VICTOIRE !", "Les quatre sphères sont sauves... mais ils arrivent sans fin.", 5.0)
			hud.show_notice("DÉFENSE SANS FIN dans 1 min : les squelettes arrivent en continu, de plus en plus forts\n(boss, archers, anges...). Tiens le plus longtemps possible : un chronomètre mesure ton record.", 9.0)
		return
	state = "break"
	Music.play_region("game", music_region())
	countdown = BREAK_TIME + carry_time
	carry_time = 0.0
	for p in players:
		p.wood = mini(p.wood + 50, p.RES_MAX)
		if not p.dead:
			p.hp = p.max_hp()
	orb.repair(150.0)
	hud.show_center("VAGUE %d TERMINÉE" % wave, "+50 bois · vie restaurée · sphère réparée (+150)", 3.0)


# ------------------------------------------------------------------ zone 2

func _complete_zone1() -> void:
	state = "explore"
	countdown = ZONE2_TIME + carry_time
	carry_time = 0.0
	Music.play_region("game", music_region())
	Sfx.play("win")
	for p in players:
		p.wood = mini(p.wood + 100, p.RES_MAX)
		if not p.dead:
			p.hp = p.max_hp()
	hud.show_center("VICTOIRE !", "La 1re sphère est sauve... mais la forêt s'ouvre au nord !", 5.0)
	rifle_craftable = true
	get_tree().create_timer(1.0, false).timeout.connect(_unlock_zone2)
	get_tree().create_timer(3.0, false).timeout.connect(func():
		if not player.has_rifle:
			hud.confirm("NOUVELLE ARME", "Tu peux maintenant fabriquer le FUSIL D'ASSAUT\n(30 balles, tir automatique, munitions illimitées).\n\nLe fabriquer maintenant ?", craft_rifle))


func _unlock_zone2() -> void:
	if zone2_unlocked:
		return
	zone2_unlocked = true
	for n in zone2_blockers:
		if is_instance_valid(n):
			n.queue_free()
	zone2_blockers.clear()
	for m in storm_mats:
		m.set_shader_parameter("gap", CORRIDOR_HALF)
	_build_zone2()
	# la 2e sphère devient la seule cible des squelettes
	orb2 = OrbScript.new()
	orb2.position = ZONE2_CENTER + ORB_OFFSET
	add_child(orb2)
	orb2.damaged.connect(_on_orb_damaged)
	orb2.destroyed.connect(_on_orb_destroyed)
	orb1.damaged.disconnect(_on_orb_damaged)
	orb1.destroyed.disconnect(_on_orb_destroyed)
	orb = orb2
	zone = 2
	wave = 0
	orb2_beacon = _make_beacon()
	orb2_beacon.position = ZONE2_CENTER + ORB_OFFSET
	add_child(orb2_beacon)
	rebuild_obstacles()
	hud.show_notice("NOUVELLE ZONE : la forêt d'érables pourpres.\nUne 2e sphère t'attend au nord (suis la colonne de lumière).\nLes vagues démarrent seules au bout de 2 min (ou plus tôt avec E / X).\nLes squelettes n'attaqueront plus que cette sphère.", 10.0)


func craft_rifle() -> void:
	if player.has_rifle:
		return
	for p in players:
		p.unlock_rifle()
	Sfx.play("build", 0.0, 0.7)
	hud.show_center("FUSIL D'ASSAUT", "Fabriqué ! Touche 2 / LB-RB pour l'équiper", 3.0)


func _make_beacon(color := Color(0.3, 0.9, 1.0, 0.45)) -> Node3D:
	var n := Node3D.new()
	var beam := Mats.cylinder(n, 1.2, 1.2, 120.0, null, Vector3(0, 60, 0), Vector3.ZERO, 16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func _build_zone2() -> void:
	var c := ZONE2_CENTER
	# Mur de tempête autour de la zone 2 et le long du couloir
	var sh := Shader.new()
	sh.code = STORM_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("gap", CORRIDOR_HALF)
	storm_mats.append(mat)
	var wall := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = ZONE2_RADIUS
	cm.bottom_radius = ZONE2_RADIUS
	cm.height = 30.0
	cm.radial_segments = 128
	cm.cap_top = false
	cm.cap_bottom = false
	wall.mesh = cm
	wall.material_override = mat
	wall.position = c + Vector3(0, 15, 0)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	var side_mat := ShaderMaterial.new()
	side_mat.shader = sh
	for x in [-CORRIDOR_HALF, CORRIDOR_HALF]:
		var sw := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 30.0, CORRIDOR_Z.y - CORRIDOR_Z.x + 4.0)
		sw.mesh = bm
		sw.material_override = side_mat
		sw.position = Vector3(x, 15.0, (CORRIDOR_Z.x + CORRIDOR_Z.y) * 0.5)
		sw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sw)

	# Forêt de fond autour de la zone 2 (érables et bouleaux)
	var all: Array = []
	all.append_array(Nature.maples())
	all.append_array(Nature.birches())
	var entries: Array = []
	var blocked3: Array = []
	for i in 420:
		var a := rng.randf() * TAU
		var r := ZONE2_RADIUS + 3.0 + pow(rng.randf(), 0.8) * 70.0
		var pos := c + Vector3(cos(a) * r, 0, sin(a) * r)
		if Vector2(pos.x, pos.z).length() < MAP_RADIUS + 25.0:
			continue
		if absf(pos.x) < CORRIDOR_HALF + 3.0 and pos.z > CORRIDOR_Z.x - 4.0:
			continue
		var sc := rng.randf_range(0.9, 1.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
		if _in_zone3_footprint(pos, 6.0):
			blocked3.append([rng.randi() % all.size(), Transform3D(b, pos)])
		else:
			entries.append([rng.randi() % all.size(), Transform3D(b, pos)])
	_add_forest(all, entries)
	if not zone3_unlocked:
		zone3_blockers.append_array(_add_forest(all, blocked3))
	# Haies de sapins le long du couloir
	var pines := Nature.pines()
	var cor: Array = []
	for i in 70:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * (CORRIDOR_HALF + rng.randf_range(2.5, 14.0)), 0, rng.randf_range(CORRIDOR_Z.x - 2.0, CORRIDOR_Z.y + 2.0))
		var sc := rng.randf_range(0.9, 1.4)
		cor.append([rng.randi() % pines.size(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), pos)])
	_add_forest(pines, cor)

	# Arbres coupables
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < ZONE2_TREE_COUNT and tries < 4000:
		tries += 1
		var r := sqrt(rng.randf_range(0.02, 1.0)) * (ZONE2_RADIUS - 5.0)
		if r < 11.0:
			continue
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < CORRIDOR_HALF + 2.0 and p.z > c.z + ZONE2_RADIUS - 14.0:
			continue   # garder l'entrée du couloir dégagée
		var ok := true
		for q in placed:
			if q.distance_to(p) < 5.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var t := TreeScript.new()
		t.species = 1 if rng.randf() < 0.65 else 2
		t.kind = rng.randi() % 4
		t.tree_scale = rng.randf_range(0.8, 1.2)
		t.main = self
		t.position = p
		add_child(t)
	rebuild_obstacles()
	for i in 22:
		spawn_rock(_random_free_spot(12.0, c, ZONE2_RADIUS), 2)
		rebuild_obstacles()
	for i in PICKUPS_PER_ZONE:
		spawn_pickup(2)
	for i in CHESTS_PER_ZONE:
		_spawn_chest(c, ZONE2_RADIUS, true, 2)
	_spawn_magic(2)

	# Végétation : herbe mauve, plantes dorées, buissons violets (zone 2) + herbe du couloir
	var grass2 := Nature.grass_material(Color(0.04, 0.01, 0.05), Color(0.40, 0.14, 0.34), Color(0.55, 0.22, 0.30))
	var not_zone1 := func(w: Vector3) -> bool: return Vector2(w.x, w.z).length() > MAP_RADIUS + 2.0
	_scatter_chunks(Nature.grass(), grass2, 1.3 if high else 0.55, ZONE2_RADIUS + 12.0, 5.0, 0.8, 1.3, 60.0 if high else 40.0, false, 0.0, c, not_zone1)
	var in_corridor := func(w: Vector3) -> bool: return absf(w.x) < CORRIDOR_HALF + 10.0 and Vector2(w.x, w.z).length() > MAP_RADIUS + 10.0
	_scatter_chunks(Nature.grass(), null, 1.3 if high else 0.55, 24.0, 0.0, 0.8, 1.3, 60.0 if high else 40.0, false, 0.0, Vector3(0, 0, (CORRIDOR_Z.x + CORRIDOR_Z.y) * 0.5), in_corridor)
	var gold := Nature.leaf_material("Flowers.png", Color(0.30, 0.14, 0.02), Color(1.0, 0.70, 0.20), 0.8, 0.05)
	var violet := Nature.leaf_material("Bush_Leaves.png", Color(0.06, 0.01, 0.08), Color(0.45, 0.18, 0.55), 1.2, 0.04)
	for v in [1, 2]:
		_scatter_chunks(Nature.red_plant(v), gold, 0.02, ZONE2_RADIUS + 12.0, 7.0, 0.6, 1.1, 80.0, true, 0.0, c, not_zone1)
	_scatter_chunks(Nature.bush(false), violet, 0.02, ZONE2_RADIUS + 12.0, 7.0, 1.0, 2.0, 80.0, true, 0.0, c, not_zone1)


# ------------------------------------------------------------------ zone volcanique (titan puis 3e sphère)

func _complete_zone2() -> void:
	state = "to_boss"
	countdown = BOSS_TRAVEL_TIME   # le report éventuel (carry_time) est gardé pour la 3e sphère
	Music.play_region("game", "volcano")   # en route vers le volcan
	Sfx.play("win")
	for p in players:
		p.wood = mini(p.wood + 100, p.RES_MAX)
		if not p.dead:
			p.hp = p.max_hp()
	hud.show_center("VICTOIRE !", "La 2e sphère est sauve... mais la terre gronde à l'ouest !", 5.0)
	get_tree().create_timer(1.0, false).timeout.connect(_unlock_zone3)


func _unlock_zone3() -> void:
	if zone3_unlocked:
		return
	zone3_unlocked = true
	for n in zone3_blockers:
		if is_instance_valid(n):
			n.queue_free()
	zone3_blockers.clear()
	for m in storm_mats:
		m.set_shader_parameter("gap2", CORRIDOR2_HALF)
	_build_zone3()
	zone = 3
	wave = 0
	if orb2_beacon and is_instance_valid(orb2_beacon):
		orb2_beacon.queue_free()
	orb2_beacon = _make_beacon(Color(1.0, 0.35, 0.1, 0.45))
	orb2_beacon.position = ZONE3_CENTER
	add_child(orb2_beacon)
	rebuild_obstacles()
	hud.show_notice("NOUVELLE ZONE : le volcan, à l'ouest de la 2e sphère (suis la lueur rouge).\nUn TITAN DE LAVE s'y dresse : il se réveille dans 1 min, ou dès que tu approches.\nAucune sphère à défendre ici, mais chaque mort te coûte une vie.\nUne fois vaincu, une 3e sphère apparaîtra à sa place.", 11.0)


func _build_zone3() -> void:
	var c := ZONE3_CENTER
	var sh := Shader.new()
	sh.code = STORM_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("gap2", CORRIDOR2_HALF)
	mat.set_shader_parameter("color", Color(1.0, 0.35, 0.12, 1.0))
	storm_mats.append(mat)
	var wall := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = ZONE3_RADIUS
	cm.bottom_radius = ZONE3_RADIUS
	cm.height = 30.0
	cm.radial_segments = 128
	cm.cap_top = false
	cm.cap_bottom = false
	wall.mesh = cm
	wall.material_override = mat
	wall.position = c + Vector3(0, 15, 0)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	var side_mat := ShaderMaterial.new()
	side_mat.shader = sh
	side_mat.set_shader_parameter("color", Color(1.0, 0.35, 0.12, 1.0))
	for dz in [-CORRIDOR2_HALF, CORRIDOR2_HALF]:
		var sw := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CORRIDOR2_X.y - CORRIDOR2_X.x + 4.0, 30.0, 0.05)
		sw.mesh = bm
		sw.material_override = side_mat
		sw.position = Vector3((CORRIDOR2_X.x + CORRIDOR2_X.y) * 0.5, 15.0, ZONE2_CENTER.z + dz)
		sw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sw)

	# Décor de fond : arbres calcinés, colonnes de basalte, volcans au loin
	var burnt: Array = [Volcanic.mesh("meshy_tree")]
	var entries: Array = []
	for i in 260:
		var a := rng.randf() * TAU
		var r := ZONE3_RADIUS + 3.0 + pow(rng.randf(), 0.8) * 60.0
		var pos := c + Vector3(cos(a) * r, 0, sin(a) * r)
		if Vector2(pos.x - ZONE2_CENTER.x, pos.z - ZONE2_CENTER.z).length() < ZONE2_RADIUS + 6.0:
			continue
		if absf(pos.z - ZONE2_CENTER.z) < CORRIDOR2_HALF + 3.0 and pos.x > c.x:
			continue
		var sc := rng.randf_range(0.9, 1.6)
		entries.append([0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc) * 8.0), pos)])   # arbre Meshy : hauteur 1 m -> 7 à 13 m
	_add_forest(burnt, entries)
	# Rochers de basalte (modèles Blender + shader à fissures de lave) : éperons autour de la zone,
	# petits blocs à l'intérieur (sans collision, assez bas pour ne gêner personne)
	var rock_entries: Array = []
	for i in 70:
		var a := rng.randf() * TAU
		var r := ZONE3_RADIUS + rng.randf_range(3.0, 45.0)
		var pos := c + Vector3(cos(a) * r, -0.2, sin(a) * r)
		if _in_zone2_footprint(pos, 8.0) or (absf(pos.z - ZONE2_CENTER.z) < CORRIDOR2_HALF + 4.0 and pos.x > c.x):
			continue
		var sc := rng.randf_range(2.0, 6.5)
		rock_entries.append([rng.randi() % 4, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.5), sc)), pos)])
	for i in 45:
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.0, ZONE3_RADIUS - 3.0)
		var pos := c + Vector3(cos(a) * r, -0.05, sin(a) * r)
		if absf(pos.z - c.z) < CORRIDOR2_HALF + 2.0 and pos.x > c.x:
			continue
		var sc := rng.randf_range(0.25, 0.6)
		rock_entries.append([[0, 2, 3][rng.randi() % 3], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * 0.7, sc)), pos)])
	for e in rock_entries:
		e[0] = 0
	for mmi in _add_forest([Volcanic.mesh("meshy_rock")], rock_entries):
		(mmi as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Volcans au loin : cônes à cratère, coulées qui descendent des flancs, panache de fumée
	for v in [[Vector3(-330, 0, -120), 75.0], [Vector3(-300, 0, -260), 95.0], [Vector3(-260, 0, -40), 60.0]]:
		var vp: Vector3 = v[0]
		var vh: float = v[1]
		var cone := MeshInstance3D.new()
		cone.mesh = Volcanic.mesh("volcano")
		cone.material_override = Volcanic.volcano_material()
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(vh * 1.1, vh, vh * 1.1)), vp + Vector3(0, -2.0, 0))
		add_child(cone)
		var gl := OmniLight3D.new()
		gl.light_color = Color(1.0, 0.4, 0.1)
		gl.light_energy = 6.0
		gl.omni_range = vh * 0.6
		gl.position = vp + Vector3(0, vh + 4.0, 0)
		add_child(gl)
		var smoke := CPUParticles3D.new()
		smoke.amount = 24
		smoke.lifetime = 9.0
		smoke.preprocess = 9.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = vh * 0.08
		smoke.direction = Vector3.UP
		smoke.spread = 12.0
		smoke.gravity = Vector3(1.5, 2.0, 0)
		smoke.initial_velocity_min = 3.0
		smoke.initial_velocity_max = 5.0
		smoke.scale_amount_min = vh * 0.12
		smoke.scale_amount_max = vh * 0.22
		var sq := QuadMesh.new()
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.vertex_color_use_as_albedo = true
		smat.albedo_texture = Volcanic.soft_dot()
		sq.material = smat
		smoke.mesh = sq
		var sramp := Gradient.new()
		sramp.set_color(0, Color(0.9, 0.35, 0.1, 0.0))
		sramp.add_point(0.15, Color(0.6, 0.25, 0.12, 0.45))
		sramp.set_color(sramp.get_point_count() - 1, Color(0.12, 0.08, 0.08, 0.0))
		smoke.color_ramp = sramp
		smoke.position = vp + Vector3(0, vh - 2.0, 0)
		add_child(smoke)

	# Colonnes de fumée grise qui montent du sol (fissures)
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(20.0, ZONE3_RADIUS + 20.0)
		var smk_p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var smk := CPUParticles3D.new()
		smk.amount = 16
		smk.lifetime = 7.0
		smk.preprocess = 7.0
		smk.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smk.emission_sphere_radius = 0.4
		smk.direction = Vector3.UP
		smk.spread = 6.0
		smk.gravity = Vector3(0.35, 0.6, 0.1)
		smk.initial_velocity_min = 1.2
		smk.initial_velocity_max = 1.8
		smk.scale_amount_min = 1.2
		smk.scale_amount_max = 2.6
		var smk_q := QuadMesh.new()
		var smk_m := StandardMaterial3D.new()
		smk_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smk_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		smk_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smk_m.vertex_color_use_as_albedo = true
		smk_m.albedo_texture = Volcanic.soft_dot()
		smk_q.material = smk_m
		smk.mesh = smk_q
		var smk_r := Gradient.new()
		smk_r.set_color(0, Color(0.55, 0.5, 0.55, 0.0))
		smk_r.add_point(0.2, Color(0.55, 0.5, 0.55, 0.35))
		smk_r.set_color(smk_r.get_point_count() - 1, Color(0.4, 0.38, 0.45, 0.0))
		smk.color_ramp = smk_r
		smk.position = smk_p
		add_child(smk)

	# Coulées de lave qui serpentent dans la zone (brûlent les joueurs qui marchent dedans) ;
	# le centre (titan puis 3e sphère) et le couloir d'arrivée restent dégagés
	lava_pools.clear()
	var flows := 0
	var guard := 0
	while flows < 6 and guard < 80:
		guard += 1
		var a0 := rng.randf() * TAU
		var p := c + Vector3(cos(a0) * (ZONE3_RADIUS - 4.0), 0, sin(a0) * (ZONE3_RADIUS - 4.0))
		if absf(p.z - c.z) < CORRIDOR2_HALF + 8.0 and p.x > c.x:
			continue
		var heading := atan2(c.z - p.z, c.x - p.x) + rng.randf_range(-0.7, 0.7)
		var pts := PackedVector3Array()
		var half := PackedFloat32Array()
		var n := rng.randi_range(22, 36)
		var base_w := rng.randf_range(1.3, 2.3)
		for i in n:
			pts.append(p)
			var tt := float(i) / (n - 1)
			# s'affine à la source, s'élargit en bas de coulée (petit lac)
			half.append(base_w * (0.55 + 0.45 * minf(tt * 4.0, 1.0)) * (1.0 + 0.6 * smoothstep(0.75, 1.0, tt)) * (0.85 + 0.3 * rng.randf()))
			heading += rng.randf_range(-0.28, 0.28)
			p += Vector3(cos(heading), 0, sin(heading)) * 1.8
			var dc := Vector2(p.x - c.x, p.z - c.z).length()
			if dc < 22.0 or dc > ZONE3_RADIUS - 2.0 or (absf(p.z - c.z) < CORRIDOR2_HALF + 3.0 and p.x > c.x):
				break
		if pts.size() < 12:
			continue
		var ok := true
		for lp in lava_pools:
			for q in pts:
				if (lp[0] as Vector3).distance_to(q) < lp[1] + 5.0:
					ok = false
		if not ok:
			continue
		lava_pools.append_array(Volcanic.build_flow(self, pts, half))
		flows += 1

	# Sapins calcinés à couper (le centre reste dégagé pour le titan puis la 3e sphère)
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < ZONE3_TREE_COUNT and tries < 4000:
		tries += 1
		var r := sqrt(rng.randf_range(0.02, 1.0)) * (ZONE3_RADIUS - 5.0)
		if r < 16.0:
			continue
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.z - c.z) < CORRIDOR2_HALF + 2.0 and p.x > c.x + ZONE3_RADIUS - 14.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 5.0:
				ok = false
				break
		for lp in lava_pools:
			if (lp[0] as Vector3).distance_to(p) < lp[1] + 2.5:
				ok = false
		if not ok:
			continue
		placed.append(p)
		var t := TreeScript.new()
		t.species = 3
		t.kind = rng.randi() % 5
		t.tree_scale = rng.randf_range(0.8, 1.2)
		t.main = self
		t.position = p
		add_child(t)
	# le titan, au centre
	titan = TitanScript.new()
	titan.main = self
	titan.position = c
	if players.size() > 1:
		titan.max_hp *= TitanScript.COOP_HP_MULT
		titan.hp = titan.max_hp
	add_child(titan)
	titan.defeated.connect(_on_titan_defeated)
	rebuild_obstacles()
	for i in 22:
		spawn_rock(_random_free_spot(14.0, c, ZONE3_RADIUS), 3)
		rebuild_obstacles()
	for i in PICKUPS_PER_ZONE:
		spawn_pickup(3)
	_spawn_magic(3)


func _start_boss() -> void:
	state = "boss"
	if titan and is_instance_valid(titan):
		titan.wake()
	Music.play_region("boss", music_region())
	if zone == 5:
		hud.show_center("COLOSSE DES NUÉES", "Il ne bouge pas, mais la foudre et le vent lui obéissent.", 3.5)
	else:
		hud.show_center("TITAN DE LAVE", "Il ne bouge pas, mais il frappe fort et de loin.", 3.5)


func _on_titan_defeated() -> void:
	state = "titan_down"
	var sky_boss := zone == 5
	var title := "COLOSSE VAINCU !" if sky_boss else "TITAN VAINCU !"
	hud.set_wave(title, ("Une 4e sphère va apparaître à sa place..." if sky_boss else "Une 3e sphère va apparaître à sa place..."))
	hud.show_center(title, "+300 bois · +150 pierre · +3 jetons de compétence" + (" · 3 tas d'os" if sky_boss else ""), 4.0)
	for p in players:
		p.gain_tokens(3)
	Music.play_region("game", music_region())
	for p in players:
		p.wood = mini(p.wood + 300, p.RES_MAX)
		p.stone = mini(p.stone + 150, p.RES_MAX)
		if not p.dead:
			p.hp = p.max_hp()
	get_tree().create_timer(4.5, false).timeout.connect(_start_sky_defense if sky_boss else _start_zone4)


## 3e sphère, à l'emplacement du titan : 3 min (+ report éventuel) avant la 1re vague.
func _start_zone4() -> void:
	if zone >= 4:
		return
	orb3 = OrbScript.new()
	orb3.position = orb_cell(ZONE3_CENTER)
	add_child(orb3)
	orb3.damaged.connect(_on_orb_damaged)
	orb3.destroyed.connect(_on_orb_destroyed)
	if orb.damaged.is_connected(_on_orb_damaged):
		orb.damaged.disconnect(_on_orb_damaged)
		orb.destroyed.disconnect(_on_orb_destroyed)
	orb = orb3
	zone = 4
	wave = 0
	state = "explore"
	countdown = ZONE4_TIME + carry_time
	carry_time = 0.0
	if orb2_beacon and is_instance_valid(orb2_beacon):
		orb2_beacon.queue_free()
	orb2_beacon = _make_beacon()
	orb2_beacon.position = orb_cell(ZONE3_CENTER)
	add_child(orb2_beacon)
	for i in CHESTS_PER_ZONE:
		_spawn_chest(ZONE3_CENTER, ZONE3_RADIUS, true, 3)
	rebuild_obstacles()
	hud.show_notice("3e SPHÈRE : défends-la contre 10 nouvelles vagues.\nLa défense commence dans 3 min (ou plus tôt avec E / X près de la sphère).\nDeux coffres gardés sont apparus dans la zone volcanique.", 9.0)


# ------------------------------------------------------------------ zone céleste (4e sphère)

func _complete_zone4() -> void:
	state = "to_boss"
	countdown = BOSS_TRAVEL_TIME   # le report éventuel est gardé pour la 4e sphère
	Music.play_region("game", "sky")   # l'escalier de nuages apparaît
	Sfx.play("win")
	for p in players:
		p.wood = mini(p.wood + 200, p.RES_MAX)
		if not p.dead:
			p.hp = p.max_hp()
	hud.show_center("VICTOIRE !", "La 3e sphère est sauve... un escalier de nuages s'élève vers le ciel !", 5.0)
	_unlock_sky()


func _unlock_sky() -> void:
	if sky_unlocked:
		return
	sky_unlocked = true
	_build_sky()
	zone = 5
	wave = 0
	# le colosse des nuées, au centre de l'île (la 4e sphère apparaîtra à sa place)
	titan = SkyTitanScript.new()
	titan.main = self
	titan.position = SKY_CENTER
	if players.size() > 1:
		titan.max_hp *= TitanScript.COOP_HP_MULT
		titan.hp = titan.max_hp
	add_child(titan)
	titan.defeated.connect(_on_titan_defeated)
	if orb2_beacon and is_instance_valid(orb2_beacon):
		orb2_beacon.queue_free()
	orb2_beacon = _make_beacon(Color(0.7, 0.85, 1.0, 0.4))
	orb2_beacon.position = SKY_CENTER
	add_child(orb2_beacon)
	rebuild_obstacles()
	hud.show_notice("NOUVELLE ZONE : l'île de nuages, dans le ciel au nord du volcan.\nMonte l'escalier de nuages, puis la passerelle. Le COLOSSE DES NUÉES s'y dresse :\nil se réveille dans 1 min, ou dès que tu approches. La 4e sphère apparaîtra à sa place.\nNouvelle ressource : les NUAGES (petits nuages à briser à la hache, on passe au travers).", 12.0)


## Colosse vaincu : la 4e sphère apparaît au centre de l'île ; défense dans 2 min 30 (+ report).
func _start_sky_defense() -> void:
	if orb4 != null:
		return
	orb4 = OrbScript.new()
	orb4.position = orb_cell(SKY_CENTER)
	add_child(orb4)
	orb4.damaged.connect(_on_orb_damaged)
	orb4.destroyed.connect(_on_orb_destroyed)
	if orb.damaged.is_connected(_on_orb_damaged):
		orb.damaged.disconnect(_on_orb_damaged)
		orb.destroyed.disconnect(_on_orb_destroyed)
	orb = orb4
	wave = 0
	state = "explore"
	countdown = SKY_TIME + carry_time
	carry_time = 0.0
	if orb2_beacon and is_instance_valid(orb2_beacon):
		orb2_beacon.queue_free()
	orb2_beacon = _make_beacon(Color(0.8, 0.9, 1.0, 0.4))
	orb2_beacon.position = orb_cell(SKY_CENTER)
	add_child(orb2_beacon)
	rebuild_obstacles()
	hud.show_notice("4e SPHÈRE : défends-la contre 10 vagues, dont des anges squelettes volants.\nLa défense commence dans 2 min 30 (ou plus tôt depuis le menu de la sphère).\nMurs en nuage : 3× plus solides que la pierre.", 9.0)


func _cloud_material(alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.88, 0.97, alpha)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.45, 0.5, 0.68)
	m.emission_energy_multiplier = 0.15
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _build_sky() -> void:
	var cmat := _cloud_material()
	# --- escalier en spirale (1,25 tour) puis passerelle jusqu'à l'île
	var stairs := StaticBody3D.new()
	stairs.collision_layer = 1
	stairs.collision_mask = 0
	add_child(stairs)
	# arbres / rochers qui gêneraient l'escalier : retirés
	for n in get_tree().get_nodes_in_group("tree") + get_tree().get_nodes_in_group("rock"):
		if Vector2(n.global_position.x - STAIR_CENTER.x, n.global_position.z - STAIR_CENTER.z).length() < STAIR_RADIUS + 6.0:
			if n.is_in_group("rock"):
				rocks.erase(n)
			n.queue_free()
	var segs := 44
	var a_end := -PI * 0.5                  # le haut de l'escalier pointe vers le nord (vers l'île)
	var a_start := a_end - TAU * 1.25
	var prev := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / segs
		var a := lerpf(a_start, a_end, t)
		var pt := STAIR_CENTER + Vector3(cos(a) * STAIR_RADIUS, t * SKY_Y, sin(a) * STAIR_RADIUS)
		if i > 0:
			var mid := (prev + pt) * 0.5
			var dir := pt - prev
			var len := dir.length()
			var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(3.6, 0.5, len + 0.5)
			cs.shape = bs
			cs.transform = Transform3D(basis, mid - basis.y * 0.25)
			stairs.add_child(cs)
			# nuages qui forment les marches (apparaissent un à un)
			var step := Node3D.new()
			step.position = mid
			stairs.add_child(step)
			for k in 3:
				var off := basis.x * (k - 1) * 1.1
				Mats.sphere(step, rng.randf_range(0.75, 1.0), cmat, off + Vector3(0, -0.45, 0), 10).scale = Vector3(1.0, 0.55, 1.0)
			step.scale = Vector3.ONE * 0.01
			var tw := step.create_tween()
			tw.tween_interval(i * 0.06)
			tw.tween_property(step, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		prev = pt
	# passerelle droite (au-dessus du mur de tempête du volcan)
	var bridge_len := BRIDGE_Z.y - BRIDGE_Z.x
	var bcs := CollisionShape3D.new()
	var bbs := BoxShape3D.new()
	bbs.size = Vector3(BRIDGE_HALF * 2.0, 0.6, bridge_len)
	bcs.shape = bbs
	bcs.position = Vector3(SKY_CENTER.x, SKY_Y - 0.3, (BRIDGE_Z.x + BRIDGE_Z.y) * 0.5)
	stairs.add_child(bcs)
	for i in int(bridge_len / 1.6):
		var z := BRIDGE_Z.y - i * 1.6
		for side in [-1.0, 0.0, 1.0]:
			Mats.sphere(stairs, rng.randf_range(0.8, 1.05), cmat, Vector3(SKY_CENTER.x + side * 1.3, SKY_Y - 0.55, z), 10).scale = Vector3(1, 0.55, 1)

	# --- l'île : grand disque de nuage (sol à SKY_Y), bord en gros « moutons »
	var island := StaticBody3D.new()
	island.collision_layer = 1
	island.collision_mask = 0
	add_child(island)
	var ics := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = SKY_RADIUS + 2.0
	cyl.height = 2.0
	ics.shape = cyl
	ics.position = SKY_CENTER + Vector3(0, -1.0, 0)
	island.add_child(ics)
	var floor_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = SKY_RADIUS + 2.0
	cm.bottom_radius = SKY_RADIUS - 6.0
	cm.height = 6.0
	cm.radial_segments = 64
	floor_mi.mesh = cm
	var fm := ShaderMaterial.new()
	var fsh := Shader.new()
	fsh.code = CLOUD_GROUND_SHADER
	fm.shader = fsh
	floor_mi.material_override = fm
	floor_mi.position = SKY_CENTER + Vector3(0, -3.0, 0)
	island.add_child(floor_mi)
	for i in 70:
		var a := TAU * i / 70.0 + rng.randf_range(-0.04, 0.04)
		var r := SKY_RADIUS + rng.randf_range(-1.0, 2.5)
		var sz := rng.randf_range(2.0, 3.8)
		Mats.sphere(island, sz, cmat, SKY_CENTER + Vector3(cos(a) * r, rng.randf_range(-2.5, 0.2), sin(a) * r), 10).scale = Vector3(1, 0.65, 1)
	# petits « moutons » posés sur le sol (décor, sans collision)
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = puff
	var xf: Array[Transform3D] = []
	for i in 260:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(0.0, 1.0)) * (SKY_RADIUS - 2.0)
		if r < 9.0:
			continue   # dégagé autour de la sphère
		var sc := rng.randf_range(0.5, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc * rng.randf_range(1.0, 1.8), sc * 0.45, sc))
		xf.append(Transform3D(b, SKY_CENTER + Vector3(cos(a) * r, -0.15, sin(a) * r)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = cmat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(mmi)
	for i in 26:   # dessous bombé
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, SKY_RADIUS - 8.0)
		Mats.sphere(island, rng.randf_range(5.0, 9.0), cmat, SKY_CENTER + Vector3(cos(a) * r, rng.randf_range(-8.0, -5.0), sin(a) * r), 10).scale = Vector3(1, 0.5, 1)
	# bancs de nuages lointains, sous et autour de l'île
	var far := _cloud_material(0.85)
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(SKY_RADIUS + 20.0, SKY_RADIUS + 90.0)
		var c := Mats.sphere(self, rng.randf_range(8.0, 16.0), far, SKY_CENTER + Vector3(cos(a) * r, rng.randf_range(-20.0, 6.0), sin(a) * r), 10)
		c.scale = Vector3(1.6, 0.5, 1.0)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# bord : muret de lumière blanche (limite de la zone)
	var sh := Shader.new()
	sh.code = STORM_SHADER
	var wm := ShaderMaterial.new()
	wm.shader = sh
	wm.set_shader_parameter("color", Color(0.75, 0.85, 1.0, 1.0))
	var wall := MeshInstance3D.new()
	var wcm := CylinderMesh.new()
	wcm.top_radius = SKY_RADIUS
	wcm.bottom_radius = SKY_RADIUS
	wcm.height = 16.0
	wcm.radial_segments = 96
	wcm.cap_top = false
	wcm.cap_bottom = false
	wall.mesh = wcm
	wall.material_override = wm
	wall.position = SKY_CENTER + Vector3(0, 8.0, 0)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	var sun := OmniLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 0.8
	sun.omni_range = 70.0
	sun.position = SKY_CENTER + Vector3(0, 25, 0)
	add_child(sun)
	# petits nuages à récolter (au sol et en l'air)
	for i in CLOUD_GROUND:
		spawn_cloud(false)
	for i in CLOUD_AIR:
		spawn_cloud(true)


## Petit nuage à récolter : au sol ou en l'air ; 1 chance sur 250 d'être magique.
func spawn_cloud(air: bool) -> void:
	var c := CloudResScript.new()
	c.main = self
	c.floating = air
	c.magic = rng.randf() < CloudResScript.MAGIC_CHANCE
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf_range(0.04, 1.0)) * (SKY_RADIUS - 4.0)
	if r < 8.0:
		r += 8.0   # pas sur la sphère
	var h := rng.randf_range(2.2, 4.5) if air else 0.0
	c.position = SKY_CENTER + Vector3(cos(a) * r, h, sin(a) * r)
	add_child(c)


func on_cloud_harvested(c: Node) -> void:
	var air: bool = c.floating
	get_tree().create_timer(rng.randf_range(12.0, 25.0), false).timeout.connect(func(): spawn_cloud(air))


# ------------------------------------------------------------------ défense sans fin

func _start_endless() -> void:
	if state == "endless":
		return
	state = "endless"
	endless_t = 0.0
	endless_spawn_t = 2.0
	endless_boss_t = 50.0
	endless_dir_t = 0.0
	Music.play_any(["endless", "sky_battle", "battle"])
	Sfx.play("horn", -2.0)
	hud.show_center("DÉFENSE SANS FIN", "Tiens le plus longtemps possible !", 3.0)


func _update_endless(delta: float) -> void:
	endless_t += delta
	# directions d'arrivée renouvelées régulièrement
	endless_dir_t -= delta
	if endless_dir_t <= 0.0:
		endless_dir_t = 25.0
		for m in spawn_markers:
			m.queue_free()
		spawn_markers.clear()
		spawn_angles.clear()
		var base := rng.randf() * TAU
		for i in 3:
			var a := base + TAU * i / 3.0 + rng.randf_range(-0.3, 0.3)
			var diff := wrapf(a - PI * 0.5, -PI, PI)
			if absf(diff) < 0.6:
				a += 1.2 * (1.0 if diff >= 0.0 else -1.0)
			spawn_angles.append(a)
			var marker := _make_spawn_marker()
			marker.position = _spawn_center() + Vector3(cos(a), 0, sin(a)) * _spawn_radius()
			add_child(marker)
			spawn_markers.append(marker)
	# flux continu, limité en nombre en même temps (la limite monte doucement)
	var alive := 0
	var angels := 0
	for z in zombie_cache:
		if is_instance_valid(z) and not z.guard and not z.dead:
			alive += 1
			if z.get("angel"):
				angels += 1
	var cap := mini(48, 13 + int(endless_t / 30.0))
	endless_spawn_t -= delta
	endless_boss_t -= delta
	if endless_spawn_t > 0.0 or alive >= cap:
		return
	endless_spawn_t = maxf(0.45, 1.5 - endless_t / 400.0)
	if endless_boss_t <= 0.0:
		endless_boss_t = maxf(25.0, 60.0 - endless_t / 30.0)
		_spawn_zombie(true)
		return
	var r := rng.randf()
	if r < 0.10 and angels < 6:
		_spawn_zombie(false, true, true)
	elif r < 0.30:
		_spawn_zombie(false, true)
	else:
		_spawn_zombie(false)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func _best_endless() -> float:
	var cf := ConfigFile.new()
	if cf.load("user://records.cfg") != OK:
		return 0.0
	return float(cf.get_value("sans_fin", "meilleur", 0.0))


func _save_best_endless(t: float) -> void:
	var cf := ConfigFile.new()
	cf.load("user://records.cfg")
	cf.set_value("sans_fin", "meilleur", t)
	cf.save("user://records.cfg")


## Où réapparaît un joueur qui n'a plus de vie : loin de la sphère, ou à l'entrée de l'arène du titan.
func respawn_anchor() -> Vector3:
	if zone == 5:
		var a := rng.randf_range(0.3, PI - 0.3)
		return SKY_CENTER + Vector3(cos(a), 0, sin(a)) * 22.0
	if zone == 3:
		return ZONE3_CENTER + Vector3(ZONE3_RADIUS - 6.0, 0, rng.randf_range(-4.0, 4.0))
	var a := rng.randf() * TAU
	return clamp_to_area(orb.global_position + Vector3(cos(a), 0, sin(a)) * OUT_RESPAWN_DIST)


func _lava_damage(p, delta: float) -> void:
	if p.dead or lava_pools.is_empty() or p.global_position.y > 0.6:
		return
	for lp in lava_pools:
		var d := Vector2(p.global_position.x - lp[0].x, p.global_position.z - lp[0].z).length()
		if d < lp[1]:
			var t: float = p.get_meta("lava_t", 0.0) - delta
			if t <= 0.0:
				t = 0.5
				p.take_damage(LAVA_DPS * 0.5)
			p.set_meta("lava_t", t)
			return


## Ambiance : brouillard rougeoyant et braises quand le joueur 1 est dans la zone volcanique.
func _update_biome(delta: float) -> void:
	if not zone3_unlocked or world_env == null:
		return
	# dans le ciel : brouillard clair et bleuté, ni braises ni lucioles
	var sky_k := clampf((player.global_position.y - (SKY_Y - 12.0)) / 10.0, 0.0, 1.0) if sky_unlocked else 0.0
	var d := Vector2(player.global_position.x - ZONE3_CENTER.x, player.global_position.z - ZONE3_CENTER.z).length()
	var k := clampf((ZONE3_RADIUS + 20.0 - d) / 30.0, 0.0, 1.0)
	var cur: float = get_meta("biome_k", 0.0)
	cur = move_toward(cur, k, delta * 0.5)
	set_meta("biome_k", cur)
	var sk: float = get_meta("sky_k", 0.0)
	sk = move_toward(sk, sky_k, delta * 0.5)
	set_meta("sky_k", sk)
	world_env.fog_light_color = Color(0.17, 0.17, 0.38).lerp(Color(0.24, 0.15, 0.22), cur).lerp(Color(0.42, 0.48, 0.72), sk)
	world_env.ambient_light_color = Color(0.22, 0.24, 0.5).lerp(Color(0.38, 0.27, 0.36), cur).lerp(Color(0.6, 0.65, 0.85), sk)
	world_env.ambient_light_energy = lerpf(0.35, 0.45, sk)
	world_env.fog_density = lerpf(lerpf(0.011, 0.016, cur), 0.006, sk)
	# volcan : air enfumé, moins de reflets roses du ciel couchant dans le brouillard
	world_env.fog_aerial_perspective = lerpf(0.35, 0.05, cur * (1.0 - sk))
	world_env.fog_sun_scatter = lerpf(0.35, 0.08, cur * (1.0 - sk))
	world_env.fog_sky_affect = lerpf(0.25, 0.1, cur * (1.0 - sk))
	if sun_light:
		sun_light.light_volumetric_fog_energy = lerpf(2.5, 0.7, cur * (1.0 - sk))   # moins de rayons roses dans la fumée
	if world_env.volumetric_fog_enabled:
		world_env.volumetric_fog_albedo = Color(0.85, 0.85, 1.0).lerp(Color(0.6, 0.5, 0.58), cur * (1.0 - sk))
		world_env.volumetric_fog_emission = Color(0.05, 0.04, 0.12).lerp(Color(0.1, 0.04, 0.05), cur * (1.0 - sk))
	embers.emitting = cur > 0.3 and sk < 0.5
	fireflies.emitting = cur < 0.7 and sk < 0.5
	embers.global_position = player.global_position + Vector3(0, 1.5, 0)
	ash.emitting = embers.emitting
	ash.global_position = player.global_position + Vector3(0, 4.0, 0)


## MODE TEST : passe directement à l'étape suivante (zone 1 → zone 2 → titan → 3e sphère → fin).
func skip_zone() -> void:
	if state == "won" or state == "lost":
		return
	for z in get_tree().get_nodes_in_group("zombie"):
		if not z.guard and z != titan:
			z.queue_free()
	for m in spawn_markers:
		m.queue_free()
	spawn_markers.clear()
	to_spawn = 0
	bosses_left = 0
	archers_left = 0
	angels_left = 0
	match zone:
		1:
			if state != "explore":
				wave = TOTAL_WAVES
				_complete_zone1()
			_unlock_zone2()
			_teleport_players(ZONE2_CENTER + ORB_OFFSET + Vector3(0, 0.5, 10))
		2:
			if state != "to_boss":
				wave = TOTAL_WAVES
				_complete_zone2()
			_unlock_zone3()
			_teleport_players(ZONE3_CENTER + Vector3(ZONE3_RADIUS - 8.0, 0.5, 0))
		3:
			if titan and is_instance_valid(titan) and not titan.dead:
				titan.die()
			_teleport_players(ZONE3_CENTER + Vector3(16.0, 0.5, 0))
		4:
			wave = TOTAL_WAVES
			state = "wave"
			_end_wave()
			_teleport_players(SKY_CENTER + Vector3(0, 0.6, 20))
		5:
			if orb4 == null:
				if titan and is_instance_valid(titan) and not titan.dead:
					titan.die()
				_teleport_players(SKY_CENTER + Vector3(0, 0.6, 16))
				return
			if state == "pre_endless":
				_start_endless()
				return
			if state == "endless":
				endless_t += 300.0   # mode test : avance de 5 minutes (niveaux +25)
				return
			wave = TOTAL_WAVES
			state = "wave"
			_end_wave()
	hud.flash_message("MODE TEST : zone suivante")


func _teleport_players(pos: Vector3) -> void:
	for i in players.size():
		var p = players[i]
		if p.dead:
			p.respawn(pos + Vector3(i * 2.0, 0, 0))
		else:
			p.global_position = pos + Vector3(i * 2.0, 0, 0)
			p.velocity = Vector3.ZERO


func _on_orb_damaged(_amount: float) -> void:
	orb_alert_t = 2.0


func _on_orb_destroyed() -> void:
	_finish(false)


func _on_player_died(p) -> void:
	if p.lives > 0:
		p.can_revive = true
		p.hud.show_center("ÉLIMINÉ", "Appuie sur E / X pour revenir ici (%d vie%s)" % [p.lives, "s" if p.lives > 1 else ""], 2.5)
	else:
		p.can_revive = false
		p.respawn_t = OUT_WAIT_BASE + OUT_WAIT_STEP * p.out_deaths
		p.out_deaths += 1
		p.hud.show_center("ÉLIMINÉ", "Plus de vie : réapparition plus loin dans %d s" % int(p.respawn_t), 2.5)


## Lancer la vague en avance : la moitié du temps restant est reportée à la pause suivante.
## Texte du bouton de lancement du menu de la sphère ("" = rien à lancer maintenant).
func orb_launch_text() -> String:
	match state:
		"idle":
			return "LANCER LE COMBAT"
		"break":
			return "LANCER LA VAGUE %d" % (wave + 1)
		"explore":
			if zone == 2 or zone == 4 or zone == 5:
				return "LANCER LE COMBAT (%de SPHÈRE)" % {2: 2, 4: 3, 5: 4}[zone]
		"pre_endless":
			return "LANCER LA DÉFENSE SANS FIN"
	return ""


## Bouton « lancer » du menu de la sphère : le temps restant est en partie reporté (50 %).
func orb_launch() -> void:
	match state:
		"pre_endless":
			_start_endless()
		"idle":
			if not Settings.test_mode:
				_carry_over(countdown)
			_start_wave(1)
		"break":
			_carry_over(countdown)
			_start_wave(wave + 1)
		"explore":
			if zone == 2 or zone == 4 or zone == 5:
				if not Settings.test_mode:
					_carry_over(countdown)
				if orb2_beacon and is_instance_valid(orb2_beacon):
					orb2_beacon.queue_free()
					orb2_beacon = null
				_start_wave(1)


## La création d'arme se débloque à la 2e sphère.
func crafting_unlocked() -> bool:
	return zone >= 2


func _carry_over(remaining: float) -> void:
	carry_time = remaining * CARRY_RATIO
	if carry_time > 1.0:
		hud.flash_message("%d s de préparation reportées à la prochaine pause" % int(carry_time))


## Repousse les squelettes autour d'un point (retour d'un joueur).
func knockback_around(pos: Vector3, radius: float, strength: float) -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		var d: Vector3 = z.global_position - pos
		d.y = 0.0
		if d.length() < radius:
			var dir := d.normalized() if d.length() > 0.1 else Vector3(1, 0, 0)
			z.knockback(dir * strength * (1.0 - d.length() / radius * 0.5))
	spawn_impact(pos + Vector3.UP, Vector3.UP, Color(0.6, 0.9, 1.0), 30, 2.5)
	Sfx.play_3d("break", pos, 2.0, 1.4)


# ------------------------------------------------------------------ joueurs et écran scindé

## Ajoute un joueur avec ses périphériques, sa vue (caméra) et son interface.
func add_player(use_kbm: bool, pad_id: int) -> Node:
	var idx := players.size()
	GameInput.setup_player(idx, use_kbm, pad_id)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	# toujours actif : sinon, jeu en pause (menus), les clics souris n'atteignent plus l'interface
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	view_root.add_child(container)
	var sv := SubViewport.new()
	sv.world_3d = get_viewport().world_3d
	sv.msaa_3d = Viewport.MSAA_2X
	sv.audio_listener_enable_3d = idx == 0
	sv.handle_input_locally = false
	container.add_child(sv)
	var cam := Camera3D.new()
	cam.near = 0.03
	cam.far = 500.0
	sv.add_child(cam)
	cam.current = true
	var h = HudScript.new()
	sv.add_child(h)
	h.main = self
	h.minimap.main = self
	h.menu_pressed.connect(_to_menu)
	h.retry_pressed.connect(_retry)
	var p = PlayerScript.new()
	p.index = idx
	p.kbm = use_kbm
	p.pad = pad_id
	p.main = self
	p.hud = h
	h.player = p
	h.minimap.player = p
	p.position = orb.global_position + Vector3(idx * 2.0, 0.2, 8)
	add_child(p)
	p.died.connect(_on_player_died.bind(p))
	if Settings.test_mode:
		_apply_test_mode(p)
	players.append(p)
	huds.append(h)
	hud.huds = huds
	views.append({"container": container, "viewport": sv, "camera": cam})
	# ce que chaque caméra voit : pas son propre corps, pas l'arme en main de l'autre
	for i in players.size():
		var mask := 0xFFFFF
		for q in players:
			if q.index == i:
				mask &= ~q.body_layer()
			else:
				mask &= ~q.view_layer()
		views[i]["camera"].cull_mask = mask
	_layout_views()
	if router and is_instance_valid(router):
		move_child(router, get_child_count() - 1)
	return p


## Mode test : toutes les armes, ressources illimitées, pierre débloquée.
func _apply_test_mode(p) -> void:
	p.test_mode = true
	rifle_craftable = true
	p.unlock_rifle()
	p.unlock_cryo()
	p.unlock_shock()
	p.unlock_sniper()
	p.unlock_zeus()
	p.set_loadout(0, p.W.PISTOL)
	p.set_loadout(1, p.W.RIFLE)
	p._select_weapon(p.W.PISTOL)


func _layout_views() -> void:
	var n := views.size()
	for i in n:
		var c: SubViewportContainer = views[i]["container"]
		c.anchor_top = 0.0
		c.anchor_bottom = 1.0
		c.anchor_left = float(i) / n
		c.anchor_right = float(i + 1) / n
		c.offset_left = 2.0 if i > 0 else 0.0
		c.offset_right = -2.0 if i < n - 1 else 0.0
		c.offset_top = 0.0
		c.offset_bottom = 0.0


## Caméras des vues = caméras des joueurs ; en écran scindé, l'interface est dessinée
## sur une toile un peu plus grande puis réduite pour tenir dans la moitié d'écran.
func _sync_views() -> void:
	for i in players.size():
		var v: Dictionary = views[i]
		var pc: Camera3D = players[i].cam
		var vc: Camera3D = v["camera"]
		vc.global_transform = pc.global_transform
		vc.fov = pc.fov
		vc.h_offset = pc.h_offset
		vc.v_offset = pc.v_offset
		var sv: SubViewport = v["viewport"]
		var want := Vector2i.ZERO
		if players.size() > 1:
			want = Vector2i(int(sv.size.x * 1.3), int(sv.size.y * 1.3))
		if sv.size_2d_override != want:
			sv.size_2d_override = want
			sv.size_2d_override_stretch = want != Vector2i.ZERO


## Arrivée du joueur 2 en cours de partie : Start sur une manette libre,
## ou Entrée au clavier si le joueur 1 joue à la manette.
func try_join(ev: InputEvent) -> bool:
	var p1 = players[0]
	if ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_START:
		var p1_pad: int = GameInput.prev_pad if GameInput.prev_kind == "pad" else -1
		if GameInput.prev_kind == "pad" and ev.device == p1_pad:
			return false   # c'est le joueur 1 qui veut mettre pause
		_reassign_p1(true, p1_pad if p1_pad != ev.device else -1)
		add_player(false, ev.device)
		_announce_join()
		return true
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.physical_keycode == KEY_ENTER or ev.physical_keycode == KEY_KP_ENTER):
		if GameInput.prev_kind == "pad" or (p1.pad >= 0 and not p1.kbm):
			_reassign_p1(false, GameInput.prev_pad if GameInput.prev_pad >= 0 else 0)
			add_player(true, -1)
			_announce_join()
			return true
	return false


## Donne une manette à un joueur (en gardant son clavier/souris s'il en avait un).
func assign_pad(index: int, pad_id: int) -> void:
	var p = players[index]
	p.pad = pad_id
	GameInput.setup_player(index, p.kbm, pad_id)
	p.hud.flash_message("Manette connectée au joueur %d" % (index + 1))


func _reassign_p1(use_kbm: bool, pad_id: int) -> void:
	var p1 = players[0]
	p1.kbm = use_kbm
	p1.pad = pad_id
	GameInput.setup_player(0, use_kbm, pad_id)


func _announce_join() -> void:
	var p2 = players[1]
	p2.wood = 60
	hud.show_center("JOUEUR 2 !", "Écran scindé : chacun ses ressources, son inventaire et ses armes.", 3.0)
	refresh_mouse()


func nearest_player(pos: Vector3):
	var best = null
	var bd := INF
	for p in players:
		if p.dead:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return best if best else players[0]


## Plus haut niveau d'amélioration des barbelés parmi les joueurs.
func wire_level(branch: String) -> int:
	var lvl := 0
	for p in players:
		lvl = maxi(lvl, p.upgrades["wire"][branch])
	return lvl


## Os laissés par un squelette : 50 % de chance d'un os ; boss de vague : os imposant ;
## archer : os en flèche. (Le titan laisse un tas d'os imposant.)
const BONE_CHANCE := 0.5
func drop_bones(z) -> void:
	var kind := ""
	if z.is_boss:
		kind = "big_bone"
	elif z.archer:
		kind = "arrow_bone"
	elif rng.randf() < BONE_CHANCE:
		kind = "bone"
	if kind != "":
		spawn_resource_drop(kind, 1, z.global_position, null)


func spawn_resource_drop(kind: String, amount: int, pos: Vector3, from_player) -> void:
	var d := DropScript.new()
	d.main = self
	d.kind = kind
	d.amount = amount
	d.dropper = from_player
	d.position = Vector3(pos.x, _floor_y(pos) + 0.05, pos.z)
	add_child(d)


## Hauteur du sol sous un point (île de nuages, constructions, terrain).
func _floor_y(pos: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.5, pos + Vector3.DOWN * 80.0, 1 | 8)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position.y if not r.is_empty() else 0.0


## Souris visible si le joueur clavier/souris a un menu ouvert, ou si le jeu est en pause.
func refresh_mouse() -> void:
	var visible := get_tree().paused
	for p in players:
		if p.kbm and p.hud and p.hud.menu_open():
			visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


func on_pause_changed(from_hud, paused: bool) -> void:
	for h in huds:
		if h != from_hud:
			if paused:
				h.show_center("PAUSE", "Un joueur a mis le jeu en pause", 600.0)
			else:
				h.show_center("", "", 0.01)


func _finish(victory: bool) -> void:
	if state == "won" or state == "lost":
		return
	state = "won" if victory else "lost"
	if victory:
		Sfx.play("win")
		hud.show_end("VICTOIRE !", "Les 10 vagues ont été repoussées. La sphère est sauve.")
	elif endless_t > 0.0:
		Sfx.play("lose")
		var best := _best_endless()
		var record := endless_t > best
		if record:
			_save_best_endless(endless_t)
		hud.show_end("FIN DE LA DÉFENSE", "Tu as tenu %s (niveau %d atteint).%s" % [_fmt_time(endless_t), ENDLESS_START_LEVEL + int(endless_t / ENDLESS_LEVEL_EVERY),
			"\nNOUVEAU RECORD !" if record else "\nRecord : %s" % _fmt_time(best)])
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
