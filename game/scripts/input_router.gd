extends Node
## Aiguille les entrées vers le bon joueur : menus de chaque joueur, pause, et arrivée du joueur 2
## (Start sur une manette libre, ou Entrée si le joueur 1 joue à la manette).
## Toujours actif, même quand le jeu est en pause.

var main


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Joueur à qui appartient l'évènement (selon son périphérique), ou -1.
func owner_of(ev: InputEvent) -> int:
	for p in main.players:
		if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventMouseMotion:
			if p.kbm:
				return p.index
		elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			if p.pad == -2 or p.pad == ev.device:
				return p.index
	return -1


func _unhandled_input(ev: InputEvent) -> void:
	if main == null or not is_inside_tree():
		return
	# on garde la vue : un bouton « Menu principal » peut nous retirer de l'arbre pendant le traitement
	var vp := get_viewport()
	# arrivée du joueur 2
	if main.players.size() == 1 and main.state != "lost" and main.state != "won" and not get_tree().paused:
		if main.try_join(ev):
			vp.set_input_as_handled()
			return
	var idx := owner_of(ev)
	# manette encore libre : on la donne au joueur qui n'en a pas (le joueur 1 en priorité)
	if idx < 0 and ev is InputEventJoypadButton and ev.pressed:
		for p in main.players:
			if p.pad == -1:
				main.assign_pad(p.index, ev.device)
				vp.set_input_as_handled()
				return
	if idx < 0:
		if main.players.size() > 1 and (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
			vp.set_input_as_handled()   # manette non attribuée : ignorée
		return
	var hud = main.huds[idx]
	if hud.handle_input(ev):
		vp.set_input_as_handled()
		return
	# en pause, seul le joueur qui a mis pause pilote le menu ; les autres entrées sont absorbées
	if get_tree().paused:
		vp.set_input_as_handled()
