extends Control
## Draws the drag-select rectangle. Never blocks mouse input.

const FILL := Color(0.4, 0.8, 1.0, 0.15)
const EDGE := Color(0.4, 0.8, 1.0, 0.9)

var _rect: Rect2 = Rect2()
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_rect(a: Vector2, b: Vector2) -> void:
	_rect = Rect2(a, b - a).abs()
	_active = true
	queue_redraw()


func hide_rect() -> void:
	_active = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_rect(_rect, FILL, true)
	draw_rect(_rect, EDGE, false, 1.0)
