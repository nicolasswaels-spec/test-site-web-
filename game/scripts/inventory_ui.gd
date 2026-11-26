extends ColorRect
## Inventaire en 2 pages (LB / RB à la manette, ou clic sur les onglets), style « grille de cases » :
##  1. Inventaire : ressources, os et armes en cases avec icône et quantité. On sélectionne une case,
##     la fiche du bas propose les actions (armes : équiper en emplacement 1 ou 2 ;
##     ressources : déposer au sol ; tas d'os : utiliser).
##  2. Améliorations : cartes d'équipement à gauche, branches à droite (niveaux en pastilles, coût en icônes).

const UI = preload("res://scripts/ui.gd")
const Skills = preload("res://scripts/skills.gd")
const Upg = preload("res://scripts/upgrades.gd")

var p                     # joueur
var page := 0
var selected_item := "pistol"
var sel_skill := "F1"
var sel := "w:0"          # case sélectionnée : « r:<ressource> » ou « w:<arme> »
var focus_key := ""       # case / bouton à re-sélectionner après reconstruction de la page
var tab_buttons: Array[Button] = []
var body: VBoxContainer
var title: Label
const DROP_STEPS := [1, 10, 50, 100, 500, -1]   # -1 = tout
var drop_idx := {}

const RES_MAIN := ["wood", "stone", "cloud", "coins", "magic_wood", "magic_stone", "magic_cloud"]
const RES_BONES := ["bone", "big_bone", "arrow_bone", "bone_pile"]
const RES_NAMES := {"wood": "BOIS", "stone": "PIERRE", "coins": "PIÈCES", "magic_wood": "BOIS MAGIQUE", "magic_stone": "PIERRE MAGIQUE",
	"cloud": "NUAGE", "magic_cloud": "NUAGE MAGIQUE",
	"bone": "OS", "big_bone": "OS IMPOSANT", "arrow_bone": "OS EN FLÈCHE", "bone_pile": "TAS D'OS IMPOSANT"}
const RES_DESC := {
	"wood": "Se récolte à la hache sur les arbres. Construction, réparations, améliorations.",
	"stone": "Rochers (hache « bois » niveau 5) ou coffres. Pièces 2× plus solides que le bois.",
	"coins": "Pièces métalliques ramassées au sol. 2 pièces = des barbelés sur un sol.",
	"magic_wood": "Arbre magique abattu. 1 = une pièce moussue, 5× plus solide qu'une pièce en bois au maximum.",
	"magic_stone": "Rocher magique cassé. 1 = une pièce moussue, 5× plus solide qu'une pièce en pierre au maximum.",
	"cloud": "Petits nuages de l'île céleste (un coup de hache = 10 nuages + 10 bois ou 10 pierre). Murs en nuage : 3× plus solides que la pierre.",
	"magic_cloud": "Nuage magique (1 chance sur 50). Pas de construction pour l'instant.",
	"bone": "Laissé par un squelette (une chance sur deux). Son usage arrive bientôt.",
	"big_bone": "Laissé par les boss des défenses. Son usage arrive bientôt.",
	"arrow_bone": "Laissé par les squelettes archers. Son usage arrive bientôt.",
	"bone_pile": "Laissé par le titan de lave. À utiliser : donne 6 os imposants et 10 os."}
# armes : index du joueur (W), rareté et couleur de carte
const WEAPON_ICONS := {0: "w_pistol", 1: "w_rifle", 4: "w_cryo", 5: "w_shock", 6: "w_sniper", 7: "w_zeus", 2: "w_axe"}
const RARITY := {0: ["RARE", Color(0.18, 0.42, 0.85)], 1: ["ÉPIQUE", Color(0.52, 0.22, 0.78)],
	4: ["LÉGENDAIRE", Color(0.85, 0.55, 0.12)], 5: ["MYTHIQUE", Color(0.72, 0.36, 0.2)], 6: ["MYTHIQUE", Color(0.2, 0.45, 0.5)], 7: ["DIVIN", Color(0.35, 0.5, 0.85)], 2: ["OUTIL", Color(0.28, 0.45, 0.32)]}
const ITEM_ICONS := {"pistol": "w_pistol", "rifle": "w_rifle", "cryo": "w_cryo", "shock": "w_shock", "sniper": "w_sniper", "zeus": "w_zeus", "axe": "w_axe", "wire": "coins"}
const ITEM_W := {"pistol": 0, "rifle": 1, "cryo": 4, "shock": 5, "sniper": 6, "zeus": 7, "axe": 2, "wire": -1}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	material = UI.blur_material(Color(0.04, 0.03, 0.11, 0.62))
	visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 660)
	cc.add_child(panel)
	visibility_changed.connect(func():
		if visible:
			UI.pop_in(panel))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 16)
	vb.add_child(top)
	_label(top, "LB ◀", 18, Color(0.7, 0.72, 0.8))
	for i in 3:
		var b := Button.new()
		b.text = ["INVENTAIRE", "AMÉLIORATIONS", "PERSONNAGE"][i]
		b.custom_minimum_size = Vector2(230, 46)
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
	var l := _label(parent, txt, 24, UI.CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_constant_override("outline_size", 8)
	# police des titres, légèrement penchée (esprit Fortnite)
	var f := FontVariation.new()
	f.base_font = UI.title_font()
	f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.15, 1), Vector2.ZERO)
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
	b.icon = UI.icon(icon_name) if icon_name != "" else null
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
		tab_buttons[k].theme_type_variation = "" if k == page else "SecondaryButton"
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var first: Control = null
	match page:
		0: first = _build_inventory()
		1: first = _build_upgrades()
		2: first = _build_skills()
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
	show_page((page + dir + 3) % 3)


func _select(key: String, then_focus := "") -> void:
	sel = key
	focus_key = then_focus if then_focus != "" else key
	show_page(0)


# ------------------------------------------------------------------ page 1 : inventaire

func _build_inventory() -> Control:
	title.text = "Choisis une case : arme → emplacement 1 ou 2 · ressource → déposer au sol"
	var first: Control = null
	for grp in [["RESSOURCES", RES_MAIN], ["OS", RES_BONES]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		body.add_child(col)
		_section(col, grp[0])
		var tiles := HBoxContainer.new()
		tiles.add_theme_constant_override("separation", 8)
		col.add_child(tiles)
		for kind in grp[1]:
			var k: String = kind
			var n: int = p.res_count(k)
			var b := _tile(tiles, "r:" + k, k, str(n), Vector2(88, 96), Color(0.16, 0.16, 0.2, 0.95), func(): _select("r:" + k, "act0"), n == 0)
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
	if p.has_sniper:
		weapons.append(6)
	if p.has_zeus:
		weapons.append(7)
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
			elif w == 7:
				desc.text = "1 nuage magique par tir · la foudre frappe %d ennemis au hasard sur la carte · %d dégâts chacun · toucher divin : +%d %% de dégâts pendant %.1f s" % [p.Upg.ZEUS_TARGETS[p.zeus_level("targets")], int(p.Upg.ZEUS_DAMAGE[p.zeus_level("damage")]), int(p.Upg.ZEUS_BOOST[p.zeus_level("boost")] * 100), p.Upg.ZEUS_DURATION[p.zeus_level("duration")]]
			elif w == 6:
				desc.text = "Coup par coup, 1 os par balle · %d dégâts · tête ×%.2f · %.1f s entre deux tirs · lunette (clic droit / LT)" % [int(p.sniper_damage()), p.sniper_headshot(), p.sniper_cooldown()]
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
	if p.has_sniper:
		arr.append("sniper")
	if p.has_zeus:
		arr.append("zeus")
	arr.append_array(["axe", "wire"])
	return arr


## Coût affiché en icônes : [icône] 300  [icône] 100 ...
func _cost_row(parent: Node, c: Dictionary) -> void:
	for k in ["wood", "stone", "magic_wood", "magic_stone", "magic_cloud", "coins", "bone", "arrow_bone", "big_bone"]:
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
	var base_mag := 12 if selected_item == "pistol" else 27
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
	if Upg.GOD_ITEMS.has(selected_item):
		_god_card(right)
	return first


## Carte « variante de Dieu » : disponible quand toutes les branches de l'arme sont au maximum.
func _god_card(parent: Node) -> void:
	var item := selected_item
	var owned: bool = p.god.get(item, false)
	var maxed: bool = Upg.all_maxed(p.upgrades, item)
	var card := PanelContainer.new()
	var gold := Color(1.0, 0.78, 0.3)
	card.add_theme_stylebox_override("panel", _flat(Color(0.24, 0.18, 0.08, 0.95) if maxed or owned else Color(0.15, 0.15, 0.2, 0.95),
		gold if maxed or owned else Color(1, 1, 1, 0.12), 2))
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	card.add_child(line)
	var txt := "%s  ·  dégâts ×2 · cadence ×2 · chargeur ×2 · rechargement ×2 (défense inchangée)" % Upg.GOD_NAMES[item]
	if owned:
		txt = "%s  ·  DÉBLOQUÉ" % Upg.GOD_NAMES[item]
	elif not maxed:
		txt = "%s  ·  toutes les améliorations au maximum pour la débloquer" % Upg.GOD_NAMES[item]
	var l := _label(line, txt, 15, gold if maxed or owned else Color(0.6, 0.6, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if owned:
		return
	_cost_row(line, Upg.GOD_COST)
	var ok: bool = maxed and p.can_afford(Upg.GOD_COST)
	var b := _button(line, "DÉBLOQUER", 150, 36, 15, func():
		if p.unlock_god(item):
			focus_key = "god"
			show_page(1), ok)
	b.set_meta("key", "god")


# ------------------------------------------------------------------ page 3 : arbre de compétences

## Zone de l'arbre : dessine les liaisons parent -> enfant derrière les cases.
class TreeCanvas extends Control:
	var links: Array = []     # [Button parent, Button enfant, couleur]
	func _draw() -> void:
		for l in links:
			var a: Button = l[0]
			var b: Button = l[1]
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var pa := a.position + Vector2(a.size.x * 0.5, a.size.y)
			var pb := b.position + Vector2(b.size.x * 0.5, 0)
			var mid := (pa.y + pb.y) * 0.5
			var col: Color = l[2]
			draw_polyline(PackedVector2Array([pa, Vector2(pa.x, mid), Vector2(pb.x, mid), pb]), col, 4.0)


func _build_skills() -> Control:
	title.text = "JETONS DE COMPÉTENCE : %d   ·   1 jeton par vague terminée, 3 après le titan" % p.skill_tokens
	if p.test_mode:
		title.text = "MODE TEST : prérequis et jetons ignorés"
	var canvas := TreeCanvas.new()
	canvas.custom_minimum_size = Vector2(960, 400)
	body.add_child(canvas)
	var col_w := 320.0
	var node_w := 102.0
	var node_h := 56.0
	var btns := {}
	var first: Control = null
	for bi in Skills.BRANCHES.size():
		var br: Array = Skills.BRANCHES[bi]
		var head := _section(canvas, br[1])
		head.position = Vector2(bi * col_w + 10, 0)
		head.add_theme_color_override("font_color", (br[2] as Color).lightened(0.3))
		for id in Skills.SKILLS:
			var sk: Dictionary = Skills.SKILLS[id]
			if sk["branch"] != br[0]:
				continue
			var st: String = p.skill_state(id)
			var bg: Color = br[2]
			match st:
				"owned": bg = (br[2] as Color).lightened(0.05)
				"ready": bg = Color(0.18, 0.2, 0.16)
				_: bg = Color(0.13, 0.13, 0.16)
			var sid: String = id
			var pick := func():
				sel_skill = sid
				focus_key = "unlock"
				show_page(2)
			var b := _tile(canvas, "s:" + id, "", sk["name"], Vector2(node_w, node_h), bg, pick, st == "need_parent")
			b.icon = null
			b.add_theme_font_size_override("font_size", 10 if (sk["name"] as String).length() > 9 else 12)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD
			b.clip_text = false
			var border := UI.YELLOW if id == sel_skill else (Color(0.5, 1.0, 0.5) if st == "ready" else Color(1, 1, 1, 0.2))
			b.add_theme_stylebox_override("normal", _flat(bg, border, 3 if id == sel_skill or st == "ready" else 2))
			var pos: Vector2 = sk["pos"]
			b.position = Vector2(bi * col_w + 4 + pos.x * (node_w + 3), 34 + pos.y * (node_h + 18))
			b.size = Vector2(node_w, node_h)
			btns[id] = b
			if id == sel_skill:
				first = b
	for id in btns:
		var par: String = Skills.SKILLS[id]["parent"]
		if par != "":
			var lit: bool = p.has_skill(par)
			canvas.links.append([btns[par], btns[id], Color(1.0, 0.85, 0.3, 0.9) if lit else Color(1, 1, 1, 0.18)])
	canvas.queue_redraw()
	# fiche de la compétence choisie
	var sk: Dictionary = Skills.SKILLS[sel_skill]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.12, 0.16, 0.95), Color(1, 1, 1, 0.12)))
	body.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var headrow := HBoxContainer.new()
	headrow.add_theme_constant_override("separation", 14)
	vb.add_child(headrow)
	_section(headrow, sk["name"])
	var st2: String = p.skill_state(sel_skill)
	var state_txt: String = {"owned": "DÉBLOQUÉE", "ready": "DÉBLOCABLE", "need_stat": "PRÉREQUIS NON ATTEINT", "need_parent": "DÉBLOQUE D'ABORD : " + (Skills.SKILLS[sk["parent"]]["name"] if sk["parent"] != "" else "")}[st2]
	_label(headrow, state_txt, 15, {"owned": UI.YELLOW, "ready": Color(0.5, 1.0, 0.5)}.get(st2, Color(0.75, 0.75, 0.8)))
	var d := _label(vb, sk["desc"], 16, Color(0.88, 0.9, 0.96))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(900, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var have: float = p.stat(sk["stat"])
	var req := _label(row, "Prérequis : %d / %d %s" % [int(minf(have, sk["need"])), sk["need"], Skills.STAT_NAMES[sk["stat"]]], 16,
		Color(0.6, 1.0, 0.6) if have >= sk["need"] else Color(1.0, 0.75, 0.5))
	req.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var can: bool = st2 == "ready" and (p.skill_tokens >= 1 or p.test_mode)
	var unlock_cb := func():
		if p.unlock_skill(sel_skill):
			focus_key = "s:" + sel_skill
			show_page(2)
	var ub := _button(row, "DÉJÀ DÉBLOQUÉE" if st2 == "owned" else "DÉBLOQUER (1 JETON)", 300, 44, 17, unlock_cb, can)
	ub.set_meta("key", "unlock")
	if focus_key == "unlock" and not can:
		focus_key = "s:" + sel_skill
	return first
