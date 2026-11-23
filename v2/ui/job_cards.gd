extends Control
## The day-job pick (user, 2026-11-22: "3 cards to choose from, like card games: what they do, the cons,
## sharp and clean, a photo for each"). Deals three cards; hover lifts one; click takes the job.
## Card text lives in data/v2/economy.json (jobs.<id>.card). Photos: art/jobs/<id>.png (GPT makes them;
## until then a placeholder frame is drawn). Concept-sheet colours: petrol, ivory, copper.

const Pal := preload("res://v2/ui/pal.gd")

const PETROL := Color(0.09, 0.2, 0.22)
const PETROL_D := Color(0.05, 0.12, 0.13)
const IVORY := Color(0.93, 0.9, 0.82)
const IVORY_D := Color(0.82, 0.78, 0.68)
const COPPER := Color(0.78, 0.45, 0.2)
const INK := Color(0.12, 0.12, 0.12)
const GIVE := Color(0.18, 0.42, 0.3)
const COST := Color(0.62, 0.17, 0.1)

const CARD := Vector2(172, 268)
const GAP := 14.0

var game: Node
var offers: Array = []
var on_pick: Callable          # func(offer: Dictionary)
var _cards: Array = []
var _picked := false


static func open(parent: Control, p_game: Node, p_offers: Array, p_on_pick: Callable) -> Control:
	var o := Control.new()
	o.set_script(load("res://v2/ui/job_cards.gd"))
	o.game = p_game
	o.offers = p_offers
	o.on_pick = p_on_pick
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.z_index = 30
	parent.add_child(o)
	return o


func _ready() -> void:
	var econ = load("res://v2/sim/economy.gd")
	for i in offers.size():
		var c := _Card.new()
		c.offer = offers[i]
		c.jd = econ.job_def(str(offers[i]["id"]))
		c.size = CARD
		c.owner_cards = self
		add_child(c)
		_cards.append(c)
	_layout()
	resized.connect(_layout)
	# deal them in, one after another
	for i in _cards.size():
		var c: Control = _cards[i]
		var end_y: float = c.position.y
		c.position.y = end_y + 60.0
		c.modulate.a = 0.0
		c.rotation = deg_to_rad(4.0 - 4.0 * i)
		var tw := c.create_tween().set_parallel(true)
		tw.tween_property(c, "position:y", end_y, 0.45).set_delay(0.08 + i * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(0.08 + i * 0.09)
		tw.tween_property(c, "rotation", 0.0, 0.45).set_delay(0.08 + i * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if game:
		game.sfx.play("bong_001", 0.8, -8.0)


func _layout() -> void:
	var total := CARD.x * _cards.size() + GAP * maxf(0, _cards.size() - 1)
	var x0 := (size.x - total) * 0.5
	var y0 := (size.y - CARD.y) * 0.5 + 16.0
	for i in _cards.size():
		var c: Control = _cards[i]
		c.position = Vector2(x0 + i * (CARD.x + GAP), y0)
		c.pivot_offset = CARD * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.035, 0.78))
	var f := Pal.bold()
	var day: int = game.state.day if game and game.state else 1
	var town: String = ""
	if game:
		town = str(load("res://v2/sim/content.gd").world().get("town", ""))
	var y := (size.y - CARD.y) * 0.5 - 30.0
	draw_string(f, Vector2(0, y), "PICK YOUR DAY JOB", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, IVORY)
	draw_string(Pal.font(), Vector2(0, y + 14), "Day %d, %s. Your cover, your wage, and what walks home in your bag." % [day, town], HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, IVORY_D)


func pick(card: Control) -> void:
	if _picked:
		return
	_picked = true
	if game:
		game.click()
		game.sfx.play("confirmation_002", 1.0, -6.0)
	for c in _cards:
		var tw := (c as Control).create_tween().set_parallel(true)
		if c == card:
			tw.tween_property(c, "scale", Vector2(1.08, 1.08), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(c, "modulate:a", 0.0, 0.2)
			tw.tween_property(c, "position:y", (c as Control).position.y + 40.0, 0.25)
	var done := create_tween()
	done.tween_interval(0.45)
	done.tween_callback(func() -> void:
		var offer: Dictionary = card.offer
		queue_free()
		on_pick.call(offer))


func hovered(card: Control) -> void:
	if game and not _picked:
		game.hover()


# ------------------------------------------------------------------ one card

class _Card extends Control:
	var offer: Dictionary
	var jd: Dictionary
	var owner_cards: Control
	var lift := 0.0
	var _hover := false
	var _photo: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var path := str(jd.get("card", {}).get("photo", ""))
		if path != "" and ResourceLoader.exists(path):
			_photo = load(path)
		mouse_entered.connect(func() -> void:
			_hover = true
			owner_cards.hovered(self)
			_tween_lift(7.0))
		mouse_exited.connect(func() -> void:
			_hover = false
			_tween_lift(0.0))

	func _tween_lift(to: float) -> void:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			lift = v
			queue_redraw(), lift, to, 0.12)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			owner_cards.pick(self)
			accept_event()

	## Layout from the user's GPT mockup (2026-11-22): big photo on top, the name under it, a rule,
	## then what it gives and costs; hover = copper frame with corner brackets.
	func _draw() -> void:
		var f := Pal.font()
		var fb := Pal.bold()
		var card: Dictionary = jd.get("card", {})
		var o := Vector2(0, -lift)
		var r := Rect2(o, size)
		# shadow, worn paper body, border
		draw_rect(Rect2(o + Vector2(3, 4 + lift * 0.5), size), Color(0, 0, 0, 0.5))
		draw_rect(r, IVORY)
		draw_rect(r.grow(-2), Color(IVORY_D, 0.6), false, 1.0)
		draw_colored_polygon(PackedVector2Array([r.end, r.end - Vector2(10, 0), r.end - Vector2(0, 10)]), Color(IVORY_D, 0.9))
		if _hover:
			draw_rect(r.grow(2), COPPER, false, 2.0)
			draw_rect(r.grow(4), Color(COPPER, 0.35), false, 1.0)
		else:
			draw_rect(r, Color(INK, 0.5), false, 1.0)
		# the photo (or its placeholder)
		var pr := Rect2(o + Vector2(4, 4), Vector2(size.x - 8, 148))
		if _photo:
			_draw_cover(_photo, pr)
		else:
			draw_rect(pr, PETROL_D)
			_dashed(pr.grow(-6), Color(IVORY_D, 0.4))
			draw_string(fb, pr.position + Vector2(0, pr.size.y * 0.5), "PHOTO", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(IVORY_D, 0.7))
			draw_string(f, pr.position + Vector2(0, pr.size.y * 0.5 + 11), str(card.get("photo", "")).get_file(), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 6, Color(IVORY_D, 0.5))
		if _hover:
			_brackets(pr.grow(-5), COPPER)
		draw_string(fb, pr.position + Vector2(6, 12), str(card.get("tag", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(IVORY, 0.85))
		# the name, then the actual job and place in small type
		var y := 4.0 + pr.size.y + 17.0     # card space; `o` (the lift) is added when drawing
		draw_string(fb, o + Vector2(0, y), str(card.get("title", jd.get("name", ""))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, INK)
		draw_string(f, o + Vector2(0, y + 10), "%s, %s" % [jd.get("name", ""), jd.get("place", "")], HORIZONTAL_ALIGNMENT_CENTER, size.x, 6, Color(INK, 0.6))
		draw_line(o + Vector2(8, y + 15), o + Vector2(size.x - 8, y + 15), Color(INK, 0.55), 1.0)
		# wage and this run's stock grade
		y += 27
		var wage := "%d cr" % int(jd.get("wage", 0))
		draw_string(fb, o + Vector2(10, y), wage, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COPPER)
		draw_string(f, o + Vector2(12 + fb.get_string_size(wage, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y), "a day", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(INK, 0.6))
		var lo := int(offer.get("lo", 1))
		var hi := int(offer.get("hi", 1))
		for i in 5:
			_star(Vector2(size.x - 52 + i * 9, y - 3), 3.6, COPPER if i < lo else (Color(COPPER, 0.45) if i < hi else Color(INK, 0.15)))
		# gives / costs
		y += 4
		for g in card.get("gives", []):
			y = _bullet(y, "+", str(g), GIVE)
		y += 2
		for c2 in card.get("costs", []):
			y = _bullet(y, "-", str(c2), COST)

	func _brackets(r2: Rect2, col: Color) -> void:
		var k := 9.0
		for c in [[r2.position, Vector2(1, 1)], [Vector2(r2.end.x, r2.position.y), Vector2(-1, 1)], [r2.end, Vector2(-1, -1)], [Vector2(r2.position.x, r2.end.y), Vector2(1, -1)]]:
			var p: Vector2 = c[0]
			var d: Vector2 = c[1]
			draw_line(p, p + Vector2(d.x * k, 0), col, 2.0)
			draw_line(p, p + Vector2(0, d.y * k), col, 2.0)

	## One bullet line (wrapped); returns the next y. Drawn relative to the lifted card.
	func _bullet(y: float, mark: String, s: String, col: Color) -> float:
		var f := Pal.font()
		var o := Vector2(0, -lift)
		var w := size.x - 28
		draw_string(Pal.bold(), o + Vector2(10, y + 8), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col)
		draw_multiline_string(f, o + Vector2(19, y + 8), s, HORIZONTAL_ALIGNMENT_LEFT, w, 6, -1, INK)
		return y + f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, 6).y + 1

	func _draw_cover(tex: Texture2D, r: Rect2) -> void:
		var ts := tex.get_size()
		var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
		var src_size := r.size / k
		draw_texture_rect_region(tex, r, Rect2((ts - src_size) * 0.5, src_size))

	func _dashed(r: Rect2, col: Color) -> void:
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(a.distance_to(b) / 6.0)
			for k in n:
				if k % 2 == 0:
					draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 1.0)

	func _star(c: Vector2, rad: float, col: Color) -> void:
		c += Vector2(0, -lift)
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + i * PI / 5
			var rr := rad if i % 2 == 0 else rad * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)
