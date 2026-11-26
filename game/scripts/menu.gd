extends Control
## Menu principal : vidéo en boucle (OpenArt) du voyageur encapuchonné avachi dans l'herbe près de
## la sphère, avec une légère parallaxe à la souris. Sans la vidéo : l'image fixe animée par code
## (yeux et sphère qui pulsent, brume, lucioles).
## À gauche le logo et les boutons ; écran « COMMANDES » séparé.

const UI = preload("res://scripts/ui.gd")
const KEYART := "res://assets/ui/menu_art.jpg"        # illustration OpenArt : le voyageur avachi près de la sphère
const HERO_EYES := "res://assets/ui/menu_eyes.png"     # lueur des yeux (calque additif, même cadrage)
const VIDEO := "res://assets/ui/menu_loop.ogv"         # la même scène animée (vidéo OpenArt, 8 s en boucle)
const ART_SIZE := Vector2(1920, 1080)
const BG_ZOOM := 1.06                                  # marge pour la parallaxe
const ORB_PX := Vector2(1332, 636)       # sphère dans l'illustration (pixels de l'image 1920×1080)

const FOG_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float t = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(5.0, 2.5) + vec2(t * 0.04, 0.0);
	float f = n(p) * 0.6 + n(p * 2.1 - vec2(t * 0.07, 0.0)) * 0.4;
	// brume basse : dense au niveau du sol, nulle en haut et tout en bas
	float band = smoothstep(0.45, 0.72, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	COLOR = vec4(0.42, 0.36, 0.7, 1.0) * f * band * 0.22;
}
"""

const SIDE_SHADER := """
shader_type canvas_item;
void fragment() {
	// voile sombre à gauche (lisibilité des boutons), qui s'efface vers la droite
	float a = smoothstep(0.62, 0.0, UV.x) * 0.78 + smoothstep(0.75, 1.0, UV.y) * 0.35;
	COLOR = vec4(0.04, 0.02, 0.10, clamp(a, 0.0, 0.85));
}
"""

var t := 0.0
var art: Control           # scène 1920×1080, mise à l'échelle pour couvrir l'écran
var bg: TextureRect
var eyes: TextureRect
var orb_glow: TextureRect
var fog_mat: ShaderMaterial
var flies: CPUParticles2D
var video: VideoStreamPlayer
var fade: ColorRect
var buttons: Array[Button] = []
var commands_panel: Control
var first_button: Button


func _ready() -> void:
	get_tree().paused = false
	get_viewport().disable_3d = false
	GameInput.set_builtin_ui_nav(true)
	Music.play("menu")
	GameInput.setup_player(0, true, -2)
	Settings.coop = false
	Settings.test_mode = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UI.make_theme()
	_build_art()
	_build_ui()
	_intro()


# ------------------------------------------------------------------ illustration animée

func _layer(tex_path: String, size: Vector2, pos := Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.texture(tex_path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = size
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(r)
	return r


## Halo radial additif (lueur de la sphère).
func _glow_sprite(center: Vector2, radius: float, col: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(radius, radius) * 2.0
	r.position = center - Vector2(radius, radius)
	r.pivot_offset = Vector2(radius, radius)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = cm
	art.add_child(r)
	return r


func _build_art() -> void:
	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	art = Control.new()
	art.size = ART_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art)
	# fond un peu plus grand que l'écran : marge pour la parallaxe
	bg = _layer(KEYART, ART_SIZE * BG_ZOOM, -ART_SIZE * (BG_ZOOM - 1.0) * 0.5)
	if ResourceLoader.exists(VIDEO):
		# vidéo en boucle par-dessus l'image fixe (qui reste visible le temps du premier décodage) ;
		# elle anime déjà tout (capuche, herbe, brume, lucioles, sphère) : pas d'effets ajoutés
		video = VideoStreamPlayer.new()
		video.stream = load(VIDEO)
		video.expand = true
		video.volume_db = -80.0
		video.size = bg.size
		video.position = bg.position
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		video.finished.connect(video.play)
		art.add_child(video)
		video.play()
		_fit_art()
		get_viewport().size_changed.connect(_fit_art)
		return
	eyes = _layer(HERO_EYES, ART_SIZE * BG_ZOOM, bg.position)
	var em := CanvasItemMaterial.new()
	em.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	eyes.material = em
	orb_glow = _glow_sprite(_orb_pos(), 130.0, Color(0.25, 0.95, 0.9, 0.35))
	var fog := ColorRect.new()
	fog.size = ART_SIZE * 1.1
	fog.position = -ART_SIZE * 0.05
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_mat = ShaderMaterial.new()
	var fsh := Shader.new()
	fsh.code = FOG_SHADER
	fog_mat.shader = fsh
	fog.material = fog_mat
	art.add_child(fog)
	# lucioles
	flies = CPUParticles2D.new()
	flies.amount = 46
	flies.lifetime = 9.0
	flies.preprocess = 9.0
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(980, 260)
	flies.position = Vector2(960, 720)
	flies.direction = Vector2(0.3, -1)
	flies.spread = 70.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 6.0
	flies.initial_velocity_max = 22.0
	flies.scale_amount_min = 2.0
	flies.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.8, 0.35, 0), Color(1, 0.85, 0.4, 1), Color(1, 0.75, 0.3, 0.3), Color(1, 0.85, 0.45, 1), Color(1, 0.8, 0.35, 0)])
	flies.color_ramp = ramp
	var fm := CanvasItemMaterial.new()
	fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flies.material = fm
	art.add_child(flies)
	_fit_art()
	get_viewport().size_changed.connect(_fit_art)


## Position de la sphère une fois l'illustration agrandie (BG_ZOOM) et centrée.
func _orb_pos() -> Vector2:
	return ORB_PX * BG_ZOOM - ART_SIZE * (BG_ZOOM - 1.0) * 0.5


## La scène 1920×1080 couvre tout l'écran (recadrée au besoin), centrée.
func _fit_art() -> void:
	var vs := get_viewport_rect().size
	var k := maxf(vs.x / ART_SIZE.x, vs.y / ART_SIZE.y)
	art.scale = Vector2(k, k)
	art.position = (vs - ART_SIZE * k) * 0.5


func _process(delta: float) -> void:
	if fade:
		fade.color.a = maxf(fade.color.a - delta * 0.8, 0.0)
	if art == null:
		return
	t += delta
	# parallaxe : la souris (et un lent balancement) déplace les plans à des vitesses différentes
	var vs := get_viewport_rect().size
	var m := (get_viewport().get_mouse_position() / vs - Vector2(0.5, 0.5)) * 2.0
	m = m.clamp(Vector2(-1, -1), Vector2(1, 1)) + Vector2(sin(t * 0.11), sin(t * 0.07) * 0.5) * 0.35
	bg.position = -ART_SIZE * (BG_ZOOM - 1.0) * 0.5 - m * 14.0
	if video:
		video.position = bg.position
		return
	eyes.position = bg.position
	orb_glow.position = _orb_pos() - orb_glow.size * 0.5 - m * 14.0
	orb_glow.modulate.a = 0.75 + 0.25 * sin(t * 1.7)
	orb_glow.scale = Vector2.ONE * (1.0 + 0.06 * sin(t * 1.7))
	fog_mat.set_shader_parameter("t", t)
	flies.position = Vector2(960, 720) - m * 40.0
	# yeux : pulsation lente + clignement de temps en temps
	var blink := 0.0 if fmod(t, 5.3) < 0.12 else 1.0
	eyes.modulate.a = (0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.3))) * blink


# ------------------------------------------------------------------ interface

func _build_ui() -> void:
	var side := ColorRect.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssm := ShaderMaterial.new()
	var ssh := Shader.new()
	ssh.code = SIDE_SHADER
	ssm.shader = ssh
	side.material = ssm
	add_child(side)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 90
	col.offset_right = 760
	col.offset_top = 40
	col.offset_bottom = -40
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var logo_tex := UI.icon("logo")
	if logo_tex:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.custom_minimum_size = Vector2(620, 164)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(logo)
	else:
		var title := Label.new()
		title.text = "ZONE ZÉRO"
		UI.style_title(title, 110)
		col.add_child(title)

	var sub := Label.new()
	sub.text = "Coupe du bois, construis, défends les sphères.\nUne forêt au crépuscule, des squelettes... et bien plus haut, le ciel."
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(1.0, 0.93, 0.85, 0.92))
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap)

	first_button = _menu_button(col, "COMMENCER", true, _on_start)
	_menu_button(col, "JOUER À DEUX", false, func():
		Settings.coop = true
		_on_start())
	_menu_button(col, "MODE TEST", false, func():
		Settings.test_mode = true
		_on_start())
	_menu_button(col, "COMMANDES", false, _open_commands)
	var quality := _menu_button(col, "", false, func(): pass)
	var refresh := func(): quality.text = "GRAPHISMES : " + ("ÉLEVÉS" if Settings.high_quality else "LÉGERS")
	refresh.call()
	quality.pressed.connect(func():
		Settings.high_quality = not Settings.high_quality
		refresh.call())
	_menu_button(col, "QUITTER", false, func(): get_tree().quit())

	var hint := Label.new()
	hint.text = "Manette : croix directionnelle pour choisir · A pour valider"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 0.93, 0.85, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 92
	hint.offset_top = -44
	hint.offset_right = 800
	hint.offset_bottom = -18
	add_child(hint)

	_build_commands()
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	first_button.grab_focus()


func _menu_button(parent: Node, txt: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(440, 72 if primary else 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if not primary else HORIZONTAL_ALIGNMENT_CENTER
	if not primary:
		b.theme_type_variation = "SecondaryButton"
		b.add_theme_font_size_override("font_size", 24)
	else:
		b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(cb)
	parent.add_child(b)
	buttons.append(b)
	return b


## Entrée : les boutons glissent depuis la gauche l'un après l'autre.
func _intro() -> void:
	await get_tree().process_frame
	for i in buttons.size():
		var b := buttons[i]
		b.modulate.a = 0.0
		var x := b.position.x
		b.position.x = x - 40.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "modulate:a", 1.0, 0.35).set_delay(0.25 + i * 0.06)
		tw.tween_property(b, "position:x", x, 0.4).set_delay(0.25 + i * 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Lancement : fondu vers l'écran de chargement (illustration + logo), puis la partie.
func _on_start() -> void:
	for b in buttons:
		b.disabled = true
	var load_screen := TextureRect.new()
	load_screen.texture = UI.texture(KEYART)
	load_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	load_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	load_screen.modulate.a = 0.0
	add_child(load_screen)
	var logo_tex := UI.icon("logo")
	if logo_tex:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
		logo.offset_left = -330
		logo.offset_right = 330
		logo.offset_top = 40
		logo.offset_bottom = 215
		load_screen.add_child(logo)
	var lbl := Label.new()
	lbl.text = "CHARGEMENT DE LA FORÊT..."
	UI.style_title(lbl, 28, UI.CREAM)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left = -520
	lbl.offset_top = -80
	lbl.offset_right = -50
	lbl.offset_bottom = -36
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	load_screen.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(load_screen, "modulate:a", 1.0, 0.4)
	tw.tween_interval(0.25)   # le temps d'afficher l'écran avant le chargement (qui bloque)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))


# ------------------------------------------------------------------ écran « COMMANDES »

const KEYS := [
	["ZQSD / WASD", "Se déplacer"], ["Souris", "Regarder"], ["Clic gauche", "Tirer · couper · construire"],
	["Clic droit", "Viser · lunette"], ["Espace", "Sauter"], ["Maj", "Courir"], ["1 · 2", "Armes équipées"],
	["3", "Hache"], ["4", "Construction"], ["F", "Changer de pièce"], ["V", "Matériau"], ["X", "Modifier (porte, fenêtre...)"],
	["G · T", "Réparer · améliorer"], ["B", "Barbelés"], ["R", "Recharger"], ["E", "Interagir · menu de la sphère"],
	["C", "Boule de feu (compétence)"], ["I · Tab", "Inventaire"], ["Échap", "Pause"],
]
const PAD := [
	["Stick G", "Se déplacer"], ["Stick D", "Regarder"], ["RT", "Tirer · couper"], ["LT", "Viser · lunette"],
	["A", "Sauter"], ["Clic stick G", "Courir"], ["LB · RB", "Changer d'arme"], ["Y", "Arme 1 → 2 → hache"],
	["B", "Mode construction"], ["RT · LT · RB", "Mur · sol · rampe (construction)"], ["Croix →", "Modifier"],
	["Croix ↓ · ↑", "Réparer · améliorer"], ["Croix ←", "Boule de feu · pièce suivante"], ["Clic stick D", "Barbelés"],
	["X", "Recharger · interagir"], ["Vue", "Inventaire"], ["Start", "Pause"],
]


func _build_commands() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.material = UI.blur_material(Color(0.04, 0.02, 0.1, 0.5))
	dim.visible = false
	add_child(dim)
	commands_panel = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "COMMANDES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_title(title, 52)
	vb.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	vb.add_child(cols)
	for grp in [["CLAVIER ET SOURIS", KEYS], ["MANETTE", PAD]]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 5)
		cols.add_child(c)
		var h := Label.new()
		h.text = grp[0]
		UI.style_title(h, 24, UI.CREAM)
		c.add_child(h)
		for row in grp[1]:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 12)
			c.add_child(r)
			r.add_child(_keycap(row[0]))
			var l := Label.new()
			l.text = row[1]
			l.add_theme_font_size_override("font_size", 16)
			r.add_child(l)
	var back := Button.new()
	back.text = "RETOUR"
	back.theme_type_variation = "SecondaryButton"
	back.custom_minimum_size = Vector2(260, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_commands)
	vb.add_child(back)
	dim.set_meta("back", back)
	dim.set_meta("panel", panel)


## Touche dessinée comme une petite touche de clavier claire.
func _keycap(txt: String) -> Control:
	var p := PanelContainer.new()
	var sb := UI.box(Color(0.95, 0.9, 0.8), 6, 10.0, 2.0)
	sb.border_width_bottom = 3
	sb.border_color = Color(0.6, 0.5, 0.4)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(150, 0)
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UI.DARK)
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


func _open_commands() -> void:
	commands_panel.visible = true
	UI.pop_in(commands_panel.get_meta("panel"))
	(commands_panel.get_meta("back") as Button).grab_focus()


func _close_commands() -> void:
	commands_panel.visible = false
	first_button.grab_focus()


func _unhandled_input(ev: InputEvent) -> void:
	if commands_panel and commands_panel.visible and (ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause")):
		_close_commands()
		get_viewport().set_input_as_handled()
