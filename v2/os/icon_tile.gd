extends Control
## An icon with a label: desktop icons, files in a folder, apps in the start menu.
## Click selects, double-click opens. On the desktop the label is white with a shadow.

signal opened
signal picked
signal menu(at: Vector2)

const P := preload("res://v2/os/os_pal.gd")

var kind := "file"
var text := ""
var on_desktop := false
var selected := false
var single_click_opens := false
var dim := false


func setup(p_kind: String, p_text: String, desktop := false, cell := Vector2(44, 32)) -> void:
	kind = p_kind
	text = p_text
	on_desktop = desktop
	custom_minimum_size = cell
	size = cell
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""


func set_selected(on: bool) -> void:
	selected = on
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()
			if e.double_click or single_click_opens:
				opened.emit()
			accept_event()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			picked.emit()
			menu.emit(get_global_mouse_position())
			accept_event()


func _draw() -> void:
	var ip := Vector2(floorf((size.x - 16) * 0.5), 1)
	if selected:
		draw_rect(Rect2(ip - Vector2(1, 1), Vector2(18, 18)), Color(P.SEL, 0.45))
	P.icon(self, kind, ip)
	if dim:
		draw_rect(Rect2(ip, Vector2(16, 16)), Color(P.FACE, 0.5))
	var lines := _wrap(text, int(size.x / 4.6))
	for i in mini(lines.size(), 2):
		var ln: String = lines[i]
		var y := 19.0 + i * 8.0
		var w := ln.length() * 4.6 + 2.0
		var x := (size.x - w) * 0.5
		if selected:
			draw_rect(Rect2(x, y, w, 8), P.SEL)
		if on_desktop and not selected:
			P.text(self, Vector2(x + 2, y + 1), ln, Color(0, 0, 0, 0.8))
		P.text(self, Vector2(x + 1, y), ln, Color.WHITE if (on_desktop or selected) else P.INK)


static func _wrap(s: String, n: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var w: String = word
		if cur == "":
			cur = w
		elif cur.length() + 1 + w.length() <= n:
			cur += " " + w
		else:
			out.append(cur)
			cur = w
	if cur != "":
		out.append(cur)
	for i in out.size():
		var ln: String = out[i]
		if ln.length() > n:
			out[i] = ln.substr(0, maxi(1, n - 1)) + "."
	return out
