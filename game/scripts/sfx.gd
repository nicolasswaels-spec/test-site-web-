extends Node
## Sons générés procéduralement (aucun fichier audio externe nécessaire).

const RATE := 22050
var streams := {}
var pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	streams["shot"] = _shot()
	streams["chop"] = _thud(150.0, 0.22, 0.55)
	streams["thud"] = _thud(90.0, 0.15, 0.7)
	streams["hurt"] = _thud(55.0, 0.25, 0.9)
	streams["swing"] = _whoosh()
	streams["hit"] = _tone(1500.0, 0.05, 0.45)
	streams["headshot"] = _tone(2300.0, 0.09, 0.55)
	streams["empty"] = _tone(900.0, 0.03, 0.3)
	streams["reload"] = _clicks()
	streams["build"] = _sweep(450.0, 950.0, 0.1)
	streams["equip"] = _sweep(300.0, 550.0, 0.05)
	streams["break"] = _noise_burst(0.35)
	streams["groan"] = _groan(0.9, 85.0)
	streams["zdie"] = _groan(0.55, 60.0)
	streams["orb_hit"] = _tone(210.0, 0.2, 0.5)
	streams["horn"] = _horn()
	streams["win"] = _arpeggio([523.0, 659.0, 784.0, 1046.0])
	streams["lose"] = _arpeggio([392.0, 330.0, 262.0, 196.0])
	for i in 18:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)


func play(sound: String, db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var chosen: AudioStreamPlayer = pool[0]
	for p in pool:
		if not p.playing:
			chosen = p
			break
	chosen.stream = streams[sound]
	chosen.volume_db = db
	chosen.pitch_scale = pitch * randf_range(0.94, 1.06)
	chosen.play()


func play_3d(sound: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or not streams.has(sound):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.9, 1.1)
	p.unit_size = 10.0
	p.max_distance = 70.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# ---------------------------------------------------------------- synthèse

func _make(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _buf(duration: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(duration * RATE))
	return s


func _shot() -> AudioStreamWAV:
	var s := _buf(0.2)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.4)
		s[i] = lp * exp(-t * 20.0) * 0.9 + sin(TAU * 105.0 * t) * exp(-t * 30.0) * 0.8
	return _make(s)


func _thud(freq: float, duration: float, noise_amt: float) -> AudioStreamWAV:
	var s := _buf(duration)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.25)
		var f := freq * (1.0 - t * 1.5)
		s[i] = (sin(TAU * f * t) * 0.8 + lp * noise_amt) * exp(-t * 18.0)
	return _make(s)


func _whoosh() -> AudioStreamWAV:
	var s := _buf(0.22)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.08 + t * 0.6)
		s[i] = lp * sin(PI * t / 0.22) * 0.7
	return _make(s)


func _tone(freq: float, duration: float, amp: float) -> AudioStreamWAV:
	var s := _buf(duration)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = sin(TAU * freq * t) * amp * exp(-t * 30.0)
	return _make(s)


func _sweep(f0: float, f1: float, duration: float) -> AudioStreamWAV:
	var s := _buf(duration)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / duration) / RATE
		s[i] = (1.0 if sin(phase) > 0.0 else -1.0) * 0.25 * (1.0 - t / duration)
	return _make(s)


func _clicks() -> AudioStreamWAV:
	var s := _buf(0.5)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.32]:
			var dt: float = t - c
			if dt >= 0.0:
				v += (randf() * 2.0 - 1.0) * exp(-dt * 120.0) * 0.8 + sin(TAU * 1800.0 * dt) * exp(-dt * 80.0) * 0.3
		s[i] = v
	return _make(s)


func _noise_burst(duration: float) -> AudioStreamWAV:
	var s := _buf(duration)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.2)
		s[i] = lp * exp(-t * 9.0) + sin(TAU * 70.0 * t) * exp(-t * 15.0) * 0.5
	return _make(s)


func _groan(duration: float, freq: float) -> AudioStreamWAV:
	var s := _buf(duration)
	var phase := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := freq * (1.0 + 0.15 * sin(TAU * 5.0 * t)) * (1.0 - 0.3 * t / duration)
		phase += f / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		lp = lerpf(lp, saw, 0.15)
		s[i] = lp * sin(PI * t / duration) * 0.6
	return _make(s)


func _horn() -> AudioStreamWAV:
	var s := _buf(1.2)
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(t * 8.0, 1.0) * exp(-t * 1.6)
		var v := 0.0
		for f in [110.0, 165.0, 220.0]:
			v += sin(TAU * f * t + sin(TAU * 3.0 * t) * 0.3)
		s[i] = v * 0.22 * env
	return _make(s)


func _arpeggio(notes: Array) -> AudioStreamWAV:
	var step := 0.16
	var s := _buf(step * notes.size() + 0.5)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for n in notes.size():
			var dt: float = t - n * step
			if dt >= 0.0:
				v += sin(TAU * float(notes[n]) * dt) * exp(-dt * 3.0) * 0.25
		s[i] = v
	return _make(s)
