extends RefCounted
## v2 look: White Knuckle darkness (bruise purple, red CRT) + Iron Nest panels (green-grey metal, brass, lamps).

const BG := Color(0.05, 0.035, 0.06)
const DESK := Color(0.09, 0.07, 0.09)
const SCREEN := Color(0.075, 0.03, 0.04)
const SCREEN_LINE := Color(0.45, 0.1, 0.09)
const PHOS := Color(1.0, 0.36, 0.26)
const TEXT := Color(0.93, 0.87, 0.78)
const DIM := Color(0.55, 0.48, 0.46)
const METAL := Color(0.29, 0.33, 0.31)
const METAL_D := Color(0.16, 0.18, 0.17)
const METAL_L := Color(0.43, 0.48, 0.45)
const BRASS := Color(0.8, 0.63, 0.3)
const CHIPS := Color(0.32, 0.64, 1.0)
const MULT := Color(1.0, 0.32, 0.26)
const LAMP_OFF := Color(0.18, 0.1, 0.08)
const AMBER := Color(1.0, 0.72, 0.22)
const GREEN := Color(0.5, 1.0, 0.42)
const PAPER := Color(0.87, 0.82, 0.69)
const INK := Color(0.14, 0.11, 0.1)

static var _font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NORMAL
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font = f
	return _font


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
