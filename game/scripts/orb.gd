extends StaticBody3D
## La sphère lumineuse à défendre. Sa couleur change en continu.

const Mats = preload("res://scripts/mats.gd")

signal damaged(amount: float)
signal destroyed

const CORE_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float flash = 0.0;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float swirl = 0.5 + 0.5 * sin(UV.x * 30.0 + UV.y * 14.0 + TIME * 3.0);
	float swirl2 = 0.5 + 0.5 * sin(UV.x * -18.0 + UV.y * 22.0 - TIME * 2.0);
	vec3 col = base_color.rgb * (1.1 + swirl * 0.5 + swirl2 * 0.4) + vec3(1.0) * fres * 1.6;
	col = mix(col, vec3(3.0, 0.3, 0.2), flash);
	ALBEDO = col;
}
"""

const SHELL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 base_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = base_color.rgb * fres * 2.5;
	ALPHA = fres;
}
"""

var max_hp := 2500.0
var hp := 2500.0
var dead := false
var core: MeshInstance3D
var core_mat: ShaderMaterial
var shell_mat: ShaderMaterial
var light: OmniLight3D
var rings: Array[MeshInstance3D] = []
var particles: CPUParticles3D
var particle_mat: StandardMaterial3D
var t := 0.0
var flash := 0.0
const CORE_Y := 1.78   # au-dessus du socle sculpté (modèle Meshy d'après l'image du menu)
const ALTAR := "res://assets/orb/orb_altar.glb"
const SIZE := 1.15      # sphère un peu plus grosse pour aller avec le socle


func _ready() -> void:
	add_to_group("orb")
	collision_layer = 32
	collision_mask = 0

	# Socle sculpté : dalles de pierre à runes turquoise et pilier au losange lumineux
	if ResourceLoader.exists(ALTAR):
		var altar := (load(ALTAR) as PackedScene).instantiate() as Node3D
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

	core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.38
	sm.height = 0.76
	sm.radial_segments = 48
	sm.rings = 24
	core.mesh = sm
	core_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CORE_SHADER
	core_mat.shader = sh
	core.material_override = core_mat
	core.position.y = CORE_Y
	core.scale = Vector3.ONE * SIZE
	add_child(core)

	var shell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.52
	sm2.height = 1.04
	shell.mesh = sm2
	shell_mat = ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = SHELL_SHADER
	shell_mat.shader = sh2
	shell.material_override = shell_mat
	core.add_child(shell)

	for i in 2:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.6 + i * 0.11
		tm.outer_radius = 0.635 + i * 0.11
		r.mesh = tm
		r.material_override = Mats.col(Color(1, 1, 1), 0.3, 1.5)
		r.position.y = CORE_Y
		r.scale = Vector3.ONE * SIZE
		add_child(r)
		rings.append(r)

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
	core_mat.set_shader_parameter("base_color", c)
	shell_mat.set_shader_parameter("base_color", c)
	light.light_color = c
	particle_mat.albedo_color = c.lightened(0.3)
	flash = maxf(flash - delta * 4.0, 0.0)
	core_mat.set_shader_parameter("flash", flash)
	if dead:
		return
	core.position.y = CORE_Y + sin(t * 1.4) * 0.06
	core.rotation.y += delta * 0.4
	rings[0].rotation = Vector3(t * 0.7, t * 0.3, 0.4)
	rings[1].rotation = Vector3(-t * 0.4, 0.0, t * 0.6)
	light.light_energy = 2.5 + sin(t * 3.0) * 0.4


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
