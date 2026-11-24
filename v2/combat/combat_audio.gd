extends RefCounted
## Sounds made in code until real ones are recorded or bought (placeholder, docs/COMBAT_SLICE.md):
## gunshots (crack + thump + room tail), a door kick, a flashbang, radio squelch clicks.

const RATE := 22050

static var _cache := {}


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## kind: rifle, pistol, smg, carbine, kick, bang, click, squelch
static func get_sound(kind: String) -> AudioStream:
	if _cache.has(kind):
		return _cache[kind]
	if "/" in kind:                   # a recorded sound, e.g. "kenney_impact/impactPlate_heavy_002" (C4)
		return load("res://art/audio/" + kind + ".ogg")      # the resource loader keeps it; a static cache would leak at exit
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var len_s := 0.6
	var crack := 1.0
	var thump := 0.8
	var tail := 0.35
	var pitch := 1.0
	match kind:
		"pistol":
			len_s = 0.45
			thump = 0.55
			pitch = 1.3
		"smg":
			len_s = 0.4
			crack = 0.8
			thump = 0.5
			pitch = 1.5
		"carbine":
			thump = 1.0
			pitch = 0.9
		"kick":
			len_s = 0.35
			crack = 0.35
			thump = 1.0
			tail = 0.15
			pitch = 0.6
		"bang":
			len_s = 1.4
			crack = 1.0
			thump = 1.0
			tail = 0.7
			pitch = 0.7
		"click", "squelch":
			len_s = 0.08 if kind == "click" else 0.18
			crack = 0.0
			thump = 0.0
			tail = 0.0
	var n := int(len_s * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var tl := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		var noise := rng.randf_range(-1.0, 1.0)
		if kind == "click" or kind == "squelch":
			var env := exp(-t * (60.0 if kind == "click" else 18.0))
			lp = lerpf(lp, noise, 0.5)
			v = lp * env * 0.5 + sin(t * TAU * 1800.0) * env * 0.15
		else:
			# the crack: bright noise, gone in a few milliseconds
			v += noise * exp(-t * 180.0 * pitch) * crack
			# the thump: a falling low sine
			var f := 110.0 * pitch * (1.0 + exp(-t * 40.0) * 2.0)
			v += sin(TAU * f * t) * exp(-t * 22.0) * thump
			# the tail: filtered noise ringing off the walls
			tl = lerpf(tl, noise, 0.08)
			v += tl * exp(-t * 6.0 / maxf(0.2, len_s)) * tail * 2.0
		s[i] = v * 0.8
	var w := _wav(s)
	_cache[kind] = w
	return w


static func play_at(parent: Node3D, kind: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = get_sound(kind)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 3000.0
	parent.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
