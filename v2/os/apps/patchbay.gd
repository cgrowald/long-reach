extends "res://v2/os/app.gd"
## PATCHBAY: the whole hack in one window (docs/HACKING.md, user 2026-11-22: "quick and fun, limited screen
## switching"). Left: tonight's targets. Middle: the briefing, then CONNECT (route the signal), then INJECT
## (the code chain), then the report. Right: the box on your desk (gadgets = multipliers). Top: the trace.
## On site (air-gapped places, with a drop stick): TUNE replaces CONNECT and a patrol clock replaces the trace.
## Rules live in v2/sim/hack.gd.

const Hack := preload("res://v2/sim/hack.gd")

const HEAD_H := 20.0
const LEFT_W := 150.0
const RIGHT_W := 132.0
const ROW_H := 36.0
const KIND_ICON := {"office": "file", "depot": "package", "shop": "drive", "clinic": "computer", "police": "lock"}

var targets: Array = []
var sel := 0
var s: RefCounted = null          # the running session (hack.gd)
var report: Dictionary = {}
var sel_tray := -1
var hover := Vector2(-1, -1)
var _knob_drag := -1
var _flash := 0.0
var _msg := ""
var _msg_t := 0.0
var _guide_next := 0              # tutorial: the next kettle line to show during the inject
var _last_stage := ""
var _aps: Array[AudioStreamPlayer] = []
var _api := 0
var _warned := 0.0             # last trace warning level played
const Synth := preload("res://v2/ui/synth.gd")
var _t := 0.0


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 6:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		_aps.append(ap)
	if win and not win.maximized:
		win.toggle_max()
	refresh()


func refresh() -> void:
	targets = Hack.tonight(state())
	if arg != "":
		for i in targets.size():
			if targets[i]["id"] == arg:
				sel = i
		arg = ""
	sel = clampi(sel, 0, maxi(0, targets.size() - 1))
	queue_redraw()


func cur() -> Dictionary:
	return targets[sel] if sel < targets.size() else {}


# ------------------------------------------------------------------ layout

func _left() -> Rect2:
	return Rect2(0, HEAD_H, LEFT_W, size.y - HEAD_H)


func _right() -> Rect2:
	return Rect2(size.x - RIGHT_W, HEAD_H, RIGHT_W, size.y - HEAD_H)


func _mid() -> Rect2:
	return Rect2(LEFT_W + 6, HEAD_H + 6, size.x - LEFT_W - RIGHT_W - 12, size.y - HEAD_H - 12)


func _row(i: int) -> Rect2:
	return Rect2(4, HEAD_H + 18 + i * (ROW_H + 3), LEFT_W - 8, ROW_H)


## Buttons in the middle's bottom strip: [[label, id, primary]]
func _buttons() -> Array:
	var out: Array = []
	if s == null and report.is_empty():
		var t := cur()
		if t.is_empty():
			return out
		var st := Hack.status(state(), t)
		if st == "ready":
			out.append(["CONNECT", "connect", true])
			if Hack.has_key(state(), t):
				out.append(["LOG IN AS %s" % str(t["owner"]).split(" ")[0].to_upper(), "login", false])
		elif st == "air_gap":
			out.append(["GO ON SITE", "onsite", true])
	elif s != null and s.stage == "inject":
		out.append(["JACK OUT", "out", true])
	elif s != null and s.stage in ["connect", "tune"]:
		out.append(["ABORT", "out", false])
	elif not report.is_empty():
		out.append(["BACK TO TARGETS", "back", true])
	return out


func _button_rect(i: int) -> Rect2:
	var m := _mid()
	var w := 120.0
	return Rect2(m.position.x + i * (w + 6), m.end.y - 18, w, 18)


# connect board
func _cell() -> float:
	var m := _mid()
	return floorf(minf((m.size.x - 40) / s.gw, (m.size.y - 122) / s.gh))


func _board() -> Rect2:
	var m := _mid()
	var c := _cell()
	var bs := Vector2(c * s.gw, c * s.gh)
	return Rect2(Vector2(m.position.x + (m.size.x - bs.x) * 0.5, m.position.y + 16), bs)


func _cell_rect(p: Vector2i) -> Rect2:
	var b := _board()
	var c := _cell()
	return Rect2(b.position + Vector2(p.x * c, p.y * c), Vector2(c, c)).grow(-1)


func _tray_rect(i: int) -> Rect2:
	var b := _board()
	var n: int = s.tray.size()
	var w := floorf(minf(28.0, (_mid().size.x - 12) / n - 6))
	var x0 := _mid().position.x + (_mid().size.x - n * (w + 6)) * 0.5
	return Rect2(x0 + i * (w + 6), b.end.y + 14, w, w)


# inject grid
func _chain_cell() -> float:
	return 22.0


func _chain_rect(p: Vector2i) -> Rect2:
	var m := _mid()
	var c := _chain_cell()
	return Rect2(m.position + Vector2(4 + p.x * c, 34 + p.y * c), Vector2(c, c)).grow(-1)


func _knob_rect(i: int) -> Rect2:
	var m := _mid()
	return Rect2(m.position.x + m.size.x * 0.5 - 60 + i * 84, m.position.y + 132, 36, 36)


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
		if _knob_drag >= 0 and s != null:
			s.turn_knob(_knob_drag, -e.relative.y * 0.004)
		queue_redraw()
		return
	if e is InputEventMouseButton:
		var p: Vector2 = e.position
		if not e.pressed:
			_knob_drag = -1
			return
		accept_event()
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and s != null and s.stage == "tune":
			for i in 2:
				if _knob_rect(i).grow(10).has_point(p):
					s.turn_knob(i, 0.02 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -0.02)
			return
		if e.button_index == MOUSE_BUTTON_RIGHT:
			if s != null and s.stage == "connect":
				var c := _cell_at(p)
				if c.x >= 0:
					s.lift(c)
					os.game.click()
			sel_tray = -1
			queue_redraw()
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		click(p)


func click(p: Vector2) -> void:
	var bs := _buttons()
	for i in bs.size():
		if _button_rect(i).has_point(p):
			press(bs[i][1])
			return
	if s == null and report.is_empty():
		for i in targets.size():
			if _row(i).has_point(p):
				sel = i
				os.game.click()
				queue_redraw()
				return
		return
	if s == null:
		return
	match s.stage:
		"connect":
			for i in s.tray.size():
				if _tray_rect(i).has_point(p) and not s.tray[i]["used"]:
					sel_tray = i
					os.game.click()
					queue_redraw()
					return
			var c := _cell_at(p)
			if c.x >= 0:
				click_cell(c)
		"tune":
			for i in 2:
				if _knob_rect(i).grow(6).has_point(p):
					_knob_drag = i
		"inject":
			for y in s.chain_n:
				for x in s.chain_n:
					if _chain_rect(Vector2i(x, y)).has_point(p):
						pick(Vector2i(x, y))
						return


func _cell_at(p: Vector2) -> Vector2i:
	if s == null:
		return Vector2i(-1, -1)
	for y in s.gh:
		for x in s.gw:
			if _cell_rect(Vector2i(x, y)).has_point(p):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Click a board cell: place the selected tray piece, or turn a placed one.
func click_cell(c: Vector2i) -> void:
	var cell: Dictionary = s.cells[c.y][c.x]
	if cell["kind"] == "empty" and sel_tray >= 0:
		if s.place(sel_tray, c):
			os.game.sfx.play("drop_002", 1.2, -10.0)
			_beep(220.0, 0.05, 0.7, -6.0)
			sel_tray = _next_free_tray()
	elif cell["kind"] == "placed":
		s.turn(c)
		os.game.sfx.play("click_001", 1.3, -8.0)
		_beep(1800.0, 0.008, 0.5, -12.0, randf_range(0.9, 1.1))
	_after_move()
	queue_redraw()


func _next_free_tray() -> int:
	for i in s.tray.size():
		if not s.tray[i]["used"]:
			return i
	return -1


func _after_move() -> void:
	if s.stage == "inject":
		_flash = 1.0
		os.game.sfx.play("confirmation_002", 1.0, -6.0)
		_say("LINK UP. Now spell the programs into the buffer.")
		_arp([520.0, 780.0, 1040.0, 1560.0])


func pick(p: Vector2i) -> void:
	if not s.can_pick(p):
		os.game.deny()
		return
	var ran: Array = s.pick(p)
	os.game.sfx.play("click_001", 1.0 + s.buffer.size() * 0.05, -8.0)
	_beep(900.0 + s.buffer.size() * 110.0, 0.02, 0.2, -10.0)
	if ran.is_empty() and s.buffer.size() >= s.buf_max:
		_beep(140.0, 0.12, 0.6, -4.0)
	for pid in ran:
		_say("%s RAN." % Hack.program(pid).get("name", pid))
		_arp([660.0, 990.0, 1320.0])
		_flash = 0.6
		os.game.sfx.play("confirmation_002", 1.2, -6.0)
	if s.stage == "done":
		_end()
	queue_redraw()


func press(id: String) -> void:
	os.game.click()
	var t := cur()
	match id:
		"connect", "login":
			if not _pay(t):
				return
			s = Hack.create(state(), t, hash(str(state().world_seed) + t["id"] + str(state().day) + str(_t)))
			if id == "login":
				s.skip_connect()
				_say("Logged in as %s. Straight to the inject." % t["owner"])
			else:
				_say("Route the signal from IN to OUT. Click a piece, click a slot, click again to turn it.")
			_guide(t, 1)
			sel_tray = _next_free_tray()
		"onsite":
			var stick := _drop_stick()
			if stick.is_empty():
				os.alert("Patchbay", "%s is air-gapped: the PC can't reach it.\nMake a drop stick at the hacking bench and go there with it." % t["name"], "warn")
				return
			if not _pay(t):
				return
			state().items.erase(stick)
			s = Hack.create(state(), t, hash(t["id"] + str(state().day) + str(_t)), true)
			_say("On site. Plug in, then turn the two knobs until your signal sits on theirs. Patrol's coming.")
		"out":
			if s != null:
				s.jack_out()
				_end()
		"back":
			report = {}
			s = null
			refresh()
	queue_redraw()


func _pay(t: Dictionary) -> bool:
	if os.spend_hours.is_valid() and not os.spend_hours.call(float(t.get("hours", 2.0))):
		os.alert("Patchbay", "No night actions left. A hack takes one.", "warn")
		return false
	return true


func _drop_stick() -> Dictionary:
	for it in state().items:
		if it.get("device", "") == "drop_stick":
			return it
	return {}


func _end() -> void:
	report = s.finish(state())
	report["target"] = s.target
	report["onsite"] = s.onsite
	if report.get("cut", false):
		os.game.sfx.play("error_004", 0.8, -4.0)
	else:
		os.game.sfx.play("confirmation_002", 0.9, -6.0)


func _say(m: String) -> void:
	_msg = m
	_msg_t = 4.0


## Tutorial targets: kettle's line for this stage, shown longer.
func _guide(t: Dictionary, i: int) -> void:
	var g: Array = t.get("guide", [])
	if t.get("tutorial", false) and i < g.size():
		_say(str(g[i]))
		_msg_t = 9.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	_msg_t = maxf(0.0, _msg_t - delta)
	if s != null and report.is_empty():
		var was: String = s.stage
		s.tick(delta)
		_trace_warn()
		if was == "tune" and s.stage == "inject":
			_flash = 1.0
			os.game.sfx.play("confirmation_002", 1.0, -6.0)
			_say("LOCKED ON. Upload before the patrol comes round.")
		if s.stage == "inject" and _last_stage != "inject":
			_guide(s.target, 2)
			_guide_next = 3
		elif _guide_next > 0 and _msg_t < 0.5:
			_guide(s.target, _guide_next)
			_guide_next = _guide_next + 1 if _guide_next < 4 else 0
		if s.stage == "done":
			_end()
		_last_stage = s.stage
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
	_draw_head()
	_draw_targets()
	_draw_box()
	var m := _mid()
	draw_rect(m.grow(2), P.PETROL)
	if not report.is_empty():
		_draw_report()
	elif s == null:
		_draw_brief()
	else:
		match s.stage:
			"connect":
				_draw_connect()
			"tune":
				_draw_tune()
			"inject", "done":
				_draw_inject()
	var bs := _buttons()
	for i in bs.size():
		var r := _button_rect(i)
		var prim: bool = bs[i][2]
		var hov := r.has_point(hover)
		draw_rect(r, (P.COPPER.lightened(0.1) if hov else P.COPPER) if prim else (P.FACE_L if hov else P.FACE))
		draw_rect(r, P.PETROL_D, false, 1.0)
		P.text(self, r.position + Vector2(0, 4), bs[i][0], P.FACE_L if prim else P.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if _msg_t > 0.0 and _msg != "":
		var a := minf(1.0, _msg_t)
		var two := P.font().get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS).x > m.size.x - 12
		var mr := Rect2(m.position.x, m.end.y - (52 if two else 40), m.size.x, 28 if two else 16)
		draw_rect(mr, Color(P.PETROL_D, 0.9 * a))
		draw_multiline_string(P.font(), mr.position + Vector2(6, 11), _msg, HORIZONTAL_ALIGNMENT_LEFT, mr.size.x - 12, P.FS, 2, Color(P.FACE_L, a))
	if _flash > 0.0:
		draw_rect(m, Color(P.COPPER, _flash * 0.25))


func _draw_head() -> void:
	draw_rect(Rect2(0, 0, size.x, HEAD_H), P.FACE_L)
	draw_line(Vector2(0, HEAD_H - 0.5), Vector2(size.x, HEAD_H - 0.5), P.FACE_D)
	var steps := ["TARGET", "TUNE" if (s != null and s.onsite) else "CONNECT", "INJECT", "DONE"]
	var cur_i := 0
	if not report.is_empty():
		cur_i = 3
	elif s != null:
		cur_i = {"connect": 1, "tune": 1, "inject": 2, "done": 3}.get(s.stage, 0)
	for i in steps.size():
		var r := Rect2(4 + i * 74, 3, 70, HEAD_H - 6)
		var on := i == cur_i
		draw_rect(r, P.COPPER if on else (P.FACE if i < cur_i else P.FACE_L))
		draw_rect(r, P.FACE_D, false, 1.0)
		P.text(self, r.position + Vector2(0, 2), "%d %s" % [i + 1, steps[i]], P.FACE_L if on else (P.INK if i <= cur_i else P.INK_DIM), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# trace (or the patrol clock on site)
	var label := "PATROL" if (s != null and s.onsite) else "TRACE"
	var tr := Rect2(size.x - 190, 4, 150, HEAD_H - 8)
	P.text(self, Vector2(tr.position.x - P.tw(label) - 6, 4), label, P.INK)
	draw_rect(tr, P.PETROL_D)
	var v: float = s.trace if s != null else 0.0
	var col := P.SAGE if v < 0.5 else (P.COPPER if v < 0.8 else P.BAD)
	var segs := 12
	for k in segs:
		var sr := Rect2(tr.position.x + 2 + k * (tr.size.x - 4) / segs, tr.position.y + 2, (tr.size.x - 4) / segs - 1, tr.size.y - 4)
		if float(k) / segs < v:
			draw_rect(sr, col)
	P.text(self, Vector2(tr.end.x + 4, 4), "%d%%" % int(v * 100), P.INK)


func _draw_targets() -> void:
	var l := _left()
	draw_rect(Rect2(l.position, Vector2(l.size.x, 14)), P.PETROL)
	P.text(self, l.position + Vector2(6, 2), "TONIGHT", P.FACE_L)
	for i in targets.size():
		var t: Dictionary = targets[i]
		var r := _row(i)
		var st := Hack.status(state(), t)
		var on := i == sel and s == null
		draw_rect(r, P.COPPER.lerp(P.FACE_L, 0.55) if on else (P.FACE_L if r.has_point(hover) else P.WIN))
		draw_rect(r, P.COPPER if on else P.FACE_D, false, 1.0)
		P.icon(self, KIND_ICON.get(t.get("kind", ""), "target"), r.position + Vector2(4, 4), 14.0)
		P.text(self, r.position + Vector2(22, 3), P.fit(str(t["name"]), r.size.x - 26), P.INK)
		for k in 3:
			var c := r.position + Vector2(26 + k * 8, 24)
			draw_circle(c, 2.5, P.COPPER if k < int(t.get("tier", 1)) else Color(P.INK, 0.15))
		var chip: String = {"ready": "READY", "air_gap": "AIR GAP", "locked": "LOCKED %d" % Hack.nights_locked(state(), t)}[st]
		var chip_col: Color = {"ready": P.SAGE, "air_gap": P.COPPER, "locked": P.INK_DIM}[st]
		if (state().os.get("jobs_done", []) as Array).has(t["id"]) and st == "ready":
			chip = "DONE"
		var cw := P.tw(chip) + 8
		var cr := Rect2(r.end.x - cw - 4, r.position.y + 19, cw, 13)
		draw_rect(cr, chip_col)
		P.text(self, cr.position + Vector2(4, 1), chip, P.FACE_L if st != "ready" else P.INK)
	if targets.is_empty():
		P.text(self, l.position + Vector2(6, 22), "Nothing tonight.", P.INK_DIM)


func _draw_box() -> void:
	var r := _right()
	draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), P.PETROL)
	P.text(self, r.position + Vector2(6, 2), "THE BOX", P.FACE_L)
	var info := {"scan": "ghost tiles on the route", "crack": "a longer buffer", "net": "a slower trace"}
	var y := r.position.y + 18
	for slot in ["scan", "crack", "net"]:
		var g := Hack.plugged(state(), slot)
		var row := Rect2(r.position.x + 4, y, r.size.x - 8, 38)
		draw_rect(row, P.WIN)
		draw_rect(row, P.FACE_D, false, 1.0)
		P.text(self, row.position + Vector2(4, 2), slot.to_upper(), P.COPPER)
		if g.is_empty():
			P.text(self, row.position + Vector2(4, 13), "empty", P.INK_DIM)
		else:
			P.text(self, row.position + Vector2(4, 13), P.fit(str(g["name"]).replace(" (gadget)", ""), row.size.x - 8), P.INK)
			for k in 5:
				draw_circle(row.position + Vector2(row.size.x - 38 + k * 7, 7), 2.2, P.COPPER if k < int(g.get("stars", 0)) else Color(P.INK, 0.15))
		P.text(self, row.position + Vector2(4, 24), P.fit(info[slot], row.size.x - 8), P.INK_DIM)
		y += 42
	P.text(self, Vector2(r.position.x + 6, y + 2), "Night actions: %d" % int(state().actions), P.INK)
	P.text(self, Vector2(r.position.x + 6, y + 14), "Money: %d cr" % int(state().money), P.INK)
	draw_multiline_string(P.font(), Vector2(r.position.x + 6, r.end.y - 30), "Craft better hardware at the bench, then plug it in on the desk.", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, P.FS - 1, -1, P.INK_DIM)


func _mid_text(pos: Vector2, s2: String, col: Color, fsz := P.FS) -> float:
	var m := _mid()
	var w := m.end.x - pos.x - 6
	draw_multiline_string(P.font(), pos + Vector2(0, P.font().get_ascent(fsz)), s2, HORIZONTAL_ALIGNMENT_LEFT, w, fsz, -1, col)
	return P.font().get_multiline_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, w, fsz).y


func _draw_brief() -> void:
	var m := _mid()
	var t := cur()
	if t.is_empty():
		return
	var x := m.position.x + 8
	var y := m.position.y + 6
	draw_string(P.Pal.bold(), Vector2(x, y + 12), str(t["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, m.size.x - 16, 11, P.FACE_L)
	y += 20
	y += _mid_text(Vector2(x, y), "%s.  Owner: %s." % [str(t.get("what", "")).capitalize(), t.get("owner_line", t.get("owner", "?"))], Color(P.FACE_L, 0.75))
	y += 6
	var st := Hack.status(state(), t)
	if st == "air_gap":
		y += _mid_text(Vector2(x, y), "AIR GAP. Nothing reaches it from outside. You need a drop stick from the hacking bench, and you go there yourself.", P.COPPER)
		y += 6
	elif st == "locked":
		y += _mid_text(Vector2(x, y), "They patched it after last time. Try again in %d nights." % Hack.nights_locked(state(), t), P.COPPER)
		y += 6
	if Hack.has_key(state(), t):
		y += _mid_text(Vector2(x, y), "You have %s's password (from their dirt): you can skip the connect." % t["owner"], P.SAGE)
		y += 6
	if t.get("tutorial", false):
		for ln in t.get("guide", []).slice(0, 1):
			y += _mid_text(Vector2(x, y), str(ln), P.COPPER) + 4
		y += _mid_text(Vector2(x, y), "Clean exit = you keep these programs for good. Cut out = just try again.", P.SAGE) + 6
	P.text(self, Vector2(x, y), "PROGRAMS YOU CAN UPLOAD HERE", Color(P.FACE_L, 0.6))
	y += 13
	for pid in t.get("programs", []):
		var pd := Hack.program(pid)
		var known := Hack.usable(state(), t, pid)
		P.text(self, Vector2(x, y), "%s %s" % ["+" if known else "x", pd.get("name", pid)], P.FACE_L if known else Color(P.FACE_L, 0.35))
		var tx := "%s" % pd.get("text", "") if known else "Locked: you don't know how yet."
		if known and not Hack.knows(state(), pid):
			tx = "LEARN IT HERE. " + tx
		_mid_text(Vector2(x + 70, y - 1), tx, Color(P.FACE_L, 0.7 if known else 0.3), P.FS - 1)
		y += 22
	P.text(self, Vector2(x, m.end.y - 34), "Costs 1 night action.", Color(P.FACE_L, 0.6))


func _pipe(r: Rect2, mask: int, col: Color, w: float) -> void:
	var c := r.get_center()
	var h := r.size.x * 0.5
	draw_circle(c, w * 0.6, col)
	for b in Hack.DIRS:
		if mask & b:
			var d: Vector2 = Vector2(Hack.DIRS[b])
			draw_line(c, c + d * h, col, w)


func _draw_connect() -> void:
	var b := _board()
	var c := _cell()
	P.text(self, Vector2(_mid().position.x + 8, _mid().position.y + 2), "SIGNAL ROUTE   %d / %d links lit" % [s.lit.size(), _route_len()], P.FACE_L)
	# in and out
	var ir := _cell_rect(Vector2i(0, s.in_row))
	var orr := _cell_rect(Vector2i(s.gw - 1, s.out_row))
	draw_colored_polygon(PackedVector2Array([Vector2(b.position.x - 14, ir.get_center().y - 7), Vector2(b.position.x - 2, ir.get_center().y), Vector2(b.position.x - 14, ir.get_center().y + 7)]), P.COPPER)
	draw_rect(Rect2(b.end.x + 3, orr.get_center().y - 6, 12, 12), P.SAGE if s.connected else P.FACE_D)
	for y in s.gh:
		for x in s.gw:
			var p := Vector2i(x, y)
			var r := _cell_rect(p)
			var cell: Dictionary = s.cells[y][x]
			var lit: bool = s.lit.has(p)
			match cell["kind"]:
				"empty":
					draw_rect(r, P.PETROL_L if r.has_point(hover) and sel_tray >= 0 else P.PETROL_D)
					draw_rect(r, Color(P.FACE_L, 0.18), false, 1.0)
					if cell.get("hint", "") != "":
						var hm: int = cell.get("want", 0)
						_pipe(r, hm, Color(P.FACE_L, 0.12), c * 0.16)
					else:
						P.text(self, r.get_center() - Vector2(3, 6), "+", Color(P.FACE_L, 0.2))
				"blocked":
					draw_rect(r, Color(P.PETROL_D, 0.6))
					draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Color(P.BAD, 0.6), 2.0)
					draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), Color(P.BAD, 0.6), 2.0)
				"fixed":
					draw_rect(r, P.FACE.darkened(0.25))
					_pipe(r, cell["mask"], P.COPPER if lit else P.INK.lightened(0.2), c * 0.18)
				"placed":
					draw_rect(r, P.FACE_L if not r.has_point(hover) else P.FACE)
					draw_rect(r, P.COPPER if lit else P.FACE_D, false, 1.0)
					_pipe(r, cell["mask"], P.COPPER if lit else P.PETROL, c * 0.2)
	# the tray
	var ty := _tray_rect(0).position.y - 10
	P.text(self, Vector2(_mid().position.x + 8, ty - 2), "TILE TRAY   (right-click a placed tile to take it back)", Color(P.FACE_L, 0.6))
	for i in s.tray.size():
		var r := _tray_rect(i)
		var used: bool = s.tray[i]["used"]
		draw_rect(r, Color(P.FACE_L, 0.12) if used else (P.COPPER if i == sel_tray else P.FACE_L))
		draw_rect(r.grow(1), P.FACE_L if i == sel_tray else Color(P.FACE_L, 0.3), false, 1.0)
		if not used:
			_pipe(r.grow(-5), Hack.SHAPES[s.tray[i]["shape"]], P.PETROL if i != sel_tray else P.FACE_L, 3.0)


func _route_len() -> int:
	var n := 0
	for y in s.gh:
		for x in s.gw:
			if s.cells[y][x].has("want") or (s.cells[y][x]["kind"] == "fixed" and s.lit.has(Vector2i(x, y))):
				n += 1
	return maxi(n, s.lit.size())


func _draw_tune() -> void:
	var m := _mid()
	P.text(self, m.position + Vector2(8, 2), "HANDHELD  -  match their signal and hold it", P.FACE_L)
	var scope := Rect2(m.position + Vector2(20, 18), Vector2(m.size.x - 40, 100))
	draw_rect(scope, Color(0.04, 0.09, 0.07))
	for gx in 8:
		draw_line(Vector2(scope.position.x + gx * scope.size.x / 8, scope.position.y), Vector2(scope.position.x + gx * scope.size.x / 8, scope.end.y), Color(0.3, 0.6, 0.4, 0.15))
	draw_line(Vector2(scope.position.x, scope.get_center().y), Vector2(scope.end.x, scope.get_center().y), Color(0.3, 0.6, 0.4, 0.25))
	var theirs := PackedVector2Array()
	var mine := PackedVector2Array()
	for i in 80:
		var u := float(i) / 79.0
		var x := scope.position.x + u * scope.size.x
		var f1: float = 1.0 + s.goal.x * 6.0
		var f2: float = 1.0 + s.knob.x * 6.0
		theirs.append(Vector2(x, scope.get_center().y - sin(u * TAU * f1 + _t * 2.0) * s.goal.y * 44.0))
		mine.append(Vector2(x, scope.get_center().y - sin(u * TAU * f2 + _t * 2.0) * s.knob.y * 44.0))
	draw_polyline(theirs, Color(0.55, 1.0, 0.6, 0.55), 2.0)
	draw_polyline(mine, P.COPPER, 2.0)
	P.text(self, scope.position + Vector2(4, 2), "THEIRS", Color(0.55, 1.0, 0.6, 0.8))
	P.text(self, scope.position + Vector2(56, 2), "YOURS", P.COPPER)
	for i in 2:
		var kr := _knob_rect(i)
		var v: float = s.knob.x if i == 0 else s.knob.y
		draw_circle(kr.get_center(), kr.size.x * 0.5, P.FACE.darkened(0.3))
		draw_circle(kr.get_center(), kr.size.x * 0.4, P.FACE_L)
		var a := lerpf(-PI * 1.25, PI * 0.25, v)
		draw_line(kr.get_center(), kr.get_center() + Vector2(cos(a), sin(a)) * kr.size.x * 0.4, P.INK, 2.0)
		P.text(self, Vector2(kr.position.x - 10, kr.end.y + 2), ["FREQ", "AMP"][i], P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x + 20)
	var lr := Rect2(m.position.x + 20, m.position.y + 190, m.size.x - 40, 10)
	draw_rect(lr, P.PETROL_D)
	draw_rect(Rect2(lr.position, Vector2(lr.size.x * s.lock, lr.size.y)), P.SAGE)
	P.text(self, Vector2(lr.position.x, lr.end.y + 2), "LOCK %d%%   (drag a knob up/down, or scroll on it)" % int(s.lock * 100), Color(P.FACE_L, 0.7))


func _draw_inject() -> void:
	var m := _mid()
	P.text(self, m.position + Vector2(6, 2), "INJECT  -  pick along the lit %s" % ("row" if s.axis == "row" else "column"), P.FACE_L)
	# the buffer
	var bw := minf(26.0, (m.size.x - 12.0) / maxf(1.0, s.buf_max))
	for i in s.buf_max:
		var br := Rect2(m.position.x + 6 + i * bw, m.position.y + 15, bw - 2, 14)
		draw_rect(br, P.PETROL_D)
		draw_rect(br, Color(P.FACE_L, 0.3), false, 1.0)
		if i < s.buffer.size():
			P.text(self, br.position + Vector2(0, 1), s.buffer[i], P.COPPER, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	# the grid
	for y in s.chain_n:
		for x in s.chain_n:
			var p := Vector2i(x, y)
			var r := _chain_rect(p)
			var on_line: bool = (s.axis == "row" and y == s.line) or (s.axis == "col" and x == s.line)
			if on_line and s.stage == "inject":
				draw_rect(r.grow(1), Color(P.COPPER, 0.22))
			var used: bool = s.used.has(p)
			var hov: bool = r.has_point(hover) and s.can_pick(p)
			if hov:
				draw_rect(r, P.COPPER)
			P.text(self, r.position + Vector2(0, 4), "[ ]" if used else s.chain[y][x], Color(P.FACE_L, 0.25) if used else (P.FACE_L if on_line else Color(P.FACE_L, 0.55)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# the programs
	var px: float = m.position.x + 20 + s.chain_n * _chain_cell()
	var py := m.position.y + 48
	P.text(self, Vector2(px, py - 14), "PROGRAMS", Color(P.FACE_L, 0.6))
	for pr in s.programs:
		var code: Array = pr["code"]
		var prog: int = s.progress(pr)
		var col := P.SAGE if pr["done"] else (P.FACE_L if pr["known"] else Color(P.FACE_L, 0.3))
		P.text(self, Vector2(px, py), ("OK " if pr["done"] else "") + str(pr["name"]), col)
		if pr["known"]:
			for k in code.size():
				var cr := Rect2(px + 2 + k * 22, py + 11, 20, 12)
				draw_rect(cr, P.SAGE if k < prog else P.PETROL_D)
				P.text(self, cr.position + Vector2(0, 0), code[k], P.INK if k < prog else Color(P.FACE_L, 0.8), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
		else:
			P.text(self, Vector2(px + 2, py + 11), "locked", Color(P.FACE_L, 0.3))
		py += 28


func _draw_report() -> void:
	var m := _mid()
	var t: Dictionary = report.get("target", {})
	var cut: bool = report.get("cut", false)
	var x := m.position.x + 8
	var y := m.position.y + 6
	draw_string(P.font(), Vector2(x, y + 12), ("CUT OUT  -  " if cut else "CLEAN EXIT  -  ") + str(t.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, m.size.x - 16, 11, P.BAD.lightened(0.3) if cut else P.SAGE)
	y += 24
	for ln in report.get("lines", []):
		y += _mid_text(Vector2(x, y), "- " + str(ln), P.FACE_L) + 3
	y += 6
	_mid_text(Vector2(x, y), "Files land on the shelves as intel. Sell them or post them from the Drop app.", Color(P.FACE_L, 0.6))


# ------------------------------------------------------------------ sounds (made in code: v2/ui/synth.gd)

func _beep(freq: float, decay: float, noise := 0.3, db := -8.0, pitch := 1.0) -> void:
	if _aps.is_empty():
		return
	var ap := _aps[_api]
	_api = (_api + 1) % _aps.size()
	ap.stream = Synth.tick(freq, decay, noise)
	ap.pitch_scale = pitch
	ap.volume_db = db
	ap.play()


## A quick rising run of notes: a program ran, the link came up.
func _arp(freqs: Array) -> void:
	for i in freqs.size():
		get_tree().create_timer(0.06 * i).timeout.connect(_beep.bind(float(freqs[i]), 0.05, 0.1, -8.0))


## Trace warnings: a low double pulse at 50%, 75% and 90%.
func _trace_warn() -> void:
	if s == null or s.stage == "done":
		_warned = 0.0
		return
	if s.trace < 0.05:
		_warned = 0.0
	for lv in [0.5, 0.75, 0.9]:
		if s.trace >= lv and _warned < lv:
			_warned = lv
			_beep(180.0, 0.07, 0.4, -6.0)
			get_tree().create_timer(0.14).timeout.connect(_beep.bind(180.0, 0.07, 0.4, -6.0))
