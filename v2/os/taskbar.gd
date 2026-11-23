extends Control
## The bottom bar (face-lift): one tab per open window, like the GPT sheets. The HEARTH menu and the clock
## moved to the top bar (desktop.gd); a small notes button stays at the right.

const P := preload("res://v2/os/os_pal.gd")

const START_W := -4.0
const QUICK := []

var os: Control
var _blink := 0.0


func setup(p_os: Control) -> void:
	os = p_os
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


func _quick_rect(i: int) -> Rect2:
	return Rect2(START_W + 4 + i * 12, 3, 11, 10)


func _win_area() -> Rect2:
	return Rect2(4, 1, size.x - 26, size.y - 2)


func _win_rects() -> Array:
	var ws: Array = os.windows()
	var area := _win_area()
	var out: Array = []
	if ws.is_empty():
		return out
	var w := minf(120.0, area.size.x / ws.size())
	for i in ws.size():
		out.append(Rect2(area.position.x + i * w, area.position.y + 1, w - 1, area.size.y - 2))
	return out


func _tray() -> Rect2:
	return Rect2(size.x - 18, 1, 17, size.y - 2)


func _note_rect() -> Rect2:
	var t := _tray()
	return Rect2(t.position.x + 2, 3, 10, 10)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.PETROL_D)
	draw_line(Vector2(0, 0.5), Vector2(size.x, 0.5), Color(P.FACE_D, 0.5))
	var ws: Array = os.windows()
	var rs := _win_rects()
	for i in rs.size():
		var w: Control = ws[i]
		var r: Rect2 = rs[i]
		var on: bool = w.active and not w.minimized
		draw_rect(r, P.COPPER if on else P.PETROL_L)
		draw_rect(r, Color(P.FACE_L, 0.35), false, 1.0)
		P.icon(self, w.icon, r.position + Vector2(3, 2), 10.0)
		P.text(self, r.position + Vector2(16, 2), P.fit(w.title.to_upper(), r.size.x - 18), P.FACE_L)
	P.icon(self, "note", _note_rect().position, 10.0)


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var p: Vector2 = e.position
	if p.x < START_W + 3:
		os.toggle_start()
		return
	for i in QUICK.size():
		if _quick_rect(i).grow(1).has_point(p):
			os.launch(QUICK[i][0])
			return
	if _note_rect().grow(2).has_point(p):
		os.launch("notepad", "/home/citizen/commands.txt")
		return
	var ws: Array = os.windows()
	var rs := _win_rects()
	for i in rs.size():
		if (rs[i] as Rect2).has_point(p):
			var w: Control = ws[i]
			os.close_menus()
			if w.active and not w.minimized:
				w.set_minimized(true)
				var t: Control = os.top_window()
				if t:
					os.focus_window(t)
			else:
				os.focus_window(w)
			queue_redraw()
			return
	os.close_menus()
