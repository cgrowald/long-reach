extends "res://v2/os/app.gd"
## TARGETS (M4 V4, v2/sim/targets.gd): every place you could hit, until the V5 map. The list on the left
## (fixed ones first), the place on the right: what you know about it, where the tip came from, and three
## things to do: WATCH it (a night action: the layout, then guards and hours), PLAN THE HIT (the plan sheet,
## then the fight), or POST IT ON NOD (someone else hits it; you get followers, not the loot).

const Targets := preload("res://v2/sim/targets.gd")

const ROW_H := 30.0
const LIST_W := 196.0
const SOURCE := {"fixed": "Always there.", "hack": "From a hack of the place.", "chair": "A prisoner gave it up.", "nod": "A tip on Nod.",
	"job": "A job.", "word": "Word on the street."}

var sel := 0
var scroll := 0
var hover := Vector2(-1, -1)
var _msg := ""
var _msg_t := 0.0
var _btns: Array = []        # [Rect2, id]


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _list() -> Array:
	return Targets.list(state())


func _row(i: int) -> Rect2:
	return Rect2(4, 18 + (i - scroll) * (ROW_H + 2), LIST_W - 4, ROW_H)


func _visible_rows() -> int:
	return int((size.y - 22) / (ROW_H + 2))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
		queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		accept_event()
		var L := _list()
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampi(scroll + 1, 0, maxi(0, L.size() - _visible_rows()))
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = maxi(0, scroll - 1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			for i in range(scroll, mini(L.size(), scroll + _visible_rows())):
				if _row(i).has_point(e.position):
					sel = i
					os.game.click()
			for b in _btns:
				if (b[0] as Rect2).has_point(e.position):
					_press(str(b[1]), L[sel])
		queue_redraw()


func _press(id: String, t: Dictionary) -> void:
	match id:
		"watch":
			if int(state().actions) <= 0:
				_say("No time left tonight. Watch it tomorrow.")
				os.game.deny()
				return
			os.game.click()
			_say(Targets.watch(state(), t))
		"plan":
			if not Targets.can_hit(state(), t):
				_say("It's shut. Try again in %d night%s." % [Targets.shut_for(state(), t), "" if Targets.shut_for(state(), t) == 1 else "s"])
				os.game.deny()
				return
			if Targets.team(state(), t).is_empty():
				_say("Nobody is fit to go. The hurt need time, or treatment.")
				os.game.deny()
				return
			if int(state().actions) <= 0:
				_say("No time left tonight.")
				os.game.deny()
				return
			os.game.click()
			os.game.set_meta("fight_target", t["id"])
			os.game.set_meta("fight_plan", {})
			os.game.goto("res://v2/combat/plan_screen.tscn")
		"nod":
			if t.has("nod_hit"):
				_say("Already posted. Wait and see.")
				return
			if int(t["know"]) < 1:
				_say("You don't know enough to post it. Watch it first.")
				os.game.deny()
				return
			os.game.sfx.play("drop_002", 1.0, -6.0)
			_say(Targets.post_on_nod(state(), t))


func _say(m: String) -> void:
	_msg = m
	_msg_t = 6.0
	queue_redraw()


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		queue_redraw()


func _status(t: Dictionary) -> Array:
	if t.has("nod_hit"):
		return ["POSTED", P.LINK]
	match str(t.get("status", "open")):
		"shut":
			return ["SHUT %dn" % Targets.shut_for(state(), t), P.INK_DIM]
	if t.has("job"):
		return ["JOB", P.COPPER]
	if t.get("event", false):
		return ["ONE CHANCE", P.BAD]
	return ["OPEN", P.GOOD]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
	_btns.clear()
	var L := _list()
	sel = clampi(sel, 0, maxi(0, L.size() - 1))
	P.text(self, Vector2(6, 3), "TARGETS  (%d)" % L.size(), P.INK)
	P.text(self, Vector2(LIST_W - 120, 3), "%d action%s left tonight" % [int(state().actions), "" if int(state().actions) == 1 else "s"], P.INK_DIM, HORIZONTAL_ALIGNMENT_RIGHT, 116)
	for i in range(scroll, mini(L.size(), scroll + _visible_rows())):
		var t: Dictionary = L[i]
		var r := _row(i)
		draw_rect(r, P.COPPER.lightened(0.55) if i == sel else (P.WIN.darkened(0.04) if r.has_point(hover) else P.WIN))
		draw_rect(r, P.FACE_D, false, 1.0)
		P.text(self, r.position + Vector2(4, 2), P.fit(str(t["name"]), r.size.x - 8), P.INK)
		var stt := _status(t)
		var B: Dictionary = load("res://v2/sim/building_gen.gd").data().get("types", {}).get(t["type"], {})
		P.text(self, r.position + Vector2(4, 15), P.fit("%s  %s" % [str(B.get("name", "Roadblock")).to_upper(), "*".repeat(int(t["tier"]))], 110), P.INK_DIM)
		P.text(self, r.position + Vector2(r.size.x - 64, 15), stt[0], stt[1], HORIZONTAL_ALIGNMENT_RIGHT, 60)
		# knowing: four pips
		for k in 3:
			var pr := Rect2(r.position + Vector2(r.size.x - 34 + k * 10, 4), Vector2(8, 5))
			draw_rect(pr, P.PETROL if int(t["know"]) > k else P.FACE_D.lightened(0.2))
	if L.is_empty():
		P.text(self, Vector2(8, 24), "Nothing yet. Hack places, listen on Nod.", P.INK_DIM)
		return
	_detail(L[sel], Rect2(LIST_W + 6, 4, size.x - LIST_W - 10, size.y - 8))
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t)
		var mr := Rect2(4, size.y - 18, size.x - 8, 15)
		draw_rect(mr, Color(P.PETROL_D, 0.92 * a))
		P.text(self, mr.position + Vector2(5, 2), P.fit(_msg, mr.size.x - 10), Color(P.FACE_L, a))


func _detail(t: Dictionary, r: Rect2) -> void:
	draw_rect(r, P.WIN)
	draw_rect(r, P.FACE_D, false, 1.0)
	var x := r.position.x + 6
	var y := r.position.y + 4
	var w := r.size.x - 12
	P.text(self, Vector2(x, y), P.fit(str(t["name"]), w), P.COPPER)
	y += 12
	var B: Dictionary = load("res://v2/sim/building_gen.gd").data().get("types", {}).get(t["type"], {})
	P.text(self, Vector2(x, y), P.fit("%s on %s   tier %d   %s" % [str(B.get("name", "Roadblock")), str(t.get("street", "?")), int(t["tier"]), SOURCE.get(str(t["source"]), "")], w), P.INK_DIM)
	y += 14
	y = _wrap(str(t.get("line", "")), x, y, w, P.INK, 3)
	if t.has("job"):
		var g := Targets.group_def(str(t["job"]))
		y = _wrap("Job for %s: %d cr when it's done." % [g.get("name", "?"), int(t.get("pay", 0))], x, y, w, P.COPPER, 1)
	y += 4
	draw_line(Vector2(x, y), Vector2(x + w, y), P.FACE_D, 1.0)
	y += 4
	P.text(self, Vector2(x, y), "WHAT WE KNOW: " + Targets.know_name(t), P.PETROL)
	y += 12
	y = _wrap(Targets.know_line(t), x, y, w, P.INK, 2)
	for wl in (t.get("watched", []) as Array).slice(-2):
		y = _wrap("Night %d: %s" % [int(wl["day"]), wl["line"]], x, y, w, P.INK_DIM, 2)
	var hard := Targets.extra_guards(state(), t)
	if hard > 0 and str(t.get("level", "")) == "":
		y = _wrap("They've hardened it: about %d more on the door than a place like this usually has." % hard, x, y, w, P.INK_DIM, 2)
	if int(t["know"]) >= 2:
		var lv := _level_of(t)
		var hour: String = str(((lv.get("plan", {}) as Dictionary).get("hours", [{"id": "day"}]) as Array)[0]["id"])
		var rr := Targets.ready_read(state(), t, lv, hour)
		y += 3
		P.text(self, Vector2(x, y), "READY?  " + str(rr["word"]), {"READY": P.GOOD, "RISKY": P.COPPER, "NOT READY": P.BAD}.get(str(rr["word"]), P.INK))
		y += 12
		for l in rr["lines"]:
			y = _wrap(str(l), x, y, w, P.INK_DIM, 1)
	if t.has("nod_hit"):
		y = _wrap("You posted it on Nod. Someone will do something about it soon.", x, y, w, P.LINK, 2)
	if Targets.kind(str(t["type"])).get("solo", false):
		y = _wrap("A one-person job. Nobody guards it.", x, y, w, P.INK_DIM, 1)
	# the buttons
	var bw := (w - 12) / 3.0
	var by := r.end.y - 24
	var can_plan := Targets.can_hit(state(), t)
	var bs := [["watch", "WATCH (1 action)", (int(t["know"]) < 2 or t.get("fixed", false)) and str(t.get("level", "")) == ""], ["plan", "PLAN THE HIT", can_plan], ["nod", "POST ON NOD", not t.has("nod_hit") and not t.get("event", false)]]
	for i in bs.size():
		var br := Rect2(x + i * (bw + 6), by, bw, 18)
		var on: bool = bs[i][2]
		var col: Color = (P.COPPER if bs[i][0] == "plan" else P.PETROL) if on else P.FACE_D
		draw_rect(br, col.lightened(0.12) if br.has_point(hover) and on else col)
		P.text(self, br.position + Vector2(0, 3), bs[i][1], P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
		if on:
			_btns.append([br, bs[i][0]])


var _lv_cache := {}


## The building tonight (generated once per target state; the app redraws often).
func _level_of(t: Dictionary) -> Dictionary:
	var key := "%s:%d:%d:%d:%d" % [t["id"], int(t["hits"]), int(t["reinforce"]), int(state().day), int(state().attention)]
	if not _lv_cache.has(key):
		_lv_cache = {key: Targets.level_for(state(), t)}
	return _lv_cache[key]


## Word-wrapped text, at most max_lines lines. Returns the next y.
func _wrap(s: String, x: float, y: float, w: float, col: Color, max_lines: int) -> float:
	var words := s.split(" ")
	var line := ""
	var n := 0
	for wd in words:
		var tryl := wd if line == "" else line + " " + wd
		if P.tw(tryl) > w and line != "":
			P.text(self, Vector2(x, y), line, col)
			y += 11
			n += 1
			line = wd
			if n >= max_lines:
				return y
		else:
			line = tryl
	if line != "" and n < max_lines:
		P.text(self, Vector2(x, y), line, col)
		y += 11
	return y
