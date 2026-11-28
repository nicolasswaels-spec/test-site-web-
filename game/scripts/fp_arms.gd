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
	# index presque tendu le long de la gâchette, les autres doigts enroulés autour de la poignée
	"pistol": {"index": 0.18, "fingers": 0.72, "thumb": 0.45, "half": 0.03},
	# main d'appui sous le garde-main : doigts peu pliés (ils remontent sur le côté sans traverser)
	"support": {"index": 0.3, "fingers": 0.32, "thumb": 0.2, "half": 0.05},
	"fist": {"index": 0.85, "fingers": 0.9, "thumb": 0.55, "half": 0.03},
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
	m.scale = Vector3.ONE * 0.92      # mains un peu plus petites (elles sont tout près de la caméra)
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
				chains.append([fn, ids, skel.find_bone(P + side + "Hand" + fn + "4")])
		r["chains"] = chains
		rig[side] = r


## Bras inutilisé (arme à une main) : replié à zéro, invisible.
func hide_arm(side: String) -> void:
	var r: Dictionary = rig[side]
	skel.set_bone_pose_scale(r["Arm"], Vector3.ONE * 0.001)


## Applique les poses posées cette image au maillage tout de suite (avant le rendu de cette image),
## sinon la peau suit avec une image de retard sur l'arme.
func flush() -> void:
	skel.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)


const MAX_WRIST := 38.0       # flexion maximale du poignet (degrés) : au-delà, la main suit l'avant-bras


## Pose un bras. Tout en coordonnées monde :
## grip = centre de la poignée, fingers = direction poignet -> doigts, palm = de la paume vers la
## poignée, out = direction (depuis la main) où file le coude puis l'épaule (hors de l'écran).
## fit : calage mesuré sur l'arme (voir fit()) : {"half": distance poignée -> poignet, "curl": {doigt: pli}}.
func solve(side: String, grip: Vector3, fingers: Vector3, palm: Vector3, out: Vector3, grip_kind: String, fit := {}) -> void:
	var r: Dictionary = rig[side]
	skel.set_bone_pose_scale(r["Arm"], Vector3.ONE)
	var to_sk := skel.global_transform.affine_inverse()
	var sc := skel.global_transform.basis.get_scale().x
	var F := (to_sk.basis * fingers).normalized()
	var Pm := to_sk.basis * palm
	Pm = (Pm - F * Pm.dot(F)).normalized()
	var o := (to_sk.basis * out).normalized()
	var G := to_sk * grip
	var g: Dictionary = GRIPS.get(grip_kind, GRIPS["pistol"])
	var half: float = fit.get("half", g.get("half", GRIP_HALF)) / sc
	var l1: float = r["l1"]
	var l2: float = r["l2"]
	var down := to_sk.basis * Vector3.DOWN
	var W := Vector3.ZERO
	var S := Vector3.ZERO
	var E := Vector3.ZERO
	# deux passes : on place le bras, puis si le poignet est trop plié, la main s'aligne en partie
	# sur l'avant-bras (elle tourne autour de la poignée, la paume reste contre)
	for it in 2:
		W = G - Pm * half - F * r["palm"]
		S = W + o * (l1 + l2) * REACH
		var d: float = S.distance_to(W)
		var dir: Vector3 = (W - S) / d
		var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
		var pole: Vector3 = -Pm + o * 0.3 + down * 0.6
		var perp: Vector3 = (pole - dir * pole.dot(dir)).normalized()
		E = S + dir * a + perp * h
		var fa := (W - E).normalized()
		# flexion du poignet = angle entre l'avant-bras et la main (composante hors de la paume)
		var fa_p := (fa - Pm * fa.dot(Pm)).normalized()
		var ang := rad_to_deg(F.angle_to(fa_p))
		if it == 1 or ang <= MAX_WRIST:
			break
		F = fa_p.slerp(F, MAX_WRIST / ang).normalized()
	_aim(r["Arm"], S, E)
	_aim(r["ForeArm"], E, W)
	# main : repère au repos (F, P) amené sur (F, Pm)
	var rest_m := Basis(r["F"], r["P"], (r["F"] as Vector3).cross(r["P"]))
	var want_m := Basis(F, Pm, F.cross(Pm))
	var hb := want_m * rest_m.inverse() * skel.get_bone_global_rest(r["Hand"]).basis
	_set_global(r["Hand"], Transform3D(hb.orthonormalized(), W))
	var curls: Dictionary = fit.get("curl", {})
	for ch in r["chains"]:
		var fn: String = ch[0]
		var amount: float = curls.get(fn, g["thumb"] if fn == "Thumb" else (g["index"] if fn == "Index" else g["fingers"]))
		_curl_chain(r, ch, amount)


## Calage de la main sur l'arme, mesuré une fois par arme (les mains sont fixées à l'arme) :
## - la paume est posée sur la surface réelle de la poignée (au lieu d'une épaisseur supposée) ;
## - chaque doigt se referme jusqu'à toucher l'arme, sans la traverser (test de contact entre les
##   phalanges et les triangles de l'arme proches de la main).
func fit(side: String, grip: Vector3, fingers: Vector3, palm: Vector3, out: Vector3, grip_kind: String, meshes: Array) -> Dictionary:
	var r: Dictionary = rig[side]
	var g: Dictionary = GRIPS.get(grip_kind, GRIPS["pistol"])
	var to_sk := skel.global_transform.affine_inverse()
	var sc := skel.global_transform.basis.get_scale().x
	var G := to_sk * grip
	var Pm := (to_sk.basis * palm).normalized()
	# triangles de l'arme proches de la poignée, dans le repère du squelette
	var tris := PackedVector3Array()
	var rad := 0.16 / sc
	for mi in meshes:
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var t: Transform3D = to_sk * (mi as MeshInstance3D).global_transform
		var f := m.get_faces()
		for i in range(0, f.size(), 3):
			var A := t * f[i]
			var B := t * f[i + 1]
			var C := t * f[i + 2]
			if ((A + B + C) / 3.0).distance_to(G) < rad:
				tris.append(A)
				tris.append(B)
				tris.append(C)
	var out_fit := {"curl": {}}
	# grille d'occupation (cases de 6 mm) : sommets, milieux d'arêtes et centres des triangles de
	# l'arme ; sert à tester l'épaisseur des doigts et de la paume (pas seulement leur axe)
	cell = 0.006 / sc
	occ = {}
	for i in range(0, tris.size(), 3):
		var A := tris[i]
		var B := tris[i + 1]
		var C := tris[i + 2]
		for q in [A, B, C, (A + B) * 0.5, (B + C) * 0.5, (A + C) * 0.5, (A + B + C) / 3.0]:
			occ[Vector3i((q / cell).floor())] = true
	# paume : surface de l'arme rencontrée en venant du côté de la paume
	var from := G - Pm * (0.2 / sc)
	var best := INF
	for i in range(0, tris.size(), 3):
		var hit = Geometry3D.segment_intersects_triangle(from, G + Pm * (0.02 / sc), tris[i], tris[i + 1], tris[i + 2])
		if hit != null:
			best = minf(best, from.distance_to(hit))
	var half := 0.03
	if best < INF:
		half = clampf((0.2 / sc - best) * sc + 0.014, 0.012, 0.09)   # surface + demi-épaisseur de la main
	# on écarte la paume tant qu'elle (poignet, base des doigts) touche l'arme
	for k in 12:
		out_fit["half"] = half
		solve(side, grip, fingers, palm, out, grip_kind, {"half": half, "curl": {"Thumb": 0.0, "Index": 0.0, "Middle": 0.0, "Ring": 0.0, "Pinky": 0.0}})
		var pts := PackedVector3Array([skel.get_bone_global_pose(r["Hand"]).origin])
		for ch in r["chains"]:
			if ch[0] == "Middle" or ch[0] == "Index":
				pts.append(skel.get_bone_global_pose(ch[1][0]).origin)
		if not _near(pts, 1) or half >= 0.07:
			break
		half += 0.006
	# doigts : pli maximal sans traverser ni s'enfoncer
	for ch in r["chains"]:
		var fn: String = ch[0]
		var hi := 1.0 if fn != "Thumb" else 0.85
		var lo := 0.0
		if _chain_hits(r, ch, hi, tris):
			for k in 6:
				var mid := (lo + hi) * 0.5
				if _chain_hits(r, ch, mid, tris):
					hi = mid
				else:
					lo = mid
			hi = lo
		var want: float = hi
		if fn == "Index" and grip_kind == "pistol":
			want = minf(hi, g["index"])     # index tendu sur la gâchette
		out_fit["curl"][fn] = want
		_curl_chain(r, ch, want)
	return out_fit


var cell := 0.006
var occ := {}


## Vrai si un des points est à moins de ~reach cases d'une surface de l'arme.
func _near(pts: PackedVector3Array, reach: int) -> bool:
	for p in pts:
		var c := Vector3i((p / cell).floor())
		for x in range(-reach, reach + 1):
			for y in range(-reach, reach + 1):
				for z in range(-reach, reach + 1):
					if occ.has(c + Vector3i(x, y, z)):
						return true
	return false


func _chain_hits(r: Dictionary, ch: Array, amount: float, tris: PackedVector3Array) -> bool:
	_curl_chain(r, ch, amount)
	var pts := PackedVector3Array()
	for bi in ch[1]:
		pts.append(skel.get_bone_global_pose(bi).origin)
	if ch[2] >= 0:
		pts.append(skel.get_bone_global_pose(ch[2]).origin)
	var samples := PackedVector3Array()
	for k in range(pts.size() - 1):
		for t in [0.5, 1.0]:
			samples.append(pts[k].lerp(pts[k + 1], t))
	if _near(samples, 1):
		return true
	for k in range(pts.size() - 1):
		for i in range(0, tris.size(), 3):
			if Geometry3D.segment_intersects_triangle(pts[k], pts[k + 1], tris[i], tris[i + 1], tris[i + 2]) != null:
				return true
	return false


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


## Doigt : chaque phalange tourne vers la paume (axe = direction de l'os × normale de la paume,
## pris dans la pose de repos, donc valable quelle que soit l'orientation de la main).
func _curl_chain(r: Dictionary, ch: Array, amount: float) -> void:
	var angles := [65.0, 80.0, 55.0]
	var pn: Vector3 = r["P"]
	var fn: String = ch[0]
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
