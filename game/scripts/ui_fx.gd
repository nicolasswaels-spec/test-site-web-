extends Node
## Autoload « UiFx » : animations communes de l'interface. Chaque bouton créé grossit légèrement
## et s'illumine quand on le survole ou le sélectionne (souris, clavier ou manette).

const HOVER_SCALE := 1.045


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Button and not n.has_meta("no_fx"):
		var b := n as Button
		b.mouse_entered.connect(_hover.bind(b, true))
		b.mouse_exited.connect(_hover.bind(b, false))
		b.focus_entered.connect(_hover.bind(b, true, true))
		b.focus_exited.connect(_hover.bind(b, false))


func _hover(b: Button, on: bool, focus := false) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	if not on and b.has_focus():
		return   # reste mis en valeur tant qu'il est sélectionné
	b.pivot_offset = b.size * 0.5
	var target := Vector2.ONE * (HOVER_SCALE if on and not b.disabled else 1.0)
	var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(b, "scale", target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if on and focus and not b.disabled:
		Sfx.play("equip", -20.0, 1.7)
