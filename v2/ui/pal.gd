extends RefCounted
## v2 look: White Knuckle darkness + the user's GPT sheets (2026-11-22 face-lift): warm near-black panels,
## thin amber frames, cream caps, boxed title tags, amber step dots, corner brackets and callouts.

const BG := Color(0.05, 0.035, 0.06)
const DESK := Color(0.09, 0.07, 0.09)
const SCREEN := Color(0.075, 0.03, 0.04)
const SCREEN_LINE := Color(0.45, 0.1, 0.09)
const PHOS := Color(1.0, 0.36, 0.26)
const TEXT := Color(0.94, 0.88, 0.76)
const DIM := Color(0.62, 0.55, 0.46)
const METAL := Color(0.2, 0.16, 0.12)
const METAL_D := Color(0.12, 0.095, 0.075)
const METAL_L := Color(0.42, 0.33, 0.22)
const BRASS := Color(0.86, 0.6, 0.26)
const CHIPS := Color(0.32, 0.64, 1.0)
const MULT := Color(1.0, 0.32, 0.26)
const LAMP_OFF := Color(0.18, 0.1, 0.08)
const AMBER := Color(1.0, 0.72, 0.22)
const GREEN := Color(0.5, 1.0, 0.42)
const PAPER := Color(0.87, 0.82, 0.69)
const INK := Color(0.14, 0.11, 0.1)

static var _font: Font
static var _theme: Theme


## The one font for the whole game (user, 2026-11-22: "I cannot read it"): DejaVu Sans Mono, bundled in
## art/fonts (free licence), smoothed and drawn at full window resolution (see pixel_view.gd).
static func font() -> Font:
	if _font == null:
		var f: FontFile = load("res://art/fonts/DejaVuSansMono.ttf")
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_font = f
	return _font


static var _bold: Font


static func bold() -> Font:
	if _bold == null:
		var f: FontFile = load("res://art/fonts/DejaVuSansMono-Bold.ttf")
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		_bold = f
	return _bold


static func theme() -> Theme:
	if _theme == null:
		var t := Theme.new()
		t.default_font = font()
		t.default_font_size = 10
		var n := StyleBoxFlat.new()
		n.bg_color = METAL_D
		n.border_color = BRASS
		n.set_border_width_all(1)
		n.set_content_margin_all(3)
		var h := n.duplicate() as StyleBoxFlat
		h.bg_color = METAL
		var p := n.duplicate() as StyleBoxFlat
		p.bg_color = BRASS
		t.set_stylebox("normal", "Button", n)
		t.set_stylebox("hover", "Button", h)
		t.set_stylebox("pressed", "Button", p)
		t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		t.set_color("font_color", "Button", TEXT)
		t.set_color("font_hover_color", "Button", Color.WHITE)
		t.set_color("font_pressed_color", "Button", INK)
		_theme = t
	return _theme


## Draw text with its top-left at pos.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font()
	ci.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(size)).round(), s, align, width, size, col)


## A bevelled metal plate.
static func plate(ci: CanvasItem, r: Rect2, col := METAL) -> void:
	ci.draw_rect(r, col)
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), col.lightened(0.25))
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), col.lightened(0.18))
	ci.draw_line(Vector2(r.position.x, r.end.y - 1), r.end - Vector2(0, 1), col.darkened(0.45))
	ci.draw_line(Vector2(r.end.x - 1, r.position.y), r.end - Vector2(1, 0), col.darkened(0.4))


## A recessed (sunken) window.
static func well(ci: CanvasItem, r: Rect2, col := Color(0.04, 0.04, 0.05)) -> void:
	ci.draw_rect(r, col)
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0, 0, 0, 0.8))
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(0, 0, 0, 0.8))
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, METAL_L)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, METAL_L)


static func lamp(ci: CanvasItem, c: Vector2, rad: float, on: bool, col: Color) -> void:
	if on:
		ci.draw_circle(c, rad + 2.0, Color(col, 0.18))
		ci.draw_circle(c, rad, col)
		ci.draw_circle(c + Vector2(-1, -1), rad * 0.35, col.lightened(0.6))
	else:
		ci.draw_circle(c, rad, LAMP_OFF)
		ci.draw_circle(c + Vector2(-1, -1), rad * 0.3, LAMP_OFF.lightened(0.2))
	ci.draw_arc(c, rad, 0, TAU, 12, Color(0, 0, 0, 0.7), 1.0)


static func screw(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c, 2.0, METAL_L)
	ci.draw_line(c + Vector2(-1.5, 0), c + Vector2(1.5, 0), METAL_D)


static func fmt_mult(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return "%d" % int(roundf(m))
	return "%.1f" % m


## Draw wrapped text inside a width, top-left at pos.
static func wrap(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, width: float, max_lines := -1) -> void:
	var f := font()
	ci.draw_multiline_string(f, Vector2(pos.x, pos.y + f.get_ascent(size)).round(), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, col)


# ------------------------------------------------------------------ the sheet look (2026-11-22 face-lift)

## Amber corner brackets round a rect (the "INSPECT" / "FIT COMPONENT" frames on the GPT sheets).
static func brackets(ci: CanvasItem, r: Rect2, col := AMBER, k := 8.0, w := 2.0) -> void:
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		ci.draw_line(p, p + Vector2(d.x * k, 0), col, w)
		ci.draw_line(p, p + Vector2(0, d.y * k), col, w)


## A boxed label with a leader line to `at` (the "CUT PANEL" / "FIT COMPONENT" callouts).
static func callout(ci: CanvasItem, at: Vector2, s: String, box_pos: Vector2, size := 8) -> void:
	var f := font()
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := Rect2(box_pos, Vector2(tw + 10, size + 7))
	var edge := Vector2(clampf(at.x, r.position.x, r.end.x), r.end.y if at.y > r.end.y else r.position.y)
	ci.draw_line(edge, at, AMBER, 1.0)
	ci.draw_circle(at, 2.0, AMBER)
	ci.draw_rect(r, Color(0.07, 0.05, 0.04, 0.92))
	ci.draw_rect(r, AMBER, false, 1.0)
	text(ci, r.position + Vector2(5, 3), s, size, TEXT)


## Step dots (filled amber = done or current).
static func dots(ci: CanvasItem, right_top: Vector2, n: int, on: int, rad := 3.0) -> void:
	for i in n:
		var c := right_top + Vector2(-(n - 1 - i) * (rad * 2 + 3) - rad, rad)
		ci.draw_circle(c, rad, AMBER if i < on else Color(0.25, 0.18, 0.12))
		ci.draw_arc(c, rad, 0, TAU, 10, Color(0, 0, 0, 0.6), 1.0)


## A boxed title tag (the "DESK" / "BENCHES" tags on the sheets).
static func tag(ci: CanvasItem, pos: Vector2, s: String, size := 10) -> Rect2:
	var f := font()
	var r := Rect2(pos, Vector2(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12, size + 8))
	ci.draw_rect(r, Color(0.07, 0.05, 0.04, 0.95))
	ci.draw_rect(r, BRASS, false, 1.0)
	text(ci, r.position + Vector2(6, 4), s, size, TEXT)
	return r
