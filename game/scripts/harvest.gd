extends RefCounted
## Logique commune des cibles de récolte (arbres et rochers).
## Au 1er coup de hache, 3 cibles apparaissent en même temps sur la ressource.
## Coup sur une cible : +100 % de ressources sur ce coup (la cible disparaît).
## Ressource terminée : gain final +80 % par cible touchée (3 cibles = +240 %, soit ×3,4).

const WeakSpot = preload("res://scripts/weak_spot.gd")
const SPOT_COUNT := 3
const SPOT_RADIUS := 0.26
const HIT_BONUS := 2.0         # +100 % sur un coup qui touche une cible
const FINAL_PER_HIT := 0.8     # +80 % sur le gain final par cible touchée

var spots: Array = []
var hits := 0
var spawned := false


## À appeler à chaque coup de hache, avec le point d'impact. Renvoie vrai si une cible est touchée.
func register_hit(hit_pos: Vector3) -> bool:
	if hit_pos == Vector3.INF:
		return false
	for s in spots:
		if is_instance_valid(s) and s.is_hit(hit_pos):
			hits += 1
			spots.erase(s)
			s.pop()
			Sfx.play_3d("headshot", hit_pos, 2.0, 1.2)
			return true
	return false


## Vrai tant que les cibles n'ont pas encore été posées (1er coup).
func needs_spots() -> bool:
	return not spawned


## Pose une cible (pos sur la surface, normal vers l'extérieur).
func add_spot(parent: Node3D, pos: Vector3, normal: Vector3) -> void:
	spawned = true
	var s := WeakSpot.new()
	parent.add_child(s)
	s.setup(pos, normal, SPOT_RADIUS)
	spots.append(s)


func final_mult() -> float:
	return 1.0 + FINAL_PER_HIT * hits


func clear() -> void:
	for s in spots:
		if is_instance_valid(s):
			s.queue_free()
	spots.clear()
