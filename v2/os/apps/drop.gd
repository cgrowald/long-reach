extends "res://v2/os/app.gd"
## DEAD DROP: what you do with stolen files (v2/sim/intel_market.gd). Every file: SELL it to the fixer
## (money now) or POST it on Nod from your anonymous account (followers; followers become recruit leads).
## One screen, two buttons per file.

const Market := preload("res://v2/sim/intel_market.gd")

const ROW_H := 34.0
const HEAD_H := 46.0

var hover := Vector2(-1, -1)
var scroll := 0
var _msg := ""
var _msg_t := 0.0


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _items() -> Array:
	return Market.intel(state())


func _row(i: int) -> Rect2:
	return Rect2(4, HEAD_H + 16 + (i - scroll) * (ROW_H + 3), size.x - 8, ROW_H)


func _sell_rect(i: int) -> Rect2:
	var r := _row(i)
	return Rect2(r.end.x - 176, r.position.y + 8, 84, 18)


func _post_rect(i: int) -> Rect2:
	var r := _row(i)
	return Rect2(r.end.x - 88, r.position.y + 8, 84, 18)


func _visible_rows() -> int:
	return int((size.y - HEAD_H - 20) / (ROW_H + 3))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
		queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		accept_event()
		var n := _items().size()
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampi(scroll + 1, 0, maxi(0, n - _visible_rows()))
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = maxi(0, scroll - 1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if int(Market.summary(state())["leads"]) > 0 and _lead_rect().has_point(e.position):
				var lp := Market.lead_person(state())
				os.alert("Dead Drop", "%s, %d. %s

\"%s\"

In it for: %s.

They're with you now (the gear cage)." % [lp["name"], int(lp["age"]), lp["background"]["name"], lp["hook"], lp["motive"]["name"]], "info")
				Market.meet_lead(state())
				os.game.sfx.play("confirmation_002", 1.0, -6.0)
				queue_redraw()
				return
			var items := _items()
			for i in range(scroll, mini(n, scroll + _visible_rows())):
				if _sell_rect(i).has_point(e.position):
					sell(items[i])
					return
				if _post_rect(i).has_point(e.position):
					post(items[i])
					return
		queue_redraw()


func sell(it: Dictionary) -> void:
	var cr := Market.sell(state(), it)
	os.game.sfx.play("confirmation_002", 1.1, -6.0)
	_say("The fixer paid %d cr for %s." % [cr, it["name"]])
	var tr := int(Market.summary(state())["trust"])
	if tr >= 3 and not state().flags.get("lantern_told", false):
		state().flags["lantern_told"] = true
		_say("The fixer slips you an address: lantern://. A black market on the PC (Lantern app).")
	if Market.market_open(state()) and not state().flags.get("market_told", false):
		state().flags["market_told"] = true
		_say("The fixer trusts you now: the Tram Yard, after curfew. Go out through the roller door.")


func post(it: Dictionary) -> void:
	var r := Market.post(state(), it)
	os.game.sfx.play("drop_002", 1.0, -6.0)
	if r["burned"]:
		_say("The account got flagged and shut down. New account: %s, starting from zero." % Market.handle(state()))
		os.game.deny()
	elif int(r["leads"]) > 0:
		_say("+%d followers. Someone wrote back: they want to help. (A recruit lead.)" % r["followers"])
	else:
		_say("Posted %s. +%d followers." % [it["name"], r["followers"]])


func _say(m: String) -> void:
	_msg = m
	_msg_t = 5.0
	queue_redraw()


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.FACE)
	var m := Market.summary(state())
	var cfg: Dictionary = Market.cfg().get("post", {})
	# header: the fixer on the left, your Nod account on the right
	var hl := Rect2(4, 4, size.x * 0.5 - 6, HEAD_H - 8)
	var hr := Rect2(size.x * 0.5 + 2, 4, size.x * 0.5 - 6, HEAD_H - 8)
	for r in [hl, hr]:
		draw_rect(r, P.WIN)
		draw_rect(r, P.FACE_D, false, 1.0)
	P.text(self, hl.position + Vector2(5, 3), "THE FIXER", P.COPPER)
	P.text(self, hl.position + Vector2(5, 14), "Trust %d / %d" % [int(m["trust"]), int(Market.cfg().get("sell", {}).get("trust_market", 5))], P.INK)
	P.text(self, hl.position + Vector2(5, 25), "Pays less for what he's had a lot of.", P.INK_DIM)
	P.text(self, hr.position + Vector2(5, 3), "NOD  %s" % Market.handle(state()), P.COPPER)
	P.text(self, hr.position + Vector2(5, 14), "%d followers   %d recruit leads" % [int(m["followers"]), int(m["leads"])], P.INK)
	var heat := float(m["acct_heat"]) / float(cfg.get("burn_at", 100))
	var hb := Rect2(hr.position.x + 5, hr.position.y + 27, hr.size.x - 70, 6)
	draw_rect(hb, P.PETROL_D)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * clampf(heat, 0, 1), hb.size.y)), P.COPPER if heat < 0.7 else P.BAD)
	P.text(self, Vector2(hb.end.x + 4, hr.position.y + 23), "HEAT", P.INK_DIM)
	# the files
	var items := _items()
	P.text(self, Vector2(6, HEAD_H + 2), "FILES  (%d)" % items.size(), P.INK)
	if int(m["leads"]) > 0:
		var lr := _lead_rect()
		draw_rect(lr, P.COPPER.lightened(0.15) if lr.has_point(hover) else P.COPPER)
		P.text(self, lr.position + Vector2(0, 2), "A LEAD WROTE BACK: MEET", P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
	if items.is_empty():
		P.text(self, Vector2(6, HEAD_H + 20), "Nothing to move. Hack something first (Jobs).", P.INK_DIM)
	for i in range(scroll, mini(items.size(), scroll + _visible_rows())):
		var it: Dictionary = items[i]
		var r := _row(i)
		draw_rect(r, P.WIN)
		draw_rect(r, P.FACE_D, false, 1.0)
		P.icon(self, "text", r.position + Vector2(4, 4), 14.0)
		P.text(self, r.position + Vector2(22, 3), P.fit("%s  [%s]" % [it["name"], str(it.get("tag", "")).to_upper()], r.size.x - 210), P.INK)
		P.text(self, r.position + Vector2(22, 17), P.fit(str(it.get("worth", "")), r.size.x - 210), P.INK_DIM)
		var sr := _sell_rect(i)
		var pr := _post_rect(i)
		draw_rect(sr, P.COPPER.lightened(0.1) if sr.has_point(hover) else P.COPPER)
		P.text(self, sr.position + Vector2(0, 3), "SELL %d cr" % Market.price(state(), it), P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
		draw_rect(pr, P.PETROL_L if pr.has_point(hover) else P.PETROL)
		P.text(self, pr.position + Vector2(0, 3), "POST +%d" % Market.followers_for(it), P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t)
		var mr := Rect2(4, size.y - 20, size.x - 8, 16)
		draw_rect(mr, Color(P.PETROL_D, 0.9 * a))
		P.text(self, mr.position + Vector2(6, 2), P.fit(_msg, mr.size.x - 12), Color(P.FACE_L, a))


func _lead_rect() -> Rect2:
	return Rect2(size.x - 170, HEAD_H, 164, 13)
