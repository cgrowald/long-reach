extends "res://v2/os/app.gd"
## CONTACTS (M4 V4, v2/sim/targets.gd "the groups"): the five groups who buy what you bring. Each has trust
## (selling and jobs raise it; a job for their rival lowers it), goods that open with trust, one job at a
## time (it lands on the Targets list), and a favour once a week at the top trust. Groups you haven't met
## yet show as a locked row: they turn up as things happen.

const Targets := preload("res://v2/sim/targets.gd")

const LIST_W := 150.0
const ROW_H := 26.0
const LINE_H := 15.0

var sel := 0
var hover := Vector2(-1, -1)
var _msg := ""
var _msg_t := 0.0
var _btns: Array = []        # [Rect2, kind, payload]
var off_scroll := 0


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	state().flags.erase("contacts_new")


func _ids() -> Array:
	return Targets.group_ids()


func _row(i: int) -> Rect2:
	return Rect2(4, 18 + i * (ROW_H + 2), LIST_W - 4, ROW_H)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
		queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		accept_event()
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			off_scroll += 1
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			off_scroll = maxi(0, off_scroll - 1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			var ids := _ids()
			for i in ids.size():
				if _row(i).has_point(e.position):
					sel = i
					off_scroll = 0
					os.game.click()
			for b in _btns:
				if (b[0] as Rect2).has_point(e.position):
					_press(str(b[1]), b[2])
					break
		queue_redraw()


func _press(kind: String, payload) -> void:
	var gid: String = _ids()[sel]
	match kind:
		"sell":
			os.game.sfx.play("confirmation_002", 1.1, -6.0)
			_say(Targets.sell(state(), gid, payload))
		"buy":
			var r := Targets.buy(state(), gid, payload)
			if r.begins_with("Not") or r.begins_with("They don't") or r.begins_with("You already"):
				os.game.deny()
			else:
				os.game.sfx.play("confirmation_002", 1.0, -6.0)
			_say(r)
		"job":
			os.game.click()
			_say(Targets.take_job(state(), gid))
		"favour":
			os.game.sfx.play("confirmation_002", 0.9, -6.0)
			_say(Targets.favour(state(), gid))


func _say(m: String) -> void:
	_msg = m
	_msg_t = 6.0
	queue_redraw()


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
	_btns.clear()
	var ids := _ids()
	P.text(self, Vector2(6, 3), "CONTACTS", P.INK)
	P.text(self, Vector2(LIST_W - 80, 3), "%d cr" % int(state().money), P.INK_DIM, HORIZONTAL_ALIGNMENT_RIGHT, 76)
	for i in ids.size():
		var gid: String = ids[i]
		var r := _row(i)
		var met := Targets.met(state(), gid)
		draw_rect(r, P.COPPER.lightened(0.55) if i == sel else (P.WIN.darkened(0.04) if r.has_point(hover) else P.WIN))
		draw_rect(r, P.FACE_D, false, 1.0)
		if met:
			P.text(self, r.position + Vector2(4, 2), P.fit(str(Targets.group_def(gid).get("name", gid)), r.size.x - 8), P.INK)
			for k in 4:
				draw_rect(Rect2(r.position + Vector2(4 + k * 12, 16), Vector2(10, 5)), P.COPPER if Targets.trust(state(), gid) > k else P.FACE_D.lightened(0.2))
			if not Targets.job(state(), gid).is_empty():
				P.text(self, r.position + Vector2(r.size.x - 44, 12), "JOB", P.COPPER, HORIZONTAL_ALIGNMENT_RIGHT, 40)
		else:
			P.text(self, r.position + Vector2(4, 2), "???", P.INK_DIM)
			P.text(self, r.position + Vector2(4, 13), "not met yet", P.INK_DIM)
	sel = clampi(sel, 0, ids.size() - 1)
	_detail(ids[sel], Rect2(LIST_W + 6, 4, size.x - LIST_W - 10, size.y - 8))
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t)
		var mr := Rect2(4, size.y - 18, size.x - 8, 15)
		draw_rect(mr, Color(P.PETROL_D, 0.92 * a))
		P.text(self, mr.position + Vector2(5, 2), P.fit(_msg, mr.size.x - 10), Color(P.FACE_L, a))


func _button(r: Rect2, label: String, kind: String, payload, on := true) -> void:
	var col: Color = P.COPPER if on else P.FACE_D
	draw_rect(r, col.lightened(0.12) if on and r.has_point(hover) else col)
	P.text(self, r.position + Vector2(0, 2), label, P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if on:
		_btns.append([r, kind, payload])


func _detail(gid: String, r: Rect2) -> void:
	draw_rect(r, P.WIN)
	draw_rect(r, P.FACE_D, false, 1.0)
	var d := Targets.group_def(gid)
	var x := r.position.x + 6
	var y := r.position.y + 4
	var w := r.size.x - 12
	if not Targets.met(state(), gid):
		P.text(self, Vector2(x, y), "You haven't met them yet.", P.INK_DIM)
		P.text(self, Vector2(x, y + 12), "People like this turn up when you have what they want.", P.INK_DIM)
		return
	P.text(self, Vector2(x, y), str(d.get("name", gid)), P.COPPER)
	P.text(self, Vector2(x + w - 150, y), "TRUST %d / 4" % Targets.trust(state(), gid), P.INK, HORIZONTAL_ALIGNMENT_RIGHT, 150)
	y += 12
	P.text(self, Vector2(x, y), P.fit(str(d.get("who", "")), w), P.INK_DIM)
	y += 11
	P.text(self, Vector2(x, y), P.fit("Wants: %s.  Gives: %s" % [Targets.want_words(gid), str(d.get("gives", ""))], w), P.INK)
	y += 11
	var rival := str(d.get("rival", ""))
	if rival != "":
		P.text(self, Vector2(x, y), P.fit("Doesn't like it when you work for %s." % Targets.group_def(rival).get("name", rival), w), P.INK_DIM)
		y += 11
	# hand things over
	y += 3
	P.text(self, Vector2(x, y), "HAND OVER", P.PETROL)
	y += 12
	var offs := Targets.offers(state(), gid)
	if offs.is_empty():
		P.text(self, Vector2(x, y), "You have nothing they want right now.", P.INK_DIM)
		y += LINE_H
	var rows := 3
	off_scroll = clampi(off_scroll, 0, maxi(0, offs.size() - rows))
	for i in range(off_scroll, mini(offs.size(), off_scroll + rows)):
		var o: Dictionary = offs[i]
		P.text(self, Vector2(x, y + 2), P.fit(str(o["label"]), w - 90), P.INK)
		_button(Rect2(x + w - 84, y, 84, 13), "GIVE  %d cr" % int(o["price"]), "sell", o)
		y += LINE_H
	if offs.size() > rows:
		P.text(self, Vector2(x, y), "(%d more: scroll)" % (offs.size() - rows), P.INK_DIM)
		y += 11
	# their goods
	y += 3
	P.text(self, Vector2(x, y), "THEIR GOODS", P.PETROL)
	y += 12
	for s in Targets.stock(state(), gid):
		var open: bool = s["open"]
		P.text(self, Vector2(x, y + 2), P.fit(str(s["line"]), w - 90), P.INK if open else P.INK_DIM)
		if open:
			_button(Rect2(x + w - 84, y, 84, 13), "BUY  %d cr" % int(s["price"]), "buy", s, int(state().money) >= int(s["price"]))
		else:
			P.text(self, Vector2(x + w - 84, y + 2), "trust %d" % int(s["lvl"]), P.INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, 84)
		y += LINE_H
	# the job and the favour
	var by := r.end.y - 22
	var bw := (w - 6) / 2.0
	var j := Targets.job(state(), gid)
	if j.is_empty():
		_button(Rect2(x, by, bw, 16), "ASK FOR A JOB", "job", null)
	else:
		P.text(self, Vector2(x, by + 3), P.fit("JOB: %s (Targets)" % j["name"], bw), P.COPPER)
	var f: Dictionary = d.get("favour", {})
	var ready := Targets.favour_ready(state(), gid)
	_button(Rect2(x + bw + 6, by, bw, 16), ("FAVOUR: " + str(f.get("name", ""))) if ready else "FAVOUR at trust 4", "favour", null, ready)
