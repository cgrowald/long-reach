extends Control
## Toy B: PACKET PIT (Ball x Pit style hack). Aim at the network, pull SEND, watch the packets bounce.

const Pal := preload("res://v2/ui/pal.gd")
const PixelRoot := preload("res://v2/ui/pixel_root.gd")
const Crt := preload("res://v2/ui/crt_screen.gd")
const Rig := preload("res://v2/ui/rig.gd")
const Sfx := preload("res://v2/ui/sfx.gd")
const Fx := preload("res://v2/ui/fx.gd")
const IntelCard := preload("res://v2/ui/intel_card.gd")
const PitSim := preload("res://v2/sim/pit_sim.gd")

const SCREEN_R := Rect2(6, 6, 312, 288)
const BOARD_OFS := Vector2(12, 12)
const COLORS := {
	"fw": Color(0.42, 0.42, 0.46),
	"data": Color(0.25, 0.6, 1.0),
	"exp": Color(1.0, 0.5, 0.15),
	"honey": Color(0.85, 0.25, 0.85),
	"vault": Color(1.0, 0.85, 0.3),
}
const TIERS := [
	{"score": 600, "label": "Building", "text": "Kessel Arms Depot, warehouse 4, Kanal St."},
	{"score": 2000, "label": "Floor + move time", "text": "Upper floor. Moves Thu 02:00 by van."},
	{"score": 5000, "label": "Room + guards", "text": "Cage 4-B. Two guards, swap at 01:40."},
	{"score": 12000, "label": "Crate photo + buyer", "text": "Photo: crate KX-0417, 12 rifles. Buyer: Precinct 9."},
]
const CARTS := [
	{"id": "worm", "name": "WORM", "desc": "Packets split when they break a firewall."},
	{"id": "keylog", "name": "KEYLOG", "desc": "Data nodes give double chips."},
	{"id": "ghost", "name": "GHOST", "desc": "Your first 2 honeypot hits don't light a trace lamp."},
	{"id": "overclock", "name": "OVRCLK", "desc": "+3 packets every send."},
]

var g: Control
var screen
var board: Control
var rig
var sfx
var sim
var state := "aim"        # aim, volley, over
var aim := Vector2(0, -1)
var _mouse := Vector2(144, 120)
var _parts: Array = []    # {p, v, life, col}
var _msg := ""
var _msg_t := 0.0
var _seed := 0


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
	board.size = Vector2(PitSim.W, PitSim.H)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	screen.add_child(board)
	rig = Rig.new()
	rig.position = Vector2(324, 6)
	rig.sfx = sfx
	g.add_child(rig)
	rig.send_pulled.connect(_on_send)
	rig.pulled_out.connect(_on_pull_out)
	rig.loadout_changed.connect(func() -> void: sim.mods = _mods())
	_new_run()


func _new_run() -> void:
	for c in g.get_children():
		if c is IntelCard:
			c.queue_free()
	_seed = randi()
	sim = PitSim.new()
	rig.target_name = "KESSEL ARMS DEPOT // ledger"
	rig.rule_text = "RULE: Patch day. Firewalls +1 HP."
	rig.weak_text = "WEAK: careless clerk. Exploits 1 HP."
	rig.carts = CARTS
	rig.tiers = TIERS
	rig.trace_max = PitSim.TRACE_MAX
	rig.plugged = ["", ""]
	rig.loadout_locked = false
	rig.lever_enabled = true
	rig.switches_enabled = false
	rig.default_info = "Click the screen to aim, pull SEND. Hold Space = fast."
	rig.set_trace(0)
	rig.set_chips(0)
	rig.set_mult(1)
	rig.set_score(0)
	sim.setup(_seed, {})
	state = "aim"
	_say("Plug in two tools. Aim. Pull SEND.")


func _say(s: String, t := 3.0) -> void:
	_msg = s
	_msg_t = t


func _mods() -> Dictionary:
	var m := {}
	for id in rig.plugged:
		if id != "":
			m[id] = true
	return m


# --- input ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://v2/menu.tscn")
		elif event.keycode == KEY_SPACE and state == "aim":
			rig.pull_lever()


func _board_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if state == "aim" and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_set_aim(_mouse)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and state == "aim":
		_set_aim(event.position)
		sfx.play("tick_002", 1.4, -14.0)


func _set_aim(p: Vector2) -> void:
	var d := p - PitSim.LAUNCH
	if d.y > -4.0:
		d.y = -4.0
	aim = d.normalized()
	if aim.y > -0.15:
		aim = Vector2(signf(aim.x) * 0.99, -0.15).normalized()


func _on_send() -> void:
	if state != "aim":
		return
	if not rig.loadout_locked:
		rig.lock_loadout()
		sim.mods = _mods()
	sim.send(aim)
	rig.set_trace(sim.trace)
	rig.switches_enabled = false
	state = "volley"


func _on_pull_out() -> void:
	if state != "aim" or sim.volleys == 0:
		return
	_finish()


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if state == "volley":
		var fast := Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		for i in (3 if fast else 1):
			sim.update(delta)
		_handle_events()
		if not sim.busy():
			sim.end_volley()
			_handle_events()
			rig.set_trace(sim.trace)
			if sim.traced:
				_finish()
			else:
				state = "aim"
				rig.lever_enabled = true
				rig.switches_enabled = true
				if sim.trace == PitSim.TRACE_MAX - 1:
					_say("ONE LAMP LEFT. Next send traces you. Pull out?", 4.0)
				elif sim.best_combo > 0:
					_say("Volley done. Hits this send: %d" % sim.combo, 2.0)
	for p in _parts:
		p["p"] += p["v"] * delta
		p["v"] *= 0.9
		p["life"] -= delta
	_parts = _parts.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	_msg_t -= delta
	rig.set_chips(sim.chips)
	rig.set_mult(sim.mult)
	rig.set_score(sim.score())
	board.queue_redraw()


func _handle_events() -> void:
	for ev in sim.events:
		match ev["e"]:
			"launch":
				sfx.play("click_001", randf_range(1.3, 1.5), -16.0, 0.03)
			"wall":
				sfx.play("tick_004", 1.8, -26.0, 0.05)
			"hit":
				var c: int = ev["combo"]
				sfx.play("tick_001", 0.9 + minf(c, 40) * 0.035, -12.0, 0.025)
				_burst(ev["pos"], COLORS[ev["t"]], 3)
			"break":
				var t: String = ev["t"]
				_burst(ev["pos"], COLORS[t], 10)
				if t == "exp" or t == "vault":
					sfx.play("confirmation_002", 1.0 if t == "exp" else 0.7, -4.0)
					Fx.float_text(screen, ev["pos"] + BOARD_OFS, ev["text"], Pal.MULT, 12, 22.0, 1.0)
					screen.shake(3.0 if t == "exp" else 6.0)
				else:
					sfx.play("glass_001", randf_range(0.9, 1.2), -10.0, 0.04)
					if ev["text"] != "":
						Fx.float_text(screen, ev["pos"] + BOARD_OFS, ev["text"], Pal.CHIPS, 9, 12.0, 0.6)
					screen.shake(0.8)
			"trace":
				sfx.play("error_004", 0.7, -4.0)
				Fx.float_text(screen, ev["pos"] + BOARD_OFS, "HONEYPOT! TRACE +1", Color(1, 0.4, 1), 9, 18.0, 1.2)
				screen.shake(4.0)
			"patched":
				sfx.play("error_006", 0.8, -4.0)
				Fx.float_text(screen, Vector2(150, ev["y"]) + BOARD_OFS, "SYSADMIN PATCHED A ROW: TRACE +1", Pal.PHOS, 9, 14.0, 1.6)
				screen.shake(3.0)
			"cart":
				rig.flash_cart(ev["id"])
				if ev.has("pos") and ev["text"] != "":
					Fx.float_text(screen, ev["pos"] + BOARD_OFS, ev["text"], Pal.GREEN, 8, 10.0, 0.6)
	sim.events.clear()


func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		_parts.append({"p": at, "v": Vector2.from_angle(randf() * TAU) * randf_range(30, 110), "life": randf_range(0.2, 0.5), "col": col})


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
	card.setup("Arms shipment", TIERS, final, sim.trace + (3 if sim.traced else 0), sim.traced)
	card.position = Vector2(32, 300)
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", 48.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.again.connect(_new_run)
	card.menu.connect(func() -> void: get_tree().change_scene_to_file("res://v2/menu.tscn"))


# --- drawing ---------------------------------------------------------------

func _draw_desk() -> void:
	g.draw_rect(Rect2(Vector2.ZERO, g.size), Pal.DESK)
	# bezel
	var b := SCREEN_R.grow(4)
	Pal.plate(g, b, Color(0.12, 0.1, 0.11))
	Pal.screw(g, b.position + Vector2(3, 3))
	Pal.screw(g, b.end - Vector2(3, 3))


func _draw_board() -> void:
	var font := Pal.font()
	# header
	Pal.text(board, Vector2(0, 2), "> probe kessel-arms.ledger", 9, Pal.PHOS)
	if _msg_t > 0.0:
		Pal.text(board, Vector2(0, 12), _msg, 8, Pal.TEXT if fmod(_msg_t, 0.6) > 0.15 or _msg_t > 2.0 else Pal.DIM)
	# sysadmin line
	var py := PitSim.TOP + PitSim.PATCH_ROW * PitSim.ROW_H - 2.0
	var x := 0.0
	while x < PitSim.W:
		board.draw_line(Vector2(x, py), Vector2(x + 4, py), Color(Pal.PHOS, 0.6))
		x += 8.0
	Pal.text(board, Vector2(PitSim.W - 50, py + 2), "SYSADMIN", 7, Color(Pal.PHOS, 0.7))
	# nodes
	for n in sim.nodes:
		var r: Rect2 = sim.rect_of(n)
		var col: Color = COLORS[n["t"]]
		var f: float = n["flash"]
		var frac := float(n["hp"]) / float(n["max"])
		board.draw_rect(r, col.darkened(0.65))
		board.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col.darkened(0.25).lerp(Color.WHITE, f * 0.8))
		board.draw_rect(r, col, false, 1.0)
		var glyph := ""
		match n["t"]:
			"exp":
				glyph = "+M "
			"vault":
				glyph = "xM "
			"honey":
				glyph = "?? "
			"data":
				glyph = "D "
		Pal.text(board, r.position + Vector2(0, 1), glyph + str(n["hp"]), 9, Color.WHITE if n["t"] != "vault" else Pal.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# packets
	for b in sim.balls:
		var p: Vector2 = b["p"]
		var v: Vector2 = b["v"]
		board.draw_line(p - v.normalized() * 6.0, p, Color(0.6, 1.0, 0.9, 0.35), 2.0)
		board.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 1.0, 0.95))
	# particles
	for p in _parts:
		board.draw_rect(Rect2(p["p"], Vector2(2, 2)), Color(p["col"], clampf(p["life"] * 3.0, 0.0, 1.0)))
	# launcher + aim
	var l := PitSim.LAUNCH
	if state == "aim":
		for i in range(1, 14):
			var q := l + aim * (i * 7.0)
			board.draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 1.0, 0.95, 0.9 - i * 0.05))
	board.draw_rect(Rect2(l + Vector2(-9, 2), Vector2(18, 6)), Pal.METAL_L)
	board.draw_line(l, l + aim * 10.0, Pal.TEXT, 2.0)
	Pal.text(board, Vector2(0, PitSim.H - 10), "%d packets / send" % sim.packets_per_send(), 7, Pal.DIM)
	# legend
	var lx := 150.0
	for t in ["fw", "data", "exp", "honey", "vault"]:
		board.draw_rect(Rect2(lx, PitSim.H - 8, 5, 5), COLORS[t])
		lx += 7
		var nm: String = {"fw": "wall", "data": "data", "exp": "+mult", "honey": "trap", "vault": "xmult"}[t]
		Pal.text(board, Vector2(lx, PitSim.H - 10), nm, 7, Pal.DIM)
		lx += font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 5
