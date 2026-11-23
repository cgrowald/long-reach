extends RefCounted
## The depot raid on top of the fight (roadmap M1; rules in v2/sim/depot_run.gd; docs/DEPOT_SLICE.md).
## The fight calls: prepare() before spawning, start() after, tick(), draw(), input(), and results() going home.
##   - a fresh depot every raid: kind, guards (person generator), stores, three vault doors
##   - going loud: the first shot starts the neighbours' clock (they always call it in eventually), and one guard
##     runs for the alarm box; drop him before he gets there and there's no alarm. Either clock running out =
##     BACKUP: Bureau reinforcements come in the front. You can fight out with meds, guns and good people.
##   - the stick carrier reaches the vault PC: "Boss, PC here, hit it?" You hack it (UNLOCK in the code chain,
##     from the van), let the stick run on its own (a chance by its stars), or leave it. One door before lockout.
##   - the door you pick opens: DCC-style loot (mostly junk, sometimes amazing). Then everyone gets out.
##   - the stores you came for go home as far as the squad can carry; a prisoner from the holding cell, or a
##     cuffed guard, comes home for the interrogation.

const Pal := preload("res://v2/ui/pal.gd")
const DepotRun := preload("res://v2/sim/depot_run.gd")
const Hack := preload("res://v2/sim/hack.gd")
const People := preload("res://v2/sim/people_gen.gd")
const Loadout := preload("res://v2/sim/loadout.gd")
const Krall := preload("res://v2/sim/krall.gd")
const Actor := preload("res://v2/combat/actor.gd")

const NEIGHBOURS_S := 150.0       # from the first shot, someone always calls it in
const ALARM_S := 75.0             # a pressed alarm brings them sooner
const ALARM_BOX := Vector3(4.6, 0, -13.6)
const STICK_S := 14.0
const RUN_SPEED := 1.9

var f: Control                    # the fight
var state: RefCounted
var run: Dictionary = {}
var phase := "quiet"              # quiet, loud, prompt, hacking, sticking, doors, opened, out
var loud := false
var t_loud := 0.0
var backup := -1.0                # seconds to backup (-1 = not coming yet)
var alarm := false
var runner = null                 # the guard running for the alarm box
var reinforced := false
var hits := {}                    # fighter id -> hits taken
var downed := {}
var session: RefCounted = null    # the vault hack
var stick_t := 0.0
var stick_chance := 0.35
var opened := -1
var door_result: Dictionary = {}
var prisoner: Dictionary = {}
var lines: Array = []             # for the report
var _btns: Array = []
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
	d["objective"] = {"text": "Reach the vault PC (dispatch office)", "room": "office", "pos": [-1.4, -24.8],
		"grab_line": "Boss, I see the PC that runs the vault doors. Want me to hit it?", "grab_log": "At the vault control PC", "hold_after": true}
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
		"hacking":
			if session != null and (session.ran as Array).has("unlock"):
				phase = "doors"
				f._event("UNLOCKED. One door, then the system locks out.")
				_flash = 1.0
			elif session != null and session.buffer.size() >= session.buf_max:
				phase = "out"
				lines.append("The vault hack failed. The doors stayed shut.")
				f._event("Hack failed. Locked out.")
				_exfil()
		"sticking":
			stick_t += delta
			if stick_t >= STICK_S:
				var rng := RandomNumberGenerator.new()
				rng.seed = int(run["seed"]) + 31
				if rng.randf() < stick_chance:
					phase = "doors"
					f._event("The stick got in. One door.")
					_flash = 1.0
				else:
					phase = "out"
					lines.append("The stick couldn't crack the vault.")
					f._event("The stick failed. Locked out.")
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


# ------------------------------------------------------------------ input

func input(e: InputEvent, mp: Vector2) -> bool:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return false
	for b in _btns:
		if (b[0] as Rect2).has_point(mp):
			_press(str(b[1]))
			return true
	# EYES ping: on a camera feed, click an enemy to alert the squad (the shout wheel's FOCUS makes them target)
	if phase in ["quiet", "loud", "out", "opened"] and not f.wheel_open and f.pending < 0:
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
	if phase == "hacking" and session != null:
		for y in session.chain_n:
			for x in session.chain_n:
				if _cell(Vector2i(x, y)).has_point(mp):
					session.pick(Vector2i(x, y))
					return true
	return false


func _press(id: String) -> void:
	match id:
		"hack":
			var t := {"id": "vault_ctrl", "name": "Vault control", "kind": "office", "tier": 1, "programs": ["unlock"], "teaches": ["unlock"], "buffer": 6, "chain": 5, "trace_rate": 0.0}
			session = Hack.create(state, t, int(run["seed"]) + 5)
			session.skip_connect()
			phase = "hacking"
			f.sq.order("hold", null, [], true)
			f._event("Squad hunkers down. Spell UNLOCK.")
		"stick":
			stick_chance = _stick_chance()
			stick_t = 0.0
			phase = "sticking"
			f.sq.order("hold", null, [], true)
			f._event("The stick is running. Squad hunkers down.")
		"leave":
			phase = "out"
			lines.append("You left the vault alone.")
			_exfil()
		"go":
			phase = "out"
			_exfil()
		_:
			if id.begins_with("door:"):
				opened = int(id.substr(5))
				door_result = run["doors"][opened]
				phase = "opened"
				_flash = 1.0
				f._event("DOOR %02d: %s" % [opened + 1, str(door_result["label"]).to_upper()])


func _stick_chance() -> float:
	var best := 0
	for it in state.items:
		if it.get("device", "") == "drop_stick":
			best = maxi(best, int(it.get("stars", 0)))
	return clampf(0.3 + best * 0.12, 0.3, 0.9)


# ------------------------------------------------------------------ drawing (on the fight's HUD, 640x360 logical)

func _btn(ci: CanvasItem, r: Rect2, label: String, id: String, primary := true) -> void:
	var hov := r.has_point(ci.get_local_mouse_position())
	var c := Pal.BRASS if primary else Pal.METAL_L
	ci.draw_rect(r, c.lightened(0.15) if hov else c)
	ci.draw_rect(r, Pal.METAL_D, false, 1.0)
	ci.draw_string(Pal.bold(), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Pal.METAL_D if primary else Pal.TEXT)
	_btns.append([r, id])


func _panel(ci: CanvasItem, r: Rect2, title: String) -> void:
	ci.draw_rect(r, Color(Pal.METAL_D, 0.96))
	ci.draw_rect(r, Pal.BRASS, false, 1.0)
	Pal.brackets(ci, r.grow(4), Pal.BRASS, 8.0, 1.0)
	Pal.tag(ci, r.position + Vector2(10, -8), title, 8)


func _cell(p: Vector2i) -> Rect2:
	var c := 20.0
	var org := Vector2(ci_size().x * 0.5 - c * 2.5 - 60, ci_size().y * 0.5 - 40)
	return Rect2(org + Vector2(p.x * c, p.y * c), Vector2(c, c)).grow(-1)


func ci_size() -> Vector2:
	return f.view.ui.size


func draw(ci: CanvasItem) -> void:
	_btns = []
	var sz := ci_size()
	if f.phase == "report":
		_draw_haul(ci, sz)
		return
	# the clocks, top centre
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
	var r := Rect2(sz.x * 0.5 - 170, sz.y * 0.5 - 80, 340, 160)
	match phase:
		"prompt":
			_panel(ci, r, "THE VAULT PC")
			ci.draw_multiline_string(Pal.font(), r.position + Vector2(12, 22), "\"Boss, I see the PC that runs the vault doors. Want me to hit it?\"\nThree doors, cabled to it. The system lets you open ONE before it locks out. The squad hunkers down while you work, and the backup clock keeps running.", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 8, -1, Pal.TEXT)
			for i in 3:
				var dr := Rect2(r.position.x + 12 + i * 60, r.position.y + 86, 54, 22)
				ci.draw_rect(dr, Color(0.18, 0.18, 0.2))
				ci.draw_string(Pal.bold(), dr.position + Vector2(0, 14), "%02d  %s" % [i + 1, DepotRun.door_hint(run, i)], HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 7, Pal.BRASS)
			_btn(ci, Rect2(r.position.x + 12, r.end.y - 30, 100, 20), "HACK IT", "hack")
			_btn(ci, Rect2(r.position.x + 118, r.end.y - 30, 130, 20), "STICK RUNS IT (%d%%)" % int(_stick_chance() * 100), "stick", false)
			_btn(ci, Rect2(r.end.x - 82, r.end.y - 30, 70, 20), "LEAVE IT", "leave", false)
		"hacking":
			_panel(ci, r, "VAULT CONTROL  |  SPELL UNLOCK")
			_draw_chain(ci, r)
		"sticking":
			_panel(ci, r, "THE STICK IS RUNNING")
			var k := stick_t / STICK_S
			var br := Rect2(r.position.x + 20, r.position.y + 60, r.size.x - 40, 10)
			ci.draw_rect(br, Pal.METAL)
			ci.draw_rect(Rect2(br.position, Vector2(br.size.x * k, br.size.y)), Pal.BRASS)
			ci.draw_string(Pal.font(), r.position + Vector2(20, 50), "Chance it gets in: %d%%. Better sticks from the hacking bench do better." % int(stick_chance * 100), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 8, Pal.TEXT)
		"doors":
			_panel(ci, r, "PICK ONE DOOR")
			ci.draw_string(Pal.font(), r.position + Vector2(12, 22), "One door. Then the system locks out for good.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.TEXT)
			for i in 3:
				var dr := Rect2(r.position.x + 18 + i * 104, r.position.y + 34, 96, 84)
				ci.draw_rect(dr, Color(0.14, 0.14, 0.16))
				ci.draw_rect(dr, Pal.METAL_L, false, 1.0)
				ci.draw_string(Pal.bold(), dr.position + Vector2(0, 30), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 18, Pal.TEXT)
				ci.draw_string(Pal.font(), dr.position + Vector2(0, 52), "intel: " + DepotRun.door_hint(run, i), HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 7, Pal.BRASS)
				_btn(ci, Rect2(dr.position.x + 18, dr.end.y - 24, 60, 18), "OPEN", "door:%d" % i)
		"opened":
			var jack: bool = door_result.get("tier", "") == "jackpot"
			_panel(ci, r, "DOOR %02d" % (opened + 1))
			var tc := {"junk": Pal.DIM, "decent": Pal.TEXT, "good": Color(0.6, 0.9, 0.5), "jackpot": Color(1.0, 0.8, 0.3)}.get(door_result.get("tier", ""), Pal.TEXT) as Color
			ci.draw_string(Pal.bold(), r.position + Vector2(0, 40), str(door_result.get("label", "")).to_upper() + ("!!" if jack else ""), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16 if jack else 13, tc)
			ci.draw_multiline_string(Pal.font(), r.position + Vector2(16, 62), "%s\n%s" % [DepotRun.describe(door_result), door_result.get("line", "")], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 8, -1, Pal.TEXT)
			_btn(ci, Rect2(r.position.x + r.size.x * 0.5 - 70, r.end.y - 30, 140, 20), "GRAB IT, GET OUT", "go")
	if _flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.8, 0.3, _flash * 0.12))


func _glyph(ci: CanvasItem, id: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var h := minf(r.size.x, r.size.y) * 0.32
	match id:
		"dia":
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0), c + Vector2(0, -h)]), col, 1.5)
		"bars":
			for k in 3:
				ci.draw_line(Vector2(c.x - h, c.y - h * 0.7 + k * h * 0.7), Vector2(c.x + h, c.y - h * 0.7 + k * h * 0.7), col, 1.5)
		"step":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h, h), c + Vector2(-h * 0.2, h), c + Vector2(-h * 0.2, -h), c + Vector2(h, -h)]), col, 1.5)
		"ring":
			ci.draw_arc(c, h * 0.85, 0, TAU, 14, col, 1.5)
		"cross":
			ci.draw_line(c + Vector2(-h, 0), c + Vector2(h, 0), col, 2.0)
			ci.draw_line(c + Vector2(0, -h), c + Vector2(0, h), col, 2.0)
		"slash":
			var sq := Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)
			ci.draw_rect(sq, col, false, 1.5)
			ci.draw_colored_polygon(PackedVector2Array([sq.position + Vector2(sq.size.x, 0), sq.end, sq.position + Vector2(0, sq.size.y)]), col)


func _draw_chain(ci: CanvasItem, r: Rect2) -> void:
	var s = session
	var pr: Dictionary = s.programs[0]
	var code: Array = pr["code"]
	var prog: int = s.progress(pr)
	var want: String = str(code[prog]) if prog < code.size() else ""
	for y in s.chain_n:
		for x in s.chain_n:
			var p := Vector2i(x, y)
			var cr := _cell(p)
			var on_line: bool = (s.axis == "row" and y == s.line) or (s.axis == "col" and x == s.line)
			if on_line:
				ci.draw_rect(cr.grow(1), Color(Pal.BRASS, 0.18))
			var sym: String = str(s.chain[y][x])
			var ok: bool = s.can_pick(p)
			if ok and sym == want:
				ci.draw_rect(cr, Color(Pal.BRASS, 0.3 + 0.12 * sin(_t * 5.0)))
			if s.used.has(p):
				ci.draw_rect(cr.grow(-6), Color(Pal.TEXT, 0.12))
			else:
				_glyph(ci, sym, cr, Pal.BRASS if ok and sym == want else (Pal.TEXT if on_line else Color(Pal.TEXT, 0.4)))
	var px := _cell(Vector2i(4, 0)).end.x + 20
	ci.draw_string(Pal.bold(), Vector2(px, r.position.y + 34), "UNLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.BRASS)
	for k in code.size():
		var cr := Rect2(px + k * 24, r.position.y + 42, 22, 16)
		ci.draw_rect(cr, Color(Pal.BRASS, 0.85) if k < prog else Pal.METAL)
		_glyph(ci, str(code[k]), cr, Pal.METAL_D if k < prog else Pal.TEXT)
	ci.draw_string(Pal.font(), Vector2(px, r.position.y + 76), "Buffer %d / %d" % [s.buffer.size(), s.buf_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.DIM)
	ci.draw_multiline_string(Pal.font(), Vector2(px, r.position.y + 92), "Pick along the lit row, then the lit column... The glowing cell is the next one you need.", HORIZONTAL_ALIGNMENT_LEFT, r.end.x - px - 10, 7, -1, Pal.DIM)


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
