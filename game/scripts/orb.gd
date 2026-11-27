extends StaticBody3D
## La sphère à défendre : socle sculpté et boule turquoise (modèle Meshy d'après l'illustration du menu).

const Mats = preload("res://scripts/mats.gd")

signal damaged(amount: float)
signal destroyed

var max_hp := 2500.0
var hp := 2500.0
var dead := false
var core: Node3D
var ball_mat: StandardMaterial3D
var light: OmniLight3D
var particles: CPUParticles3D
var particle_mat: StandardMaterial3D
var t := 0.0
var flash := 0.0
const CORE_Y := 1.78   # au-dessus du socle sculpté (modèle Meshy d'après l'image du menu)
const ALTAR := "res://assets/orb/orb_altar.glb"


func _ready() -> void:
	add_to_group("orb")
	collision_layer = 32
	collision_mask = 0

	# Socle sculpté : dalles de pierre à runes turquoise et pilier au losange lumineux
	if ResourceLoader.exists(ALTAR):
		var altar := (load(ALTAR) as PackedScene).instantiate() as Node3D
		Mats.fix_glb_textures(altar, ALTAR)
		altar.rotation_degrees.y = 90.0
		add_child(altar)
	else:
		var stone := Mats.col(Color(0.55, 0.58, 0.68), 0.7)
		Mats.cylinder(self, 0.45, 0.6, 1.3, stone, Vector3(0, 0.65, 0), Vector3.ZERO, 8)

	var s1 := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.5
	s1.shape = sph
	s1.position.y = CORE_Y
	add_child(s1)
	var s2 := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 0.35
	s2.shape = cyl
	s2.position.y = 0.17
	var s3 := CollisionShape3D.new()
	var pil := CylinderShape3D.new()
	pil.radius = 0.5
	pil.height = 1.3
	s3.shape = pil
	s3.position.y = 0.65
	add_child(s3)
	add_child(s2)

	# la boule du modèle (texture turquoise striée) : animée ici (flotte, tourne) ; repli : sphère simple
	core = Node3D.new()
	core.position.y = CORE_Y
	add_child(core)
	var ball: MeshInstance3D = null
	for c in get_children():
		if c is Node3D and c != core:
			ball = c.find_child("ball", true, false) as MeshInstance3D
			if ball:
				break
	if ball:
		ball.get_parent().remove_child(ball)
		ball.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
		core.add_child(ball)
		var src := ball.mesh.surface_get_material(0) as StandardMaterial3D
		ball_mat = (src.duplicate() if src else StandardMaterial3D.new()) as StandardMaterial3D
		ball_mat.roughness_texture = null
		ball_mat.roughness = 0.45
		ball_mat.metallic = 0.0
		ball_mat.emission_enabled = true
		ball_mat.emission_texture = null
		ball_mat.emission = Color(0.1, 0.6, 0.55)
		ball_mat.emission_energy_multiplier = 0.35
		ball.material_override = ball_mat
	else:
		ball_mat = Mats.col(Color(0.2, 0.8, 0.75), 0.4, 0.6)
		Mats.sphere(core, 0.44, ball_mat, Vector3.ZERO, 24)

	light = OmniLight3D.new()
	light.position.y = CORE_Y
	light.omni_range = 12.0
	light.light_energy = 2.5
	add_child(light)

	particles = CPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 2.5
	particles.position.y = 1.3
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.7
	particles.direction = Vector3.UP
	particles.spread = 20.0
	particles.gravity = Vector3(0, 0.6, 0)
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 0.9
	var pm := BoxMesh.new()
	pm.size = Vector3.ONE * 0.07
	particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = particle_mat
	particles.mesh = pm
	add_child(particles)


func _process(delta: float) -> void:
	t += delta
	# turquoise comme sur l'illustration du menu, qui ondule légèrement
	var c := Color.from_hsv(0.47 + 0.035 * sin(t * 0.6), 0.72, 1.0)
	light.light_color = c
	particle_mat.albedo_color = c.lightened(0.3)
	flash = maxf(flash - delta * 4.0, 0.0)
	# coup reçu : la boule rougeoie un instant
	ball_mat.emission = Color(0.1, 0.6, 0.55).lerp(Color(1.0, 0.15, 0.1), flash)
	ball_mat.emission_energy_multiplier = 0.35 + flash * 2.0
	if dead:
		return
	core.position.y = CORE_Y + sin(t * 1.4) * 0.06
	core.rotation.y += delta * 0.4
	light.light_energy = 1.4 + sin(t * 3.0) * 0.25


func take_damage(amount: float) -> void:
	if dead:
		return
	hp = maxf(hp - amount, 0.0)
	flash = 1.0
	damaged.emit(amount)
	Sfx.play_3d("orb_hit", core.global_position, -4.0)
	if hp <= 0.0:
		dead = true
		var tw := create_tween()
		tw.tween_property(core, "scale", Vector3.ONE * 1.8, 0.4)
		tw.tween_property(core, "scale", Vector3.ONE * 0.01, 0.3)
		tw.parallel().tween_property(light, "light_energy", 0.0, 0.3)
		destroyed.emit()


func repair(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
