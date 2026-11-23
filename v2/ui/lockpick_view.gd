extends Control
## The lockpicking minigame on screen (rules: v2/sim/lockpick.gd). A big cutaway of the lock: pins in their
## chambers, the pick under one pin, the tension wrench, and a front view that turns like Skyrim's.
##   move the mouse sideways: pick under a pin      hold LEFT and move up: lift the pin
##   mouse wheel (or W/S): tension                   SPACE: let go (resets a jam)      Esc / right-click: give up
## Emits finished("open" | "broke" | "quit"). Picks come from state.supplies["picks"]; a snap uses one.

signal finished(result: String)

const Lockpick := preload("res://v2/sim/lockpick.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Synth := preload("res://v2/ui/synth.gd")

const L := 70.0                   # how far a pin can travel (px)
const SPRING_TOP := 40.0

var lock: Lockpick
var state: RefCounted             # may be null (the toy): then picks are endless
var lock_id := "padlock"
var holding := false
var mouse := Vector2.ZERO
var _pick_x := 0.0
var _shake := 0.0
var _flash := {}                  # pin -> 0..1
var _red := 0.0
var _gold := 0.0
var _done_t := -1.0
var _msg := ""
var _msg_t := 0.0
var _scrape: AudioStreamPlayer
var _fx: Array[AudioStreamPlayer] = []
var _fxi := 0
var _last_h := 0.0
var _t := 0.0
var _tick_t := 0.0


func start(p_lock: String, p_state: RefCounted, p_seed: int) -> void:
	lock_id = p_lock
	state = p_state
	lock = Lockpick.create(p_lock, p_seed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_scrape = AudioStreamPlayer.new()
	_scrape.stream = Synth.scrape()
	_scrape.volume_db = -80.0
	add_child(_scrape)
	_scrape.play()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_fx.append(p)
	_say(str(lock.def.get("name", "A lock")) + ". Feel for the pin that binds.")


func picks() -> int:
	return 99 if state == null else int(state.supplies.get("picks", 0))


func _play(s: AudioStream, pitch := 1.0, db := -6.0) -> void:
	var p := _fx[_fxi]
	_fxi = (_fxi + 1) % _fx.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func _say(m: String) -> void:
	_msg = m
	_msg_t = 3.5


# ------------------------------------------------------------------ geometry

func _box() -> Rect2:
	var w := minf(size.x - 230, 380.0)
	return Rect2(Vector2((size.x - w) * 0.5 - 25, size.y * 0.5 - 90), Vector2(w, 180))


func _y0() -> float:                   # keyway floor
	return _box().end.y - 34


func _ys() -> float:                   # the shear line (top of the plug)
	return _y0() - 80


func _pin_x(i: int) -> float:
	var b := _box()
	var n: int = lock.pins.size()
	return b.position.x + 110 + i * (b.size.x - 150) / maxf(1, n - 1)


func _nearest_pin(x: float) -> int:
	var best := 0
	var bd := 1e9
	for i in lock.pins.size():
		var d := absf(_pin_x(i) - x)
		if d < bd:
			bd = d
			best = i
	return best


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if lock == null or _done_t >= 0.0:
		return
	if e is InputEventMouseMotion:
		mouse = e.position
	elif e is InputEventMouseButton:
		mouse = e.position
		if e.button_index == MOUSE_BUTTON_LEFT:
			holding = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_tension(0.04)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_tension(-0.04)
		elif e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_quit()
	accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if lock == null or not visible or _done_t >= 0.0 or not (e is InputEventKey) or not e.pressed:
		return
	match e.keycode:
		KEY_ESCAPE:
			_quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _tension(d: float) -> void:
	lock.set_tension(lock.tension + d)
	_play(Synth.tick(900.0 + lock.tension * 600.0, 0.008, 0.6), 1.0, -18.0)


func _quit() -> void:
	_finish("quit")


func _finish(r: String) -> void:
	if _done_t >= 0.0:
		return
	_done_t = 0.0 if r != "open" else 0.0
	_scrape.stop()
	var t := create_tween()
	t.tween_interval(0.9 if r == "open" else 0.2)
	t.tween_callback(func() -> void: finished.emit(r))


# ------------------------------------------------------------------ the loop

func _process(delta: float) -> void:
	if lock == null:
		return
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	_shake = maxf(0.0, _shake - delta * 6.0)
	_red = maxf(0.0, _red - delta * 2.0)
	_gold = maxf(0.0, _gold - delta * 1.5)
	for k in _flash.keys():
		_flash[k] = maxf(0.0, float(_flash[k]) - delta * 2.5)
	if _done_t >= 0.0:
		_done_t += delta
		lock.tick(delta)
		queue_redraw()
		return
	# the pick follows the mouse sideways and snaps under the nearest pin
	var target_x := _pin_x(_nearest_pin(mouse.x))
	_pick_x = lerpf(_pick_x, target_x, 1.0 - exp(-delta * 18.0)) if _pick_x != 0.0 else target_x
	lock.at = _nearest_pin(_pick_x)
	# tension: hold E (or W) for more, Q (or S) for less; the wheel nudges it
	var dt := 0.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_W):
		dt += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_S):
		dt -= 1.0
	if dt != 0.0:
		lock.set_tension(lock.tension + dt * 0.45 * delta)
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = 0.06
			_play(Synth.tick(900.0 + lock.tension * 600.0, 0.008, 0.6), 1.0, -20.0)
	if Input.is_key_pressed(KEY_SPACE):
		lock.set_tension(0.0)
	# lift: hold the left button and the pick pushes the pin up steadily; let go and it falls back
	if holding:
		lock.lift = minf(1.0, lock.lift + delta * 0.5)
	else:
		lock.lift = maxf(0.0, lock.lift - delta * 1.6)
	lock.tick(delta)
	for ev in lock.events:
		match ev:
			"set":
				_play(Synth.tick(2400.0, 0.012, 0.5), randf_range(0.95, 1.08), -2.0)
				_play(load("res://art/audio/kenney_interface/click_003.ogg"), 1.4, -8.0)
				_flash[lock.order[lock.set_count() - 1]] = 1.0
				_shake = 0.6
				_gold = 0.4
			"false":
				_play(Synth.tick(500.0, 0.03, 0.4), 0.8, -4.0)
				_say("It pushed back. A false set: ease off the tension a little.")
				_shake = 0.4
			"over":
				_play(Synth.tick(180.0, 0.05, 0.7), 1.0, -2.0)
				_say("Overset. It's jammed. Let the tension go (SPACE) and start again.")
				_shake = 0.5
			"drop":
				_play(Synth.tick(1500.0, 0.01, 0.6), 0.7, -10.0)
			"snap":
				_play(load("res://art/audio/kenney_interface/glass_001.ogg"), 0.55, 0.0)
				_shake = 1.6
				_red = 1.0
				if state != null:
					state.supplies["picks"] = maxi(0, picks() - 1)
				if picks() <= 0:
					_say("Your last pick snapped.")
					_finish("broke")
				else:
					_say("SNAP. Too much tension. %d picks left." % picks())
			"open":
				_play(load("res://art/audio/kenney_interface/confirmation_002.ogg"), 0.9, -2.0)
				_play(Synth.tick(140.0, 0.08, 0.5), 1.0, 0.0)
				_gold = 1.0
				_shake = 0.8
				_finish("open")
	lock.events.clear()
	# the scrape: louder when the pick moves a pin, higher as it nears the sweet spot
	var b: int = lock.binding()
	var h: float = lock.pins[lock.at]["h"]
	var moving := absf(h - _last_h) / maxf(delta, 0.001)
	_last_h = h
	var loud := clampf(moving * 0.5, 0.0, 1.0) * (1.0 if lock.at == b else 0.4)
	_scrape.volume_db = lerpf(_scrape.volume_db, -40.0 + loud * 30.0 if loud > 0.02 else -80.0, 1.0 - exp(-delta * 15.0))
	_scrape.pitch_scale = 0.8 + lock.feel * 0.6
	queue_redraw()


# ------------------------------------------------------------------ drawing

const BRASS := Color(0.82, 0.62, 0.3)
const BRASS_D := Color(0.5, 0.36, 0.16)
const STEEL := Color(0.62, 0.64, 0.66)
const STEEL_D := Color(0.32, 0.33, 0.35)
const HOUSE := Color(0.26, 0.2, 0.14)
const HOUSE_D := Color(0.14, 0.11, 0.08)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.055, 0.045))
	# warm lamp pool
	for k in 6:
		draw_circle(size * Vector2(0.45, 0.45), 260.0 - k * 36.0, Color(1.0, 0.6, 0.2, 0.025))
	if lock == null:
		return
	var jig := lock.feel * 1.2 if holding else 0.0
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_shake * 3.0 + jig)
	draw_set_transform(sh)
	var b := _box()
	var y0 := _y0()
	var ys := _ys()
	# housing (top) and plug (bottom)
	draw_rect(b, HOUSE)
	draw_rect(Rect2(b.position.x, ys, b.size.x, b.end.y - ys), BRASS_D.darkened(0.25))
	draw_rect(Rect2(b.position.x + 30, y0 - 4, b.size.x - 40, 16), HOUSE_D)              # the keyway
	draw_line(Vector2(b.position.x, ys), Vector2(b.end.x, ys), Color(BRASS, 0.5 + _gold * 0.5), 1.5)
	Pal.brackets(self, b.grow(6), Pal.BRASS, 10.0, 1.5)
	var bind: int = lock.binding()
	for i in lock.pins.size():
		_draw_pin(i, i == bind)
	_draw_wrench()
	_draw_pick()
	draw_set_transform(Vector2.ZERO)
	_draw_face()
	_draw_hud()


func _draw_pin(i: int, binding: bool) -> void:
	var p: Dictionary = lock.pins[i]
	var x := _pin_x(i)
	# the pin under the pick shakes as you push it: harder near the sweet spot (Skyrim's tell), a rattle when the tension is too high
	if i == lock.at and holding and not p["set"]:
		var amt := 0.4 + (lock.feel * 3.0 if binding else 0.3)
		if lock.tension > lock.t_hi:
			amt += 1.5
		x += randf_range(-1.0, 1.0) * amt
	var y0 := _y0()
	var ys := _ys()
	var top := _box().position.y + 8
	draw_rect(Rect2(x - 8, top, 16, y0 - top - 2), HOUSE_D)                         # the chamber
	var kl := (y0 - ys) - float(p["shear"]) * L                                       # key pin length: tops at the shear line when h == shear
	var bottom := y0 - 2 - float(p["h"]) * L
	var key_top := bottom - kl
	var fl := float(_flash.get(i, 0.0))
	var kc := BRASS.lerp(Color(1, 0.9, 0.5), fl)
	# key pin with a rounded nose
	draw_rect(Rect2(x - 6, key_top, 12, kl - 4), kc)
	draw_circle(Vector2(x, bottom - 4), 6.0, kc)
	draw_line(Vector2(x - 6, key_top), Vector2(x - 6, bottom - 4), kc.darkened(0.3), 1.0)
	# driver pin on top (a spool has a waist), then the spring
	var gap := 3.0 if p["set"] else 0.0
	var dtop := key_top - gap - 26
	var dc := STEEL.lerp(Color(1, 0.9, 0.5), fl * 0.6)
	if p["spool"]:
		draw_rect(Rect2(x - 6, dtop, 12, 6), dc)
		draw_rect(Rect2(x - 3, dtop + 6, 6, 14), dc.darkened(0.15))
		draw_rect(Rect2(x - 6, dtop + 20, 12, 6), dc)
	else:
		draw_rect(Rect2(x - 6, dtop, 12, 26), dc)
	draw_line(Vector2(x + 6, dtop), Vector2(x + 6, dtop + 26), STEEL_D, 1.0)
	var coils := 7
	var sp_h := dtop - top
	for c in coils:
		var a := Vector2(x - 6 if c % 2 == 0 else x + 6, top + sp_h * c / coils)
		var bb := Vector2(x + 6 if c % 2 == 0 else x - 6, top + sp_h * (c + 1) / coils)
		draw_line(a, bb, STEEL_D.lightened(0.2), 1.2)
	if p["set"]:
		draw_line(Vector2(x - 9, ys), Vector2(x + 9, ys), Color(1.0, 0.85, 0.4, 0.9), 2.0)
	if p["over"]:
		draw_rect(Rect2(x - 9, top, 18, y0 - top), Color(0.9, 0.2, 0.1, 0.18 + 0.1 * sin(_t * 10.0)))


func _draw_pick() -> void:
	var y0 := _y0()
	var b := _box()
	var tip := Vector2(_pick_x, y0 - 2 - lock.lift * L)
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * lock.feel * 2.2
	tip += jitter
	var handle := Vector2(b.position.x - 50, y0 + 34)
	var mid := Vector2(b.position.x + 20, y0 + 6)
	var bend_off := Vector2(0, lock.bend * 10.0)
	var col := STEEL.lerp(Color(0.95, 0.3, 0.15), clampf(lock.bend * 1.2, 0.0, 1.0))
	draw_line(handle, mid + bend_off * 0.5, col, 3.0)
	draw_line(mid + bend_off * 0.5, Vector2(tip.x - 10, y0 + 4) + bend_off, col, 2.0)
	draw_line(Vector2(tip.x - 10, y0 + 4) + bend_off, tip, col, 2.0)
	draw_rect(Rect2(handle - Vector2(30, 6), Vector2(32, 12)), Color(0.55, 0.12, 0.08))          # the red grip
	draw_rect(Rect2(handle - Vector2(30, 6), Vector2(32, 12)), Color(0, 0, 0, 0.4), false, 1.0)


func _draw_wrench() -> void:
	var b := _box()
	var y0 := _y0()
	var base := Vector2(b.position.x + 34, y0 + 10)
	var ang := -0.2 - lock.tension * 0.7
	var arm := base + Vector2(cos(PI * 0.5 + ang), sin(PI * 0.5 + ang)) * 48.0
	var hot := lock.tension > lock.t_hi
	var col := STEEL_D.lerp(Color(1.0, 0.45, 0.2), 0.6 if hot else 0.0)
	draw_line(base + Vector2(0, -12), base, col, 3.0)
	draw_line(base, arm, col, 3.0)
	# the tension gauge
	var g := Vector2(b.position.x - 40, b.position.y + 30)
	var r := 26.0
	draw_arc(g, r, PI, TAU, 24, Color(Pal.METAL_L, 0.8), 4.0)
	if lock.def.get("show_band", false):
		draw_arc(g, r, PI + lock.t_lo * PI, PI + lock.t_hi * PI, 12, Color(0.5, 0.8, 0.35, 0.9), 4.0)
	var na := PI + lock.tension * PI
	draw_line(g, g + Vector2(cos(na), sin(na)) * (r + 4), Color(1.0, 0.55, 0.2) if not hot else Color(1, 0.25, 0.15), 2.0)
	draw_circle(g, 3.0, Pal.BRASS)
	draw_string(Pal.font(), g + Vector2(-28, 14), "TENSION", HORIZONTAL_ALIGNMENT_CENTER, 56, 7, Pal.DIM)


func _draw_face() -> void:
	# the front of the lock, turning like Skyrim's (top right)
	var b := _box()
	var c := Vector2(b.end.x + 70, b.position.y + 50)
	draw_circle(c, 38.0, HOUSE_D)
	draw_circle(c, 34.0, BRASS_D)
	draw_circle(c, 26.0, BRASS)
	var a := lock.plug * PI * 0.5 - lock.counter * 0.08 * sin(_t * 30.0) + lock.tension * 0.03
	var d := Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5))
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([c - d * 16 - n * 3, c + d * 16 - n * 3, c + d * 16 + n * 3, c - d * 16 + n * 3])
	draw_colored_polygon(pts, HOUSE_D)
	draw_arc(c, 38.0, 0, TAU, 32, Color(1.0, 0.8, 0.35, _gold), 3.0)
	# set pins as pips under the face
	for i in lock.pins.size():
		var on: bool = lock.pins[lock.order[i]]["set"] if i < lock.order.size() else false
		var pc := c + Vector2((i - (lock.pins.size() - 1) * 0.5) * 11.0, 52)
		if on:
			draw_circle(pc, 3.5, Pal.BRASS)
		else:
			draw_arc(pc, 3.5, 0, TAU, 12, Pal.DIM, 1.0)


func _draw_hud() -> void:
	Pal.tag(self, Vector2(16, 12), "LOCK  |  " + str(lock.def.get("name", "")).to_upper(), 9)
	var pk := "PICKS  x%d" % picks() if state != null else "PICKS  x-"
	draw_string(Pal.bold(), Vector2(size.x - 150, 26), pk, HORIZONTAL_ALIGNMENT_RIGHT, 134, 9, Pal.TEXT)
	# bend bar
	var br := Rect2(size.x - 150, 32, 134, 4)
	draw_rect(br, Pal.METAL_D)
	draw_rect(Rect2(br.position, Vector2(br.size.x * lock.bend, br.size.y)), Color(1.0, 0.35, 0.15))
	draw_string(Pal.font(), Vector2(size.x - 150, 46), "BEND", HORIZONTAL_ALIGNMENT_RIGHT, 134, 7, Pal.DIM)
	var help := "MOUSE: pick under a pin     HOLD LEFT: push the pin up     E / Q (or wheel): tension up / down     SPACE: let go     ESC: give up"
	draw_string(Pal.font(), Vector2(16, size.y - 12), help, HORIZONTAL_ALIGNMENT_CENTER, size.x - 32, 7, Pal.DIM)
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t)
		var tw := Pal.font().get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var mr := Rect2(Vector2((size.x - tw) * 0.5 - 10, size.y - 50), Vector2(tw + 20, 18))
		draw_rect(mr, Color(Pal.METAL_D, 0.9 * a))
		draw_rect(mr, Color(Pal.BRASS, 0.6 * a), false, 1.0)
		draw_string(Pal.font(), mr.position + Vector2(10, 13), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Pal.TEXT, a))
	if _red > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.1, 0.05, _red * 0.25))
	if _gold > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.75, 0.3, _gold * 0.08))
	if lock.opened:
		draw_string(Pal.bold(), Vector2(0, size.y * 0.5 - 110), "OPEN", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Pal.BRASS)
