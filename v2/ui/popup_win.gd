extends Control
## A small window over the fight screen that you drag by its title bar (the vault terminal, the vault
## camera, the PC prompt). The owner draws the body (draw_body(win, body_rect)) and gets clicks on it
## (click_body(local_pos)); buttons drawn with button() emit `pressed`.

signal pressed(id: String)

const Pal := preload("res://v2/ui/pal.gd")
const BAR := 13.0

var title := ""
var draw_body: Callable
var click_body: Callable
var accent := Color(0.95, 0.72, 0.3)
var _buttons: Array = []          # [Rect2, id], local, rebuilt every draw
var _drag := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func body_rect() -> Rect2:
	return Rect2(3, BAR + 2, size.x - 6, size.y - BAR - 5)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	_buttons = []
	draw_rect(Rect2(Vector2(2, 2), size), Color(0, 0, 0, 0.35))          # a drop shadow
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.97))
	draw_rect(Rect2(0, 0, size.x, BAR), Color(0.16, 0.15, 0.13))
	draw_rect(Rect2(Vector2.ZERO, size), accent, false, 1.0)
	Pal.text(self, Vector2(5, 2), title, 8, Color(0.9, 0.87, 0.78), HORIZONTAL_ALIGNMENT_LEFT, size.x - 30)
	for k in 3:                                                         # the grip
		draw_rect(Rect2(size.x - 18 + k * 4, 5, 2, 3), Color(0.6, 0.58, 0.52))
	if draw_body.is_valid():
		draw_body.call(self, body_rect())


func button(r: Rect2, label: String, id: String, primary := true) -> void:
	var hov := r.has_point(get_local_mouse_position())
	var c := accent if primary else Color(0.35, 0.34, 0.31)
	draw_rect(r, c.lightened(0.15) if hov else c)
	Pal.text(self, r.position + Vector2(0, (r.size.y - 10) * 0.5), label, 8, Color(0.08, 0.07, 0.06) if primary else Color(0.92, 0.9, 0.84), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_buttons.append([r, id])


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and _drag:
		position += e.relative
		var ps: Vector2 = get_parent_area_size()
		position = position.clamp(Vector2(-size.x + 40, 0), ps - Vector2(40, BAR))
		accept_event()
		return
	if not (e is InputEventMouseButton):
		return
	accept_event()
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if not e.pressed:
		_drag = false
		return
	if e.position.y < BAR:
		_drag = true
		return
	for b in _buttons:
		if (b[0] as Rect2).has_point(e.position):
			pressed.emit(str(b[1]))
			return
	if click_body.is_valid():
		click_body.call(e.position)
