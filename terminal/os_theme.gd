extends RefCounted
## Look of HEARTH OS: grey-blue state-issue windows, teal title bars, a plain system font.

const BG := Color(0.11, 0.13, 0.16)
const PANEL := Color(0.86, 0.87, 0.85)
const PANEL_DARK := Color(0.74, 0.76, 0.75)
const TITLE := Color(0.13, 0.33, 0.38)
const TITLE_DIM := Color(0.36, 0.42, 0.45)
const INK := Color(0.08, 0.09, 0.1)
const DIM := Color(0.42, 0.45, 0.48)
const ACCENT := Color(0.79, 0.64, 0.16)
const DANGER := Color(0.75, 0.22, 0.2)

static var _theme: Theme
static var _mono: SystemFont


static func ui_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Tahoma", "Verdana", "Segoe UI", "Arial"])
	f.hinting = TextServer.HINTING_NORMAL
	return f


static func mono() -> SystemFont:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New"])
	return _mono


static func make() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)

	t.set_stylebox("normal", "Button", box(Color(0.9, 0.91, 0.89), Color(0.45, 0.48, 0.5), 1, 2))
	t.set_stylebox("hover", "Button", box(Color(0.96, 0.96, 0.93), TITLE, 1, 2))
	t.set_stylebox("pressed", "Button", box(Color(0.74, 0.78, 0.78), TITLE, 1, 2))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.74, 0.78, 0.78), TITLE, 1, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.84, 0.85, 0.83), Color(0.7, 0.72, 0.72), 1, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", DIM)

	var le := box(Color(1, 1, 1), Color(0.45, 0.48, 0.5), 1, 2)
	le.content_margin_left = 6
	le.content_margin_right = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(Color(1, 1, 1), TITLE, 2, 2))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("selection_color", "LineEdit", Color(0.5, 0.7, 0.75))

	t.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_DARK, 0, 0))
	t.set_stylebox("panel", "ItemList", box(Color(1, 1, 1), Color(0.6, 0.62, 0.62), 1, 2))
	t.set_color("font_color", "ItemList", INK)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_stylebox("selected", "ItemList", box(TITLE, TITLE, 0, 0))
	t.set_stylebox("selected_focus", "ItemList", box(TITLE, TITLE, 0, 0))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())

	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.6, 0.63, 0.64)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.8, 0.81, 0.8)
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab)
		t.set_stylebox("grabber_pressed", sb, grab)
		t.set_stylebox("scroll", sb, track)
	_theme = t
	return t


static func box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func label(text: String, size: int = 15, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
