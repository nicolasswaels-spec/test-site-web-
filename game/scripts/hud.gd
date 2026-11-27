extends CanvasLayer
## Interface en jeu : vie, munitions, bois, vagues, sphère, menus pause / fin.

const UI = preload("res://scripts/ui.gd")
const HpBar = preload("res://scripts/hp_bar.gd")
## intérieur du verre de la fiole (fraction de la hauteur de l'image), mesuré par tools/key_vial.py
const VIAL_Y_TOP := 0.2204
const VIAL_Y_BOT := 0.8616
const Upg = preload("res://scripts/upgrades.gd")
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


## Mini-carte tournante : la flèche du joueur pointe toujours vers le haut, c'est la carte qui tourne
## (le « N » suit le nord). Squelettes en rouge, sphère défendue en vert.
class Minimap extends Control:
	var main
	var player
	const SCALE := 1.5          # pixels par mètre
	func _process(_d: float) -> void:
		queue_redraw()
	## Cercle tracé seulement à l'intérieur du radar (rayon lim autour de c).
	func _clipped_circle(c: Vector2, lim: float, center: Vector2, radius: float, col: Color) -> void:
		var n := 128
		var prev := center + Vector2(radius, 0)
		for i in range(1, n + 1):
			var a := TAU * i / n
			var pt := center + Vector2(cos(a), sin(a)) * radius
			if prev.distance_to(c) < lim and pt.distance_to(c) < lim:
				draw_line(prev, pt, col, 2.0)
			prev = pt

	var yaw := 0.0
	func _w2m(c: Vector2, origin: Vector3, w: Vector3) -> Vector2:
		return c + Vector2(w.x - origin.x, w.z - origin.z).rotated(yaw) * SCALE
	func _draw() -> void:
		if main == null or player == null:
			return
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c, r, Color(0.05, 0.04, 0.12, 0.72))
		var o: Vector3 = player.global_position
		yaw = player.rotation.y
		# limite de la zone en cours uniquement, coupée au bord du radar
		var zc: Vector3 = main.zone_center(main.zone)
		var zr: float = main.zone_radius(main.zone)
		_clipped_circle(c, r - 2.0, _w2m(c, o, zc), zr * SCALE, Color(0.45, 0.5, 1.0, 0.7))
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
		var op := _w2m(c, o, main.objective_pos())
		if op.distance_to(c) > r - 7:
			op = c + (op - c).normalized() * (r - 7)
		draw_circle(op, 6.0, Color(0, 0, 0, 0.7))
		draw_circle(op, 4.5, Color(1.0, 0.45, 0.1) if main.zone == 3 else Color(0.3, 1.0, 0.4))
		# joueur : flèche bleue orientée
		# alliés (autres joueurs) : points bleus
		for other in main.players:
			if other != player and is_instance_valid(other):
				var ap := _w2m(c, o, other.global_position)
				if ap.distance_to(c) > r - 7:
					ap = c + (ap - c).normalized() * (r - 7)
				draw_circle(ap, 5.5, Color(0, 0, 0, 0.7))
				draw_circle(ap, 4.0, Color(0.35, 0.65, 1.0))
		var fwd := Vector2(0, -1)
		var side := Vector2(1, 0)
		var pts := PackedVector2Array([c + fwd * 9.0, c - fwd * 6.0 + side * 6.0, c - fwd * 3.0, c - fwd * 6.0 - side * 6.0])
		draw_colored_polygon(pts, Color(0.35, 0.65, 1.0))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.WHITE, 1.5)
		draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)
		# « N » sur le bord, dans la direction du nord
		var npos := c + Vector2(0, -1).rotated(yaw) * (r - 11.0)
		draw_circle(npos, 9.0, Color(0.05, 0.04, 0.12, 0.85))
		draw_string(ThemeDB.fallback_font, npos + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.4))


var root: Control
var top_box: VBoxContainer
var narrow := false
var main
var player          # joueur auquel appartient cette interface
var minimap: Minimap
var enemy_box: VBoxContainer
var enemy_name: Label
var enemy_bar: ColorRect
var enemy_bar_mat: ShaderMaterial
var enemy_ref = null
var enemy_lag := 1.0
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
var orb_bar: ColorRect
var orb_bar_mat: ShaderMaterial
var orb_lag := 1.0
var orb_title := ""
var orb_label: Label
var alert_label: Label
var hp_bar: Control
var hp_vial: ShaderMaterial
var hp_num: Label
var shield_bar: Control
var shield_vial: ShaderMaterial
var shield_num: Label
var vial_state := {"hp": [1.0, 1.0, 0.0, -1.0], "sh": [1.0, 1.0, 0.0, -1.0]}   # niveau, traîne, agitation, dernière valeur
var hp_label: Label
var skill_label: Label   # bouclier / boule de feu (au-dessus de la vie)
var scope: ColorRect     # vue à travers la lunette du fusil de précision
const SCOPE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 px = SCREEN_UV * (1.0 / SCREEN_PIXEL_SIZE);
	vec2 c = (1.0 / SCREEN_PIXEL_SIZE) * 0.5;
	float r = min(c.x, c.y) * 0.86;
	float d = distance(px, c);
	float lens = smoothstep(r, r - 3.0, d);
	vec2 o = abs(px - c);
	float cross = (step(o.x, 1.2) + step(o.y, 1.2)) * step(26.0, max(o.x, o.y)) * step(max(o.x, o.y), r * 0.9);
	float dot = step(d, 2.5);
	float rim = smoothstep(r - 10.0, r, d) * lens;
	vec4 col = vec4(0.0, 0.0, 0.0, 1.0 - lens);
	col = mix(col, vec4(0.0, 0.0, 0.0, 0.85), clamp(cross + dot, 0.0, 1.0) * lens);
	col = mix(col, vec4(0.0, 0.0, 0.0, 0.6), rim);
	COLOR = col;
}
"""
var ammo_label: Label
var info_label: Label
const RES_KINDS := ["wood", "magic_wood", "stone", "magic_stone", "cloud", "magic_cloud", "coins"]
var res_rows := {}     # type de ressource -> {row, label, pop}
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
var orb_panel: Control      # menu de la sphère (lancer, création d'arme)
var orb_launch_btn: Button
var orb_craft_btn: Button
var craft_panel: Control    # création d'arme
var craft_row: GridContainer
var menu_player
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

	scope = ColorRect.new()
	_full(scope)
	var smat := ShaderMaterial.new()
	var ssh := Shader.new()
	ssh.code = SCOPE_SHADER
	smat.shader = ssh
	scope.material = smat
	scope.visible = false
	root.add_child(scope)
	crosshair = Crosshair.new()
	_full(crosshair)
	root.add_child(crosshair)
	hit = HitMarker.new()
	_full(hit)
	root.add_child(hit)

	# --- haut : vague + sphère
	var top := VBoxContainer.new()
	top_box = top
	_place(top, 0.5, 0.0, 0.5, 0.0, -300, 10, 300, 150)
	top.add_theme_constant_override("separation", 2)
	root.add_child(top)
	wave_title = _label(top, "PRÉPARATION", 34, UI.YELLOW)
	UI.style_title(wave_title, 38)
	wave_sub = _label(top, "", 18)
	var orb_row := HBoxContainer.new()
	orb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	orb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(orb_row)
	orb_label = _label(orb_row, "SPHÈRE", 16, Color(0.75, 0.9, 1.0))
	# barre stylisée (même dessin que celles des murs et des monstres) : sphère et boss
	orb_bar = ColorRect.new()
	orb_bar.custom_minimum_size = Vector2(340, 26)
	orb_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb_bar_mat = HpBar.canvas_material()
	orb_bar_mat.set_shader_parameter("aspect", 340.0 / 26.0)
	orb_bar.material = orb_bar_mat
	orb_row.add_child(orb_bar)
	alert_label = _label(top, "", 20, Color(1, 0.3, 0.25))

	# --- bas gauche : vie
	var hp_panel := PanelContainer.new()
	hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hp_panel, 0.0, 1.0, 0.0, 1.0, 20, -70, 200, -20)
	root.add_child(hp_panel)
	var hp_vb := VBoxContainer.new()
	hp_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_panel.add_child(hp_vb)
	hp_label = _label(hp_vb, "100 PV", 22, Color(0.6, 1.0, 0.5))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_label = _label(root, "", 18, Color(1.0, 0.8, 0.55))
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(skill_label, 0.0, 1.0, 0.0, 1.0, 24, -128, 560, -100)
	# fioles illustrées (OpenArt) le long du bord gauche : vie (rouge) et bouclier (bleu, si débloqué).
	# Le liquide animé est dessiné sous l'image, dans l'intérieur du verre (masque).
	var hpv := _vial(Color(0.86, 0.07, 0.12), Vector2(18, -200), 92.0)
	hp_bar = hpv[0]
	hp_vial = hpv[1]
	hp_num = _label(root, "100", 20, Color(1.0, 0.78, 0.75))
	_place(hp_num, 0.0, 0.5, 0.0, 0.5, 18, 140, 110, 166)
	var shv := _vial(Color(0.2, 0.6, 1.0), Vector2(108, -130), 66.0)
	shield_bar = shv[0]
	shield_vial = shv[1]
	shield_num = _label(root, "0", 16, Color(0.72, 0.87, 1.0))
	_place(shield_num, 0.0, 0.5, 0.0, 0.5, 106, 116, 176, 140)

	# --- bas droite : armes, munitions, bois
	var br := VBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_END
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(br, 1.0, 1.0, 1.0, 1.0, -480, -250, -20, -20)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(br)
	# --- droite, sous la mini-carte : ressources (icône + quantité, une par ligne)
	var res_col := VBoxContainer.new()
	res_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	res_col.add_theme_constant_override("separation", 0)
	_place(res_col, 1.0, 0.0, 1.0, 0.0, -260, 238, -16, 440)
	root.add_child(res_col)
	var colors := {"wood": Color(0.95, 0.78, 0.55), "magic_wood": Color(0.55, 1.0, 0.7), "stone": Color(0.8, 0.8, 0.95),
		"magic_stone": Color(0.8, 0.65, 1.0), "cloud": Color(0.92, 0.95, 1.0), "magic_cloud": Color(1.0, 0.9, 0.6),
		"coins": Color(0.75, 0.9, 1.0)}
	for kind in RES_KINDS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		res_col.add_child(row)
		var pop := _label(row, "", 20, Color(0.6, 1.0, 0.5))
		var lab := _label(row, "0", 26, colors[kind])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var icon := TextureRect.new()
		icon.texture = load_icon(kind)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		res_rows[kind] = {"row": row, "label": lab, "pop": pop}
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
	slot_on = UI.box(Color(0.42, 0.26, 0.10, 0.9), 10, 14.0, 8.0)
	slot_on.border_color = Color(1.0, 0.8, 0.4)
	slot_on.set_border_width_all(3)
	slot_on.shadow_color = Color(1.0, 0.7, 0.3, 0.35)
	slot_on.shadow_size = 10
	slot_off = UI.box(Color(0.07, 0.06, 0.16, 0.72), 10, 14.0, 8.0)
	slot_off.border_color = Color(1.0, 0.8, 0.42, 0.25)
	slot_off.set_border_width_all(1)
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
	UI.style_title(center_title, 80)
	center_sub = _label(center_box, "", 24)
	center_box.modulate.a = 0.0

	prompt_label = _label(root, "", 26)
	_place(prompt_label, 0.5, 0.6, 0.5, 0.6, -400, 0, 400, 40)
	message_label = _label(root, "", 22, Color(1, 0.6, 0.4))
	_place(message_label, 0.5, 0.645, 0.5, 0.645, -400, 0, 400, 40)
	build_prompt = _label(root, "", 20, Color(0.85, 0.95, 1.0))
	_place(build_prompt, 0.5, 0.56, 0.5, 0.56, -500, 0, 500, 60)
	# messages d'information : en bas de l'écran (au-dessus de la barre d'armes), pas au milieu de la vue
	notice_label = _label(root, "", 18, Color(0.85, 0.85, 1.0))
	_place(notice_label, 0.5, 0.71, 0.5, 0.71, -560, 0, 560, 100)
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
	_place(enemy_box, 0.5, 0.5, 0.5, 0.5, -120, -86, 120, -30)
	root.add_child(enemy_box)
	enemy_name = _label(enemy_box, "", 15, Color(1, 0.8, 0.75))
	# barre stylisée (même dessin que celle des murs)
	enemy_bar = ColorRect.new()
	enemy_bar.custom_minimum_size = Vector2(240, 22)
	enemy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_bar_mat = HpBar.canvas_material()
	enemy_bar_mat.set_shader_parameter("aspect", 240.0 / 22.0)
	enemy_bar.material = enemy_bar_mat
	enemy_box.add_child(enemy_bar)
	enemy_box.visible = false

	if Settings.test_mode:
		# mode test : passer directement à l'étape suivante (zone 1 → 2 → titan → zone volcanique)
		pause_panel = _overlay("PAUSE", "MODE TEST", ["REPRENDRE", "ZONE SUIVANTE (TEST)", "MENU PRINCIPAL"],
			[func(): set_paused(false), _test_skip_zone, func(): menu_pressed.emit()])
	else:
		pause_panel = _overlay("PAUSE", "", ["REPRENDRE", "MENU PRINCIPAL"], [func(): set_paused(false), func(): menu_pressed.emit()])
	orb_panel = _overlay("SPHÈRE", "", ["LANCER", "CRÉATION D'ARME", "FERMER"],
		[_orb_launch, open_craft_menu, close_orb_menu])
	var obtns := orb_panel.find_children("*", "Button", true, false)
	orb_launch_btn = obtns[0]
	orb_craft_btn = obtns[1]
	_build_craft_panel()
	var end := _overlay("", "", ["REJOUER", "MENU PRINCIPAL"], [func(): retry_pressed.emit(), func(): menu_pressed.emit()])
	end_panel = end
	end_title = end.get_meta("title")
	end_sub = end.get_meta("sub")
	confirm_panel = _overlay("", "", ["CONFIRMER", "ANNULER"], [func(): _close_confirm(true), func(): _close_confirm(false)])
	confirm_title = confirm_panel.get_meta("title")
	confirm_text = confirm_panel.get_meta("sub")
	confirm_title.add_theme_font_size_override("font_size", 52)
	_build_inventory()


func _test_skip_zone() -> void:
	set_paused(false)
	if main:
		main.skip_zone()


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
	# fond : la scène floutée et assombrie ; au centre, un panneau de verre liseré d'or
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.material = UI.blur_material()
	dim.visible = false
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := _label(vb, title, 64, UI.YELLOW)
	UI.style_title(t, 64)
	var line := ColorRect.new()
	line.color = UI.GOLD_LINE
	line.custom_minimum_size = Vector2(260, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(line)
	var s := _label(vb, sub, 20)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(460, 0)
	for i in buttons.size():
		var b := Button.new()
		if i == 0:
			dim.set_meta("first", b)
		else:
			b.theme_type_variation = "SecondaryButton"
			b.add_theme_font_size_override("font_size", 24)
		b.text = buttons[i]
		b.custom_minimum_size = Vector2(400, 60 if i == 0 else 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(callbacks[i])
		vb.add_child(b)
	dim.set_meta("title", t)
	dim.set_meta("sub", s)
	dim.visibility_changed.connect(func():
		if dim.visible:
			UI.pop_in(panel))
	return dim


# ------------------------------------------------------------------ API utilisée par le jeu

func _process(delta: float) -> void:
	# écran scindé : bandeau du haut resserré pour ne pas passer sous la mini-carte
	var w := get_viewport().get_visible_rect().size.x
	if (w < 1300.0) != narrow:
		narrow = w < 1300.0
		top_box.offset_left = -300.0 if not narrow else -330.0
		top_box.offset_right = 300.0 if not narrow else 210.0
		top_box.anchor_left = 0.5 if not narrow else 0.45
		top_box.anchor_right = 0.5 if not narrow else 0.45
		wave_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF
	vignette_strength = maxf(vignette_strength - delta * 1.5, 0.0)
	vignette_mat.set_shader_parameter("strength", vignette_strength)
	if message_t > 0.0:
		message_t -= delta
		message_label.modulate.a = clampf(message_t, 0.0, 1.0)
	if notice_t > 0.0:
		notice_t -= delta
		notice_label.modulate.a = clampf(notice_t, 0.0, 1.0)
		notice_label.visible = notice_t > 0.0


## Fiole illustrée : liquide (shader + masque de l'intérieur du verre) sous l'image de la fiole.
## pos : coin haut gauche (ancré au milieu du bord gauche), w : largeur affichée.
func _vial(color: Color, pos: Vector2, w: float) -> Array:
	var frame: Texture2D = load("res://assets/ui/vial/vial_frame.png")
	var mask: Texture2D = load("res://assets/ui/vial/vial_mask.png")
	var h := w * frame.get_height() / frame.get_width()
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(box, 0.0, 0.5, 0.0, 0.5, pos.x, pos.y, pos.x + w, pos.y + h)
	root.add_child(box)
	var liquid := ColorRect.new()
	liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(liquid)
	var m := HpBar.vial_liquid_material(color, mask, VIAL_Y_TOP, VIAL_Y_BOT, h / w)
	liquid.material = m
	box.add_child(liquid)
	var tr := TextureRect.new()
	tr.texture = frame
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(tr)
	box.add_child(tr)
	return [box, m]


## Fiole : niveau, traîne qui rattrape les pertes, agitation du liquide quand la valeur change.
func _update_vial(k: String, m: ShaderMaterial, v: float, mx: float) -> void:
	var st: Array = vial_state[k]
	var dt := get_process_delta_time()
	var lv := clampf(v / maxf(mx, 1.0), 0.0, 1.0)
	if st[3] >= 0.0 and absf(v - st[3]) > 0.5:
		st[2] = minf(1.0, st[2] + absf(v - st[3]) / maxf(mx, 1.0) * 4.0 + 0.3)
	st[3] = v
	st[0] = lv
	st[1] = maxf(lv, move_toward(st[1], lv, dt * 0.35))
	st[2] = maxf(0.0, st[2] - dt * 0.8)
	m.set_shader_parameter("level", lv)
	m.set_shader_parameter("lag", st[1])
	m.set_shader_parameter("slosh", st[2])


func update_player(p) -> void:
	_update_vial("hp", hp_vial, p.hp, p.max_hp())
	hp_num.text = str(int(ceil(p.hp)))
	var has_shield: bool = p.shield_max() > 0.0
	shield_bar.visible = has_shield
	shield_num.visible = has_shield
	if has_shield:
		_update_vial("sh", shield_vial, p.shield, p.shield_max())
		shield_num.text = str(int(ceil(p.shield)))
	# ébullition : commence sous 55 % de vie, à fond sous 10 %
	hp_vial.set_shader_parameter("boil", 0.0 if p.dead else clampf((0.55 - p.hp / p.max_hp()) / 0.45, 0.0, 1.0))
	var extra := ""
	if p.has_skill("A7"):
		extra += "   FEU %s" % ("PRÊT (C / ◀)" if p.fireball_cd <= 0.0 else "%d s" % int(ceil(p.fireball_cd)))
	hp_label.text = "VIES %d" % p.lives
	skill_label.text = extra.strip_edges()
	var counts := {"wood": p.wood, "magic_wood": p.magic_wood, "stone": p.stone, "magic_stone": p.magic_stone,
		"cloud": p.clouds, "magic_cloud": p.magic_clouds, "coins": p.coins}
	var shown := {"wood": true, "magic_wood": p.magic_wood > 0, "stone": p.stone > 0 or p.can_mine_stone(),
		"magic_stone": p.magic_stone > 0, "cloud": p.clouds > 0 or (p.main != null and p.main.sky_unlocked),
		"magic_cloud": p.magic_clouds > 0, "coins": p.coins > 0 or not p.first_coin}
	for kind in RES_KINDS:
		var r: Dictionary = res_rows[kind]
		r["row"].visible = shown[kind]
		r["label"].text = str(counts[kind])
	# Construction visée : réparer / améliorer
	var bt = p.build_target
	if bt and is_instance_valid(bt) and not p.dead:
		var mname: String = p.MAT_NAMES[bt.repair_material()].to_lower()
		var parts: Array[String] = [bt.describe() + "  %d / %d PV" % [int(ceil(bt.hp)), int(bt.max_hp)]]
		var rc: int = p.repair_price(bt)
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
	var short := {0: "PISTOLET", 1: "FUSIL", 4: "CRYO", 5: "CHOC", 6: "SNIPER", 7: "ZEUS"}
	for i in slots.size():
		slots[i].add_theme_stylebox_override("panel", slot_on if i == si else slot_off)
		if i < 2:
			var w: int = p.loadout[i]
			(slots[i].get_child(0) as Label).text = "%d\n%s" % [i + 1, short[w] if w >= 0 else "—"]
			slots[i].modulate.a = 1.0 if w >= 0 else 0.35
	var mode := 0
	match p.weapon:
		0, 1, 4:
			ammo_label.add_theme_color_override("font_color", Color.WHITE if p.weapon != 4 else Color(0.6, 0.95, 1.0))
			if p.weapon == 4:
				ammo_label.text = "RAYON ∞"
				info_label.text = "Rayon de glace : ajoute des statuts de glace (1 à 10) ; plus il y en a, plus la cible est lente et vulnérable"
			else:
				ammo_label.text = "RECHARGE..." if p.reloading else "%d / ∞" % p.ammo
				info_label.text = ("Coup par coup · " if p.weapon == 0 else "") + "Clic G / RT : tirer · Clic D / LT : viser · R / X : recharger"
			mode = 0
			if p.aiming:
				mode = 3
			crosshair.visible = true
		7:
			var zready: bool = p.zeus_cd <= 0.0
			ammo_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0) if zready else Color(0.7, 0.7, 0.75))
			ammo_label.text = ("PRÊT" if zready else "%.1f s" % p.zeus_cd) + "  ·  NUAGES MAGIQUES %s" % ("∞" if p.test_mode else str(p.magic_clouds))
			info_label.text = "Éclair de Zeus : 1 nuage magique · %d ennemis au hasard sur la carte · %d dégâts chacun" % [p.Upg.ZEUS_TARGETS[p.zeus_level("targets")], int(p.Upg.ZEUS_DAMAGE[p.zeus_level("damage")])]
			mode = 0
			crosshair.visible = true
		6:
			var sready: bool = p.sniper_cd <= 0.0
			ammo_label.add_theme_color_override("font_color", Color.WHITE if sready else Color(0.7, 0.7, 0.75))
			ammo_label.text = ("PRÊT" if sready else "%.1f s" % p.sniper_cd) + "  ·  OS %s" % ("∞" if p.test_mode else str(p.bones))
			info_label.text = "Fusil de précision : 1 os par balle · %d dégâts · tête ×%.2f · Clic D / LT : lunette" % [int(p.sniper_damage()), p.sniper_headshot()]
			mode = 3 if p.aiming else 0
			crosshair.visible = true
		5:
			var ready: bool = p.shock_cd <= 0.0
			ammo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6) if ready else Color(0.7, 0.7, 0.75))
			var os_txt := "∞" if p.test_mode else str(p.bones)
			ammo_label.text = ("PRÊT" if ready else "%.1f s" % p.shock_cd) + "  ·  OS %s" % os_txt
			info_label.text = "Onde de choc : 1 os par tir · cône large devant toi (%d m) · %d dégâts" % [int(p.shock_range()), int(p.shock_damage())]
			mode = 0
			crosshair.visible = true
		2:
			ammo_label.add_theme_color_override("font_color", Color.WHITE)
			ammo_label.text = "HACHE"
			info_label.text = "Clic G / RT : couper un arbre (bois) ou un rocher (pierre)"
			mode = 1
			crosshair.visible = true
		3:
			var have: int = p._material_count(p.build_mat)
			ammo_label.text = "%s · %s %d" % [p.PIECE_NAMES[p.build_piece], p.MAT_NAMES[p.build_mat], have]
			ammo_label.add_theme_color_override("font_color", Color.WHITE if have >= p.build_cost() else Color(1, 0.4, 0.35))
			info_label.text = "Clic G construire · F pièce · V matériau · X modifier\nManette : RT mur · LT sol · RB rampe · Y matériau · → modifier"
			mode = 2
			crosshair.visible = true
	# lunette du fusil de précision
	var scoped: bool = p.weapon == 6 and p.aiming and p.ads_t > 0.7 and not p.dead
	scope.visible = scoped
	if scoped:
		crosshair.visible = false
	if p.dead:
		crosshair.visible = false
	if crosshair.mode != mode:
		crosshair.mode = mode
		crosshair.queue_redraw()


func set_wave(title: String, sub: String) -> void:
	wave_title.text = title
	wave_sub.text = sub


func set_orb(hp: float, max_hp: float, title := "SPHÈRE") -> void:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if title != orb_title:
		orb_title = title
		orb_lag = ratio
	orb_lag = maxf(ratio, move_toward(orb_lag, ratio, get_process_delta_time() * 0.4))
	orb_label.text = "%s %d  " % [title, int(ceil(hp))]
	orb_bar_mat.set_shader_parameter("ratio", ratio)
	orb_bar_mat.set_shader_parameter("lag", orb_lag)
	orb_bar_mat.set_shader_parameter("tint", Color(0.3, 0.82, 1.0, 1.0) if title == "SPHÈRE" else Color(1.0, 0.38, 0.1, 1.0))


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


static func load_icon(kind: String) -> Texture2D:
	return UI.icon(kind)


## Petit « +N » à gauche de la quantité qui vient d'augmenter.
func res_gain(kind: String, amount: int) -> void:
	var pop: Label = res_rows[kind]["pop"]
	pop.text = "+%d" % amount
	pop.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(pop, "modulate:a", 0.0, 0.5)


func stone_gain(amount: int) -> void:
	res_gain("stone", amount)


func coin_gain(amount: int) -> void:
	res_gain("coins", amount)


func show_notice(text: String, duration := 6.0) -> void:
	notice_label.text = text
	notice_t = duration
	notice_label.modulate.a = 1.0
	notice_label.visible = true


func wood_gain(amount: int) -> void:
	res_gain("wood", amount)


func damage_flash() -> void:
	vignette_strength = minf(vignette_strength + 0.6, 1.0)


## Un menu (pause, fin, confirmation, inventaire) de ce joueur est ouvert.
func menu_open() -> bool:
	return confirm_panel.visible or inventory_panel.visible or pause_panel.visible or end_panel.visible \
		or orb_panel.visible or craft_panel.visible


func _solo() -> bool:
	return main == null or main.players.size() < 2


func _act(ev: InputEvent, name: String) -> bool:
	return player != null and ev.is_action_pressed(player.a(name))


## Entrées de ce joueur quand un de ses menus est ouvert (appelé par le routeur d'entrées).
## Renvoie vrai si l'évènement a été utilisé.
func handle_input(ev: InputEvent) -> bool:
	if not menu_open():
		if _act(ev, "pause") and not game_over:
			set_paused(true)
			return true
		return false
	if confirm_panel.visible:
		if _act(ev, "nav_back") or _act(ev, "pause"):
			_close_confirm(false)
			return true
	elif inventory_panel.visible:
		if _act(ev, "nav_back") or _act(ev, "pause") or _act(ev, "inventory"):
			close_inventory()
			return true
		if _act(ev, "weapon_next"):
			inventory_panel.next_page(1)
			return true
		if _act(ev, "weapon_prev"):
			inventory_panel.next_page(-1)
			return true
	elif craft_panel.visible:
		if _act(ev, "nav_back") or _act(ev, "pause"):
			_close_craft()
			return true
	elif orb_panel.visible:
		if _act(ev, "nav_back") or _act(ev, "pause") or _act(ev, "interact"):
			close_orb_menu()
			return true
	elif pause_panel.visible:
		if _act(ev, "pause") or _act(ev, "nav_back"):
			set_paused(false)
			return true
	# navigation dans le menu ouvert
	if _act(ev, "nav_up"):
		_nav_dir(Vector2.UP)
		return true
	if _act(ev, "nav_down"):
		_nav_dir(Vector2.DOWN)
		return true
	if _act(ev, "nav_left"):
		_nav_dir(Vector2.LEFT)
		return true
	if _act(ev, "nav_right"):
		_nav_dir(Vector2.RIGHT)
		return true
	if _act(ev, "nav_accept"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and not (f as Button).disabled and f.is_visible_in_tree():
			(f as Button).pressed.emit()
		return true
	# tout autre évènement de ce joueur est absorbé tant que le menu est ouvert
	return not (ev is InputEventMouseButton or ev is InputEventMouseMotion)


func _current_menu() -> Control:
	if confirm_panel.visible:
		return confirm_panel
	if inventory_panel.visible:
		return inventory_panel
	if craft_panel.visible:
		return craft_panel
	if orb_panel.visible:
		return orb_panel
	if end_panel.visible:
		return end_panel
	return pause_panel


func _nav_buttons() -> Array:
	var out := []
	for b in _current_menu().find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			out.append(b)
	return out


## Navigation spatiale : va au bouton le plus proche dans la direction demandée
## (haut/bas restent dans la colonne, gauche/droite passent d'une colonne à l'autre).
func _nav_dir(d: Vector2) -> void:
	var btns := _nav_buttons()
	if btns.is_empty():
		return
	var cur = get_viewport().gui_get_focus_owner()
	if not btns.has(cur):
		(btns[0] as Button).grab_focus()
		return
	var cr: Rect2 = (cur as Control).get_global_rect()
	var cc := cr.get_center()
	var best = null
	# 1er passage : haut / bas dans la même colonne ; 2e passage (si rien trouvé) : la case la
	# plus proche dans cette direction, même décalée (ex. racine d'un arbre de compétences)
	for strict in [true, false]:
		best = _nav_pick(btns, cur, cr, cc, d, strict)
		if best:
			break
	if best:
		(best as Button).grab_focus()


func _nav_pick(btns: Array, cur, cr: Rect2, cc: Vector2, d: Vector2, strict: bool):
	var best = null
	var best_score := INF
	for b in btns:
		if b == cur:
			continue
		var r: Rect2 = (b as Control).get_global_rect()
		var v := r.get_center() - cc
		var along := v.dot(d)
		if along <= 4.0:
			continue
		var perp := absf(v.dot(Vector2(-d.y, d.x)))
		if d.y != 0.0:
			# vers le haut / le bas : on reste de préférence dans la même colonne
			var overlap := minf(cr.end.x, r.end.x) - maxf(cr.position.x, r.position.x)
			if overlap <= 0.0:
				if strict:
					continue
				perp *= 1.5
			else:
				perp = 0.0
		else:
			# vers la gauche / la droite : on reste de préférence sur la même ligne
			var overlap_y := minf(cr.end.y, r.end.y) - maxf(cr.position.y, r.position.y)
			if overlap_y > 0.0:
				perp = 0.0
			perp *= 1.5
		var score := along + perp
		if score < best_score:
			best_score = score
			best = b
	return best


func _nav_move(dir: int) -> void:
	var btns := _nav_buttons()
	if btns.is_empty():
		return
	var i := btns.find(get_viewport().gui_get_focus_owner())
	i = 0 if i < 0 else (i + dir + btns.size()) % btns.size()
	(btns[i] as Button).grab_focus()


func focus_first() -> void:
	var btns := _nav_buttons()
	if not btns.is_empty():
		(btns[0] as Button).grab_focus()


func _refresh_mouse() -> void:
	if main and main.has_method("refresh_mouse"):
		main.refresh_mouse()


func set_paused(p: bool) -> void:
	get_tree().paused = p
	pause_panel.visible = p
	if p:
		(pause_panel.get_meta("first") as Button).grab_focus()
	if main:
		main.on_pause_changed(self, p)
	_refresh_mouse()


func show_end(title: String, sub: String) -> void:
	game_over = true
	end_title.text = title
	end_sub.text = sub
	end_panel.visible = true
	(end_panel.get_meta("first") as Button).grab_focus()
	pause_panel.visible = false
	_refresh_mouse()


# ------------------------------------------------------------------ ennemi visé

func set_enemy(z) -> void:
	if z == null or not is_instance_valid(z) or z.dead:
		enemy_box.visible = false
		return
	enemy_box.visible = true
	var names := {"minion": "SQUELETTE", "rogue": "SQUELETTE À CAPUCHE", "boss": "BOSS", "titan": "TITAN DE LAVE", "sky_titan": "COLOSSE DES NUÉES", "archer": "SQUELETTE ARCHER", "angel": "ANGE SQUELETTE"}
	var lv: String = ("  NIV %d" % z.level) if z.get("level") != null and not z.is_in_group("titan") else ""
	enemy_name.text = "%s%s  %d / %d" % [names.get(z.kind, "SQUELETTE"), lv, int(ceil(maxf(z.hp, 0.0))), int(z.max_hp)]
	if z.is_frozen():
		enemy_name.text += "   GLACE %d" % z.frost_level()
	var ratio := clampf(z.hp / z.max_hp, 0.0, 1.0)
	if z != enemy_ref:
		enemy_ref = z
		enemy_lag = ratio
	enemy_lag = maxf(ratio, move_toward(enemy_lag, ratio, get_process_delta_time() * 0.6))
	enemy_bar_mat.set_shader_parameter("ratio", ratio)
	enemy_bar_mat.set_shader_parameter("lag", enemy_lag)
	enemy_bar_mat.set_shader_parameter("tint", Color(1.0, 0.72, 0.15, 1.0) if z.kind == "boss" or z.is_in_group("titan") else Color(0.92, 0.2, 0.16, 1.0))


# ------------------------------------------------------------------ fenêtre de confirmation

func confirm(title: String, text: String, on_yes: Callable) -> void:
	confirm_title.text = title
	confirm_text.text = text
	confirm_cb = on_yes
	confirm_panel.visible = true
	if _solo():
		get_tree().paused = true
	(confirm_panel.get_meta("first") as Button).grab_focus()
	_refresh_mouse()


func _close_confirm(yes: bool) -> void:
	confirm_panel.visible = false
	if _solo():
		get_tree().paused = false
	_refresh_mouse()
	if yes and confirm_cb.is_valid():
		confirm_cb.call()


# ------------------------------------------------------------------ inventaire

func _build_inventory() -> void:
	inventory_panel = InventoryUI.new()
	root.add_child(inventory_panel)


# ------------------------------------------------------------------ menu de la sphère

func open_orb_menu(p) -> void:
	if menu_open() or main == null:
		return
	menu_player = p
	var txt: String = main.orb_launch_text()
	orb_launch_btn.text = txt if txt != "" else "VAGUE EN COURS"
	orb_launch_btn.disabled = txt == ""
	var unlocked: bool = main.crafting_unlocked()
	orb_craft_btn.text = "CRÉATION D'ARME" if unlocked else "CRÉATION D'ARME  (dès la 2e sphère)"
	orb_craft_btn.disabled = not unlocked
	(orb_panel.get_meta("sub") as Label).text = "Lancer en avance reporte 50 % du temps restant sur la pause suivante." if txt != "" else ""
	orb_panel.visible = true
	if _solo():
		get_tree().paused = true
	var first: Button = orb_launch_btn if not orb_launch_btn.disabled else (orb_craft_btn if unlocked else orb_panel.find_children("*", "Button", true, false)[2])
	first.call_deferred("grab_focus")
	_refresh_mouse()


func close_orb_menu() -> void:
	orb_panel.visible = false
	craft_panel.visible = false
	if _solo():
		get_tree().paused = false
	_refresh_mouse()


func _orb_launch() -> void:
	close_orb_menu()
	if main:
		main.orb_launch()


func _build_craft_panel() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.material = UI.blur_material()
	dim.visible = false
	root.add_child(dim)
	craft_panel = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	dim.visibility_changed.connect(func():
		if dim.visible:
			UI.pop_in(panel))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := _label(vb, "CRÉATION D'ARME", 44, UI.YELLOW)
	UI.style_title(t, 50)
	_label(vb, "L'arme fabriquée est rangée dans l'inventaire (à équiper en emplacement 1 ou 2).", 16, Color(0.75, 0.78, 0.9))
	craft_row = GridContainer.new()
	craft_row.columns = 2
	craft_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	craft_row.add_theme_constant_override("h_separation", 16)
	craft_row.add_theme_constant_override("v_separation", 12)
	vb.add_child(craft_row)
	var back := Button.new()
	back.text = "RETOUR"
	back.theme_type_variation = "SecondaryButton"
	back.custom_minimum_size = Vector2(260, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_craft)
	vb.add_child(back)


func open_craft_menu() -> void:
	if main == null or not main.crafting_unlocked():
		return
	orb_panel.visible = false
	craft_panel.visible = true
	_refresh_craft()


func _close_craft() -> void:
	craft_panel.visible = false
	if menu_player:
		orb_panel.visible = true
		orb_craft_btn.call_deferred("grab_focus")
	else:
		close_orb_menu()


func _refresh_craft(focus_id := "") -> void:
	for c in craft_row.get_children():
		craft_row.remove_child(c)
		c.queue_free()
	var p = menu_player if menu_player else player
	var first: Button = null
	for r in Upg.CRAFTS:
		var id: String = r["id"]
		# arme réservée à la sphère des nuages : visible seulement là-bas (ou si déjà possédée)
		if r.get("sky_only", false) and not (main.zone == 5 and main.orb4 != null) and not p.owns_craft(id):
			continue
		var owned: bool = p.owns_craft(id)
		var card := PanelContainer.new()
		var ccol: Color = {"cryo": Color(0.85, 0.55, 0.12, 0.95), "shock": Color(0.70, 0.36, 0.20, 0.95),
			"sniper": Color(0.2, 0.45, 0.5, 0.95), "zeus": Color(0.35, 0.5, 0.85, 0.95)}.get(id, Color(0.4, 0.4, 0.5, 0.95))
		var cs := UI.box(ccol, 6, 16.0, 12.0)
		cs.border_color = Color(1, 1, 1, 0.25)
		cs.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", cs)
		card.custom_minimum_size = Vector2(420, 0)
		craft_row.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var ic := TextureRect.new()
		ic.texture = UI.icon(r["icon"])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(0, 80)
		cv.add_child(ic)
		_label(cv, r["name"], 24)
		var d := _label(cv, r["desc"], 15, Color(1, 1, 1, 0.9))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(340, 0)
		var cost_row := HBoxContainer.new()
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override("separation", 6)
		cv.add_child(cost_row)
		for k in ["wood", "stone", "magic_wood", "magic_stone", "magic_cloud", "coins", "bone", "arrow_bone", "big_bone"]:
			if not r["cost"].has(k):
				continue
			var t := TextureRect.new()
			t.texture = UI.icon(k)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(34, 34)
			cost_row.add_child(t)
			var enough: bool = p.test_mode or p.res_count(k) >= r["cost"][k]
			_label(cost_row, str(r["cost"][k]) + "  ", 20, Color.WHITE if enough else Color(1, 0.5, 0.45))
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 54)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 22)
		if owned:
			b.text = "DÉJÀ POSSÉDÉE"
			b.disabled = true
		else:
			b.text = "FABRIQUER"
			b.disabled = not p.can_afford(r["cost"])
			b.pressed.connect(func():
				if p.craft_weapon(id):
					show_center(r["name"], "Fabriquée ! Équipe-la depuis l'inventaire.", 2.5)
					_refresh_craft())
		cv.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first == null:
		first = craft_panel.find_children("*", "Button", true, false).back()
	first.call_deferred("grab_focus")


func toggle_inventory(p) -> void:
	if inventory_panel.visible:
		close_inventory()
	else:
		open_inventory(p)


func open_inventory(p) -> void:
	inv_player = p
	inventory_panel.open(p)
	# en solo l'inventaire met le jeu en pause ; à deux, non
	if _solo():
		get_tree().paused = true
	_refresh_mouse()


func close_inventory() -> void:
	inventory_panel.visible = false
	if _solo():
		get_tree().paused = false
	_refresh_mouse()
