extends RefCounted
## Logique commune des cibles de récolte (arbres et rochers).
## Bonus final × (1 + cibles touchées / cibles possibles) : toutes touchées = bonus doublé.

const WeakSpot = preload("res://scripts/weak_spot.gd")
const START_RADIUS := 0.32
const SHRINK := 0.85
const MIN_RADIUS := 0.13

var spot: Node3D = null
var shown := 0
var hits := 0
var swings := 0     # coups de hache reçus (le 1er fait apparaître la 1re cible)
var radius := START_RADIUS


## À appeler à chaque coup de hache, avec le point d'impact. Renvoie vrai si la cible est touchée.
func register_hit(hit_pos: Vector3) -> bool:
	swings += 1
	if spot and is_instance_valid(spot) and hit_pos != Vector3.INF and spot.is_hit(hit_pos):
		hits += 1
		spot.pop()
		spot = null
		Sfx.play_3d("headshot", hit_pos, 2.0, 1.2)
		return true
	return false


## Fait apparaître une nouvelle cible (plus petite) si aucune n'est active.
func ensure_spot(parent: Node3D, pos: Vector3, normal: Vector3) -> void:
	if spot and is_instance_valid(spot):
		return
	spot = WeakSpot.new()
	parent.add_child(spot)
	spot.setup(pos, normal, radius)
	shown += 1
	radius = maxf(radius * SHRINK, MIN_RADIUS)


## Part des cibles touchées parmi toutes celles qu'on aurait pu toucher
## (chaque coup après le premier est une occasion).
func ratio() -> float:
	return clampf(float(hits) / float(swings - 1), 0.0, 1.0) if swings > 1 else 0.0


func clear() -> void:
	if spot and is_instance_valid(spot):
		spot.queue_free()
	spot = null
