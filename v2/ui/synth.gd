extends RefCounted
## Tiny procedural sounds (no downloads): metal scrape loops, clicks and thunks, built once as AudioStreamWAV.

const RATE := 22050

static var _cache := {}


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


## A gritty metal-on-metal scrape (loops).
static func scrape() -> AudioStreamWAV:
	if _cache.has("scrape"):
		return _cache["scrape"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := RATE / 2
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var hp_prev := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		if rng.randf() < 0.02:
			x *= 4.0                     # grit
		lp += (x - lp) * 0.35
		var hp := lp - hp_prev * 0.97
		hp_prev = lp
		var ring := sin(TAU * 2900.0 * i / RATE) * 0.15 + sin(TAU * 4400.0 * i / RATE) * 0.08
		s[i] = (hp * 0.6 + ring * absf(lp)) * 0.7
	var w := _wav(s, true)
	_cache["scrape"] = w
	return w


## A short click / tick: freq in Hz, decay in seconds, noise mix 0..1.
static func tick(freq: float, decay: float, noise := 0.3) -> AudioStreamWAV:
	var key := "tick%d_%d_%d" % [int(freq), int(decay * 1000), int(noise * 10)]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	var n := int(RATE * decay * 4.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t / decay)
		s[i] = (sin(TAU * freq * t) * (1.0 - noise) + rng.randf_range(-1, 1) * noise) * env
	var w := _wav(s)
	_cache[key] = w
	return w
