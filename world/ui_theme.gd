extends RefCounted
## Shared look for the strategy screens (map, HQ, after-action report): a DIN-style font
## (Bahnschrift ships with Windows) and flat dark buttons with gold highlights.

const GOLD := Color(1.0, 0.8, 0.32)

static var _theme: Theme


static func make() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	t.default_font = f
	t.default_font_size = 16

	t.set_stylebox("normal", "Button", _box(Color(0.1, 0.13, 0.16), Color(0.24, 0.3, 0.36)))
	t.set_stylebox("hover", "Button", _box(Color(0.14, 0.18, 0.22), Color(GOLD, 0.75)))
	t.set_stylebox("pressed", "Button", _box(Color(0.22, 0.18, 0.08), GOLD))
	t.set_stylebox("hover_pressed", "Button", _box(Color(0.22, 0.18, 0.08), GOLD))
	t.set_stylebox("disabled", "Button", _box(Color(0.07, 0.09, 0.11), Color(0.14, 0.17, 0.2)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.9, 0.92, 0.94))
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.38, 0.42, 0.46))

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.3, 0.36, 0.42)
	grabber.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.1, 0.12)
	track.content_margin_left = 4
	track.content_margin_right = 4
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", track)
	_theme = t
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
