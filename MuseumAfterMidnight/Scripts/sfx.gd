class_name Sfx
extends RefCounted
## Procedural sound library (the Synty packs ship no audio). Every sound is synthesised once,
## cached, and played through the SFX or Ambience bus.

const RATE := 22050
static var _cache := {}
static var _rng := RandomNumberGenerator.new()

static func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	var peak := 0.001
	for v in s: peak = maxf(peak, absf(v))
	var norm := 0.95 / peak if peak > 0.95 else 1.0
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i] * norm, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

static func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * sec))
	return s

static func _n() -> float:
	return _rng.randf_range(-1.0, 1.0)

## Adds a decaying sine "resonance" (used for metal rings, thumps, knocks).
static func _ring(s: PackedFloat32Array, start: float, freq: float, decay: float, amp: float, sweep := 0.0) -> void:
	var i0 := int(start * RATE)
	var ph := 0.0
	for i in range(i0, s.size()):
		var t := float(i - i0) / RATE
		var e := exp(-t * decay)
		if e < 0.001: break
		ph += TAU * (freq + sweep * t) / RATE
		s[i] += sin(ph) * e * amp

## Adds filtered noise. lp: 0..1 smoothing (lower = darker), hp removes low rumble.
static func _noise(s: PackedFloat32Array, start: float, dur: float, decay: float, amp: float, lp := 0.5, hp := 0.0, attack := 0.002) -> void:
	var i0 := int(start * RATE)
	var i1 := mini(s.size(), i0 + int(dur * RATE))
	var l := 0.0; var l2 := 0.0
	for i in range(i0, i1):
		var t := float(i - i0) / RATE
		l = lerpf(l, _n(), lp)
		l2 = lerpf(l2, l, hp) if hp > 0.0 else 0.0
		var env := minf(t / attack, 1.0) * exp(-t * decay)
		s[i] += (l - l2) * env * amp

static func get_stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	_rng.seed = hash(kind)
	var s: PackedFloat32Array
	var loop := false
	match kind:
		"rifle":
			s = _buf(0.7)
			_noise(s, 0.0, 0.25, 30.0, 1.0, 0.9, 0.2)      # supersonic crack
			_ring(s, 0.0, 85.0, 16.0, 0.9, -40.0)            # body thump
			_noise(s, 0.005, 0.6, 7.0, 0.35, 0.12)           # room tail
			_ring(s, 0.055, 2400.0, 60.0, 0.12)              # bolt clack
			_ring(s, 0.085, 1600.0, 70.0, 0.1)
		"pistol":
			s = _buf(0.45)
			_noise(s, 0.0, 0.18, 38.0, 1.0, 0.95, 0.35)
			_ring(s, 0.0, 140.0, 22.0, 0.7, -60.0)
			_noise(s, 0.004, 0.4, 9.0, 0.25, 0.15)
			_ring(s, 0.04, 3100.0, 80.0, 0.1)
		"dry":
			s = _buf(0.08); _ring(s, 0.0, 2800.0, 120.0, 0.6); _noise(s, 0.0, 0.03, 200.0, 0.3, 0.9)
		"mag_out":
			s = _buf(0.25); _ring(s, 0.0, 900.0, 40.0, 0.5); _ring(s, 0.02, 1500.0, 50.0, 0.3); _noise(s, 0.0, 0.1, 40.0, 0.25, 0.6)
		"mag_in":
			s = _buf(0.25); _ring(s, 0.0, 700.0, 35.0, 0.6); _ring(s, 0.0, 2100.0, 60.0, 0.35); _noise(s, 0.0, 0.05, 80.0, 0.4, 0.8)
		"bolt":
			s = _buf(0.35); _ring(s, 0.0, 1800.0, 45.0, 0.5); _noise(s, 0.0, 0.04, 90.0, 0.4, 0.9); _ring(s, 0.12, 1200.0, 40.0, 0.6); _ring(s, 0.12, 3000.0, 70.0, 0.3)
		"switch":
			s = _buf(0.35); _noise(s, 0.0, 0.25, 10.0, 0.3, 0.3, 0.05, 0.05); _ring(s, 0.2, 1400.0, 60.0, 0.4)
		"impact_stone":
			s = _buf(0.3); _noise(s, 0.0, 0.25, 25.0, 0.8, 0.6, 0.1); _ring(s, 0.0, 180.0, 40.0, 0.4)
		"impact_wood":
			s = _buf(0.3); _ring(s, 0.0, 240.0, 30.0, 0.8); _ring(s, 0.0, 410.0, 45.0, 0.4); _noise(s, 0.0, 0.08, 60.0, 0.4, 0.5)
		"impact_metal":
			s = _buf(0.6); _ring(s, 0.0, 1850.0, 9.0, 0.5); _ring(s, 0.0, 2730.0, 12.0, 0.35); _ring(s, 0.0, 4100.0, 18.0, 0.2); _noise(s, 0.0, 0.04, 100.0, 0.6, 0.9)
		"impact_glass":
			s = _buf(0.5); _noise(s, 0.0, 0.3, 14.0, 0.6, 0.95, 0.5)
			for k in 6: _ring(s, _rng.randf_range(0.0, 0.25), _rng.randf_range(3000, 6000), 30.0, 0.15)
		"impact_flesh":
			s = _buf(0.3); _ring(s, 0.0, 95.0, 30.0, 0.9, -40.0); _noise(s, 0.0, 0.15, 30.0, 0.5, 0.25)
		"impact_spirit":
			s = _buf(0.5); _ring(s, 0.0, 600.0, 8.0, 0.4, -700.0); _noise(s, 0.0, 0.4, 8.0, 0.3, 0.4, 0.2, 0.05)
		"step_stone":
			s = _buf(0.18); _noise(s, 0.0, 0.12, 45.0, 0.6, 0.5, 0.15); _ring(s, 0.0, 120.0, 50.0, 0.35)
		"step_wood":
			s = _buf(0.2); _ring(s, 0.0, 160.0, 35.0, 0.6); _ring(s, 0.0, 330.0, 50.0, 0.25); _noise(s, 0.0, 0.06, 60.0, 0.3, 0.4)
		"step_metal":
			s = _buf(0.3); _ring(s, 0.0, 520.0, 20.0, 0.35); _ring(s, 0.0, 1300.0, 30.0, 0.2); _noise(s, 0.0, 0.05, 70.0, 0.4, 0.7)
		"glass_break":
			s = _buf(1.4); _noise(s, 0.0, 0.5, 6.0, 0.8, 0.95, 0.4)
			for k in 26: _ring(s, _rng.randf_range(0.0, 0.9), _rng.randf_range(2500, 7500), _rng.randf_range(20, 45), _rng.randf_range(0.05, 0.2))
		"stone_grind":
			s = _buf(1.6); _noise(s, 0.0, 1.6, 0.8, 0.8, 0.06, 0.0, 0.3)
			for i in s.size(): s[i] *= 0.6 + 0.4 * sin(TAU * 7.0 * i / RATE)
		"whisper":
			s = _buf(2.6)
			var l := 0.0; var l2 := 0.0
			for i in s.size():
				var t := float(i) / RATE
				l = lerpf(l, _n(), 0.6); l2 = lerpf(l2, l, 0.3)
				var formant := 0.5 + 0.5 * sin(TAU * (3.0 + 2.0 * sin(t * 1.3)) * t)
				s[i] = (l - l2) * formant * sin(PI * t / 2.6) * 0.8
		"creak":
			s = _buf(1.1)
			var ph := 0.0
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (70.0 + 40.0 * sin(t * 3.0)) / RATE
				s[i] = (fmod(ph, TAU) / TAU - 0.5) * (0.4 + 0.6 * absf(sin(t * 23.0))) * sin(PI * t / 1.1) * 0.6
		"alarm":
			s = _buf(2.0); loop = true
			var ph := 0.0
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (880.0 if fmod(t, 1.0) < 0.5 else 660.0) / RATE
				s[i] = (sin(ph) * 0.6 + sin(ph * 2.0) * 0.2) * 0.5
		"ghost_wail":
			s = _buf(1.8)
			var ph := 0.0
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (420.0 + 180.0 * sin(t * 1.7) + 12.0 * sin(t * 35.0)) / RATE
				s[i] = sin(ph) * sin(PI * t / 1.8) * 0.5
			_noise(s, 0.0, 1.8, 0.6, 0.15, 0.5, 0.3, 0.4)
		"phase":
			s = _buf(0.6); _noise(s, 0.0, 0.6, 5.0, 0.6, 0.35, 0.1, 0.15); _ring(s, 0.0, 300.0, 6.0, 0.3, 900.0)
		"awaken":
			s = _buf(1.6); _noise(s, 0.0, 1.6, 1.5, 0.7, 0.05, 0.0, 0.2); _ring(s, 0.3, 75.0, 2.0, 0.6, -20.0); _ring(s, 0.6, 140.0, 3.0, 0.4)
		"growl":
			s = _buf(0.8)
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, _n(), 0.08)
				s[i] = (lp * 2.5 * (0.6 + 0.4 * sin(TAU * 23.0 * t)) + sin(TAU * (90.0 - 40.0 * t) * t) * 0.4) * sin(PI * t / 0.8) * 0.7
		"moan":
			s = _buf(1.4)
			var ph := 0.0
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (150.0 - 30.0 * t + 6.0 * sin(t * 30.0)) / RATE
				s[i] = (sin(ph) + 0.4 * sin(ph * 2.01) + 0.2 * sin(ph * 3.0)) * sin(PI * t / 1.4) * 0.45
			_noise(s, 0.0, 1.4, 1.0, 0.2, 0.2, 0.0, 0.3)
		"shriek":
			s = _buf(0.9)
			var ph := 0.0
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (900.0 + 600.0 * t + 40.0 * sin(t * 60.0)) / RATE
				s[i] = sin(ph) * sin(PI * t / 0.9) * 0.4
			_noise(s, 0.0, 0.9, 2.0, 0.4, 0.8, 0.4, 0.1)
		"hit":
			s = _buf(0.12)
			for i in s.size():
				var t := float(i) / RATE
				s[i] = (_n() * 0.5 + sin(TAU * 180.0 * t)) * exp(-t * 40.0) * 0.6
		"hurt":
			s = _buf(0.3); _ring(s, 0.0, 160.0, 12.0, 0.8, -220.0); _noise(s, 0.0, 0.15, 20.0, 0.25, 0.3)
		"death":
			s = _buf(1.2)
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, _n(), 0.05)
				s[i] = (lp * 3.0 + sin(TAU * (120.0 - 80.0 * t) * t) * 0.5) * exp(-t * 2.5) * 0.6
		"round_chime":
			s = _buf(2.0)
			for k in 4: _ring(s, k * 0.12, [523.25, 659.25, 783.99, 1046.5][k], 2.0, 0.3)
		"death_sting":
			s = _buf(2.2); _ring(s, 0.0, 65.0, 1.2, 0.7); _ring(s, 0.0, 69.3, 1.2, 0.6); _ring(s, 0.0, 98.0, 1.5, 0.4); _noise(s, 0.0, 2.0, 1.5, 0.2, 0.05)
		"ui_click":
			s = _buf(0.06); _ring(s, 0.0, 1200.0, 90.0, 0.4)
		"power_down":
			s = _buf(1.4); _ring(s, 0.0, 240.0, 1.2, 0.6, -170.0); _noise(s, 0.0, 0.15, 25.0, 0.6, 0.7)
		"power_up":
			s = _buf(1.0); _ring(s, 0.0, 90.0, 1.5, 0.5, 220.0); _ring(s, 0.05, 2200.0, 50.0, 0.2)
		"horn":
			s = _buf(2.4)
			var ph := 0.0; var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (110.0 + 2.0 * sin(t * 5.0)) / RATE
				lp = lerpf(lp, (fmod(ph, TAU) / TAU - 0.5), 0.12)
				s[i] = lp * minf(t / 0.3, 1.0) * minf((2.4 - t) / 0.5, 1.0) * 2.0
		"hum":
			s = _buf(2.0); loop = true
			for i in s.size():
				var t := float(i) / RATE
				s[i] = (sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.0 * t) * 0.25 + sin(TAU * 165.5 * t) * 0.1) * 0.6
		"heartbeat":
			s = _buf(0.9); _ring(s, 0.0, 55.0, 18.0, 0.9); _ring(s, 0.22, 50.0, 18.0, 0.7)
		"amb_museum":
			s = _buf(6.0); loop = true
			var l := 0.0
			for i in s.size():
				var t := float(i) / RATE
				l = lerpf(l, _n(), 0.03)
				s[i] = l * 1.6 + sin(TAU * 50.0 * t) * 0.05 + sin(TAU * 100.0 * t) * 0.03
		"amb_occult":
			s = _buf(8.0); loop = true
			var l := 0.0; var ph := 0.0
			for i in s.size():
				var t := float(i) / RATE
				l = lerpf(l, _n(), 0.02)
				ph += TAU * (41.2 + 0.4 * sin(TAU * t / 8.0)) / RATE
				s[i] = l * 1.4 + sin(ph) * 0.3 + sin(ph * 1.498) * 0.15
		_:
			s = _buf(0.1); _ring(s, 0.0, 800.0, 40.0, 0.3)
	_cache[kind] = _wav(s, loop)
	return _cache[kind]

## Plays a one-shot. pos: Vector3 for positional audio, null for 2D.
static func play(parent: Node, kind: String, pos = null, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> Node:
	if parent == null or not parent.is_inside_tree():
		return null
	var p: Node
	if pos is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 7.0
		p3.max_distance = 45.0
		p = p3
		parent.add_child(p3)
		p3.global_position = pos
	else:
		p = AudioStreamPlayer.new()
		parent.add_child(p)
	p.bus = bus
	p.stream = get_stream(kind)
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.finished.connect(p.queue_free)
	p.play()
	return p

## Starts a looping sound and returns the player (caller stops/frees it).
static func loop(parent: Node, kind: String, pos = null, volume_db := 0.0, bus := "Ambience") -> Node:
	var p: Node
	if pos is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 8.0; p3.max_distance = 40.0
		parent.add_child(p3); p3.global_position = pos; p = p3
	else:
		p = AudioStreamPlayer.new(); parent.add_child(p)
	p.bus = bus
	p.stream = get_stream(kind)
	p.volume_db = volume_db
	p.play()
	return p
