extends AudioStreamPlayer
## Placeholder room tone, generated (no downloads): rain-like brown noise plus a faint mains hum.

const RATE := 11025.0

var _pb: AudioStreamGeneratorPlayback
var _brown := 0.0
var _phase := 0.0
var _drip := 0.0


func _ready() -> void:
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.25
	stream = g
	bus = "Music"
	volume_db = -14.0
	play()
	_pb = get_stream_playback()


func _process(_delta: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	for i in n:
		_brown = clampf(_brown + randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		_phase = fmod(_phase + 50.0 / RATE, 1.0)
		var hum := sin(_phase * TAU) * 0.05 + sin(_phase * TAU * 3.0) * 0.015
		if randf() < 0.00012:
			_drip = 0.5
		_drip *= 0.996
		var drip := _drip * sin(float(i) * 0.9)
		var s := _brown * 0.6 + hum + drip * 0.15
		_pb.push_frame(Vector2(s, s))
