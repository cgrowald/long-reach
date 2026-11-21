extends Control
## Toy A: BREACH HAND (Balatro-style hack). Pick packets, pull SEND, watch the chips and mult tally.

const Pal := preload("res://v2/ui/pal.gd")
const PixelRoot := preload("res://v2/ui/pixel_root.gd")
const Crt := preload("res://v2/ui/crt_screen.gd")
const Rig := preload("res://v2/ui/rig.gd")
const Sfx := preload("res://v2/ui/sfx.gd")
const Fx := preload("res://v2/ui/fx.gd")
const IntelCard := preload("res://v2/ui/intel_card.gd")
const HandSim := preload("res://v2/sim/hand_sim.gd")

const SCREEN_R := Rect2(6, 6, 312, 288)
const BOARD_OFS := Vector2(12, 12)
const BOARD_SIZE := Vector2(288, 264)
const CARD := Vector2(36, 52)
const HAND_Y := 196.0
const PLAY_Y := 84.0
const SUIT_COL := {
	"SSH": Color(0.4, 0.9, 0.4),
	"MAIL": Color(1.0, 0.7, 0.2),
	"CAM": Color(0.3, 0.8, 1.0),
	"BADGE": Color(0.95, 0.35, 0.85),
}
const PORT := {"SSH": "22", "MAIL": "25", "CAM": "554", "BADGE": "13.56"}
const TIERS := [
	{"score": 200, "label": "A second phone", "text": "Deputy Minister Rusk carries a second phone."},
	{"score": 500, "label": "Who he texts", "text": "Texts 'Irena' every night after 23:00."},
	{"score": 1000, "label": "Where they meet", "text": "Hotel Linden, Thursdays, room 31."},
	{"score": 1700, "label": "Proof", "text": "Photos + bank transfers to her flat."},
]
const CARTS := [
	{"id": "sticky", "name": "STICKY", "desc": "The careless clerk's sticky notes: +4 mult if you play any MAIL packet."},
	{"id": "camloop", "name": "CAMLOOP", "desc": "+15 chips for every CAM packet that scores."},
	{"id": "brute", "name": "BRUTE", "desc": "x2 mult on BRUTE FORCE or better."},
	{"id": "quiet", "name": "QUIET", "desc": "Your first 2 reroutes light no trace lamp."},
]

var g: Control
var screen
var board: Control
var rig
var sfx
var sim
var state := "pick"   # pick, scoring, over
var _played: Array = []
var _leaving: Array = []
var _hover := -1
var _title := ""
var _title_pop := 0.0
var _msg := ""
var _msg_t := 0.0


func _ready() -> void:
	g = PixelRoot.make(self)
	sfx = Sfx.new()
	add_child(sfx)
	g.draw.connect(_draw_desk)
	screen = Crt.new()
	g.add_child(screen)
	screen.place(SCREEN_R)
	board = Control.new()
	board.position = BOARD_OFS
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	screen.add_child(board)
	rig = Rig.new()
	rig.position = Vector2(324, 6)
	rig.sfx = sfx
	g.add_child(rig)
	rig.send_pulled.connect(_on_send)
	rig.alt_pulled.connect(_on_reroute)
	rig.pulled_out.connect(_on_pull_out)
	rig.loadout_changed.connect(func() -> void: sim.mods = _mods())
	_new_run()


func _new_run() -> void:
	for c in g.get_children():
		if c is IntelCard:
			c.queue_free()
	sim = HandSim.new()
	sim.setup(randi(), {})
	rig.target_name = "MINISTRY OF SUPPLY // mail"
	rig.rule_text = "RULE: Mail filter. MAIL scores 0."
	rig.weak_text = "WEAK: clerk writes passwords down."
	rig.carts = CARTS
	rig.tiers = TIERS
	rig.trace_max = HandSim.TRACE_MAX
	rig.plugged = ["", ""]
	rig.loadout_locked = false
	rig.alt_label = "REROUTE"
	rig.lever_enabled = true
	rig.switches_enabled = true
	rig.default_info = "Pick packets, pull SEND. Play: 2 trace. Reroute: 1."
	rig.set_trace(0)
	rig.set_chips(0)
	rig.set_mult(0)
	rig.set_score(0)
	_played.clear()
	_leaving.clear()
	_title = ""
	for i in sim.hand.size():
		sim.hand[i]["pos"] = Vector2(BOARD_SIZE.x + 20 + i * 10, HAND_Y)
		sim.hand[i]["sel"] = false
		sim.hand[i]["pop"] = 0.0
	_layout()
	state = "pick"
	_say("Plug in two tools. Pick packets. Pull SEND.")
	sfx.play("open_001", 1.0, -8.0)


func _mods() -> Dictionary:
	var m := {}
	for id in rig.plugged:
		if id != "":
			m[id] = true
	return m


func _say(s: String, t := 3.0) -> void:
	_msg = s
	_msg_t = t


func _selected() -> Array:
	var out: Array = []
	for i in sim.hand.size():
		if sim.hand[i].get("sel", false):
			out.append(i)
	return out


func _layout() -> void:
	var n: int = sim.hand.size()
	var x0 := (BOARD_SIZE.x - n * 40.0 + 4.0) * 0.5
	for i in n:
		var c: Dictionary = sim.hand[i]
		var lift := 10.0 if c.get("sel", false) else (3.0 if i == _hover and state == "pick" else 0.0)
		c["target"] = Vector2(x0 + i * 40.0, HAND_Y - lift)
		if not c.has("pos"):
			c["pos"] = Vector2(BOARD_SIZE.x + 30, HAND_Y)
			c["sel"] = false
			c["pop"] = 0.0
	var m := _played.size()
	var px := (BOARD_SIZE.x - m * 40.0 + 4.0) * 0.5
	for i in m:
		_played[i]["target"] = Vector2(px + i * 40.0, PLAY_Y)


# --- input ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://v2/menu.tscn")
		elif event.keycode == KEY_SPACE and state == "pick":
			rig.pull_lever()


func _card_at(p: Vector2) -> int:
	for i in range(sim.hand.size() - 1, -1, -1):
		var c: Dictionary = sim.hand[i]
		if Rect2(c["pos"], CARD).has_point(p):
			return i
	return -1


func _board_input(event: InputEvent) -> void:
	if state != "pick":
		return
	if event is InputEventMouseMotion:
		var h := _card_at(event.position)
		if h != _hover:
			_hover = h
			if h >= 0:
				sfx.play("tick_002", 1.6, -20.0)
			_layout()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(event.position)
		if i < 0:
			return
		var c: Dictionary = sim.hand[i]
		if not c.get("sel", false) and _selected().size() >= 5:
			sfx.play("error_006", 1.0, -10.0)
			return
		c["sel"] = not c.get("sel", false)
		sfx.play("click_003", 1.2 if c["sel"] else 0.9, -8.0)
		_layout()
		_preview()


func _preview() -> void:
	var sel := _selected()
	if sel.is_empty():
		_title = ""
		rig.set_chips(0)
		rig.set_mult(0)
		return
	var cards: Array = sel.map(func(i: int) -> Dictionary: return sim.hand[i])
	var info: Array = HandSim.HANDS[HandSim.evaluate(cards)["key"]]
	_title = "%s   %d x %d" % [info[0], int(info[1]), int(info[2])]
	rig.set_chips(info[1])
	rig.set_mult(info[2])


func _on_send() -> void:
	if state != "pick":
		return
	var sel := _selected()
	if sel.is_empty():
		_say("Pick 1 to 5 packets first.")
		sfx.play("error_006", 1.0, -8.0)
		rig.lever_enabled = true
		return
	_play(sel)


func _on_reroute() -> void:
	if state != "pick":
		return
	var sel := _selected()
	if sel.is_empty():
		_say("Pick the packets to reroute (discard) first.")
		return
	if not rig.loadout_locked:
		rig.lock_loadout()
		sim.mods = _mods()
	var res: Dictionary = sim.reroute(sel)
	if res["cost"] == 0:
		rig.flash_cart("quiet")
		_say("QUIET: reroute was free.")
	for c in res["gone"]:
		c["target"] = Vector2(c["pos"].x, BOARD_SIZE.y + 40)
		_leaving.append(c)
	sfx.play("drop_002", 1.3, -6.0)
	rig.set_trace(sim.trace)
	_hover = -1
	_layout()
	_preview()
	if sim.traced:
		_finish()


func _on_pull_out() -> void:
	if state != "pick" or sim.plays == 0:
		return
	_finish()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _play(sel: Array) -> void:
	state = "scoring"
	rig.switches_enabled = false
	if not rig.loadout_locked:
		rig.lock_loadout()
		sim.mods = _mods()
	_hover = -1
	var res: Dictionary = sim.play(sel)
	rig.set_trace(sim.trace)
	_played = res["cards"]
	for c in _played:
		c["sel"] = false
	_layout()
	_title = str(res["name"])
	_title_pop = 1.0
	var chips: float = res["base_chips"]
	var mult: float = res["base_mult"]
	rig.set_chips(chips)
	rig.set_mult(mult)
	sfx.play("maximize_006", 1.0, -6.0)
	await _wait(0.45)
	var n := 0
	for st in res["steps"]:
		if st["k"] == "card":
			n += 1
			var c: Dictionary = _played[st["i"]]
			c["pop"] = 1.0
			var at: Vector2 = c["pos"] + Vector2(CARD.x * 0.5, CARD.y + 16) + BOARD_OFS
			if st["blocked"]:
				Fx.float_text(screen, at, "BLOCKED 0", Pal.DIM, 9)
				sfx.play("error_006", 0.8, -10.0)
			else:
				chips += float(st["chips"])
				rig.set_chips(chips)
				Fx.float_text(screen, at, "+%d" % int(st["chips"]), Pal.CHIPS, 12)
				sfx.play("tick_001", 0.9 + n * 0.12, -4.0)
			screen.shake(0.8)
		else:
			rig.flash_cart(st["id"])
			var at2: Vector2 = rig.cart_center(st["id"]) + Vector2(0, -16)
			if st.has("chips"):
				chips += float(st["chips"])
				rig.set_chips(chips)
				Fx.float_text(g, at2, st["text"], Pal.CHIPS, 10)
			elif st.has("mult"):
				mult += float(st["mult"])
				rig.set_mult(mult)
				Fx.float_text(g, at2, st["text"], Pal.MULT, 11)
			else:
				mult *= float(st["xmult"])
				rig.set_mult(mult)
				Fx.float_text(g, at2, st["text"], Pal.MULT, 13, 20.0, 1.0)
			sfx.play("click_005", 1.0 + n * 0.12, -2.0)
			n += 1
			screen.shake(1.5)
		await _wait(0.32)
	var total: int = res["total"]
	rig.set_score(sim.score)
	_title = "%s   %d x %s = %d" % [res["name"], int(chips), Pal.fmt_mult(mult), total]
	_title_pop = 1.0
	sfx.play("bong_001", 1.0, -2.0)
	screen.shake(clampf(1.0 + total / 120.0, 1.0, 7.0))
	Fx.float_text(screen, Vector2(BOARD_SIZE.x * 0.5, PLAY_Y - 18) + BOARD_OFS, "+%d" % total, Pal.TEXT, 16 if total < 300 else 20, 26.0, 1.2)
	await _wait(0.8)
	for c in _played:
		c["target"] = Vector2(c["pos"].x, -80)
		_leaving.append(c)
	_played.clear()
	for c in res["drawn"]:
		c["pos"] = Vector2(BOARD_SIZE.x + 30, HAND_Y)
		c["sel"] = false
		c["pop"] = 0.0
	_layout()
	_preview()
	if not res["drawn"].is_empty():
		sfx.play("drop_002", 1.5, -10.0)
	await _wait(0.25)
	if sim.traced or sim.hand.is_empty():
		_finish()
		return
	state = "pick"
	rig.lever_enabled = true
	rig.switches_enabled = true
	if sim.trace + HandSim.PLAY_COST >= HandSim.TRACE_MAX:
		_say("Next play fills the trace. Pull out, or risk it?", 5.0)


func _finish() -> void:
	state = "over"
	rig.lever_enabled = false
	rig.switches_enabled = false
	var final: int = sim.final_score()
	rig.set_score(final)
	sfx.play("bong_001", 0.6 if sim.traced else 1.0, -2.0)
	if sim.traced:
		screen.shake(7.0)
	var card := IntelCard.new()
	g.add_child(card)
	card.setup("Deputy Minister Rusk", TIERS, final, sim.trace + (3 if sim.traced else 0), sim.traced)
	card.position = Vector2(32, 300)
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", 48.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.again.connect(_new_run)
	card.menu.connect(func() -> void: get_tree().change_scene_to_file("res://v2/menu.tscn"))


# --- loop + drawing ---------------------------------------------------------------

func _process(delta: float) -> void:
	var k := 1.0 - exp(-16.0 * delta)
	for c in sim.hand + _played + _leaving:
		c["pos"] = (c["pos"] as Vector2).lerp(c["target"], k)
		c["pop"] = maxf(0.0, float(c.get("pop", 0.0)) - delta * 3.0)
	_leaving = _leaving.filter(func(c: Dictionary) -> bool: return (c["pos"] as Vector2).distance_to(c["target"]) > 2.0)
	_title_pop = maxf(0.0, _title_pop - delta * 4.0)
	_msg_t -= delta
	board.queue_redraw()


func _draw_desk() -> void:
	g.draw_rect(Rect2(Vector2.ZERO, g.size), Pal.DESK)
	var b := SCREEN_R.grow(4)
	Pal.plate(g, b, Color(0.12, 0.1, 0.11))
	Pal.screw(g, b.position + Vector2(3, 3))
	Pal.screw(g, b.end - Vector2(3, 3))


func _draw_board() -> void:
	Pal.text(board, Vector2(0, 2), "> breach ministry-supply.mail", 9, Pal.PHOS)
	if _msg_t > 0.0:
		Pal.text(board, Vector2(0, 12), _msg, 8, Pal.TEXT)
	# play zone
	var pz := Rect2(4, PLAY_Y - 26, BOARD_SIZE.x - 8, CARD.y + 34)
	board.draw_rect(pz, Color(Pal.PHOS, 0.05))
	board.draw_rect(pz, Color(Pal.PHOS, 0.25), false, 1.0)
	if _title != "":
		var s := 10 + int(_title_pop * 4.0)
		Pal.text(board, Vector2(pz.position.x, pz.position.y + 4 - _title_pop * 2.0), _title, s, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, pz.size.x)
	else:
		Pal.text(board, Vector2(pz.position.x, pz.position.y + 30), "pick packets below", 9, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, pz.size.x)
	# deck + legend
	Pal.text(board, Vector2(0, HAND_Y - 26), "DECK %d   PLAYS %d" % [sim.deck.size(), sim.plays], 8, Pal.DIM)
	var lx := 120.0
	for s in HandSim.SUITS:
		board.draw_rect(Rect2(lx, HAND_Y - 24, 5, 5), SUIT_COL[s])
		Pal.text(board, Vector2(lx + 7, HAND_Y - 26), s, 8, Pal.DIM)
		lx += 7 + s.length() * 5 + 8
	for c in _leaving:
		_draw_card(c)
	for c in sim.hand:
		_draw_card(c)
	for c in _played:
		_draw_card(c)
	Pal.text(board, Vector2(0, BOARD_SIZE.y - 9), "Space = SEND   Esc = menu", 7, Pal.DIM)


func _draw_card(c: Dictionary) -> void:
	var pos: Vector2 = c["pos"]
	var pop: float = c.get("pop", 0.0)
	var s := 1.0 + pop * 0.25
	var col: Color = SUIT_COL[c["s"]]
	board.draw_set_transform(pos + CARD * 0.5, sin(pop * 6.0) * pop * 0.12, Vector2(s, s))
	var r := Rect2(-CARD * 0.5, CARD)
	board.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.5))
	board.draw_rect(r, Color(0.11, 0.09, 0.1).lerp(Color.WHITE, pop * 0.3))
	board.draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), col)
	Pal.text(board, r.position + Vector2(0, 1), c["s"], 8, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	Pal.text(board, r.position + Vector2(0, 15), str(c["r"]), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	Pal.text(board, r.position + Vector2(0, 40), ":" + PORT[c["s"]], 7, col.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var border := Pal.AMBER if c.get("sel", false) else col.darkened(0.3)
	board.draw_rect(r, border, false, 1.0 if not c.get("sel", false) else 2.0)
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
