extends AudioStreamPlayer
## Footsteps on the garage's concrete, generated (no downloads, like v2/ui/ambience.gd): a soft heel thump and a
## short gritty scuff, four variants so it doesn't machine-gun. step() plays the next one.

const RATE := 22050

var _variants: Array = []
var _i := 0


func _ready() -> void:
	bus = "SFX"
	volume_db = -15.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for v in 4:
		_variants.append(_make(rng, 0.85 + v * 0.07))


func _make(rng: RandomNumberGenerator, pitch: float) -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for k in n:
		var t := float(k) / RATE
		var thump := sin(TAU * 62.0 * pitch * t) * exp(-t * 45.0) * 0.9
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.22            # gritty, low-passed noise
		var scuff := lp * exp(-maxf(t - 0.012, 0.0) * 32.0) * (0.0 if t < 0.006 else 0.8)
		var s := clampf((thump + scuff) * 0.7, -1.0, 1.0)
		data.encode_s16(k * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func step() -> void:
	if _variants.is_empty():
		return
	_i = (_i + 1 + randi() % 2) % _variants.size()
	stream = _variants[_i]
	pitch_scale = randf_range(0.93, 1.07)
	play()
