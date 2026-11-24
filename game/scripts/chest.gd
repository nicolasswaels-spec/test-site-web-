extends StaticBody3D
## Coffre au trésor gardé par des squelettes. On l'ouvre avec E / X : butin aléatoire
## (commun, rare, légendaire ; l'arme cryogénique est très rare : 4 %).

const MODEL := preload("res://assets/chests/chest.glb")
const MODEL_GOLD := preload("res://assets/chests/chest_gold.glb")
const RARITY_COLORS := {"COMMUN": Color(0.85, 0.85, 0.9), "RARE": Color(0.3, 0.6, 1.0), "LÉGENDAIRE": Color(1.0, 0.7, 0.15)}

var main
var gold := false
var opened := false
var lid: Node3D
var label: Label3D


func _ready() -> void:
	add_to_group("chest")
	collision_layer = 16
	collision_mask = 0
	var model: Node3D = (MODEL_GOLD if gold else MODEL).instantiate()
	model.scale = Vector3.ONE * 1.3
	add_child(model)
	lid = model.find_child("*_lid", true, false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 1.1, 1.0)
	cs.shape = bs
	cs.position.y = 0.55
	add_child(cs)
	# petite lueur pour qu'on le repère dans la forêt
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 1.5, 0.8)
	add_child(l)
	label = Label3D.new()
	label.text = "COFFRE"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color(1.0, 0.85, 0.4)
	label.position = Vector3(0, 2.0, 0)
	add_child(label)


## Tire le butin. Renvoie {rarity, wood, stone, coins, cryo}.
static func roll_loot(already_has_cryo: bool) -> Dictionary:
	var loot := {"rarity": "COMMUN", "wood": 0, "stone": 0, "coins": 0, "cryo": false}
	var r := randf()
	if r < 0.60:
		loot["wood"] = randi_range(100, 300)
	elif r < 0.90:
		loot["rarity"] = "RARE"
		match randi() % 3:
			0:
				loot["wood"] = randi_range(300, 500)
			1:
				loot["stone"] = randi_range(100, 300)
			_:
				loot["wood"] = randi_range(200, 300)
				loot["stone"] = randi_range(50, 150)
	else:
		loot["rarity"] = "LÉGENDAIRE"
		# 10 % de légendaire, dont 40 % pour l'arme cryogénique => 4 % au total
		if randf() < 0.4 and not already_has_cryo:
			loot["cryo"] = true
		else:
			match randi() % 4:
				0:
					loot["wood"] = randi_range(1500, 2500)
				1:
					loot["stone"] = randi_range(1000, 1800)
				2:
					loot["coins"] = randi_range(30, 50)
				_:
					loot["wood"] = 1000
					loot["stone"] = 1000
					loot["coins"] = 20
	return loot


func open(p) -> void:
	if opened:
		return
	opened = true
	label.visible = false
	var loot := roll_loot(p.has_cryo)
	var parts: Array[String] = []
	if loot["wood"] > 0:
		parts.append("+%d bois" % p.add_resource("wood", loot["wood"]))
	if loot["stone"] > 0:
		parts.append("+%d pierre" % p.add_resource("stone", loot["stone"]))
	if loot["coins"] > 0:
		parts.append("+%d pièces" % p.add_resource("coins", loot["coins"]))
	if loot["cryo"]:
		p.unlock_cryo()
		parts.append("NOUVELLE ARME : CANON CRYOGÉNIQUE !")
	var col: Color = RARITY_COLORS[loot["rarity"]]
	if p.hud:
		p.hud.show_center("COFFRE %s" % loot["rarity"], " · ".join(parts), 4.0)
	Sfx.play("win" if loot["rarity"] == "LÉGENDAIRE" else "coin", -2.0)
	if lid:
		create_tween().tween_property(lid, "rotation:x", deg_to_rad(-110.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# colonne de lumière de la couleur de la rareté
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.3
	cm.height = 8.0
	beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.5)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 4.5
	add_child(beam)
	var tw := beam.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(beam.queue_free)
	if main and main.has_method("rebuild_obstacles"):
		main.call_deferred("rebuild_obstacles")
