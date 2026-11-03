class_name Sfx
extends RefCounted
## Tiny procedural sound effects (the Synty packs ship no audio).

const RATE := 22050
static var _cache := {}

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

## kind: "shot", "hit", "growl", "hurt", "death"
static func get_stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var s := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"shot":
			var n := int(RATE * 0.32)
			s.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.35)
				s[i] = (lp * exp(-t * 18.0) * 0.9 + sin(TAU * 70.0 * t) * exp(-t * 25.0) * 0.8)
		"hit":
			var n := int(RATE * 0.12)
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				s[i] = (rng.randf_range(-1, 1) * 0.5 + sin(TAU * 180.0 * t)) * exp(-t * 40.0) * 0.6
		"growl":
			var n := int(RATE * 0.7)
			s.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.08)
				var env := sin(PI * t / 0.7)
				s[i] = (lp * 2.5 * (0.6 + 0.4 * sin(TAU * 23.0 * t)) + sin(TAU * (90.0 - 40.0 * t) * t) * 0.4) * env * 0.7
		"hurt":
			var n := int(RATE * 0.25)
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				s[i] = sin(TAU * (160.0 - 200.0 * t) * t) * exp(-t * 12.0) * 0.8
		"death":
			var n := int(RATE * 1.2)
			s.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.05)
				s[i] = (lp * 3.0 + sin(TAU * (120.0 - 80.0 * t) * t) * 0.5) * exp(-t * 2.5) * 0.6
	_cache[kind] = _wav(s)
	return _cache[kind]

static func play(parent: Node, kind: String, pos = null, volume_db := 0.0, pitch := 1.0) -> void:
	var p: Node
	if pos is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p = p3
		parent.add_child(p3)
		p3.global_position = pos
	else:
		p = AudioStreamPlayer.new()
		parent.add_child(p)
	p.stream = get_stream(kind)
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.finished.connect(p.queue_free)
	p.play()
