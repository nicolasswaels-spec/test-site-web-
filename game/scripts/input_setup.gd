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
	_key("repair", KEY_G)
	_key("upgrade", KEY_T)
	_key("build_material", KEY_V)
	_key("edit", KEY_X)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)

	# --- Manette (Xbox / PlayStation), disposition proche de Fortnite
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)    # RT / R2
	_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)      # LT / L2
	_button("jump", JOY_BUTTON_A)                 # A / Croix
	_button("build_toggle", JOY_BUTTON_B)         # B / Rond
	_button("reload", JOY_BUTTON_X)               # X / Carré
	_button("interact", JOY_BUTTON_X)
	_button("weapon_swap", JOY_BUTTON_Y)          # Y / Triangle : fusil <-> hache
	_button("weapon_prev", JOY_BUTTON_LEFT_SHOULDER)
	_button("weapon_next", JOY_BUTTON_RIGHT_SHOULDER)
	_button("sprint_toggle", JOY_BUTTON_LEFT_STICK)   # clic stick gauche
	_button("piece_next", JOY_BUTTON_DPAD_LEFT)
	_button("edit", JOY_BUTTON_DPAD_RIGHT)
	_button("upgrade", JOY_BUTTON_DPAD_UP)
	_button("repair", JOY_BUTTON_DPAD_DOWN)
	# En mode construction : RT = mur, LT = sol, RB = rampe
	_axis("pad_build_wall", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("pad_build_floor", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button("pad_build_ramp", JOY_BUTTON_RIGHT_SHOULDER)
	_button("pause", JOY_BUTTON_START)
	_button("pause", JOY_BUTTON_BACK)
	# Navigation dans les menus à la manette
	_button("ui_accept", JOY_BUTTON_A)
	_button("ui_cancel", JOY_BUTTON_B)
	_button("ui_up", JOY_BUTTON_DPAD_UP)
	_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		InputMap.action_set_deadzone(a, 0.2)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		InputMap.action_set_deadzone(a, 0.12)
	for a in ["fire", "aim", "pad_build_wall", "pad_build_floor"]:
		InputMap.action_set_deadzone(a, 0.35)


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


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, direction: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = direction
	e.device = -1
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)
