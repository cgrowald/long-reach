extends Control
## The hack rig beside the screen (Iron Nest feel): target plate, CHIPS x MULT counters, a rolling SCORE,
## the intel tier ladder, trace lamps, tool cartridges you plug into two slots, switches and the SEND lever.

signal send_pulled
signal alt_pulled
signal pulled_out
signal loadout_changed

const Pal := preload("res://v2/ui/pal.gd")

const PLATE := Rect2(4, 4, 193, 40)
const CHIPS_R := Rect2(4, 48, 86, 22)
const MULT_R := Rect2(106, 48, 60, 22)
const SCORE_R := Rect2(4, 74, 193, 22)
const TIER_Y := 100.0
const TRACE_Y := 149.0
const RACK_Y := 178.0
const SLOT_Y := 208.0
const INFO_R := Rect2(4, 236, 142, 24)
const PULL_R := Rect2(4, 264, 68, 20)
const ALT_R := Rect2(78, 264, 68, 20)
const LEVER_R := Rect2(152, 168, 45, 116)
const LEVER_TOP := 190.0
const LEVER_TRAVEL := 70.0

var sfx
var target_name := ""
var rule_text := ""
var weak_text := ""
var carts: Array = []          # {id, name, desc}
var plugged: Array = ["", ""]
var tiers: Array = []          # {score, label}
var trace_max := 9
var trace := 0
var alt_label := ""
var send_label := "SEND"
var loadout_locked := false
var lever_enabled := true
var switches_enabled := true
var default_info := "Plug two cartridges, then pull SEND."

var _chips_t := 0.0
var _chips := 0.0
var _mult_t := 1.0
var _mult := 1.0
var _score_t := 0.0
var _score := 0.0
var _flash := {}
var _bump := {"chips": 0.0, "mult": 0.0, "score": 0.0}
var _hover := ""
var _lever_t := 0.0
var _dragging := false
var _press := Vector2.ZERO
var _pull_anim := 0.0
var _alt_anim := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(201, 288)


# --- API ---------------------------------------------------------------

func set_chips(v: float) -> void:
	if v != _chips_t:
		_bump["chips"] = 1.0
	_chips_t = v


func set_mult(v: float) -> void:
	if v != _mult_t:
		_bump["mult"] = 1.0
	_mult_t = v


func set_score(v: float) -> void:
	if v != _score_t:
		_bump["score"] = 1.0
	_score_t = v


func set_trace(n: int) -> void:
	if n > trace and sfx:
		sfx.play("error_004", 0.8 + n * 0.05, -10.0)
	trace = n


func flash_cart(id: String) -> void:
	_flash[id] = 1.0


func has_cart(id: String) -> bool:
	return plugged.has(id)


func lock_loadout() -> void:
	loadout_locked = true


func cart_center(id: String) -> Vector2:
	var i := plugged.find(id)
	if i >= 0:
		return position + _slot_rect(i).get_center()
	return position + Vector2(100, 190)


# --- layout ---------------------------------------------------------------

func _cart_rect(i: int) -> Rect2:
	return Rect2(4 + i * 36, RACK_Y, 34, 22)


func _slot_rect(i: int) -> Rect2:
	return Rect2(4 + i * 72, SLOT_Y, 68, 24)


# --- input ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		if _dragging:
			_lever_t = clampf((p.y - _press.y) / LEVER_TRAVEL, 0.0, 1.0)
		_hover = ""
		for i in carts.size():
			if _cart_rect(i).has_point(p):
				_hover = carts[i]["id"]
		for i in 2:
			if _slot_rect(i).has_point(p) and plugged[i] != "":
				_hover = plugged[i]
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if event.pressed:
			if LEVER_R.has_point(p) and lever_enabled:
				_dragging = true
				_press = p
				if sfx:
					sfx.play("click_002", 0.7, -10.0)
				accept_event()
				return
			if not loadout_locked:
				for i in carts.size():
					if _cart_rect(i).has_point(p):
						_toggle_cart(carts[i]["id"])
						return
				for i in 2:
					if _slot_rect(i).has_point(p) and plugged[i] != "":
						_toggle_cart(plugged[i])
						return
			if PULL_R.has_point(p) and switches_enabled:
				_pull_anim = 1.0
				if sfx:
					sfx.play("switch_002", 0.8, -4.0)
				pulled_out.emit()
				return
			if ALT_R.has_point(p) and switches_enabled and alt_label != "":
				_alt_anim = 1.0
				if sfx:
					sfx.play("switch_002", 1.1, -4.0)
				alt_pulled.emit()
				return
		elif _dragging:
			_dragging = false
			if _lever_t > 0.6 or (p - _press).length() < 3.0:
				pull_lever()
			else:
				var tw := create_tween()
				tw.tween_property(self, "_lever_t", 0.0, 0.15)


## Animate a full lever pull and emit send_pulled at the bottom (also used by the Space key).
func pull_lever() -> void:
	if not lever_enabled:
		return
	lever_enabled = false
	var tw := create_tween()
	tw.tween_property(self, "_lever_t", 1.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if sfx:
			sfx.play("drop_002", 0.7, -2.0)
		send_pulled.emit())
	tw.tween_property(self, "_lever_t", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _toggle_cart(id: String) -> void:
	var i := plugged.find(id)
	if i >= 0:
		plugged[i] = ""
		if sfx:
			sfx.play("click_004", 0.8, -6.0)
	else:
		var free := plugged.find("")
		if free < 0:
			if sfx:
				sfx.play("error_006", 1.0, -10.0)
			return
		plugged[free] = id
		_flash[id] = 1.0
		if sfx:
			sfx.play("click_005", 0.9, -4.0)
	loadout_changed.emit()


# --- draw ---------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var k := 1.0 - exp(-10.0 * delta)
	_chips = _snap(lerpf(_chips, _chips_t, k), _chips_t)
	_mult = _snap(lerpf(_mult, _mult_t, k), _mult_t)
	_score = _snap(lerpf(_score, _score_t, 1.0 - exp(-6.0 * delta)), _score_t)
	for key in _bump:
		_bump[key] = maxf(0.0, _bump[key] - delta * 5.0)
	for key in _flash.keys():
		_flash[key] = maxf(0.0, _flash[key] - delta * 2.5)
	_pull_anim = maxf(0.0, _pull_anim - delta * 3.0)
	_alt_anim = maxf(0.0, _alt_anim - delta * 3.0)
	queue_redraw()


func _snap(v: float, t: float) -> float:
	return t if absf(v - t) < 0.5 else v


func _draw() -> void:
	Pal.plate(self, Rect2(Vector2.ZERO, size), Pal.METAL)
	for c in [Vector2(3, 3), Vector2(size.x - 3, 3), Vector2(3, size.y - 3), Vector2(size.x - 3, size.y - 3)]:
		Pal.screw(self, c)
	# target plate
	Pal.plate(self, PLATE, Pal.BRASS.darkened(0.35))
	Pal.text(self, PLATE.position + Vector2(4, 2), target_name, 10, Pal.TEXT)
	Pal.text(self, PLATE.position + Vector2(4, 14), rule_text, 9, Color(1.0, 0.55, 0.45))
	Pal.text(self, PLATE.position + Vector2(4, 26), weak_text, 9, Pal.AMBER)
	# chips x mult
	var cb: float = _bump["chips"]
	var mb: float = _bump["mult"]
	Pal.well(self, CHIPS_R, Pal.CHIPS.darkened(0.7 - cb * 0.3))
	Pal.text(self, CHIPS_R.position + Vector2(3, 1), "CHIPS", 8, Pal.CHIPS)
	Pal.text(self, CHIPS_R.position + Vector2(0, 8 - cb * 2), "%d" % int(roundf(_chips)), 12 + int(cb * 3), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, CHIPS_R.size.x - 4)
	Pal.text(self, Vector2(CHIPS_R.end.x + 4, 52), "x", 14, Pal.TEXT)
	Pal.well(self, MULT_R, Pal.MULT.darkened(0.7 - mb * 0.3))
	Pal.text(self, MULT_R.position + Vector2(3, 1), "MULT", 8, Pal.MULT)
	Pal.text(self, MULT_R.position + Vector2(0, 8 - mb * 2), Pal.fmt_mult(_mult), 12 + int(mb * 3), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, MULT_R.size.x - 4)
	# score odometer
	Pal.well(self, SCORE_R)
	Pal.text(self, SCORE_R.position + Vector2(3, 6), "SCORE", 9, Pal.DIM)
	var digits := "%07d" % int(roundf(_score))
	var sb: float = _bump["score"]
	for i in 7:
		var r := Rect2(SCORE_R.position.x + 52 + i * 19, SCORE_R.position.y + 2, 17, 18)
		draw_rect(r, Color(0.9, 0.87, 0.8) if digits[i] != "0" or i == 6 or int(digits.left(i + 1)) > 0 else Color(0.55, 0.53, 0.5))
		draw_rect(Rect2(r.position + Vector2(0, 8), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.25))
		Pal.text(self, r.position + Vector2(0, 2 - sb), digits[i], 14, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# tier ladder
	for i in tiers.size():
		var y := TIER_Y + i * 12.0
		var on := _score_t >= float(tiers[i]["score"])
		Pal.lamp(self, Vector2(10, y + 5), 3.5, on, Pal.GREEN)
		Pal.text(self, Vector2(16, y), "%d" % int(tiers[i]["score"]), 9, Pal.TEXT if on else Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 40)
		Pal.text(self, Vector2(62, y), str(tiers[i]["label"]), 9, Pal.TEXT if on else Pal.DIM)
	# trace lamps
	Pal.text(self, Vector2(4, TRACE_Y + 2), "TRACE", 9, Pal.DIM)
	var step := minf(17.0, 150.0 / float(trace_max))
	for i in trace_max:
		var c := Vector2(44 + i * step, TRACE_Y + 7)
		var last := i == trace_max - 1
		var on := i < trace
		var blink := last and trace == trace_max - 1 and fmod(_time, 0.5) < 0.25
		Pal.lamp(self, c, 4.5, on or blink, Pal.MULT if not last else Color(1, 0.1, 0.1))
		if last:
			draw_arc(c, 6.5, 0, TAU, 14, Pal.MULT, 1.0)
	# cartridges
	Pal.text(self, Vector2(4, RACK_Y - 11), "TOOLS" if not loadout_locked else "TOOLS (locked)", 8, Pal.DIM)
	for i in carts.size():
		var id: String = carts[i]["id"]
		var r := _cart_rect(i)
		Pal.well(self, r, Color(0.07, 0.07, 0.08))
		if not plugged.has(id):
			_draw_cart(r.grow(-2), carts[i], _hover == id)
	for i in 2:
		var r := _slot_rect(i)
		Pal.well(self, r, Color(0.03, 0.03, 0.04))
		Pal.text(self, r.position + Vector2(2, 1), "SLOT %s" % ["A", "B"][i], 7, Pal.DIM)
		if plugged[i] != "":
			var cart: Dictionary = {}
			for c in carts:
				if c["id"] == plugged[i]:
					cart = c
			var f: float = _flash.get(plugged[i], 0.0)
			var rr := r.grow(-2)
			rr.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * (1.0 if f > 0.5 else 0.0)
			_draw_cart(rr, cart, _hover == plugged[i], f)
			Pal.lamp(self, Vector2(r.end.x - 5, r.position.y + 5), 2.0, true, Pal.GREEN if f < 0.1 else Color.WHITE)
	# info line
	var info := default_info
	if _hover != "":
		for c in carts:
			if c["id"] == _hover:
				info = "%s: %s" % [c["name"], c["desc"]]
	Pal.well(self, INFO_R, Color(0.05, 0.06, 0.05))
	_wrap(info, INFO_R.position + Vector2(2, 1), INFO_R.size.x - 4, 8, Pal.GREEN.darkened(0.15))
	# switches
	_draw_switch(PULL_R, "PULL OUT", _pull_anim, switches_enabled)
	if alt_label != "":
		_draw_switch(ALT_R, alt_label, _alt_anim, switches_enabled)
	# lever
	Pal.plate(self, LEVER_R, Pal.METAL_D)
	Pal.text(self, LEVER_R.position + Vector2(0, 3), send_label, 9, Pal.TEXT if lever_enabled else Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, LEVER_R.size.x)
	var cx := LEVER_R.get_center().x
	Pal.well(self, Rect2(cx - 3, LEVER_TOP - 6, 6, LEVER_TRAVEL + 12))
	var ky := LEVER_TOP + _lever_t * LEVER_TRAVEL
	draw_rect(Rect2(cx - 2, LEVER_TOP - 6, 4, ky - LEVER_TOP + 6), Pal.METAL_L)
	var kc := Color(0.75, 0.12, 0.1) if lever_enabled else Color(0.35, 0.15, 0.13)
	draw_circle(Vector2(cx, ky), 9.0, kc.darkened(0.4))
	draw_circle(Vector2(cx, ky - 1), 8.0, kc)
	draw_circle(Vector2(cx - 3, ky - 4), 2.5, kc.lightened(0.5))
	Pal.lamp(self, Vector2(cx, LEVER_R.end.y - 6), 3.0, lever_enabled and fmod(_time, 1.0) < 0.6, Pal.AMBER)


func _draw_cart(r: Rect2, cart: Dictionary, hover: bool, f := 0.0) -> void:
	var col := Color(0.55, 0.15, 0.12).lerp(Color.WHITE, f * 0.6)
	if hover:
		col = col.lightened(0.2)
	Pal.plate(self, r, col)
	draw_rect(Rect2(r.position + Vector2(2, r.size.y - 5), Vector2(r.size.x - 4, 3)), Pal.BRASS)
	Pal.text(self, r.position + Vector2(0, 2), str(cart.get("name", "")), 8, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_switch(r: Rect2, label: String, anim: float, enabled: bool) -> void:
	Pal.plate(self, r, Pal.METAL_D)
	var base := Vector2(r.position.x + 10, r.get_center().y)
	draw_circle(base, 5.0, Pal.METAL_L)
	var ang := lerpf(-0.9, 0.9, anim)
	var tip := base + Vector2(sin(ang), -cos(ang)) * 7.0
	draw_line(base, tip, Pal.BRASS if enabled else Pal.DIM, 2.0)
	draw_circle(tip, 2.0, Pal.BRASS if enabled else Pal.DIM)
	Pal.text(self, Vector2(r.position.x + 18, r.position.y + 5), label, 8, Pal.TEXT if enabled else Pal.DIM)


func _wrap(s: String, pos: Vector2, width: float, fsize: int, col: Color) -> void:
	var f := Pal.font()
	var words := s.split(" ")
	var line := ""
	var y := pos.y
	for w in words:
		var test := w if line == "" else line + " " + w
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > width and line != "":
			Pal.text(self, Vector2(pos.x, y), line, fsize, col)
			y += fsize + 1
			line = w
		else:
			line = test
	if line != "":
		Pal.text(self, Vector2(pos.x, y), line, fsize, col)
