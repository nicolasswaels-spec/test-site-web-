extends RefCounted
## Relaie les messages généraux (vagues, sphère, victoire…) à l'interface de chaque joueur.

var huds: Array = []


func set_wave(title: String, sub: String) -> void:
	for h in huds: h.set_wave(title, sub)


func set_orb(hp: float, max_hp: float, title := "SPHÈRE") -> void:
	for h in huds: h.set_orb(hp, max_hp, title)


func set_alert(text: String) -> void:
	for h in huds: h.set_alert(text)


func show_center(title: String, sub: String, duration := 2.5) -> void:
	for h in huds: h.show_center(title, sub, duration)


func show_notice(text: String, duration := 6.0) -> void:
	for h in huds: h.show_notice(text, duration)


func flash_message(text: String) -> void:
	for h in huds: h.flash_message(text)


func show_end(title: String, sub: String) -> void:
	for h in huds: h.show_end(title, sub)


## Les fenêtres de confirmation ne s'affichent que chez le joueur 1.
func confirm(title: String, text: String, on_yes: Callable) -> void:
	if not huds.is_empty():
		huds[0].confirm(title, text, on_yes)
