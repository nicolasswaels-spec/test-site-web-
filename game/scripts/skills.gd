extends RefCounted
## Arbre de compétences du personnage : 3 branches (RÉCOLTE, ATTAQUE, DÉFENSE) de 9 compétences.
## Débloquer une compétence demande : la compétence parente, un prérequis lié à l'effet
## (ex. +10 % bois : avoir abattu 15 arbres) et 1 jeton de compétence.
## Jetons : 1 par vague terminée, 3 après le titan de lave.
##
## Chaque compétence : branche, position dans l'arbre (colonne 0-2, ligne 0-4), parent,
## nom, effet, statistique à atteindre (voir STAT_NAMES) et seuil.

const BRANCHES := [
	["farm", "RÉCOLTE", Color(0.35, 0.75, 0.35)],
	["attack", "ATTAQUE", Color(0.85, 0.32, 0.25)],
	["defense", "DÉFENSE", Color(0.3, 0.55, 0.95)],
]

const SKILLS := {
	# ---------------------------------------------------------------- récolte
	"F1": {"branch": "farm", "pos": Vector2(1, 0), "parent": "", "name": "BÛCHERON",
		"desc": "+10 % de bois récolté.", "stat": "trees", "need": 15},
	"F2": {"branch": "farm", "pos": Vector2(0, 1), "parent": "F1", "name": "TAILLEUR",
		"desc": "+10 % de pierre récoltée.", "stat": "rocks", "need": 10},
	"F3": {"branch": "farm", "pos": Vector2(2, 1), "parent": "F1", "name": "HACHE VIVE",
		"desc": "La hache frappe 20 % plus vite.", "stat": "targets", "need": 25},
	"F4": {"branch": "farm", "pos": Vector2(0, 2), "parent": "F2", "name": "ABONDANCE",
		"desc": "+15 % de bois et de pierre (en plus des autres bonus).", "stat": "harvested", "need": 5000},
	"F6": {"branch": "farm", "pos": Vector2(1, 2), "parent": "F2", "name": "FERRAILLEUR",
		"desc": "Ramasser une pièce : 25 % de chance d'en gagner une de plus.", "stat": "coins", "need": 30},
	"F5": {"branch": "farm", "pos": Vector2(2, 2), "parent": "F3", "name": "ŒIL DU FORESTIER",
		"desc": "Toucher une cible de récolte rapporte +50 % de plus sur ce coup.", "stat": "targets", "need": 75},
	"F7": {"branch": "farm", "pos": Vector2(0, 4), "parent": "F9", "name": "SÈVE MAGIQUE",
		"desc": "Arbre / rocher magique terminé : 50 % de chance d'un bois / d'une pierre magique en plus.", "stat": "magic", "need": 4},
	"F8": {"branch": "farm", "pos": Vector2(2, 3), "parent": "F5", "name": "ARCHITECTE",
		"desc": "Constructions et réparations 20 % moins chères (bois / pierre).", "stat": "built", "need": 150},
	"F9": {"branch": "farm", "pos": Vector2(0, 3), "parent": "F4", "name": "CHAROGNARD",
		"desc": "Ramasser des os : 25 % de chance d'en obtenir un de plus.", "stat": "bones", "need": 50},
	# ---------------------------------------------------------------- attaque
	"A1": {"branch": "attack", "pos": Vector2(1, 0), "parent": "", "name": "ENTRAÎNEMENT",
		"desc": "+5 % de dégâts avec toutes les armes.", "stat": "kills", "need": 50},
	"A2": {"branch": "attack", "pos": Vector2(0, 1), "parent": "A1", "name": "TIREUR",
		"desc": "+10 % de dégâts avec les armes à feu (pistolet, fusil, cryo).", "stat": "headshots", "need": 30},
	"A3": {"branch": "attack", "pos": Vector2(2, 1), "parent": "A1", "name": "BRAS DE FER",
		"desc": "+40 % de dégâts de hache contre les squelettes.", "stat": "kills_axe", "need": 15},
	"A4": {"branch": "attack", "pos": Vector2(0, 2), "parent": "A2", "name": "MAIN SÛRE",
		"desc": "Rechargement 25 % plus rapide.", "stat": "kills_gun", "need": 150},
	"A5": {"branch": "attack", "pos": Vector2(1, 2), "parent": "A2", "name": "TÊTE FROIDE",
		"desc": "Tirs à la tête ×2,5 au lieu de ×2.", "stat": "headshots", "need": 100},
	"A6": {"branch": "attack", "pos": Vector2(2, 2), "parent": "A3", "name": "CHOC AMPLIFIÉ",
		"desc": "Onde de choc : +2 m de portée et +15 % de dégâts.", "stat": "kills_shock", "need": 30},
	"A7": {"branch": "attack", "pos": Vector2(0, 3), "parent": "A4", "name": "BOULE DE FEU",
		"desc": "Compétence (C / croix gauche hors construction) : boule de feu, 60 dégâts puis brûlure 5 s (12 dégâts/s). Recharge 12 s.", "stat": "boss_kills", "need": 3},
	"A8": {"branch": "attack", "pos": Vector2(2, 3), "parent": "A5", "name": "EXÉCUTION",
		"desc": "+30 % de dégâts contre les ennemis sous 30 % de PV.", "stat": "kills", "need": 300},
	"A9": {"branch": "attack", "pos": Vector2(0, 4), "parent": "A7", "name": "FOURNAISE",
		"desc": "La boule de feu explose (4 m autour de l'impact) et se recharge en 8 s.", "stat": "kills_fire", "need": 20},
	# ---------------------------------------------------------------- défense
	"D1": {"branch": "defense", "pos": Vector2(1, 0), "parent": "", "name": "ENDURANCE",
		"desc": "+20 PV maximum.", "stat": "waves", "need": 3},
	"D2": {"branch": "defense", "pos": Vector2(0, 1), "parent": "D1", "name": "PEAU DURE",
		"desc": "10 % de dégâts subis en moins.", "stat": "dmg_taken", "need": 300},
	"D3": {"branch": "defense", "pos": Vector2(2, 1), "parent": "D1", "name": "AGILITÉ",
		"desc": "+10 % de vitesse de déplacement.", "stat": "distance", "need": 2000},
	"D4": {"branch": "defense", "pos": Vector2(0, 2), "parent": "D2", "name": "BOUCLIER",
		"desc": "Bouclier de 10 PV : il encaisse les coups avant la vie et se recharge en 10 s après 2 s sans être touché.", "stat": "dmg_taken", "need": 1000},
	"D5": {"branch": "defense", "pos": Vector2(1, 2), "parent": "D2", "name": "SECOND SOUFFLE",
		"desc": "Régénère 2 PV/s après 5 s sans être touché.", "stat": "waves", "need": 8},
	"D6": {"branch": "defense", "pos": Vector2(2, 2), "parent": "D3", "name": "ESQUIVE",
		"desc": "10 % de chance d'esquiver complètement un coup.", "stat": "distance", "need": 5000},
	"D7": {"branch": "defense", "pos": Vector2(0, 3), "parent": "D4", "name": "REMPART",
		"desc": "Le bouclier passe à 25 PV.", "stat": "shield_absorbed", "need": 150},
	"D8": {"branch": "defense", "pos": Vector2(2, 3), "parent": "D5", "name": "RENAISSANCE",
		"desc": "Revenir après une mort : 8 s d'invulnérabilité (au lieu de 5) et recul plus fort.", "stat": "revives", "need": 2},
	"D9": {"branch": "defense", "pos": Vector2(0, 4), "parent": "D7", "name": "VIE BONUS",
		"desc": "+1 vie (immédiatement).", "stat": "waves", "need": 20},
}

const STAT_NAMES := {
	"trees": "arbres abattus", "rocks": "rochers cassés", "targets": "cibles de récolte touchées",
	"harvested": "bois et pierre récoltés", "coins": "pièces ramassées", "magic": "ressources magiques obtenues",
	"built": "pièces construites", "bones": "os ramassés",
	"kills": "squelettes tués", "headshots": "tirs à la tête", "kills_axe": "squelettes tués à la hache",
	"kills_gun": "squelettes tués par balle", "kills_shock": "squelettes tués à l'onde de choc",
	"boss_kills": "boss tués", "kills_fire": "squelettes tués par le feu",
	"waves": "vagues survécues", "dmg_taken": "dégâts encaissés", "distance": "mètres parcourus",
	"shield_absorbed": "dégâts absorbés par le bouclier", "revives": "retours après une mort",
}


static func new_stats() -> Dictionary:
	var st := {}
	for k in STAT_NAMES:
		st[k] = 0.0
	return st
