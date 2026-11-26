extends Control
## Menu principal : la caméra avance lentement dans la forêt au crépuscule (vraie scène 3D du jeu :
## sapins, herbe, lucioles, rayons de lumière, sphère turquoise au loin) ; à gauche le logo et les
## boutons ; écran « COMMANDES » séparé.

const UI = preload("res://scripts/ui.gd")
const Nature = preload("res://scripts/nature.gd")
const Mats = preload("res://scripts/mats.gd")
const Main = preload("res://scripts/main.gd")

const CAM_START := 10.0
const CAM_END := -24.0
const CAM_SPEED := 0.6          # m/s : travelling très lent
const KEYART := "res://assets/ui/keyart.jpg"
const ORB_POS := Vector3(2.5, 0.0, -40.0)

const SIDE_SHADER := """
shader_type canvas_item;
void fragment() {
	// voile sombre à gauche (lisibilité des boutons), qui s'efface vers la droite
	float a = smoothstep(0.62, 0.0, UV.x) * 0.78 + smoothstep(0.75, 1.0, UV.y) * 0.35;
	COLOR = vec4(0.04, 0.02, 0.10, clamp(a, 0.0, 0.85));
}
"""

var cam: Camera3D
var t := 0.0
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
	if Settings.high_quality:
		_build_world()
	else:
		# graphismes légers : l'illustration peinte en fond, sans 3D
		var art := TextureRect.new()
		art.texture = UI.texture(KEYART)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	_build_ui()
	_intro()


# ------------------------------------------------------------------ forêt en arrière-plan

func _build_world() -> void:
	var high: bool = Settings.high_quality
	var world := Node3D.new()
	add_child(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# ciel, brouillard coloré, bloom
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Main.SKY_SHADER
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.22, 0.24, 0.5)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.17, 0.17, 0.38)
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.009
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.25
	if high:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0035
		env.volumetric_fog_albedo = Color(0.85, 0.85, 1.0)
		env.volumetric_fog_emission = Color(0.05, 0.04, 0.12)
		env.volumetric_fog_emission_energy = 0.3
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 70.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, 145, 0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.68, 0.42)
	sun.light_volumetric_fog_energy = 2.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0 if high else 35.0
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, -30, 0)
	fill.light_energy = 0.25
	fill.light_color = Color(0.45, 0.5, 1.0)
	world.add_child(fill)
	# sol
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	var gsh := Shader.new()
	gsh.code = Main.GROUND_SHADER
	gm.shader = gsh
	ground.material_override = gm
	ground.position = Vector3(0, 0, -40)
	world.add_child(ground)
	# sapins : de part et d'autre d'un sentier qui mène à la sphère
	var pines := Nature.pines()
	var per := {}
	for i in (320 if high else 170):
		var x := rng.randf_range(-45.0, 45.0)
		var z := rng.randf_range(-130.0, 14.0)
		if absf(x - _path_x(z)) < 4.5 or Vector2(x - ORB_POS.x, z - ORB_POS.z).length() < 9.0:
			continue
		var s := rng.randf_range(0.8, 1.5)
		var k := rng.randi() % pines.size()
		if not per.has(k):
			per[k] = []
		per[k].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0, z)))
	for k in per:
		_multimesh(world, pines[k], per[k])
	# herbe, plantes rouges, buissons
	var grass: Array = []
	for i in (2600 if high else 1100):
		var x := rng.randf_range(-22.0, 22.0)
		var z := rng.randf_range(-90.0, 14.0)
		if absf(x - _path_x(z)) < 1.2:
			continue
		var s := rng.randf_range(0.8, 1.3)
		grass.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0, z)))
	_multimesh(world, Nature.grass(), grass)
	for v in [1, 2]:
		var pl: Array = []
		for i in 70:
			var x := rng.randf_range(-16.0, 16.0)
			var z := rng.randf_range(-80.0, 10.0)
			if absf(x - _path_x(z)) < 2.0:
				continue
			var s := rng.randf_range(0.6, 1.1)
			pl.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0, z)))
		_multimesh(world, Nature.red_plant(v), pl)
	var bushes: Array = []
	for i in 60:
		var x := rng.randf_range(-20.0, 20.0)
		var z := rng.randf_range(-90.0, 10.0)
		if absf(x - _path_x(z)) < 3.0:
			continue
		var s := rng.randf_range(1.0, 2.0)
		bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0, z)))
	_multimesh(world, Nature.bush(false), bushes)
	for i in 6:
		var dt := MeshInstance3D.new()
		dt.mesh = Nature.dead_tree(1 + i % 3)
		dt.position = Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-100, -20))
		dt.rotation.y = rng.randf() * TAU
		world.add_child(dt)
	# la sphère au bout du sentier (socle de pierre + lueur turquoise)
	var stone := Mats.col(Color(0.3, 0.28, 0.38), 0.9)
	Mats.cylinder(world, 0.9, 1.2, 0.6, stone, ORB_POS + Vector3(0, 0.3, 0), Vector3.ZERO, 10)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.3, 1.0, 0.95)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.3, 1.0, 0.9)
	glow_mat.emission_energy_multiplier = 5.0
	Mats.sphere(world, 0.75, glow_mat, ORB_POS + Vector3(0, 1.6, 0), 24)
	Nature.glow_halo(world, Color(0.2, 0.7, 0.65), 7.0, ORB_POS + Vector3(0, 1.6, 0))
	var ol := OmniLight3D.new()
	ol.light_color = Color(0.3, 1.0, 0.9)
	ol.light_energy = 4.0
	ol.omni_range = 16.0
	ol.light_volumetric_fog_energy = 3.0
	ol.position = ORB_POS + Vector3(0, 2.0, 0)
	world.add_child(ol)
	# lucioles autour de la caméra
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 300.0
	world.add_child(cam)
	cam.current = true
	var ff := CPUParticles3D.new()
	ff.amount = 120 if high else 60
	ff.lifetime = 7.0
	ff.preprocess = 7.0
	ff.local_coords = false
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(14, 2.5, 18)
	ff.direction = Vector3.UP
	ff.spread = 180.0
	ff.gravity = Vector3(0, 0.05, 0)
	ff.initial_velocity_min = 0.1
	ff.initial_velocity_max = 0.4
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_color = Color(1.0, 0.9, 0.45)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.85, 0.4)
	fm.emission_energy_multiplier = 3.0
	q.material = fm
	ff.mesh = q
	ff.position = Vector3(0, 1.5, -12)
	cam.add_child(ff)
	t = 0.0
	_place_camera()


## Le sentier serpente doucement.
func _path_x(z: float) -> float:
	return sin(z * 0.05) * 3.0


func _multimesh(parent: Node, mesh: Mesh, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func _place_camera() -> void:
	var z := CAM_START - t * CAM_SPEED
	var pos := Vector3(_path_x(z) + sin(t * 0.21) * 0.4, 1.75 + sin(t * 0.37) * 0.08, z)
	cam.position = pos
	var look := ORB_POS + Vector3(sin(t * 0.13) * 2.0, 2.4, 0)
	cam.look_at(look, Vector3.UP)


func _process(delta: float) -> void:
	if cam == null:
		if fade:
			fade.color.a = maxf(fade.color.a - delta * 0.8, 0.0)
		return
	t += delta
	var z := CAM_START - t * CAM_SPEED
	# en fin de travelling : fondu au noir puis on recommence
	var remain := z - CAM_END
	if fade:
		fade.color.a = clampf(1.0 - remain / 3.0, 0.0, 1.0) if remain < 3.0 else maxf(fade.color.a - delta * 0.8, 0.0)
	if z <= CAM_END:
		t = 0.0
	_place_camera()


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
