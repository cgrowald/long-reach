extends "res://v2/stations/station.gd"
## The hack rig: a stub of the job engine (docs/RESTART.md section 6). Pick up to 5 cards in order, pull SEND.
## CHIPS x MULT rolls up, a kill chain (SCAN > ACCESS > EXPLOIT > PAYLOAD) doubles it, and the score
## flows through the target's nodes with overkill carrying on. Nothing is kept: it's for the feel.

const ROLE_COL := {"SCAN": Color(0.45, 0.75, 1.0), "ACCESS": Color(0.5, 1.0, 0.45), "EXPLOIT": Color(1.0, 0.35, 0.28), "PAYLOAD": Color(1.0, 0.75, 0.25)}
const CHAIN := ["SCAN", "ACCESS", "EXPLOIT", "PAYLOAD"]
const CARD := Vector2(52, 70)

var _hand: Array = []
var _picked: Array = []          # indices into _hand, in play order
var _hover := -1
var _target: Dictionary = {}
var _hp: Array = []              # remaining defence per node
var _chips := 0.0
var _mult := 0.0
var _chips_show := 0.0
var _mult_show := 0.0
var _score_show := 0.0
var _chain_text := ""
var _phase := "pick"             # pick, scoring, done
var _lever := 0.0                # 0 up .. 1 pulled
var _lever_hover := false
var _t := 0.0
var _result := ""
var _bump := 0.0


func build() -> void:
	var back_b := Kit.button("Back", close, game)
	back_b.position = Vector2(size.x - 52, size.y - 22)
	add_child(back_b)
	_deal()


func _deal() -> void:
	var cards: Array = Content.world().get("cards", [])
	var targets: Array = Content.world().get("targets", [{}])
	_target = targets[randi() % targets.size()]
	_hp = (_target.get("defence", []) as Array).duplicate()
	_hand.clear()
	var pool := cards.duplicate()
	pool.shuffle()
	for i in mini(7, pool.size()):
		_hand.append(pool[i])
	# Make sure a full kill chain is possible, so the "OHHH" can happen.
	for role in CHAIN:
		var has := false
		for c in _hand:
			has = has or c["role"] == role
		if not has:
			for c in cards:
				if c["role"] == role:
					_hand[randi() % _hand.size()] = c
					break
	_picked.clear()
	_chips = 0.0
	_mult = 0.0
	_chips_show = 0.0
	_mult_show = 0.0
	_score_show = 0.0
	_chain_text = ""
	_result = ""
	_phase = "pick"


func _card_rect(i: int) -> Rect2:
	var n := _hand.size()
	var x0 := 20.0 + (size.x - 110.0 - n * (CARD.x + 4)) * 0.5
	var lift := -10.0 if _picked.has(i) else (-3.0 if i == _hover else 0.0)
	return Rect2(Vector2(x0 + i * (CARD.x + 4), size.y - CARD.y - 30 + lift), CARD)


func _lever_rect() -> Rect2:
	return Rect2(Vector2(size.x - 70, 96), Vector2(40, 120))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := -1
		for i in _hand.size():
			if _card_rect(i).has_point(event.position):
				h = i
		if h != _hover and h >= 0:
			game.hover()
		_hover = h
		_lever_hover = _lever_rect().has_point(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _phase == "done":
			_deal()
			game.sfx.play("drop_002", 1.0, -8.0)
			return
		if _phase != "pick":
			return
		if _lever_hover:
			_send()
		elif _hover >= 0:
			if _picked.has(_hover):
				_picked.erase(_hover)
				game.sfx.play("tick_001", 0.8, -8.0)
			elif _picked.size() < 5:
				_picked.append(_hover)
				game.sfx.play("tick_001", 1.0 + _picked.size() * 0.12, -6.0)
			_preview()


func _preview() -> void:
	_chips = 0.0
	_mult = 1.0
	for i in _picked:
		_chips += float(_hand[i]["chips"])
		_mult += float(_hand[i]["mult"])
	_chain_text = ""
	var roles: Array = []
	for i in _picked:
		roles.append(_hand[i]["role"])
	if _has_chain(roles):
		_chain_text = "KILL CHAIN x2"
	elif roles.count("ACCESS") >= 3:
		_chain_text = "BRUTE (loud)"


static func _has_chain(roles: Array) -> bool:
	var k := 0
	for r in roles:
		if k < CHAIN.size() and r == CHAIN[k]:
			k += 1
	return k == CHAIN.size()


func _send() -> void:
	if _picked.is_empty():
		game.deny()
		garage.toast("Pick some cards first.")
		return
	if not garage.spend(def.get("hours", 2.0)):
		return
	_phase = "scoring"
	game.clunk()
	garage.shake(0.25)
	var tw := create_tween()
	tw.tween_property(self, "_lever", 1.0, 0.12)
	tw.tween_property(self, "_lever", 0.0, 0.3).set_delay(0.15)
	_score_run()


func _score_run() -> void:
	_chips_show = 0.0
	_mult_show = 1.0
	for i in _picked:
		var c: Dictionary = _hand[i]
		await get_tree().create_timer(0.28).timeout
		if not is_inside_tree():
			return
		_chips_show += float(c["chips"])
		_mult_show += float(c["mult"])
		_bump = 1.0
		game.sfx.play("tick_004", 1.0 + _mult_show * 0.05, -4.0)
	await get_tree().create_timer(0.3).timeout
	var score := _chips_show * _mult_show
	if _chain_text.begins_with("KILL"):
		score *= 2.0
		game.sfx.play("confirmation_004", 1.2, -2.0)
		garage.shake(0.5)
	var tw := create_tween()
	tw.tween_property(self, "_score_show", score, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	# The score flows through the nodes; overkill carries on.
	var left := score
	var broken := 0
	for n in _hp.size():
		if left <= 0.0:
			break
		var take := minf(left, float(_hp[n]))
		var tw2 := create_tween()
		tw2.tween_method(func(v: float) -> void: _hp[n] = v, float(_hp[n]), float(_hp[n]) - take, 0.35)
		await tw2.finished
		left -= take
		if float(_hp[n]) <= 0.5:
			broken += 1
			game.sfx.play("glass_002", 1.0 + broken * 0.1, -4.0)
			garage.shake(0.3)
	var tiers := ["F: you got the building's name", "C: a floor plan", "B: a room number", "A: the room and a schedule", "S: the crate photo and the buyer"]
	_result = "INTEL " + tiers[clampi(broken, 0, tiers.size() - 1)]
	_phase = "done"


func _process(delta: float) -> void:
	_t += delta
	_bump = maxf(0.0, _bump - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(10, 8), size - Vector2(20, 16)), Color(0.06, 0.06, 0.07, 0.94))
	draw_rect(Rect2(Vector2(10, 8), size - Vector2(20, 16)), Pal.METAL_L, false, 1.0)
	Pal.text(self, Vector2(20, 14), "TARGET: %s" % _target.get("name", "?"), 10, Pal.PHOS)
	Pal.text(self, Vector2(20, 26), "placeholder job: cards and numbers are dummies, nothing is kept", 8, Pal.DIM)
	# The network.
	var nodes: Array = _target.get("nodes", [])
	var defs: Array = _target.get("defence", [])
	for i in nodes.size():
		var p := Vector2(40 + i * 100, 48)
		if i > 0:
			draw_line(p + Vector2(-28, 14), p + Vector2(0, 14), Pal.METAL_L, 1.0)
		var r := Rect2(p, Vector2(72, 30))
		var dead := float(_hp[i]) <= 0.5
		draw_rect(r, Color(0.12, 0.05, 0.05) if dead else Pal.METAL_D)
		draw_rect(r, Pal.MULT if dead else Pal.METAL_L, false, 1.0)
		Pal.text(self, r.position + Vector2(4, 3), str(nodes[i]), 8, Pal.DIM if dead else Pal.TEXT)
		var frac := clampf(float(_hp[i]) / maxf(1.0, float(defs[i])), 0.0, 1.0)
		draw_rect(Rect2(r.position + Vector2(4, 18), Vector2(64 * frac, 6)), Pal.CHIPS)
		draw_rect(Rect2(r.position + Vector2(4, 18), Vector2(64, 6)), Pal.METAL_L, false, 1.0)
		Pal.text(self, r.position + Vector2(4, 31), "%d" % int(ceil(float(_hp[i]))), 8, Pal.DIM)
	# Counters.
	var cy := 104.0
	var chips := _chips_show if _phase != "pick" else _chips
	var mult := _mult_show if _phase != "pick" else _mult
	var bump := _bump * 3.0
	var cr := Rect2(Vector2(40, cy - bump), Vector2(90, 26 + bump))
	draw_rect(cr, Color(0.05, 0.1, 0.2))
	Pal.text(self, cr.position + Vector2(0, 5), "%d" % int(chips), 14, Pal.CHIPS, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
	Pal.text(self, Vector2(136, cy + 6), "x", 12, Pal.TEXT)
	var mr := Rect2(Vector2(150, cy - bump), Vector2(64, 26 + bump))
	draw_rect(mr, Color(0.2, 0.05, 0.05))
	Pal.text(self, mr.position + Vector2(0, 5), Pal.fmt_mult(mult), 14, Pal.MULT, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	Pal.text(self, Vector2(226, cy + 2), "SCORE", 8, Pal.DIM)
	Pal.text(self, Vector2(226, cy + 11), "%d" % int(_score_show), 14, Pal.AMBER)
	if _chain_text != "":
		var a := 0.7 + 0.3 * sin(_t * 8.0)
		Pal.text(self, Vector2(40, cy + 32), _chain_text, 10, Color(Pal.AMBER, a))
	if _result != "":
		Pal.text(self, Vector2(40, cy + 46), _result, 10, Pal.GREEN)
		Pal.text(self, Vector2(40, cy + 58), "Click anywhere to deal again.", 8, Pal.DIM)
	# Cards.
	for i in _hand.size():
		var c: Dictionary = _hand[i]
		var r := _card_rect(i)
		var col: Color = ROLE_COL.get(c["role"], Pal.TEXT)
		draw_rect(r, Pal.PAPER.darkened(0.1 if i != _hover else 0.0))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 12)), col.darkened(0.35))
		Pal.text(self, r.position + Vector2(0, 2), c["role"], 8, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		Pal.wrap(self, r.position + Vector2(3, 16), c["name"], 8, Pal.INK, r.size.x - 5, 2)
		if int(c["chips"]) > 0:
			Pal.text(self, r.position + Vector2(3, 46), "+%d" % int(c["chips"]), 8, Pal.CHIPS.darkened(0.3))
		if float(c["mult"]) > 0.0:
			Pal.text(self, r.position + Vector2(3, 56), "+%s mult" % Pal.fmt_mult(float(c["mult"])), 8, Pal.MULT.darkened(0.2))
		var k := _picked.find(i)
		if k >= 0:
			draw_rect(r, Pal.AMBER, false, 2.0)
			draw_circle(r.position + Vector2(r.size.x - 6, 6), 6, Pal.AMBER)
			Pal.text(self, r.position + Vector2(r.size.x - 12, 1), str(k + 1), 8, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER, 12)
	Pal.text(self, Vector2(20, size.y - 24), "Pick up to 5 in order (SCAN > ACCESS > EXPLOIT > PAYLOAD), then pull SEND.", 8, Pal.DIM)
	# The SEND lever.
	var lr := _lever_rect()
	Pal.plate(self, lr, Pal.METAL_D)
	var slot := Rect2(lr.position + Vector2(17, 14), Vector2(6, lr.size.y - 28))
	draw_rect(slot, Color(0.02, 0.02, 0.02))
	var ky := slot.position.y + 6 + _lever * (slot.size.y - 12)
	draw_line(Vector2(slot.get_center().x, slot.position.y + slot.size.y * 0.5), Vector2(slot.get_center().x, ky), Pal.METAL_L, 3.0)
	draw_circle(Vector2(slot.get_center().x, ky), 9, Pal.MULT if not _lever_hover else Pal.MULT.lightened(0.3))
	Pal.text(self, Vector2(lr.position.x, lr.end.y + 2), "SEND", 10, Pal.AMBER if _phase == "pick" else Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
