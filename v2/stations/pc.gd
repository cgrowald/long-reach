extends "res://v2/stations/station.gd"
## The PC: HEARTH OS fills the CRT (v2/os/desktop.gd). Using it costs no time.
## Boots once per session; Esc closes a menu, then leaves the PC.

const Desktop := preload("res://v2/os/desktop.gd")

var desktop: Control
var _glass: Control
const BEZEL := 5.0


func build() -> void:
	var bezel := Control.new()
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.draw.connect(func() -> void:
		bezel.draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.15, 0.14))
		bezel.draw_rect(Rect2(Vector2.ONE * (BEZEL - 1), size - Vector2.ONE * (BEZEL - 1) * 2), Color(0.05, 0.05, 0.05), false, 1.0))
	add_child(bezel)
	desktop = Desktop.new()
	desktop.position = Vector2.ONE * BEZEL
	desktop.size = size - Vector2.ONE * BEZEL * 2.0
	add_child(desktop)
	desktop.on_leave = close
	desktop.on_war = func() -> void: garage.open_screen("warroom")
	desktop.spend_hours = func(h: float) -> bool: return garage.spend(h)
	var booted: bool = game.get_meta("os_booted", false)
	desktop.setup(game, booted)
	game.set_meta("os_booted", true)
	# the glass: scanlines and a soft vignette so it still reads as a CRT in the garage
	_glass = Control.new()
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.draw.connect(_draw_glass)
	add_child(_glass)


func _draw_glass() -> void:
	var r := Rect2(Vector2.ONE * BEZEL, size - Vector2.ONE * BEZEL * 2.0)
	for y in range(int(r.position.y) + 1, int(r.end.y), 2):
		_glass.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.07))
	for i in 6:
		_glass.draw_rect(r.grow(-i), Color(0, 0, 0, 0.09), false, 1.0)


func back() -> bool:
	return desktop.back()


## Keep the garage's movement keys (A, D, S, Backspace...) from leaving the PC while you use it.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k: int = event.keycode
		if k in [KEY_ESCAPE, KEY_F1, KEY_F3, KEY_F5, KEY_F10]:
			return
		get_viewport().set_input_as_handled()
