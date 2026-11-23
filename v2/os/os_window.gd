extends Control
## A HEARTH window: Win2000 frame, gradient title bar with icon, minimise / maximise / close,
## drag by the title, double-click the title to maximise, resize from the bottom-right corner.
## The app lives in `body`.

signal closed
signal focus_me

const P := preload("res://v2/os/os_pal.gd")
const TITLE_H := 16.0
const MIN_SIZE := Vector2(120, 70)

var title := ""
var icon := "file"
var app_id := ""
var app: Control
var body: Control
var active := true
var minimized := false
var maximized := false
var _restore := Rect2()
var _drag := false
var _resize := false
var _off := Vector2.ZERO


func setup(p_title: String, p_icon: String, p_size: Vector2) -> void:
	title = p_title
	icon = p_icon
	size = p_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = P.theme()
	body = Control.new()
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	resized.connect(_layout)
	_layout()


func set_app(a: Control) -> void:
	app = a
	body.add_child(a)
	_layout()


func _layout() -> void:
	if body == null:
		return
	body.position = Vector2(2, TITLE_H + 3)
	body.size = size - Vector2(4, TITLE_H + 5)
	if app:
		app.position = Vector2.ZERO
		app.size = body.size
	queue_redraw()


func set_active(on: bool) -> void:
	active = on
	queue_redraw()


func _buttons() -> Array:
	var y := 3.0
	var w := 12.0
	var x := size.x - 3.0 - w
	return [Rect2(x - 2 * (w + 2), y, w, 11), Rect2(x - (w + 2), y, w, 11), Rect2(x, y, w, 11)]


func _draw() -> void:
	# ivory body, a petrol frame line, a flat petrol title bar (GPT concept sheets)
	draw_rect(Rect2(Vector2(2, 3), size), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
	var bar := Rect2(0, 0, size.x, TITLE_H + 1)
	draw_rect(bar, P.PETROL if active else P.TITLE_OFF_A)
	P.icon(self, icon, Vector2(4, 3), 11.0)
	var tw := size.x - 70.0
	P.text(self, Vector2(19, 3), P.fit(title.to_upper(), tw), P.FACE_L if active else P.FACE)
	var b := _buttons()
	for i in 3:
		var r: Rect2 = b[i]
		draw_rect(r, P.FACE_L)
		draw_rect(r, P.PETROL_D, false, 1.0)
		var c := r.get_center()
		match i:
			0:
				draw_rect(Rect2(c.x - 3, c.y + 2, 6, 1.5), P.INK)
			1:
				draw_rect(Rect2(c.x - 3, c.y - 3, 6, 6), P.INK, false, 1.0)
			2:
				draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), P.INK, 1.5)
				draw_line(c + Vector2(3, -3), c + Vector2(-3, 3), P.INK, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), P.PETROL_D, false, 1.0)
	if not maximized:
		for i in 3:
			var o := 3.0 + i * 3.0
			draw_line(size - Vector2(o, 2), size - Vector2(2, o), P.FACE_D)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = e.position
		if e.pressed:
			focus_me.emit()
			var b := _buttons()
			if (b[2] as Rect2).grow(1).has_point(p):
				close()
			elif (b[1] as Rect2).grow(1).has_point(p):
				toggle_max()
			elif (b[0] as Rect2).grow(1).has_point(p):
				set_minimized(true)
			elif p.y < TITLE_H + 4:
				if e.double_click:
					toggle_max()
				elif not maximized:
					_drag = true
					_off = p
			elif not maximized and p.x > size.x - 8 and p.y > size.y - 8:
				_resize = true
			accept_event()
		else:
			_drag = false
			_resize = false
	elif e is InputEventMouseMotion:
		if _drag:
			var parent := get_parent() as Control
			var np: Vector2 = parent.get_local_mouse_position() - _off
			np.x = clampf(np.x, -size.x + 40, parent.size.x - 40)
			np.y = clampf(np.y, 0, parent.size.y - TITLE_H - 20)
			position = np.round()
		elif _resize:
			size = Vector2(maxf(MIN_SIZE.x, e.position.x + 2), maxf(MIN_SIZE.y, e.position.y + 2)).round()
		elif not maximized and e.position.x > size.x - 8 and e.position.y > size.y - 8:
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW


func toggle_max() -> void:
	var parent := get_parent() as Control
	if maximized:
		maximized = false
		position = _restore.position
		size = _restore.size
	else:
		maximized = true
		_restore = Rect2(position, size)
		position = Vector2.ZERO
		size = parent.size
	_click()


func set_minimized(on: bool) -> void:
	minimized = on
	visible = not on
	_click()


func close() -> void:
	closed.emit()
	var g := get_node_or_null("/root/Game")
	if g:
		g.sfx.play("close_001", 1.1, -12.0)
	queue_free()


func _click() -> void:
	var g := get_node_or_null("/root/Game")
	if g:
		g.click()
