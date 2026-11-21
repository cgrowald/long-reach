extends Node
## The squad decides HOW; you only say WHERE and WHEN. Turns a direction into a room clear:
## stack along the wall beside the door, open it (or bang it), flow through without stopping in
## the doorway, peel to alternating sides, dominate the room, call it clear.
## Skill (data/watch/skills.json) changes the quality: spacing, gaps, hesitation, wrong turns.

signal bark(unit, text: String)
signal room_cleared(id: String)
signal status(text: String)

const Unit := preload("res://tactical/units/unit.gd")
const UP := Vector3.UP

var units: Array = []
var hostiles: Array = []
var graph
var skill: Dictionary = {}
var loud := false
var cleared: Dictionary = {}           # room id -> true
var stats := {"hesitations": 0, "wrong_side": 0, "funnel": 0, "rooms": 0}
var previous_room := "outside"

var _op: Dictionary = {}                # the current clear: phase, door, target room, timers...
var _jobs: Array = []                   # {"t": seconds left, "fn": Callable} scheduled steps
var _hack: Dictionary = {}


func setup(p_units: Array, p_hostiles: Array, p_graph, p_skill: Dictionary) -> void:
	units = p_units
	hostiles = p_hostiles
	graph = p_graph
	skill = p_skill
	for u in units:
		u.reaction_time *= float(skill.get("reaction_mult", 1.0))
		u.accuracy_mult *= float(skill.get("accuracy", 1.0))
		u.turn_rate *= float(skill.get("turn_mult", 1.0))
		u.moving_accuracy = float(skill.get("moving_accuracy", 0.0))
		u.damage_taken_mult = float(skill.get("damage_taken", 1.0))


func alive() -> Array:
	return units.filter(func(u): return not u.is_dead)


func centroid() -> Vector3:
	var a := alive()
	if a.is_empty():
		return Vector3.ZERO
	var c := Vector3.ZERO
	for u in a:
		c += u.global_position
	return c / a.size()


func current_room() -> String:
	var counts: Dictionary = {}
	for u in alive():
		var r: String = graph.room_at(u.global_position)
		counts[r] = int(counts.get(r, 0)) + 1
	var best := "outside"
	var n := -1
	for r in counts:
		if int(counts[r]) > n:
			n = int(counts[r])
			best = r
	return best


func busy() -> bool:
	return not _op.is_empty()


func phase() -> String:
	return str(_op.get("phase", "holding"))


# ------------------------------------------------------------- orders

## What "go that way" would do right now (for the preview marker).
func preview(dir: Vector3) -> Dictionary:
	return graph.best_exit(current_room(), centroid(), dir, cleared)


## Stack the chosen soldiers on a door (by doctrine) and wait for a breach plan.
func stack_on(door, who: Array) -> void:
	var squad: Array = who.filter(func(u): return not u.is_dead)
	if squad.is_empty():
		return
	var c := Vector3.ZERO
	for u in squad:
		c += u.global_position
	c /= squad.size()
	var n: Vector3 = door.normal()
	if (c - door.center).dot(n) > 0.0:
		n = -n                       # into = away from where the stackers are
	var to: String = graph.room_at(door.center + n * 0.8)
	advance({"door": door, "into": n, "to": to}, squad, false)


## Move the chosen soldiers to a point, spread out a little, facing on the way they went.
func move_to(who: Array, point: Vector3) -> void:
	var squad: Array = who.filter(func(u): return not u.is_dead)
	if squad.size() == alive().size():
		_cancel()
	var i := 0
	for u in squad:
		var off := Vector3((i % 2) * 1.1 - 0.55, 0.0, (i / 2) * 1.1) if squad.size() > 1 else Vector3.ZERO
		var dest: Vector3 = _nav(point + off)
		var dir: Vector3 = (dest - u.global_position)
		dir.y = 0.0
		u.stop()
		u.set_pace(Unit.Pace.RUN if loud else Unit.Pace.WALK)
		u.order_move(dest, false)
		if dir.length() > 0.5:
			u.order_face(dest + dir.normalized() * 5.0)
		i += 1
	if not squad.is_empty():
		bark.emit(squad[0], "Moving.")


## Run the breach plan on the stacked door.
## plan: {"method": "open"|"kick"|"charge", "grenade": "none"|"flashbang"|"frag", "order": [units], "pie": bool}
func execute(plan: Dictionary) -> void:
	if _op.is_empty() or not (str(_op["phase"]) in ["stacked", "approach"]):
		return
	_op["plan"] = plan
	var ord: Array = plan.get("order", []).filter(func(u): return not u.is_dead)
	for u in _op["order"]:
		if not ord.has(u) and not u.is_dead:
			ord.append(u)
	_op["order"] = ord
	if str(_op["phase"]) == "approach":
		_op["auto"] = true      # still walking up: hit it as soon as they are stacked
		return
	_door_step()


func stacked() -> bool:
	return str(_op.get("phase", "")) == "stacked"


func stacked_door():
	return _op.get("door") if not _op.is_empty() else null


## Clear the room behind this exit. auto = go straight in (old direction mode); else wait for a plan.
func advance(exit: Dictionary, who: Array = [], auto: bool = true) -> void:
	if exit.is_empty() or alive().is_empty():
		return
	_cancel()
	previous_room = current_room()
	var door = exit["door"]
	var n: Vector3 = exit["into"]
	var t: Vector3 = n.cross(UP).normalized()
	var squad: Array = who.filter(func(u): return not u.is_dead) if not who.is_empty() else alive()
	if squad.is_empty():
		return
	# Stack on the side of the door we can stand on and that's closer to us.
	var base: Vector3 = door.center - n * 0.6
	var side := 1.0
	var best := INF
	for s in [1.0, -1.0]:
		var p: Vector3 = _nav(base + t * s * 1.3)
		var ok: bool = p.distance_to(base + t * s * 1.3) < 0.35
		var dist: float = p.distance_to(centroid()) + (0.0 if ok else 100.0)
		if dist < best:
			best = dist
			side = s
	_op = {"phase": "approach", "door": door, "n": n, "t": t, "side": side, "to": str(exit["to"]),
		"time": 0.0, "stack": [], "order": squad, "auto": auto}
	var spacing: float = float(skill.get("stack_spacing", 1.0))
	var jitter: float = float(skill.get("stack_jitter", 0.0))
	var gap: float = float(skill.get("depart_gap", 0.4))
	for i in squad.size():
		var u = squad[i]
		var p: Vector3 = base + t * side * (0.95 + i * spacing + randf_range(-jitter, jitter))
		if i == squad.size() - 1 and i > 0 and randf() < float(skill.get("funnel_chance", 0.0)):
			p = door.center - n * (1.4 + randf() * 0.6)   # standing in the fatal funnel
			stats["funnel"] += 1
			_later(i * gap + 0.2, func(): bark.emit(u, "..."))
		p = _nav(p)
		_op["stack"].append(p)
		var pace_run: bool = loud
		_later(i * gap, func():
			if u.is_dead:
				return
			u.stop()
			u.set_pace(Unit.Pace.RUN if pace_run else Unit.Pace.WALK)
			u.order_move(p, false)
			u.order_face(door.center))
	bark.emit(squad[0], "Moving.")
	status.emit("Stacking on the door to %s" % graph.room(_op["to"])["name"])


## Stop everything and hold where you are.
func hold(only: Array = []) -> void:
	var who := only if not only.is_empty() else alive()
	if only.is_empty():
		_cancel()
	for u in who:
		u.stop()
	if not who.is_empty():
		bark.emit(who[0], "Holding.")
	status.emit("Holding")


## Fall back to the last room you came from.
func pull_out() -> void:
	_cancel()
	var dest: Vector3 = graph.center(previous_room) if previous_room != "outside" else Vector3(0.0, 0.0, 17.0)
	var i := 0
	for u in alive():
		u.stop()
		u.set_pace(Unit.Pace.RUN)
		u.order_move(_nav(dest + Vector3((i % 2) * 1.2 - 0.6, 0.0, (i / 2) * 1.2)), false)
		i += 1
	if not alive().is_empty():
		bark.emit(alive()[0], "Pulling out!")
	status.emit("Pulling out")


## One soldier: take a spot that way inside the current room and watch that way.
func defend(u, dir: Vector3) -> void:
	if u.is_dead:
		return
	var here: String = graph.room_at(u.global_position)
	var spot: Vector3 = u.global_position + dir * 4.0
	spot = graph.clamp_in(here, spot) if here != "outside" else spot
	spot = _nav(spot)
	u.stop()
	u.order_move(spot, false)
	u.order_face(spot + dir * 6.0)
	bark.emit(u, "Covering.")


## One soldier: go to the camera hub and work it. on_done() when finished.
func hack(u, hub: Vector3, seconds: float, on_done: Callable) -> void:
	if u.is_dead:
		return
	u.stop()
	u.order_move(_nav(hub), false)
	_hack = {"unit": u, "hub": hub, "left": seconds, "done": on_done, "working": false}
	bark.emit(u, "On the box.")


func set_loud(v: bool) -> void:
	loud = v
	for u in alive():
		u.set_pace(Unit.Pace.RUN if loud else Unit.Pace.WALK)


# ------------------------------------------------------------- the clear, step by step

func _physics_process(delta: float) -> void:
	_run_jobs(delta)
	_update_hack(delta)
	if _op.is_empty():
		return
	_op["time"] = float(_op["time"]) + delta
	match str(_op["phase"]):
		"approach":
			if _all_arrived() or float(_op["time"]) > 14.0:
				if _op.get("auto", true):
					_door_step()
				else:
					_op["phase"] = "stacked"
					var st: Array = _op["order"].filter(func(u): return not u.is_dead)
					if not st.is_empty():
						bark.emit(st[st.size() - 1], "Stacked.")
					status.emit("Stacked on the door to %s. Build the breach plan." % graph.room(_op["to"])["name"])
		"pie":
			# Done when the point man has finished his arc (or it's taking too long).
			_op["pie_wait"] = float(_op.get("pie_wait", 0.0)) + delta
			var point = _op["order"][0]
			if float(_op["pie_wait"]) > 0.8 and (point.is_dead or not point.is_moving()) and point.target == null:
				_op["phase"] = "door"
				_start_entry()
			elif float(_op["pie_wait"]) > 7.0:
				_op["phase"] = "door"
				_start_entry()
		"entry":
			pass   # scheduled jobs move people in
		"clearing":
			_check_clear(delta)


func _door_step() -> void:
	var door = _op["door"]
	var squad: Array = _op["order"].filter(func(u): return not u.is_dead)
	if squad.is_empty():
		_cancel()
		return
	_op["phase"] = "door"
	var point = squad[0]
	var inside: Vector3 = door.center + _op["n"] * 3.0
	var plan: Dictionary = _op.get("plan", {})
	var method: String = str(plan.get("method", "kick" if loud else "open"))
	var grenade: String = str(plan.get("grenade", "flashbang" if loud else "none"))
	var pie: bool = bool(plan.get("pie", (not loud) and skill.get("pies_doorway", false)))
	var delay := 0.3
	if not door.is_open:
		match method:
			"charge":
				var breacher = null
				for u in squad:
					if u.can_do("breach"):
						breacher = u
						break
				if breacher != null:
					breacher.items["breach_charge"] = breacher.item_count("breach_charge") - 1
					bark.emit(breacher, "Breaching!")
					door.blow()
					delay = 0.6
				else:
					door.kick()
					bark.emit(point, "No charge. Kicking it!")
			"kick":
				door.kick()
				bark.emit(point, "Kick!")
			_:
				door.open()
	if grenade != "none":
		for u in squad:
			if u.throw_grenade(grenade, graph.clamp_in(_op["to"], inside)):
				bark.emit(u, "Flash out!" if grenade == "flashbang" else "Frag out!")
				delay = maxf(delay, 1.1)
				pie = false       # after a bang, you go now, you don't slice
				break
	if pie:
		# Slice the pie on the open doorway from outside: see (and shoot) into the room
		# from cover before anyone steps into the doorway. The Door Kickers moment.
		_op["phase"] = "pie"
		_later(0.35, func():
			if _op.is_empty() or point.is_dead:
				return
			point.order_pie(door.center, false)
			bark.emit(point, "Slicing it."))
		_op["pie_wait"] = 0.0
		return
	_later(delay, _start_entry)


func _start_entry() -> void:
	if _op.is_empty():
		return
	_op["phase"] = "entry"
	var squad: Array = _op["order"].filter(func(u): return not u.is_dead)
	var door = _op["door"]
	var n: Vector3 = _op["n"]
	var t: Vector3 = _op["t"]
	var s: float = float(_op["side"])
	var gaps: Array = skill.get("entry_gap", [0.5, 0.6])
	var when := 0.0
	var prev_side := 0.0
	_op["inside"] = 0
	for i in squad.size():
		var u = squad[i]
		# Alternate sides: #1 crosses away from the stack, #2 takes the stack side, and so on.
		var side: float = -s if i % 2 == 0 else s
		if i > 0 and randf() < float(skill.get("wrong_side_chance", 0.0)):
			side = prev_side
			stats["wrong_side"] += 1
		prev_side = side
		var depth: float = 1.6 if i < 2 else 3.2
		var lateral: float = 2.3 if i < 2 else 1.1
		var spot: Vector3 = _nav(graph.clamp_in(_op["to"], door.center + n * depth + t * side * lateral))
		var corner: Vector3 = graph.clamp_in(_op["to"], door.center + n * 0.4 + t * side * 12.0, 0.3)
		var room_c: Vector3 = graph.center(_op["to"])
		var threshold: Vector3 = door.center + n * 0.25
		var hesitate: bool = randf() < float(skill.get("hesitate_chance", 0.0))
		var h_range: Array = skill.get("hesitate_time", [0.0, 0.0])
		var h_time: float = randf_range(float(h_range[0]), float(h_range[1]))
		var vet_eyes: bool = skill.get("pies_doorway", false)
		_later(when, func():
			if u.is_dead or _op.is_empty():
				return
			u.stop()
			u.set_pace(Unit.Pace.RUN if loud else Unit.Pace.WALK)
			if hesitate:
				stats["hesitations"] += 1
				u.order_move(threshold, false)   # stops in the doorway, the worst place to stop
				_later(h_time, func():
					if u.is_dead or _op.is_empty():
						return
					u.order_move(spot, false)
					u.order_face(room_c)
					_op["inside"] = int(_op.get("inside", 0)) + 1)
			else:
				u.order_move(spot, false)
				u.order_face(room_c)
				_op["inside"] = int(_op.get("inside", 0)) + 1
			if vet_eyes:
				u.look_now(corner, true)       # eyes on his corner first, weapon up
			if i == 0:
				bark.emit(u, "Going in!"))
		when += randf_range(float(gaps[0]), float(gaps[1]))
	_later(when + 0.5, func():
		if not _op.is_empty():
			_op["phase"] = "clearing"
			_op["quiet_for"] = 0.0)


func _check_clear(delta: float) -> void:
	var to: String = _op["to"]
	var threats := 0
	for h in hostiles:
		if not h.is_dead and not h.captured and graph.room_at(h.global_position) == to:
			threats += 1
	if threats > 0 or not _all_arrived():
		_op["quiet_for"] = 0.0
		return
	_op["quiet_for"] = float(_op.get("quiet_for", 0.0)) + delta
	if float(_op["quiet_for"]) < 1.0:
		return
	if not cleared.has(to):
		cleared[to] = true
		stats["rooms"] += 1
	var squad: Array = _op["order"].filter(func(u): return not u.is_dead)
	if not squad.is_empty():
		bark.emit(squad[squad.size() - 1], "CLEAR!")
	room_cleared.emit(to)
	status.emit("%s clear. Waiting for orders." % graph.room(to)["name"])
	_op = {}


func _all_arrived() -> bool:
	var who: Array = _op.get("order", alive()) if not _op.is_empty() else alive()
	for u in who:
		if u.is_dead:
			continue
		if u.is_moving():
			return false
	return true


# ------------------------------------------------------------- the hacker

func _update_hack(delta: float) -> void:
	if _hack.is_empty():
		return
	var u = _hack["unit"]
	if u.is_dead:
		_hack = {}
		return
	if not _hack["working"]:
		if not u.is_moving() and u.global_position.distance_to(_hack["hub"]) < 1.6:
			_hack["working"] = true
			bark.emit(u, "Working...")
		return
	_hack["left"] = float(_hack["left"]) - delta
	if float(_hack["left"]) <= 0.0:
		bark.emit(u, "Cameras are ours.")
		var cb: Callable = _hack["done"]
		_hack = {}
		cb.call()


# ------------------------------------------------------------- helpers

func _later(seconds: float, fn: Callable) -> void:
	_jobs.append({"t": seconds, "fn": fn})


func _run_jobs(delta: float) -> void:
	var due: Array = []
	for j in _jobs:
		j["t"] = float(j["t"]) - delta
		if float(j["t"]) <= 0.0:
			due.append(j)
	for j in due:
		_jobs.erase(j)
		(j["fn"] as Callable).call()


func _cancel() -> void:
	_op = {}
	_jobs.clear()


func _nav(p: Vector3) -> Vector3:
	var q: Vector3 = NavigationServer3D.map_get_closest_point(get_viewport().find_world_3d().navigation_map, p)
	q.y = 0.0
	return q
