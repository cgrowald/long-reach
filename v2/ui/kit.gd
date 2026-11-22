extends RefCounted
## UI building blocks for the pixel layer: the theme, metal panels, buttons with sound, labels.

const Pal := preload("res://v2/ui/pal.gd")

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Pal.theme().duplicate()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.065, 0.075, 0.96)
	panel.border_color = Pal.METAL_L
	panel.set_border_width_all(1)
	panel.set_content_margin_all(6)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 4
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", Pal.TEXT)
	t.set_font_size("font_size", "Label", 10)
	var n: StyleBoxFlat = t.get_stylebox("normal", "Button").duplicate()
	n.set_content_margin_all(3)
	n.content_margin_left = 6
	n.content_margin_right = 6
	var h: StyleBoxFlat = t.get_stylebox("hover", "Button").duplicate()
	h.content_margin_left = 6
	h.content_margin_right = 6
	h.border_color = Pal.AMBER
	var p: StyleBoxFlat = t.get_stylebox("pressed", "Button").duplicate()
	p.content_margin_left = 6
	p.content_margin_right = 6
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color(0.1, 0.1, 0.1)
	d.border_color = Pal.METAL_D
	t.set_stylebox("normal", "Button", n)
	t.set_stylebox("hover", "Button", h)
	t.set_stylebox("pressed", "Button", p)
	t.set_stylebox("disabled", "Button", d)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Pal.DIM.darkened(0.3))
	# Sliders and toggles.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.03, 0.035)
	track.border_color = Pal.METAL_D
	track.set_border_width_all(1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Pal.BRASS.darkened(0.2)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _grabber()
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	t.set_color("font_color", "CheckButton", Pal.TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _toggle(true))
	t.set_icon("unchecked", "CheckButton", _toggle(false))
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	var sep := StyleBoxLine.new()
	sep.color = Pal.METAL_D
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


static func _grabber() -> ImageTexture:
	var img := Image.create(5, 9, false, Image.FORMAT_RGBA8)
	img.fill(Pal.BRASS)
	for y in 9:
		img.set_pixel(0, y, Pal.BRASS.lightened(0.3))
		img.set_pixel(4, y, Pal.BRASS.darkened(0.4))
	return ImageTexture.create_from_image(img)


static func _toggle(on: bool) -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.035))
	for x in 16:
		img.set_pixel(x, 0, Pal.METAL_D)
		img.set_pixel(x, 7, Pal.METAL_L)
	var x0 := 9 if on else 1
	for y in range(1, 7):
		for x in range(x0, x0 + 6):
			img.set_pixel(x, y, Pal.GREEN if on else Pal.METAL)
	return ImageTexture.create_from_image(img)


## A centred metal panel with a title. Returns the content VBox. The panel itself is the VBox's grandparent.
static func panel(parent: Control, title: String, min_size := Vector2(180, 0)) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	center.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	if title != "":
		v.add_child(label(title, Pal.PHOS, 14))
		v.add_child(HSeparator.new())
	return v


static func label(text: String, col := Pal.TEXT, size := 10, wrap_width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	return l


static func button(text: String, cb: Callable, game: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func() -> void:
		if game and not b.disabled:
			game.hover())
	b.pressed.connect(func() -> void:
		if game:
			game.click()
		cb.call())
	return b


static func row(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	parent.add_child(h)
	return h


## Dark full-screen backdrop that eats clicks.
static func dim(parent: Control, alpha := 0.55) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.01, 0.03, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	return r
