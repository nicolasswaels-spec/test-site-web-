extends RefCounted
## Thème d'interface : polices Lilita One (titres, boutons) et Nunito (textes), boutons principaux
## ambrés, boutons secondaires en « verre » sombre liseré d'or, panneaux translucides.

const YELLOW := Color(1.0, 0.8, 0.3)          # or chaud (titres, accents)
const DARK := Color(0.09, 0.06, 0.16)          # violet très sombre (texte sur boutons ambre)
const CREAM := Color(1.0, 0.95, 0.86)
const GOLD_LINE := Color(1.0, 0.8, 0.42, 0.55)
const GLASS := Color(0.07, 0.06, 0.16, 0.78)
const TITLE_FONT := "res://assets/fonts/LilitaOne-Regular.ttf"
const BODY_FONT := "res://assets/fonts/Nunito-Variable.ttf"
## Flou + teinte de la scène derrière un menu (fond des fenêtres : pause, inventaire...).
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.05, 0.03, 0.13, 0.55);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.5).rgb;
	float v = distance(UV, vec2(0.5));
	c = mix(c, tint.rgb, clamp(tint.a + v * 0.45, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
"""

static var _fonts := {}
static var _blur: Shader


static func _load_font(path: String) -> FontFile:
	if _fonts.has(path):
		return _fonts[path]
	var f: FontFile = null
	if ResourceLoader.exists(path):
		f = load(path)
	else:
		f = FontFile.new()
		f.load_dynamic_font(path)
	_fonts[path] = f
	return f


## Police des titres et des boutons (arrondie et épaisse).
static func title_font() -> Font:
	return _load_font(TITLE_FONT)


## Police des textes (Nunito en gras).
static func make_font() -> Font:
	if _fonts.has("body"):
		return _fonts["body"]
	var fv := FontVariation.new()
	fv.base_font = _load_font(BODY_FONT)
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 750}
	_fonts["body"] = fv
	return fv


static func box(c: Color, radius := 10, margin_h := 18.0, margin_v := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	s.anti_aliasing = true
	return s


static func _glass_box(bg: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var s := box(bg, 12, 32.0, 12.0)
	s.border_color = border
	s.set_border_width_all(bw)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = make_font()
	t.default_font_size = 20
	# --- bouton principal : ambre chaud, relief en bas, ombre douce
	var normal := box(Color(0.98, 0.68, 0.22), 12, 40.0, 12.0)
	normal.border_width_bottom = 5
	normal.border_color = Color(0.68, 0.34, 0.06)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.8, 0.4)
	hover.shadow_color = Color(1.0, 0.7, 0.3, 0.45)
	hover.shadow_size = 16
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.9, 0.56, 0.14)
	pressed.border_width_bottom = 1
	var disabled := box(Color(0.25, 0.23, 0.32, 0.6), 12, 40.0, 12.0)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	# Sélection (manette / clavier) : liseré blanc-or avec halo
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = Color(1.0, 0.97, 0.85)
	focus.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		focus.set_expand_margin(side, 5)
	focus.shadow_color = Color(1.0, 0.78, 0.35, 0.55)
	focus.shadow_size = 14
	t.set_stylebox("focus", "Button", focus)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "Button", DARK)
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.73, 0.82, 0.7))
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 28)
	# --- bouton secondaire : verre sombre, liseré doré, texte crème
	t.add_type("SecondaryButton")
	t.set_type_variation("SecondaryButton", "Button")
	var s_normal := _glass_box(Color(0.10, 0.08, 0.22, 0.75), GOLD_LINE)
	var s_hover := _glass_box(Color(0.20, 0.15, 0.36, 0.88), Color(1.0, 0.82, 0.45, 0.95))
	s_hover.shadow_color = Color(1.0, 0.75, 0.35, 0.3)
	s_hover.shadow_size = 12
	var s_pressed := _glass_box(Color(0.06, 0.05, 0.14, 0.9), Color(1.0, 0.82, 0.45, 0.95))
	t.set_stylebox("normal", "SecondaryButton", s_normal)
	t.set_stylebox("hover", "SecondaryButton", s_hover)
	t.set_stylebox("pressed", "SecondaryButton", s_pressed)
	t.set_stylebox("disabled", "SecondaryButton", _glass_box(Color(0.08, 0.07, 0.15, 0.5), Color(1, 1, 1, 0.1)))
	for k in ["font_color", "font_pressed_color"]:
		t.set_color(k, "SecondaryButton", CREAM)
	for k in ["font_hover_color", "font_focus_color"]:
		t.set_color(k, "SecondaryButton", Color(1.0, 0.88, 0.55))
	t.set_color("font_disabled_color", "SecondaryButton", Color(0.7, 0.7, 0.78, 0.5))
	# --- textes
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.02, 0.08, 0.85))
	t.set_constant("outline_size", "Label", 6)
	# --- panneaux : verre sombre, liseré doré, coins arrondis
	var panel := box(GLASS, 16, 18.0, 12.0)
	panel.border_color = Color(1.0, 0.8, 0.42, 0.35)
	panel.set_border_width_all(2)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


## Fond de fenêtre : la scène floutée et assombrie (à mettre sur un ColorRect plein écran).
static func blur_material(tint := Color(0.05, 0.03, 0.13, 0.55)) -> ShaderMaterial:
	if _blur == null:
		_blur = Shader.new()
		_blur.code = BLUR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _blur
	m.set_shader_parameter("tint", tint)
	return m


## Titre en police Lilita One, or chaud avec contour sombre.
static func style_title(l: Label, size: int, color := YELLOW) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", DARK)
	l.add_theme_constant_override("outline_size", maxi(8, size / 6))


## Apparition douce d'une fenêtre (fondu + léger zoom).
static func pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.97, 0.97)
	var tw := c.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "modulate:a", 1.0, 0.18)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static var _icons := {}

## Icône d'interface (assets/ui/<nom>.png) ; chargée brute si l'éditeur ne l'a pas encore importée.
static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "res://assets/ui/%s.png" % name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var img := Image.load_from_file(path)
		if img:
			tex = ImageTexture.create_from_image(img)
	_icons[name] = tex
	return tex


## Image quelconque du jeu (jpg / png), chargée brute si pas encore importée.
static func texture(path: String) -> Texture2D:
	if _icons.has(path):
		return _icons[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var img := Image.load_from_file(path)
		if img:
			tex = ImageTexture.create_from_image(img)
	_icons[path] = tex
	return tex
