extends ColorRect
## Inventaire en 2 pages (LB / RB à la manette, ou clic sur les onglets) :
##  1. Résumé : ressources, armes possédées, choix des 2 armes équipées (+ hache toujours)
##  2. Améliorations : arbre de compétences de chaque équipement

const UI = preload("res://scripts/ui.gd")
const Upg = preload("res://scripts/upgrades.gd")

var p                     # joueur
var page := 0
var selected_item := "pistol"
var tab_buttons: Array[Button] = []
var body: VBoxContainer
var title: Label
const DROP_STEPS := [10, 50, 100, 500, -1]   # -1 = tout
var drop_idx := {"wood": 1, "stone": 1, "coins": 0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.03, 0.02, 0.1, 0.8)
	visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.05, 0.18, 0.96), 16, 32.0, 22.0))
	panel.custom_minimum_size = Vector2(1000, 640)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 16)
	vb.add_child(top)
	_label(top, "LB ◀", 18, Color(0.7, 0.75, 0.9))
	for i in 2:
		var b := Button.new()
		b.text = ["RÉSUMÉ", "AMÉLIORATIONS"][i]
		b.custom_minimum_size = Vector2(260, 52)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func(): show_page(idx))
		top.add_child(b)
		tab_buttons.append(b)
	_label(top, "▶ RB", 18, Color(0.7, 0.75, 0.9))
	title = _label(vb, "", 18, Color(0.75, 0.8, 1.0))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	_label(vb, "Select / I / Tab : fermer   ·   LB / RB : changer de page   ·   A : valider", 14, Color(0.65, 0.65, 0.8))


func _label(parent: Node, txt: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node, txt: String, w: float, h: float, size: int, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.disabled = not enabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func open(player) -> void:
	p = player
	visible = true
	show_page(page)


func show_page(i: int) -> void:
	page = i
	for k in tab_buttons.size():
		tab_buttons[k].modulate = Color.WHITE if k == page else Color(0.55, 0.55, 0.65)
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var first: Control = _build_summary() if page == 0 else _build_upgrades()
	if first:
		call_deferred("_focus_if_valid", first)


## Donne le focus plus tard, seulement si le bouton existe encore (la page a pu être reconstruite).
func _focus_if_valid(b) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
		b.grab_focus()


func next_page(dir: int) -> void:
	show_page((page + dir + 2) % 2)


func _res_line(parent: Node) -> void:
	_label(parent, "BOIS  %d        PIERRE  %d        PIÈCES  %d" % [p.wood, p.stone, p.coins], 26)


# ------------------------------------------------------------------ page 1 : résumé

func _gun_name(w: int) -> String:
	return "— vide —" if w < 0 else p.WEAPON_NAMES[w]


func _build_summary() -> Control:
	title.text = "RESSOURCES ET ARMES"
	_res_line(body)
	var first: Control = null
	if p.main and p.main.rifle_craftable and not p.has_rifle:
		first = _button(body, "FABRIQUER LE FUSIL D'ASSAUT", 600, 52, 20, func():
			p.main.craft_rifle()
			show_page(0))
		(first as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_label(body, "ARMES ÉQUIPÉES  (A : changer)  —  la hache est toujours équipée", 18, Color(0.75, 0.8, 1.0))
	for slot in 2:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		body.add_child(row)
		_label(row, "EMPLACEMENT %d" % (slot + 1), 18)
		var sl := slot
		var b := _button(row, _gun_name(p.loadout[slot]), 420, 50, 20, func(): _cycle_slot(sl))
		if first == null:
			first = b
	var axe_row := HBoxContainer.new()
	axe_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(axe_row)
	_label(axe_row, "EMPLACEMENT 3   HACHE (toujours équipée)", 18, Color(0.8, 0.8, 0.85))
	# dépôt de ressources au sol (pour les donner à l'autre joueur)
	_label(body, "DÉPOSER AU SOL  (A sur la quantité pour la changer)", 18, Color(0.75, 0.8, 1.0))
	for kind in ["wood", "stone", "coins"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		body.add_child(row)
		var k: String = kind
		var nm := _label(row, {"wood": "BOIS", "stone": "PIERRE", "coins": "PIÈCES"}[k], 18)
		nm.custom_minimum_size = Vector2(110, 0)
		var qty := _button(row, _drop_text(k), 170, 42, 17, func(): _cycle_amount(k))
		qty.set_meta("drop_qty", k)
		_button(row, "DÉPOSER", 160, 42, 17, func():
			p.drop_resource(k, _drop_value(k))
			show_page(0))
	_label(body, "ARMES POSSÉDÉES", 18, Color(0.75, 0.8, 1.0))
	var guns := [p.W.PISTOL, p.W.RIFLE]
	if p.has_cryo:
		guns.append(p.W.CRYO)
	for w in guns:
		var owned: bool = p.owned_guns().has(w)
		var txt := "%s  —  " % p.WEAPON_NAMES[w]
		if w == p.W.CRYO:
			txt += "rayon de glace continu · ralentit à 70 % · +10 % de dégâts subis (3 s) · dégâts très faibles"
		elif owned:
			txt += "%d balles · %.1f tirs/s · %.0f dégâts%s" % [p.gun_mag(w), 1.0 / p.gun_interval(w), p.gun_damage(w), " · coup par coup" if w == p.W.PISTOL else " · automatique"]
		else:
			txt += "verrouillé (se fabrique à la fin de la 1re sphère)"
		_label(body, txt, 17, Color.WHITE if owned else Color(0.55, 0.55, 0.6))
	return first


func _drop_value(kind: String) -> int:
	var v: int = DROP_STEPS[drop_idx[kind]]
	var have: int = {"wood": p.wood, "stone": p.stone, "coins": p.coins}[kind]
	return have if v < 0 else mini(v, have)


func _drop_text(kind: String) -> String:
	var v: int = DROP_STEPS[drop_idx[kind]]
	return "QUANTITÉ : TOUT" if v < 0 else "QUANTITÉ : %d" % v


func _cycle_amount(kind: String) -> void:
	drop_idx[kind] = (drop_idx[kind] + 1) % DROP_STEPS.size()
	for b in body.find_children("*", "Button", true, false):
		if b.get_meta("drop_qty", "") == kind:
			b.text = _drop_text(kind)


func _cycle_slot(slot: int) -> void:
	var opts: Array = p.owned_guns()
	opts.append(-1)
	var i := opts.find(p.loadout[slot])
	var nxt: int = opts[(i + 1) % opts.size()]
	if slot == 0 and nxt == -1:
		nxt = opts[0]   # l'emplacement 1 n'est jamais vide
	p.set_loadout(slot, nxt)
	show_page(0)
	# garder le focus sur le bouton de cet emplacement
	await get_tree().process_frame
	if not is_inside_tree() or not visible:
		return   # inventaire refermé entre-temps
	var btns := body.find_children("*", "Button", true, false)
	var idx := slot + (1 if (p.main and p.main.rifle_craftable and not p.has_rifle) else 0)
	if idx < btns.size():
		(btns[idx] as Button).grab_focus()


# ------------------------------------------------------------------ page 2 : améliorations

func _items() -> Array:
	var arr := ["pistol"]
	if p.has_rifle:
		arr.append("rifle")
	if p.has_cryo:
		arr.append("cryo")
	arr.append_array(["axe", "wire"])
	return arr


func _build_upgrades() -> Control:
	title.text = "AMÉLIORATIONS  —  choisis un équipement, puis une branche"
	_res_line(body)
	if not _items().has(selected_item):
		selected_item = "pistol"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# colonne de gauche : équipements
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var first: Control = null
	for item in _items():
		var it: String = item
		var b := _button(left, Upg.ITEMS[it]["name"], 220, 54, 18, func():
			selected_item = it
			show_page(1))
		if it == selected_item:
			b.add_theme_color_override("font_color", Color(0.1, 0.1, 0.4))
			b.text = "▶ " + b.text
			first = b
	# droite : branches de l'arbre
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_label(right, Upg.ITEMS[selected_item]["name"], 26, UI.YELLOW)
	var base_mag := 12 if selected_item == "pistol" else 30
	for br in Upg.ITEMS[selected_item]["branches"]:
		var branch: String = br[0]
		var lvl: int = p.upgrades[selected_item][branch]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		right.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		box.add_child(head)
		var nm := _label(head, br[1], 18)
		nm.custom_minimum_size = Vector2(300, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label(head, "●".repeat(lvl) + "○".repeat(Upg.MAX_LEVEL - lvl), 18, UI.YELLOW)
		_label(head, "NIV %d / %d" % [lvl, Upg.MAX_LEVEL], 16, Color(0.75, 0.8, 1.0))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		box.add_child(line)
		var now := Upg.effect_text(selected_item, branch, lvl, base_mag)
		if lvl >= Upg.MAX_LEVEL:
			_label(line, "Actuel : %s  —  MAXIMUM" % now, 15, Color(0.6, 1.0, 0.6))
		else:
			var c := Upg.cost(selected_item, branch, lvl + 1)
			var nxt := Upg.effect_text(selected_item, branch, lvl + 1, base_mag)
			var ok: bool = p.can_afford(c)
			var buy := func():
				if p.buy_upgrade(selected_item, branch):
					show_page(1)
			_button(line, "AMÉLIORER  (%s)" % Upg.cost_text(c), 330, 40, 15, buy, ok)
			_label(line, "%s  →  %s" % [now, nxt], 15, Color(0.85, 0.9, 1.0) if ok else Color(0.6, 0.6, 0.7))
	return first
