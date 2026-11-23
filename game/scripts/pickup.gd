extends Node3D
## Pièce métallique (écrou + engrenage) posée au sol, ramassée en passant dessus.
## Sert à fabriquer des barbelés.

const Mats = preload("res://scripts/mats.gd")

var main
var zone := 1
var t := 0.0
var model: Node3D
static var _metal: StandardMaterial3D
static var _brass: StandardMaterial3D


func _ready() -> void:
	add_to_group("pickup")
	t = randf() * TAU
	if _metal == null:
		_metal = StandardMaterial3D.new()
		_metal.albedo_color = Color(0.62, 0.66, 0.74)
		_metal.metallic = 0.85
		_metal.roughness = 0.3
		_metal.emission_enabled = true
		_metal.emission = Color(0.35, 0.55, 0.65)
		_metal.emission_energy_multiplier = 0.35
		_brass = _metal.duplicate()
		_brass.albedo_color = Color(0.85, 0.62, 0.30)
		_brass.emission = Color(0.6, 0.4, 0.15)
	model = Node3D.new()
	add_child(model)
	# engrenage
	var gear := Node3D.new()
	gear.rotation_degrees = Vector3(70, 0, 0)
	model.add_child(gear)
	Mats.cylinder(gear, 0.16, 0.16, 0.05, _metal, Vector3.ZERO, Vector3.ZERO, 12)
	for i in 8:
		var a := TAU * i / 8.0
		Mats.box(gear, Vector3(0.06, 0.05, 0.07), _metal, Vector3(cos(a) * 0.19, 0, sin(a) * 0.19), Vector3(0, -rad_to_deg(a), 0))
	Mats.cylinder(gear, 0.06, 0.06, 0.07, _brass, Vector3.ZERO, Vector3.ZERO, 6)
	# boulon
	Mats.cylinder(model, 0.03, 0.03, 0.22, _metal, Vector3(0.18, 0.02, 0.05), Vector3(0, 0, 80), 6)
	Mats.cylinder(model, 0.055, 0.055, 0.05, _brass, Vector3(0.07, 0.04, 0.05), Vector3(0, 0, 80), 6)


func _process(delta: float) -> void:
	t += delta
	model.position.y = 0.35 + sin(t * 2.0) * 0.06
	model.rotation.y += delta * 1.6
	if main == null:
		return
	for pl in main.players:
		if pl.dead:
			continue
		var p: Vector3 = pl.global_position
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() < 1.4 and absf(p.y - global_position.y) < 2.0:
			pl.collect_coin()
			main.on_pickup_collected(self)
			queue_free()
			return
