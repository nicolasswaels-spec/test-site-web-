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


static func cost(item: String, branch: String, level: int) -> Dictionary:
	# level = niveau visé (1..8)
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


## Canon cryo : statut de glace de 0 à 10, gagné en touchant la cible (0,35 par tic de 0,1 s :
## ~3 s de rayon continu pour atteindre 10). Les effets ci-dessous sont les valeurs à 10 statuts.
const CRYO_STACKS_PER_TICK := 0.35
const CRYO_BASE_DPS := 20.0


## Ralentissement à 10 statuts : 30 % → 40 %
static func cryo_max_slow(lvl: int) -> float:
	return 0.30 + 0.0125 * lvl


## Dégâts du rayon : 20 / s → 35 / s
static func cryo_damage_mult(lvl: int) -> float:
	return 1.0 + 0.09375 * lvl


## Vulnérabilité à 10 statuts : +10 % → +30 %
static func cryo_max_vuln(lvl: int) -> float:
	return 0.10 + 0.025 * lvl


## Durée d'un statut (on en perd un à chaque fois) : 1 s → 3 s
static func cryo_stack_time(lvl: int) -> float:
	return 1.0 + 0.25 * lvl


## Texte de l'effet d'une branche à un niveau donné (pour l'interface).
static func effect_text(item: String, branch: String, lvl: int, base_mag := 12) -> String:
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
			return "×%.2f par coup" % harvest_mult(lvl)
		"slow":
			return "vitesse réduite à %d %%" % int(round(wire_slow(lvl) * 100.0))
	return ""
