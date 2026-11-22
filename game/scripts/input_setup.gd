extends Node
## Déclare les actions d'entrée au démarrage.
## On utilise les touches PHYSIQUES : W/A/S/D correspondent à Z/Q/S/D sur un clavier AZERTY.

func _ready() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_RIGHT)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("reload", KEY_R)
	_key("interact", KEY_E)
	_key("weapon_1", KEY_1)
	_key("weapon_2", KEY_2)
	_key("weapon_3", KEY_3)
	_key("cycle_piece", KEY_F)
	_key("piece_wall", KEY_F1)
	_key("piece_floor", KEY_F2)
	_key("piece_ramp", KEY_F3)
	_key("pause", KEY_ESCAPE)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: String, code: Key) -> void:
	_ensure(action)
	var e := InputEventKey.new()
	e.physical_keycode = code
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
