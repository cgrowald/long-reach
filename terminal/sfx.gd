extends Node
## Laptop sounds: files from data/terminal/sounds.json (Kenney CC0), synthesized fallback for the rest.

const RATE := 22050

var _players: Array = []
var _cache: Dictionary = {}
var _files: Dictionary = {}
var _fan: AudioStreamPlayer


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_fan = AudioStreamPlayer.new()
	_fan.stream = _make_fan()
	_fan.volume_db = -30.0
	add_child(_fan)


func play(name: String, volume_db: float = -10.0) -> void:
	var stream: AudioStream = _file_stream(name)
	if stream == null:
		if not _cache.has(name):
			_cache[name] = _make(name)
		stream = _cache[name]
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = randf_range(0.95, 1.05) if name == "key" or name == "click" else 1.0
			p.play()
			return


func _file_stream(name: String) -> AudioStream:
	if _files.is_empty():
		_load_files()
	var list: Array = _files.get(name, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()]


func _load_files() -> void:
	_files["_loaded"] = []
	var f := FileAccess.open("res://data/terminal/sounds.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	for n in d.get("sounds", {}):
		var streams: Array = []
		for file in d["sounds"][n]:
			var s = load(str(d["dir"]) + str(file))
			if s is AudioStream:
				streams.append(s)
		_files[n] = streams


func fan(on: bool, louder: bool = false) -> void:
	_fan.volume_db = -24.0 if louder else -30.0
	if on and not _fan.playing:
		_fan.play()
	elif not on:
		_fan.stop()


func _make(name: String) -> AudioStreamWAV:
	match name:
		"click":
			return _wav(_noise_burst(0.018, 0.5))
		"key":
			return _wav(_noise_burst(0.012, 0.35))
		"pip":
			return _wav(_tones([[880.0, 0.07], [1320.0, 0.09]], 0.35))
		"beep":
			return _wav(_tones([[1000.0, 0.18]], 0.3, true))
		"error":
			return _wav(_tones([[180.0, 0.16]], 0.3, true))
		"chime":
			return _wav(_tones([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1046.0, 0.3]], 0.3))
		"secret":
			return _wav(_tones([[659.0, 0.1], [988.0, 0.1], [1319.0, 0.25]], 0.3))
		"lid":
			return _wav(_noise_burst(0.12, 0.6, true))
	return _wav(PackedFloat32Array([0.0]))


func _noise_burst(dur: float, amp: float, low: bool = false) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var env := 1.0 - float(i) / n
		var v := randf_range(-1.0, 1.0)
		if low:
			prev = prev * 0.92 + v * 0.08
			v = prev * 4.0
		out[i] = v * amp * env * env
	return out


func _tones(seq: Array, amp: float, square: bool = false) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for s in seq:
		var f: float = s[0]
		var n := int(float(s[1]) * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := minf(1.0, i / 200.0) * (1.0 - float(i) / n)
			var v := sin(TAU * f * t)
			if square:
				v = signf(v) * 0.6
			out.append(v * amp * env)
	return out


func _make_fan() -> AudioStreamWAV:
	var n := RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		a = a * 0.97 + randf_range(-1.0, 1.0) * 0.03
		b = b * 0.995 + a * 0.005
		out[i] = (a * 3.0 + b * 8.0) * 0.5 + sin(TAU * 120.0 * i / RATE) * 0.02
	# Crossfade the ends so the loop doesn't click.
	var fade := 2000
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[n - fade + i] * (1.0 - w)
	var s := _wav(out.slice(0, n - fade))
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n - fade
	return s


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
