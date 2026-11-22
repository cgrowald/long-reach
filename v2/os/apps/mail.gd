extends "res://v2/os/app.gd"
## Mail: inbox on the left, the message on the right. Read mails are remembered in the save.

var _list: VBoxContainer
var _from: Label
var _subject: Label
var _body: Label
var _sel := -1


func build() -> void:
	var h := HSplitContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.split_offset = 0
	add_child(h)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 104
	left.add_theme_stylebox_override("panel", _well())
	h.add_child(left)
	_list = VBoxContainer.new()
	left.add_child(_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _well())
	h.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	_from = P.label("", P.INK_DIM)
	_subject = P.label("Select a message.", P.INK)
	_body = P.label("", P.INK, 150)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(_from)
	rv.add_child(_subject)
	rv.add_child(HSeparator.new())
	rv.add_child(_body)
	_fill()


func _well() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.WIN
	sb.border_color = P.FACE_D
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	return sb


func _mails() -> Array:
	return Fs.data().get("mail", [])


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var read: Array = state().os.get("read_mail", [])
	var ms := _mails()
	for i in ms.size():
		var m: Dictionary = ms[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(96, 0)
		var unread := not read.has(i)
		b.text = ("* " if unread else "  ") + str(m["from"])
		if i == _sel:
			b.add_theme_color_override("font_color", P.SEL)
		b.pressed.connect(func() -> void: show_mail(i))
		_list.add_child(b)
	var unread_n := ms.size() - read.size()
	win.title = "Mail (%d unread)" % maxi(0, unread_n) if unread_n > 0 else "Mail"
	win.queue_redraw()


func show_mail(i: int) -> void:
	var m: Dictionary = _mails()[i]
	_sel = i
	_from.text = "From: " + str(m["from"])
	_subject.text = str(m.get("subject", ""))
	_body.text = str(m.get("body", ""))
	_body.custom_minimum_size.x = maxf(80.0, size.x - 124.0)
	var read: Array = state().os.get("read_mail", [])
	if not read.has(i):
		read.append(i)
		state().os["read_mail"] = read
	os.game.click()
	_fill()
