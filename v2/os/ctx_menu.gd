extends Control
## A right-click menu: items = [[label, Callable], ...]. A label of "-" draws a separator.

const P := preload("res://v2/os/os_pal.gd")
const ROW := 11.0

var os: Control
var items: Array = []
var _hover := -1


func setup(p_os: Control, p_items: Array) -> void:
	os = p_os
	items = p_items
	mouse_filter = Control.MOUSE_FILTER_STOP
	var w := 60.0
	for it in items:
		w = maxf(w, str(it[0]).length() * 4.6 + 16.0)
	size = Vector2(w, items.size() * ROW + 4)


func _draw() -> void:
	P.bevel(self, Rect2(Vector2.ZERO, size), P.FACE, true)
	for i in items.size():
		var y := 2.0 + i * ROW
		var lab: String = items[i][0]
		if lab == "-":
			draw_line(Vector2(4, y + ROW * 0.5), Vector2(size.x - 4, y + ROW * 0.5), P.FACE_D)
			continue
		if i == _hover:
			draw_rect(Rect2(2, y, size.x - 4, ROW), P.SEL)
		P.text(self, Vector2(8, y + 1), lab, Color.WHITE if i == _hover else P.INK)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := int((e.position.y - 2.0) / ROW)
		_hover = h if h >= 0 and h < items.size() else -1
		queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		accept_event()
		var i := int((e.position.y - 2.0) / ROW)
		if i >= 0 and i < items.size() and str(items[i][0]) != "-":
			var cb: Callable = items[i][1]
			os.close_menus()
			os.game.click()
			cb.call()
