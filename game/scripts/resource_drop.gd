extends Node3D
## Ressources déposées au sol (bois, pierre ou pièces). N'importe quel joueur peut les ramasser.

const Mats = preload("res://scripts/mats.gd")
const NAMES := {"wood": "BOIS", "stone": "PIERRE", "coins": "PIÈCES", "magic_wood": "BOIS MAGIQUE", "magic_stone": "PIERRE MAGIQUE",
	"bone": "OS", "big_bone": "OS IMPOSANT", "arrow_bone": "OS EN FLÈCHE", "bone_pile": "TAS D'OS IMPOSANT"}

var main
var kind := "wood"
var amount := 0
var dropper = null      # le joueur qui a déposé ne peut pas le reprendre tout de suite
var age := 0.0
var t := 0.0
var model: Node3D
var label: Label3D


func _ready() -> void:
	add_to_group("resource_drop")
	model = Node3D.new()
	add_child(model)
	match kind:
		"wood":
			var w := Mats.col(Color(0.55, 0.33, 0.18))
			var end := Mats.col(Color(0.85, 0.68, 0.45))
			for i in 3:
				var y := 0.12 + (0.2 if i == 2 else 0.0)
				var x := (-0.12 if i == 0 else 0.12) if i < 2 else 0.0
				Mats.cylinder(model, 0.1, 0.1, 0.7, w, Vector3(x, y, 0), Vector3(90, 0, 0), 8)
				Mats.cylinder(model, 0.09, 0.09, 0.71, end, Vector3(x, y, 0), Vector3(90, 0, 0), 8).scale = Vector3(1, 1.0, 1)
		"stone":
			var st := Mats.col(Color(0.5, 0.5, 0.6), 0.9)
			Mats.sphere(model, 0.18, st, Vector3(-0.12, 0.15, 0), 6)
			Mats.sphere(model, 0.15, st, Vector3(0.14, 0.13, 0.05), 6)
			Mats.sphere(model, 0.13, st, Vector3(0.0, 0.32, -0.02), 6)
		"bone", "big_bone", "arrow_bone", "bone_pile":
			_bone_model()
		_:
			var sack := Mats.col(Color(0.55, 0.42, 0.25))
			var gold := Mats.col(Color(0.85, 0.65, 0.3), 0.3, 0.5)
			Mats.sphere(model, 0.22, sack, Vector3(0, 0.2, 0), 10)
			Mats.cylinder(model, 0.07, 0.1, 0.12, sack, Vector3(0, 0.44, 0), Vector3.ZERO, 8)
			Mats.cylinder(model, 0.08, 0.08, 0.02, gold, Vector3(0.12, 0.05, 0.2), Vector3(70, 0, 0), 10)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 40
	label.outline_size = 10
	label.no_depth_test = true
	label.position = Vector3(0, 0.95, 0)
	add_child(label)
	_update_label()


## Os au sol : petits os blancs (plus gros / en tas selon le type), légère lueur pour les repérer.
func _bone_model() -> void:
	var bone := Mats.col(Color(0.93, 0.89, 0.78), 0.6, 0.25)
	var sc: float = {"bone": 1.0, "big_bone": 1.7, "arrow_bone": 1.0, "bone_pile": 1.3}[kind]
	var n := 4 if kind == "bone_pile" else 1
	for i in n:
		var a := i * 1.3
		var b := Node3D.new()
		var off := 0.18 if i > 0 else 0.0
		b.position = Vector3(cos(a) * off, 0.12 + i * 0.08, sin(a) * off)
		b.rotation = Vector3(0, a, PI * 0.5)
		b.scale = Vector3.ONE * sc
		model.add_child(b)
		Mats.cylinder(b, 0.045, 0.045, 0.5, bone, Vector3.ZERO, Vector3.ZERO, 6)
		for y in [-0.25, 0.25]:
			for x in [-0.04, 0.04]:
				Mats.sphere(b, 0.06, bone, Vector3(x, y, 0), 6)
		if kind == "arrow_bone":
			Mats.cylinder(b, 0.0, 0.07, 0.16, bone, Vector3(0, 0.33, 0), Vector3.ZERO, 4)
	if kind == "bone_pile":
		Mats.sphere(model, 0.2, bone, Vector3(0, 0.45, 0), 10)
	if kind == "bone" or kind == "arrow_bone":
		return   # pas de lumière pour les petits os (il peut y en avoir beaucoup)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.6)
	l.light_energy = 1.6
	l.omni_range = 2.5
	l.position.y = 0.6
	model.add_child(l)


func _update_label() -> void:
	label.text = "%s × %d" % [NAMES[kind], amount]


func _process(delta: float) -> void:
	t += delta
	age += delta
	model.position.y = 0.1 + sin(t * 2.0) * 0.05
	model.rotation.y += delta * 0.8
	if main == null:
		return
	for p in main.players:
		if p.dead or (p == dropper and age < 2.5) or age < 0.6:
			continue
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < 1.4 and absf(p.global_position.y - global_position.y) < 2.0:
			var taken: int = p.add_resource(kind, amount)
			if taken > 0:
				amount -= taken
				Sfx.play("coin", -4.0, 0.8)
				if p.hud:
					p.hud.flash_message("+%d %s" % [taken, NAMES[kind].to_lower()])
			if amount <= 0:
				queue_free()
				return
			_update_label()
