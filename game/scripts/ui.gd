extends RefCounted
## Thème d'interface façon "battle royale" : gros caractères, boutons jaunes.

const YELLOW := Color(1.0, 0.83, 0.12)
const DARK := Color(0.08, 0.06, 0.18)


static func make_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue", "Arial", "DejaVu Sans", "Sans-Serif"])
	f.font_weight = 800
	return f


static func box(c: Color, radius := 10, margin_h := 18.0, margin_v := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = make_font()
	t.default_font_size = 20
	var normal := box(YELLOW, 12, 40.0, 14.0)
	normal.border_width_bottom = 5
	normal.border_color = Color(0.75, 0.55, 0.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.92, 0.45)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.92, 0.7, 0.05)
	pressed.border_width_bottom = 1
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "Button", DARK)
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 6)
	t.set_stylebox("panel", "PanelContainer", box(Color(0.05, 0.05, 0.15, 0.7), 10, 14.0, 10.0))
	return t
