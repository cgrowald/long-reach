extends Control
## Radial action wheel. open(center, options) shows wedges around the cursor;
## left-click a wedge to choose, right-click / Esc / click the middle to cancel.
## Each option: {"id": String, "label": String, "enabled": bool}.

signal chosen(id: String, context: Dictionary)
signal cancelled

const RADIUS := 135.0
const INNER := 32.0
const FONT_SIZE := 14
const COLOR_BG := Color(0.06, 0.08, 0.1, 0.88)
const COLOR_HOVER := Color(0.95, 0.75, 0.25, 0.95)
const COLOR_EDGE := Color(1, 1, 1, 0.25)
const COLOR_TEXT := Color(1, 1, 1)
const COLOR_DISABLED := Color(0.55, 0.55, 0.55)

var _options: Array = []
var _context: Dictionary = {}
var _center: Vector2 = Vector2.ZERO
var _hover: int = -1
var _title: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_silently()


func is_open() -> bool:
	return visible


## context is handed back with the choice (e.g. which door or units it was for).
func open(center: Vector2, title: String, options: Array, context: Dictionary) -> void:
	_center = center
	_title = title
	_options = options
	_context = context
	_hover = -1
	# Cover the whole window so every click lands here while open
	# (full-rect anchors don't size a Control whose parent is a CanvasLayer).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func close() -> void:
	if visible:
		_close_silently()
		cancelled.emit()


func _close_silently() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h: int = _index_at((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _index_at(mb.position)
			if idx >= 0 and bool(_options[idx].get("enabled", true)):
				var id: String = _options[idx]["id"]
				var ctx: Dictionary = _context
				_close_silently()
				chosen.emit(id, ctx)
			elif idx < 0:
				close()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _index_at(p: Vector2) -> int:
	if _options.is_empty():
		return -1
	var d: Vector2 = p - _center
	if d.length() < INNER or d.length() > RADIUS * 1.5:
		return -1
	var seg: float = TAU / float(_options.size())
	var a: float = fposmod(d.angle() + PI * 0.5 + seg * 0.5, TAU)
	return int(a / seg) % _options.size()


func _draw() -> void:
	if _options.is_empty():
		return
	var n: int = _options.size()
	var seg: float = TAU / float(n)
	var font: Font = get_theme_default_font()
	for i in n:
		var a0: float = -PI * 0.5 - seg * 0.5 + seg * float(i)
		var a1: float = a0 + seg
		var pts := PackedVector2Array()
		var steps: int = 12
		for k in steps + 1:
			pts.append(_center + Vector2.from_angle(lerpf(a0, a1, float(k) / steps)) * RADIUS)
		for k in range(steps, -1, -1):
			pts.append(_center + Vector2.from_angle(lerpf(a0, a1, float(k) / steps)) * INNER)
		var enabled: bool = bool(_options[i].get("enabled", true))
		var fill: Color = COLOR_HOVER if (i == _hover and enabled) else COLOR_BG
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, COLOR_EDGE, 1.0)
		var mid: Vector2 = _center + Vector2.from_angle((a0 + a1) * 0.5) * (INNER + RADIUS) * 0.55
		var label: String = _options[i]["label"]
		var size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var color: Color = COLOR_TEXT if enabled else COLOR_DISABLED
		if i == _hover and enabled:
			color = Color.BLACK
		draw_string(font, mid - Vector2(size.x * 0.5, -size.y * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
	if _title != "":
		var tsize: Vector2 = font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var tpos: Vector2 = _center + Vector2(-tsize.x * 0.5, -RADIUS - 10.0)
		draw_string_outline(font, tpos, _title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color.BLACK)
		draw_string(font, tpos, _title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_HOVER)
