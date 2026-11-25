extends StaticBody3D
## Grand sapin stylisé que l'on peut couper à la hache pour récolter du bois.

const Nature = preload("res://scripts/nature.gd")

const Harvest = preload("res://scripts/harvest.gd")

const WOOD_PER_HIT := 15
const WOOD_FELL := 40          # bois du dernier coup, +80 % par cible touchée (jusqu'à ×3,4)

var kind := 0
var species := 0   # 0 sapin, 1 érable, 2 bouleau, 3 sapin calciné (zone volcanique)
## Arbre magique : lueur, ressources doublées et 1 BOIS MAGIQUE quand il tombe.
var magic := false
const MAGIC_MULT := 2
var tree_scale := 1.0
var trunk_radius := 0.4
var main
var max_hp := 200.0          # ~8 coups de hache
var hp := 200.0
var harvest := Harvest.new()
var last_target_hit := false
var visual: Node3D
var fallen := false


func _ready() -> void:
	add_to_group("tree")
	collision_layer = 16
	collision_mask = 0
	visual = Node3D.new()
	add_child(visual)
	visual.scale = Vector3.ONE * tree_scale
	visual.rotation.y = randf() * TAU
	var variants: Array[ArrayMesh] = Nature.pines()
	if species == 1:
		variants = Nature.maples()
	elif species == 2:
		variants = Nature.birches()
	elif species == 3:
		variants = Nature.ash_pines()
	var mi := MeshInstance3D.new()
	mi.mesh = variants[kind % variants.size()]
	visual.add_child(mi)
	if magic:
		_add_magic_look(mi)
	trunk_radius = float(mi.mesh.get_meta("trunk_radius", 0.35)) * tree_scale

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = trunk_radius + 0.05
	cyl.height = 8.0
	shape.shape = cyl
	shape.position.y = 4.0
	add_child(shape)
	hp = max_hp


## Appelé par la hache (avec le point d'impact). Renvoie le bois gagné.
func chop(damage: float, hit_pos := Vector3.INF) -> int:
	if fallen:
		return 0
	last_target_hit = harvest.register_hit(hit_pos)
	hp -= damage
	Sfx.play_3d("chop", global_position + Vector3.UP, 2.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 0.04, 0.05)
	tw.tween_property(visual, "rotation:z", -0.03, 0.08)
	tw.tween_property(visual, "rotation:z", 0.0, 0.12)
	if main:
		main.spawn_impact(global_position + Vector3.UP * 6.0, Vector3.DOWN, Color(0.15, 0.35, 0.35), 10, 1.0)
	if hp <= 0.0:
		var bonus := int(round(WOOD_FELL * harvest.final_mult())) * (MAGIC_MULT if magic else 1)
		harvest.clear()
		_fall()
		return bonus
	# 1er coup : 3 cibles d'un coup, réparties autour du tronc (une vers le joueur, deux sur les côtés)
	if harvest.needs_spots():
		var base := randf() * TAU
		if hit_pos != Vector3.INF:
			var d := hit_pos - global_position
			base = atan2(d.z, d.x)
		var heights := [randf_range(0.6, 1.0), randf_range(1.2, 1.6), randf_range(1.8, 2.3)]
		heights.shuffle()
		for k in harvest.SPOT_COUNT:
			var a := base + deg_to_rad([0.0, -75.0, 75.0][k] + randf_range(-15.0, 15.0))
			var n := Vector3(cos(a), 0.0, sin(a))
			harvest.add_spot(self, global_position + n * (trunk_radius + 0.16) + Vector3.UP * heights[k], n)
	return int(round(WOOD_PER_HIT * (harvest.HIT_BONUS if last_target_hit else 1.0))) * (MAGIC_MULT if magic else 1)


## Frappé par un squelette qui était bloqué : l'arbre finit par tomber (sans bois pour le joueur).
func smash(damage: float) -> void:
	if fallen:
		return
	hp -= damage
	Sfx.play_3d("chop", global_position + Vector3.UP, 0.0, 0.7)
	if hp <= 0.0:
		_fall()


func _fall() -> void:
	harvest.clear()
	fallen = true
	remove_from_group("tree")
	collision_layer = 0
	if main and main.has_method("rebuild_obstacles"):
		main.call_deferred("rebuild_obstacles")
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", PI * 0.5 * (1.0 if randf() > 0.5 else -1.0), 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Sfx.play_3d("break", global_position, 6.0, 0.6))
	tw.tween_interval(0.8)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(queue_free)


## Apparence magique : mousse lumineuse sur l'écorce, feuillage turquoise, lueur et étincelles.
func _add_magic_look(mi: MeshInstance3D) -> void:
	var mats: Array = Nature.magic_tree_materials(species)
	mi.set_surface_override_material(0, mats[0])
	if mi.mesh.get_surface_count() > 1:
		mi.set_surface_override_material(1, mats[1])
	var l := OmniLight3D.new()
	l.light_color = Color(0.3, 1.0, 0.65)
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.position = Vector3(0, 3.0, 0)
	add_child(l)
	var sp := CPUParticles3D.new()
	sp.amount = 24
	sp.lifetime = 3.0
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(1.6, 3.0, 1.6)
	sp.position = Vector3(0, 3.5, 0)
	sp.direction = Vector3.UP
	sp.spread = 30.0
	sp.gravity = Vector3.ZERO
	sp.initial_velocity_min = 0.2
	sp.initial_velocity_max = 0.6
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.6, 1.0, 0.8)
	q.material = m
	sp.mesh = q
	add_child(sp)
