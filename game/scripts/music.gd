extends Node
## Musique de fond (autoload « Music »).
## Dépose tes fichiers dans game/assets/music/ avec ces noms (mp3, ogg ou wav) :
##   menu          → menu principal
##   game          → forêt : exploration / préparation / pauses entre vagues
##   battle        → forêt : pendant les vagues
##   volcano       → zone volcanique : exploration / préparation / pauses   (sinon game)
##   volcano_battle→ zone volcanique : vagues                               (sinon battle)
##   volcano_boss  → combat contre le titan de lave                          (sinon boss, puis battle)
##   sky           → île des nuages : exploration / préparation / pauses    (sinon game)
##   sky_battle    → île des nuages : vagues                                (sinon battle)
##   sky_boss      → combat contre le colosse des nuées                      (sinon boss, puis battle)
##   endless       → défense sans fin                                        (sinon sky_battle, puis battle)
## Un fichier absent = on prend le suivant de la liste ; s'il n'y en a aucun : silence (aucune erreur).
## Les morceaux bouclent et s'enchaînent en fondu.

const DIR := "res://assets/music/"
const EXTS := ["ogg", "mp3", "wav"]
const FADE := 2.0
const VOLUME_DB := -8.0

var _players: Array[AudioStreamPlayer] = []
var _cur := 0
var _track := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la musique continue en pause
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## fallback : morceau joué si le fichier du premier n'existe pas (ex. « boss » → « battle »).
func play(track: String, fallback := "") -> void:
	if track == _track:
		return
	_track = track
	var stream := _load(track)
	if stream == null and fallback != "":
		stream = _load(fallback)
	var old := _players[_cur]
	_cur = 1 - _cur
	var nxt := _players[_cur]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.tween_callback(old.stop)
	if stream != null:
		nxt.stream = stream
		nxt.volume_db = -40.0
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", VOLUME_DB, FADE)


## Joue le premier morceau de la liste dont le fichier existe (ex. ["volcano_battle", "battle"]).
func play_any(tracks: Array) -> void:
	for t in tracks:
		if _load(t) != null:
			play(t)
			return
	play(tracks[0] if tracks.size() > 0 else "")


## Morceau d'un moment de jeu (« game », « battle », « boss ») pour une région (« », « volcano », « sky »).
func play_region(kind: String, region: String) -> void:
	var list := []
	if region != "":
		list.append(region if kind == "game" else region + "_" + kind)
	list.append(kind)
	if kind == "boss":
		list.append("battle")
	play_any(list)


func stop() -> void:
	play("")


func _load(track: String) -> AudioStream:
	if track == "":
		return null
	if _cache.has(track):
		return _cache[track]
	var s: AudioStream = null
	for ext in EXTS:
		var path: String = DIR + track + "." + ext
		if ResourceLoader.exists(path):
			s = load(path)   # fichier importé par l'éditeur Godot
		elif FileAccess.file_exists(path):
			s = _load_raw(path, ext)   # fichier pas encore importé
		if s != null:
			break
	if s != null:
		if "loop" in s:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[track] = s
	return s


func _load_raw(path: String, ext: String) -> AudioStream:
	match ext:
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(path)
			return m
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return null
