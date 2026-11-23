extends CanvasLayer
## Interface en jeu : vie, munitions, bois, vagues, sphère, menus pause / fin.

const UI = preload("res://scripts/ui.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")

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


## Mini-carte : nord en haut, joueur en bleu (flèche), squelettes en rouge, sphère défendue en vert.
class Minimap extends Control:
	var main
	const SCALE := 1.5          # pixels par mètre
	func _process(_d: float) -> void:
		queue_redraw()
	func _w2m(c: Vector2, origin: Vector3, w: Vector3) -> Vector2:
		return c + Vector2(w.x - origin.x, w.z - origin.z) * SCALE
	func _draw() -> void:
		if main == null or main.player == null:
			return
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c, r, Color(0.05, 0.04, 0.12, 0.72))
		var o: Vector3 = main.player.global_position
		# limites des zones
		var z1 := _w2m(c, o, Vector3.ZERO)
		draw_arc(z1, main.MAP_RADIUS * SCALE, 0, TAU, 96, Color(0.45, 0.5, 1.0, 0.7), 2.0)
		if main.zone2_unlocked:
			draw_arc(_w2m(c, o, main.ZONE2_CENTER), main.ZONE2_RADIUS * SCALE, 0, TAU, 96, Color(0.45, 0.5, 1.0, 0.7), 2.0)
			var a := _w2m(c, o, Vector3(-main.CORRIDOR_HALF, 0, main.CORRIDOR_Z.x))
			var b := _w2m(c, o, Vector3(main.CORRIDOR_HALF, 0, main.CORRIDOR_Z.y))
			draw_rect(Rect2(a, b - a), Color(0.45, 0.5, 1.0, 0.25))
		# constructions
		for st in main.structures.values():
			if is_instance_valid(st):
				var sp := _w2m(c, o, st.global_position)
				if sp.distance_to(c) < r - 3:
					draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.65, 0.4, 0.8))
		# squelettes
		for z in main.zombie_cache:
			if is_instance_valid(z):
				var zp := _w2m(c, o, z.global_position)
				if zp.distance_to(c) < r - 3:
					draw_circle(zp, 5.0 if z.is_boss else 3.0, Color(1.0, 0.2, 0.15))
		# sphère défendue (épinglée au bord si hors de portée)
		var op := _w2m(c, o, main.orb.global_position)
		if op.distance_to(c) > r - 7:
			op = c + (op - c).normalized() * (r - 7)
		draw_circle(op, 6.0, Color(0, 0, 0, 0.7))
		draw_circle(op, 4.5, Color(0.3, 1.0, 0.4))
		# joueur : flèche bleue orientée
		var yaw: float = main.player.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		var pts := PackedVector2Array([c + fwd * 9.0, c - fwd * 6.0 + side * 6.0, c - fwd * 3.0, c - fwd * 6.0 - side * 6.0])
		draw_colored_polygon(pts, Color(0.35, 0.65, 1.0))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.WHITE, 1.5)
		draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(c.x - 5, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))


var root: Control
var main
var minimap: Minimap
var enemy_box: VBoxContainer
var enemy_name: Label
var enemy_bar: ProgressBar
var enemy_fill: StyleBoxFlat
var confirm_panel: Control
var confirm_title: Label
var confirm_text: Label
var confirm_cb: Callable
var inventory_panel
var inv_res: Label
var inv_weapons: VBoxContainer
var inv_player
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
var coin_label: Label
var coin_pop: Label
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
	_place(br, 1.0, 1.0, 1.0, 1.0, -480, -250, -20, -20)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(br)
	var wood_row := HBoxContainer.new()
	wood_row.alignment = BoxContainer.ALIGNMENT_END
	wood_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br.add_child(wood_row)
	wood_pop = _label(wood_row, "", 22, Color(0.6, 1.0, 0.5))
	wood_label = _label(wood_row, "BOIS 0", 26, Color(0.95, 0.75, 0.5))
	stone_pop = _label(wood_row, "", 22, Color(0.6, 1.0, 0.5))
	stone_label = _label(wood_row, "", 26, Color(0.78, 0.78, 0.92))
	coin_pop = _label(wood_row, "", 22, Color(0.6, 1.0, 0.5))
	coin_label = _label(wood_row, "", 26, Color(0.75, 0.9, 1.0))
	ammo_label = _label(br, "30 / ∞", 36)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label = _label(br, "", 15, Color(0.85, 0.9, 1.0))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(440, 0)
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_END
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_row.add_theme_constant_override("separation", 8)
	br.add_child(slot_row)
	slot_on = UI.box(Color(0.2, 0.5, 1.0, 0.9), 8, 14.0, 8.0)
	slot_on.border_color = Color.WHITE
	slot_on.set_border_width_all(3)
	slot_off = UI.box(Color(0.05, 0.05, 0.15, 0.65), 8, 14.0, 8.0)
	for txt in ["1\nPISTOLET", "2\nFUSIL", "3\nHACHE", "4\nBÂTIR"]:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(100, 70)
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

	# mini-carte en haut à droite
	minimap = Minimap.new()
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(minimap, 1.0, 0.0, 1.0, 0.0, -230, 14, -14, 230)
	root.add_child(minimap)

	# barre de vie de l'ennemi visé (au-dessus du viseur)
	enemy_box = VBoxContainer.new()
	enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(enemy_box, 0.5, 0.5, 0.5, 0.5, -110, -78, 110, -30)
	root.add_child(enemy_box)
	enemy_name = _label(enemy_box, "", 15, Color(1, 0.8, 0.75))
	enemy_bar = ProgressBar.new()
	enemy_bar.show_percentage = false
	enemy_bar.custom_minimum_size = Vector2(220, 12)
	enemy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_bar.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.6), 4, 0.0, 0.0))
	enemy_fill = UI.box(Color(0.95, 0.25, 0.2), 4, 0.0, 0.0)
	enemy_bar.add_theme_stylebox_override("fill", enemy_fill)
	enemy_box.add_child(enemy_bar)
	enemy_box.visible = false

	pause_panel = _overlay("PAUSE", "", ["REPRENDRE", "MENU PRINCIPAL"], [func(): set_paused(false), func(): menu_pressed.emit()])
	var end := _overlay("", "", ["REJOUER", "MENU PRINCIPAL"], [func(): retry_pressed.emit(), func(): menu_pressed.emit()])
	end_panel = end
	end_title = end.get_meta("title")
	end_sub = end.get_meta("sub")
	confirm_panel = _overlay("", "", ["CONFIRMER", "ANNULER"], [func(): _close_confirm(true), func(): _close_confirm(false)])
	confirm_title = confirm_panel.get_meta("title")
	confirm_text = confirm_panel.get_meta("sub")
	confirm_title.add_theme_font_size_override("font_size", 52)
	_build_inventory()


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
	coin_label.text = ("   PIÈCES %d" % p.coins) if (p.coins > 0 or not p.first_coin) else ""
	# Construction visée : réparer / améliorer
	var bt = p.build_target
	if bt and is_instance_valid(bt) and not p.dead:
		var mname: String = p.MAT_NAMES[bt.material_type].to_lower()
		var parts: Array[String] = [bt.describe() + "  %d / %d PV" % [int(ceil(bt.hp)), int(bt.max_hp)]]
		var rc: int = bt.repair_cost()
		if rc > 0:
			parts.append("[G / ↓] Réparer (%d %s)" % [rc, mname])
		elif bt.is_repairing():
			parts.append("Réparation en cours...")
		if bt.can_upgrade():
			parts.append("[T / ↑] Améliorer : PV ×%d (%d %s)" % [int(bt.next_upgrade_mult()), bt.upgrade_cost(), mname])
		else:
			parts.append("Niveau maximum")
		parts.append("[X / →] Modifier : %s" % bt.next_edit_label())
		if bt.can_have_trap():
			parts.append("[B / clic stick droit] Poser des barbelés (%d pièces)" % bt.TRAP_COST)
		elif bt.trap:
			parts.append("Barbelés posés")
		build_prompt.text = "\n".join(parts)
	else:
		build_prompt.text = ""
	var si: int = p.slot_index()
	var short := {0: "PISTOLET", 1: "FUSIL"}
	for i in slots.size():
		slots[i].add_theme_stylebox_override("panel", slot_on if i == si else slot_off)
		if i < 2:
			var w: int = p.loadout[i]
			(slots[i].get_child(0) as Label).text = "%d\n%s" % [i + 1, short[w] if w >= 0 else "—"]
			slots[i].modulate.a = 1.0 if w >= 0 else 0.35
	var mode := 0
	match p.weapon:
		0, 1:
			ammo_label.add_theme_color_override("font_color", Color.WHITE)
			ammo_label.text = "RECHARGE..." if p.reloading else "%d / ∞" % p.ammo
			info_label.text = ("Coup par coup · " if p.weapon == 0 else "") + "Clic G / RT : tirer · Clic D / LT : viser · R / X : recharger"
			mode = 0
			if p.aiming:
				mode = 3
			crosshair.visible = true
		2:
			ammo_label.add_theme_color_override("font_color", Color.WHITE)
			ammo_label.text = "HACHE"
			info_label.text = "Clic G / RT : couper un arbre (bois) ou un rocher (pierre)"
			mode = 1
			crosshair.visible = true
		3:
			var have: int = p.wood if p.build_mat == 0 else p.stone
			ammo_label.text = "%s · %s %d" % [p.PIECE_NAMES[p.build_piece], p.MAT_NAMES[p.build_mat], have]
			ammo_label.add_theme_color_override("font_color", Color.WHITE if have >= p.BUILD_COST else Color(1, 0.4, 0.35))
			info_label.text = "Clic G construire · F pièce · V matériau · X modifier\nManette : RT mur · LT sol · RB rampe · Y matériau · → modifier"
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


func coin_gain(amount: int) -> void:
	coin_pop.text = "   +%d" % amount
	coin_pop.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(coin_pop, "modulate:a", 0.0, 0.5)


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
	if confirm_panel.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			_close_confirm(false)
			get_viewport().set_input_as_handled()
		return
	if inventory_panel.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			close_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("weapon_next"):
			inventory_panel.next_page(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("weapon_prev"):
			inventory_panel.next_page(-1)
			get_viewport().set_input_as_handled()
		return
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


# ------------------------------------------------------------------ ennemi visé

func set_enemy(z) -> void:
	if z == null or not is_instance_valid(z) or z.dead:
		enemy_box.visible = false
		return
	enemy_box.visible = true
	var names := {"minion": "SQUELETTE", "rogue": "SQUELETTE À CAPUCHE", "boss": "BOSS"}
	enemy_name.text = "%s  %d / %d" % [names.get(z.kind, "SQUELETTE"), int(ceil(maxf(z.hp, 0.0))), int(z.max_hp)]
	enemy_bar.max_value = z.max_hp
	enemy_bar.value = maxf(z.hp, 0.0)
	enemy_fill.bg_color = Color(1.0, 0.75, 0.15) if z.kind == "boss" else Color(0.95, 0.25, 0.2)


# ------------------------------------------------------------------ fenêtre de confirmation

func confirm(title: String, text: String, on_yes: Callable) -> void:
	confirm_title.text = title
	confirm_text.text = text
	confirm_cb = on_yes
	confirm_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(confirm_panel.get_meta("first") as Button).grab_focus()


func _close_confirm(yes: bool) -> void:
	confirm_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if yes and confirm_cb.is_valid():
		confirm_cb.call()


# ------------------------------------------------------------------ inventaire

func _build_inventory() -> void:
	inventory_panel = InventoryUI.new()
	root.add_child(inventory_panel)


func toggle_inventory(p) -> void:
	if inventory_panel.visible:
		close_inventory()
	else:
		open_inventory(p)


func open_inventory(p) -> void:
	inv_player = p
	inventory_panel.open(p)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	inventory_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
