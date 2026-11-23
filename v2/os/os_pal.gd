extends RefCounted
## HEARTH OS look: ReactOS / Win2000 grey bevels, Unity orange for the state brand, an old-Linux steel desktop.
## Drawn at the game's pixel resolution, so everything is small (8 px text, 16 px icons).

const Pal := preload("res://v2/ui/pal.gd")

const FACE := Color(0.76, 0.75, 0.72)
const FACE_L := Color(0.96, 0.95, 0.91)
const FACE_D := Color(0.45, 0.44, 0.42)
const SHADOW := Color(0.12, 0.12, 0.14)
const WIN := Color(0.97, 0.96, 0.93)
const INK := Color(0.08, 0.08, 0.1)
const INK_DIM := Color(0.38, 0.38, 0.4)
const TITLE_A := Color(0.07, 0.14, 0.4)
const TITLE_B := Color(0.32, 0.47, 0.74)
const TITLE_OFF_A := Color(0.42, 0.42, 0.44)
const TITLE_OFF_B := Color(0.66, 0.66, 0.66)
const SEL := Color(0.16, 0.27, 0.58)
const BRAND := Color(0.9, 0.42, 0.15)       # the state orange
const LINK := Color(0.1, 0.2, 0.75)
const BAD := Color(0.75, 0.12, 0.1)
const GOOD := Color(0.1, 0.5, 0.15)

## Wallpapers: [top, bottom, line] colours. Index saved in state.os.wallpaper.
const WALLPAPERS := [
	{"name": "Civic Steel", "a": Color(0.42, 0.5, 0.62), "b": Color(0.17, 0.21, 0.3), "line": Color(0.75, 0.82, 0.92, 0.18)},
	{"name": "Hearth Dawn", "a": Color(0.42, 0.12, 0.27), "b": Color(0.86, 0.38, 0.18), "line": Color(1.0, 0.8, 0.7, 0.16)},
	{"name": "Ministry Grey", "a": Color(0.5, 0.5, 0.49), "b": Color(0.26, 0.26, 0.27), "line": Color(1, 1, 1, 0.12)},
]

const FS := 9   # font size everywhere in the OS

static var _theme: Theme
static var _font: Font
static var _mono: Font


## The game's one font (v2/ui/pal.gd): a smoothed monospace, like the user's concept sheets.
static func font() -> Font:
	if _font == null:
		_font = Pal.font()
	return _font


## The terminal uses the same monospace.
static func mono() -> Font:
	if _mono == null:
		_mono = Pal.font()
	return _mono


static func text(ci: CanvasItem, pos: Vector2, s: String, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font()
	ci.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(FS)).round(), s, align, width, FS, col)


## Width of a string in the OS font.
static func tw(s: String) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x


## Cut a string to fit a width, ending in "..".
static func fit(s: String, w: float) -> String:
	if tw(s) <= w:
		return s
	var t := s
	while t.length() > 1 and tw(t + "..") > w:
		t = t.substr(0, t.length() - 1)
	return t + ".."


## Raised (or sunken) Win2000 bevel.
static func bevel(ci: CanvasItem, r: Rect2, col := FACE, raised := true) -> void:
	ci.draw_rect(r, col)
	var hi := FACE_L if raised else SHADOW
	var lo := SHADOW if raised else FACE_L
	ci.draw_line(r.position, Vector2(r.end.x - 1, r.position.y), hi)
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y - 1), hi)
	ci.draw_line(Vector2(r.position.x, r.end.y - 1), Vector2(r.end.x - 1, r.end.y - 1), lo)
	ci.draw_line(Vector2(r.end.x - 1, r.position.y), Vector2(r.end.x - 1, r.end.y - 1), lo)


## Horizontal gradient bar (title bars), drawn in a few hard steps so it dithers in the pixel look.
static func grad_h(ci: CanvasItem, r: Rect2, a: Color, b: Color, steps := 12) -> void:
	var w := r.size.x / steps
	for i in steps:
		ci.draw_rect(Rect2(r.position.x + i * w, r.position.y, w + 1.0, r.size.y), a.lerp(b, float(i) / (steps - 1)))


static func grad_v(ci: CanvasItem, r: Rect2, a: Color, b: Color, steps := 24) -> void:
	var h := r.size.y / steps
	for i in steps:
		ci.draw_rect(Rect2(r.position.x, r.position.y + i * h, r.size.x, h + 1.0), a.lerp(b, float(i) / (steps - 1)))


## The theme for real controls inside windows (buttons, fields, text areas, scroll bars).
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FS
	var btn := StyleBoxFlat.new()
	btn.bg_color = FACE
	btn.border_color = FACE_D
	btn.set_border_width_all(1)
	btn.border_width_top = 1
	btn.set_content_margin_all(2)
	btn.content_margin_left = 4
	btn.content_margin_right = 4
	var hov := btn.duplicate() as StyleBoxFlat
	hov.bg_color = FACE.lightened(0.12)
	var prs := btn.duplicate() as StyleBoxFlat
	prs.bg_color = FACE.darkened(0.15)
	prs.border_color = SHADOW
	var dis := btn.duplicate() as StyleBoxFlat
	dis.bg_color = FACE.lightened(0.05)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = {"normal": btn, "hover": hov, "pressed": prs, "disabled": dis, "focus": StyleBoxEmpty.new()}[k]
		t.set_stylebox(k, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_DIM)
	var field := StyleBoxFlat.new()
	field.bg_color = WIN
	field.border_color = FACE_D
	field.set_border_width_all(1)
	field.set_content_margin_all(2)
	for c in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", c, field)
		t.set_stylebox("focus", c, field)
		t.set_stylebox("read_only", c, field)
		t.set_color("font_color", c, INK)
		t.set_color("font_readonly_color", c, INK_DIM)
		t.set_color("caret_color", c, INK)
		t.set_color("selection_color", c, Color(SEL, 0.45))
		t.set_color("font_placeholder_color", c, INK_DIM)
	t.set_color("font_color", "Label", INK)
	var link := StyleBoxEmpty.new()
	t.set_stylebox("focus", "LinkButton", link)
	t.set_color("font_color", "LinkButton", LINK)
	t.set_color("font_hover_color", "LinkButton", BRAND)
	var sc := StyleBoxFlat.new()
	sc.bg_color = FACE.lightened(0.1)
	var grab := StyleBoxFlat.new()
	grab.bg_color = FACE_D
	for c in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", c, sc)
		t.set_stylebox("grabber", c, grab)
		t.set_stylebox("grabber_highlight", c, grab)
		t.set_stylebox("grabber_pressed", c, grab)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 2)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", FS)
	t.set_font("normal_font", "RichTextLabel", font())
	_theme = t
	return t


static func label(s: String, col := INK, width := 0.0) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", FS)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
	return l


# ------------------------------------------------------------------ icons (16 x 16, drawn)

## kind: folder, file, text, image, computer, home, trash, terminal, globe, mail, note, package, chart, gear,
## program, lock, war, drive, user, info, warn, monitor, mouse, clock, sound, network, paint
static func icon(ci: CanvasItem, kind: String, p: Vector2, s := 16.0) -> void:
	var k := s / 16.0
	var R := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(p + Vector2(x, y) * k, Vector2(w, h) * k), c)
	var O := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(p + Vector2(x, y) * k, Vector2(w, h) * k), c, false, 1.0)
	match kind:
		"folder", "home":
			R.call(1, 4, 6, 2, Color(0.85, 0.66, 0.25))
			R.call(1, 5, 14, 9, Color(0.95, 0.76, 0.3))
			R.call(1, 7, 14, 7, Color(0.99, 0.84, 0.4))
			O.call(1, 5, 14, 9, Color(0.45, 0.32, 0.1))
			if kind == "home":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(8, 6) * k, p + Vector2(4, 10) * k, p + Vector2(12, 10) * k]), BAD)
				R.call(5, 10, 6, 3, FACE_L)
		"file", "text", "note", "image", "program":
			var paper := Color(1.0, 0.93, 0.45) if kind == "note" else FACE_L
			R.call(3, 1, 10, 14, paper)
			O.call(3, 1, 10, 14, INK_DIM)
			if kind == "image":
				R.call(4, 4, 8, 6, Color(0.4, 0.6, 0.85))
				R.call(4, 8, 8, 2, Color(0.3, 0.55, 0.25))
				R.call(9, 5, 2, 2, Color(1, 0.9, 0.4))
			elif kind == "program":
				R.call(4, 4, 8, 7, SHADOW)
				R.call(5, 5, 2, 1, Color(0.4, 1, 0.4))
				R.call(5, 7, 4, 1, Color(0.4, 1, 0.4))
			else:
				for i in 4:
					R.call(5, 4 + i * 2.5, 6 if i % 2 else 5, 1, INK_DIM)
		"computer", "monitor":
			R.call(1, 2, 14, 9, FACE)
			O.call(1, 2, 14, 9, INK_DIM)
			R.call(2, 3, 12, 7, Color(0.25, 0.42, 0.7))
			R.call(5, 11, 6, 2, FACE_D)
			R.call(3, 13, 10, 2, FACE)
		"drive":
			R.call(1, 5, 14, 7, FACE)
			O.call(1, 5, 14, 7, INK_DIM)
			R.call(11, 8, 2, 1, Color(0.3, 0.9, 0.3))
		"trash":
			R.call(3, 4, 10, 2, FACE_D)
			R.call(4, 6, 8, 9, FACE)
			O.call(4, 6, 8, 9, INK_DIM)
			for i in 3:
				R.call(5.5 + i * 2, 7, 1, 7, FACE_D)
			R.call(6, 2, 4, 2, FACE_D)
		"terminal":
			R.call(1, 2, 14, 12, SHADOW)
			O.call(1, 2, 14, 12, FACE_D)
			R.call(1, 2, 14, 2, FACE_D)
			ci.draw_line(p + Vector2(3, 6) * k, p + Vector2(5, 8) * k, Color(0.4, 1, 0.4))
			ci.draw_line(p + Vector2(5, 8) * k, p + Vector2(3, 10) * k, Color(0.4, 1, 0.4))
			R.call(7, 10, 4, 1, Color(0.4, 1, 0.4))
		"globe", "network":
			ci.draw_circle(p + Vector2(8, 8) * k, 6.5 * k, Color(0.3, 0.55, 0.9))
			R.call(4, 5, 4, 3, Color(0.35, 0.7, 0.3))
			R.call(8, 9, 4, 3, Color(0.35, 0.7, 0.3))
			ci.draw_arc(p + Vector2(8, 8) * k, 6.5 * k, 0, TAU, 14, Color(0.1, 0.2, 0.45), 1.0)
		"mail":
			R.call(1, 4, 14, 9, FACE_L)
			O.call(1, 4, 14, 9, INK_DIM)
			ci.draw_line(p + Vector2(1, 4) * k, p + Vector2(8, 9) * k, INK_DIM)
			ci.draw_line(p + Vector2(15, 4) * k, p + Vector2(8, 9) * k, INK_DIM)
		"package":
			R.call(2, 4, 12, 10, Color(0.75, 0.55, 0.3))
			O.call(2, 4, 12, 10, Color(0.4, 0.28, 0.12))
			R.call(7, 4, 2, 10, Color(0.9, 0.8, 0.55))
			R.call(4, 2, 8, 2, Color(0.65, 0.45, 0.25))
		"chart":
			R.call(1, 2, 14, 12, SHADOW)
			for i in 5:
				var hh: float = [3, 6, 4, 8, 5][i]
				R.call(2.5 + i * 2.5, 13 - hh, 1.5, hh, Color(0.4, 1, 0.4))
		"gear", "paint":
			ci.draw_circle(p + Vector2(8, 8) * k, 5.5 * k, FACE_D)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_circle(p + (Vector2(8, 8) + Vector2(cos(a), sin(a)) * 6.0) * k, 1.4 * k, FACE_D)
			ci.draw_circle(p + Vector2(8, 8) * k, 2.2 * k, FACE_L)
			if kind == "paint":
				R.call(10, 9, 5, 5, BRAND)
		"lock", "war":
			ci.draw_arc(p + Vector2(8, 6) * k, 3.5 * k, PI, TAU, 8, FACE_D, 2.0)
			R.call(3, 7, 10, 8, Color(0.8, 0.65, 0.25) if kind == "lock" else BAD)
			R.call(7, 9, 2, 3, SHADOW)
		"user":
			ci.draw_circle(p + Vector2(8, 5) * k, 3.2 * k, Color(0.9, 0.75, 0.6))
			R.call(3, 9, 10, 6, Color(0.3, 0.4, 0.6))
		"info", "warn":
			ci.draw_circle(p + Vector2(8, 8) * k, 7 * k, Color(0.2, 0.35, 0.8) if kind == "info" else Color(0.9, 0.7, 0.1))
			R.call(7, 3, 2, 7, Color.WHITE if kind == "info" else INK)
			R.call(7, 11, 2, 2, Color.WHITE if kind == "info" else INK)
		"mouse":
			R.call(5, 3, 6, 10, FACE_L)
			O.call(5, 3, 6, 10, INK_DIM)
			R.call(8, 3, 1, 4, INK_DIM)
		"clock":
			ci.draw_circle(p + Vector2(8, 8) * k, 6.5 * k, FACE_L)
			ci.draw_arc(p + Vector2(8, 8) * k, 6.5 * k, 0, TAU, 14, INK_DIM, 1.0)
			ci.draw_line(p + Vector2(8, 8) * k, p + Vector2(8, 4) * k, INK)
			ci.draw_line(p + Vector2(8, 8) * k, p + Vector2(11, 9) * k, INK)
		"sound":
			R.call(2, 6, 4, 4, FACE_D)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(5, 6) * k, p + Vector2(10, 2) * k, p + Vector2(10, 14) * k, p + Vector2(5, 10) * k]), FACE_D)
			ci.draw_arc(p + Vector2(10, 8) * k, 4 * k, -0.9, 0.9, 6, INK_DIM, 1.0)
		"target":
			ci.draw_circle(p + Vector2(8, 8) * k, 7 * k, SHADOW)
			ci.draw_arc(p + Vector2(8, 8) * k, 5.5 * k, 0, TAU, 14, Color(0.4, 1, 0.4), 1.0)
			ci.draw_arc(p + Vector2(8, 8) * k, 2.5 * k, 0, TAU, 10, Color(0.4, 1, 0.4), 1.0)
			R.call(7.5, 1, 1, 4, Color(0.4, 1, 0.4))
			R.call(7.5, 11, 1, 4, Color(0.4, 1, 0.4))
			R.call(1, 7.5, 4, 1, Color(0.4, 1, 0.4))
			R.call(11, 7.5, 4, 1, Color(0.4, 1, 0.4))
		"hearth":
			ci.draw_circle(p + Vector2(8, 8) * k, 7 * k, BRAND)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(8, 3) * k, p + Vector2(11, 10) * k, p + Vector2(8, 13) * k, p + Vector2(5, 10) * k]), Color(1, 0.9, 0.5))
		_:
			R.call(2, 2, 12, 12, FACE)
			O.call(2, 2, 12, 12, INK_DIM)
