extends StaticBody3D
## Petit nuage à récolter (zone céleste). On passe au travers (couche 128 : ni le joueur ni les
## squelettes ne la heurtent, les balles non plus), mais le coup de hache le touche.
## Un seul coup le brise : +10 nuages. Nuage magique (1 chance sur 250 à chaque apparition) :
## +1 nuage magique et, au hasard, +1 bois magique ou +1 pierre magique.

const Mats = preload("res://scripts/mats.gd")
const LAYER := 128
const YIELD := 10
const MAGIC_CHANCE := 1.0 / 250.0

var main
var magic := false
var floating := false        # nuage en l'air (sinon posé au sol)
var visual: Node3D
var t := 0.0
static var _mat: StandardMaterial3D
static var _magic_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("cloud_res")
	collision_layer = LAYER
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.9
	cs.shape = sh
	cs.position.y = 0.6
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	var m := _magic_material() if magic else _material()
	var n := randi_range(4, 6)
	for i in n:
		var a := TAU * i / n + randf_range(-0.3, 0.3)
		var r := randf_range(0.25, 0.6)
		Mats.sphere(visual, randf_range(0.35, 0.55), m, Vector3(cos(a) * r, 0.5 + randf_range(-0.1, 0.25), sin(a) * r), 10)
	Mats.sphere(visual, 0.6, m, Vector3(0, 0.75, 0), 12)
	t = randf() * TAU
	if magic:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.4)
		l.light_energy = 2.0
		l.omni_range = 6.0
		l.position.y = 0.8
		add_child(l)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE * randf_range(0.9, 1.25), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.95, 0.97, 1.0)
		_mat.roughness = 1.0
		_mat.emission_enabled = true
		_mat.emission = Color(0.55, 0.6, 0.75)
		_mat.emission_energy_multiplier = 0.2
		_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return _mat


static func _magic_material() -> StandardMaterial3D:
	if _magic_mat == null:
		_magic_mat = _material().duplicate()
		_magic_mat.albedo_color = Color(1.0, 0.92, 0.65)
		_magic_mat.emission = Color(1.0, 0.75, 0.3)
		_magic_mat.emission_energy_multiplier = 0.9
	return _magic_mat


func _process(delta: float) -> void:
	t += delta
	visual.position.y = sin(t * 1.2) * (0.25 if floating else 0.08)
	visual.rotation.y += delta * 0.15


## Coup de hache : le nuage se brise et donne ses ressources au joueur.
func harvest(p) -> void:
	if is_queued_for_deletion():
		return
	var gained: int = p.add_resource("cloud", YIELD)
	if p.hud:
		p.hud.res_gain("cloud", gained)
	if magic:
		p.add_resource("magic_cloud", 1)
		var extra := "magic_wood" if randf() < 0.5 else "magic_stone"
		p.add_resource(extra, 1)
		if p.hud:
			p.hud.show_notice("NUAGE MAGIQUE !\n+1 nuage magique  ·  +1 %s" % ("bois magique" if extra == "magic_wood" else "pierre magique"), 5.0)
	p.add_stat("harvested", gained)
	if main:
		main.spawn_impact(global_position + Vector3.UP * 0.6, Vector3.UP, Color(1, 1, 1) if not magic else Color(1.0, 0.85, 0.4), 18, 1.6)
		main.on_cloud_harvested(self)
	Sfx.play_3d("orb_hit", global_position, -2.0, 1.8)
	queue_free()
