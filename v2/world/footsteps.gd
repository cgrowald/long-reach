extends AudioStreamPlayer
## Footsteps in the garage: Kenney Impact Sounds (CC0, art/audio/kenney_impact/), concrete on the bare floor and
## carpet on the rugs and mats. step(soft) plays the next one, never the same twice in a row.

const DIR := "res://art/audio/kenney_impact/"

var _hard: Array = []
var _soft: Array = []
var _last := -1


func _ready() -> void:
	bus = "SFX"
	volume_db = -13.0
	for k in 5:
		_hard.append(load(DIR + "footstep_concrete_%03d.ogg" % k))
		_soft.append(load(DIR + "footstep_carpet_%03d.ogg" % k))


func step(soft := false) -> void:
	var set_: Array = _soft if soft else _hard
	if set_.is_empty():
		return
	var i := randi() % set_.size()
	if i == _last:
		i = (i + 1) % set_.size()
	_last = i
	stream = set_[i]
	pitch_scale = randf_range(0.94, 1.06)
	volume_db = -15.0 if soft else -13.0
	play()
