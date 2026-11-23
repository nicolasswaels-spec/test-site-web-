extends RefCounted
## Arbres d'amélioration (données + effets). Les coûts sont ici pour être faciles à ajuster.

const MAX_LEVEL := 8

## Coûts des niveaux 1 à 8 pour les armes et les barbelés :
## 1-2 : bois · 3-4 : pierre · 5-6 : bois + pierre · 7-8 : bois + pierre + pièces
const GEAR_COSTS := [
	{"wood": 100},
	{"wood": 250},
	{"stone": 100},
	{"stone": 250},
	{"wood": 400, "stone": 200},
	{"wood": 700, "stone": 400},
	{"wood": 1000, "stone": 600, "coins": 10},
	{"wood": 1500, "stone": 900, "coins": 20},
]
## Hache : la branche « bois » ne coûte que du bois, la branche « pierre » que de la pierre.
const AXE_COSTS := [250, 450, 700, 950, 1250, 1600, 2000, 2500]

const ITEMS := {
	"pistol": {"name": "PISTOLET", "branches": [
		["rate", "Cadence de tir"], ["damage", "Dégâts par balle"], ["mag", "Chargeur"], ["reload", "Vitesse de rechargement"], ["defense", "Défense (arme en main)"]]},
	"rifle": {"name": "FUSIL D'ASSAUT", "branches": [
		["rate", "Cadence de tir"], ["damage", "Dégâts par balle"], ["mag", "Chargeur"], ["reload", "Vitesse de rechargement"], ["defense", "Défense (arme en main)"]]},
	"axe": {"name": "HACHE", "branches": [
		["wood", "Récolte de bois (payée en bois)"], ["stone", "Récolte de pierre (payée en pierre)"]]},
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
	return 1.0 + 0.25 * lvl          # niveau 8 : ×3 ressources par coup


static func wire_slow(lvl: int) -> float:
	return maxf(0.80 - 0.025 * lvl, 0.60)   # vitesse restante des squelettes : 80 % → 60 %


static func wire_dps(lvl: int) -> float:
	return 6.0 * (1.0 + 0.3 * lvl)


## Texte de l'effet d'une branche à un niveau donné (pour l'interface).
static func effect_text(item: String, branch: String, lvl: int, base_mag := 12) -> String:
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
