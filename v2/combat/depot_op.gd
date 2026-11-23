extends RefCounted
## The depot raid on top of the fight (roadmap M1; rules in v2/sim/depot_run.gd; docs/DEPOT_SLICE.md).
## The fight calls: prepare() before spawning, start() after, tick(), draw(), input(), and results() going home.
##   - a fresh depot every raid: kind, guards (person generator), stores, three vault doors
##   - going loud: the first shot starts the neighbours' clock (they always call it in eventually), and one guard
##     runs for the alarm box; drop him before he gets there and there's no alarm. Either clock running out =
##     BACKUP: Bureau reinforcements come in the front. You can fight out with meds, guns and good people.
##   - the vault: three steel doors in the secure store, cabled to a control PC (v2/combat/vault_room.gd).
##     The stick carrier (picked in the cage) reaches the PC: "Boss, PC here, hit it?" Plug in = the guided
##     command hack (v2/sim/vault_hack.gd), every command costs real seconds; or leave it.
##   - logged in, the system grants ONE door: click it on the camera feed and it swings open. DCC-style loot
##     (mostly junk, sometimes amazing). Then everyone gets out.
##   - the stores you came for go home as far as the squad can carry; a prisoner from the holding cell, or a
##     cuffed guard, comes home for the interrogation.

const Pal := preload("res://v2/ui/pal.gd")
const DepotRun := preload("res://v2/sim/depot_run.gd")
const VaultHack := preload("res://v2/sim/vault_hack.gd")
const VaultRoom := preload("res://v2/combat/vault_room.gd")
const PopupWin := preload("res://v2/ui/popup_win.gd")
const People := preload("res://v2/sim/people_gen.gd")
const Loadout := preload("res://v2/sim/loadout.gd")
const Krall := preload("res://v2/sim/krall.gd")
const Actor := preload("res://v2/combat/actor.gd")

const NEIGHBOURS_S := 150.0       # from the first shot, someone always calls it in
const ALARM_S := 75.0             # a pressed alarm brings them sooner
const ALARM_BOX := Vector3(4.6, 0, -13.6)
const RUN_SPEED := 1.9
const PC_POS := Vector3(-1.9, 0, -23.3)
const OPEN_S := 1.7

var f: Control                    # the fight
var state: RefCounted
var run: Dictionary = {}
var phase := "quiet"              # quiet, prompt, cmd, doors, opening, opened, out
var loud := false
var t_loud := 0.0
var backup := -1.0                # seconds to backup (-1 = not coming yet)
var alarm := false
var runner = null                 # the guard running for the alarm box
var reinforced := false
var hits := {}                    # fighter id -> hits taken
var downed := {}
var vhack: RefCounted = null      # the guided command hack (v2/sim/vault_hack.gd)
var vault: Node3D                 # the 3D vault room
var typed := ""                   # the terminal's input line
var hack_t := 0.0                 # seconds spent at the PC
var open_t := 0.0
var _door_rects: Array = []       # [Rect2, i] in the vault camera window
var _sugg_rects: Array = []       # [Rect2, text] the terminal's suggested commands
var term_focus := false           # keys go to the terminal (click it), or to the fight (Esc / click away)
var _win_prompt: Control
var _win_term: Control
var _win_door: Control
var door_vp: SubViewport
var door_cam: Camera3D
var door_post: ShaderMaterial
var opened := -1
var door_result: Dictionary = {}
var prisoner: Dictionary = {}
var lines: Array = []             # for the report
var _t := 0.0
var _flash := 0.0


func prepare(p_fight: Control, data: Dictionary) -> Dictionary:
	f = p_fight
	state = f.game.state
	run = DepotRun.create(state, hash(str(state.world_seed) + "depot" + str(state.day) + str(int(state.flags.get("depot", {}).get("raids", 0)))))
	var hinted := DepotRun.apply_hints(state, run)
	var d := data.duplicate(true)
	d["name"] = "Dobrev Freight - %s" % run["kind_name"]
	d["enemies"] = run["guards"]
	d["objective"] = {"text": "Reach the vault PC (secure store)", "room": "office", "pos": [PC_POS.x, PC_POS.z],
		"grab_line": "Boss, I see the PC that runs the vault doors. Want me to hit it?", "grab_log": "At the vault control PC", "hold_after": true}
	d["bare_rooms"] = ["office"]           # the vault fills it
	for r in d.get("rooms", []):
		if r["id"] == "office":
			r["name"] = "SECURE STORE"
	lines.append("%s. %d guards. %s" % [run["kind_name"], run["guards"].size(), ("Your intel marked %d of the vault doors." % hinted) if hinted > 0 else "No intel on the vault."])
	return d


func start() -> void:
	for a in f.squad:
		a.hit_taken.connect(func(who, _info) -> void: hits[who.id] = int(hits.get(who.id, 0)) + 1)
		a.went_down.connect(func(who) -> void: downed[who.id] = true)
	for a in f.squad + f.enemies:
		a.fired.connect(_on_fired)
	f.sq.objective_done.connect(_on_objective)
	f.sq.log_line.connect(_on_log)
	vault = VaultRoom.new()
	f.level.add_child(vault)
	var rc: Rect2 = f.level.room("office")["rect"]
	vault.build(f.level, rc.position.y, PC_POS, run["doors"])


func _on_fired(_who, _target) -> void:
	if loud:
		return
	loud = true
	backup = NEIGHBOURS_S
	f._event("SHOTS FIRED. The neighbours will call it in.")
	# one guard runs for the alarm box
	var best = null
	var bd := 1e9
	for e in f.enemies:
		if e.state == "ok":
			var dd: float = e.global_position.distance_to(ALARM_BOX)
			if dd < bd:
				bd = dd
				best = e
	if best:
		runner = best
		runner.go(f.sq._route(runner, ALARM_BOX), RUN_SPEED)
		runner.bark_custom("The alarm! Hit the alarm!")
		f._event("A guard is running for the alarm. Stop him.")


func _on_log(t: String) -> void:
	if "STORE ROOM" in t and t.ends_with("cleared") and prisoner.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(run["seed"]) + 7
		if rng.randf() < 0.65:
			prisoner = People.make(int(run["seed"]) + 77, "prisoner")
			f._event("Holding cell: %s. In for: %s." % [prisoner["name"], prisoner["offense"]])
			var pt = f.sq.by_role("point")
			if pt:
				pt.say("There's someone in the cell back here. We're taking them.", true)


func _on_objective() -> void:
	phase = "prompt"
	f._event("At the vault PC. Your call.")
	_open_prompt_win()


# ------------------------------------------------------------------ the loop

func tick(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 1.5)
	if loud:
		t_loud += delta
	if runner != null and not alarm:
		if runner.state != "ok":
			runner = null
			f._event("The alarm runner is down. No alarm.")
		elif runner.global_position.distance_to(ALARM_BOX) < 0.9:
			alarm = true
			runner.bark_custom("Alarm's on! They're coming!")
			backup = minf(backup if backup > 0.0 else ALARM_S, ALARM_S)
			f._event("ALARM. Backup in %d seconds." % int(backup))
			runner = null
	if backup > 0.0:
		backup -= delta
		if backup <= 0.0 and not reinforced:
			_reinforce()
	match phase:
		"cmd":
			_tick_hack(delta)
		"opening":
			open_t += delta
			if open_t >= OPEN_S:
				phase = "opened"
				_flash = 1.0
				f._event("DOOR %02d: %s" % [opened + 1, str(door_result["label"]).to_upper()])


## The hack runs while the stick carrier is at the PC. While they type (and the command runs) they're out of
## the fight: covering them is your job. If they go down, the next one with the tech takes the stick over.
func _tick_hack(delta: float) -> void:
	var c = f.sq.stick_carrier()
	if c == null:
		phase = "out"
		lines.append("Nobody left who could work the vault PC.")
		f._event("Nobody can work the PC. Get out.")
		_exfil()
		return
	vhack.who = str(c.fighter_name).split(" ")[0].capitalize()
	if c.global_position.distance_to(PC_POS) > 1.6:
		if not c.moving():
			c.go(f.sq._route(c, PC_POS + Vector3(0.6, 0, 0.3)), RUN_SPEED)
		return
	hack_t += delta
	if vhack.busy():
		c.busy = maxf(c.busy, 0.2)          # hands on the keyboard, not the gun
		c.crouch = 0.35
		c.look_at_point = PC_POS + Vector3(0, 1.0, 0)
	var was_typing: bool = vhack.busy() and not vhack.typing_done()
	if vhack.tick(delta) and f.game:
		f.game.sfx.play("switch_002", 1.4, -12.0)
	elif was_typing and f.game and fmod(hack_t, 0.16) < delta:
		f.game.sfx.play("switch_002", 2.2 + randf() * 0.4, -26.0)       # keys
	if vhack.logged_in:
		phase = "doors"
		_flash = 1.0
		vault.grant()
		lines.append("%s hacked the vault PC in %d seconds." % [vhack.who, int(hack_t)])
		f._event("ACCESS. The vault camera is up: pick a door.")
		_close_win(_win_term)
		_open_door_win()
	elif vhack.locked_out:
		phase = "out"
		lines.append("Three wrong PINs. The vault locked out.")
		f._event("LOCKOUT. Get out.")
		_close_win(_win_term)
		_exfil()


func _reinforce() -> void:
	reinforced = true
	f._event("BACKUP IS HERE. Bureau response at the front door.")
	var sp: Array = f.data["start"]["pos"]
	for i in 3:
		var p := People.make(int(run["seed"]) + 900 + i, "guard")
		var def := {"id": "b%d" % i, "name": "Bureau %s" % p["last"], "kind": "bureau", "camo": "black", "head": "helmet",
			"gear": {"weapon": "carbine", "round": "fmj", "attach": ["light"], "plate": 1, "mags": 99, "meds": 1}, "state": "combat"}
		var a: Node3D = Actor.new()
		f.world.add_child(a)
		a.setup_actor(def, "them", f.level)
		a.set_meta("def", def)
		a.position = Vector3(float(sp[0]) + i * 0.7 - 0.7, 0, float(sp[1]) + 2.0)
		a.face_yaw = PI
		a.rotation.y = PI
		f._wire(a)
		a.fired.connect(_on_fired)
		var target_pos: Vector3 = f.squad[0].global_position if not f.squad.is_empty() else Vector3.ZERO
		a.set_meta("ai", {"mode": "combat", "morale": 1.0, "react": 0.0, "patrol": [], "pi": 0, "last_seen": target_pos, "lost": 5.0, "home": a.global_position})
		f.enemies.append(a)


func _exfil() -> void:
	f.sq._next_doctrine()


# ------------------------------------------------------------------ the small windows

func _win(title: String, sz: Vector2, at: Vector2, body: Callable) -> Control:
	var w: Control = PopupWin.new()
	w.title = title
	w.size = sz
	w.position = at
	w.draw_body = body
	w.pressed.connect(_press)
	f.view.ui.add_child(w)
	return w


func _close_win(w: Control) -> void:
	if w != null and is_instance_valid(w):
		w.queue_free()


func _over_win(mp: Vector2) -> bool:
	for w in [_win_prompt, _win_term, _win_door]:
		if w != null and is_instance_valid(w) and Rect2(w.position, w.size).has_point(mp):
			return true
	return false


func _open_prompt_win() -> void:
	var img: Rect2 = f._main_img()
	_win_prompt = _win("VAULT PC", Vector2(236, 96), img.position + Vector2(10, 30), _draw_prompt)


func _open_term_win() -> void:
	var img: Rect2 = f._main_img()
	_win_term = _win("terminal", Vector2(228, 128), Vector2(img.position.x + 10, img.end.y - 138), _draw_term)
	_win_term.accent = Color(0.45, 0.8, 0.55)
	_win_term.click_body = func(p: Vector2) -> void:
		term_focus = true
		for s in _sugg_rects:
			if (s[0] as Rect2).has_point(p):
				typed = str(s[1])
				if not typed.ends_with(" "):
					_run_typed()
	term_focus = true


## The vault system's own camera, in its own little window, square on the three doors.
func _open_door_win() -> void:
	var rc: Rect2 = f.level.room("office")["rect"]
	door_vp = SubViewport.new()
	door_vp.size = Vector2i(256, 144)
	door_vp.world_3d = f.view.vp.find_world_3d()
	door_vp.audio_listener_enable_3d = false
	door_vp.msaa_3d = Viewport.MSAA_DISABLED
	f.add_child(door_vp)
	door_cam = Camera3D.new()
	door_cam.near = 0.05
	door_cam.fov = 70.0
	door_vp.add_child(door_cam)
	door_cam.current = true
	door_cam.position = Vector3(rc.end.x - 0.25, 2.55, rc.end.y - 0.25)
	door_cam.look_at(Vector3(-0.2, 0.9, vault.wall_z + 0.6), Vector3.UP)
	door_post = f._post_for(door_cam, 3)
	var img: Rect2 = f._main_img()
	_win_door = _win("VAULT-CAM  /  SECURE STORE", Vector2(224, 176), Vector2(img.end.x - 234, img.position.y + 30), _draw_door)
	_win_door.click_body = func(p: Vector2) -> void:
		if phase != "doors":
			return
		for dr in _door_rects:
			if (dr[0] as Rect2).has_point(p):
				_open_door(int(dr[1]))
				return


func _draw_prompt(w: Control, b: Rect2) -> void:
	var c = f.sq.stick_carrier()
	var who := "Nobody brought a stick." if c == null else "%s has the stick (tech %d)." % [str(c.fighter_name).split(" ")[0].capitalize(), int(c.tech)]
	w.draw_multiline_string(Pal.font(), b.position + Vector2(4, 10), "\"Boss, PC here. It runs the vault doors. Hit it?\"\nOne door, then it locks out. %s" % who, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 8, 8, -1, Pal.TEXT)
	if c != null:
		w.button(Rect2(b.position.x + 4, b.end.y - 20, 120, 16), "PLUG IN THE STICK", "plug")
	w.button(Rect2(b.end.x - 74, b.end.y - 20, 70, 16), "LEAVE IT", "leave", false)


const TERM_FG := Color(0.62, 0.95, 0.68)
const TERM_DIM := Color(0.45, 0.62, 0.5)


## A plain shell: what's been run, what they're typing now, then your line (what you tell them) and the
## suggested commands to click.
func _draw_term(w: Control, b: Rect2) -> void:
	w.title = "%s@vaultctl  -  terminal" % vhack.who.to_lower()
	w.draw_rect(b, Color(0.01, 0.02, 0.015))
	var lh := 10.0
	var foot := 34.0
	var rows := int((b.size.y - foot - 4) / lh) - 1
	var from := maxi(0, vhack.lines.size() - rows)
	var y := b.position.y + 2
	for k in range(from, vhack.lines.size()):
		var ln: Array = vhack.lines[k]
		var col: Color = {"cmd": Color(0.85, 0.85, 0.8), "ok": TERM_FG, "bad": Color(1.0, 0.45, 0.35), "hint": Color(0.95, 0.75, 0.35)}.get(str(ln[1]), TERM_DIM)
		Pal.text(w, Vector2(b.position.x + 3, y), str(ln[0]), 7, col, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 6)
		y += lh
	# the shell line: their typing, or the command running
	var cur := "_" if fmod(_t, 0.8) < 0.45 else " "
	var shell: String = vhack.prompt()
	if vhack.busy():
		if not vhack.typing_done():
			shell += vhack.typing_text() + cur
		else:
			shell += vhack.typing_text()
			var dots := ".".repeat(1 + int(_t * 3.0) % 3)
			if vhack.running["cmd"] == "brute":
				shell = "trying %04d %s" % [randi() % 10000, dots]
			elif vhack.running["cmd"] == "sniff":
				shell = "listening on the wire " + dots
			else:
				shell += "  " + dots
	elif vhack.logged_in or vhack.locked_out:
		shell = ""
	else:
		shell += cur
	Pal.text(w, Vector2(b.position.x + 3, y), shell, 7, TERM_FG, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 6)
	# your line
	var fy := b.end.y - foot
	w.draw_line(Vector2(b.position.x, fy), Vector2(b.end.x, fy), Color(TERM_DIM, 0.5), 1.0)
	var mine := "tell %s: %s%s" % [vhack.who.to_upper(), typed, cur if term_focus and not vhack.busy() else ""]
	if vhack.busy():
		mine = "%s is typing. Cover them." % vhack.who
	Pal.text(w, Vector2(b.position.x + 3, fy + 3), mine, 8, Color(0.95, 0.75, 0.35) if term_focus else TERM_DIM, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 6)
	# suggestions to click
	_sugg_rects = []
	var sx := b.position.x + 3
	var sy := fy + 16
	Pal.text(w, Vector2(sx, sy + 1), "PIN %s" % vhack.pin_shown(), 7, TERM_DIM)
	sx += 50
	if not vhack.busy():
		for s in vhack.suggestions():
			var lab := str(s).strip_edges()
			if lab == "login":
				lab = "login ____"
			var sw := lab.length() * 4.6 + 8
			var r := Rect2(sx, sy, sw, 12)
			var hov := r.has_point(w.get_local_mouse_position())
			w.draw_rect(r, Color(TERM_FG, 0.25 if hov else 0.1))
			Pal.text(w, r.position + Vector2(4, 1), lab, 7, TERM_FG)
			_sugg_rects.append([r, s])
			sx += sw + 4


## The vault camera: the doors marked (hover, click one), then what was behind it.
func _draw_door(w: Control, b: Rect2) -> void:
	if door_cam == null:
		return
	f._apply_feed_look(door_post, {"kind": "cctv", "dead_t": 0.0})
	var fr := Rect2(b.position, Vector2(b.size.x, b.size.x * 9.0 / 16.0))
	w.draw_texture_rect(door_vp.get_texture(), fr, false)
	_door_rects = []
	var mp := w.get_local_mouse_position()
	for i in 3:
		var p: Vector3 = vault.door_point(i)
		var a := door_cam.unproject_position(p + Vector3(0, 1.0, 0)) * fr.size / Vector2(door_vp.size) + fr.position
		var bb := door_cam.unproject_position(p - Vector3(0, 1.05, 0)) * fr.size / Vector2(door_vp.size) + fr.position
		var hgt := absf(bb.y - a.y)
		var dr := Rect2(Vector2(a.x - hgt * 0.27, a.y), Vector2(hgt * 0.54, hgt))
		var on := phase == "doors" and dr.has_point(mp)
		var c := Color(1.0, 0.8, 0.35) if on or i == opened else Color(1.0, 0.8, 0.35, 0.5)
		if phase == "doors" or i == opened:
			w.draw_rect(dr, c, false, 2.0 if on else 1.0)
		Pal.text(w, Vector2(dr.position.x - 10, dr.end.y + 1), "%02d %s" % [i + 1, DepotRun.door_hint(run, i).to_lower()], 7, c, HORIZONTAL_ALIGNMENT_CENTER, dr.size.x + 20)
		_door_rects.append([dr, i])
	var ty := fr.end.y + 3
	match phase:
		"doors":
			Pal.text(w, Vector2(b.position.x + 3, ty), "ONE door, then lockout. Click a door.", 8, Color(0.95, 0.75, 0.35))
		"opening":
			Pal.text(w, Vector2(b.position.x + 3, ty), "Door %02d is opening..." % (opened + 1), 8, Pal.TEXT)
		"opened", "out":
			if opened >= 0:
				var tc := {"junk": Pal.DIM, "decent": Pal.TEXT, "good": Color(0.6, 0.9, 0.5), "jackpot": Color(1.0, 0.8, 0.3)}.get(door_result.get("tier", ""), Pal.TEXT) as Color
				Pal.text(w, Vector2(b.position.x + 3, ty), "%02d: %s%s" % [opened + 1, str(door_result.get("label", "")).to_upper(), "!!" if door_result.get("tier", "") == "jackpot" else ""], 9, tc)
				Pal.text(w, Vector2(b.position.x + 3, ty + 12), DepotRun.describe(door_result), 7, Pal.TEXT, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 6)
			if phase == "opened":
				w.button(Rect2(b.end.x - 110, b.end.y - 16, 106, 14), "GRAB IT, GET OUT", "go")
			else:
				w.button(Rect2(b.end.x - 50, b.end.y - 16, 46, 14), "CLOSE", "close_door", false)


# ------------------------------------------------------------------ input

func input(e: InputEvent, mp: Vector2) -> bool:
	# typing into the vault terminal while it has focus (Esc gives focus back to the fight)
	if phase == "cmd" and term_focus and e is InputEventKey and e.pressed:
		var k: int = e.keycode
		if k == KEY_ESCAPE:
			term_focus = false
			return true
		if k == KEY_TAB:
			return false
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_run_typed()
		elif k == KEY_BACKSPACE:
			typed = typed.substr(0, maxi(0, typed.length() - 1))
		elif e.unicode >= 32 and e.unicode < 127 and typed.length() < 28:
			typed += char(e.unicode)
		return true
	if e is InputEventMouseButton or e is InputEventMouseMotion:
		if _over_win(mp):
			return true               # the window handles it
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return false
	if phase == "cmd":
		term_focus = false            # clicked the fight: keys are the fight's again
	# EYES ping: on a camera feed, click an enemy to alert the squad (the shout wheel's FOCUS makes them target)
	if not f.wheel_open and f.pending < 0:
		var mf: Dictionary = f.feeds[f.main_i] if f.main_i < f.feeds.size() else {}
		if mf.get("kind", "") == "cctv":
			var hit: Dictionary = f._pick_target("enemy")
			if hit.has("actor"):
				var en = hit["actor"]
				en.set_meta("seen_t", f.sq._t)
				en.set_meta("seen_pos", en.global_position)
				en.set_meta("pinged", true)
				var pt = f.sq.by_role("point")
				if pt:
					pt.say("Copy. Contact, %s." % f.sq._room_name(f.level.room_at(en.global_position)), true)
				f._event("PING: %s" % en.fighter_name)
				return true
	return false


func _run_typed() -> void:
	if typed.strip_edges() == "":
		return
	var why: String = vhack.submit(typed)
	if why != "":
		f._event(why)
	else:
		typed = ""


func _open_door(i: int) -> void:
	opened = i
	door_result = run["doors"][i]
	phase = "opening"
	open_t = 0.0
	vault.open(i)
	if f.game:
		f.game.sfx.play("drop_002", 0.5, -4.0)
	f._event("Door %02d. It's opening." % (i + 1))


func _press(id: String) -> void:
	match id:
		"plug":
			var c = f.sq.stick_carrier()
			vhack = VaultHack.new()
			vhack.on_manifest = func() -> void:
				for i in 3:
					run["hints"][i] = true
			vhack.start(int(run["seed"]) + 5, int(c.tech), int(c.stick), str(c.fighter_name).split(" ")[0].capitalize())
			phase = "cmd"
			hack_t = 0.0
			typed = ""
			_close_win(_win_prompt)
			_open_term_win()
			f._event("Stick's in. Tell %s what to type. Cover them while they do." % vhack.who)
		"leave":
			phase = "out"
			lines.append("You left the vault alone.")
			_close_win(_win_prompt)
			_exfil()
		"go":
			phase = "out"
			_exfil()
		"close_door":
			_close_win(_win_door)


# ------------------------------------------------------------------ drawing (on the fight's HUD)

func draw(ci: CanvasItem) -> void:
	var sz: Vector2 = f.view.ui.size
	if f.phase == "report":
		for w in [_win_prompt, _win_term, _win_door]:
			_close_win(w)
		_draw_haul(ci, sz)
		return
	# the clocks, top right of the feed
	var txt := ""
	var col := Pal.TEXT
	if runner != null and not alarm:
		txt = "ALARM RUNNER!  stop him"
		col = Color(1.0, 0.5, 0.3)
	elif backup > 0.0:
		txt = "BACKUP  %02d:%02d%s" % [int(backup) / 60, int(backup) % 60, "   (ALARM)" if alarm else "   (neighbours)"]
		col = Color(1.0, 0.7 - minf(0.5, 30.0 / maxf(backup, 1.0) * 0.2), 0.3)
	elif reinforced:
		txt = "BACKUP IS HERE: FIGHT OUT"
		col = Color(1.0, 0.35, 0.25)
	if txt != "":
		var mr: Rect2 = f._main_rect()
		var tr := Rect2(mr.end.x - 196, mr.position.y + 36, 186, 14)
		ci.draw_rect(tr, Color(0, 0, 0, 0.75))
		ci.draw_rect(tr, col, false, 1.0)
		ci.draw_string(Pal.bold(), Vector2(tr.position.x, tr.position.y + 11), txt, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 8, col)
	if _flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.8, 0.3, _flash * 0.12))


# ------------------------------------------------------------------ going home

## The squad's free rig cells (what they can carry out).
func _carry_cells() -> int:
	var n := 0
	for a in f.squad:
		if a.state != "ok" and a.state != "down":
			continue
		var p := Loadout.person(state, a.id)
		if p.is_empty():
			n += 4
			continue
		var gs := Loadout.grid_size(state, p)
		var used := 0
		for e in p["grid"]:
			var c := Loadout.cells(e["gear"])
			used += c.x * c.y
		n += maxi(0, gs.x * gs.y - used) + 2            # plus what fits in hands and pockets
	return n


## Called by the fight on the way home. Returns lines for the op notes.
func results(outcome: String) -> Array:
	var out: Array = lines.duplicate()
	if outcome == "success":
		if opened >= 0:
			out.append("From the vault: " + DepotRun.grant(state, door_result))
		var carried := DepotRun.carry_stores(state, run, _carry_cells())
		if not carried.is_empty():
			out.append("Carried out of the %s: %s." % [str(run["stores_title"]).to_lower(), ", ".join(PackedStringArray(carried))])
		# a prisoner: the holding cell, or a guard you cuffed
		var p := prisoner
		if p.is_empty():
			for e in f.enemies:
				if e.state == "cuffed":
					var d: Dictionary = e.get_meta("def")
					p = d.get("person", {})
					if not p.is_empty():
						p = p.duplicate(true)
						p["kind"] = "prisoner"
						p["offense"] = "Guarded the depot"
						break
		if not p.is_empty():
			state.flags["prisoner"] = p
			out.append("You brought %s back to the garage. They're tied to a chair under the bulb." % p["name"])
		Krall.bump(state, 2.0, "the depot raid")
	else:
		Krall.bump(state, 3.0, "a failed depot raid")
	DepotRun.close(state, run, {"loud": loud, "alarm": alarm, "door": opened, "time": int(f.t_op), "kind": run["kind"]})
	return out


## Per-fighter extras for Loadout.apply_op: health left, hits taken, went down.
func fighter_result(a) -> Dictionary:
	return {"hp": float(a.hp), "hits": int(hits.get(a.id, 0)), "was_down": downed.has(a.id)}


## On the op report: what's coming home (it lands when you press Back home).
func _draw_haul(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(54, sz.y * 0.5 + 40, sz.x - 108, 92)
	ci.draw_rect(r, Color(0.08, 0.07, 0.06, 0.95))
	ci.draw_rect(r, Pal.BRASS, false, 1.0)
	ci.draw_string(Pal.bold(), r.position + Vector2(8, 13), "THE HAUL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.BRASS)
	var y := r.position.y + 26
	var rows: Array = []
	if f.outcome != "success":
		rows.append("Nothing. You didn't hold the building.")
	else:
		rows.append("Vault: " + ("door %02d - %s: %s" % [opened + 1, str(door_result.get("label", "")).to_upper(), DepotRun.describe(door_result)] if opened >= 0 else "not opened"))
		rows.append("Stores from the %s: as much as the squad can carry (%d slots)." % [str(run["stores_title"]).to_lower(), _carry_cells()])
		var pz := prisoner
		if pz.is_empty():
			for e in f.enemies:
				if e.state == "cuffed":
					pz = (e.get_meta("def") as Dictionary).get("person", {})
					break
		rows.append("Prisoner: " + (str(pz.get("name", "")) + " comes back to the garage" if not pz.is_empty() else "none"))
	rows.append("Krall: this brings him closer.")
	for row in rows:
		ci.draw_string(Pal.font(), Vector2(r.position.x + 10, y), str(row), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 8, Pal.TEXT)
		y += 14
