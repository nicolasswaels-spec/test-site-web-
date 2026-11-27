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


## Fiole verticale (vie, bouclier) : verre, bouchon doré, liquide dont la surface ondule et
## s'agite quand la valeur change, bulles qui montent, reflet. level / lag : 0..1.
const VIAL := """
shader_type canvas_item;
uniform float level = 1.0;
uniform float lag = 1.0;
uniform float slosh = 0.0;       // agitation (coup reçu / soin), retombe à 0
uniform float aspect = 6.0;      // hauteur / largeur
uniform vec4 liquid : source_color = vec4(0.85, 0.08, 0.12, 1.0);
uniform float danger = 0.0;      // > 0 : clignote (vie basse)

float hash(float n) { return fract(sin(n) * 43758.5453); }
float sd_box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }

void fragment() {
	float A = aspect;
	vec2 p = vec2(UV.x - 0.5, UV.y * A);      // unités : largeur de la fiole
	float t = TIME;
	float aa = 1.5 * fwidth(p.x);
	// bouchon doré
	float cap = sd_box(p - vec2(0.0, 0.17), vec2(0.36, 0.13)) - 0.05;
	float neck = sd_box(p - vec2(0.0, 0.38), vec2(0.27, 0.09));
	// corps : capsule
	float top = 0.45; float bot = A - 0.06; float r = 0.42;
	float yc = clamp(p.y, top + r, bot - r);
	float body = length(vec2(p.x, p.y - yc)) - r;
	float shape = min(min(cap, neck), body);
	float alpha = 1.0 - smoothstep(-aa, aa, shape);
	vec3 col;
	float a = 1.0;
	if (body < 0.0 && p.y > top + 0.02) {
		float inner = body + 0.075;
		// contenu : liquide ou vide (verre sombre)
		float ih_top = top + 0.08; float ih_bot = bot - 0.08;
		float surf = mix(ih_bot, ih_top, level);
		float wave = sin(p.x * 9.0 + t * 3.0) * (0.025 + 0.07 * slosh) + sin(p.x * 15.0 - t * 2.2) * (0.012 + 0.04 * slosh);
		surf += wave * step(0.001, level) * step(level, 0.999);
		float surf_lag = mix(ih_bot, ih_top, lag) + wave;
		vec3 glass = vec3(0.05, 0.04, 0.09);
		col = glass; a = 0.62;
		if (inner < 0.0) {
			if (p.y > surf) {
				float depth = (p.y - surf) / max(ih_bot - ih_top, 0.01);
				vec3 lc = liquid.rgb * mix(1.25, 0.55, clamp(depth * 1.4, 0.0, 1.0));
				// reflets mouvants dans le liquide
				lc += liquid.rgb * 0.09 * sin(p.y * 4.0 - t * 1.5 + sin(p.x * 4.0 + t) * 1.2);
				// ligne claire de la surface
				lc = mix(lc, vec3(1.0, 0.95, 0.9), (1.0 - smoothstep(0.0, 0.05, p.y - surf)) * 0.55);
				// bulles qui montent
				for (int i = 0; i < 7; i++) {
					float fi = float(i);
					float bx = (hash(fi * 3.1) - 0.5) * 0.5;
					float sp = 0.25 + hash(fi * 7.7) * 0.35;
					float by = ih_bot - fract(t * sp + hash(fi)) * (ih_bot - surf);
					float br = 0.025 + 0.025 * hash(fi * 5.3);
					float d = length(p - vec2(bx + sin(t * 2.0 + fi) * 0.03, by));
					lc = mix(lc, vec3(1.0), (1.0 - smoothstep(br * 0.6, br, d)) * 0.5 * step(surf, by));
				}
				lc *= 1.0 + danger * (0.35 + 0.35 * sin(t * 9.0));
				col = lc; a = 1.0;
			} else if (p.y > surf_lag) {
				col = mix(glass, liquid.rgb + 0.3, 0.55); a = 0.85;   // traîne de la valeur perdue
			}
		}
		// paroi du verre + reflet vertical
		float rim = smoothstep(-0.075, -0.02, body);
		col = mix(col, vec3(0.75, 0.8, 0.95), rim * 0.55); a = max(a, rim);
		float shine = (1.0 - smoothstep(0.0, 0.05, abs(p.x + 0.2))) * smoothstep(top + 0.1, top + 0.4, p.y) * (1.0 - smoothstep(bot - 0.5, bot - 0.2, p.y));
		col += vec3(0.5) * shine; 
		// graduations
		float g = step(0.0, inner) * 0.0 + (1.0 - smoothstep(0.0, 0.012, abs(fract((p.y - ih_top) / (ih_bot - ih_top) * 4.0 + 0.5) - 0.5) * (ih_bot - ih_top) / 4.0)) * step(0.18, p.x) * step(p.x, 0.3);
		col = mix(col, vec3(1.0, 0.9, 0.7), g * 0.5);
	} else {
		// bouchon et col : or
		float lit = 0.5 + 0.5 * cos(p.x * 3.0);
		col = mix(vec3(0.45, 0.26, 0.08), vec3(1.0, 0.82, 0.45), lit);
		col *= 0.85 + 0.15 * step(0.5, fract(p.y * 9.0));
	}
	// contour sombre
	float edge = smoothstep(-0.03, 0.0, shape);
	col = mix(col, vec3(0.03, 0.02, 0.05), edge);
	COLOR = vec4(col, a * alpha);
}
"""

static var _vial: Shader


static func vial_material(color: Color) -> ShaderMaterial:
	if _vial == null:
		_vial = Shader.new()
		_vial.code = VIAL
	var m := ShaderMaterial.new()
	m.shader = _vial
	m.set_shader_parameter("liquid", color)
	return m
