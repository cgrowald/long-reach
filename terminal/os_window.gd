extends Panel
## A HEARTH OS window: draggable title bar, close button, a content area.

signal closed
signal focused

const T := preload("res://terminal/os_theme.gd")
const TITLE_H := 26

var app_id: String = ""
var title_label: Label
var content: MarginContainer
var _dragging := false
var _drag_off := Vector2.ZERO
var _active := true


func setup(title: String, id: String, size_px: Vector2) -> void:
	app_id = id
	size = size_px
	custom_minimum_size = Vector2(200, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_style()

	var bar := Panel.new()
	bar.name = "Bar"
	bar.position = Vector2(2, 2)
	bar.size = Vector2(size_px.x - 4, TITLE_H)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_bar_input)
	add_child(bar)
	title_label = T.label(title, 14, Color.WHITE)
	title_label.position = Vector2(8, 4)
	bar.add_child(title_label)
	var x := Button.new()
	x.text = "x"
	x.focus_mode = Control.FOCUS_NONE
	x.size = Vector2(22, 20)
	x.position = Vector2(size_px.x - 4 - 25, 3)
	x.add_theme_font_size_override("font_size", 13)
	x.pressed.connect(close)
	bar.add_child(x)

	content = MarginContainer.new()
	content.position = Vector2(4, TITLE_H + 4)
	content.size = Vector2(size_px.x - 8, size_px.y - TITLE_H - 8)
	for s in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + s, 4)
	add_child(content)
	set_active(true)


func set_active(on: bool) -> void:
	_active = on
	var bar: Panel = get_node_or_null("Bar")
	if bar:
		var s := StyleBoxFlat.new()
		s.bg_color = T.TITLE if on else T.TITLE_DIM
		bar.add_theme_stylebox_override("panel", s)


func _set_style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = T.PANEL
	s.border_color = Color(0.2, 0.22, 0.24)
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(3, 3)
	add_theme_stylebox_override("panel", s)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		focused.emit()


func _bar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			focused.emit()
			_dragging = true
			_drag_off = get_global_mouse_position() - global_position
		else:
			_dragging = false
	elif e is InputEventMouseMotion and _dragging:
		var parent_rect: Vector2 = get_parent().size
		var p: Vector2 = get_global_mouse_position() - _drag_off - get_parent().global_position
		p.x = clampf(p.x, -size.x + 80, parent_rect.x - 80)
		p.y = clampf(p.y, 0, parent_rect.y - TITLE_H - 4)
		position = p


func close() -> void:
	closed.emit()
	queue_free()
