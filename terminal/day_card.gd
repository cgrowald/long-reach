extends Control
## Full-screen story card between nights: typed text, choices, results. Also used for the title and the end.

signal finished
signal chosen(index: int)

const T := preload("res://terminal/os_theme.gd")
const TYPE_SPEED := 90.0   # characters per second

var state
var _sections: Array = []
var _i := -1
var _title: Label
var _text: Label
var _buttons: VBoxContainer
var _typing := false
var _after_type: Callable


func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.position = Vector2(size.x / 2 - 420, 120)
	col.custom_minimum_size = Vector2(840, 0)
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	_title = T.label("", 30, Color(0.9, 0.78, 0.4))
	col.add_child(_title)
	_text = T.label("", 20, Color(0.88, 0.88, 0.85))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(840, 0)
	col.add_child(_text)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	col.add_child(_buttons)


func _process(d: float) -> void:
	if not _typing:
		return
	_text.visible_characters += maxi(1, int(TYPE_SPEED * d))
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_typing()


func _gui_input(e: InputEvent) -> void:
	if _typing and e is InputEventMouseButton and e.pressed:
		_finish_typing()


func _unhandled_key_input(e: InputEvent) -> void:
	if _typing and e.pressed and (e.keycode == KEY_SPACE or e.keycode == KEY_ENTER):
		_finish_typing()


func _type(title: String, text: String, then: Callable) -> void:
	for b in _buttons.get_children():
		b.queue_free()
	if title != "":
		_title.text = title
	_text.text = text
	_text.visible_characters = 0
	_typing = true
	_after_type = then


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	if _after_type.is_valid():
		var c := _after_type
		_after_type = Callable()
		c.call()


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", T.box(Color(0.1, 0.1, 0.11), Color(0.3, 0.3, 0.32), 1, 3))
	b.add_theme_stylebox_override("hover", T.box(Color(0.15, 0.14, 0.12), Color(0.9, 0.78, 0.4), 1, 3))
	b.add_theme_stylebox_override("pressed", T.box(Color(0.2, 0.17, 0.1), Color(0.9, 0.78, 0.4), 1, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0.9, 0.88, 0.82))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_buttons.add_child(b)


# ------------------------------------------------------------- title / end

func show_title(title: String, text: String, options: Array) -> void:
	_type(title, text, func():
		for i in options.size():
			var idx := i
			_button(str(options[i]["text"]), func(): chosen.emit(idx)))


# ------------------------------------------------------------- day story

func play(st, sections: Array) -> void:
	state = st
	_sections = sections
	_i = -1
	var dd: Dictionary = state.date_dict()
	var months := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
	_title.text = "%s   %d %s %d" % [str(state.day_def().get("weekday", "")).to_upper(), int(dd["day"]), months[int(dd["month"]) - 1], int(dd["year"])]
	_next()


func _next() -> void:
	_i += 1
	while _i < _sections.size() and not state.cond(_sections[_i].get("if", {})):
		_i += 1
	if _i >= _sections.size():
		finished.emit()
		return
	var s: Dictionary = _sections[_i]
	state.do_actions(s.get("do", []))
	var choices: Array = s.get("choices", []).filter(func(c): return state.cond(c.get("if", {})))
	_type(str(s.get("title", "")), str(s.get("text", "")), func():
		if choices.is_empty():
			_button("Continue", _next)
		else:
			for c in choices:
				var ch: Dictionary = c
				_button(str(ch["text"]), func(): _choose(ch)))


func _choose(c: Dictionary) -> void:
	state.do_actions(c.get("do", []))
	if c.has("result"):
		_type("", str(c["result"]), func(): _button("Continue", _next))
	else:
		_next()
