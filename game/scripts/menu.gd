extends Control
## Menu principal très sommaire : titre + bouton Commencer.

const UI = preload("res://scripts/ui.gd")

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.16, 0.36, 0.95);
	vec3 bottom = vec3(0.55, 0.18, 0.85);
	vec3 c = mix(top, bottom, uv.y);
	float r = length((uv - vec2(0.5, 0.42)) * vec2(1.6, 1.0));
	c += vec3(1.0, 0.85, 0.3) * smoothstep(0.55, 0.0, r) * (0.35 + 0.1 * sin(TIME * 1.5));
	float rays = 0.5 + 0.5 * sin(atan(uv.y - 0.42, uv.x - 0.5) * 14.0 + TIME * 0.4);
	c += vec3(0.08) * rays * smoothstep(0.9, 0.1, r);
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UI.make_theme()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BG_SHADER
	sm.shader = sh
	bg.material = sm
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	var title := Label.new()
	title.text = "ZONE ZÉRO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", UI.YELLOW)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", UI.DARK)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Coupe du bois, construis, défends la sphère.\n10 vagues de zombies."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)

	var start := Button.new()
	start.text = "COMMENCER"
	start.custom_minimum_size = Vector2(380, 80)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_on_start)
	vb.add_child(start)

	var quit := Button.new()
	quit.text = "QUITTER"
	quit.custom_minimum_size = Vector2(260, 56)
	quit.add_theme_font_size_override("font_size", 22)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)

	var help := Label.new()
	help.text = "ZQSD / WASD : bouger · Souris : viser · Clic G : tirer / couper / construire · Clic D : viser\n1 : fusil · 2 : hache · 3 : construction (F : mur / sol / rampe) · R : recharger · E : interagir · Échap : pause"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 15)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -700
	help.offset_right = 700
	help.offset_top = -80
	help.offset_bottom = -20
	add_child(help)

	start.grab_focus()


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
