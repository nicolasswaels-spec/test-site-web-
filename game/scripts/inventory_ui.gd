extends ColorRect
## Inventaire en 2 pages (LB / RB à la manette, ou clic sur les onglets), style « grille de cases » :
##  1. Inventaire : ressources, os et armes en cases avec icône et quantité. On sélectionne une case,
##     la fiche du bas propose les actions (armes : équiper en emplacement 1 ou 2 ;
##     ressources : déposer au sol ; tas d'os : utiliser).
##  2. Améliorations : cartes d'équipement à gauche, branches à droite (niveaux en pastilles, coût en icônes).

const UI = preload("res://scripts/ui.gd")
const Upg = preload("res://scripts/upgrades.gd")

var p                     # joueur
var page := 0
var selected_item := "pistol"
var sel := "w:0"          # case sélectionnée : « r:<ressource> » ou « w:<arme> »
var focus_key := ""       # case / bouton à re-sélectionner après reconstruction de la page
var tab_buttons: Array[Button] = []
var body: VBoxContainer
var title: Label
const DROP_STEPS := [1, 10, 50, 100, 500, -1]   # -1 = tout
var drop_idx := {}

const RES_MAIN := ["wood", "stone", "coins", "magic_wood", "magic_stone"]
const RES_BONES := ["bone", "big_bone", "arrow_bone", "bone_pile"]
const RES_NAMES := {"wood": "BOIS", "stone": "PIERRE", "coins": "PIÈCES", "magic_wood": "BOIS MAGIQUE", "magic_stone": "PIERRE MAGIQUE",
	"bone": "OS", "big_bone": "OS IMPOSANT", "arrow_bone": "OS EN FLÈCHE", "bone_pile": "TAS D'OS IMPOSANT"}
const RES_DESC := {
	"wood": "Se récolte à la hache sur les arbres. Construction, réparations, améliorations.",
	"stone": "Rochers (hache « bois » niveau 5) ou coffres. Pièces 2× plus solides que le bois.",
	"coins": "Pièces métalliques ramassées au sol. 2 pièces = des barbelés sur un sol.",
	"magic_wood": "Arbre magique abattu. 1 = une pièce moussue, 5× plus solide qu'une pièce en bois au maximum.",
	"magic_stone": "Rocher magique cassé. 1 = une pièce moussue, 5× plus solide qu'une pièce en pierre au maximum.",
	"bone": "Laissé par un squelette (une chance sur deux). Son usage arrive bientôt.",
	"big_bone": "Laissé par les boss des défenses. Son usage arrive bientôt.",
	"arrow_bone": "Laissé par les squelettes archers. Son usage arrive bientôt.",
	"bone_pile": "Laissé par le titan de lave. À utiliser : donne 6 os imposants et 10 os."}
# armes : index du joueur (W), rareté et couleur de carte
const WEAPON_ICONS := {0: "w_pistol", 1: "w_rifle", 4: "w_cryo", 5: "w_shock", 2: "w_axe"}
const RARITY := {0: ["RARE", Color(0.18, 0.42, 0.85)], 1: ["ÉPIQUE", Color(0.52, 0.22, 0.78)],
	4: ["LÉGENDAIRE", Color(0.85, 0.55, 0.12)], 5: ["MYTHIQUE", Color(0.72, 0.36, 0.2)], 2: ["OUTIL", Color(0.28, 0.45, 0.32)]}
const ITEM_ICONS := {"pistol": "w_pistol", "rifle": "w_rifle", "cryo": "w_cryo", "shock": "w_shock", "axe": "w_axe", "wire": "coins"}
const ITEM_W := {"pistol": 0, "rifle": 1, "cryo": 4, "shock": 5, "axe": 2, "wire": -1}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.02, 0.06, 0.82)
	visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	var ps := UI.box(Color(0.08, 0.08, 0.11, 0.94), 6, 28.0, 18.0)
	ps.border_color = Color(0.35, 0.35, 0.42)
	ps.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(1000, 660)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 16)
	vb.add_child(top)
	_label(top, "LB ◀", 18, Color(0.7, 0.72, 0.8))
	for i in 2:
		var b := Button.new()
		b.text = ["INVENTAIRE", "AMÉLIORATIONS"][i]
		b.custom_minimum_size = Vector2(250, 46)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func(): show_page(idx))
		top.add_child(b)
		tab_buttons.append(b)
	_label(top, "▶ RB", 18, Color(0.7, 0.72, 0.8))
	title = _label(vb, "", 15, Color(0.7, 0.72, 0.85))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	_label(vb, "Select / I / Tab : fermer   ·   LB / RB : changer de page   ·   A : sélectionner / valider", 13, Color(0.6, 0.6, 0.7))


# ------------------------------------------------------------------ outils d'interface

func _label(parent: Node, txt: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Titre de section, gras et penché comme dans les menus de Fortnite.
func _section(parent: Node, txt: String) -> Label:
	var l := _label(parent, txt, 22, Color(0.92, 0.92, 0.96))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_constant_override("outline_size", 8)
	var f := FontVariation.new()
	f.base_font = get_theme_default_font()
	f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
	f.variation_embolden = 0.6
	l.add_theme_font_override("font", f)
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


func _flat(bg: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var s := UI.box(bg, 4, 6.0, 6.0)
	s.border_color = border
	s.set_border_width_all(bw)
	return s


## Case carrée (ou carte) avec icône en haut et texte dessous.
func _tile(parent: Node, key: String, icon_name: String, txt: String, size: Vector2, bg: Color, cb: Callable, dim := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.icon = UI.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = txt
	b.add_theme_font_size_override("font_size", 20)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 6)
	var chosen := key == sel and page == 0
	var border := UI.YELLOW if chosen else Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", _flat(bg, border, 3 if chosen else 2))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.15), border, 3 if chosen else 2))
	b.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.15), border, 3))
	b.modulate = Color(1, 1, 1, 0.45) if dim else Color.WHITE
	b.set_meta("key", key)
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
		tab_buttons[k].modulate = Color.WHITE if k == page else Color(0.5, 0.5, 0.58)
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var first: Control = _build_inventory() if page == 0 else _build_upgrades()
	if focus_key != "":
		for b in body.find_children("*", "Button", true, false):
			if b.get_meta("key", "") == focus_key:
				first = b
				break
		focus_key = ""
	if first:
		call_deferred("_focus_if_valid", first)


## Donne le focus plus tard, seulement si le bouton existe encore (la page a pu être reconstruite).
func _focus_if_valid(b) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
		b.grab_focus()


func next_page(dir: int) -> void:
	show_page((page + dir + 2) % 2)


func _select(key: String, then_focus := "") -> void:
	sel = key
	focus_key = then_focus if then_focus != "" else key
	show_page(0)


# ------------------------------------------------------------------ page 1 : inventaire

func _build_inventory() -> Control:
	title.text = "Choisis une case : arme → emplacement 1 ou 2 · ressource → déposer au sol"
	var first: Control = null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	body.add_child(row)
	for grp in [["RESSOURCES", RES_MAIN], ["OS", RES_BONES]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		_section(col, grp[0])
		var tiles := HBoxContainer.new()
		tiles.add_theme_constant_override("separation", 8)
		col.add_child(tiles)
		for kind in grp[1]:
			var k: String = kind
			var n: int = p.res_count(k)
			var b := _tile(tiles, "r:" + k, k, str(n), Vector2(92, 104), Color(0.16, 0.16, 0.2, 0.95), func(): _select("r:" + k, "act0"), n == 0)
			if first == null:
				first = b
	_section(body, "ARMES")
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 10)
	body.add_child(wrow)
	var weapons := [0, 1]
	if p.has_cryo:
		weapons.append(4)
	if p.has_shock:
		weapons.append(5)
	weapons.append(2)
	for w in weapons:
		var wi: int = w
		var owned: bool = wi == 2 or p.owned_guns().has(wi)
		var txt: String = p.WEAPON_NAMES[wi]
		var slot: int = p.loadout.find(wi)
		if wi == 2:
			txt += "\nEMPLACEMENT 3"
		elif not owned:
			txt += "\nVERROUILLÉ"
		elif slot >= 0:
			txt += "\nEMPLACEMENT %d" % (slot + 1)
		else:
			txt += "\nNON ÉQUIPÉE"
		var bg: Color = RARITY[wi][1] if owned else Color(0.2, 0.2, 0.24)
		var b := _tile(wrow, "w:%d" % wi, WEAPON_ICONS[wi], txt, Vector2(218, 132), bg, func(): _select("w:%d" % wi, "act0"), not owned)
		b.add_theme_font_size_override("font_size", 15)
	first = _build_detail() if first == null else _build_detail_keep(first)
	return first


func _build_detail_keep(first: Control) -> Control:
	_build_detail()
	return first


## Fiche de la case sélectionnée + boutons d'action.
func _build_detail() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.12, 0.16, 0.95), Color(1, 1, 1, 0.12)))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	vb.add_child(head)
	var name_l := _section(head, "")
	var tag := _label(head, "", 15, Color(0.8, 0.8, 0.9))
	var desc := _label(vb, "", 16, Color(0.85, 0.86, 0.92))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(900, 0)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 12)
	vb.add_child(acts)
	var first: Button = null
	if sel.begins_with("r:"):
		var k := sel.substr(2)
		var n: int = p.res_count(k)
		name_l.text = RES_NAMES[k]
		tag.text = "× %d" % n
		desc.text = RES_DESC[k]
		if k == "bone_pile":
			var use_cb := func():
				p.use_bone_pile()
				_select(sel, "act0")
			first = _act(acts, "UTILISER  (+6 os imposants, +10 os)", 420, use_cb, n > 0)
		if not drop_idx.has(k):
			drop_idx[k] = 2 if n >= 10 else 0
		var qty_cb := func():
			drop_idx[k] = (drop_idx[k] + 1) % DROP_STEPS.size()
			_select(sel, "act%d" % (1 if k == "bone_pile" else 0))
		var q := _act(acts, _drop_text(k), 220, qty_cb, n > 0)
		var drop_cb := func():
			p.drop_resource(k, _drop_value(k))
			_select(sel, "r:" + k)
		var d := _act(acts, "DÉPOSER AU SOL", 250, drop_cb, n > 0)
		if first == null:
			first = q
		if n == 0:
			_label(acts, "Tu n'en as pas encore.", 15, Color(0.6, 0.6, 0.7))
		d.set_meta("key", "act%d" % (2 if k == "bone_pile" else 1))
		q.set_meta("key", "act%d" % (1 if k == "bone_pile" else 0))
	else:
		var w := int(sel.substr(2))
		name_l.text = p.WEAPON_NAMES[w]
		tag.text = RARITY[w][0]
		tag.add_theme_color_override("font_color", RARITY[w][1].lightened(0.35))
		if w == 2:
			desc.text = "Toujours équipée (emplacement 3). Coupe le bois, casse les rochers, frappe les squelettes. Un coup toutes les 0,9 s."
		elif not p.owned_guns().has(w):
			desc.text = "Se fabrique à la fin de la 1re sphère." if w == 1 else "Se trouve dans un coffre, ou se fabrique à la sphère (création d'arme)."
			if w == 1 and p.main and p.main.rifle_craftable:
				first = _act(acts, "FABRIQUER LE FUSIL D'ASSAUT", 420, func():
					p.main.craft_rifle()
					_select(sel, "act0"))
		else:
			if w == 4:
				desc.text = "Rayon de glace continu : ajoute des statuts de glace (1 à 10) qui ralentissent la cible et la rendent vulnérable."
			elif w == 5:
				desc.text = "1 os par tir · cône de 120° devant toi · %d m · %d dégâts à chaque squelette touché · %.1f s entre deux tirs" % [int(p.shock_range()), int(p.shock_damage()), p.shock_cooldown()]
			else:
				desc.text = "%d balles · %.1f tirs/s · %.0f dégâts · %s" % [p.gun_mag(w), 1.0 / p.gun_interval(w), p.gun_damage(w), "coup par coup" if w == 0 else "automatique"]
			for slot in 2:
				var sl := slot
				var inside: bool = p.loadout[sl] == w
				var eq_cb := func():
					p.set_loadout(sl, w)
					_select(sel, "w:%d" % w)
				var b := _act(acts, ("DANS L'EMPLACEMENT %d" if inside else "ÉQUIPER EMPLACEMENT %d") % (sl + 1), 330, eq_cb, not inside)
				if first == null and not inside:
					first = b
			if p.loadout[1] == w:
				_act(acts, "RETIRER", 160, func():
					p.set_loadout(1, -1)
					_select(sel, "w:%d" % w))
		if first == null:
			for b in acts.get_children():
				if b is Button and not b.disabled:
					first = b
					break
	var i := 0
	for b in acts.get_children():
		if b is Button and not b.has_meta("key"):
			b.set_meta("key", "act%d" % i)
		if b is Button:
			i += 1
	return first


func _act(parent: Node, txt: String, w: float, cb: Callable, enabled := true) -> Button:
	return _button(parent, txt, w, 46, 17, cb, enabled)


func _drop_value(kind: String) -> int:
	var v: int = DROP_STEPS[drop_idx.get(kind, 0)]
	var have: int = p.res_count(kind)
	return have if v < 0 else mini(v, have)


func _drop_text(kind: String) -> String:
	var v: int = DROP_STEPS[drop_idx.get(kind, 0)]
	return "QUANTITÉ : TOUT" if v < 0 else "QUANTITÉ : %d" % v


# ------------------------------------------------------------------ page 2 : améliorations

func _items() -> Array:
	var arr := ["pistol"]
	if p.has_rifle:
		arr.append("rifle")
	if p.has_cryo:
		arr.append("cryo")
	if p.has_shock:
		arr.append("shock")
	arr.append_array(["axe", "wire"])
	return arr


## Coût affiché en icônes : [icône] 300  [icône] 100 ...
func _cost_row(parent: Node, c: Dictionary) -> void:
	for k in ["wood", "stone", "coins", "bone", "big_bone"]:
		if c.get(k, 0) <= 0:
			continue
		var t := TextureRect.new()
		t.texture = UI.icon(k)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(30, 30)
		parent.add_child(t)
		var have: int = p.res_count(k)
		_label(parent, str(c[k]), 18, Color.WHITE if have >= c[k] or p.test_mode else Color(1, 0.45, 0.4))


func _build_upgrades() -> Control:
	title.text = "Choisis un équipement à gauche, puis une branche à améliorer"
	if not _items().has(selected_item):
		selected_item = "pistol"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# cartes d'équipement
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	_section(left, "ÉQUIPEMENT")
	var first: Control = null
	for item in _items():
		var it: String = item
		var w: int = ITEM_W[it]
		var bg: Color = RARITY[w][1] if w >= 0 else Color(0.35, 0.36, 0.42)
		var b := _tile(left, "u:" + it, ITEM_ICONS[it], Upg.ITEMS[it]["name"], Vector2(200, 92), bg, func():
			selected_item = it
			focus_key = "u:" + it
			show_page(1))
		b.add_theme_font_size_override("font_size", 16)
		if it == selected_item:
			b.add_theme_stylebox_override("normal", _flat(bg, UI.YELLOW, 4))
			first = b
	# branches
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_section(right, Upg.ITEMS[selected_item]["name"])
	var base_mag := 12 if selected_item == "pistol" else 30
	for br in Upg.ITEMS[selected_item]["branches"]:
		var branch: String = br[0]
		var lvl: int = p.upgrades[selected_item][branch]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _flat(Color(0.15, 0.15, 0.2, 0.95), Color(1, 1, 1, 0.12)))
		right.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card.add_child(vb)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		vb.add_child(head)
		var nm := _label(head, br[1], 17)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# niveaux en pastilles
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		head.add_child(pips)
		for i in Upg.max_level(selected_item, branch):
			var pc := Panel.new()
			pc.custom_minimum_size = Vector2(18, 14)
			pc.add_theme_stylebox_override("panel", _flat(UI.YELLOW if i < lvl else Color(0.08, 0.08, 0.1), Color(1, 1, 1, 0.25), 1))
			pips.add_child(pc)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		vb.add_child(line)
		var now := Upg.effect_text(selected_item, branch, lvl, base_mag)
		if lvl >= Upg.max_level(selected_item, branch):
			var l := _label(line, "%s  ·  MAXIMUM" % now, 15, Color(0.6, 1.0, 0.6))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			var c := Upg.cost(selected_item, branch, lvl + 1)
			var nxt := Upg.effect_text(selected_item, branch, lvl + 1, base_mag)
			var ok: bool = p.can_afford(c)
			var eff := _label(line, "%s  →  %s" % [now, nxt], 15, Color(0.85, 0.9, 1.0) if ok else Color(0.6, 0.6, 0.7))
			eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_cost_row(line, c)
			var key := "b:" + branch
			var buy_cb := func():
				if p.buy_upgrade(selected_item, branch):
					focus_key = key
					show_page(1)
			var buy := _button(line, "AMÉLIORER", 150, 36, 15, buy_cb, ok)
			buy.set_meta("key", key)
	return first
