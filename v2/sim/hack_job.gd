extends RefCounted
## One hacking job (docs/HEARTH_OS.md "Build 4"). Three stages, one trace bar:
##   scan   - ping the dark network to find the login server, then knock on it
##   crack  - three dials (name, year, ending) built from the owner's life
##   siphon - queue files; they download while the trace climbs on its own
## Gadgets plugged into the box (state.os["box"]) are the multipliers. No nodes: the PC app draws it.

const Content := preload("res://v2/sim/content.gd")

const PING_TRACE := 0.06
const KNOCK_WRONG := 0.03
const TRY_TRACE := 0.12
const SIPHON_TRACE := 0.035      # per second while connected in the siphon stage
const BASE_PING := 0.16          # ring radius, as a fraction of the field
const BANDWIDTH := 1.6           # MB per second

var target: Dictionary = {}
var stage := "scan"              # scan, crack, siphon, done
var trace := 0.0
var traced := false
var nodes: Array = []            # {name, kind, pos: Vector2 0..1, seen}
var pings: Array = []            # {pos: Vector2, t: float}
var ping_r := BASE_PING
var dials: Array = []            # {label, options: Array, answer: int, crossed: Array[int], solved}
var tries := 0
var files: Array = []            # {name, size, tag, worth, got, queued, done}
var queue: Array = []            # file indices, head downloads first
var trace_mult := 1.0
var grabbed: Array = []          # file indices finished
var gadgets := {}                # slot -> item dict
var finished := false
var aspect := 1.6                # field width / height, so the ping ring is a circle on screen
var _rng := RandomNumberGenerator.new()


## Distance in field units (1.0 = field height), allowing for the field being wider than tall.
func field_dist(a: Vector2, b: Vector2) -> float:
	return Vector2((a.x - b.x) * aspect, a.y - b.y).length()


static func targets() -> Array:
	return Content.get_file("os").get("targets", [])


static func target_def(id: String) -> Dictionary:
	for t in targets():
		if t["id"] == id:
			return t
	return {}


## The gadget item plugged into a box slot ("scan", "crack", "net"), or {}.
static func plugged(state: RefCounted, slot: String) -> Dictionary:
	var box: Dictionary = state.os.get("box", {})
	if not box.has(slot):
		return {}
	var id := int(box[slot])
	for it in state.items:
		if int(it.get("id", -1)) == id:
			return it
	return {}


static func create(state: RefCounted, t: Dictionary, p_seed: int) -> RefCounted:
	var j = load("res://v2/sim/hack_job.gd").new()
	j._setup(state, t, p_seed)
	return j


func _setup(state: RefCounted, t: Dictionary, p_seed: int) -> void:
	target = t
	_rng.seed = p_seed
	for slot in ["scan", "crack", "net"]:
		var g := plugged(state, slot)
		if not g.is_empty():
			gadgets[slot] = g
	var scan_stars := int(gadgets.get("scan", {}).get("stars", 0))
	ping_r = BASE_PING * (1.0 + 0.15 * scan_stars)
	var net_stars := int(gadgets.get("net", {}).get("stars", 0))
	trace_mult = maxf(0.45, 1.0 - 0.1 * net_stars) * float(t.get("trace_rate", 1.0))
	_make_network()
	_make_dials()
	for f in t.get("files", []):
		var fd: Dictionary = f
		files.append({"name": fd["name"], "size": float(fd["size"]), "tag": fd.get("tag", ""), "worth": fd.get("worth", ""),
			"got": 0.0, "queued": false, "done": false})


func _make_network() -> void:
	var n := int(target.get("nodes", 10))
	var names: Array = (target.get("machines", []) as Array).duplicate()
	nodes.append({"name": "router (you're in)", "kind": "router", "pos": Vector2(0.07, 0.5), "seen": true})
	# the login server sits on the far side; the file server somewhere in the middle
	nodes.append({"name": target.get("auth_name", "auth-01"), "kind": "auth", "pos": _free_spot(Vector2(0.6, 0.94)), "seen": false})
	nodes.append({"name": target.get("files_name", "files-01"), "kind": "files", "pos": _free_spot(Vector2(0.35, 0.9)), "seen": false})
	for i in n - 3:
		var nm: String = names[i] if i < names.size() else "host-%02d" % (i + 1)
		var kind := "misc"
		if nm.begins_with("cam"):
			kind = "camera"
		elif nm.begins_with("print") or nm.begins_with("fax"):
			kind = "printer"
		nodes.append({"name": nm, "kind": kind, "pos": _free_spot(Vector2(0.18, 0.94)), "seen": false})


func _free_spot(xr: Vector2) -> Vector2:
	var best := Vector2(0.5, 0.5)
	for attempt in 40:
		var p := Vector2(_rng.randf_range(xr.x, xr.y), _rng.randf_range(0.1, 0.9))
		var ok := true
		for nd in nodes:
			if (nd["pos"] as Vector2).distance_to(p) < 0.13:
				ok = false
				break
		best = p
		if ok:
			break
	return best


func _make_dials() -> void:
	var crack_stars := int(gadgets.get("crack", {}).get("stars", 0))
	var cross := 0
	if crack_stars > 0:
		cross = 1 + (1 if crack_stars >= 3 else 0) + (1 if crack_stars >= 5 else 0)
	for d in target.get("password", []):
		var dd: Dictionary = d
		var opts: Array = dd["options"]
		var ans := opts.find(dd["answer"])
		var wrong: Array = []
		for i in opts.size():
			if i != ans:
				wrong.append(i)
		wrong.shuffle()
		dials.append({"label": dd["label"], "options": opts, "answer": ans, "crossed": wrong.slice(0, mini(cross, wrong.size())), "solved": false})


# ------------------------------------------------------------------ actions

func add_trace(x: float) -> void:
	if stage == "done":
		return
	trace = minf(1.0, trace + x * trace_mult)
	if trace >= 1.0:
		traced = true
		stage = "done"


## Ping at p (0..1 field coords). Returns the indices of machines it revealed.
func ping(p: Vector2) -> Array:
	if stage != "scan":
		return []
	pings.append({"pos": p, "t": 0.0})
	var found: Array = []
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		if not nd["seen"] and field_dist(nd["pos"], p) <= ping_r:
			nd["seen"] = true
			found.append(i)
	add_trace(PING_TRACE)
	return found


## Knock on a machine you've seen. Only the login server opens.
func knock(i: int) -> bool:
	if stage != "scan" or not nodes[i]["seen"]:
		return false
	if nodes[i]["kind"] == "auth":
		stage = "crack"
		return true
	add_trace(KNOCK_WRONG)
	return false


## Try the dials (one option index per dial). Returns which dials are right.
func try_password(choice: Array) -> Array:
	if stage != "crack":
		return []
	tries += 1
	var right: Array = []
	var all := true
	for i in dials.size():
		var ok := int(choice[i]) == int(dials[i]["answer"])
		right.append(ok)
		if ok:
			dials[i]["solved"] = true
		else:
			all = false
	if all:
		stage = "siphon"
	else:
		add_trace(TRY_TRACE)
	return right


func queue_file(i: int) -> void:
	if stage != "siphon" or files[i]["queued"]:
		return
	files[i]["queued"] = true
	queue.append(i)


func tick(delta: float) -> void:
	for p in pings:
		p["t"] = float(p["t"]) + delta
	if stage != "siphon":
		return
	add_trace(SIPHON_TRACE * delta)
	if stage != "siphon" or queue.is_empty():
		return
	var i: int = queue[0]
	var f: Dictionary = files[i]
	f["got"] = minf(float(f["size"]), float(f["got"]) + BANDWIDTH * delta)
	if f["got"] >= f["size"]:
		f["done"] = true
		grabbed.append(i)
		queue.pop_front()


func disconnect_now() -> void:
	stage = "done"


## Apply the result to the game: intel items for what you took, a clue if you were traced. Once.
func finish(state: RefCounted) -> Dictionary:
	if finished:
		return {}
	finished = true
	stage = "done"
	var got_names: Array = []
	for i in grabbed:
		var f: Dictionary = files[i]
		got_names.append(f["name"])
		if f["tag"] == "junk":
			continue
		state.items.append({"id": state.next_item_id, "name": f["name"], "type": "intel", "tag": f["tag"], "worth": f["worth"],
			"source": target.get("name", "?"), "day": state.day, "stars": 0, "quality": 0.0, "hand": true, "perks": []})
		state.next_item_id += 1
	var clue := ""
	if traced:
		clue = str(target.get("clue", "Someone broke in tonight."))
		var clues: Array = state.flags.get("clues", [])
		clues.append(clue)
		state.flags["clues"] = clues
		state.attention = minf(100.0, state.attention + 5.0)
	var done: Array = state.os.get("jobs_done", [])
	if not done.has(target["id"]):
		done.append(target["id"])
	state.os["jobs_done"] = done
	return {"grabbed": got_names, "traced": traced, "trace": trace, "clue": clue, "tries": tries, "pings": pings.size()}
