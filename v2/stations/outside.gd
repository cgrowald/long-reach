extends "res://v2/stations/station.gd"
## The roller door: going out after curfew to the Tram Yard, the black market in person (user 2026-11-23).
## brief -> the dash there (top-down night map, v2/sim/curfew_map.gd) -> the stalls (v2/sim/markets.gd)
## -> the dash home with the bag -> home. A padlocked yard gate is a shortcut you can pick
## (v2/ui/lockpick_view.gd). Getting caught: bribe, or they search you and take the bag.

const CurfewMap := preload("res://v2/sim/curfew_map.gd")
const Markets := preload("res://v2/sim/markets.gd")
const Mat := preload("res://v2/sim/materials.gd")
const LockView := preload("res://v2/ui/lockpick_view.gd")

const WALK := 3.0
const RUN := 5.2

var phase := "brief"              # brief, go, yard, back, caught, pick, end
var map: CurfewMap
var me := Vector2.ZERO            # tile space, tile centres at +0.5
var path: Array = []              # Vector2 waypoints
var astar: AStarGrid2D
var hover := Vector2(-1, -1)
var grace := 0.0
var want_gate := false
var lockv: Control
var _alert: Control
var _msg := ""
var _msg_t := 0.0
var _t := 0.0
var _end_lines: Array = []
var _bribe := 0
var _btns: Array = []             # [Rect2, id] built each draw
var _hidden := false
var _running := false


func build() -> void:
	focus_mode = Control.FOCUS_ALL
	game.sfx.play("switch_002", 0.5, -10.0)


func back() -> bool:
	if phase in ["go", "back", "yard", "caught", "pick"]:
		if phase == "pick" and lockv != null:
			lockv._quit()
		else:
			_say("You're out after curfew. Get home first.")
		return true
	return false


func _say(m: String, t := 4.0) -> void:
	_msg = m
	_msg_t = t


# ------------------------------------------------------------------ setup

func _go() -> void:
	var st: RefCounted = game.state
	if not garage.spend(float(Markets.mdef("curfew").get("hours", 2.0))):
		return
	st.minute = maxi(st.minute, 22 * 60)
	map = CurfewMap.create(hash(str(st.world_seed) + "curfew" + str(st.day)), float(st.attention))
	# no patrol starts on your doorstep
	for p in map.patrols:
		for k in 4:
			if (p["pos"] as Vector2).distance_to(Vector2(map.home) + Vector2(0.5, 0.5)) < 7.0:
				p["seg"] = (int(p["seg"]) + 1) % 4
				map._place(p)
	_build_astar()
	me = Vector2(map.home) + Vector2(0.5, 0.5)
	phase = "go"
	grace = 2.5
	game.sfx.play("open_001", 0.7, -8.0)
	_say("Out the side door. The Tram Yard is across town (top right). Stay out of the torches.", 6.0)


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, CurfewMap.W, CurfewMap.H)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in CurfewMap.H:
		for x in CurfewMap.W:
			astar.set_point_solid(Vector2i(x, y), not map.walkable(Vector2i(x, y)))


# ------------------------------------------------------------------ geometry

func _tile() -> float:
	return floorf(minf((size.x - 24) / CurfewMap.W, (size.y - 64) / CurfewMap.H))


func _origin() -> Vector2:
	var t := _tile()
	return Vector2(floorf((size.x - t * CurfewMap.W) * 0.5), 34)


func _to_px(p: Vector2) -> Vector2:
	return _origin() + p * _tile()


func _to_tile(px: Vector2) -> Vector2i:
	var q := (px - _origin()) / _tile()
	return Vector2i(int(floor(q.x)), int(floor(q.y)))


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		for b in _btns:
			if (b[0] as Rect2).has_point(e.position):
				_button(str(b[1]))
				return
		if phase in ["go", "back"]:
			_click_map(_to_tile(e.position))


func _click_map(c: Vector2i) -> void:
	if map == null:
		return
	if c == map.gate and not map.gate_open:
		var cur := Vector2i(int(me.x), int(me.y))
		if (Vector2(cur) - Vector2(c)).length() <= 1.01:
			_open_lock()
		else:
			var best := Vector2i(-1, -1)
			var bd := 1e9
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if map.walkable(n):
					var pl := astar.get_id_path(cur, n)
					if not pl.is_empty() and pl.size() < bd:
						bd = pl.size()
						best = n
			if best.x >= 0:
				_path_to(best)
				want_gate = true
		return
	if map.walkable(c):
		want_gate = false
		_path_to(c)


func _path_to(c: Vector2i) -> void:
	var cur := Vector2i(int(me.x), int(me.y))
	var pl := astar.get_id_path(cur, c)
	path = []
	for i in range(1, pl.size()):
		path.append(Vector2(pl[i]) + Vector2(0.5, 0.5))
	game.sfx.play("tick_002", 1.2, -18.0)


func _button(id: String) -> void:
	game.click()
	match id:
		"go":
			_go()
		"stay":
			close()
		"home":
			_leave_yard()
		"bribe":
			_try_bribe()
		"search":
			_searched()
		"done":
			close()
		_:
			if id.begins_with("buy:"):
				var r := Markets.buy(game.state, "curfew", int(id.substr(4)))
				_say(r["msg"], 5.0)
				if r.get("sting", false):
					game.sfx.play("error_004", 0.7, -2.0)
					garage.shake(0.6)
					phase = "back"
					me = Vector2(map.yard) + Vector2(0.5, 0.5)
					for p in map.patrols:
						p["meter"] = 0.7
				elif r["ok"]:
					game.sfx.play("drop_002", 1.0, -6.0)
				else:
					game.deny()
			elif id.begins_with("trade:"):
				var mid := id.substr(6)
				var v := Markets.barter(game.state, mid)
				if v > 0:
					game.sfx.play("confirmation_002", 1.3, -8.0)
					_say("Traded one %s for %d cr." % [Markets.item_name("material", mid), v])


func _leave_yard() -> void:
	phase = "back"
	grace = 1.5
	me = Vector2(map.yard) + Vector2(0.5, 0.5)
	path = []
	var n: int = Markets.carrying(game.state).size()
	_say("Home now. %s" % ("With the bag. Don't get searched." if n > 0 else "Empty-handed."), 5.0)


# ------------------------------------------------------------------ the gate

func _open_lock() -> void:
	if int(game.state.supplies.get("picks", 0)) <= 0:
		_say("No picks. Buy some (Lantern or a stall here), or go round.")
		game.deny()
		return
	phase = "pick"
	path = []
	lockv = LockView.new()
	lockv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lockv)
	lockv.size = size
	lockv.start("yard_gate", game.state, hash(str(game.state.world_seed) + "gate" + str(game.state.day)))
	lockv.finished.connect(_lock_done)
	_alert = Control.new()
	_alert.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.draw.connect(_draw_alert)
	add_child(_alert)
	lockv.grab_focus()


func _lock_done(r: String) -> void:
	if lockv != null:
		lockv.queue_free()
		lockv = null
	if _alert != null:
		_alert.queue_free()
		_alert = null
	if phase != "pick":
		return
	phase = "back" if Markets.carrying(game.state).size() > 0 or _was_back else "go"
	if r == "open":
		map.gate_open = true
		_build_astar()
		_say("The gate's open. A shortcut through the yard.")
	elif r == "broke":
		_say("Out of picks. Go round.")
	else:
		_say("You left the gate.")


var _was_back := false


func _draw_alert() -> void:
	if map == null or _alert == null:
		return
	var m: float = map.max_meter()
	var r := Rect2(_alert.size.x * 0.5 - 90, 8, 180, 8)
	_alert.draw_rect(r, Color(0, 0, 0, 0.6))
	_alert.draw_rect(Rect2(r.position, Vector2(r.size.x * m, r.size.y)), Color(1.0, 0.75 - m * 0.5, 0.2))
	_alert.draw_string(Pal.font(), Vector2(r.position.x, r.end.y + 10), "STREET: " + ("SOMEONE'S COMING" if m > 0.3 else "quiet"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 7, Pal.TEXT if m < 0.3 else Color(1, 0.5, 0.3))


# ------------------------------------------------------------------ caught

func _caught() -> void:
	phase = "caught"
	path = []
	game.sfx.play("error_006", 0.8, -2.0)
	garage.shake(0.8)
	_bribe = maxi(20, int(game.state.money * 0.3))
	if lockv != null:
		lockv.queue_free()
		lockv = null
	if _alert != null:
		_alert.queue_free()
		_alert = null


func _try_bribe() -> void:
	var st: RefCounted = game.state
	if st.money < _bribe:
		game.deny()
		return
	st.money -= _bribe
	var chance := clampf(0.7 - float(st.attention) / 250.0, 0.2, 0.8)
	if randf() < chance:
		map.calm()
		grace = 4.0
		phase = "back" if _was_back else "go"
		_say("He pocketed %d cr and looked the other way. Move." % _bribe, 5.0)
		game.sfx.play("confirmation_002", 0.8, -6.0)
	else:
		_say("He took the money AND searched you.", 5.0)
		_searched()


func _searched() -> void:
	var st: RefCounted = game.state
	var lost: int = Markets.lose_carry(st)
	st.attention = minf(100.0, st.attention + 8.0)
	_end_lines = ["Stopped after curfew. Papers checked, name written down (+8 Bureau attention)."]
	if lost > 0:
		_end_lines.append("They took the bag: %d thing%s gone." % [lost, "" if lost == 1 else "s"])
	_end_lines.append("A patrol walked you home.")
	phase = "end"
	garage.refresh()


func _arrive_home() -> void:
	var got: Array = Markets.bring_home(game.state)
	_end_lines = ["Home. The roller door, quietly."]
	if got.is_empty():
		_end_lines.append("Nothing in the bag.")
	else:
		_end_lines.append("On the shelves now: " + ", ".join(PackedStringArray(got)) + ".")
	phase = "end"
	game.sfx.play("confirmation_004", 1.0, -6.0)
	garage.refresh()


# ------------------------------------------------------------------ the loop

func _process(delta: float) -> void:
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	if map != null and phase in ["go", "back", "pick"]:
		_was_back = phase == "back" or (phase == "pick" and _was_back)
		grace = maxf(0.0, grace - delta)
		_running = Input.is_key_pressed(KEY_SHIFT) and not path.is_empty() and phase != "pick"
		if phase != "pick" and not path.is_empty():
			var sp := RUN if _running else WALK
			var tgt: Vector2 = path[0]
			var d := tgt - me
			if d.length() <= sp * delta:
				me = tgt
				path.pop_front()
				if path.is_empty() and want_gate:
					want_gate = false
					_open_lock()
			else:
				me += d.normalized() * sp * delta
		_hidden = map.dark.has(Vector2i(int(me.x), int(me.y)))
		var r: String = map.tick(delta, me, 3.5 if _running else 0.0, _hidden)
		if grace > 0.0:
			r = ""
			for p in map.patrols:
				if not p["chase"]:
					p["meter"] = 0.0
		if r == "caught":
			_caught()
		elif phase == "go" and me.distance_to(Vector2(map.yard) + Vector2(0.5, 0.5)) < 0.7:
			phase = "yard"
			path = []
			game.sfx.play("open_001", 0.6, -6.0)
			_say("The Tram Yard. Lanterns under the sheds. Watch who's too cheap.", 5.0)
		elif phase == "back" and me.distance_to(Vector2(map.home) + Vector2(0.5, 0.5)) < 0.7:
			_arrive_home()
		if _alert != null:
			_alert.queue_redraw()
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _btn(r: Rect2, label: String, id: String, primary := true, enabled := true) -> void:
	var hov := r.has_point(hover) and enabled
	var c := Pal.BRASS if primary else Pal.METAL_L
	if not enabled:
		c = Pal.METAL
	draw_rect(r, c.lightened(0.15) if hov else c)
	draw_rect(r, Pal.METAL_D, false, 1.0)
	draw_string(Pal.bold(), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, Pal.METAL_D if primary and enabled else Pal.TEXT)
	if enabled:
		_btns.append([r, id])


func _draw() -> void:
	_btns = []
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.06))
	match phase:
		"brief":
			_draw_brief()
		"yard":
			_draw_map()
			_draw_yard()
		"end":
			_draw_map()
			_draw_end()
		_:
			_draw_map()
			if phase == "caught":
				_draw_caught()
	if _msg_t > 0.0 and phase != "pick":
		var a := minf(1.0, _msg_t)
		var tw := Pal.font().get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var mr := Rect2(Vector2((size.x - tw) * 0.5 - 10, size.y - 44), Vector2(tw + 20, 18))
		draw_rect(mr, Color(Pal.METAL_D, 0.92 * a))
		draw_rect(mr, Color(Pal.BRASS, 0.7 * a), false, 1.0)
		draw_string(Pal.font(), mr.position + Vector2(10, 13), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Pal.TEXT, a))


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(Pal.METAL_D, 0.96))
	draw_rect(r, Pal.BRASS, false, 1.0)
	Pal.brackets(self, r.grow(4), Pal.BRASS, 8.0, 1.0)


func _draw_brief() -> void:
	var st: RefCounted = game.state
	var r := Rect2(size.x * 0.5 - 180, size.y * 0.5 - 125, 360, 250)
	_panel(r)
	Pal.tag(self, r.position + Vector2(12, -8), "THE ROLLER DOOR", 9)
	var x := r.position.x + 16
	var y := r.position.y + 26
	if not Markets.unlocked(st, "curfew"):
		draw_string(Pal.bold(), Vector2(x, y), "Nowhere to go yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.TEXT)
		draw_multiline_string(Pal.font(), Vector2(x, y + 20), "After curfew the town shuts. Somewhere a market opens, but you don't know where. The fixer does: sell him enough files from the Dead Drop and he'll tell you (trust %d)." % int(Markets.mdef("curfew").get("unlock_trust", 5)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 9, -1, Pal.DIM)
		_btn(Rect2(r.end.x - 110, r.end.y - 34, 94, 22), "STAY IN", "stay")
		return
	draw_string(Pal.bold(), Vector2(x, y), "THE TRAM YARD, AFTER CURFEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.BRASS)
	var lines := [
		"The black market under the old tram sheds. The most stock and the best grades in town.",
		"They take credits, or trade for cigarettes, vodka and your other materials.",
		"Patrols: %d, plus the searchlight. Lamps give you away; dark corners hide you." % (3 + int(st.attention / 30.0)),
		"Lock picks: %d (a padlocked gate on the way is a shortcut)." % int(st.supplies.get("picks", 0)),
		"Costs 1 night action. Get caught and they search you.",
	]
	y += 10
	for ln in lines:
		y += _wrap(Vector2(x, y), ln, r.size.x - 32, Pal.TEXT if ln == lines[0] else Pal.DIM) + 4
	_btn(Rect2(r.end.x - 214, r.end.y - 34, 94, 22), "STAY IN", "stay", false)
	_btn(Rect2(r.end.x - 110, r.end.y - 34, 94, 22), "GO OUT", "go", true, st.actions > 0)


func _wrap(pos: Vector2, s: String, w: float, col: Color, fs := 9) -> float:
	var h := Pal.font().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
	draw_multiline_string(Pal.font(), pos + Vector2(0, fs), s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
	return h


func _draw_map() -> void:
	if map == null:
		return
	var t := _tile()
	var o := _origin()
	var mapr := Rect2(o, Vector2(CurfewMap.W, CurfewMap.H) * t)
	for y in CurfewMap.H:
		for x in CurfewMap.W:
			var c := Vector2i(x, y)
			var r := Rect2(o + Vector2(x, y) * t, Vector2(t, t))
			var v: int = map.grid[y][x]
			if v == CurfewMap.WALL:
				draw_rect(r, Color(0.1, 0.095, 0.11))
				var edge := Color(0.24, 0.22, 0.25)
				if not map.is_wall(c + Vector2i(0, 1)):
					draw_rect(Rect2(r.position + Vector2(0, t - 2), Vector2(t, 2)), Color(0.05, 0.05, 0.06))
				if not map.is_wall(c + Vector2i(0, -1)):
					draw_line(r.position + Vector2(0, 0.5), Vector2(r.end.x, r.position.y + 0.5), edge, 1.0)
				if not map.is_wall(c + Vector2i(-1, 0)):
					draw_line(r.position + Vector2(0.5, 0), Vector2(r.position.x + 0.5, r.end.y), edge, 1.0)
				if not map.is_wall(c + Vector2i(1, 0)):
					draw_line(Vector2(r.end.x - 0.5, r.position.y), Vector2(r.end.x - 0.5, r.end.y), edge, 1.0)
				if (x * 31 + y * 17) % 13 == 0 and map.is_wall(c + Vector2i(0, 1)) and map.is_wall(c - Vector2i(0, 1)):
					draw_rect(Rect2(r.position + Vector2(t * 0.3, t * 0.3), Vector2(t * 0.35, t * 0.25)), Color(0.9, 0.65, 0.3, 0.55))    # a lit window
			else:
				draw_rect(r, Color(0.16, 0.165, 0.19))
				var l := float(map.lit.get(c, 0.0))
				if l > 0.0:
					draw_rect(r, Color(1.0, 0.68, 0.28, l * 0.32))
				if map.dark.has(c):
					draw_rect(r, Color(0, 0, 0, 0.5))
				if v == CurfewMap.GATE:
					var gc := Color(0.6, 0.42, 0.2) if not map.gate_open else Color(0.35, 0.28, 0.18)
					for k in 3:
						var gx := r.position.x + (k + 0.5) * t / 3.0
						draw_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y), gc, 2.0 if not map.gate_open else 1.0)
					if not map.gate_open:
						draw_rect(Rect2(r.get_center() - Vector2(3, 3), Vector2(6, 6)), Pal.BRASS)
	for l in map.lamps:
		draw_circle(_to_px(Vector2(l) + Vector2(0.5, 0.5)), 2.0, Color(1.0, 0.85, 0.5))
	# home and the yard
	var hp := _to_px(Vector2(map.home) + Vector2(0.5, 0.5))
	draw_rect(Rect2(hp - Vector2(t, t) * 0.7, Vector2(t, t) * 1.4), Color(Pal.BRASS, 0.35))
	draw_string(Pal.bold(), hp + Vector2(t, 4), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.BRASS)
	var yp := _to_px(Vector2(map.yard) + Vector2(0.5, 0.5))
	for k in 4:
		draw_circle(yp, t * (2.2 - k * 0.45), Color(1.0, 0.6, 0.2, 0.08 + 0.02 * sin(_t * 3.0)))
	draw_string(Pal.bold(), yp + Vector2(-t * 6, -t * 0.9), "TRAM YARD", HORIZONTAL_ALIGNMENT_RIGHT, t * 5, 8, Pal.BRASS)
	# the searchlight
	var lp: Vector2 = map.light["pos"]
	var la := float(map.light["ang"])
	var pts := PackedVector2Array([_to_px(lp)])
	for k in 9:
		var a := la - 0.22 + 0.44 * k / 8.0
		var dir := Vector2(cos(a), sin(a))
		pts.append(_to_px(lp + dir * map.ray(lp, dir, float(map.light["range"]))))
	draw_colored_polygon(pts, Color(0.85, 0.9, 1.0, 0.16))
	draw_circle(_to_px(lp), 3.0, Color(0.85, 0.9, 1.0))
	# patrols and their torches
	for p in map.patrols:
		var pp: Vector2 = p["pos"]
		var dir0: Vector2 = p["dir"]
		var base := dir0.angle()
		var cone := PackedVector2Array([_to_px(pp)])
		for k in 11:
			var a := base - CurfewMap.CONE + 2.0 * CurfewMap.CONE * k / 10.0
			var dv := Vector2(cos(a), sin(a))
			cone.append(_to_px(pp + dv * map.ray(pp, dv, CurfewMap.RANGE)))
		var m := 1.0 if p["chase"] else float(p["meter"])
		draw_colored_polygon(cone, Color(1.0, 0.9 - m * 0.6, 0.5 - m * 0.4, 0.13 + m * 0.2))
		var px := _to_px(pp)
		draw_circle(px, t * 0.42, Color(0.12, 0.16, 0.3))
		draw_circle(px + dir0 * t * 0.25, t * 0.15, Color(0.9, 0.9, 0.8))
		if p["chase"]:
			draw_string(Pal.bold(), px + Vector2(-4, -t * 0.8), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.3, 0.2))
		elif float(p.get("lost", 0.0)) > 0.0:
			draw_string(Pal.bold(), px + Vector2(-4, -t * 0.8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.TEXT)
		elif m > 0.02:
			draw_arc(px + Vector2(0, -t * 1.0), 4.0, -PI * 0.5, -PI * 0.5 + TAU * m, 16, Color(1.0, 0.8 - m * 0.5, 0.3), 2.0)
	# you
	if phase != "end":
		if not path.is_empty():
			var prev := _to_px(me)
			for w in path:
				var q := _to_px(w)
				draw_line(prev, q, Color(Pal.BRASS, 0.35), 1.0)
				prev = q
		var mp := _to_px(me)
		draw_circle(mp, t * 0.48, Color(0, 0, 0, 0.6))
		draw_circle(mp, t * 0.38, Color(0.95, 0.68, 0.3) if not _hidden else Color(0.45, 0.35, 0.22))
		if Markets.carrying(game.state).size() > 0:
			draw_rect(Rect2(mp + Vector2(t * 0.2, 0), Vector2(t * 0.4, t * 0.35)), Color(0.25, 0.45, 0.55))
		if _running:
			draw_arc(mp, 3.5 * t, 0, TAU, 32, Color(1.0, 0.6, 0.3, 0.25 + 0.1 * sin(_t * 12.0)), 1.0)
	draw_rect(mapr, Pal.METAL_L, false, 1.0)
	if phase in ["yard", "end"]:
		return
	# HUD
	var obj := "GET TO THE TRAM YARD" if phase == "go" else ("GET HOME" if phase in ["back", "caught"] else "AFTER CURFEW")
	Pal.tag(self, Vector2(12, 8), "AFTER CURFEW  |  " + obj, 9)
	var mm: float = map.max_meter()
	var br := Rect2(size.x - 170, 12, 120, 6)
	draw_rect(br, Pal.METAL_D)
	draw_rect(Rect2(br.position, Vector2(br.size.x * mm, br.size.y)), Color(1.0, 0.78 - mm * 0.5, 0.25))
	draw_string(Pal.font(), Vector2(br.end.x + 6, br.end.y + 2), "SEEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.DIM if mm < 0.3 else Color(1, 0.5, 0.3))
	var info := "%d cr   picks %d   bag %d" % [game.state.money, int(game.state.supplies.get("picks", 0)), Markets.carrying(game.state).size()]
	draw_string(Pal.font(), Vector2(size.x - 330, 18), info, HORIZONTAL_ALIGNMENT_RIGHT, 150, 8, Pal.TEXT)
	if _hidden and phase in ["go", "back"]:
		draw_string(Pal.bold(), Vector2(size.x - 170, 30), "IN THE DARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.DIM)
	if phase in ["go", "back"]:
		draw_string(Pal.font(), Vector2(0, size.y - 10), "CLICK: walk     HOLD SHIFT: run (loud)     DARK CORNERS hide you, LAMPS give you away     CLICK THE GATE: pick it", HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, Pal.DIM)


func _draw_caught() -> void:
	var r := Rect2(size.x * 0.5 - 150, size.y * 0.5 - 70, 300, 140)
	_panel(r)
	Pal.tag(self, r.position + Vector2(12, -8), "STOPPED", 9)
	var y := r.position.y + 24
	draw_string(Pal.bold(), Vector2(r.position.x + 14, y), "\"Papers. What's in the bag?\"", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.TEXT)
	y += 12
	var n: int = Markets.carrying(game.state).size()
	_wrap(Vector2(r.position.x + 14, y), "A patrolman, torch in your face. %s A bribe might work. It might not." % ("You're carrying %d things from the yard." % n if n > 0 else "Your bag is empty."), r.size.x - 28, Pal.DIM)
	_btn(Rect2(r.position.x + 14, r.end.y - 34, 130, 22), "BRIBE %d cr" % _bribe, "bribe", true, game.state.money >= _bribe)
	_btn(Rect2(r.end.x - 144, r.end.y - 34, 130, 22), "LET THEM SEARCH", "search", false)


func _draw_end() -> void:
	var r := Rect2(size.x * 0.5 - 160, size.y * 0.5 - 70, 320, 140)
	_panel(r)
	Pal.tag(self, r.position + Vector2(12, -8), "BACK INSIDE", 9)
	var y := r.position.y + 20
	for ln in _end_lines:
		y += _wrap(Vector2(r.position.x + 14, y), str(ln), r.size.x - 28, Pal.TEXT) + 4
	_btn(Rect2(r.end.x - 110, r.end.y - 34, 94, 22), "DONE", "done")


func _draw_yard() -> void:
	var st: RefCounted = game.state
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.045, 0.94))
	var r := Rect2(16, 22, size.x - 32, size.y - 76)
	_panel(r)
	Pal.tag(self, r.position + Vector2(12, -8), "THE TRAM YARD", 9)
	draw_string(Pal.bold(), Vector2(r.end.x - 200, r.position.y + 16), "%d cr" % st.money, HORIZONTAL_ALIGNMENT_RIGHT, 186, 11, Pal.BRASS)
	# stalls
	var list := Markets.offers(st, "curfew")
	var cw := (r.size.x - 200 - 24) / 3.0
	var ch := 62.0
	for i in list.size():
		var o: Dictionary = list[i]
		var cr := Rect2(r.position.x + 10 + (i % 3) * (cw + 4), r.position.y + 26 + (i / 3) * (ch + 4), cw, ch)
		var sold: bool = o["sold"]
		draw_rect(cr, Color(0.2, 0.15, 0.11) if not sold else Color(0.13, 0.1, 0.08))
		draw_rect(cr, Color(Pal.BRASS, 0.35), false, 1.0)
		var a := 0.4 if sold else 1.0
		draw_string(Pal.font(), cr.position + Vector2(6, 11), str(o.get("stall", "")), HORIZONTAL_ALIGNMENT_LEFT, cw - 12, 7, Color(Pal.DIM, a))
		draw_string(Pal.bold(), cr.position + Vector2(6, 23), str(o["name"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 12, 9, Color(Pal.TEXT, a))
		var sub := "x%d" % int(o["qty"])
		draw_string(Pal.font(), cr.position + Vector2(6, 35), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Pal.TEXT, a))
		if int(o.get("grade", 0)) > 0:
			for k in 5:
				var pc := cr.position + Vector2(30 + k * 8, 32)
				if k < int(o["grade"]):
					draw_circle(pc, 2.5, Color(Pal.BRASS, a))
				else:
					draw_arc(pc, 2.5, 0, TAU, 10, Color(Pal.DIM, a * 0.6), 1.0)
		if str(o.get("tell", "")) != "":
			draw_string(Pal.font(), cr.position + Vector2(6, 47), str(o["tell"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 64, 7, Color(1.0, 0.55, 0.4, a))
		_btn(Rect2(cr.end.x - 58, cr.end.y - 20, 52, 16), "SOLD" if sold else "%d cr" % int(o["price"]), "buy:%d" % i, true, not sold and st.money >= int(o["price"]))
	# your bag + barter
	var side := Rect2(r.end.x - 196, r.position.y + 26, 186, r.size.y - 36)
	draw_rect(side, Color(0.13, 0.1, 0.08))
	draw_string(Pal.bold(), side.position + Vector2(6, 12), "YOUR BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.BRASS)
	var y := side.position.y + 24
	var carry: Array = Markets.carrying(st)
	if carry.is_empty():
		draw_string(Pal.font(), Vector2(side.position.x + 6, y), "empty", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.DIM)
		y += 12
	for o in carry.slice(0, 5):
		draw_string(Pal.font(), Vector2(side.position.x + 6, y), "%s x%d" % [o["name"], int(o["qty"])], HORIZONTAL_ALIGNMENT_LEFT, side.size.x - 12, 8, Pal.TEXT)
		y += 11
	y += 6
	draw_string(Pal.bold(), Vector2(side.position.x + 6, y), "TRADE YOURS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.BRASS)
	y += 6
	var mats: Array = []
	for id in st.materials:
		if int(st.materials[id]) > 0:
			mats.append(id)
	mats.sort_custom(func(a, b) -> bool: return Markets.barter_value(st, a) > Markets.barter_value(st, b))
	for id in mats.slice(0, 7):
		var row := Rect2(side.position.x + 4, y + 4, side.size.x - 8, 15)
		draw_string(Pal.font(), row.position + Vector2(2, 11), "%s (%d)" % [Markets.item_name("material", id), int(st.materials[id])], HORIZONTAL_ALIGNMENT_LEFT, side.size.x - 70, 8, Pal.TEXT)
		_btn(Rect2(row.end.x - 50, row.position.y, 48, 14), "+%d" % Markets.barter_value(st, id), "trade:" + str(id), false)
		y += 17
	_btn(Rect2(r.end.x - 130, r.end.y - 30, 118, 22), "HEAD HOME", "home")
