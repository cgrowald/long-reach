extends Control
## Base for a HEARTH app inside a window. os = the desktop (launch, alert, game), win = the window.

const P := preload("res://v2/os/os_pal.gd")
const Fs := preload("res://v2/os/fs.gd")

var os: Control
var win: Control
var arg := ""


func setup(p_os: Control, p_win: Control, p_arg: String) -> void:
	os = p_os
	win = p_win
	arg = p_arg
	mouse_filter = Control.MOUSE_FILTER_PASS
	build()


func build() -> void:
	pass


func state() -> RefCounted:
	return os.game.state


## A filled VBox that tracks this app's size (most apps lay out inside one).
func vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	return v


func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		os.game.click()
		cb.call())
	return b


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
