extends RefCounted
## Hacking rules (docs/HACKING.md). No nodes: the PATCHBAY app draws a session.
##
## Targets: the fixed specials (data/v2/os.json "targets") plus a roster of town places generated from the
## world seed (data/v2/hacking.json "kinds"); each night shows a few of them.
## A session runs in stages, one trace bar (or, on site, a patrol clock) through all of them:
##   connect - PATCHBAY: place and turn tiles so the signal runs from IN to OUT. Live: it connects itself.
##   tune    - on site only: turn two knobs to match the target's signal and hold it (instead of connect)
##   inject  - the code chain: pick codes row / column / row... into the buffer; any program whose code shows
##             up in the buffer runs. Greed vs the trace.
##   done
## Gadgets in the box: SCAN shows ghost tiles on the route, CRACK makes the buffer longer, NET slows the trace.

const Content := preload("res://v2/sim/content.gd")

# tile sides
const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}
const SHAPES := {"straight": 5, "corner": 3, "tee": 7, "cross": 15}    # masks at rotation 0

# ------------------------------------------------------------------ data and knowledge

static func data() -> Dictionary:
	return Content.get_file("hacking")


static func program(id: String) -> Dictionary:
	return data().get("programs", {}).get(id, {})


## Usable at this target: known, or this is the tutorial target that teaches it.
static func usable(state: RefCounted, t: Dictionary, prog: String) -> bool:
	return knows(state, prog) or (t.get("teaches", []) as Array).has(prog)


## The guided first hacks (data/v2/hacking.json "tutorial"): the first one not done yet, or {}.
static func tutorial_next(state: RefCounted) -> Dictionary:
	var done: Array = state.os.get("jobs_done", [])
	for t in data().get("tutorial", []):
		if not done.has(t["id"]):
			return _tutorial(t)
	return {}


static func _tutorial(t: Dictionary) -> Dictionary:
	var d := t.duplicate(true)
	d["special"] = true
	d["tutorial"] = true
	d["programs"] = (t.get("teaches", []) as Array).duplicate()
	d["hours"] = float(t.get("hours", 1.5))
	return d


static func knows(state: RefCounted, prog: String) -> bool:
	if program(prog).get("known", false):
		return true
	return (state.os.get("know", []) as Array).has(prog)


static func learn(state: RefCounted, prog: String) -> void:
	var k: Array = state.os.get("know", [])
	if not k.has(prog):
		k.append(prog)
	state.os["know"] = k


static func learn_all(state: RefCounted) -> void:
	for p in data().get("programs", {}).keys():
		learn(state, p)


## The box gadget in a slot ("scan", "crack", "net"), or {}.
static func plugged(state: RefCounted, slot: String) -> Dictionary:
	var box: Dictionary = state.os.get("box", {})
	if not box.has(slot):
		return {}
	var id := int(box[slot])
	for it in state.items:
		if int(it.get("id", -1)) == id:
			return it
	return {}


# ------------------------------------------------------------------ targets

## Every place you could ever hack this run: the specials, then the town roster (same every load).
static func all_targets(state: RefCounted) -> Array:
	var out: Array = []
	for t in data().get("tutorial", []):
		out.append(_tutorial(t))
	for t in Content.get_file("os").get("targets", []):
		out.append(_special(t))
	out.append_array(_roster(state))
	return out


static func find(state: RefCounted, id: String) -> Dictionary:
	for t in all_targets(state):
		if t["id"] == id:
			return t
	return {}


## Tonight's list: the specials you've opened up, plus a few town places (rotates every night).
static func tonight(state: RefCounted) -> Array:
	var out: Array = []
	var tut := tutorial_next(state)
	if not tut.is_empty():
		return [tut]           # the guided hacks come first, one at a time
	var done: Array = state.os.get("jobs_done", [])
	for t in all_targets(state):
		if t.get("special", false) and not t.get("tutorial", false) and (not t.has("after") or done.has(t["after"])):
			out.append(t)
	var ros := _roster(state)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.world_seed) + "tonight" + str(state.day))
	var idx: Array = range(ros.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	for i in mini(int(data().get("per_night", 3)), idx.size()):
		out.append(ros[idx[i]])
	# an air-gapped place always shows once you've done a few jobs, so the on-site hack is findable
	if done.size() >= 1:
		for t in ros:
			if t.get("air_gap", false) and not out.has(t):
				out.append(t)
				break
	return out


## "ready", "locked" (cut out recently), "air_gap" (needs a device on site).
static func status(state: RefCounted, t: Dictionary) -> String:
	var locks: Dictionary = state.os.get("locked", {})
	if int(locks.get(t["id"], 0)) > int(state.day):
		return "locked"
	if t.get("air_gap", false):
		return "air_gap"
	return "ready"


static func nights_locked(state: RefCounted, t: Dictionary) -> int:
	return maxi(0, int(state.os.get("locked", {}).get(t["id"], 0)) - int(state.day))


## You have the owner's password (from a DIRT run): skip CONNECT.
static func has_key(state: RefCounted, t: Dictionary) -> bool:
	return (state.os.get("keys", []) as Array).has(str(t.get("owner", "")))


static func _special(t: Dictionary) -> Dictionary:
	var owner := str(t.get("owner", "?")).split(",")[0].strip_edges()
	var files: Array = []
	for f in t.get("files", []):
		files.append({"name": f["name"], "tag": f.get("tag", ""), "worth": f.get("worth", "")})
	var kind := "depot" if "depot" in str(t["id"]) else "office"
	var tier := 2 if kind == "depot" else 1
	var d := {"id": t["id"], "name": t["name"], "what": t.get("what", ""), "kind": kind, "tier": tier, "special": true,
		"owner": owner, "owner_line": t.get("owner", ""), "files": files, "clue": t.get("clue", ""),
		"programs": (data().get("kinds", {}).get(kind, {}).get("programs", ["grab", "wipe"]) as Array).duplicate(),
		"hours": float(t.get("hours", 2.0))}
	if t.has("after"):
		d["after"] = t["after"]
	return d


static func _roster(state: RefCounted) -> Array:
	var D := data()
	var kinds: Dictionary = D.get("kinds", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.world_seed) + "hack_roster")
	var streets: Array = D.get("streets", ["Main"])
	var firsts: Array = D.get("first_names", ["Ana"])
	var lasts: Array = D.get("last_names", ["Novak"])
	var jobs: Array = D.get("jobs", ["clerk"])
	var order := ["office", "depot", "shop", "clinic", "office", "depot", "clinic", "shop", "police"]
	var out: Array = []
	for i in int(D.get("roster", 9)):
		var kind: String = order[i % order.size()]
		var kd: Dictionary = kinds.get(kind, {})
		var names: Array = kd.get("names", ["Place %d"])
		var pat: String = names[rng.randi() % names.size()]
		var name := pat % (rng.randi_range(2, 9)) if "%d" in pat else pat % streets[rng.randi() % streets.size()]
		var tr: Array = kd.get("tier", [1, 1])
		var tier := rng.randi_range(int(tr[0]), int(tr[1]))
		var owner := "%s %s" % [firsts[rng.randi() % firsts.size()], lasts[rng.randi() % lasts.size()]]
		var files: Array = []
		for f in kd.get("files", []):
			var fn: String = f[0]
			files.append({"name": fn % rng.randi_range(1, 9), "tag": f[1], "worth": "%s (%s)" % [f[2], name]})
		out.append({"id": "%s_%d" % [kind, i], "name": name, "what": kd.get("what", ""), "kind": kind, "tier": tier,
			"owner": owner, "owner_line": "%s, %s" % [owner, jobs[rng.randi() % jobs.size()]], "files": files,
			"family": kd.get("family", "parts"), "air_gap": kd.get("air_gap", false),
			"programs": (kd.get("programs", ["grab", "wipe"]) as Array).duplicate(),
			"clue": "%s breach: someone got into %s in the evening." % [name, kd.get("what", "a terminal")],
			"hours": float(D.get("tiers", {}).get(str(tier), {}).get("hours", 2.0))})
	return out


# ------------------------------------------------------------------ a session

var target: Dictionary = {}
var onsite := false
var stage := "connect"            # connect, tune, inject, done
var trace := 0.0                  # 0..1 (on site: the patrol clock, as a fraction used)
var cut := false                  # trace full / clock out
var tier := 1
var rate := 1.0                   # trace multiplier (tier x NET gadget)
var gadgets := {}
var _rng := RandomNumberGenerator.new()
var finished := false

# connect: cells[y][x] = {kind: "empty"|"blocked"|"fixed"|"placed", mask: int, shape: String, rot: int, hint: String}
var gw := 5
var gh := 4
var cells: Array = []
var in_row := 0
var out_row := 0
var tray: Array = []              # {shape, used: bool}
var lit := {}                     # Vector2i -> true: cells the signal reaches right now
var connected := false

# tune (on site)
var knob := Vector2(0.2, 0.8)     # x = frequency, y = amplitude, both 0..1
var goal := Vector2(0.6, 0.4)
var lock := 0.0                   # 0..1: fills while matched
var _drift := Vector2.ZERO

# inject
var chain_n := 5
var chain: Array = []             # chain[y][x] = symbol
var used := {}                    # Vector2i -> true
var buffer: Array = []            # symbols picked
var buf_max := 5
var axis := "row"                 # pick along a row (index line) or a column
var line := 0
var programs: Array = []          # {id, name, code: Array, known: bool, done: bool}
var ran: Array = []               # program ids that ran, in order
var plan_path: Array = []          # the guaranteed route through the chain (for tests and hints)


static func create(state: RefCounted, t: Dictionary, p_seed: int, p_onsite := false) -> RefCounted:
	var s = load("res://v2/sim/hack.gd").new()
	s._setup(state, t, p_seed, p_onsite)
	return s


func _setup(state: RefCounted, t: Dictionary, p_seed: int, p_onsite: bool) -> void:
	target = t
	onsite = p_onsite
	_rng.seed = p_seed
	tier = int(t.get("tier", 1))
	for slot in ["scan", "crack", "net"]:
		var g := plugged(state, slot)
		if not g.is_empty():
			gadgets[slot] = g
	var td: Dictionary = data().get("tiers", {}).get(str(tier), {})
	var net := int(gadgets.get("net", {}).get("stars", 0))
	rate = float(td.get("trace_rate", 1.0)) * maxf(0.5, 1.0 - 0.08 * net)
	var g: Array = td.get("grid", [5, 4])
	gw = int(g[0])
	gh = int(g[1])
	chain_n = int(td.get("chain", 5))
	buf_max = int(data().get("buffer", 5)) + int(gadgets.get("crack", {}).get("stars", 0)) / 2
	if t.has("buffer"):
		buf_max = maxi(buf_max, int(t["buffer"]))
	if t.has("chain"):
		chain_n = int(t["chain"])
	if t.has("trace_rate"):
		rate *= float(t["trace_rate"])
	_make_patchbay(float(td.get("fixed", 0.4)), float(td.get("blocked", 0.25)), int(gadgets.get("scan", {}).get("stars", 0)))
	_make_programs(state)
	_make_chain()
	if onsite:
		stage = "tune"
		goal = Vector2(_rng.randf_range(0.25, 0.85), _rng.randf_range(0.3, 0.9))
		knob = Vector2(clampf(1.0 - goal.x, 0.05, 0.95), clampf(1.0 - goal.y, 0.05, 0.95))
	elif has_key(state, t):
		pass    # the app offers "log in as"; skip_connect() does it


## Skip CONNECT with the owner's password (the dirt shortcut, F).
func skip_connect() -> void:
	if stage == "connect":
		stage = "inject"


# ------------------------------------------------------------------ connect (PATCHBAY)

static func rot_mask(mask: int, rot: int) -> int:
	var m := mask
	for i in (rot % 4):
		m = ((m << 1) | (m >> 3)) & 15
	return m


static func shape_of(mask: int) -> String:
	var n := 0
	for b in [N, E, S, W]:
		if mask & b:
			n += 1
	if n == 4:
		return "cross"
	if n == 3:
		return "tee"
	if mask == (N | S) or mask == (E | W):
		return "straight"
	return "corner"


## Rotation that turns a shape's base mask into `mask` (or -1).
static func rot_for(shape: String, mask: int) -> int:
	for r in 4:
		if rot_mask(SHAPES[shape], r) == mask:
			return r
	return -1


func _make_patchbay(fixed_frac: float, blocked_frac: float, scan_stars: int) -> void:
	cells = []
	for y in gh:
		var row: Array = []
		for x in gw:
			row.append({"kind": "empty", "mask": 0, "shape": "", "rot": 0, "hint": ""})
		cells.append(row)
	in_row = _rng.randi_range(0, gh - 1)
	out_row = _rng.randi_range(0, gh - 1)
	# the route: column by column, go up or down to a random row, then step east
	var path: Array = []
	var y := in_row
	for x in gw:
		var to := out_row if x == gw - 1 else _rng.randi_range(0, gh - 1)
		path.append(Vector2i(x, y))
		while y != to:
			y += 1 if to > y else -1
			path.append(Vector2i(x, y))
	var masks := {}
	for i in path.size():
		var p: Vector2i = path[i]
		var m := 0
		var prev: Vector2i = path[i - 1] if i > 0 else Vector2i(-1, in_row)
		var nxt: Vector2i = path[i + 1] if i < path.size() - 1 else Vector2i(gw, out_row)
		for q in [prev, nxt]:
			var d: Vector2i = q - p
			for b in DIRS:
				if DIRS[b] == d:
					m |= b
		masks[p] = m
	var empties: Array = []
	for p in path:
		var c: Dictionary = cells[p.y][p.x]
		var m: int = masks[p]
		var sh := shape_of(m)
		if _rng.randf() < fixed_frac and p.x != 0:
			c["kind"] = "fixed"
			c["shape"] = sh
			c["rot"] = rot_for(sh, m)
			c["mask"] = m
		else:
			tray.append({"shape": sh, "used": false})
			empties.append(p)
			c["want"] = m
	# the first cell is always open (so the start is yours)
	# scan gadget: ghost hints on some route cells
	empties.shuffle()
	for i in mini(scan_stars, empties.size()):
		var p: Vector2i = empties[i]
		cells[p.y][p.x]["hint"] = shape_of(masks[p])
	# the rest of the board: blocked cells and decoys
	for yy in gh:
		for xx in gw:
			var p := Vector2i(xx, yy)
			if masks.has(p):
				continue
			var roll := _rng.randf()
			if roll < blocked_frac:
				cells[yy][xx]["kind"] = "blocked"
			elif roll < blocked_frac + 0.12:
				var sh: String = ["straight", "corner", "tee"][_rng.randi() % 3]
				var r := _rng.randi_range(0, 3)
				cells[yy][xx] = {"kind": "fixed", "shape": sh, "rot": r, "mask": rot_mask(SHAPES[sh], r), "hint": ""}
	# one or two decoy pieces in the tray, shuffled
	for i in 1 + (1 if tier >= 2 else 0):
		tray.append({"shape": ["straight", "corner", "tee"][_rng.randi() % 3], "used": false})
	tray.shuffle()
	_flow()


## Place tray piece `ti` on an empty cell. Returns true if placed.
func place(ti: int, at: Vector2i) -> bool:
	if stage != "connect" or ti < 0 or ti >= tray.size() or tray[ti]["used"]:
		return false
	var c: Dictionary = cells[at.y][at.x]
	if c["kind"] != "empty":
		return false
	var sh: String = tray[ti]["shape"]
	# start turned the way that best fits its neighbours (kind to the player; the turning still matters)
	c["kind"] = "placed"
	c["shape"] = sh
	c["rot"] = 0
	c["tray"] = ti
	c["mask"] = SHAPES[sh]
	tray[ti]["used"] = true
	_flow()
	return true


## Turn a placed tile a quarter clockwise.
func turn(at: Vector2i) -> void:
	if stage != "connect":
		return
	var c: Dictionary = cells[at.y][at.x]
	if c["kind"] != "placed":
		return
	c["rot"] = (int(c["rot"]) + 1) % 4
	c["mask"] = rot_mask(SHAPES[c["shape"]], int(c["rot"]))
	_flow()


## Take a placed tile back into the tray.
func lift(at: Vector2i) -> void:
	if stage != "connect":
		return
	var c: Dictionary = cells[at.y][at.x]
	if c["kind"] != "placed":
		return
	tray[int(c["tray"])]["used"] = false
	cells[at.y][at.x] = {"kind": "empty", "mask": 0, "shape": "", "rot": 0, "hint": c.get("hint", ""), "want": c.get("want", 0)}
	_flow()


## Light every cell the signal reaches from IN; connected when it leaves through OUT.
func _flow() -> void:
	lit = {}
	connected = false
	var start := Vector2i(0, in_row)
	var c0: Dictionary = cells[start.y][start.x]
	if not (int(c0["mask"]) & W):
		return
	var todo: Array = [start]
	lit[start] = true
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		var m: int = cells[p.y][p.x]["mask"]
		if p == Vector2i(gw - 1, out_row) and (m & E):
			connected = true
		for b in DIRS:
			if not (m & b):
				continue
			var q: Vector2i = p + DIRS[b]
			if q.x < 0 or q.y < 0 or q.x >= gw or q.y >= gh or lit.has(q):
				continue
			var opp: int = rot_mask(b, 2)
			if int(cells[q.y][q.x]["mask"]) & opp:
				lit[q] = true
				todo.append(q)
	if connected and stage == "connect":
		stage = "inject"


# ------------------------------------------------------------------ tune (on site)

func turn_knob(which: int, amount: float) -> void:
	if stage != "tune":
		return
	if which == 0:
		knob.x = clampf(knob.x + amount, 0.0, 1.0)
	else:
		knob.y = clampf(knob.y + amount, 0.0, 1.0)


func tune_error() -> float:
	return absf(knob.x - goal.x) + absf(knob.y - goal.y)


# ------------------------------------------------------------------ inject (the code chain)

func _make_programs(state: RefCounted) -> void:
	var syms: Array = data().get("symbols", ["1C", "55"])
	for pid in target.get("programs", ["grab"]):
		var pd := program(pid)
		var code: Array = []
		for i in int(pd.get("len", 2)):
			code.append(syms[_rng.randi() % syms.size()])
		programs.append({"id": pid, "name": pd.get("name", pid), "code": code, "known": usable(state, target, pid), "done": false, "text": pd.get("text", "")})


func _make_chain() -> void:
	var syms: Array = data().get("symbols", ["1C", "55"])
	chain = []
	for y in chain_n:
		var row: Array = []
		for x in chain_n:
			row.append(syms[_rng.randi() % syms.size()])
		chain.append(row)
	# a guaranteed route for the known programs, in order (GRAB first), as far as the buffer allows
	var plan: Array = []
	for p in programs:
		if p["known"] and plan.size() + (p["code"] as Array).size() <= buf_max:
			plan.append_array(p["code"])
	var pos := Vector2i(_rng.randi_range(0, chain_n - 1), 0)
	var seen := {}
	var along_row := true     # the first pick is in row 0 (choosing a column)
	for i in plan.size():
		seen[pos] = true
		plan_path.append(pos)
		chain[pos.y][pos.x] = plan[i]
		# next pick: in the column of this one (a new row), then in that row (a new column)...
		var options: Array = []
		for k in chain_n:
			var c := Vector2i(pos.x, k) if along_row else Vector2i(k, pos.y)
			if not seen.has(c):
				options.append(c)
		if options.is_empty():
			break               # boxed in: the rest of the plan just isn't guaranteed
		var nxt: Vector2i = options[_rng.randi() % options.size()]
		along_row = not along_row
		pos = nxt


## Can this cell be picked now?
func can_pick(p: Vector2i) -> bool:
	if stage != "inject" or used.has(p) or buffer.size() >= buf_max:
		return false
	return p.y == line if axis == "row" else p.x == line


func pick(p: Vector2i) -> Array:
	if not can_pick(p):
		return []
	used[p] = true
	buffer.append(chain[p.y][p.x])
	if axis == "row":
		axis = "col"
		line = p.x
	else:
		axis = "row"
		line = p.y
	var newly: Array = []
	for pr in programs:
		if pr["done"] or not pr["known"]:
			continue
		if _contains(buffer, pr["code"]):
			pr["done"] = true
			ran.append(pr["id"])
			newly.append(pr["id"])
			if pr["id"] == "wipe":
				trace = maxf(0.0, trace - float(data().get("trace", {}).get("wipe", 0.33)))
	if buffer.size() >= buf_max:
		stage = "done"
	return newly


static func _contains(buf: Array, code: Array) -> bool:
	if code.is_empty() or code.size() > buf.size():
		return false
	for i in buf.size() - code.size() + 1:
		var ok := true
		for k in code.size():
			if buf[i + k] != code[k]:
				ok = false
				break
		if ok:
			return true
	return false


## How many leading symbols of a program's code the buffer's tail already matches (for the progress dots).
func progress(pr: Dictionary) -> int:
	if pr["done"]:
		return (pr["code"] as Array).size()
	var code: Array = pr["code"]
	for n in range(mini(code.size() - 1, buffer.size()), 0, -1):
		var ok := true
		for k in n:
			if buffer[buffer.size() - n + k] != code[k]:
				ok = false
				break
		if ok:
			return n
	return 0


func jack_out() -> void:
	stage = "done"


# ------------------------------------------------------------------ time

func tick(delta: float) -> void:
	if stage == "done":
		return
	var T: Dictionary = data().get("trace", {})
	if onsite:
		trace += delta / float(T.get("onsite_seconds", 75))
		if stage == "tune":
			goal += _drift * delta
			if _rng.randf() < delta * 0.8:
				_drift = Vector2(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.05, 0.05))
			goal = goal.clamp(Vector2(0.1, 0.15), Vector2(0.9, 0.95))
			if tune_error() < 0.09:
				lock = minf(1.0, lock + delta * 0.45)
			else:
				lock = maxf(0.0, lock - delta * 0.25)
			if lock >= 1.0:
				stage = "inject"
	elif stage == "connect":
		trace += float(T.get("connect_per_s", 0.004)) * rate * delta
	elif stage == "inject":
		trace += float(T.get("inject_per_s", 0.022)) * rate * delta
	if trace >= 1.0:
		trace = 1.0
		cut = true
		stage = "done"


# ------------------------------------------------------------------ the result

## Apply what ran to the game. Once. Returns {lines: Array, ran: Array, cut: bool}.
func finish(state: RefCounted) -> Dictionary:
	if finished:
		return {}
	finished = true
	stage = "done"
	var D := data()
	var lines: Array = []
	for pid in ran:
		match pid:
			"grab":
				for f in target.get("files", []):
					if f.get("tag", "") == "junk":
						continue
					_intel(state, f["name"], f["tag"], f["worth"])
					lines.append("Copied %s." % f["name"])
			"dirt":
				var who := str(target.get("owner", "someone"))
				_intel(state, "dirt_%s.txt" % who.to_lower().replace(" ", "_"), "dirt", "Private mail of %s. Enough to lean on them." % target.get("owner_line", who), who)
				var keys: Array = state.os.get("keys", [])
				if not keys.has(who):
					keys.append(who)
				state.os["keys"] = keys
				lines.append("Dirt on %s, and their password for next time." % who)
			"camera":
				var cams: Array = state.os.get("cameras", [])
				if not cams.has(target["id"]):
					cams.append(target["id"])
				state.os["cameras"] = cams
				lines.append("Cameras at %s linked (WATCHLINE)." % target["name"])
			"payroll":
				var amounts: Array = D.get("payroll_cr", [40, 70, 110])
				var cr := int(amounts[clampi(tier - 1, 0, amounts.size() - 1)])
				state.money += cr
				state.attention = minf(100.0, state.attention + float(D.get("payroll_attention", 6)))
				lines.append("Skimmed %d cr from the payroll. Someone will notice." % cr)
			"redirect":
				var drops: Array = state.flags.get("drops", [])
				drops.append({"family": target.get("family", "parts"), "tier": tier, "from": target["name"], "day": state.day + 1})
				state.flags["drops"] = drops
				lines.append("A delivery from %s is rerouted. The crate waits at the drop tomorrow." % target["name"])
			"wipe":
				lines.append("Logs wiped.")
	if not cut and target.has("teaches"):
		for pid in target["teaches"]:
			if not knows(state, pid):
				learn(state, pid)
				lines.append("You learned %s. It works anywhere now." % program(pid).get("name", pid))
	var Krall = load("res://v2/sim/krall.gd")
	if cut:
		Krall.bump(state, 1.0, "cut out of %s" % target.get("name", "a hack"))
	elif ran.has("wipe"):
		Krall.push_back(state, 0.5, "wiped the logs at %s" % target.get("name", "a hack"))
	if cut:
		var clue := str(target.get("clue", "Someone broke in tonight."))
		var clues: Array = state.flags.get("clues", [])
		clues.append(clue)
		state.flags["clues"] = clues
		state.attention = minf(100.0, state.attention + float(D.get("onsite_caught_attention" if onsite else "caught_attention", 8)))
		var locks: Dictionary = state.os.get("locked", {})
		locks[target["id"]] = int(state.day) + (0 if target.get("tutorial", false) else int(D.get("lock_nights", 3)))
		state.os["locked"] = locks
		lines.append("CUT OUT. They saw you. %s is locked for %d nights, and the Bureau has a new clue." % [target["name"], int(D.get("lock_nights", 3))])
	var done: Array = state.os.get("jobs_done", [])
	if not done.has(target["id"]) and not (cut and target.get("tutorial", false)):
		done.append(target["id"])
	state.os["jobs_done"] = done
	lines.append_array(load("res://v2/sim/targets.gd").on_hack(state, target, ran, cut))
	if lines.is_empty():
		lines.append("You got out with nothing.")
	return {"lines": lines, "ran": ran.duplicate(), "cut": cut}


func _intel(state: RefCounted, fname: String, tag: String, worth: String, person := "") -> void:
	state.items.append({"id": state.next_item_id, "name": fname, "type": "intel", "tag": tag, "worth": worth, "person": person,
		"source": target.get("name", "?"), "day": state.day, "stars": 0, "quality": 0.0, "hand": true, "perks": []})
	state.next_item_id += 1


# ------------------------------------------------------------------ the morning: rerouted crates arrive

## Called overnight: crates whose day has come land in the stash. Returns ledger lines.
static func deliver_drops(state: RefCounted) -> Array:
	var lines: Array = []
	var drops: Array = state.flags.get("drops", [])
	var keep: Array = []
	var mats: Dictionary = Content.get_file("recipes").get("materials", {})
	for d in drops:
		if int(d["day"]) > int(state.day) + 1:
			keep.append(d)
			continue
		if load("res://v2/sim/krall.gd").seize_delivery(state):
			lines.append("SEIZED: the crate from %s was gone. Krall's people got there first." % d.get("from", "?"))
			continue
		# a few units of a material of that family, grade by tier
		var fam: String = d.get("family", "parts")
		var ids: Array = (data().get("families", {}).get(fam, []) as Array).duplicate()
		if ids.is_empty():
			ids = mats.keys()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(state.world_seed) + str(d))
		var got: Array = []
		for i in 2 + int(d.get("tier", 1)):
			var mid: String = ids[rng.randi() % ids.size()]
			var grade := clampi(int(d.get("tier", 1)) + rng.randi_range(0, 2), 1, 5)
			load("res://v2/sim/materials.gd").add(state, mid, 1, grade)
			got.append(str(mats[mid].get("name", mid)))
		lines.append("The crate from %s was at the drop: %s." % [d.get("from", "?"), ", ".join(PackedStringArray(got))])
	state.flags["drops"] = keep
	return lines
