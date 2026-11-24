extends CharacterBody3D
## Joueur à la première personne : fusil d'assaut, hache et construction.

const Mats = preload("res://scripts/mats.gd")
const Structure = preload("res://scripts/structure.gd")
const Upg = preload("res://scripts/upgrades.gd")

signal died

enum W { PISTOL, RIFLE, AXE, BUILD, CRYO }
const WEAPON_NAMES := ["PISTOLET", "FUSIL D'ASSAUT", "HACHE", "CONSTRUCTION", "CANON CRYOGÉNIQUE"]
const RES_MAX := 9999
const PIECE_NAMES := ["MUR", "SOL", "RAMPE"]

const WALK_SPEED := 6.5
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MOUSE_SENS := 0.0025
## Caractéristiques des armes à feu (munitions illimitées, seul le chargeur compte)
const GUNS := {
	W.PISTOL: {"mag": 12, "interval": 0.2, "damage": 34.0, "reload": 1.2, "auto": false, "spread": 0.012, "kick": 0.02},
	W.RIFLE: {"mag": 30, "interval": 0.1, "damage": 24.0, "reload": 1.6, "auto": true, "spread": 0.022, "kick": 0.011},
	# rayon de glace continu : très faibles dégâts, ralentit (70 % de vitesse) et rend vulnérable (+10 %) pendant 3 s
	W.CRYO: {"mag": 0, "interval": 0.1, "damage": 1.5, "reload": 0.0, "auto": true, "spread": 0.0, "kick": 0.0},
}
const MAG_SIZE := 30
const FIRE_INTERVAL := 0.1
const RELOAD_TIME := 1.6
const RIFLE_DAMAGE := 24.0
const AXE_TREE_DAMAGE := 25.0
const AXE_ZOMBIE_DAMAGE := 45.0
const AXE_STRUCTURE_DAMAGE := 80.0
const CLIMB_SPEED := 5.0
const CELL := 4.0
const BUILD_COST := 10
const MAT_NAMES := ["BOIS", "PIERRE"]
const MAX_HP := 100.0
const MASK_SHOOT := 1 | 4 | 8 | 16 | 32

const HIP_POS := Vector3(0.25, -0.22, -0.64)
const ADS_POS := Vector3(0.0, -0.105, -0.55)
const AXE_POS := Vector3(0.34, -0.32, -0.55)
const PISTOL_HIP := Vector3(0.2, -0.2, -0.42)
const PISTOL_ADS := Vector3(0.0, -0.085, -0.36)

var main
var hud
## Écran scindé : numéro du joueur et périphériques qui le contrôlent
var index := 0
var kbm := true          # clavier + souris
var pad := -2            # -2 toutes les manettes, -1 aucune, sinon numéro de manette
var respawn_t := 0.0
var avatar: Node3D
const PLAYER_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.55, 0.15)]

var head: Node3D
var cam: Camera3D
var viewmodel: Node3D
var rifle: Node3D          # arme à feu actuellement en main (pistolet ou fusil)
var gun_data := {}         # W -> {node, muzzle, flash, light, crystal, glow, hip, ads}
var has_rifle := false
var has_cryo := false
var mags := {W.PISTOL: 12, W.RIFLE: 30, W.CRYO: 0}
var cryo_beam: MeshInstance3D
var cryo_beam_t := 0.0
## Deux armes à feu équipées (choisies dans l'inventaire) ; la hache est toujours là.
var loadout := [W.PISTOL, -1]
var upgrades := Upg.new_state()
const GUN_KEYS := {W.PISTOL: "pistol", W.RIFLE: "rifle"}
## Mode test : toutes les armes et ressources illimitées
var test_mode := false
var muzzle: Marker3D
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var axe: Node3D
var axe_pivot: Node3D
var ghost: MeshInstance3D
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var piece_meshes: Array[BoxMesh] = []

var weapon := W.PISTOL
var build_piece := 0
var ammo := 12
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
var coins := 0
var first_coin := true
var build_mat := 0   # 0 bois, 1 pierre
var build_target = null
var crystal_mat: StandardMaterial3D
var sight_glow: OmniLight3D
var ads_t := 0.0
var shake_t := 0.0
var shake_amp := 0.0
var swinging := false
var trigger_held := false
var last_gun := W.PISTOL
var climbing := false
var swing_tween: Tween
var dead := false
var invuln_t := 0.0
var ghost_valid := false
var ghost_info := {}


## Nom de l'action propre à ce joueur (ex. "fire@1").
func a(action: String) -> String:
	return "%s@%d" % [action, index]


## Couche de rendu de l'arme en main / du fantôme (visible uniquement par ce joueur)
func view_layer() -> int:
	return 1 << (5 + index)


## Couche de rendu du corps (invisible pour ce joueur, visible pour l'autre)
func body_layer() -> int:
	return 1 << (2 + index)


## Un menu de ce joueur est ouvert : il ne contrôle plus son personnage.
func input_blocked() -> bool:
	return hud != null and hud.menu_open()


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
	viewmodel = Node3D.new()
	cam.add_child(viewmodel)

	_build_rifle()
	_build_pistol()
	_build_cryo()
	_build_axe()
	_build_ghost()
	_build_avatar()
	_select_weapon(W.PISTOL, true)
	_apply_layers(viewmodel, view_layer())
	_apply_layers(ghost, view_layer())


func _apply_layers(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask
	for c in n.get_children():
		_apply_layers(c, mask)


## Petit personnage visible par l'autre joueur (couleur du joueur, étiquette J1 / J2).
func _build_avatar() -> void:
	avatar = Node3D.new()
	add_child(avatar)
	var col: Color = PLAYER_COLORS[index % 2]
	var suit := Mats.col(col, 0.6)
	var dark := Mats.col(col.darkened(0.55), 0.8)
	var skin := Mats.col(Color(0.95, 0.78, 0.62), 0.7)
	Mats.box(avatar, Vector3(0.22, 0.8, 0.26), dark, Vector3(-0.14, 0.4, 0))
	Mats.box(avatar, Vector3(0.22, 0.8, 0.26), dark, Vector3(0.14, 0.4, 0))
	Mats.box(avatar, Vector3(0.6, 0.7, 0.34), suit, Vector3(0, 1.15, 0))
	Mats.box(avatar, Vector3(0.4, 0.45, 0.18), dark, Vector3(0, 1.15, 0.24))   # sac à dos
	Mats.box(avatar, Vector3(0.18, 0.65, 0.2), suit, Vector3(-0.4, 1.15, -0.05))
	Mats.box(avatar, Vector3(0.18, 0.65, 0.2), suit, Vector3(0.4, 1.15, -0.05))
	Mats.sphere(avatar, 0.21, skin, Vector3(0, 1.72, 0), 12)
	Mats.box(avatar, Vector3(0.46, 0.12, 0.46), suit, Vector3(0, 1.88, 0))     # bonnet
	var tag := Label3D.new()
	tag.text = "J%d" % (index + 1)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = 0.0008
	tag.font_size = 48
	tag.outline_size = 12
	tag.modulate = col.lightened(0.3)
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.3, 0)
	avatar.add_child(tag)
	_apply_layers(avatar, body_layer())

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
	rifle.visible = false
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
	gun_data[W.RIFLE] = {"node": rifle, "muzzle": muzzle, "flash": muzzle_flash, "light": muzzle_light,
		"crystal": crystal_mat, "glow": sight_glow, "hip": HIP_POS, "ads": ADS_POS, "rest": Vector3(0, deg_to_rad(6.0), 0)}


## Pistolet : même esprit que le fusil (acier bleui, crosse en bois, cristal turquoise).
func _build_pistol() -> void:
	var g := Node3D.new()
	g.position = PISTOL_HIP
	g.scale = Vector3.ONE * 0.9
	viewmodel.add_child(g)
	var wood := ShaderMaterial.new()
	var wsh := Shader.new()
	wsh.code = WOOD_SHADER
	wood.shader = wsh
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.10, 0.11, 0.15)
	steel.metallic = 0.35
	steel.roughness = 0.55
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.56, 0.26)
	brass.metallic = 0.6
	brass.roughness = 0.4
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.30, 0.95, 0.90, 1.0)
	cmat.emission_enabled = true
	cmat.emission = Color(0.30, 0.95, 0.90)
	cmat.emission_energy_multiplier = 4.0
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# culasse, canon, crosse en bois, pontet, chien
	Mats.box(g, Vector3(0.05, 0.06, 0.24), steel, Vector3(0, 0.0, -0.04))
	Mats.cylinder(g, 0.014, 0.014, 0.08, steel, Vector3(0, -0.005, -0.19), Vector3(90, 0, 0), 8)
	Mats.cylinder(g, 0.018, 0.018, 0.012, brass, Vector3(0, -0.005, -0.155), Vector3(90, 0, 0), 8)
	Mats.box(g, Vector3(0.052, 0.008, 0.2), brass, Vector3(0, -0.032, -0.04))
	Mats.box(g, Vector3(0.042, 0.13, 0.06), wood, Vector3(0, -0.09, 0.07), Vector3(-16, 0, 0))
	Mats.box(g, Vector3(0.01, 0.01, 0.06), steel, Vector3(0, -0.05, 0.0))
	Mats.box(g, Vector3(0.012, 0.025, 0.02), steel, Vector3(0, 0.035, 0.085), Vector3(-30, 0, 0))
	Mats.box(g, Vector3(0.003, 0.01, 0.12), Mats.col(Color(0.30, 0.95, 0.90), 0.1, 4.0), Vector3(0.026, 0.0, -0.04))
	Mats.box(g, Vector3(0.016, 0.016, 0.016), cmat, Vector3(0, 0.042, 0.06), Vector3(45, 45, 0))
	Mats.box(g, Vector3(0.006, 0.014, 0.008), steel, Vector3(0, 0.036, -0.15))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 0.95, 0.9)
	glow.light_energy = 0.15
	glow.omni_range = 0.3
	glow.position = Vector3(0, 0.05, 0.06)
	g.add_child(glow)
	var m := Marker3D.new()
	m.position = Vector3(0, -0.005, -0.24)
	g.add_child(m)
	var fl := Mats.sphere(m, 0.05, Mats.col(Color(1.0, 0.75, 0.35), 0.2, 8.0), Vector3.ZERO, 6)
	fl.visible = false
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.7, 0.4)
	li.omni_range = 6.0
	li.light_energy = 0.0
	m.add_child(li)
	gun_data[W.PISTOL] = {"node": g, "muzzle": m, "flash": fl, "light": li, "crystal": cmat, "glow": glow,
		"hip": PISTOL_HIP, "ads": PISTOL_ADS, "rest": Vector3(0, deg_to_rad(4.0), 0)}


func _build_axe() -> void:
	axe = Node3D.new()
	axe.position = AXE_POS
	viewmodel.add_child(axe)
	axe_pivot = Node3D.new()
	axe.add_child(axe_pivot)
	var wood := ShaderMaterial.new()
	var wsh := Shader.new()
	wsh.code = WOOD_SHADER
	wood.shader = wsh
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.20, 0.21, 0.26)
	steel.metallic = 0.5
	steel.roughness = 0.45
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.75, 0.78, 0.85)
	edge.metallic = 0.6
	edge.roughness = 0.25
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.56, 0.26)
	brass.metallic = 0.6
	brass.roughness = 0.4
	var leather := Mats.col(Color(0.20, 0.10, 0.07), 0.9)
	var rune := Mats.col(Color(0.30, 0.95, 0.90), 0.1, 3.0)
	var h := Node3D.new()
	h.rotation_degrees = Vector3(-25, 0, 18)
	axe_pivot.add_child(h)
	# manche en bois, poignée en cuir, pommeau et virole en laiton
	Mats.cylinder(h, 0.022, 0.028, 0.66, wood, Vector3(0, 0.2, 0), Vector3.ZERO, 8)
	Mats.cylinder(h, 0.032, 0.032, 0.17, leather, Vector3(0, -0.04, 0), Vector3.ZERO, 8)
	Mats.cylinder(h, 0.036, 0.03, 0.03, brass, Vector3(0, -0.14, 0), Vector3.ZERO, 8)
	Mats.cylinder(h, 0.03, 0.03, 0.03, brass, Vector3(0, 0.36, 0), Vector3.ZERO, 8)
	# tête : douille, joue, tranchant clair et bec arrière
	Mats.box(h, Vector3(0.05, 0.09, 0.07), steel, Vector3(0, 0.46, 0.0))
	Mats.box(h, Vector3(0.035, 0.12, 0.12), steel, Vector3(0, 0.46, -0.09))
	Mats.box(h, Vector3(0.03, 0.2, 0.06), steel, Vector3(0, 0.46, -0.17))
	Mats.box(h, Vector3(0.022, 0.24, 0.025), edge, Vector3(0, 0.46, -0.21))
	Mats.box(h, Vector3(0.03, 0.04, 0.07), steel, Vector3(0, 0.46, 0.06), Vector3(-20, 0, 0))
	Mats.box(h, Vector3(0.038, 0.012, 0.07), rune, Vector3(0, 0.46, -0.1))


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
	var is_mouse := event is InputEventMouseButton or event is InputEventMouseMotion
	if is_mouse and not kbm:
		return
	if input_blocked():
		return
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
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)
	if event.is_action_pressed(a("weapon_1")):
		if loadout[0] >= 0:
			_select_weapon(loadout[0])
	elif event.is_action_pressed(a("weapon_2")):
		if loadout[1] >= 0:
			_select_weapon(loadout[1])
		elif hud:
			hud.flash_message("Emplacement 2 vide (inventaire : Select / I)")
	elif event.is_action_pressed(a("weapon_3")):
		_select_weapon(W.AXE)
	elif event.is_action_pressed(a("weapon_4")):
		_select_weapon(W.BUILD)
	elif event.is_action_pressed(a("cycle_piece")):
		if weapon == W.BUILD:
			build_piece = (build_piece + 1) % 3
			Sfx.play("equip", -8.0)
		else:
			_select_weapon(W.BUILD)
	elif event.is_action_pressed(a("piece_wall")):
		_pick_piece(0)
	elif event.is_action_pressed(a("piece_floor")):
		_pick_piece(1)
	elif event.is_action_pressed(a("piece_ramp")):
		_pick_piece(2)
	elif event.is_action_pressed(a("reload")) and _is_gun(weapon):
		_start_reload()
	elif event.is_action_pressed(a("repair")):
		_try_repair()
	elif event.is_action_pressed(a("upgrade")):
		_try_upgrade()
	elif event.is_action_pressed(a("edit")):
		_try_edit()
	elif event.is_action_pressed(a("trap")):
		_try_trap()
	elif event.is_action_pressed(a("build_material")):
		_toggle_material()
	elif event.is_action_pressed(a("weapon_next")) and weapon != W.BUILD:
		_cycle_weapon(1)
	elif event.is_action_pressed(a("weapon_prev")):
		_cycle_weapon(-1)
	elif event.is_action_pressed(a("weapon_swap")):
		if weapon == W.BUILD:
			_toggle_material()
		else:
			_cycle_hand_weapons()
	elif event.is_action_pressed(a("build_toggle")):
		_select_weapon(last_gun if weapon == W.BUILD else W.BUILD)
	elif event.is_action_pressed(a("piece_next")):
		_pick_piece((build_piece + 1) % 3)
	elif event.is_action_pressed(a("inventory")):
		if hud:
			hud.toggle_inventory(self)
			get_viewport().set_input_as_handled()   # sinon l'interface le referme aussitôt
	elif event.is_action_pressed(a("sprint_toggle")):
		sprint_toggle = true


func _pick_piece(p: int) -> void:
	build_piece = p
	_select_weapon(W.BUILD)


func _is_gun(w: int) -> bool:
	return w == W.PISTOL or w == W.RIFLE or w == W.CRYO


func _cycle_weapon(dir: int) -> void:
	var order := [loadout[0], loadout[1], W.AXE, W.BUILD]
	var i := order.find(weapon)
	if i < 0:
		i = 0
	for k in 4:
		i = (i + dir + 4) % 4
		if order[i] >= 0:
			_select_weapon(order[i])
			return


## Y / Triangle : arme 1 → arme 2 → hache → arme 1 (emplacements vides sautés).
func _cycle_hand_weapons() -> void:
	var order := []
	for w in loadout:
		if w >= 0:
			order.append(w)
	order.append(W.AXE)
	var i := order.find(weapon)
	_select_weapon(order[(i + 1) % order.size()] if i >= 0 else order[0])


func owned_guns() -> Array:
	var arr := [W.PISTOL]
	if has_rifle:
		arr.append(W.RIFLE)
	if has_cryo:
		arr.append(W.CRYO)
	return arr


## Change l'arme d'un emplacement (0 ou 1). Une même arme ne peut pas être dans les deux.
func set_loadout(slot: int, w: int) -> void:
	var other := 1 - slot
	if w >= 0 and loadout[other] == w:
		loadout[other] = loadout[slot]
	loadout[slot] = w
	if loadout[0] < 0 and loadout[1] >= 0:
		loadout[0] = loadout[1]
		loadout[1] = -1
	if _is_gun(weapon) and not loadout.has(weapon):
		_select_weapon(loadout[0] if loadout[0] >= 0 else W.AXE)


## Index de l'emplacement de l'arme en main (0-1 armes, 2 hache, 3 construction).
func slot_index() -> int:
	if weapon == W.AXE:
		return 2
	if weapon == W.BUILD:
		return 3
	return loadout.find(weapon)


func unlock_cryo() -> void:
	has_cryo = true
	if loadout[1] < 0:
		loadout[1] = W.CRYO
	if hud:
		hud.flash_message("Équipe-le dans l'inventaire (emplacement 1 ou 2)" if not loadout.has(W.CRYO) else "Touche %d pour l'équiper" % (loadout.find(W.CRYO) + 1))


func unlock_rifle() -> void:
	has_rifle = true
	mags[W.RIFLE] = gun_mag(W.RIFLE)
	if loadout[1] < 0:
		loadout[1] = W.RIFLE
	_select_weapon(W.RIFLE)


# ------------------------------------------------------------------ caractéristiques améliorées

func gun_lvl(w: int, branch: String) -> int:
	if not GUN_KEYS.has(w):
		return 0   # le canon cryogénique n'a pas (encore) d'arbre d'amélioration
	return upgrades[GUN_KEYS[w]][branch]


func gun_mag(w: int) -> int:
	return Upg.mag_size(GUNS[w]["mag"], gun_lvl(w, "mag"))


func gun_interval(w: int) -> float:
	return GUNS[w]["interval"] * Upg.fire_interval_mult(gun_lvl(w, "rate"))


func gun_damage(w: int) -> float:
	return GUNS[w]["damage"] * Upg.damage_mult(gun_lvl(w, "damage"))


func can_afford(c: Dictionary) -> bool:
	if test_mode:
		return true
	return wood >= c.get("wood", 0) and stone >= c.get("stone", 0) and coins >= c.get("coins", 0)


## Achète le niveau suivant d'une branche (si le précédent est acquis et qu'on a les ressources).
func buy_upgrade(item: String, branch: String) -> bool:
	var lvl: int = upgrades[item][branch]
	if lvl >= Upg.MAX_LEVEL:
		return false
	var c := Upg.cost(item, branch, lvl + 1)
	if not can_afford(c):
		return false
	if not test_mode:
		wood -= c.get("wood", 0)
		stone -= c.get("stone", 0)
		coins -= c.get("coins", 0)
	upgrades[item][branch] = lvl + 1
	if branch == "mag":
		for w in GUN_KEYS:
			if GUN_KEYS[w] == item:
				mags[w] = gun_mag(w)
				if weapon == w:
					ammo = mags[w]
	Sfx.play("build", -2.0, 1.3)
	return true


func _select_weapon(w: int, force := false) -> void:
	if w == W.RIFLE and not has_rifle:
		if hud:
			hud.flash_message("Fusil d'assaut pas encore fabriqué (fin de la 1re sphère)")
		return
	if _is_gun(w) and not loadout.has(w):
		if hud:
			hud.flash_message("Cette arme n'est pas équipée (inventaire : Select / I)")
		return
	if w == weapon and not force:
		return
	if _is_gun(weapon):
		mags[weapon] = ammo
	weapon = w
	reloading = false
	if _is_gun(w):
		last_gun = w
		ammo = mags[w]
		var gd: Dictionary = gun_data[w]
		rifle = gd["node"]
		muzzle = gd["muzzle"]
		muzzle_flash = gd["flash"]
		muzzle_light = gd["light"]
		crystal_mat = gd["crystal"]
		sight_glow = gd["glow"]
		rifle_rest_rot = gd["rest"]
	for k in gun_data:
		gun_data[k]["node"].visible = (k == w)
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

	var input := Input.get_vector(a("move_left"), a("move_right"), a("move_forward"), a("move_back"))
	if input_blocked():
		input = Vector2.ZERO
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var spd := WALK_SPEED
	if input.length() < 0.3:
		sprint_toggle = false
	if (Input.is_action_pressed(a("sprint")) or sprint_toggle) and input.y < 0.0 and not aiming:
		spd = SPRINT_SPEED
	if aiming:
		spd *= 0.6
	if Input.is_action_just_pressed(a("jump")) and is_on_floor() and not input_blocked():
		velocity.y = JUMP_VELOCITY
	var accel := 14.0 if is_on_floor() else 4.0
	velocity.x = lerpf(velocity.x, dir.x * spd, minf(accel * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * spd, minf(accel * delta, 1.0))
	if climbing:
		velocity.y = CLIMB_SPEED
	move_and_slide()

	# Escalade : on avance contre une de nos constructions → on grimpe dessus
	climbing = false
	if input.y < -0.3:
		var fwd := -global_transform.basis.z
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var c := col.get_collider()
			var n := col.get_normal()
			if c and c is Node and (c as Node).is_in_group("structure") and absf(n.y) < 0.4 and fwd.dot(-n) > 0.5:
				climbing = true
				break

	# limites de la zone
	if main:
		position = main.clamp_to_area(position)
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
	var captured := kbm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if input_blocked():
		aiming = false
		trigger_held = false
		return
	aiming = Input.is_action_pressed(a("aim")) and _is_gun(weapon) and not reloading \
		and (captured or not (kbm and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))

	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			ammo = gun_mag(weapon) if _is_gun(weapon) else ammo

	var firing := Input.is_action_pressed(a("fire")) and (captured or not (kbm and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))
	match weapon:
		W.CRYO:
			cryo_beam_t -= delta
			if firing and fire_cd <= 0.0:
				_shoot_cryo()
			cryo_beam.visible = cryo_beam_t > 0.0
			trigger_held = firing
		W.PISTOL, W.RIFLE:
			# pistolet : coup par coup (une pression = un tir) ; fusil : automatique
			var trigger := firing if GUNS[weapon]["auto"] else (firing and not trigger_held)
			if trigger and fire_cd <= 0.0 and not reloading:
				if ammo > 0:
					_shoot()
				else:
					_start_reload()
			trigger_held = firing
		W.AXE:
			if firing and swing_cd <= 0.0:
				_swing()
		W.BUILD:
			# Manette : RT = mur, LT = sol, RB = rampe. Souris : clic gauche = pièce choisie.
			var want := -1
			if Input.is_action_pressed(a("pad_build_wall")):
				want = 0
			elif Input.is_action_pressed(a("pad_build_floor")):
				want = 1
			elif Input.is_action_pressed(a("pad_build_ramp")):
				want = 2
			elif captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				want = build_piece
			if want >= 0 and want != build_piece:
				build_piece = want
			_update_ghost()
			if want >= 0 and build_cd <= 0.0:
				_place()


func _process(delta: float) -> void:
	if test_mode:
		wood = RES_MAX
		stone = RES_MAX
		coins = RES_MAX
	# Visée au stick droit (courbe quadratique pour la précision)
	if not dead and not get_tree().paused and not input_blocked():
		var look := Input.get_vector(a("look_left"), a("look_right"), a("look_up"), a("look_down"))
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

	var gdat: Dictionary = gun_data[last_gun]
	var target_pos: Vector3 = gdat["ads"] if aiming else gdat["hip"]
	var target_rot := Vector3.ZERO if aiming else rifle_rest_rot
	if reloading:
		target_pos = gdat["hip"] + Vector3(-0.05, -0.08, 0.05)
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
	_update_aimed_enemy()

	flash_t -= delta
	muzzle_flash.visible = flash_t > 0.0
	muzzle_light.light_energy = 3.0 if flash_t > 0.0 else 0.0
	if muzzle_flash.visible:
		muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.6)


# ------------------------------------------------------------------ fusil

func _start_reload() -> void:
	if not _is_gun(weapon) or weapon == W.CRYO or reloading or ammo >= gun_mag(weapon):
		return
	reloading = true
	reload_t = GUNS[weapon]["reload"] * Upg.reload_mult(gun_lvl(weapon, "reload"))
	Sfx.play("reload", -2.0)


func _shoot() -> void:
	ammo -= 1
	var gs: Dictionary = GUNS[weapon]
	fire_cd = gun_interval(weapon)
	flash_t = 0.04
	recoil = 1.0
	Sfx.play("shot", -5.0, 1.25 if weapon == W.PISTOL else 1.0)

	var spread: float = 0.004 if aiming else gs["spread"]
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
			c.take_damage(gun_damage(weapon) * (2.0 if is_head else 1.0), is_head)
			if hud:
				hud.hitmarker(is_head)
			Sfx.play("headshot" if is_head else "hit", -6.0)
			main.spawn_impact(end, r.normal, Color(0.35, 0.85, 0.2), 10, 1.0)
		else:
			main.spawn_impact(end, r.normal, Color(1.0, 0.85, 0.55), 6, 0.6)
	main.spawn_tracer(muzzle.global_position, end)

	head.rotation.x = clampf(head.rotation.x + (0.005 if aiming else gs["kick"]), -1.5, 1.5)
	rotate_y(randf_range(-0.004, 0.004))


## Rayon de glace : touche ce qui est sous le viseur à chaque tic (10 / s).
func _shoot_cryo() -> void:
	fire_cd = GUNS[W.CRYO]["interval"]
	cryo_beam_t = 0.12
	if randf() < 0.3:
		Sfx.play("orb_hit", -16.0, 2.2)
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 45.0
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SHOOT)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not r.is_empty():
		end = r.position
		var c = r.collider
		if c and c.is_in_group("zombie"):
			var cu: Dictionary = upgrades["cryo"]
			c.apply_frost(Upg.cryo_speed(cu["slow"]), Upg.cryo_vuln(cu["vuln"]), Upg.cryo_duration(cu["duration"]))
			c.take_damage(GUNS[W.CRYO]["damage"] * Upg.cryo_damage_mult(cu["damage"]), false)
			if hud and randf() < 0.3:
				hud.hitmarker(false)
		if randf() < 0.5:
			main.spawn_impact(end, r.normal, Color(0.6, 0.95, 1.0), 4, 0.5)
	# rayon visible du canon au point d'impact
	var a: Vector3 = muzzle.global_position
	var length := a.distance_to(end)
	cryo_beam.global_position = (a + end) * 0.5
	var dir := (end - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	cryo_beam.look_at(end, up)
	cryo_beam.scale = Vector3(1.0 + randf() * 0.4, 1.0 + randf() * 0.4, length)
	cryo_beam.visible = true


## Canon cryogénique : corps blanc, réservoir de glace lumineux, ailettes émettrices.
func _build_cryo() -> void:
	var g := Node3D.new()
	g.position = HIP_POS
	g.scale = Vector3.ONE * 0.82
	g.visible = false
	viewmodel.add_child(g)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.86, 0.9, 0.96)
	shell.metallic = 0.3
	shell.roughness = 0.35
	var dark := Mats.col(Color(0.12, 0.14, 0.2), 0.5)
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.55, 0.92, 1.0, 0.85)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.emission_enabled = true
	ice.emission = Color(0.4, 0.85, 1.0)
	ice.emission_energy_multiplier = 3.0
	Mats.box(g, Vector3(0.1, 0.12, 0.42), shell, Vector3(0, 0, 0))
	Mats.cylinder(g, 0.055, 0.055, 0.22, ice, Vector3(0, 0.1, -0.02), Vector3(90, 0, 0), 12)
	Mats.cylinder(g, 0.062, 0.062, 0.02, dark, Vector3(0, 0.1, 0.1), Vector3(90, 0, 0), 12)
	Mats.cylinder(g, 0.062, 0.062, 0.02, dark, Vector3(0, 0.1, -0.14), Vector3(90, 0, 0), 12)
	Mats.cylinder(g, 0.03, 0.05, 0.3, shell, Vector3(0, 0, -0.36), Vector3(90, 0, 0), 10)
	for i in 3:
		var a := TAU * i / 3.0
		Mats.box(g, Vector3(0.015, 0.07, 0.12), dark, Vector3(cos(a) * 0.055, sin(a) * 0.055, -0.5), Vector3(0, 0, rad_to_deg(a)))
	Mats.sphere(g, 0.035, ice, Vector3(0, 0, -0.53), 10)
	Mats.box(g, Vector3(0.05, 0.14, 0.06), dark, Vector3(0, -0.11, 0.1), Vector3(-15, 0, 0))
	Mats.box(g, Vector3(0.07, 0.1, 0.2), shell, Vector3(0, -0.02, 0.28))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.85, 1.0)
	glow.light_energy = 0.4
	glow.omni_range = 0.6
	glow.position = Vector3(0, 0.1, 0)
	g.add_child(glow)
	var m := Marker3D.new()
	m.position = Vector3(0, 0, -0.56)
	g.add_child(m)
	var fl := Mats.sphere(m, 0.06, ice, Vector3.ZERO, 6)
	fl.visible = false
	var li := OmniLight3D.new()
	li.light_color = Color(0.5, 0.9, 1.0)
	li.omni_range = 5.0
	li.light_energy = 0.0
	m.add_child(li)
	gun_data[W.CRYO] = {"node": g, "muzzle": m, "flash": fl, "light": li, "crystal": ice, "glow": glow,
		"hip": HIP_POS, "ads": ADS_POS, "rest": Vector3(0, deg_to_rad(6.0), 0)}
	# le rayon (dans le monde, pas dans la main) : boîte fine étirée le long de son axe Z
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 1.0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(0.5, 0.95, 1.0, 0.9)
	cryo_beam = MeshInstance3D.new()
	cryo_beam.mesh = bm
	cryo_beam.material_override = beam_mat
	cryo_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cryo_beam.top_level = true
	cryo_beam.visible = false
	add_child(cryo_beam)


# ------------------------------------------------------------------ hache

## Coup de hache en 4 temps : armé (on lève la hache en arrière), frappe rapide en arc,
## impact (petit arrêt + tremblement), puis retour en position.
func _swing() -> void:
	swing_cd = 0.62
	swinging = true
	if swing_tween and swing_tween.is_valid():
		swing_tween.kill()
	var tw := create_tween()
	swing_tween = tw
	# 1. armé : la hache recule et monte au-dessus de l'épaule
	tw.tween_property(axe, "position", AXE_POS + Vector3(0.05, 0.08, 0.03), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(axe_pivot, "rotation", Vector3(0.55, -0.2, -0.3), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
		var got: int = c.mine(AXE_TREE_DAMAGE, r.position)
		got = int(round(got * Upg.harvest_mult(upgrades["axe"]["stone"])))
		if got > 0:
			stone = mini(stone + got, RES_MAX)
			if hud:
				hud.stone_gain(got)
				if c.last_target_hit:
					hud.hitmarker(true)
		elif hud and main and not main.stone_unlocked:
			hud.flash_message("La pierre se débloque à la vague %d" % main.STONE_WAVE)
		main.spawn_impact(r.position, r.normal, Color(0.5, 0.5, 0.6), 10, 1.0)
		_shake(0.02)
	elif c and c.is_in_group("tree"):
		var gained: int = c.chop(AXE_TREE_DAMAGE, r.position)
		gained = int(round(gained * Upg.harvest_mult(upgrades["axe"]["wood"])))
		wood = mini(wood + gained, RES_MAX)
		if hud and gained > 0:
			hud.wood_gain(gained)
		if hud and c.last_target_hit:
			hud.hitmarker(true)
		_shake(0.018)
		main.spawn_impact(r.position, r.normal, Color(0.65, 0.45, 0.25), 10, 1.0)
	elif c and c.is_in_group("structure"):
		# on peut démolir ses propres constructions à la hache (pour ne jamais rester coincé)
		c.take_damage(AXE_STRUCTURE_DAMAGE)
		_shake(0.015)
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
	if test_mode:
		return
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


## Ennemi sous le viseur (pour afficher sa barre de vie).
func _update_aimed_enemy() -> void:
	if hud == null:
		return
	if dead:
		hud.set_enemy(null)
		return
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * 120.0, 1 | 4 | 8 | 16)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r.collider and r.collider.is_in_group("zombie"):
		hud.set_enemy(r.collider)
	else:
		hud.set_enemy(null)


func _try_repair() -> void:
	if build_target == null or not is_instance_valid(build_target):
		return
	if build_target.is_repairing():
		hud.flash_message("Réparation déjà en cours")
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


## Ajoute des ressources (bois, pierre, pièces) dans la limite du maximum. Renvoie la quantité prise.
func add_resource(kind: String, amount: int) -> int:
	var have: int = {"wood": wood, "stone": stone, "coins": coins}[kind]
	var take := mini(amount, RES_MAX - have)
	match kind:
		"wood":
			wood += take
		"stone":
			stone += take
		"coins":
			coins += take
	return take


## Dépose au sol, devant soi, une quantité d'une ressource.
func drop_resource(kind: String, amount: int) -> void:
	var have: int = {"wood": wood, "stone": stone, "coins": coins}[kind]
	amount = mini(amount, have)
	if amount <= 0 or main == null:
		return
	match kind:
		"wood":
			wood -= amount
		"stone":
			stone -= amount
		"coins":
			coins -= amount
	var fwd := -global_transform.basis.z
	main.spawn_resource_drop(kind, amount, global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 1.6, self)


func collect_coin() -> void:
	coins = mini(coins + 1, RES_MAX)
	Sfx.play("coin", -4.0)
	if hud:
		hud.coin_gain(1)
		if first_coin:
			first_coin = false
			hud.show_notice("PIÈCE ramassée !\n2 pièces = des barbelés à poser sur un SOL (B / clic stick droit).\nLes squelettes y avancent à 80 % de leur vitesse et sont blessés.", 7.0)


func _try_trap() -> void:
	if build_target == null or not is_instance_valid(build_target):
		hud.flash_message("Vise un sol pour y poser des barbelés")
		return
	if not build_target.can_have_trap():
		hud.flash_message("Les barbelés se posent sur un sol plein (sans barbelés)")
		return
	if coins < build_target.TRAP_COST:
		hud.flash_message("Il faut %d pièces pour des barbelés" % build_target.TRAP_COST)
		return
	coins -= build_target.TRAP_COST
	build_target.add_trap()


func _try_edit() -> void:
	if build_target == null or not is_instance_valid(build_target):
		return
	var nm: String = build_target.cycle_edit()
	if hud:
		hud.flash_message(nm)


func _try_upgrade() -> void:
	if build_target == null or not is_instance_valid(build_target):
		return
	if not build_target.can_upgrade():
		hud.flash_message("Niveau maximum atteint")
		return
	var m: int = build_target.material_type
	var cost: int = build_target.upgrade_cost()
	if _material_count(m) < cost:
		hud.flash_message("Il faut %d %s pour améliorer" % [cost, MAT_NAMES[m].to_lower()])
		return
	var target = build_target
	if cost >= 1000:
		# grosse dépense : on demande confirmation
		hud.confirm("AMÉLIORATION ULTIME", "Attention : cette amélioration coûte %d %s.\nPV de la construction ×4.\n\nConfirmer ?" % [cost, MAT_NAMES[m].to_lower()],
			func(): _do_upgrade(target, m, cost))
		return
	_do_upgrade(target, m, cost)


func _do_upgrade(target, m: int, cost: int) -> void:
	if not is_instance_valid(target) or _material_count(m) < cost:
		return
	_spend(m, cost)
	target.upgrade()


# ------------------------------------------------------------------ santé

func take_damage(amount: float) -> void:
	if dead or invuln_t > 0.0:
		return
	# défense apportée par l'arme en main
	if _is_gun(weapon):
		amount *= 1.0 - Upg.defense(gun_lvl(weapon, "defense"))
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
	mags = {W.PISTOL: gun_mag(W.PISTOL), W.RIFLE: gun_mag(W.RIFLE), W.CRYO: 0}
	ammo = gun_mag(weapon) if _is_gun(weapon) else ammo
	reloading = false
	position = pos
	velocity = Vector3.ZERO
	head.position.y = 1.6
	head.rotation = Vector3.ZERO
	viewmodel.visible = true
	_select_weapon(weapon, true)
