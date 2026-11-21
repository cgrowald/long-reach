extends Node
## Tiny sound pool. play("tick_001", pitch, db, min_gap) with a per-sound rate limit.

const DIR := "res://art/audio/kenney_interface/"
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _next := 0


func _ready() -> void:
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(id: String, pitch := 1.0, db := -8.0, min_gap := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last.get(id, -10.0)) < min_gap:
		return
	_last[id] = now
	if not _streams.has(id):
		_streams[id] = load(DIR + id + ".ogg")
	var s: AudioStream = _streams[id]
	if s == null or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.3, 4.0)
	p.volume_db = db
	p.play()
