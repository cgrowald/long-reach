extends "res://v2/os/app.gd"
## The hacking job window: header with the stages and the trace bar, the box's gadgets, then the stage:
## SCAN (ping the dark, knock on the login server), CRACK (three dials from the owner's life),
## SIPHON (queue files, disconnect before the trace fills), then the report. Rules: v2/sim/hack_job.gd.

const Job := preload("res://v2/sim/hack_job.gd")
const DARK := Color(0.03, 0.05, 0.06)
const GRN := Color(0.4, 1.0, 0.45)
const CUE := Color(1.0, 0.3, 0.85)
const STAGES := ["scan", "crack", "siphon"]

var job: RefCounted
var report: Dictionary = {}
var _t := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
var _choice: Array = []
var _dial_flash: Array = []        # per dial: [time_left, ok]
var _pops: Array = []              # {text, pos, t, col}
var _alarm := 0.0
var _hover_file := -1
var _mouse := Vector2.ZERO


func build() -> void:
	var td := Job.target_def(arg)
	job = Job.create(state(), td, hash(str(state().world_seed) + arg + str(state().day)))
	for d in job.dials:
		var crossed: Array = d["crossed"]
		var start := 0
		while crossed.has(start):
			start += 1
		_choice.append(start)
		_dial_flash.append([0.0, false])
	win.title = "Job - " + str(td.get("name", arg))
	win.icon = "target"
	win.closed.connect(_on_window_closed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	os.game.sfx.play("maximize_006", 0.7, -8.0)


func _on_window_closed() -> void:
	if job and not job.finished:
		job.disconnect_now()
		report = job.finish(state())


# ------------------------------------------------------------------ layout

func _body() -> Rect2:
	return Rect2(4, 30, size.x - 8, size.y - 34)


func _trace_rect() -> Rect2:
	return Rect2(size.x - 134, 4, 130, 11)


func _field() -> Rect2:
	var b := _body()
	return Rect2(b.position, b.size - Vector2(0, 12))


func _to_px(p: Vector2) -> Vector2:
	var f := _field()
	return f.position + Vector2(p.x * f.size.x, p.y * f.size.y)


func _to_field(px: Vector2) -> Vector2:
	var f := _field()
	return Vector2((px.x - f.position.x) / f.size.x, (px.y - f.position.y) / f.size.y)


func _dial_rect(i: int) -> Rect2:
	var b := _body()
	var x0 := b.position.x + b.size.x * 0.44
	var w := (b.size.x * 0.56 - 8) / 3.0
	return Rect2(x0 + i * (w + 4), b.position.y + 14, w, 70)


func _try_rect() -> Rect2:
	var b := _body()
	return Rect2(b.end.x - 92, b.position.y + 96, 88, 20)


func _file_rect(i: int) -> Rect2:
	var b := _body()
	return Rect2(b.position.x, b.position.y + 34 + i * 17, b.size.x, 15)


func _disc_rect() -> Rect2:
	var b := _body()
	return Rect2(b.end.x - 96, b.end.y - 18, 96, 18)


func _close_rect() -> Rect2:
	var b := _body()
	return Rect2(b.end.x - 70, b.end.y - 18, 70, 18)


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = e.position
		_hover_file = -1
		if job.stage == "siphon":
			for i in job.files.size():
				if _file_rect(i).has_point(_mouse):
					_hover_file = i
	elif e is InputEventMouseButton and e.pressed:
		accept_event()
		var p: Vector2 = e.position
		if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if job.stage == "crack":
				for i in job.dials.size():
					if _dial_rect(i).has_point(p):
						turn_dial(i, -1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		match job.stage:
			"scan":
				click_field(p)
			"crack":
				for i in job.dials.size():
					var r := _dial_rect(i)
					if r.has_point(p):
						turn_dial(i, -1 if p.y < r.get_center().y else 1)
						return
				if _try_rect().has_point(p):
					try_now()
			"siphon":
				if _disc_rect().has_point(p):
					disconnect_now()
					return
				for i in job.files.size():
					if _file_rect(i).has_point(p):
						grab(i)
			"done":
				if _close_rect().has_point(p):
					win.close()


## SCAN: click a seen machine to knock, anywhere else to ping.
func click_field(px: Vector2) -> void:
	if not _field().has_point(px):
		return
	for i in job.nodes.size():
		var nd: Dictionary = job.nodes[i]
		if nd["seen"] and _to_px(nd["pos"]).distance_to(px) < 10.0:
			if nd["kind"] == "router":
				return
			if job.knock(i):
				_pop("DOOR FOUND", _to_px(nd["pos"]), GRN)
				_stage_flash(GRN)
				os.game.sfx.play("confirmation_004", 1.0, -6.0)
			else:
				_pop("not a way in", _to_px(nd["pos"]), Color(1, 0.5, 0.4))
				os.game.sfx.play("error_006", 1.2, -10.0)
			_check_traced()
			return
	ping(_to_field(px))


func ping(fp: Vector2) -> Array:
	job.aspect = _field().size.x / maxf(1.0, _field().size.y)
	var found: Array = job.ping(fp)
	os.game.sfx.play("tick_002", 0.7, -8.0)
	for i in found:
		var nd: Dictionary = job.nodes[i]
		var at := _to_px(nd["pos"])
		get_tree().create_timer(0.15 + randf() * 0.15).timeout.connect(func() -> void:
			os.game.sfx.play("glass_002", 1.3 if nd["kind"] == "auth" else 1.0, -10.0)
			_pop(nd["name"], at, CUE if nd["kind"] == "auth" else GRN))
	if found.is_empty():
		_pop("nothing", _to_px(fp), Color(0.5, 0.6, 0.6))
	_check_traced()
	return found


func turn_dial(i: int, dir: int) -> void:
	var d: Dictionary = job.dials[i]
	if d["solved"]:
		return
	var n: int = (d["options"] as Array).size()
	var c: int = _choice[i]
	for k in n:
		c = posmod(c + dir, n)
		if not (d["crossed"] as Array).has(c):
			break
	_choice[i] = c
	os.game.sfx.play("click_003", 0.9 + i * 0.1, -10.0)


func try_now() -> void:
	var right: Array = job.try_password(_choice)
	for i in right.size():
		_dial_flash[i] = [0.7, right[i]]
	if job.stage == "siphon":
		_stage_flash(GRN)
		_pop("ACCESS GRANTED", _body().get_center(), GRN)
		os.game.sfx.play("confirmation_002", 1.0, -6.0)
	else:
		os.game.sfx.play("error_004", 0.9, -8.0)
		_pop("ACCESS DENIED", _try_rect().get_center() - Vector2(0, 14), Color(1, 0.4, 0.35))
	_check_traced()


func grab(i: int) -> void:
	if job.files[i]["queued"]:
		return
	job.queue_file(i)
	os.game.sfx.play("click_005", 1.0, -10.0)


func disconnect_now() -> void:
	job.disconnect_now()
	os.game.sfx.play("switch_002", 0.8, -6.0)
	_end()


func _check_traced() -> void:
	if job.traced and report.is_empty():
		_stage_flash(Color(1, 0.2, 0.15))
		os.game.sfx.play("error_006", 0.6, -4.0)
		_end()


func _end() -> void:
	_pops.clear()
	if report.is_empty():
		report = job.finish(state())


func _pop(text: String, at: Vector2, col: Color) -> void:
	_pops.append({"text": text, "pos": at, "t": 0.0, "col": col})


func _stage_flash(col: Color) -> void:
	_pops.clear()
	_flash = 0.35
	_flash_col = col


# ------------------------------------------------------------------ tick

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	for f in _dial_flash:
		f[0] = maxf(0.0, float(f[0]) - delta)
	for p in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 1.2)
	if job:
		var before: int = job.grabbed.size()
		job.tick(delta)
		if job.grabbed.size() > before:
			os.game.sfx.play("drop_002", 1.2, -8.0)
			var f: Dictionary = job.files[job.grabbed[-1]]
			_pop("GOT " + str(f["name"]), _file_rect(job.grabbed[-1]).get_center(), GRN)
		if job.trace > 0.7 and job.stage != "done":
			_alarm -= delta
			if _alarm <= 0.0:
				_alarm = lerpf(0.9, 0.25, (job.trace - 0.7) / 0.3)
				os.game.sfx.play("bong_001", 1.4, -14.0)
		_check_traced()
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
	_draw_header()
	match job.stage:
		"scan":
			_draw_scan()
		"crack":
			_draw_crack()
		"siphon":
			_draw_siphon()
		"done":
			_draw_report()
	for p in _pops:
		var a := 1.0 - float(p["t"]) / 1.2
		var pos: Vector2 = p["pos"] - Vector2(0, float(p["t"]) * 14.0)
		var tw := P.tw(p["text"])
		draw_rect(Rect2(pos - Vector2(tw * 0.5 + 2, 0), Vector2(tw + 4, 11)), Color(0, 0, 0, 0.6 * a))
		P.text(self, pos - Vector2(tw * 0.5, 0), p["text"], Color(p["col"], a))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_col, _flash * 0.6))


func _draw_header() -> void:
	var x := 4.0
	for i in STAGES.size():
		var s: String = STAGES[i]
		var cur: bool = s == job.stage
		var past: bool = STAGES.find(job.stage) > i or job.stage == "done"
		var lab := "%d %s" % [i + 1, {"scan": "SCAN", "crack": "CRACK", "siphon": "SIPHON"}[s]]
		var w := P.tw(lab) + 8
		P.bevel(self, Rect2(x, 3, w, 13), P.SEL if cur else P.FACE, not cur)
		P.text(self, Vector2(x + 4, 4), lab, Color.WHITE if cur else (P.GOOD if past else P.INK_DIM))
		x += w + 3
	# trace bar
	var tr := _trace_rect()
	var shake := Vector2.ZERO
	if job.trace > 0.8 and job.stage != "done":
		shake = Vector2(randf_range(-1, 1), 0).round()
	tr.position += shake
	P.text(self, Vector2(tr.position.x - 34, 4), "TRACE", P.BAD if job.trace > 0.7 else P.INK)
	draw_rect(tr, DARK)
	var col := GRN.lerp(Color(1, 0.25, 0.2), clampf(job.trace / 0.8, 0.0, 1.0))
	if job.trace > 0.7 and fmod(_t, 0.4) < 0.2:
		col = Color(1, 0.9, 0.9)
	draw_rect(Rect2(tr.position, Vector2(tr.size.x * job.trace, tr.size.y)), col)
	draw_rect(tr, P.FACE_D, false, 1.0)
	P.text(self, tr.position + Vector2(0, 0), "%d%%" % int(job.trace * 100.0), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
	# the box's gadgets, the multipliers
	var gs: Array = []
	for slot in ["scan", "crack", "net"]:
		var g: Dictionary = job.gadgets.get(slot, {})
		if g.is_empty():
			gs.append("%s: empty" % slot.to_upper())
		else:
			var eff := ""
			match slot:
				"scan":
					eff = "ping +%d%%" % int(round((job.ping_r / Job.BASE_PING - 1.0) * 100.0))
				"crack":
					eff = "crosses out %d" % (job.dials[0]["crossed"] as Array).size() if not job.dials.is_empty() else ""
				"net":
					eff = "trace x%.2f" % job.trace_mult
			gs.append("%s: %s %s" % [slot.to_upper(), "*".repeat(int(g["stars"])), eff])
	P.text(self, Vector2(6, 18), "BOX  " + "   |   ".join(PackedStringArray(gs)), P.INK_DIM)


func _draw_scan() -> void:
	var f := _field()
	draw_rect(f, DARK)
	for gx in range(1, 12):
		var x := f.position.x + f.size.x * gx / 12.0
		draw_line(Vector2(x, f.position.y), Vector2(x, f.end.y), Color(0.08, 0.16, 0.12))
	for gy in range(1, 7):
		var y := f.position.y + f.size.y * gy / 7.0
		draw_line(Vector2(f.position.x, y), Vector2(f.end.x, y), Color(0.08, 0.16, 0.12))
	var rad: float = job.ping_r * f.size.y
	# pings: an expanding ring, then a faint scanned area that stays
	for pg in job.pings:
		var c := _to_px(pg["pos"])
		var t := float(pg["t"])
		draw_circle(c, rad, Color(0.3, 0.9, 0.5, 0.05))
		if t < 1.0:
			draw_arc(c, rad * minf(1.0, t / 0.35), 0, TAU, 32, Color(GRN, 1.0 - t), 1.0)
	# links from the router
	var router := _to_px(job.nodes[0]["pos"])
	for nd in job.nodes:
		if nd["seen"] and nd["kind"] != "router":
			var to := _to_px(nd["pos"])
			var n := int(router.distance_to(to) / 6.0)
			for k in n:
				if k % 2 == 0:
					draw_line(router.lerp(to, float(k) / n), router.lerp(to, float(k + 1) / n), Color(0.2, 0.5, 0.3))
	for nd in job.nodes:
		if not nd["seen"]:
			continue
		var c := _to_px(nd["pos"])
		var kind: String = nd["kind"]
		var ic: String = {"router": "network", "auth": "lock", "files": "drive", "camera": "monitor", "printer": "file"}.get(kind, "computer")
		if kind == "auth":
			var pulse := 1.0 + 0.3 * sin(_t * 6.0)
			draw_arc(c, 11.0 * pulse, 0, TAU, 20, CUE, 1.0)
		P.icon(self, ic, c - Vector2(6, 6), 12.0)
		var lab: String = nd["name"]
		if kind == "auth":
			lab = "LOGIN SERVER: click to knock"
		P.text(self, c + Vector2(-P.tw(lab) * 0.5, 7), lab, CUE if kind == "auth" else Color(0.7, 0.9, 0.75))
	# where your next ping would reach
	if f.has_point(_mouse):
		draw_arc(_mouse, rad, 0, TAU, 32, Color(GRN, 0.25), 1.0)
	P.text(self, Vector2(f.position.x, f.end.y + 1), "Click the dark to ping (+%d%% trace). Find the LOGIN SERVER, then click it to knock." % int(Job.PING_TRACE * job.trace_mult * 100.0), P.INK)


func _draw_crack() -> void:
	var b := _body()
	var left := Rect2(b.position, Vector2(b.size.x * 0.42, b.size.y))
	draw_rect(left, P.WIN)
	draw_rect(left, P.FACE_D, false, 1.0)
	P.text(self, left.position + Vector2(4, 3), "WHOSE LOGIN: " + str(job.target.get("owner", "?")), P.SEL)
	var y := left.position.y + 17
	P.text(self, Vector2(left.position.x + 4, y), "What you know about them:", P.INK_DIM)
	y += 12
	for line in job.target.get("profile", []):
		var s := "- " + str(line)
		draw_multiline_string(P.font(), Vector2(left.position.x + 4, y + P.font().get_ascent(P.FS)), s, HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 8, P.FS, -1, P.INK)
		var h := P.font().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 8, P.FS).y
		y += h + 4
	P.text(self, Vector2(left.position.x + 4, left.end.y - 12), "People build passwords from their life.", P.INK_DIM)
	# dials
	P.text(self, Vector2(_dial_rect(0).position.x, b.position.y + 2), "Set the three dials, then TRY.  Wheel or click top/bottom to turn.", P.INK)
	for i in job.dials.size():
		var d: Dictionary = job.dials[i]
		var r := _dial_rect(i)
		var fl: Array = _dial_flash[i]
		var solved: bool = d["solved"]
		var base := Color(0.1, 0.35, 0.15) if solved else DARK
		if float(fl[0]) > 0.0:
			base = base.lerp(Color(0.2, 0.8, 0.3) if fl[1] else Color(0.8, 0.15, 0.1), float(fl[0]) / 0.7)
		draw_rect(r, base)
		draw_rect(r, P.FACE_D, false, 1.0)
		P.text(self, Vector2(r.position.x, r.position.y + 3), d["label"], Color(0.6, 0.8, 0.7), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var opts: Array = d["options"]
		var c: int = _choice[i]
		var prev: String = opts[_neighbour(d, c, -1)]
		var next: String = opts[_neighbour(d, c, 1)]
		P.text(self, Vector2(r.position.x, r.position.y + 16), prev, Color(0.4, 0.5, 0.45), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		draw_rect(Rect2(r.position.x + 3, r.position.y + 29, r.size.x - 6, 13), Color(0, 0, 0, 0.4))
		P.text(self, Vector2(r.position.x, r.position.y + 30), opts[c], GRN if solved else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		P.text(self, Vector2(r.position.x, r.position.y + 44), next, Color(0.4, 0.5, 0.45), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var crossed: Array = d["crossed"]
		if not crossed.is_empty():
			var names: Array = []
			for k in crossed:
				names.append(str(opts[k]))
			P.text(self, Vector2(r.position.x + 2, r.end.y - 11), "x " + ", ".join(PackedStringArray(names)), Color(0.9, 0.5, 0.4))
		Pal_lamp(Vector2(r.end.x - 6, r.position.y + 6), solved)
	var tr := _try_rect()
	P.bevel(self, tr, P.FACE, true)
	P.text(self, tr.position + Vector2(0, 5), "TRY  (+%d%% if wrong)" % int(Job.TRY_TRACE * job.trace_mult * 100.0), P.INK, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
	P.text(self, Vector2(_dial_rect(0).position.x, tr.position.y + 5), "Tries: %d" % job.tries, P.INK_DIM)


func Pal_lamp(c: Vector2, on: bool) -> void:
	draw_circle(c, 3.0, GRN if on else Color(0.2, 0.1, 0.08))
	draw_arc(c, 3.0, 0, TAU, 10, Color(0, 0, 0, 0.7), 1.0)


func _draw_siphon() -> void:
	var b := _body()
	# the pipe: server -> box
	var pipe := Rect2(b.position.x, b.position.y, b.size.x, 26)
	draw_rect(pipe, DARK)
	P.icon(self, "drive", pipe.position + Vector2(4, 5), 16.0)
	P.text(self, pipe.position + Vector2(22, 9), "SERVER", GRN)
	P.icon(self, "package", Vector2(pipe.end.x - 20, pipe.position.y + 5), 16.0)
	P.text(self, Vector2(pipe.end.x - 52, pipe.position.y + 9), "BOX", GRN)
	var a := pipe.position + Vector2(64, 13)
	var z := Vector2(pipe.end.x - 58, pipe.position.y + 13)
	draw_line(a, z, Color(0.15, 0.35, 0.2), 3.0)
	if not job.queue.is_empty():
		for k in 8:
			var ph := fmod(_t * 0.9 + k / 8.0, 1.0)
			draw_rect(Rect2(a.lerp(z, ph) - Vector2(2, 2), Vector2(4, 4)), GRN)
	for i in job.files.size():
		var f: Dictionary = job.files[i]
		var r := _file_rect(i)
		var hov: bool = i == _hover_file
		draw_rect(r, P.WIN.darkened(0.08) if hov else P.WIN)
		var prog := float(f["got"]) / float(f["size"])
		if f["queued"]:
			draw_rect(Rect2(r.position, Vector2(r.size.x * prog, r.size.y)), Color(0.4, 0.9, 0.45, 0.35))
		P.icon(self, "text", r.position + Vector2(2, 1), 13.0)
		P.text(self, r.position + Vector2(18, 2), f["name"], P.INK)
		P.text(self, r.position + Vector2(r.size.x * 0.42, 2), "%d MB" % int(f["size"]), P.INK_DIM)
		var tag: String = f["tag"]
		var tcol: Color = {"dirt": P.BAD, "plan": P.SEL, "money": P.GOOD, "names": P.BRAND.darkened(0.2)}.get(tag, P.INK_DIM)
		P.text(self, r.position + Vector2(r.size.x * 0.55, 2), tag.to_upper(), tcol)
		var st := "click to grab"
		if f["done"]:
			st = "GOT IT"
		elif f["queued"]:
			st = "%d%%" % int(prog * 100.0) if job.queue.size() > 0 and job.queue[0] == i else "queued"
		P.text(self, r.position + Vector2(r.size.x * 0.7, 2), st, P.GOOD if f["done"] else P.INK)
	var y := _file_rect(job.files.size()).position.y + 2
	if _hover_file >= 0:
		P.text(self, Vector2(b.position.x, y), str(job.files[_hover_file]["worth"]), P.INK)
	P.text(self, Vector2(b.position.x, b.end.y - 14), "Grab files. The trace climbs while you're in. Leave before it fills.", P.INK_DIM)
	var dr := _disc_rect()
	P.bevel(self, dr, Color(0.75, 0.3, 0.25), true)
	P.text(self, dr.position + Vector2(0, 4), "DISCONNECT", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, dr.size.x)


func _draw_report() -> void:
	var b := _body()
	draw_rect(b, P.WIN)
	draw_rect(b, P.FACE_D, false, 1.0)
	var traced: bool = report.get("traced", job.traced)
	var head := "TRACED - CUT OUT" if traced else "CLEAN EXIT"
	P.text(self, b.position + Vector2(8, 6), head, P.BAD if traced else P.GOOD)
	P.text(self, b.position + Vector2(8, 20), "Trace %d%%   pings %d   password tries %d" % [int(job.trace * 100.0), job.pings.size(), job.tries], P.INK)
	var y := b.position.y + 38
	P.text(self, Vector2(b.position.x + 8, y), "You took:" if not job.grabbed.is_empty() else "You took nothing.", P.INK)
	y += 12
	for i in job.grabbed:
		var f: Dictionary = job.files[i]
		var line := "%s  (%s)  %s" % [f["name"], str(f["tag"]).to_upper(), f["worth"]]
		if f["tag"] == "junk":
			line += "  - junk, binned"
		P.text(self, Vector2(b.position.x + 14, y), P.fit(line, b.size.x - 24), P.INK)
		y += 11
	y += 6
	if traced:
		P.text(self, Vector2(b.position.x + 8, y), "The Bureau found a clue (on your corkboard):", P.BAD)
		P.text(self, Vector2(b.position.x + 14, y + 12), P.fit(str(report.get("clue", "")), b.size.x - 24), P.INK)
	else:
		P.text(self, Vector2(b.position.x + 8, y), "Nobody saw you. The intel is on your shelves.", P.GOOD)
	var cr := _close_rect()
	P.bevel(self, cr, P.FACE, true)
	P.text(self, cr.position + Vector2(0, 4), "Close", P.INK, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)


## The next option in a direction, skipping ones the wordlist crossed out.
func _neighbour(d: Dictionary, c: int, dir: int) -> int:
	var n: int = (d["options"] as Array).size()
	var k := c
	for i in n:
		k = posmod(k + dir, n)
		if not (d["crossed"] as Array).has(k):
			return k
	return c
