extends CanvasLayer
## Interface en jeu : vie, munitions, bois, vagues, sphère, menus pause / fin.

const UI = preload("res://scripts/ui.gd")

signal menu_pressed
signal retry_pressed

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5));
	COLOR = vec4(0.9, 0.05, 0.05, smoothstep(0.25, 0.75, d) * strength);
}
"""


class Crosshair extends Control:
	var gap := 7.0
	var mode := 0
	func _draw() -> void:
		var c := size * 0.5
		if mode == 2:
			draw_arc(c, 10.0, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 4.0)
			draw_arc(c, 10.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
			return
		if mode == 3:
			# point de visée discret quand on épaule
			draw_circle(c, 2.6, Color(0, 0, 0, 0.7))
			draw_circle(c, 1.6, Color(0.4, 1.0, 0.95, 0.95))
			return
		if mode == 1:
			draw_circle(c, 4.0, Color(0, 0, 0, 0.6))
			draw_circle(c, 2.5, Color.WHITE)
			return
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * gap, c + d * (gap + 9.0), Color(0, 0, 0, 0.6), 4.0)
			draw_line(c + d * gap, c + d * (gap + 9.0), Color.WHITE, 2.0)
		draw_circle(c, 1.6, Color.WHITE)


class HitMarker extends Control:
	var t := 0.0
	var head := false
	func _process(delta: float) -> void:
		if t > 0.0:
			t -= delta
			queue_redraw()
	func _draw() -> void:
		if t <= 0.0:
			return
		var c := size * 0.5
		var col := Color(1, 0.85, 0.1, t / 0.2) if head else Color(1, 1, 1, t / 0.2)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 7.0, c + d * 15.0, col, 3.0)


var root: Control
var crosshair: Crosshair
var hit: HitMarker
var vignette_mat: ShaderMaterial
var vignette_strength := 0.0
var wave_title: Label
var wave_sub: Label
var orb_bar: ProgressBar
var orb_label: Label
var alert_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var ammo_label: Label
var info_label: Label
var wood_label: Label
var wood_pop: Label
var stone_label: Label
var stone_pop: Label
var build_prompt: Label
var notice_label: Label
var notice_t := 0.0
var slots: Array[PanelContainer] = []
var slot_on: StyleBoxFlat
var slot_off: StyleBoxFlat
var center_box: VBoxContainer
var center_title: Label
var center_sub: Label
var center_tween: Tween
var prompt_label: Label
var message_label: Label
var message_t := 0.0
var pause_panel: Control
var end_panel: Control
var end_title: Label
var end_sub: Label
var game_over := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)

	var vig := ColorRect.new()
	_full(vig)
	vignette_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	vignette_mat.shader = sh
	vig.material = vignette_mat
	root.add_child(vig)

	crosshair = Crosshair.new()
	_full(crosshair)
	root.add_child(crosshair)
	hit = HitMarker.new()
	_full(hit)
	root.add_child(hit)

	# --- haut : vague + sphère
	var top := VBoxContainer.new()
	_place(top, 0.5, 0.0, 0.5, 0.0, -300, 10, 300, 150)
	top.add_theme_constant_override("separation", 2)
	root.add_child(top)
	wave_title = _label(top, "PRÉPARATION", 34, UI.YELLOW)
	wave_sub = _label(top, "", 18)
	var orb_row := HBoxContainer.new()
	orb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	orb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(orb_row)
	orb_label = _label(orb_row, "SPHÈRE", 16, Color(0.75, 0.9, 1.0))
	orb_bar = _bar(Color(0.3, 0.8, 1.0), Vector2(320, 18))
	orb_row.add_child(orb_bar)
	alert_label = _label(top, "", 20, Color(1, 0.3, 0.25))

	# --- bas gauche : vie
	var hp_panel := PanelContainer.new()
	hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hp_panel, 0.0, 1.0, 0.0, 1.0, 20, -96, 380, -20)
	root.add_child(hp_panel)
	var hp_vb := VBoxContainer.new()
	hp_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_panel.add_child(hp_vb)
	hp_label = _label(hp_vb, "100 PV", 22, Color(0.6, 1.0, 0.5))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_bar = _bar(Color(0.35, 0.85, 0.3), Vector2(340, 20))
	hp_vb.add_child(hp_bar)

	# --- bas droite : armes, munitions, bois
	var br := VBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_END
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(br, 1.0, 1.0, 1.0, 1.0, -460, -240, -20, -20)
	root.add_child(br)
	var wood_row := HBoxContainer.new()
	wood_row.alignment = BoxContainer.ALIGNMENT_END
	wood_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br.add_child(wood_row)
	wood_pop = _label(wood_row, "", 22, Color(0.6, 1.0, 0.5))
	wood_label = _label(wood_row, "BOIS 0", 26, Color(0.95, 0.75, 0.5))
	stone_pop = _label(wood_row, "", 22, Color(0.6, 1.0, 0.5))
	stone_label = _label(wood_row, "", 26, Color(0.78, 0.78, 0.92))
	ammo_label = _label(br, "30 / ∞", 40)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label = _label(br, "", 16, Color(0.85, 0.9, 1.0))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_END
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_row.add_theme_constant_override("separation", 8)
	br.add_child(slot_row)
	slot_on = UI.box(Color(0.2, 0.5, 1.0, 0.9), 8, 14.0, 8.0)
	slot_on.border_color = Color.WHITE
	slot_on.set_border_width_all(3)
	slot_off = UI.box(Color(0.05, 0.05, 0.15, 0.65), 8, 14.0, 8.0)
	for txt in ["1\nFUSIL", "2\nHACHE", "3\nCONSTRUIRE"]:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(110, 70)
		p.add_theme_stylebox_override("panel", slot_off)
		var l := _label(p, txt, 16)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_row.add_child(p)
		slots.append(p)

	# --- centre : grands messages
	center_box = VBoxContainer.new()
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(center_box, 0.5, 0.22, 0.5, 0.22, -500, 0, 500, 160)
	root.add_child(center_box)
	center_title = _label(center_box, "", 72, UI.YELLOW)
	center_title.add_theme_constant_override("outline_size", 14)
	center_title.add_theme_color_override("font_outline_color", UI.DARK)
	center_sub = _label(center_box, "", 24)
	center_box.modulate.a = 0.0

	prompt_label = _label(root, "", 26)
	_place(prompt_label, 0.5, 0.6, 0.5, 0.6, -400, 0, 400, 40)
	message_label = _label(root, "", 22, Color(1, 0.6, 0.4))
	_place(message_label, 0.5, 0.67, 0.5, 0.67, -400, 0, 400, 40)
	build_prompt = _label(root, "", 20, Color(0.85, 0.95, 1.0))
	_place(build_prompt, 0.5, 0.56, 0.5, 0.56, -500, 0, 500, 60)
	notice_label = _label(root, "", 22, Color(0.85, 0.85, 1.0))
	_place(notice_label, 0.5, 0.36, 0.5, 0.36, -600, 0, 600, 110)
	notice_label.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.04, 0.16, 0.8), 12, 24.0, 14.0))
	notice_label.visible = false

	pause_panel = _overlay("PAUSE", "", ["REPRENDRE", "MENU PRINCIPAL"], [func(): set_paused(false), func(): menu_pressed.emit()])
	var end := _overlay("", "", ["REJOUER", "MENU PRINCIPAL"], [func(): retry_pressed.emit(), func(): menu_pressed.emit()])
	end_panel = end
	end_title = end.get_meta("title")
	end_sub = end.get_meta("sub")


# ------------------------------------------------------------------ helpers UI

func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


func _label(parent: Node, txt: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.max_value = 100.0
	b.value = 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UI.box(Color(0, 0, 0, 0.55), 6, 0.0, 0.0)
	var fg := UI.box(color, 6, 0.0, 0.0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _overlay(title: String, sub: String, buttons: Array, callbacks: Array) -> Control:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.1, 0.7)
	dim.visible = false
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)
	var t := _label(vb, title, 80, UI.YELLOW)
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", UI.DARK)
	var s := _label(vb, sub, 24)
	for i in buttons.size():
		var b := Button.new()
		if i == 0:
			dim.set_meta("first", b)
		b.text = buttons[i]
		b.custom_minimum_size = Vector2(360, 66)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(callbacks[i])
		vb.add_child(b)
	dim.set_meta("title", t)
	dim.set_meta("sub", s)
	return dim


# ------------------------------------------------------------------ API utilisée par le jeu

func _process(delta: float) -> void:
	vignette_strength = maxf(vignette_strength - delta * 1.5, 0.0)
	vignette_mat.set_shader_parameter("strength", vignette_strength)
	if message_t > 0.0:
		message_t -= delta
		message_label.modulate.a = clampf(message_t, 0.0, 1.0)
	if notice_t > 0.0:
		notice_t -= delta
		notice_label.modulate.a = clampf(notice_t, 0.0, 1.0)
		notice_label.visible = notice_t > 0.0


func update_player(p) -> void:
	hp_bar.value = p.hp
	hp_label.text = "%d PV" % int(ceil(p.hp))
	wood_label.text = "BOIS %d" % p.wood
	stone_label.text = ("   PIERRE %d" % p.stone) if (p.main and p.main.stone_unlocked) else ""
	# Construction visée : réparer / améliorer
	var bt = p.build_target
	if bt and is_instance_valid(bt) and not p.dead:
		var mname: String = p.MAT_NAMES[bt.material_type].to_lower()
		var parts: Array[String] = [bt.describe() + "  %d / %d PV" % [int(ceil(bt.hp)), int(bt.max_hp)]]
		var rc: int = bt.repair_cost()
		if rc > 0:
			parts.append("[G / ↓] Réparer (%d %s)" % [rc, mname])
		if bt.can_upgrade():
			parts.append("[T / ↑] Améliorer ×3 PV (%d %s)" % [bt.UPGRADE_COST, mname])
		build_prompt.text = "\n".join(parts)
	else:
		build_prompt.text = ""
	for i in slots.size():
		slots[i].add_theme_stylebox_override("panel", slot_on if i == p.weapon else slot_off)
	var mode := 0
	match p.weapon:
		0:
			ammo_label.text = "RECHARGE..." if p.reloading else "%d / ∞" % p.ammo
			info_label.text = "Clic G / RT : tirer · Clic D / LT : viser · R / X : recharger"
			mode = 0
			if p.aiming:
				mode = 3
			crosshair.visible = true
		1:
			ammo_label.text = "HACHE"
			info_label.text = "Clic G / RT : couper un arbre (bois) ou un rocher (pierre)"
			mode = 1
			crosshair.visible = true
		2:
			ammo_label.text = "%s · %s" % [p.PIECE_NAMES[p.build_piece], p.MAT_NAMES[p.build_mat]]
			info_label.text = "Souris : clic G construire · F pièce · V matériau\nManette : RT mur · LT sol · RB rampe · Y matériau  (%d par pièce)" % p.BUILD_COST
			mode = 2
			crosshair.visible = true
	if p.dead:
		crosshair.visible = false
	if crosshair.mode != mode:
		crosshair.mode = mode
		crosshair.queue_redraw()


func set_wave(title: String, sub: String) -> void:
	wave_title.text = title
	wave_sub.text = sub


func set_orb(hp: float, max_hp: float) -> void:
	orb_bar.max_value = max_hp
	orb_bar.value = hp
	orb_label.text = "SPHÈRE %d  " % int(ceil(hp))


func set_alert(text: String) -> void:
	alert_label.text = text


func set_prompt(text: String) -> void:
	prompt_label.text = text


func flash_message(text: String) -> void:
	message_label.text = text
	message_t = 2.0


func show_center(title: String, sub: String, duration := 2.5) -> void:
	center_title.text = title
	center_sub.text = sub
	if center_tween:
		center_tween.kill()
	center_box.modulate.a = 0.0
	center_box.scale = Vector2.ONE
	center_tween = create_tween()
	center_tween.tween_property(center_box, "modulate:a", 1.0, 0.25)
	center_tween.tween_interval(duration)
	center_tween.tween_property(center_box, "modulate:a", 0.0, 0.5)


func hitmarker(head: bool) -> void:
	hit.t = 0.2
	hit.head = head
	hit.queue_redraw()


func stone_gain(amount: int) -> void:
	stone_pop.text = "   +%d" % amount
	stone_pop.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(stone_pop, "modulate:a", 0.0, 0.5)


func show_notice(text: String, duration := 6.0) -> void:
	notice_label.text = text
	notice_t = duration
	notice_label.modulate.a = 1.0
	notice_label.visible = true


func wood_gain(amount: int) -> void:
	wood_pop.text = "+%d  " % amount
	wood_pop.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(wood_pop, "modulate:a", 0.0, 0.5)


func damage_flash() -> void:
	vignette_strength = minf(vignette_strength + 0.6, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not game_over:
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(p: bool) -> void:
	get_tree().paused = p
	pause_panel.visible = p
	if p:
		(pause_panel.get_meta("first") as Button).grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func show_end(title: String, sub: String) -> void:
	game_over = true
	end_title.text = title
	end_sub.text = sub
	end_panel.visible = true
	(end_panel.get_meta("first") as Button).grab_focus()
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
