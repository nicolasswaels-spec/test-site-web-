extends CharacterBody3D
## Joueur à la première personne : fusil d'assaut, hache et construction.

const Mats = preload("res://scripts/mats.gd")
const Structure = preload("res://scripts/structure.gd")
const Upg = preload("res://scripts/upgrades.gd")
const Skills = preload("res://scripts/skills.gd")

signal died

enum W { PISTOL, RIFLE, AXE, BUILD, CRYO, SHOCK, SNIPER, ZEUS }
const WEAPON_NAMES := ["PISTOLET", "FUSIL D'ASSAUT", "HACHE", "CONSTRUCTION", "CANON CRYOGÉNIQUE", "ONDE DE CHOC", "FUSIL DE PRÉCISION", "ÉCLAIR DE ZEUS"]
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
	W.RIFLE: {"mag": 27, "interval": 0.111, "damage": 21.6, "reload": 1.6, "auto": true, "spread": 0.022, "kick": 0.011},
	# rayon de glace continu : très faibles dégâts, ralentit (70 % de vitesse) et rend vulnérable (+10 %) pendant 3 s
	W.CRYO: {"mag": 0, "interval": 0.1, "damage": 42.0, "reload": 0.0, "auto": true, "spread": 0.0, "kick": 0.0},
	W.ZEUS: {"mag": 0, "interval": 1.5, "damage": 1000.0, "reload": 0.0, "auto": false, "spread": 0.0, "kick": 0.0},
	W.SNIPER: {"mag": 0, "interval": 1.6, "damage": 175.0, "reload": 0.0, "auto": false, "spread": 0.03, "kick": 0.09},
	W.SHOCK: {"mag": 0, "interval": 4.0, "damage": 100.0, "reload": 0.0, "auto": false, "spread": 0.0, "kick": 0.0},
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
const MAT_NAMES := ["BOIS", "PIERRE", "BOIS MAGIQUE", "PIERRE MAGIQUE", "NUAGE"]
const MAGIC_BUILD_COST := 1   # 1 bois / pierre magique = 1 pièce
const MAX_HP := 100.0
const MASK_SHOOT := 1 | 4 | 8 | 16 | 32

const HIP_POS := Vector3(0.22, -0.19, -0.5)   # armes longues près de la caméra : la crosse sort de l'écran
const ADS_POS := Vector3(0.0, -0.105, -0.66)
const AXE_POS := Vector3(0.34, -0.32, -0.55)
const PISTOL_HIP := Vector3(0.15, -0.12, -0.34)
const PISTOL_ADS := Vector3(0.0, -0.085, -0.36)

var main
var hud
## Écran scindé : numéro du joueur et périphériques qui le contrôlent
var index := 0
var kbm := true          # clavier + souris
var pad := -2            # -2 toutes les manettes, -1 aucune, sinon numéro de manette
var respawn_t := 0.0
## Vies : avec une vie, on revient sur place (X / E) ; sans vie, attente qui s'allonge.
const START_LIVES := 5
var lives := START_LIVES
var can_revive := false
var out_deaths := 0
var avatar: Node3D
const PLAYER_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.55, 0.15)]

var head: Node3D
var cam: Camera3D
var viewmodel: Node3D
var rifle: Node3D          # arme à feu actuellement en main (pistolet ou fusil)
var gun_data := {}         # W -> {node, muzzle, flash, light, crystal, glow, hip, ads}
var has_rifle := false
var has_cryo := false
var has_shock := false
var has_sniper := false
var has_zeus := false
var zeus_cd := 0.0
var divine_t := 0.0      # toucher divin : bonus de dégâts temporaire après un éclair
var divine_boost := 0.0
var sniper_cd := 0.0
var shock_cd := 0.0   # rechargement de l'onde de choc (indépendant des autres armes)
var mags := {W.PISTOL: 12, W.RIFLE: 27, W.CRYO: 0, W.SHOCK: 0, W.SNIPER: 0, W.ZEUS: 0}
var cryo_beam: MeshInstance3D
var cryo_beam_t := 0.0
## Deux armes à feu équipées (choisies dans l'inventaire) ; la hache est toujours là.
var loadout := [W.PISTOL, -1]
var upgrades := Upg.new_state()
var god := {}              # variantes de Dieu débloquées : "pistol", "rifle", "cryo", "shock", "sniper" -> true
const GOD_KEYS := {W.PISTOL: "pistol", W.RIFLE: "rifle", W.CRYO: "cryo", W.SHOCK: "shock", W.SNIPER: "sniper"}
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
# ---- arbre de compétences
var skills := {}                 # id -> vrai si débloquée
var skill_tokens := 0
var stats := Skills.new_stats()  # compteurs pour les prérequis
var shield := 0.0
var since_hit := 99.0            # temps depuis le dernier coup reçu
var fireball_cd := 0.0
var _last_pos := Vector3.INF
var wood := 60
var stone := 0
var coins := 0
var magic_wood := 0
var magic_stone := 0
const MAGIC_MAX := 99
# os (visibles seulement dans l'inventaire) : leur usage viendra plus tard
var clouds := 0
var magic_clouds := 0
var bones := 0
var big_bones := 0
var arrow_bones := 0
var bone_piles := 0
## Type de ressource -> propriété du joueur
const RES_PROPS := {"wood": "wood", "stone": "stone", "coins": "coins", "magic_wood": "magic_wood", "magic_stone": "magic_stone",
	"cloud": "clouds", "magic_cloud": "magic_clouds", "bone": "bones", "big_bone": "big_bones", "arrow_bone": "arrow_bones", "bone_pile": "bone_piles"}
var first_coin := true
var build_mat := 0   # 0 bois, 1 pierre, 2 bois magique, 3 pierre magique, 4 nuage
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
	_build_shock()
	_build_sniper()
	_build_zeus()
	_build_axe()
	_build_ghost()
	_build_avatar()
	_build_arms()
	_select_weapon(W.PISTOL, true)
	_apply_layers(viewmodel, view_layer())
	_apply_layers(ghost, view_layer())


## Bras du voyageur à la 1re personne (tools/blender/rig_fp_arm.py) : modèle Meshy avec un squelette
## doigt par doigt. Repère du modèle : +X = vers les doigts, +Z = normale de la paume, pouce vers -Y.
const FP_ARM := preload("res://assets/characters/fp_arm.glb")
const ARM_SCALE := 0.78
const PALM_N := Vector3(0, 0, 1)
const GRIP_HALF := 0.024   # demi-épaisseur d'une poignée (m)
const PALM_C := Vector3(0.455, 0.0, 0.0)     # centre de la paume (modèle), recalé sur l'os « hand »
const FINGERS := ["index", "middle", "ring", "pinky"]
## Poses de prise : flexion des doigts (0 = ouverte, 1 = poing) et du pouce, opposition du pouce.
const GRIPS := {
	"pistol": {"curl": 0.7, "index": 0.22, "thumb": 0.45, "opp": 0.7},   # index tendu sur la gâchette
	"support": {"curl": 0.42, "thumb": 0.25, "opp": 0.3},
	"fist": {"curl": 1.0, "thumb": 0.6, "opp": 0.9},
}
var arm_rigs: Array = []        # [{skel, side}] : coude orienté vers l'épaule, animations de doigts
## Épaules (repère de la caméra) : le haut du bras part du coude vers ce point, hors de l'écran.
# épaules très basses et en retrait : le haut du bras (manchon) file hors champ, on ne voit que l'avant-bras
const SHOULDERS := [Vector3(0.34, -0.9, 0.05), Vector3(-0.32, -0.9, -0.05)]


## Place un bras : centre de la paume sur « hand », avant-bras vers « elbow » (hors de l'écran),
## paume tournée vers « palm_dir ». side : 0 = droit, 1 = gauche (miroir du droit).
func _add_arm(parent: Node3D, hand: Vector3, elbow: Vector3, side := 0, palm_dir := Vector3.LEFT, grip := "pistol") -> void:
	var m: Node3D = FP_ARM.instantiate()
	var x := (hand - elbow).normalized()
	var z := (palm_dir - x * palm_dir.dot(x)).normalized()
	var y := z.cross(x)
	var b := Basis(x, y, z)
	if side == 1:
		b = b * Basis.from_scale(Vector3(1, -1, 1))      # bras gauche : miroir (pouce de l'autre côté)
	b = b.scaled(Vector3.ONE * ARM_SCALE)
	var skel: Skeleton3D = m.find_child("*", true, false) as Skeleton3D
	if skel == null:
		for c in m.find_children("*", "Skeleton3D", true, false):
			skel = c
	var palm := PALM_C
	if skel:
		var hi := skel.find_bone("hand")
		if hi >= 0:
			palm = skel.get_bone_global_rest(hi).origin + Vector3(0.065, 0, 0)
	# la paume se pose CONTRE la poignée (pas en son centre) : décalée de l'épaisseur de la poignée,
	# les doigts fermés s'enroulent autour au lieu de rentrer dedans
	m.transform = Transform3D(b, hand - z * GRIP_HALF - b * palm)
	parent.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var sm := (mi as MeshInstance3D).mesh.surface_get_material(i) as StandardMaterial3D
			if sm:
				matte(sm)
	if skel:
		set_grip(skel, GRIPS[grip])
		arm_rigs.append({"skel": skel, "side": side})


## Coude : l'os « upper » (haut du bras) vise l'épaule, quelle que soit la position de la main
## (arme qui recule, coup de hache...). Appelé à chaque image pour les bras visibles.
func _update_arms() -> void:
	for a in arm_rigs:
		var skel: Skeleton3D = a["skel"]
		if not is_instance_valid(skel) or not skel.is_visible_in_tree():
			continue
		var ui := skel.find_bone("upper")
		if ui < 0:
			continue
		var pi := skel.get_bone_parent(ui)
		var parent_g := skel.get_bone_global_pose(pi)
		var rest_l := skel.get_bone_rest(ui)
		var cur_g := parent_g * rest_l
		var to_skel := skel.global_transform.affine_inverse() * cam.global_transform
		var shoulder: Vector3 = to_skel * SHOULDERS[a["side"]]
		var rest_dir := cur_g.basis.y.normalized()          # l'os est orienté selon son axe Y
		var want := (shoulder - cur_g.origin).normalized()
		if want.length() < 0.5:
			continue
		var q := Quaternion(rest_dir, want)
		var g_basis := Basis(q) * cur_g.basis
		var local := parent_g.basis.inverse() * g_basis
		skel.set_bone_pose_rotation(ui, local.get_rotation_quaternion())


## Plie les doigts : chaque phalange tourne autour de (direction de l'os × normale de la paume).
## g : {curl, thumb, opp} ; utilisable aussi pour animer (rechargement, coup de hache...).
static func set_grip(skel: Skeleton3D, g: Dictionary) -> void:
	var angles := [70.0, 85.0, 60.0]
	for f in FINGERS + ["thumb"]:
		for j in 3:
			var bi := skel.find_bone("%s_%d" % [f, j + 1])
			if bi < 0:
				continue
			var grest := skel.get_bone_global_rest(bi)
			var dir: Vector3
			var ci := skel.find_bone("%s_%d" % [f, j + 2])
			if ci >= 0:
				dir = (skel.get_bone_global_rest(ci).origin - grest.origin).normalized()
			else:
				var pi := skel.get_bone_parent(bi)
				dir = (grest.origin - skel.get_bone_global_rest(pi).origin).normalized()
			var amount: float = g.get(f, g["curl"])
			var q := Quaternion(grest.basis.inverse() * dir.cross(PALM_N).normalized(), deg_to_rad(angles[j] * amount))
			if f == "thumb" and j == 0:
				# opposition : le pouce passe devant la paume (rotation autour de l'axe de la main)
				q = Quaternion(grest.basis.inverse() * Vector3(-1, 0, 0), deg_to_rad(45.0 * g["opp"])) * q
			skel.set_bone_pose_rotation(bi, skel.get_bone_rest(bi).basis.get_rotation_quaternion() * q)


func _build_arms() -> void:
	# main droite sur la poignée (hand_r), main gauche sous le garde-main ou en soutien (hand_l)
	for w in gun_data:
		var d: Dictionary = gun_data[w]
		var g: Node3D = d["node"]
		var hr: Vector3 = d["hand_r"]
		var hl: Vector3 = d["hand_l"]
		# main droite : poignet derrière la poignée, articulations vers l'avant, paume contre la poignée
		_add_arm(g, hr, hr + Vector3(0.08, -0.25, 0.35), 0, Vector3.LEFT, "pistol")
		if hl.z < hr.z - 0.15:
			# arme longue : main gauche sous le garde-main, doigts qui passent en travers, paume vers le haut
			_add_arm(g, hl, hl + Vector3(-0.24, -0.3, 0.22), 1, Vector3.UP, "support")   # coude bas et proche : avant-bras qui file hors champ
		# armes courtes (pistolet...) : tenues d'une main
	var h: Node3D = axe_pivot.get_child(0)
	_add_arm(h, Vector3(0, -0.04, 0), Vector3(0.32, -0.2, 0.22), 0, Vector3(-1, 0, -1).normalized(), "fist")


func _apply_layers(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask
	for c in n.get_children():
		_apply_layers(c, mask)


## Petit personnage visible par l'autre joueur (couleur du joueur, étiquette J1 / J2).
## Voyageur encapuchonné (visuel OpenArt → modèle 3D, squelette et animations Meshy,
## assemblé par tools/blender/assemble_character.py) : le même pour les deux joueurs.
const AVATAR_MODEL := preload("res://assets/characters/traveler.glb")
var avatar_anim: AnimationPlayer


## Personnage visible par l'autre joueur (le voyageur encapuchonné, étiquette J1 / J2 au-dessus).
func _build_avatar() -> void:
	avatar = Node3D.new()
	add_child(avatar)
	var col: Color = PLAYER_COLORS[index % 2]
	var model: Node3D = AVATAR_MODEL.instantiate()
	model.rotation.y = PI          # le modèle regarde vers +Z, le joueur vers -Z
	model.scale = Vector3.ONE * 1.0  # 1,75 m
	avatar.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var keep: bool = mi.get_parent() is Skeleton3D or mi.name.ends_with("_Cape") or mi.name.ends_with("_Hat")
		mi.visible = keep
	avatar_anim = model.find_child("AnimationPlayer", true, false)
	for an in ["Idle", "Walking_A", "Running_A", "Jump_Idle"]:   # Death_A : jouée une fois
		if avatar_anim.has_animation(an):
			avatar_anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	avatar_anim.play("Idle")
	var tag := Label3D.new()
	tag.text = "J%d" % (index + 1)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = 0.0008
	tag.font_size = 48
	tag.outline_size = 12
	tag.modulate = col.lightened(0.3)
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.15, 0)
	avatar.add_child(tag)
	_apply_layers(avatar, body_layer())

# ------------------------------------------------------------------ modèles



## Fusil d'assaut (modèle Blender, tools/blender/rifle.py) : boîtier bleu-nuit à fenêtre sur le
## cœur de cristal, bois et cuir, chargeur incurvé, cristal-viseur turquoise.
func _build_rifle() -> void:
	rifle = _gun_from_model(W.RIFLE, "res://assets/weapons/rifle.glb", HIP_POS, ADS_POS.z, 0.82,
		Color(0.2, 0.9, 0.8), Color(1.0, 0.75, 0.35), 6.0)
	rifle_rest_rot = gun_data[W.RIFLE]["rest"]


## Arme à feu en main à partir de son modèle Blender : repères, lueur du viseur, éclair de tir.
## k = échelle du modèle, gscale = échelle du nœud en main (les repères sont en coordonnées de g).
func _gun_from_model(w: int, path: String, hip: Vector3, ads_z: float, gscale: float, sight_col: Color,
		flash_col: Color, rest_deg: float, below := 0.022) -> Node3D:
	var g := Node3D.new()
	g.position = hip
	g.scale = Vector3.ONE * gscale
	g.visible = false
	viewmodel.add_child(g)
	var cmat := _sight_mat(sight_col)
	var mk := _attach_model(g, path, 1.0, cmat)
	# variante de Dieu (modèle fissuré et lumineux, même forme) : cachée jusqu'au déblocage
	var god_path := path.replace(".glb", "_god.glb")
	var god_model: Node3D = null
	if ResourceLoader.exists(god_path):
		god_model = _attach_model(g, god_path, 1.0, cmat)["model"]
		god_model.visible = false
	var glow := OmniLight3D.new()
	glow.light_color = sight_col
	glow.light_energy = 0.2
	glow.omni_range = 0.4
	glow.position = mk["sight"]
	g.add_child(glow)
	var m := Marker3D.new()
	m.position = mk["muzzle"]
	g.add_child(m)
	var fl := Mats.sphere(m, 0.06, Mats.col(flash_col, 0.2, 8.0), Vector3.ZERO, 6)
	fl.visible = false
	var li := OmniLight3D.new()
	li.light_color = flash_col
	li.omni_range = 6.0
	li.light_energy = 0.0
	m.add_child(li)
	gun_data[w] = {"node": g, "muzzle": m, "flash": fl, "light": li, "crystal": cmat, "glow": glow,
		"hip": hip, "ads": _ads_from(mk["sight"], gscale, ads_z, below), "rest": Vector3(0, deg_to_rad(rest_deg), 0),
		"hand_r": mk["hand_r"], "hand_l": mk["hand_l"], "model": mk["model"], "god_model": god_model}
	return g


## Modèle d'arme fait dans Blender (tools/blender/*.py → assets/weapons/*.glb).
## Blender : X = avant, Z = haut → on tourne de 90° pour que l'avant soit -Z.
## Renvoie les repères du modèle (muzzle, sight, hand_r, hand_l) en coordonnées de `g`.
func _attach_model(g: Node3D, path: String, k: float, crystal: StandardMaterial3D = null) -> Dictionary:
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.rotation_degrees.y = 90.0
	inst.scale = Vector3.ONE * k
	g.add_child(inst)
	var out := {}
	for n in ["muzzle", "sight", "hand_r", "hand_l"]:
		var mk := inst.find_child(n, true, false) as Node3D
		if mk:
			out[n] = inst.transform * mk.position
	_tune_model(inst, crystal)
	out["model"] = inst
	return out


## Ajuste les matériaux importés : parties lumineuses plus vives, cristal-viseur qui s'estompe en visée.
func _tune_model(n: Node, crystal: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if crystal and mi.name.begins_with("sight_crystal"):
			mi.material_override = crystal
		else:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if m:
					matte(m)
	for c in n.get_children():
		_tune_model(c, crystal)


## Matériaux Meshy (armes, bras) : très brillants d'origine (rugosité ~0,35), ils reflètent le ciel
## clair et ressortent presque blancs sur un vrai GPU. On les rend mats, façon peinture stylisée,
## et on modère l'émission (sinon le halo lumineux de l'écran les blanchit aussi).
static func matte(m: StandardMaterial3D) -> void:
	m.roughness_texture = null
	m.roughness = 0.78
	m.metallic = minf(m.metallic, 0.45)
	m.metallic_specular = 0.25
	if m.emission_enabled:
		m.emission_energy_multiplier = clampf(m.emission_energy_multiplier, 0.8, 1.6)


## Cristal du viseur (s'estompe quand on vise, voir _physics_process).
func _sight_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Position de visée : le cristal-viseur juste sous le centre de l'écran.
func _ads_from(sight: Vector3, k: float, z: float, below := 0.022) -> Vector3:
	return Vector3(-sight.x * k, -below - sight.y * k, z)


## Pistolet de garde forestier (modèle Blender, tools/blender/pistol.py) : culasse bleu-nuit,
## crosse en bois, laiton, cœur de cristal turquoise visible par la fenêtre, cristal-viseur.
func _build_pistol() -> void:
	_gun_from_model(W.PISTOL, "res://assets/weapons/pistol.glb", PISTOL_HIP, PISTOL_ADS.z - 0.06, 1.25,
		Color(0.2, 0.9, 0.8), Color(1.0, 0.75, 0.35), 12.0)


func _build_axe() -> void:
	axe = Node3D.new()
	axe.position = AXE_POS
	viewmodel.add_child(axe)
	axe_pivot = Node3D.new()
	axe.add_child(axe_pivot)
	# modèle Meshy (visuel OpenArt) : manche vertical, tranchant vers l'avant ; la main (repère hand_r)
	# est ramenée au point de prise historique (0, -0.04, 0)
	var h := Node3D.new()
	h.rotation_degrees = Vector3(-25, 0, 18)
	axe_pivot.add_child(h)
	var mk := _attach_model(h, "res://assets/weapons/axe.glb", 1.0)
	if mk.has("hand_r"):
		(mk["model"] as Node3D).position += Vector3(0, -0.04, 0) - mk["hand_r"]


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
		var sens := MOUSE_SENS * ((0.22 if weapon == W.SNIPER else 0.55) if aiming else 1.0)
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
	elif event.is_action_pressed(a("skill")) and weapon != W.BUILD and has_skill("A7"):
		_cast_fireball()
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
	return w == W.PISTOL or w == W.RIFLE or w == W.CRYO or w == W.SHOCK or w == W.SNIPER or w == W.ZEUS


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
	if has_shock:
		arr.append(W.SHOCK)
	if has_sniper:
		arr.append(W.SNIPER)
	if has_zeus:
		arr.append(W.ZEUS)
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


func owns_craft(id: String) -> bool:
	match id:
		"cryo": return has_cryo
		"shock": return has_shock
		"sniper": return has_sniper
		"zeus": return has_zeus
	return false


## Fabrique une arme (menu de la sphère) : paie le coût et la range dans l'inventaire.
func craft_weapon(id: String) -> bool:
	for r in Upg.CRAFTS:
		if r["id"] == id and not owns_craft(id) and can_afford(r["cost"]):
			pay(r["cost"])
			match id:
				"cryo": unlock_cryo()
				"shock": unlock_shock()
				"sniper": unlock_sniper()
				"zeus": unlock_zeus()
			Sfx.play("build", 0.0, 0.8)
			return true
	return false


func unlock_zeus() -> void:
	has_zeus = true
	if loadout[1] < 0:
		loadout[1] = W.ZEUS
	if hud:
		hud.flash_message("ÉCLAIR DE ZEUS ajouté à l'inventaire")


func unlock_sniper() -> void:
	has_sniper = true
	if loadout[1] < 0:
		loadout[1] = W.SNIPER
	if hud:
		hud.flash_message("FUSIL DE PRÉCISION ajouté à l'inventaire")


## Arme fabriquée / obtenue : rangée dans l'inventaire (et dans l'emplacement 2 s'il est vide).
func unlock_shock() -> void:
	has_shock = true
	if loadout[1] < 0:
		loadout[1] = W.SHOCK
	if hud:
		hud.flash_message("ONDE DE CHOC ajoutée à l'inventaire")


func unlock_rifle() -> void:
	has_rifle = true
	mags[W.RIFLE] = gun_mag(W.RIFLE)
	if loadout[1] < 0:
		loadout[1] = W.RIFLE
	_select_weapon(W.RIFLE)


# ------------------------------------------------------------------ caractéristiques améliorées

func gun_lvl(w: int, branch: String) -> int:
	if w == W.SNIPER:
		return upgrades["sniper"].get(branch, 0)
	if not GUN_KEYS.has(w):
		return 0   # le canon cryogénique n'a pas (encore) d'arbre d'amélioration
	return upgrades[GUN_KEYS[w]][branch]


## Multiplicateur de la variante de Dieu de l'arme (×2 si débloquée, ×1 sinon).
func god_mult(w: int) -> float:
	return Upg.GOD_MULT if god.get(GOD_KEYS.get(w, ""), false) else 1.0


func gun_mag(w: int) -> int:
	return int(Upg.mag_size(GUNS[w]["mag"], gun_lvl(w, "mag")) * god_mult(w))


func gun_interval(w: int) -> float:
	return GUNS[w]["interval"] * Upg.fire_interval_mult(gun_lvl(w, "rate")) / god_mult(w)


func gun_damage(w: int) -> float:
	return GUNS[w]["damage"] * Upg.damage_mult(gun_lvl(w, "damage")) * god_mult(w)


## Débloque la variante de Dieu d'une arme (toutes ses branches au maximum + 5 bois, 5 pierres
## et 5 nuages magiques). Le cristal de l'arme devient doré.
func unlock_god(item: String) -> bool:
	if god.get(item, false) or not Upg.GOD_ITEMS.has(item) or not Upg.all_maxed(upgrades, item):
		return false
	if not can_afford(Upg.GOD_COST):
		return false
	pay(Upg.GOD_COST)
	god[item] = true
	for w in GOD_KEYS:
		if GOD_KEYS[w] == item:
			if GUNS[w]["mag"] > 0:
				mags[w] = gun_mag(w)
				if weapon == w:
					ammo = mags[w]
			_gild(w)
	Sfx.play("orb_hit", -2.0, 0.8)
	if hud:
		hud.show_notice("%s DÉBLOQUÉ !\nDégâts ×2, cadence ×2, chargeur ×2, rechargement 2× plus rapide." % Upg.GOD_NAMES[item], 6.0)
	return true


## Variante de Dieu : le cristal-viseur et sa lueur deviennent dorés.
func _gild(w: int) -> void:
	if not gun_data.has(w):
		return
	if gun_data[w].get("god_model"):
		gun_data[w]["model"].visible = false
		gun_data[w]["god_model"].visible = true
	var gold := Color(1.0, 0.78, 0.3)
	var m: StandardMaterial3D = gun_data[w]["crystal"]
	m.albedo_color = Color(gold.r, gold.g, gold.b, m.albedo_color.a)
	m.emission = gold
	(gun_data[w]["glow"] as OmniLight3D).light_color = gold


func can_afford(c: Dictionary) -> bool:
	if test_mode:
		return true
	for k in c:
		if res_count(k) < c[k]:
			return false
	return true


## Paie un coût (bois, pierre, pièces, os...). Rien en mode test.
func pay(c: Dictionary) -> void:
	if test_mode:
		return
	for k in c:
		set(RES_PROPS[k], res_count(k) - c[k])


## Achète le niveau suivant d'une branche (si le précédent est acquis et qu'on a les ressources).
func buy_upgrade(item: String, branch: String) -> bool:
	var lvl: int = upgrades[item][branch]
	if lvl >= Upg.max_level(item, branch):
		return false
	var c := Upg.cost(item, branch, lvl + 1)
	if not can_afford(c):
		return false
	pay(c)
	upgrades[item][branch] = lvl + 1
	if item == "axe" and branch == "wood" and lvl + 1 == Upg.STONE_UNLOCK_LEVEL and hud:
		hud.show_notice("PIERRE DÉBLOQUÉE !\nTa hache peut maintenant casser les rochers pour récolter de la pierre.\nConstruire en pierre : 2× plus solide que le bois (V / Y pour changer de matériau).", 8.0)
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
	spd *= move_speed_mult()
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
	shock_cd -= delta
	sniper_cd -= delta
	zeus_cd -= delta
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
		W.ZEUS:
			if firing and not trigger_held and zeus_cd <= 0.0:
				if magic_clouds < 1 and not test_mode:
					if hud:
						hud.flash_message("Il faut 1 NUAGE MAGIQUE par éclair")
				else:
					_shoot_zeus()
			trigger_held = firing
		W.SNIPER:
			if firing and not trigger_held and sniper_cd <= 0.0:
				if bones < 1 and not test_mode:
					if hud:
						hud.flash_message("Il faut 1 OS par balle (les squelettes en laissent tomber)")
				else:
					_shoot_sniper()
			trigger_held = firing
		W.SHOCK:
			if firing and not trigger_held and shock_cd <= 0.0:
				if bones < 1 and not test_mode:
					if hud:
						hud.flash_message("Il faut 1 OS par tir (les squelettes en laissent tomber)")
				else:
					_shoot_shock()
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


func _animate_avatar() -> void:
	if avatar_anim == null:
		return
	var want := "Idle"
	var spd := Vector2(velocity.x, velocity.z).length()
	if dead:
		want = "Death_A"
	elif not is_on_floor():
		want = "Jump_Idle"
	elif spd > 7.5:
		want = "Running_A"
	elif spd > 0.6:
		want = "Walking_A"
	if avatar_anim.current_animation != want:
		avatar_anim.play(want, 0.2)


func _process(delta: float) -> void:
	_animate_avatar()
	_update_arms()
	if zeus_ray_boost > 0.0:
		zeus_ray_boost = move_toward(zeus_ray_boost, 0.0, delta * 2.5)
		for m in zeus_ray_mats:
			m.set_shader_parameter("boost", zeus_ray_boost)
	_update_skills(delta)
	if test_mode:
		wood = RES_MAX
		stone = RES_MAX
		coins = RES_MAX
		magic_wood = MAGIC_MAX
		magic_stone = MAGIC_MAX
		clouds = RES_MAX
	# Visée au stick droit (courbe quadratique pour la précision)
	if not dead and not get_tree().paused and not input_blocked():
		var look := Input.get_vector(a("look_left"), a("look_right"), a("look_up"), a("look_down"))
		if look.length() > 0.0:
			look = look * look.length()
			var spd := STICK_LOOK_SPEED * ((0.2 if weapon == W.SNIPER else 0.45) if aiming else 1.0)
			rotate_y(-look.x * spd * delta)
			head.rotation.x = clampf(head.rotation.x - look.y * spd * 0.75 * delta, -1.5, 1.5)
	# Animations de l'arme en main (balancement, recul, visée)
	cam.fov = lerpf(cam.fov, (18.0 if weapon == W.SNIPER else 55.0) if aiming else 80.0, minf(14.0 * delta, 1.0))
	# lunette : l'arme disparaît quand on vise (vue à travers la lunette, voir l'interface)
	viewmodel.visible = not dead and not (weapon == W.SNIPER and ads_t > 0.7)
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
	if not _is_gun(weapon) or weapon == W.CRYO or weapon == W.SHOCK or weapon == W.SNIPER or weapon == W.ZEUS or reloading or ammo >= gun_mag(weapon):
		return
	reloading = true
	reload_t = GUNS[weapon]["reload"] * Upg.reload_mult(gun_lvl(weapon, "reload")) * (0.75 if has_skill("A4") else 1.0) / god_mult(weapon)
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
			if is_head:
				add_stat("headshots")
			deal_damage(c, gun_damage(weapon) * ((2.5 if has_skill("A5") else 2.0) if is_head else 1.0), is_head, "gun")
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
			var gm := god_mult(W.CRYO)
			c.apply_frost(Upg.CRYO_STACKS_PER_TICK * gm, Upg.cryo_max_slow(cu["slow"]), Upg.cryo_max_vuln(cu["vuln"]), Upg.cryo_stack_time(cu["duration"]))
			deal_damage(c, GUNS[W.CRYO]["damage"] * Upg.cryo_damage_mult(cu["damage"]) * gm, false, "gun")
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


# ------------------------------------------------------------------ onde de choc

func shock_damage() -> float:
	return Upg.shock_damage(upgrades["shock"]["damage"]) * god_mult(W.SHOCK)


func shock_cooldown() -> float:
	return Upg.shock_cooldown(upgrades["shock"]["cooldown"]) / god_mult(W.SHOCK)


func shock_range() -> float:
	return Upg.shock_range(upgrades["shock"]["range"]) + (2.0 if has_skill("A6") else 0.0)


## Onde de choc : coûte 1 os ; tous les squelettes dans un large cône devant soi
## (120°, portée 6 m de base) prennent les dégâts instantanément.
func _shoot_shock() -> void:
	shock_cd = shock_cooldown()
	if not test_mode:
		bones -= 1
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var origin := global_position
	var rng := shock_range()
	var cos_lim := cos(deg_to_rad(Upg.SHOCK_HALF_ANGLE))
	var hits := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.dead:
			continue
		var d: Vector3 = z.global_position - origin
		if absf(d.y) > 3.5:
			continue
		d.y = 0.0
		var reach := rng + (2.0 if z.is_in_group("titan") else 0.4)
		if d.length() > reach:
			continue
		if d.length() > 0.8 and d.normalized().dot(fwd) < cos_lim:
			continue
		deal_damage(z, shock_damage(), false, "shock")
		hits += 1
	if hud and hits > 0:
		hud.hitmarker(false)
	recoil = 1.0
	_shake(0.03)
	Sfx.play("break", -2.0, 1.6)
	Sfx.play("orb_hit", -4.0, 0.6)
	_spawn_shock_fx(origin + Vector3.UP * 0.9, fwd, rng)


## Effet visible : éventail translucide qui s'élargit jusqu'à la portée puis s'efface.
func _spawn_shock_fx(pos: Vector3, fwd: Vector3, rng: float) -> void:
	if main == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(Upg.SHOCK_HALF_ANGLE)
	var segs := 20
	for i in segs:
		var a0 := -half + 2.0 * half * i / segs
		var a1 := -half + 2.0 * half * (i + 1) / segs
		for v in [Vector3.ZERO, Vector3(sin(a0), 0, -cos(a0)), Vector3(sin(a1), 0, -cos(a1))]:
			st.set_uv(Vector2(v.length(), 0))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.95, 0.9, 0.75, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	mi.global_position = pos
	mi.global_basis = Basis.looking_at(fwd, Vector3.UP)
	mi.scale = Vector3.ONE * 0.5
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(rng, 1.0, rng), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)
	main.spawn_impact(pos + fwd * rng * 0.6 - Vector3.UP * 0.8, Vector3.UP, Color(0.9, 0.85, 0.7), 16, 1.4)


# ------------------------------------------------------------------ éclair de Zeus

func zeus_level(branch: String) -> int:
	return upgrades["zeus"][branch]


## Éclair de Zeus : 1 nuage magique ; la foudre frappe N ennemis AU HASARD parmi tous ceux présents
## sur la carte (anges compris). Moins de cibles seulement s'il y a moins de N ennemis.
## Puis le « toucher divin » augmente tes dégâts quelques secondes (relancé à chaque tir).
func _shoot_zeus() -> void:
	zeus_ray_boost = 1.0
	var n: int = Upg.ZEUS_TARGETS[zeus_level("targets")]
	var dmg: float = Upg.ZEUS_DAMAGE[zeus_level("damage")]
	var cands := []
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.dead:
			continue
		cands.append([0.0, z, z.global_position + Vector3.UP * (5.0 if z.is_in_group("titan") else 1.2)])
	if cands.is_empty():
		if hud:
			hud.flash_message("Aucun ennemi sur la carte")
		zeus_cd = 0.3
		return
	cands.shuffle()
	zeus_cd = Upg.ZEUS_COOLDOWN
	if not test_mode:
		magic_clouds -= 1
	recoil = 1.2
	_shake(0.03)
	Sfx.play("break", 0.0, 1.8)
	Sfx.play("horn", -10.0, 2.2)
	var from: Vector3 = muzzle.global_position
	var hits := 0
	for i in mini(n, cands.size()):
		var z = cands[i][1]
		var c: Vector3 = cands[i][2]
		_spawn_bolt(from, c)
		_spawn_bolt(c + Vector3(randf_range(-2, 2), 30.0, randf_range(-2, 2)), c)
		deal_damage(z, dmg, false, "zeus")
		main.spawn_impact(c, Vector3.UP, Color(0.8, 0.9, 1.0), 14, 1.4)
		hits += 1
	if hud:
		hud.hitmarker(false)
	# toucher divin (s'il est amélioré)
	var boost: float = Upg.ZEUS_BOOST[zeus_level("boost")]
	if boost > 0.0:
		divine_boost = boost
		divine_t = Upg.ZEUS_DURATION[zeus_level("duration")]


## Éclair visible : ligne brisée lumineuse entre deux points, qui s'efface vite.
func _spawn_bolt(a: Vector3, b: Vector3) -> void:
	var root := Node3D.new()
	main.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.88, 1.0, 1.0)
	var segs := 8
	var prev := a
	var dir := b - a
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var pt := a + dir * t
		if i < segs:
			pt += side * randf_range(-0.6, 0.6) + Vector3.UP * randf_range(-0.4, 0.4)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, prev.distance_to(pt))
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = (prev + pt) * 0.5
		var up := Vector3.UP if absf((pt - prev).normalized().y) < 0.98 else Vector3.RIGHT
		mi.look_at(pt, up)
		prev = pt
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.85, 1.0)
	l.light_energy = 5.0
	l.omni_range = 10.0
	root.add_child(l)
	l.global_position = b
	var tw := root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(root.queue_free)


## Éclair de Zeus en main (modèle Blender, tools/blender/zeus.py) : marbre et or, éclair de cristal
## tenu par trois griffes, volutes de nuage.
func _build_zeus() -> void:
	var g := _gun_from_model(W.ZEUS, "res://assets/weapons/zeus.glb", HIP_POS + Vector3(0, 0.02, 0), -0.66, 0.62,
		Color(0.6, 0.85, 1.0), Color(0.7, 0.85, 1.0), 6.0, 0.06)
	gun_data[W.ZEUS]["glow"].light_energy = 0.6
	gun_data[W.ZEUS]["glow"].light_color = Color(1.0, 0.97, 0.9)
	_add_light_rays(g)


const RAY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
uniform float h = 0.1;
uniform float boost = 0.0;
varying float t;
void vertex() { t = clamp(VERTEX.y / h + 0.5, 0.0, 1.0); }
void fragment() {
	// rayon : intense à la sortie de la fissure, s'estompe vers le bout ; bords doux (vu de face)
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float flick = 0.55 + 0.45 * sin(TIME * 2.3 + phase) * sin(TIME * 1.3 + phase * 1.7);
	ALBEDO = vec3(1.0, 0.96, 0.88) * 1.6;
	ALPHA = (1.0 - t) * (1.0 - t) * pow(face, 2.0) * (flick + boost * 1.5) * 0.55;
}
"""
var zeus_ray_mats: Array[ShaderMaterial] = []
var zeus_ray_boost := 0.0


## Rayons de lumière blanche qui sortent des fissures du canon de Zeus (comme le soleil à travers
## les nuages) : cônes additifs le long du canon, qui scintillent et s'embrasent à chaque tir.
## Positions en coordonnées Blender du modèle (X = avant, Z = haut), converties comme _attach_model.
func _add_light_rays(g: Node3D) -> void:
	var sh := Shader.new()
	sh.code = RAY_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 12:
		var bx := rng.randf_range(-0.13, 0.06)                 # le long du canon de marbre
		var a := rng.randf_range(-PI * 0.95, PI * 0.95) + PI * 0.5   # surtout vers le haut et les côtés
		var radial := Vector3(0, cos(a), sin(a))
		var base_bl := Vector3(bx, 0.0, 0.03) + radial * 0.034
		var dir_bl := (radial + Vector3(rng.randf_range(-0.4, 0.4), 0, 0)).normalized()
		var to_g := func(v: Vector3) -> Vector3: return Vector3(-v.y, v.z, -v.x)   # Blender -> Godot (modèle tourné de 90°)
		var base: Vector3 = to_g.call(base_bl)
		var dir: Vector3 = to_g.call(dir_bl)
		var hgt := rng.randf_range(0.07, 0.16)
		var cm := CylinderMesh.new()
		cm.height = hgt
		cm.bottom_radius = rng.randf_range(0.003, 0.006)
		cm.top_radius = rng.randf_range(0.022, 0.04)
		cm.radial_segments = 12
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("phase", rng.randf() * TAU)
		m.set_shader_parameter("h", hgt)
		zeus_ray_mats.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var up := Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var x := up.cross(dir).normalized()
		mi.transform = Transform3D(Basis(x, dir, x.cross(dir)), base + dir * hgt * 0.5)
		g.add_child(mi)


# ------------------------------------------------------------------ fusil de précision

func sniper_damage() -> float:
	return Upg.sniper_damage(upgrades["sniper"]["damage"]) * god_mult(W.SNIPER)


func sniper_cooldown() -> float:
	return Upg.sniper_cooldown(upgrades["sniper"]["cooldown"]) / god_mult(W.SNIPER)


## Multiplicateur de tir à la tête : ×3 de base (au lieu de ×2), amélioré, +0,5 avec « Tête froide ».
func sniper_headshot() -> float:
	return Upg.sniper_headshot(upgrades["sniper"]["headshot"]) + (0.5 if has_skill("A5") else 0.0)


## Tir au fusil de précision : 1 os par balle, très précis en visant, gros dégâts.
func _shoot_sniper() -> void:
	sniper_cd = sniper_cooldown()
	if not test_mode:
		bones -= 1
	recoil = 1.6
	flash_t = 0.06
	Sfx.play("shot", 0.0, 0.62)
	var spread: float = 0.0005 if aiming else GUNS[W.SNIPER]["spread"]
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		spread += 0.01
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * randf_range(-spread, spread) + b.y * randf_range(-spread, spread)).normalized()
	var from := cam.global_position
	var to := from + dir * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SHOOT)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not r.is_empty():
		end = r.position
		var c = r.collider
		if c and c.is_in_group("zombie"):
			var is_head: bool = r.position.y > c.global_position.y + c.head_height
			if is_head:
				add_stat("headshots")
			deal_damage(c, sniper_damage() * (sniper_headshot() if is_head else 1.0), is_head, "gun")
			if hud:
				hud.hitmarker(is_head)
			Sfx.play("headshot" if is_head else "hit", -2.0)
			main.spawn_impact(end, r.normal, Color(0.35, 0.85, 0.2), 16, 1.4)
		else:
			main.spawn_impact(end, r.normal, Color(1.0, 0.85, 0.55), 10, 0.9)
	main.spawn_tracer(muzzle.global_position, end)
	head.rotation.x = clampf(head.rotation.x + (0.02 if aiming else 0.09), -1.5, 1.5)


## Fusil de précision en main (modèle Blender, tools/blender/sniper.py) : crosse pleine en bois
## avec incrustation d'os en flèche, lunette à bagues de laiton.
func _build_sniper() -> void:
	_gun_from_model(W.SNIPER, "res://assets/weapons/sniper.glb", HIP_POS, -0.45, 0.82,
		Color(0.3, 0.65, 1.0), Color(1.0, 0.85, 0.5), 5.0)


## Onde de choc en main (modèle Blender, tools/blender/shock.py) : corne d'os en pavillon,
## anneaux de laiton, cœur ambré en cage.
func _build_shock() -> void:
	_gun_from_model(W.SHOCK, "res://assets/weapons/shock.glb", HIP_POS, -0.6, 0.82,
		Color(1.0, 0.6, 0.2), Color(1.0, 0.75, 0.4), 6.0, 0.07)


## Canon cryogénique (modèle Blender, tools/blender/cryo.py) : coque givrée, réservoir de verre
## et éclats de glace lumineux, émetteur à ailettes entouré de cristaux.
func _build_cryo() -> void:
	_gun_from_model(W.CRYO, "res://assets/weapons/cryo.glb", HIP_POS, -0.62, 0.82,
		Color(0.4, 0.85, 1.0), Color(0.5, 0.9, 1.0), 6.0, 0.075)
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
	swing_cd = 0.9 / (1.2 if has_skill("F3") else 1.0)     # cadence réduite : viser les cibles devient plus rentable que taper vite
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


# ------------------------------------------------------------------ compétences

func has_skill(id: String) -> bool:
	return skills.get(id, false)


func stat(k: String) -> float:
	return stats.get(k, 0.0)


func add_stat(k: String, v := 1.0) -> void:
	stats[k] = stats.get(k, 0.0) + v


## État d'une compétence : "owned", "ready" (débloquable), "need_stat", "need_parent".
func skill_state(id: String) -> String:
	if has_skill(id):
		return "owned"
	var sk: Dictionary = Skills.SKILLS[id]
	if sk["parent"] != "" and not has_skill(sk["parent"]):
		return "need_parent"
	if stat(sk["stat"]) < sk["need"] and not test_mode:
		return "need_stat"
	return "ready"


func unlock_skill(id: String) -> bool:
	if skill_state(id) != "ready" or (skill_tokens < 1 and not test_mode):
		return false
	if not test_mode:
		skill_tokens -= 1
	skills[id] = true
	match id:
		"D1":
			hp = minf(hp + 20.0, max_hp())
		"D4", "D7":
			shield = shield_max()
		"D9":
			lives += 1
	Sfx.play("build", 0.0, 1.4)
	return true


func max_hp() -> float:
	return MAX_HP + (20.0 if has_skill("D1") else 0.0)


func shield_max() -> float:
	if has_skill("D7"):
		return 25.0
	return 10.0 if has_skill("D4") else 0.0


func move_speed_mult() -> float:
	return 1.1 if has_skill("D3") else 1.0


func harvest_bonus(kind: String) -> float:
	var m := 1.0
	if kind == "wood" and has_skill("F1"):
		m += 0.10
	if kind == "stone" and has_skill("F2"):
		m += 0.10
	if has_skill("F4"):
		m += 0.15
	return m


## Multiplicateur de dégâts selon la source (« gun », « axe », « shock », « fire »).
func dmg_mult(src: String) -> float:
	var m := 1.05 if has_skill("A1") else 1.0
	if divine_t > 0.0:
		m *= 1.0 + divine_boost   # toucher divin (éclair de Zeus)
	if src == "gun" and has_skill("A2"):
		m *= 1.10
	if src == "axe" and has_skill("A3"):
		m *= 1.40
	if src == "shock" and has_skill("A6"):
		m *= 1.15
	return m


## Inflige des dégâts à un ennemi en appliquant les compétences, et compte les éliminations.
func deal_damage(c, amount: float, head: bool, src: String) -> void:
	if c == null or not is_instance_valid(c) or c.dead:
		return
	amount *= dmg_mult(src)
	if has_skill("A8") and c.hp < c.max_hp * 0.3:
		amount *= 1.3
	c.take_damage(amount, head)
	if c.dead:
		register_kill(c, src)


func register_kill(c, src: String) -> void:
	add_stat("kills")
	match src:
		"gun": add_stat("kills_gun")
		"axe": add_stat("kills_axe")
		"shock": add_stat("kills_shock")
		"fire": add_stat("kills_fire")
	if c.is_boss and not c.is_in_group("titan"):
		add_stat("boss_kills")


func repair_price(st) -> int:
	var c: int = st.repair_cost()
	if has_skill("F8") and not st.is_magic():
		c = maxi(1, int(ceil(c * 0.8)))
	return c


## Jeton de compétence (fin de vague, titan).
func gain_tokens(n: int) -> void:
	skill_tokens += n
	if hud:
		hud.flash_message("+%d JETON%s DE COMPÉTENCE  (inventaire → page PERSONNAGE)" % [n, "S" if n > 1 else ""])


## Boule de feu (compétence A7) : projectile qui brûle la cible.
func _cast_fireball() -> void:
	if not has_skill("A7") or dead or fireball_cd > 0.0:
		return
	fireball_cd = 8.0 if has_skill("A9") else 12.0
	var fb := Fireball.new()
	fb.owner_player = self
	fb.explode = has_skill("A9")
	var dir := -cam.global_transform.basis.z
	fb.velocity = dir * 32.0
	main.add_child(fb)
	fb.global_position = cam.global_position + dir * 1.0 - cam.global_transform.basis.y * 0.15
	Sfx.play("orb_hit", -2.0, 0.7)


class Fireball extends Node3D:
	var owner_player
	var velocity := Vector3.ZERO
	var explode := false
	var life := 2.5

	func _ready() -> void:
		Mats.sphere(self, 0.28, Mats.col(Color(1.0, 0.5, 0.12), 0.5, 6.0), Vector3.ZERO, 10)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 2.5
		l.omni_range = 5.0
		add_child(l)

	func _physics_process(delta: float) -> void:
		life -= delta
		var from := global_position
		var to := from + velocity * delta
		var hit = null
		for z in get_tree().get_nodes_in_group("zombie"):
			if z.dead:
				continue
			var c: Vector3 = z.global_position + Vector3.UP * (5.0 if z.is_in_group("titan") else 1.0)
			var ab := to - from
			var t := clampf((c - from).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if (from + ab * t).distance_to(c) < (2.5 if z.is_in_group("titan") else 1.0):
				hit = z
				break
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 16)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if hit or not r.is_empty() or life <= 0.0:
			_burst(to if r.is_empty() else r.position, hit)
			return
		global_position = to

	func _burst(pos: Vector3, hit) -> void:
		var p = owner_player
		var targets := []
		if hit:
			targets.append(hit)
		if explode:
			for z in get_tree().get_nodes_in_group("zombie"):
				if not z.dead and z != hit and z.global_position.distance_to(pos) < 4.0:
					targets.append(z)
		for z in targets:
			if is_instance_valid(p):
				p.deal_damage(z, 180.0, false, "fire")
			if is_instance_valid(z) and not z.dead and z.has_method("ignite"):
				z.ignite(5.0, 36.0 * (p.dmg_mult("fire") if is_instance_valid(p) else 1.0), p)
		if is_instance_valid(p) and p.main:
			p.main.spawn_impact(pos, Vector3.UP, Color(1.0, 0.5, 0.1), 24 if explode else 12, 2.0 if explode else 1.2)
		Sfx.play_3d("break", pos, 0.0, 1.3)
		queue_free()


func _update_skills(delta: float) -> void:
	fireball_cd = maxf(fireball_cd - delta, 0.0)
	divine_t = maxf(divine_t - delta, 0.0)
	if dead:
		_last_pos = Vector3.INF
		return
	since_hit += delta
	var sm := shield_max()
	if sm > 0.0 and since_hit > 2.0 and shield < sm:
		shield = minf(shield + sm / 10.0 * delta, sm)
	if has_skill("D5") and since_hit > 5.0 and hp < max_hp():
		hp = minf(hp + 2.0 * delta, max_hp())
	var gp := Vector3(global_position.x, 0, global_position.z)
	if _last_pos != Vector3.INF:
		var dd := gp.distance_to(_last_pos)
		if dd < 2.0:          # (une téléportation ne compte pas)
			add_stat("distance", dd)
	_last_pos = gp
	if test_mode:
		skill_tokens = maxi(skill_tokens, 99)


func _axe_impact() -> void:
	if dead or weapon != W.AXE:
		return
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 3.3
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8 | 16 | 32 | 128)   # 128 : petits nuages
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var c = r.collider
	_shake(0.012)
	if c and c.is_in_group("cloud_res"):
		c.harvest(self)
		_shake(0.015)
	elif c and c.is_in_group("rock"):
		var got: int = c.mine(AXE_TREE_DAMAGE, r.position, can_mine_stone())
		var tgt_mult := 1.5 if (c.last_target_hit and has_skill("F5")) else 1.0
		got = int(round(got * Upg.harvest_mult(upgrades["axe"]["stone"]) * harvest_bonus("stone") * tgt_mult))
		if c.last_target_hit and got > 0:
			add_stat("targets")
		add_stat("harvested", got)
		if c.broken and got > 0:
			add_stat("rocks")
		if c.magic and c.broken:
			_gain_magic("magic_stone")
		if got > 0:
			stone = mini(stone + got, RES_MAX)
			if hud:
				hud.stone_gain(got)
				if c.last_target_hit:
					hud.hitmarker(true)
		elif hud and not can_mine_stone():
			hud.flash_message("Récolter la pierre : améliore la hache (récolte de bois) au niveau %d" % Upg.STONE_UNLOCK_LEVEL)
		main.spawn_impact(r.position, r.normal, Color(0.5, 0.5, 0.6), 10, 1.0)
		_shake(0.02)
	elif c and c.is_in_group("tree"):
		var gained: int = c.chop(AXE_TREE_DAMAGE, r.position)
		var tgt_mult := 1.5 if (c.last_target_hit and has_skill("F5")) else 1.0
		gained = int(round(gained * Upg.harvest_mult(upgrades["axe"]["wood"]) * harvest_bonus("wood") * tgt_mult))
		if c.last_target_hit and gained > 0:
			add_stat("targets")
		add_stat("harvested", gained)
		if c.fallen and gained > 0:
			add_stat("trees")
		wood = mini(wood + gained, RES_MAX)
		if c.magic and c.fallen and gained > 0:
			_gain_magic("magic_wood")
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
		deal_damage(c, AXE_ZOMBIE_DAMAGE, false, "axe")
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
	ghost_valid = _material_count(build_mat) >= build_cost() and not main.structures.has(ghost_info["key"])
	ghost_ok_mat.albedo_color = [Color(0.3, 0.7, 1.0, 0.35), Color(0.75, 0.7, 1.0, 0.4), Color(0.3, 1.0, 0.55, 0.4), Color(0.75, 0.45, 1.0, 0.45), Color(0.95, 0.97, 1.0, 0.45)][build_mat]
	ghost.material_override = ghost_ok_mat if ghost_valid else ghost_bad_mat


func _place() -> void:
	if ghost_info.is_empty():
		return
	if not ghost_valid:
		if _material_count(build_mat) < build_cost() and hud:
			hud.flash_message(["Pas assez de bois ! Coupe des arbres (hache)", "Pas assez de pierre ! Casse des rochers (hache)",
				"Plus de bois magique ! Abats un arbre magique (lueur verte)", "Plus de pierre magique ! Casse un rocher magique (cristaux violets)", "Pas assez de nuages ! Frappe les petits nuages à la hache"][build_mat])
		build_cd = 0.4
		return
	_spend(build_mat, build_cost())
	add_stat("built")
	build_cd = 0.15
	main.place_structure(build_piece, ghost_info["xform"], ghost_info["key"], build_mat)


## La pierre se récolte une fois la hache (récolte de bois) au niveau 5.
func can_mine_stone() -> bool:
	return test_mode or upgrades["axe"]["wood"] >= Upg.STONE_UNLOCK_LEVEL


func _material_count(m: int) -> int:
	return [wood, stone, magic_wood, magic_stone, clouds][m]


## Coût d'une pièce dans le matériau choisi (10 bois / pierre, ou 1 bois / pierre magique).
func build_cost(m := -1) -> int:
	if m < 0:
		m = build_mat
	if m == 2 or m == 3:
		return MAGIC_BUILD_COST
	return 8 if has_skill("F8") else BUILD_COST


func _spend(m: int, amount: int) -> void:
	if test_mode:
		return
	match m:
		0: wood -= amount
		1: stone -= amount
		2: magic_wood -= amount
		3: magic_stone -= amount
		4: clouds -= amount


## Matériau suivant : bois → pierre (si débloquée) → bois magique → pierre magique (si on en a).
func _toggle_material() -> void:
	var order := [0, 1, 4, 2, 3]
	var next := build_mat
	var at := order.find(build_mat)
	for k in range(1, 6):
		var m: int = order[(at + k) % 5]
		if m == 1 and stone <= 0 and not can_mine_stone():
			continue
		if m >= 2 and _material_count(m) <= 0:
			continue   # bois / pierre magiques, nuage : seulement si on en a
		next = m
		break
	if next == build_mat:
		if hud:
			if stone <= 0 and not can_mine_stone():
				hud.flash_message("Pas de pierre : trouve-en dans un coffre, ou améliore la hache (bois) au niveau %d" % Upg.STONE_UNLOCK_LEVEL)
			else:
				hud.flash_message("Aucun autre matériau disponible")
		return
	build_mat = next
	if hud:
		hud.flash_message("Matériau : " + MAT_NAMES[build_mat])
	Sfx.play("equip", -6.0)
	if weapon != W.BUILD:
		_select_weapon(W.BUILD)
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
	var cost: int = repair_price(build_target)
	if cost == 0:
		hud.flash_message("Cette construction est intacte")
		return
	var m: int = build_target.repair_material()
	if _material_count(m) < cost:
		hud.flash_message("Il faut %d %s pour réparer" % [cost, MAT_NAMES[m].to_lower()])
		return
	_spend(m, cost)
	build_target.repair()


## Ajoute des ressources (bois, pierre, pièces) dans la limite du maximum. Renvoie la quantité prise.
func add_resource(kind: String, amount: int) -> int:
	var prop: String = RES_PROPS[kind]
	var have: int = get(prop)
	var take := mini(amount, (MAGIC_MAX if kind.begins_with("magic") else RES_MAX) - have)
	set(prop, have + take)
	return take


## Dépose au sol, devant soi, une quantité d'une ressource.
func drop_resource(kind: String, amount: int) -> void:
	var prop: String = RES_PROPS[kind]
	var have: int = get(prop)
	amount = mini(amount, have)
	if amount <= 0 or main == null:
		return
	set(prop, have - amount)
	var fwd := -global_transform.basis.z
	main.spawn_resource_drop(kind, amount, global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 1.6, self)


## Arbre / rocher magique terminé : +1 bois ou pierre magique.
func _gain_magic(kind: String) -> void:
	add_resource(kind, 1)
	add_stat("magic")
	if has_skill("F7") and randf() < 0.5:
		add_resource(kind, 1)
	Sfx.play("coin", 0.0, 0.7)
	if hud:
		hud.res_gain(kind, 1)
		var wood_k := kind == "magic_wood"
		hud.show_notice(("+1 BOIS MAGIQUE !\nIl permet de construire 1 pièce (mur, sol ou rampe) couverte de mousse,\n5× plus solide qu'une pièce en bois améliorée au maximum." if wood_k else
			"+1 PIERRE MAGIQUE !\nElle permet de construire 1 pièce (mur, sol ou rampe) couverte de mousse,\n5× plus solide qu'une pièce en pierre améliorée au maximum.") +
			"\nChoisis-la en mode construction (V / Y). Réparation : jusqu'à 1000 %s." % ("bois" if wood_k else "pierre"), 8.0)


func res_count(kind: String) -> int:
	return get(RES_PROPS[kind])


## Tas d'os imposant : se transforme en 6 os imposants + 10 os.
func use_bone_pile() -> bool:
	if bone_piles <= 0:
		return false
	bone_piles -= 1
	add_resource("big_bone", 6)
	add_resource("bone", 10)
	Sfx.play("coin", 0.0, 0.6)
	return true


func collect_coin() -> void:
	coins = mini(coins + 1, RES_MAX)
	add_stat("coins")
	if has_skill("F6") and randf() < 0.25:
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
	var m: int = build_target.repair_material()
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
	# esquive, défense apportée par l'arme en main, peau dure, bouclier
	if has_skill("D6") and randf() < 0.10:
		if hud:
			hud.flash_message("ESQUIVE !")
		return
	if _is_gun(weapon):
		amount *= 1.0 - Upg.defense(gun_lvl(weapon, "defense"))
	if has_skill("D2"):
		amount *= 0.9
	since_hit = 0.0
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		add_stat("shield_absorbed", absorbed)
		if amount <= 0.0:
			Sfx.play("orb_hit", -8.0, 1.6)
			return
	add_stat("dmg_taken", amount)
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


func respawn(pos: Vector3, invuln := 3.0) -> void:
	dead = false
	can_revive = false
	invuln_t = invuln
	hp = max_hp()
	shield = shield_max()
	mags = {W.PISTOL: gun_mag(W.PISTOL), W.RIFLE: gun_mag(W.RIFLE), W.CRYO: 0, W.SHOCK: 0, W.SNIPER: 0, W.ZEUS: 0}
	ammo = gun_mag(weapon) if _is_gun(weapon) else ammo
	reloading = false
	position = pos
	velocity = Vector3.ZERO
	head.position.y = 1.6
	head.rotation = Vector3.ZERO
	viewmodel.visible = true
	_select_weapon(weapon, true)
