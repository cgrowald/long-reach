extends Control
## Screen-space feedback for mouse gestures: the drag-select rectangle and the
## right-drag facing arrow. Never blocks mouse input.

const FILL := Color(0.4, 0.8, 1.0, 0.15)
const EDGE := Color(0.4, 0.8, 1.0, 0.9)
const ARROW := Color(1.0, 0.85, 0.3, 0.95)

var _rect: Rect2 = Rect2()
var _rect_active: bool = false
var _arrow_from: Vector2 = Vector2.ZERO
var _arrow_to: Vector2 = Vector2.ZERO
var _arrow_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_rect(a: Vector2, b: Vector2) -> void:
	_rect = Rect2(a, b - a).abs()
	_rect_active = true
	queue_redraw()


func hide_rect() -> void:
	_rect_active = false
	queue_redraw()


func show_arrow(from: Vector2, to: Vector2) -> void:
	_arrow_from = from
	_arrow_to = to
	_arrow_active = true
	queue_redraw()


func hide_arrow() -> void:
	_arrow_active = false
	queue_redraw()


func _draw() -> void:
	if _rect_active:
		draw_rect(_rect, FILL, true)
		draw_rect(_rect, EDGE, false, 1.0)
	if _arrow_active:
		draw_line(_arrow_from, _arrow_to, ARROW, 2.0)
		draw_circle(_arrow_from, 4.0, ARROW)
		var dir: Vector2 = (_arrow_to - _arrow_from).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			_arrow_to, _arrow_to - dir * 14.0 + side * 7.0, _arrow_to - dir * 14.0 - side * 7.0,
		]), ARROW)
