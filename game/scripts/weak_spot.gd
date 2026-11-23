extends Node3D
## Cible de récolte (sur un arbre ou un rocher) : anneau turquoise lumineux qui pulse.
## Toucher la cible avec la hache augmente le bonus de ressources final.

static var _ring_mat: StandardMaterial3D
static var _core_mat: StandardMaterial3D

var radius := 0.3
var t := 0.0
var ring: MeshInstance3D


func setup(pos: Vector3, normal: Vector3, r: float) -> void:
	radius = r
	global_position = pos
	var y := normal.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	global_transform.basis = Basis(x, y, z)


func _ready() -> void:
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.albedo_color = Color(0.35, 1.0, 0.95)
		_ring_mat.emission_enabled = true
		_ring_mat.emission = Color(0.35, 1.0, 0.95)
		_ring_mat.emission_energy_multiplier = 3.0
		_core_mat = _ring_mat.duplicate()
		_core_mat.albedo_color = Color(1.0, 1.0, 1.0)
		_core_mat.emission = Color(0.8, 1.0, 1.0)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.78
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(radius, radius * 0.25, radius)
	add_child(ring)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.28
	cm.height = 0.1
	cm.radial_segments = 16
	core.mesh = cm
	core.material_override = _core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * radius
	add_child(core)
	# apparition
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	t += delta
	var s := 1.0 + 0.12 * sin(t * 6.0)
	ring.scale = Vector3(radius * s, radius * 0.25, radius * s)


## Vrai si le point d'impact tombe sur la cible.
func is_hit(p: Vector3) -> bool:
	return p.distance_to(global_position) < radius * 1.45


func pop() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.6, 0.08)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.1)
	tw.tween_callback(queue_free)
