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
var _line := PackedVector2Array()
var _look_from: Vector2 = Vector2.ZERO
var _look_to: Vector2 = Vector2.ZERO
var _look_pie: bool = false
var _look_active: bool = false

const LINE := Color(0.4, 0.85, 1.0, 0.9)


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


func show_line(points: PackedVector2Array) -> void:
	_line = points
	queue_redraw()


func hide_line() -> void:
	_line = PackedVector2Array()
	queue_redraw()


## Right-drag preview: solid line = look, dotted line + pie icon = pie.
func show_look_line(from: Vector2, to: Vector2, pie: bool) -> void:
	_look_from = from
	_look_to = to
	_look_pie = pie
	_look_active = true
	queue_redraw()


func hide_look_line() -> void:
	_look_active = false
	queue_redraw()


## A small "pie" glyph: circle with one slice cut out and filled.
static func draw_pie_icon(ci: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	ci.draw_arc(at, radius, 0.0, TAU, 24, color, 2.0)
	var pts := PackedVector2Array([at])
	for k in 7:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + k * (PI * 0.5 / 6.0)) * radius)
	ci.draw_colored_polygon(pts, color)


func _draw() -> void:
	if _look_active:
		if _look_pie:
			draw_dashed_line(_look_from, _look_to, ARROW, 2.0, 8.0)
			draw_pie_icon(self, _look_to, 9.0, ARROW)
		else:
			draw_line(_look_from, _look_to, ARROW, 2.0)
			draw_circle(_look_to, 4.0, ARROW)
	if _line.size() >= 2:
		draw_polyline(_line, LINE, 3.0, true)
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
