extends Control
## The CRT on the desk: dark red phosphor, scanlines, a vignette, and screen shake.

const Pal := preload("res://v2/ui/pal.gd")

var trauma := 0.0
var _base := Vector2.ZERO
var _overlay: Control


func place(r: Rect2) -> void:
	position = r.position
	size = r.size
	_base = r.position


func _ready() -> void:
	clip_contents = true
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 50
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func shake(amount: float) -> void:
	trauma = minf(trauma + amount, 7.0)


func _process(delta: float) -> void:
	if trauma > 0.15:
		position = _base + Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * trauma
		trauma *= exp(-9.0 * delta)
	else:
		trauma = 0.0
		position = _base


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.SCREEN)


func _draw_overlay() -> void:
	var s := _overlay.size
	for y in range(1, int(s.y), 2):
		_overlay.draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.2))
	for i in 7:
		_overlay.draw_rect(Rect2(i, i, s.x - i * 2, s.y - i * 2), Color(0, 0, 0, 0.13), false, 1.0)
	_overlay.draw_rect(Rect2(Vector2.ZERO, s), Pal.SCREEN_LINE, false, 1.0)
