extends Node3D
## Bras à la première personne : le voyageur riggé par Mixamo (bras extraits, squelette complet),
## posés chaque image par cinématique inverse à deux os (épaule -> coude -> poignet) sur les
## poignées de l'arme en main. Les mains prennent l'orientation voulue (direction des doigts,
## paume tournée vers la poignée) et les doigts se referment selon la prise.
## Un rechargement se fait en déplaçant simplement la cible d'une main (voir player.gd).

const MODEL := preload("res://assets/characters/fp_arms.glb")
const P := "mixamorig_"
const SIDES := ["Right", "Left"]
## Prises : courbure des chaînes de doigts (0 = tendu, 1 = poing). Avec le squelette Mixamo à
## 41 os, « index » plie les quatre doigts ensemble ; un squelette à 65 os sépare les doigts
## (Middle, Ring, Pinky prennent alors la valeur « fingers », l'index garde la sienne).
const GRIPS := {
	"pistol": {"index": 0.55, "fingers": 0.85, "thumb": 0.5},
	"support": {"index": 0.45, "fingers": 0.45, "thumb": 0.3},
	"fist": {"index": 0.9, "fingers": 0.95, "thumb": 0.6},
}
const GRIP_HALF := 0.022      # demi-épaisseur d'une poignée : la paume se pose contre, pas dedans
const REACH := 0.86           # distance épaule-poignet, en fraction de la longueur du bras
## Calques de rendu des bras (un par joueur, voir player.arms_layer) : les petites lumières des
## armes les excluent (sinon les gants prennent leur teinte), la caméra de l'autre joueur aussi.
const ALL_LAYERS := (1 << 12) | (1 << 13)
var layer := 1 << 12

var skel: Skeleton3D
var rig := {}                 # par côté : indices des os, longueurs, repère de la main au repos


func _ready() -> void:
	var m: Node3D = MODEL.instantiate()
	add_child(m)
	skel = m.find_children("*", "Skeleton3D", true, false)[0]
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).layers = layer
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var sm := (mi as MeshInstance3D).mesh.surface_get_material(i) as StandardMaterial3D
			if sm:
				sm.roughness_texture = null
				sm.roughness = 0.8
				sm.metallic = 0.0
	for side in SIDES:
		var r := {}
		for b in ["Arm", "ForeArm", "Hand", "HandIndex1", "HandThumb1"]:
			r[b] = skel.find_bone(P + side + b)
		var s := skel.get_bone_global_rest(r["Arm"]).origin
		var e := skel.get_bone_global_rest(r["ForeArm"]).origin
		var w := skel.get_bone_global_rest(r["Hand"]).origin
		r["l1"] = s.distance_to(e)
		r["l2"] = e.distance_to(w)
		# repère de la main au repos : doigts F, paume P (sens : vers le corps, pose A)
		var f := (skel.get_bone_global_rest(r["HandIndex1"]).origin - w).normalized()
		var t := skel.get_bone_global_rest(r["HandThumb1"]).origin - w
		var pn := f.cross(t).normalized()
		var hips := skel.get_bone_global_rest(skel.find_bone(P + "Hips")).origin
		if pn.dot(hips - w) < 0.0:   # paume tournée vers le corps (pose A) ou vers le bas (T-pose)
			pn = -pn
		pn = (pn - f * pn.dot(f)).normalized()
		r["F"] = f
		r["P"] = pn
		r["palm"] = skel.get_bone_global_rest(r["HandIndex1"]).origin.distance_to(w) * 0.55
		# chaînes de doigts présentes (41 os : Thumb, Index ; 65 os : + Middle, Ring, Pinky)
		var chains := []
		for fn in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
			var ids := []
			for j in 3:
				var bi := skel.find_bone(P + side + "Hand" + fn + str(j + 1))
				if bi >= 0:
					ids.append(bi)
			if ids.size() == 3:
				chains.append([fn, ids])
		r["chains"] = chains
		rig[side] = r


## Pose un bras. Tout en coordonnées monde :
## grip = centre de la poignée, fingers = direction poignet -> doigts, palm = de la paume vers la
## poignée, out = direction (depuis la main) où file le coude puis l'épaule (hors de l'écran).
## Bras inutilisé (arme à une main) : replié à zéro, invisible.
func hide_arm(side: String) -> void:
	var r: Dictionary = rig[side]
	skel.set_bone_pose_scale(r["Arm"], Vector3.ONE * 0.001)


func solve(side: String, grip: Vector3, fingers: Vector3, palm: Vector3, out: Vector3, grip_kind: String) -> void:
	var r: Dictionary = rig[side]
	skel.set_bone_pose_scale(r["Arm"], Vector3.ONE)
	var to_sk := skel.global_transform.affine_inverse()
	var sc := skel.global_transform.basis.get_scale().x
	var F := (to_sk.basis * fingers).normalized()
	var Pm := to_sk.basis * palm
	Pm = (Pm - F * Pm.dot(F)).normalized()
	var o := (to_sk.basis * out).normalized()
	var G := to_sk * grip
	# poignet : la paume posée contre la poignée, les doigts dépassent vers l'avant
	var W: Vector3 = G - Pm * (GRIP_HALF / sc) - F * r["palm"]
	var l1: float = r["l1"]
	var l2: float = r["l2"]
	var S: Vector3 = W + o * (l1 + l2) * REACH
	# coude : deux os, plié vers le bas / l'extérieur (direction o + un peu de -paume)
	var d: float = S.distance_to(W)
	var dir: Vector3 = (W - S) / d
	var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pole: Vector3 = -Pm + o * 0.3 + to_sk.basis * Vector3.DOWN * 0.6
	var perp: Vector3 = (pole - dir * pole.dot(dir)).normalized()
	var E: Vector3 = S + dir * a + perp * h
	_aim(r["Arm"], S, E)
	_aim(r["ForeArm"], E, W)
	# main : repère au repos (F, P) amené sur (F, Pm)
	var rest_m := Basis(r["F"], r["P"], (r["F"] as Vector3).cross(r["P"]))
	var want_m := Basis(F, Pm, F.cross(Pm))
	var hb := want_m * rest_m.inverse() * skel.get_bone_global_rest(r["Hand"]).basis
	_set_global(r["Hand"], Transform3D(hb.orthonormalized(), W))
	_curl(r, GRIPS.get(grip_kind, GRIPS["pistol"]))


## Oriente un os (axe Y = le long de l'os) de a vers b, origine en a.
func _aim(bi: int, a: Vector3, b: Vector3) -> void:
	var rest := skel.get_bone_global_rest(bi).basis
	var q := Quaternion(rest.y.normalized(), (b - a).normalized())
	_set_global(bi, Transform3D(Basis(q) * rest, a))


func _set_global(bi: int, g: Transform3D) -> void:
	var pi := skel.get_bone_parent(bi)
	var pg := skel.get_bone_global_pose(pi) if pi >= 0 else Transform3D()
	var l := pg.affine_inverse() * g
	skel.set_bone_pose_position(bi, l.origin)
	skel.set_bone_pose_rotation(bi, l.basis.get_rotation_quaternion())


## Doigts : chaque phalange tourne vers la paume (axe = direction de l'os × normale de la paume,
## pris dans la pose de repos, donc valable quelle que soit l'orientation de la main).
func _curl(r: Dictionary, g: Dictionary) -> void:
	var angles := [65.0, 80.0, 55.0]
	var pn: Vector3 = r["P"]
	for ch in r["chains"]:
		var fn: String = ch[0]
		var amount: float = g["thumb"] if fn == "Thumb" else (g["index"] if fn == "Index" else g["fingers"])
		var ids: Array = ch[1]
		for j in 3:
			var bi: int = ids[j]
			var gr := skel.get_bone_global_rest(bi)
			var nxt := skel.get_bone_global_rest(ids[j + 1]).origin if j < 2 else gr.origin + gr.basis.y
			var dir := (nxt - gr.origin).normalized()
			var axis := dir.cross(pn)
			if fn == "Thumb":
				axis = dir.cross(pn + (r["F"] as Vector3) * 0.3)
			if axis.length() < 0.01:
				continue
			var la := (gr.basis.inverse() * axis).normalized()
			var rest_q := skel.get_bone_rest(bi).basis.get_rotation_quaternion()
			skel.set_bone_pose_rotation(bi, rest_q * Quaternion(la, deg_to_rad(angles[j] * amount)))
			skel.set_bone_pose_position(bi, skel.get_bone_rest(bi).origin)
