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
const CORE_Y := 1.35   # sphère réduite de moitié


func _ready() -> void:
	add_to_group("orb")
	collision_layer = 32
	collision_mask = 0

	# Socle en pierre
	var stone := Mats.col(Color(0.55, 0.58, 0.68), 0.7)
	var stone_dark := Mats.col(Color(0.38, 0.40, 0.50), 0.7)
	Mats.cylinder(self, 1.0, 1.15, 0.3, stone_dark, Vector3(0, 0.15, 0), Vector3.ZERO, 8)
	Mats.cylinder(self, 0.65, 0.85, 0.35, stone, Vector3(0, 0.45, 0), Vector3.ZERO, 8)
	for i in 8:
		var a := TAU * i / 8.0
		Mats.box(self, Vector3(0.14, 0.5, 0.14), stone, Vector3(cos(a) * 0.92, 0.5, sin(a) * 0.92), Vector3(0, -rad_to_deg(a), 8))

	var s1 := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.65
	s1.shape = sph
	s1.position.y = CORE_Y
	add_child(s1)
	var s2 := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 0.6
	s2.shape = cyl
	s2.position.y = 0.3
	add_child(s2)

	core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	sm.radial_segments = 48
	sm.rings = 24
	core.mesh = sm
	core_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CORE_SHADER
	core_mat.shader = sh
	core.material_override = core_mat
	core.position.y = CORE_Y
	add_child(core)

	var shell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.75
	sm2.height = 1.5
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
		tm.inner_radius = 0.85 + i * 0.16
		tm.outer_radius = 0.9 + i * 0.16
		r.mesh = tm
		r.material_override = Mats.col(Color(1, 1, 1), 0.3, 1.5)
		r.position.y = CORE_Y
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
	particles.position.y = 0.7
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.0
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
	var c := Color.from_hsv(fmod(t * 0.07, 1.0), 0.75, 1.0)
	core_mat.set_shader_parameter("base_color", c)
	shell_mat.set_shader_parameter("base_color", c)
	light.light_color = c
	particle_mat.albedo_color = c.lightened(0.3)
	flash = maxf(flash - delta * 4.0, 0.0)
	core_mat.set_shader_parameter("flash", flash)
	if dead:
		return
	core.position.y = CORE_Y + sin(t * 1.4) * 0.08
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
