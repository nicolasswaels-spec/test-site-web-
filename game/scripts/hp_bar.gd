extends RefCounted
## Barre de vie stylisée (murs et monstres) : cadre sombre à bouts biseautés, liseré doré,
## remplissage dégradé avec reflet, graduations, « traîne » claire qui rattrape les dégâts,
## part en cours de réparation en bleu. Même dessin en 3D (murs) et dans l'interface (monstres).

const BODY := """
uniform float ratio = 1.0;
uniform float lag = 1.0;        // ancienne valeur (traîne claire qui rattrape la vie)
uniform float repair = 0.0;     // part qui sera réparée (bleu)
uniform float aspect = 8.0;     // largeur / hauteur
uniform vec4 tint = vec4(0.0);  // couleur imposée (a > 0), sinon vert -> jaune -> rouge selon la vie

vec4 hp_bar(vec2 uv, float t) {
	float a = aspect;
	vec2 p = vec2(uv.x * a, uv.y);
	float cy = abs(p.y - 0.5);
	// bouts biseautés (pointes) : distance signée à la forme
	float d = max(cy - 0.5, abs(p.x - a * 0.5) + cy * 0.75 - a * 0.5);
	float aa = 1.5 * fwidth(d);
	float alpha = 1.0 - smoothstep(-aa, 0.0, d);
	if (alpha <= 0.0) {
		return vec4(0.0);
	}
	vec3 outer = vec3(0.04, 0.03, 0.07);
	vec3 gold = mix(vec3(1.0, 0.86, 0.5), vec3(0.62, 0.38, 0.14), uv.y);
	vec3 col = outer;
	float rim = smoothstep(-0.13 - aa, -0.13, d) * (1.0 - smoothstep(-0.06 - aa, -0.06, d));
	// intérieur
	float inner = 1.0 - smoothstep(-0.19 - aa, -0.19, d);
	float fx = clamp((p.x - 0.3) / (a - 0.6), 0.0, 1.0);
	vec3 empty = vec3(0.13, 0.06, 0.09) + 0.03 * step(0.5, fract((p.x + p.y) * 3.0));
	vec3 fill;
	if (tint.a > 0.0) {
		fill = tint.rgb;
	} else {
		fill = ratio > 0.5 ? mix(vec3(1.0, 0.82, 0.15), vec3(0.35, 0.92, 0.3), (ratio - 0.5) * 2.0)
				: mix(vec3(0.95, 0.18, 0.12), vec3(1.0, 0.82, 0.15), ratio * 2.0);
	}
	// relief : haut clair, bas sombre, fin reflet brillant
	float yy = (p.y - 0.25) / 0.5;
	fill *= mix(1.25, 0.6, clamp(yy, 0.0, 1.0));
	fill += vec3(0.35) * smoothstep(0.32, 0.24, abs(yy - 0.18)) * 0.5;
	// reflet qui glisse le long de la barre
	float sh = fract(t * 0.25);
	fill += vec3(0.25) * smoothstep(0.08, 0.0, abs(fx - sh * 1.6 + 0.3 - (p.y - 0.5) * 0.15));
	vec3 inside = empty;
	if (fx < ratio) {
		inside = fill;
	} else if (fx < ratio + repair) {
		inside = vec3(0.3, 0.6, 1.0) * (0.75 + 0.25 * sin(t * 8.0));
	} else if (fx < lag) {
		inside = vec3(1.0, 0.9, 0.7);
	}
	// graduations tous les 10 %
	float tick = abs(fract(fx * 10.0 + 0.5) - 0.5) / 10.0 * (a - 0.6);
	inside *= 1.0 - 0.4 * (1.0 - smoothstep(0.015, 0.035, tick)) * step(0.05, fx) * step(fx, 0.95);
	col = mix(col, inside, inner);
	col = mix(col, gold, rim);
	return vec4(col, alpha);
}
"""

const SPATIAL := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
""" + BODY + """
void vertex() {
	// toujours face à la caméra, taille constante à l'écran
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float dist = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	VERTEX *= clamp(dist, 2.0, 60.0) * 0.11;
}
void fragment() {
	vec4 c = hp_bar(UV, TIME);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

const CANVAS := """
shader_type canvas_item;
""" + BODY + """
void fragment() {
	COLOR = hp_bar(UV, TIME);
}
"""

static var _spatial: Shader
static var _canvas: Shader


static func spatial_material() -> ShaderMaterial:
	if _spatial == null:
		_spatial = Shader.new()
		_spatial.code = SPATIAL
	var m := ShaderMaterial.new()
	m.shader = _spatial
	return m


static func canvas_material() -> ShaderMaterial:
	if _canvas == null:
		_canvas = Shader.new()
		_canvas.code = CANVAS
	var m := ShaderMaterial.new()
	m.shader = _canvas
	return m
