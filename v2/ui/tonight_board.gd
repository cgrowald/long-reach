extends Control
## The TONIGHT board on screen (docs/CONNECTED_LOOP.md section 2; concept docs/refs/Garage/05_tonight_board.png):
## a corkboard with pinned paper cards saying what's next. Click a card: the garage turns to that station.
## Text from v2/sim/tonight.gd. Used big by the board station (v2/stations/board.gd); the 3D board is v2/world/garage_boards.gd.

signal go(station: String)

const Pal := preload("res://v2/ui/pal.gd")
const Tonight := preload("res://v2/sim/tonight.gd")

const CORK := Color(0.5, 0.33, 0.2)
const CORK_D := Color(0.36, 0.23, 0.14)
const FRAME := Color(0.3, 0.2, 0.12)
const PAPER := Color(0.92, 0.87, 0.76)
const INK := Color(0.16, 0.13, 0.11)
const PENCIL := Color(0.33, 0.28, 0.24)

var game: Node
var cards: Array = []
var _rects: Array = []
var _hover := -1
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh() -> void:
	if game and game.state:
		cards = Tonight.board(game.state)
	size = Vector2(150, 30 + cards.size() * 30 + 30)      # + the Bureau corner (D)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := -1
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(e.position):
				h = i
		if h != _hover:
			_hover = h
			if h >= 0 and game:
				game.hover()
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(e.position):
				accept_event()
				go.emit(str(cards[i]["go"]))
				return


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func _draw() -> void:
	_rects.clear()
	var r := Rect2(Vector2.ZERO, size)
	# frame and cork
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, FRAME)
	var cork := r.grow(-4)
	draw_rect(cork, CORK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		draw_rect(Rect2(cork.position + Vector2(rng.randf() * cork.size.x, rng.randf() * cork.size.y), Vector2(1, 1)), CORK_D)
	# the title, a torn paper strip
	var tr := Rect2(Vector2(r.size.x * 0.5 - 40, 6), Vector2(80, 17))
	draw_rect(tr, PAPER)
	draw_string(Pal.bold(), Vector2(tr.position.x, tr.position.y + 13), "TONIGHT", HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 11, INK)
	# the cards
	for i in cards.size():
		var c: Dictionary = cards[i]
		var y := 28.0 + i * 30.0
		var cr := Rect2(Vector2(9, y), Vector2(r.size.x - 18, 26))
		var tilt := (float((i * 37) % 7) - 3.0) * 0.006
		var hov := _hover == i
		draw_set_transform(cr.get_center(), tilt, Vector2.ONE * (1.04 if hov else 1.0))
		var lr := Rect2(-cr.size * 0.5, cr.size)
		draw_rect(Rect2(lr.position + Vector2(1, 2), lr.size), Color(0, 0, 0, 0.3))
		draw_rect(lr, PAPER.lightened(0.05) if hov else PAPER)
		draw_circle(lr.position + Vector2(8, 5), 2.2, Pal.BRASS)            # the pin
		draw_string(Pal.bold(), lr.position + Vector2(14, 10), str(c["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
		var col: Color = PENCIL if not c["ok"] else Color(0.2, 0.36, 0.18)
		draw_string(Pal.font(), lr.position + Vector2(14, 21), str(c["line"]), HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 18, 8, col)
		if hov:
			draw_string(Pal.font(), lr.position + Vector2(lr.size.x - 16, 10), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.BRASS)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_rects.append(cr)
	# the Bureau corner: Krall's clock and the newest note about you
	if game and game.state:
		var bu: Dictionary = Tonight.bureau(game.state)
		var br := Rect2(Vector2(9, size.y - 30), Vector2(size.x - 18, 25))
		draw_rect(br, Color(0.84, 0.85, 0.82))
		draw_rect(Rect2(br.position, Vector2(br.size.x, 9)), Color(0.16, 0.2, 0.3))
		draw_string(Pal.bold(), br.position + Vector2(3, 8), str(bu["clock"]), HORIZONTAL_ALIGNMENT_LEFT, br.size.x - 6, 7, Color(1.0, 0.6, 0.5))
		draw_string(Pal.font(), br.position + Vector2(3, 18), str(bu["note"]) if str(bu["note"]) != "" else "Nothing on you. Yet.", HORIZONTAL_ALIGNMENT_LEFT, br.size.x - 6, 7, INK)
