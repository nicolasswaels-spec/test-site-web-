extends RefCounted
## Arbres d'amélioration (données + effets). Les coûts sont ici pour être faciles à ajuster.

const MAX_LEVEL := 8

## Coûts des niveaux 1 à 8 pour les armes et les barbelés :
## 1-2 : bois · 3-4 : pierre · 5-6 : bois + pierre · 7-8 : bois + pierre + pièces
const GEAR_COSTS := [
	{"wood": 300},
	{"wood": 600},
	{"stone": 100},
	{"stone": 250},
	{"wood": 400, "stone": 200},
	{"wood": 700, "stone": 400},
	{"wood": 1000, "stone": 600, "coins": 10},
	{"wood": 1500, "stone": 900, "coins": 20},
]
## Hache : la branche « bois » ne coûte que du bois, la branche « pierre » que de la pierre.
## Canon cryogénique : très cher dès le premier niveau (arme rare).
const CRYO_COSTS := [
	{"wood": 800, "stone": 400, "coins": 10},
	{"wood": 1200, "stone": 700, "coins": 15},
	{"wood": 1700, "stone": 1000, "coins": 20},
	{"wood": 2200, "stone": 1400, "coins": 25},
	{"wood": 2800, "stone": 1800, "coins": 30},
	{"wood": 3500, "stone": 2300, "coins": 40},
	{"wood": 4300, "stone": 2900, "coins": 50},
	{"wood": 5200, "stone": 3600, "coins": 60},
]
## Niveau de « récolte de bois » de la hache qui permet de récolter la pierre.
const STONE_UNLOCK_LEVEL := 5
const AXE_COSTS := [300, 550, 850, 1150, 1500, 1900, 2400, 3000]

const ITEMS := {
	"pistol": {"name": "PISTOLET", "branches": [
		["rate", "Cadence de tir"], ["damage", "Dégâts par balle"], ["mag", "Chargeur"], ["reload", "Vitesse de rechargement"], ["defense", "Défense (arme en main)"]]},
	"rifle": {"name": "FUSIL D'ASSAUT", "branches": [
		["rate", "Cadence de tir"], ["damage", "Dégâts par balle"], ["mag", "Chargeur"], ["reload", "Vitesse de rechargement"], ["defense", "Défense (arme en main)"]]},
	"axe": {"name": "HACHE", "branches": [
		["wood", "Récolte de bois (payée en bois)"], ["stone", "Récolte de pierre (payée en pierre)"]]},
	"cryo": {"name": "CANON CRYO", "branches": [
		["slow", "Ralentissement (à 10 statuts)"], ["damage", "Dégâts"], ["vuln", "Vulnérabilité (à 10 statuts)"], ["duration", "Durée d'un statut de glace"]]},
	"shock": {"name": "ONDE DE CHOC", "branches": [
		["damage", "Dégâts"], ["cooldown", "Rechargement"], ["range", "Portée"]]},
	"sniper": {"name": "FUSIL DE PRÉCISION", "branches": [
		["cooldown", "Réarmement"], ["damage", "Dégâts de base"], ["headshot", "Multiplicateur tir à la tête"], ["defense", "Défense (arme en main)"]]},
	"zeus": {"name": "ÉCLAIR DE ZEUS", "branches": [
		["targets", "Nombre de cibles"], ["damage", "Dégâts par cible"], ["boost", "Toucher divin (bonus de dégâts)"], ["duration", "Durée du toucher divin"]]},
	"wire": {"name": "BARBELÉS", "branches": [
		["slow", "Ralentissement"], ["damage", "Dégâts"]]},
}


static func new_state() -> Dictionary:
	var st := {}
	for item in ITEMS:
		st[item] = {}
		for b in ITEMS[item]["branches"]:
			st[item][b[0]] = 0
	return st


# ------------------------------------------------------------------ création d'arme (menu de la sphère, dès la 2e sphère)
const CRAFTS := [
	{"id": "cryo", "name": "CANON CRYOGÉNIQUE", "icon": "w_cryo", "cost": {"wood": 3300, "stone": 1700, "magic_wood": 8, "magic_stone": 8},
		"desc": "Rayon de glace continu : ralentit et rend vulnérable."},
	{"id": "shock", "name": "ONDE DE CHOC", "icon": "w_shock", "cost": {"wood": 2000, "stone": 1000, "bone": 30},
		"desc": "1 os par tir : cône large devant toi, 250 dégâts à tous les squelettes touchés."},
	{"id": "zeus", "name": "ÉCLAIR DE ZEUS", "icon": "w_zeus", "cost": {"magic_cloud": 5, "magic_wood": 3, "magic_stone": 3},
		"desc": "1 nuage magique par tir : la foudre frappe 7 ennemis au hasard sur la carte, 3000 dégâts chacun.", "sky_only": true},
	{"id": "sniper", "name": "FUSIL DE PRÉCISION", "icon": "w_sniper", "cost": {"wood": 2000, "stone": 1000, "arrow_bone": 20},
		"desc": "Lunette, coup par coup, 1 os par balle : 175 dégâts, ×3 à la tête."},
]


# ------------------------------------------------------------------ onde de choc
## Dégâts 250 -> 600 (10 niveaux), rechargement 4 s -> 2 s (4 niveaux), portée 6 -> 12 m (6 niveaux).
## Coûts en bois, pierre, pièces et os ; le dernier niveau de chaque branche demande aussi 1 os imposant.
const SHOCK_LEVELS := {"damage": 10, "cooldown": 4, "range": 6}
const SHOCK_COSTS := {
	"damage": {"wood": [300, 450, 600, 800, 1000, 1300, 1600, 2000, 2500, 3000],
		"stone": [100, 150, 200, 300, 400, 500, 650, 800, 1000, 1200],
		"coins": [0, 0, 2, 4, 6, 8, 10, 14, 18, 25],
		"bone": [5, 5, 8, 10, 12, 15, 18, 22, 26, 30]},
	"cooldown": {"wood": [600, 1200, 2000, 3000], "stone": [300, 600, 1000, 1500],
		"coins": [5, 10, 20, 30], "bone": [10, 20, 30, 40]},
	"range": {"wood": [400, 700, 1100, 1600, 2200, 3000], "stone": [200, 350, 550, 800, 1100, 1500],
		"coins": [2, 5, 8, 12, 16, 22], "bone": [6, 10, 14, 18, 24, 30]},
}
const SHOCK_BASE_DAMAGE := 250.0
const SHOCK_DAMAGE_STEP := 35.0
const SHOCK_BASE_COOLDOWN := 4.0
const SHOCK_BASE_RANGE := 6.0
const SHOCK_HALF_ANGLE := 60.0    # cône de 120°


static func shock_damage(lvl: int) -> float:
	return SHOCK_BASE_DAMAGE + SHOCK_DAMAGE_STEP * lvl


static func shock_cooldown(lvl: int) -> float:
	return SHOCK_BASE_COOLDOWN - 0.5 * lvl


static func shock_range(lvl: int) -> float:
	return SHOCK_BASE_RANGE + 1.0 * lvl


## Nombre de niveaux d'une branche (8 partout, sauf l'onde de choc).
static func max_level(item: String, branch: String) -> int:
	if item == "shock":
		return SHOCK_LEVELS[branch]
	if item == "zeus":
		return 5
	return MAX_LEVEL


# ------------------------------------------------------------------ fusil de précision
## Réarmement 1,6 s -> 0,8 s ; dégâts 175 -> 350 ; tir à la tête ×3 -> ×5 ; défense comme les autres armes.
const SNIPER_BASE_DAMAGE := 175.0
const SNIPER_BASE_COOLDOWN := 1.6
const SNIPER_BASE_HEADSHOT := 3.0
const SNIPER_COSTS := {"wood": [400, 700, 1000, 1400, 1900, 2500, 3200, 4000],
	"stone": [150, 300, 450, 650, 900, 1200, 1500, 1900],
	"coins": [0, 2, 4, 6, 9, 12, 16, 22],
	"arrow_bone": [1, 2, 2, 3, 3, 4, 5, 6]}     # moitié de l'ancien coût (arrondi au-dessus)


static func sniper_cooldown(lvl: int) -> float:
	return SNIPER_BASE_COOLDOWN - 0.1 * lvl


static func sniper_damage(lvl: int) -> float:
	return SNIPER_BASE_DAMAGE + 21.875 * lvl


static func sniper_headshot(lvl: int) -> float:
	return SNIPER_BASE_HEADSHOT + 0.25 * lvl


# ------------------------------------------------------------------ éclair de Zeus (5 niveaux par branche, non linéaires)
const ZEUS_TARGETS := [7, 8, 10, 11, 13, 15]
const ZEUS_DAMAGE := [3000.0, 3500.0, 4200.0, 5200.0, 7000.0, 10000.0]
const ZEUS_BOOST := [0.0, 0.15, 0.30, 0.50, 0.70, 1.0]       # toucher divin : bonus de dégâts du personnage
const ZEUS_DURATION := [2.0, 3.0, 4.5, 6.0, 8.0, 10.0]        # durée du toucher divin (s)
const ZEUS_COOLDOWN := 0.3   # l'arme est limitée par les nuages magiques, pas par la cadence
const ZEUS_COSTS := [{"magic_wood": 1}, {"magic_stone": 1}, {"magic_wood": 2}, {"magic_stone": 2},
	{"magic_cloud": 1, "magic_wood": 3, "magic_stone": 3}]


# ------------------------------------------------------------------ variantes de Dieu
## Quand TOUTES les branches d'une arme sont au maximum, on peut débloquer sa variante de Dieu
## (pas pour l'éclair de Zeus, la hache ni les barbelés) : cadence ×2, dégâts ×2, chargeur ×2,
## rechargement 2× plus rapide (la défense ne change pas). Cryo : dégâts ×2 et statuts de glace
## posés 2× plus vite ; onde de choc : dégâts ×2 et rechargement 2× plus court ;
## précision : dégâts ×2 et réarmement 2× plus court.
const GOD_ITEMS := ["pistol", "rifle", "cryo", "shock", "sniper"]
const GOD_COST := {"magic_wood": 5, "magic_stone": 5, "magic_cloud": 5}
const GOD_NAMES := {"pistol": "PISTOLET DE DIEU", "rifle": "FUSIL DE DIEU", "cryo": "CANON CRYO DE DIEU",
	"shock": "ONDE DE CHOC DE DIEU", "sniper": "FUSIL DE PRÉCISION DE DIEU"}
const GOD_MULT := 2.0


## Toutes les branches de l'arme sont-elles au maximum ?
static func all_maxed(state: Dictionary, item: String) -> bool:
	for b in ITEMS[item]["branches"]:
		if state[item][b[0]] < max_level(item, b[0]):
			return false
	return true


static func cost(item: String, branch: String, level: int) -> Dictionary:
	# level = niveau visé (1..max)
	if item == "zeus":
		return ZEUS_COSTS[level - 1].duplicate()
	if item == "sniper":
		var sc := {}
		for k in SNIPER_COSTS:
			var v: int = SNIPER_COSTS[k][level - 1]
			if v > 0:
				sc[k] = v
		if level == MAX_LEVEL:
			sc["big_bone"] = 1
		return sc
	if item == "shock":
		var c := {}
		for k in SHOCK_COSTS[branch]:
			var v: int = SHOCK_COSTS[branch][k][level - 1]
			if v > 0:
				c[k] = v
		if level == SHOCK_LEVELS[branch]:
			c["big_bone"] = 1
		return c
	if item == "axe":
		return {branch: AXE_COSTS[level - 1]}   # "wood" ou "stone"
	if item == "cryo":
		return CRYO_COSTS[level - 1]
	return GEAR_COSTS[level - 1]


static func cost_text(c: Dictionary) -> String:
	var parts: Array[String] = []
	if c.has("wood"):
		parts.append("%d bois" % c["wood"])
	if c.has("stone"):
		parts.append("%d pierre" % c["stone"])
	if c.has("coins"):
		parts.append("%d pièces" % c["coins"])
	if c.has("bone"):
		parts.append("%d os" % c["bone"])
	if c.has("magic_wood"):
		parts.append("%d bois magique" % c["magic_wood"])
	if c.has("magic_stone"):
		parts.append("%d pierre magique" % c["magic_stone"])
	if c.has("magic_cloud"):
		parts.append("%d nuage magique" % c["magic_cloud"])
	if c.has("arrow_bone"):
		parts.append("%d os en flèche" % c["arrow_bone"])
	if c.has("big_bone"):
		parts.append("%d os imposant" % c["big_bone"])
	return " + ".join(parts)


# ------------------------------------------------------------------ effets

static func fire_interval_mult(lvl: int) -> float:
	return 1.0 - 0.06 * lvl          # niveau 8 : tir ~2× plus rapide


static func damage_mult(lvl: int) -> float:
	return 1.0 + 0.12 * lvl          # niveau 8 : ×1,96


static func mag_size(base: int, lvl: int) -> int:
	return base + int(round(base * 0.15 * lvl))   # niveau 8 : ×2,2


static func reload_mult(lvl: int) -> float:
	return 1.0 - 0.07 * lvl          # niveau 8 : rechargement 44 % plus court


static func defense(lvl: int) -> float:
	return 0.05 * lvl                # niveau 8 : -40 % de dégâts subis


static func harvest_mult(lvl: int) -> float:
	return 1.0 + 0.375 * lvl         # niveau 8 : ×4 ressources par coup


static func wire_slow(lvl: int) -> float:
	return maxf(0.80 - 0.025 * lvl, 0.60)   # vitesse restante des squelettes : 80 % → 60 %


static func wire_dps(lvl: int) -> float:
	return 6.0 * (1.0 + 0.3 * lvl)


## Canon cryo : statut de glace de 0 à 10, gagné en touchant la cible (0,7 par tic de 0,1 s :
## ~1,5 s de rayon continu pour atteindre 10). Les effets ci-dessous sont les valeurs à 10 statuts.
const CRYO_STACKS_PER_TICK := 1.05   # statuts appliqués encore 1,5× plus vite
const CRYO_BASE_DPS := 420.0         # 420 dégâts/s de base, 1600 au niveau 8 (hors vulnérabilité et variante de Dieu)


## Ralentissement à 10 statuts : 30 % → 40 %
static func cryo_max_slow(lvl: int) -> float:
	return 0.30 + 0.0125 * lvl


## Dégâts du rayon : 420 / s → 1600 / s (avant vulnérabilité)
static func cryo_damage_mult(lvl: int) -> float:
	return 1.0 + (1600.0 / CRYO_BASE_DPS - 1.0) / 8.0 * lvl


## Vulnérabilité à 10 statuts : +10 % → +40 %
static func cryo_max_vuln(lvl: int) -> float:
	return 0.30 + (0.70 / 8.0) * lvl     # à 10 statuts : +30 % de dégâts subis, +100 % au niveau 8


## Durée d'un statut (on en perd un à chaque fois) : 1 s → 3 s
static func cryo_stack_time(lvl: int) -> float:
	return 1.0 + 0.25 * lvl


## Texte de l'effet d'une branche à un niveau donné (pour l'interface).
static func effect_text(item: String, branch: String, lvl: int, base_mag := 12) -> String:
	if item == "zeus":
		match branch:
			"targets": return "%d cibles" % ZEUS_TARGETS[lvl]
			"damage": return "%d dégâts" % int(ZEUS_DAMAGE[lvl])
			"boost": return "+%d %% de dégâts" % int(round(ZEUS_BOOST[lvl] * 100.0))
			"duration": return "%.1f s" % ZEUS_DURATION[lvl]
	if item == "sniper":
		match branch:
			"cooldown":
				return "%.1f s entre deux tirs" % sniper_cooldown(lvl)
			"damage":
				return "%d dégâts" % int(sniper_damage(lvl))
			"headshot":
				return "tête ×%.2f" % sniper_headshot(lvl)
	if item == "shock":
		match branch:
			"damage":
				return "%d dégâts" % int(shock_damage(lvl))
			"cooldown":
				return "%.1f s entre deux tirs" % shock_cooldown(lvl)
			"range":
				return "portée %d m" % int(shock_range(lvl))
	if item == "cryo":
		match branch:
			"slow":
				return "ralentissement max %.1f %%" % (cryo_max_slow(lvl) * 100.0)
			"damage":
				return "%.1f dégâts / s" % (CRYO_BASE_DPS * cryo_damage_mult(lvl))
			"vuln":
				return "vulnérabilité max +%.1f %%" % (cryo_max_vuln(lvl) * 100.0)
			"duration":
				return "1 statut perdu / %.2f s" % cryo_stack_time(lvl)
	match branch:
		"rate":
			return "+%d %% de cadence" % int(round((1.0 / fire_interval_mult(lvl) - 1.0) * 100.0))
		"damage":
			if item == "wire":
				return "%.0f PV/s" % wire_dps(lvl)
			return "+%d %% de dégâts" % int(round((damage_mult(lvl) - 1.0) * 100.0))
		"mag":
			return "%d balles" % mag_size(base_mag, lvl)
		"defense":
			return "-%d %% de dégâts subis" % int(round(defense(lvl) * 100.0))
		"reload":
			return "rechargement -%d %%" % int(round((1.0 - reload_mult(lvl)) * 100.0))
		"wood", "stone":
			var t := "×%.2f par coup" % harvest_mult(lvl)
			if branch == "wood" and lvl == STONE_UNLOCK_LEVEL:
				t += " + DÉBLOQUE LA PIERRE"
			return t
		"slow":
			return "vitesse réduite à %d %%" % int(round(wire_slow(lvl) * 100.0))
	return ""
