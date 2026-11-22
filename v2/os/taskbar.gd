extends Control
## The bottom bar: HEARTH start button, quick launch, one button per window, tray (notes, network, clock).

const P := preload("res://v2/os/os_pal.gd")

const START_W := 50.0
const QUICK := [["terminal", "terminal"], ["browser", "globe"], ["files", "folder"]]

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
	var x0 := START_W + 4 + QUICK.size() * 12 + 4
	return Rect2(x0, 1, size.x - x0 - 86, size.y - 2)


func _win_rects() -> Array:
	var ws: Array = os.windows()
	var area := _win_area()
	var out: Array = []
	if ws.is_empty():
		return out
	var w := minf(72.0, area.size.x / ws.size())
	for i in ws.size():
		out.append(Rect2(area.position.x + i * w, area.position.y + 1, w - 1, area.size.y - 2))
	return out


func _tray() -> Rect2:
	return Rect2(size.x - 82, 1, 81, size.y - 2)


func _note_rect() -> Rect2:
	var t := _tray()
	return Rect2(t.position.x + 2, 3, 10, 10)


func _draw() -> void:
	P.bevel(self, Rect2(Vector2.ZERO, size), P.FACE, true)
	# start button
	var sr := Rect2(2, 1, START_W, size.y - 2)
	var open: bool = os.start_menu != null and is_instance_valid(os.start_menu)
	P.bevel(self, sr, P.FACE, not open)
	P.icon(self, "hearth", sr.position + Vector2(2, 2), 10.0)
	P.text(self, sr.position + Vector2(14, 2), "HEARTH", P.INK)
	draw_line(Vector2(START_W + 2, 2), Vector2(START_W + 2, size.y - 2), P.FACE_D)
	for i in QUICK.size():
		P.icon(self, QUICK[i][1], _quick_rect(i).position, 10.0)
	# window buttons
	var ws: Array = os.windows()
	var rs := _win_rects()
	for i in rs.size():
		var w: Control = ws[i]
		var r: Rect2 = rs[i]
		var pressed: bool = w.active and not w.minimized
		P.bevel(self, r, P.FACE.lightened(0.08) if pressed else P.FACE, not pressed)
		P.icon(self, w.icon, r.position + Vector2(2, 2), 9.0)
		P.text(self, r.position + Vector2(13, 1), P.fit(w.title, r.size.x - 15), P.INK)
	# tray
	var tr := _tray()
	P.bevel(self, tr, P.FACE, false)
	P.icon(self, "note", _note_rect().position, 10.0)
	var watched := fmod(_blink, 3.0) < 0.25
	P.icon(self, "network", tr.position + Vector2(14, 2), 10.0)
	if watched:
		draw_circle(tr.position + Vector2(23, 3), 2.0, P.BAD)
	P.text(self, Vector2(tr.position.x + 28, 3), os.game.state.clock_text(), P.INK, HORIZONTAL_ALIGNMENT_RIGHT, tr.size.x - 31)


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
