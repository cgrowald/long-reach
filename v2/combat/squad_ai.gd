extends RefCounted
## Your people (docs/COMBAT_SLICE.md section 8): they are their own people. Left alone they clear by
## doctrine, slowly: stack on the next door, take a breath, open it, flow in one at a time to the corners,
## call it clear, regroup, move on. Your shouts (order()) set the focus and the risk. They answer back,
## take cover before obeying under fire, patch each other, cuff anyone who gives up.

signal log_line(text: String)
signal objective_done
signal exfil_done

const Audio := preload("res://v2/combat/combat_audio.gd")
const Rules := preload("res://v2/combat/rules.gd")
const WALK := 0.85
const RUN := 1.9
const ENTRY_GAP := 1.3
const STICK_TECH_MIN := 1
const BREATH := 2.2

var fighters: Array = []
var enemies: Array = []
var level: Node3D
var enemy_ai: RefCounted
var rng := RandomNumberGenerator.new()
var task: Dictionary = {"type": "idle"}
var auto := true                   # doctrine picks the next step when a task ends
var cleared := {}
var focus_target = null
var cover := {}                    # fighter -> Vector3 they watch
var pending: Dictionary = {}       # an order waiting for the shooting to stop
var have_objective := false
var pc_files: Array = []           # PCs exploited this op (C3): what came off them
var start_pos := Vector3.ZERO
var in_contact := false
var _contact_t := 0.0
var _t := 0.0


func setup(p_fighters: Array, p_enemies: Array, p_level: Node3D, p_enemy_ai: RefCounted, p_start: Vector3) -> void:
	fighters = p_fighters
	enemies = p_enemies
	level = p_level
	enemy_ai = p_enemy_ai
	start_pos = p_start
	rng.seed = 5
	cleared["hall"] = true        # they start in it
	cleared[level.room_at(p_start)] = true
	if not level.data.get("doctrine", true):
		auto = false             # an open place (M4): nothing to clear room by room until you say
		return
	for r in level.rooms:
		if r["outdoor"]:
			cleared[r["id"]] = true     # a building raid (M4 V3): the street and the yard aren't rooms to clear
	_next_doctrine()


## Who carries the drop stick (picked in the cage). If they're down or dead, the nearest fighter with
## enough tech takes it off them. null = nobody has one.
func stick_carrier():
	var had = null
	for f in fighters:
		if f.stick >= 0:
			had = f
	if had == null:
		return null
	if had.alive():
		return had
	var best = null
	var bd := 1e9
	for f in alive_fighters():
		if f.tech >= STICK_TECH_MIN:
			var d: float = f.global_position.distance_to(had.global_position)
			if d < bd:
				bd = d
				best = f
	if best == null:
		return null
	best.stick = had.stick
	had.stick = -1
	best.say("I've got %s's stick." % _first(had), true)
	log_line.emit("%s took %s's stick" % [_first(best), _first(had)])
	return best


func by_role(r: String):
	for f in fighters:
		if f.role == r and f.alive():
			return f
	for f in fighters:
		if f.alive():
			return f
	return null


func alive_fighters() -> Array:
	return fighters.filter(func(f) -> bool: return f.alive())


# ------------------------------------------------------------------ your shouts

## kind: stack, breach, bang, charge, push, hold, fallback, cover, focus, medic, go.
## target: a door dict, a room id, an actor, or a Vector3. who: [] = everyone.
var objection: Dictionary = {}    # {kind, target, who, by, reason, suggest, suggest_label, t}
const RISKY := ["push", "breach", "open", "move", "charge", "bang", "bang_wait"]


func order(kind: String, target = null, who: Array = [], skip_check := false) -> void:
	# the same shout again while they're objecting = do it anyway (they go, but shaken)
	if not objection.is_empty() and objection["kind"] == kind and _same(objection["target"], target) and _t - float(objection["t"]) < 12.0:
		var by = objection["by"]
		# their lives come first (user 2026-11-23): a deadly order is refused even when you repeat it
		if float(objection.get("risk", 0.0)) > threshold(by) + 0.45 if by else false:
			by.say(["No. That's a grave, boss. Not doing it.", "Negative. We'd all die in there.", "I won't send us in to die. Find another way."][rng.randi() % 3], true)
			log_line.emit("%s REFUSED: too deadly" % _first(by))
			objection["t"] = _t
			return
		if by and by.alive():
			by.say(["Copy... going.", "Your call, boss.", "Fine. Going in."][rng.randi() % 3], true)
		log_line.emit("YOU overruled %s: %s anyway" % [_first(by), kind.to_upper()])
		_shake_team()
		objection.clear()
		skip_check = true
	elif kind in RISKY and not skip_check and not (target is Vector3):     # a point outside: they bound cover to cover
		var dz := danger(kind, target)
		var by = dz["by"]
		if by != null and float(dz["risk"]) > threshold(by):
			objection = {"kind": kind, "target": target, "who": who, "by": by, "reason": dz["reason"], "risk": float(dz["risk"]),
				"suggest": dz["suggest"], "suggest_label": dz["suggest_label"], "t": _t}
			by.say("%s %s" % [dz["reason"], dz["suggest_line"]], true)
			return
	if kind != "medic" and kind != "cover" and kind != "focus":
		objection.clear()
	match kind:
		"stack":
			auto = false
			_set_stack(target, "", false)
			_ack("stack", {"door": _door_name(target)})
		"breach", "bang", "charge", "open", "bang_wait":
			auto = true          # after the room they go on to the next door and ask again (they never open one alone)
			var how := {"breach": "kick", "bang": "bang", "charge": "charge", "open": "open", "bang_wait": "bang"}[kind] as String
			if task.get("type") == "stacked" and task.get("door") == target:
				task["wait"] = kind == "bang_wait"
				_set_breach(target, how)
			else:
				_set_stack(target, how, true)
				task["wait"] = kind == "bang_wait"
			_ack({"open": "breach", "bang_wait": "bang"}.get(kind, kind))
		"move":
			auto = false
			if target is Vector3:
				_move_to_point(target)
				return
			var rid := str(target)
			var lead = by_role("point")
			var rooms: Array = level.room_path(level.room_near(lead.global_position), rid) if lead else []
			for i in range(rooms.size() - 1):
				var d: Dictionary = level.door_between(rooms[i], rooms[i + 1])
				if not d.is_empty() and d["state"] == "closed":
					if lead:
						lead.say("Door's shut on the way. Stacking on it.", true)
					_set_stack(d, "", false)
					return
			var c: Vector2 = (level.room(rid)["rect"] as Rect2).get_center()
			var k := 0
			for f in alive_fighters():
				f.go(_route(f, Vector3(c.x + (k % 2) * 0.8 - 0.4, 0, c.y + int(k / 2) * 0.8 - 0.4)), WALK)
				k += 1
			task = {"type": "move", "room": rid}
			_ack("push", {"room": _room_name(rid)})


		"push":
			auto = false
			var d := _door_toward(str(target))
			if d.is_empty():
				return
			if d["state"] != "closed":
				_set_flow(d, str(target), true)
			else:
				_set_stack(d, "kick", true)
			_ack("push", {"room": _room_name(str(target))})
		"hold":
			for f in _who(who):
				f.stop()
			if who.is_empty():
				task = {"type": "hold"}
			_ack("hold")
		"fallback":
			auto = false
			bound_out(true)
			_ack("fallback")
		"cover":
			for f in _who(who):
				cover[f] = target
			_ack("cover")
		"focus":
			focus_target = target
			_ack("focus")
		"medic":
			task["medic_for"] = target
			var m = by_role("medic")
			if m:
				m.bark("medic", {"name": _first(target)}, true)
		"go":
			auto = true
			pending.clear()
			_next_doctrine()
			_ack("go")


## Their way: do what the objecting fighter suggested instead.
func accept_suggestion() -> void:
	if objection.is_empty():
		return
	var s: String = objection["suggest"]
	var tgt = objection["target"]
	var who: Array = objection["who"]
	objection.clear()
	if s == "hold":
		order("hold", null, who, true)
	elif tgt is String:
		# they were asked to push a room: their way is to flash the door into it
		var d := _door_toward(tgt)
		if not d.is_empty():
			order(s, d, who, true)
	else:
		order(s, tgt, who, true)


func _same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		return a.get("id", "") == b.get("id", "")
	return a == b


## Being overruled rattles them: slower to react for a while.
func _shake_team() -> void:
	for f in alive_fighters():
		if not f.has_meta("shaky_until"):
			f.st["react"] = float(f.st["react"]) + 0.35
		f.set_meta("shaky_until", _t + 20.0)


## How dangerous an order looks to the fighter who'd go first, and what they'd rather do.
func danger(kind: String, target) -> Dictionary:
	var room := ""
	if target is Dictionary:
		var d: Dictionary = target
		room = d["b"] if cleared.get(d["a"], false) or d["a"] == "hall" else d["a"]
	elif target is String:
		room = target
	var by = by_role("point")
	var risk := 0.0
	var reasons: Array = []
	if room != "" and not cleared.get(room, false):
		risk += 0.35
		reasons.append([0.35, "Boss, we don't know what's in there."])
		var seen := 0
		for e in enemies:
			if e.state == "ok" and e.has_meta("seen_t") and _t - float(e.get_meta("seen_t")) < 15.0 and level.room_at(e.get_meta("seen_pos")) == room:
				seen += 1
		if seen > 0:
			risk += 0.3 * seen
			reasons.append([0.3 * seen + 0.36, "There's %s in there, they're waiting for us." % ("one" if seen == 1 else str(seen))])
	if in_contact:
		risk += 0.3
		reasons.append([0.31, "We're taking fire!"])
	if by:
		if by.wounds > 0 or by.hp < 55.0:
			risk += 0.15
			reasons.append([0.15, "I'm hurt, boss."])
		if by.mags <= 0 and by.mag_rounds < 10:
			risk += 0.2
			reasons.append([0.2, "I'm nearly dry."])
	if kind in ["bang", "bang_wait"]:
		risk *= 0.4
	elif kind == "charge":
		risk *= 0.5
	reasons.sort_custom(func(p: Array, q: Array) -> bool: return p[0] > q[0])
	var reason: String = reasons[0][1] if not reasons.is_empty() else ""
	var flash_ok := false
	for f in alive_fighters():
		if f.flashes > 0:
			flash_ok = true
	var suggest := "bang" if flash_ok and not in_contact and kind not in ["bang", "bang_wait"] else "hold"
	var line := "Let me bang it first." if suggest == "bang" else "Let's hold till it's quiet."
	return {"risk": risk, "reason": reason, "by": by, "suggest": suggest, "suggest_label": "FLASH & CLEAR" if suggest == "bang" else "HOLD", "suggest_line": line}


## How much risk this fighter takes on a word: nerve from the trait (training adds to it later).
func threshold(f) -> float:
	var t := {"careful": 0.45, "steady": 0.55, "jumpy": 0.4, "cocky": 0.8}.get(f.trait_name, 0.5) as float
	if f.has_meta("shaky_until"):
		t -= 0.1
	return t


func _ack(key: String, fill := {}) -> void:
	var f = by_role("point")
	if key in ["breach", "bang", "charge"]:
		f = by_role("breacher")
	if f:
		f.bark(key, fill, true)


func _who(who: Array) -> Array:
	if who.is_empty():
		return alive_fighters()
	return who.filter(func(f) -> bool: return f.alive())


# ------------------------------------------------------------------ the doctrine

## Next room to clear: the nearest uncleared one on the way, the objective room last.
func _next_doctrine() -> void:
	if have_objective:
		bound_out(false)
		return
	var lead = by_role("point")
	if lead == null:
		task = {"type": "idle"}
		return
	var here: String = level.room_at(lead.global_position)
	var best := {}
	var bd := 1e9
	var obj_room: String = level.data.get("objective", {}).get("room", "")
	for d in level.doors:
		for side in [["a", "b"], ["b", "a"]]:
			var into: String = d[side[1]]
			if cleared.get(into, false) or into == here:
				continue
			if d[side[0]] != here and not cleared.get(d[side[0]], false) and d[side[0]] != "hall":
				continue
			var dist: float = level.door_world(d).distance_to(lead.global_position)
			if level.room(d[side[0]]).get("outdoor", false) and not level.room(here).get("outdoor", false):
				dist += 40.0           # inside already: don't walk out and round to a back door
			if into == obj_room:
				dist += 100.0          # the objective last
			if dist < bd:
				bd = dist
				best = {"door": d, "into": into}
	if best.is_empty():
		task = {"type": "idle"}
		return
	var door: Dictionary = best["door"]
	if door["state"] != "closed":
		_set_stack(door, "open", true)
	else:
		var how := "kick" if door["locked"] else "open"
		# trained teams flash a room they know is occupied (from what they or the cameras saw)
		var lead2 = by_role("point")
		if lead2 and float(danger("open", door)["risk"]) > threshold(lead2) and alive_fighters().any(func(f) -> bool: return f.flashes > 0):
			how = "bang"
		# they never open an unknown door on their own (user 2026-11-24, C2): stack, then ask you.
		# Their suggestion (how) is offered as the first choice.
		_set_stack(door, how, false)
		task["await_call"] = true


func _set_stack(d: Dictionary, how: String, then_breach: bool) -> void:
	if d.is_empty():
		return
	var from: String = d["a"] if cleared.get(d["a"], false) or d["a"] == "hall" else d["b"]
	var into: String = d["b"] if from == d["a"] else d["a"]
	# A fluid stack: everyone takes the side of the door they're already on (nobody crosses the open
	# doorway), and on each side the closest fills the front spot, the next fills the next one. Nobody
	# reshuffles by role: if you arrive fourth, you're fourth, and you go in fourth.
	var sides := {1.0: [], -1.0: []}
	for f in alive_fighters():
		sides[level.door_side(d, from, f.global_position)].append(f)
	var stack: Array = []
	var spots: Array = []
	for s in [1.0, -1.0]:
		var group: Array = sides[s]
		group.sort_custom(func(p, q) -> bool: return p.global_position.distance_to(level.door_world(d)) < q.global_position.distance_to(level.door_world(d)))
		var ss: Array = level.stack_spots_side(d, from, s)
		for i in group.size():
			var f = group[i]
			var spot: Vector3 = ss[mini(i, 3)]
			f.set_meta("stack_i", i)
			f.go(_route(f, spot), WALK)
			f.look_at_point = null
			spots.append(spot)
	# entry order: the front of each side, alternating (a criss-cross), then the next ones
	for i in 4:
		for s in [1.0, -1.0]:
			var group: Array = sides[s]
			if i < group.size():
				stack.append(group[i])
	task = {"type": "stack", "door": d, "into": into, "from": from, "how": how, "then": then_breach, "t": 0.0, "spots": spots, "stack": stack}


func _stack_order() -> Array:
	var out: Array = []
	for r in ["point", "breacher", "medic", "rear"]:
		for f in fighters:
			if f.role == r and f.alive():
				out.append(f)
	return out


func _set_breach(d: Dictionary, how: String) -> void:
	task = {"type": "breach", "door": d, "into": task.get("into", d["b"]), "how": how, "t": 0.0, "step": 0,
		"stack": task.get("stack", _stack_order()), "wait": task.get("wait", false)}


## Who works the door: the front of the stack, or whoever carries the flash / the charge.
func _opener(how: String):
	var stack: Array = (task.get("stack", []) as Array).filter(func(f) -> bool: return f.alive())
	if stack.is_empty():
		stack = alive_fighters()
	if how == "bang":
		for f in stack.slice(0, 3):
			if f.flashes > 0:
				return f
	if how == "charge":
		for f in stack:
			if f.charges > 0:
				return f
	return stack[0] if not stack.is_empty() else null


func _set_flow(d: Dictionary, into: String, _fast: bool) -> void:
	var spots: Array = level.entry_spots(d, into)
	var order_: Array = (task.get("stack", []) as Array).filter(func(f) -> bool: return f.alive())
	if order_.is_empty():
		order_ = _stack_order()
	# whoever is furthest back holds the hall
	order_.sort_custom(func(p, q) -> bool: return p.global_position.distance_to(level.door_world(d)) < q.global_position.distance_to(level.door_world(d)))
	# the room's size decides how many go in (Operator clip 5): a closet takes one, a small room two, a big one three;
	# one always stays in the hall (the user's method) when there's anyone to spare
	var r: Rect2 = level.room(into)["rect"]
	var area := r.size.x * r.size.y
	var want := 1 if area < 6.0 else (2 if area < 14.0 else 3)
	var n := mini(want, order_.size() - 1) if order_.size() > 1 else 1
	# the first man picks how he goes in: a J-hook round the frame to his own side's corner, or straight across
	# to the far corner; the next goes opposite, the third opposite of that (deeper) (the user's method)
	var from: String = d["a"] if d["b"] == into else d["b"]
	var dp: Vector3 = level.door_world(d)
	var nrm: Vector3 = level.door_normal(d, into)
	var side0: float = level.door_side(d, from, order_[0].global_position) if not order_.is_empty() else 1.0
	var hook := rng.randf() < 0.5
	# entry_spots: 0 and 1 are the two near corners (0 on physical side -1, 1 on side +1), 2 and 3 deeper
	var own := 0 if side0 < 0.0 else 1
	var first := own if hook else 1 - own
	var plan := [spots[first], spots[1 - first], spots[2 + first], spots[3 - first]]
	if not order_.is_empty() and n > 0:
		var right := nrm.cross(Vector3.UP)
		var lr := "right" if ((plan[0] as Vector3) - dp).dot(right) > 0.0 else "left"
		order_[0].say(("Hooking %s!" if hook else "Straight in, going %s!") % lr, true)
	for i in order_.size():
		var f = order_[i]
		if i < n:
			var inside: Vector3 = dp + nrm * 0.35
			f.set_meta("flow_at", _t + ENTRY_GAP * i)
			f.set_meta("flow_path", [dp - nrm * 0.4, inside, plan[i]])
		else:
			f.look_at_point = level.door_world(d) - level.door_normal(d, into) * 6.0 + Vector3(0, 1.3, 0)
			f.remove_meta("flow_at")
	task = {"type": "flow", "door": d, "into": into, "t": 0.0, "n": n, "stack": order_}
	for k in n:
		order_[k].light_wanted = true


func _route(f, to: Vector3) -> Array:
	var a: String = level.room_near(f.global_position)
	var b: String = level.room_near(to)
	var pts: Array = []
	var rooms: Array = level.room_path(a, b)
	var cur: Vector3 = f.global_position
	var open_hop := false        # across open ground (street to yard): no door, walk the grid round the building
	for i in range(rooms.size() - 1):
		var d: Dictionary = level.door_between(rooms[i], rooms[i + 1])
		if d.is_empty():
			open_hop = true
			continue
		var n: Vector3 = level.door_normal(d, rooms[i + 1])
		var p1: Vector3 = level.door_world(d) - n * 0.4
		if open_hop:
			pts.append_array(_grid_leg(cur, p1))
			open_hop = false
		pts.append(p1)
		cur = level.door_world(d) + n * 0.5
		pts.append(cur)
	if open_hop:
		pts.append_array(_grid_leg(cur, to))
	pts.append(to)
	return pts


## The walking grid's way from a to b, without b itself.
func _grid_leg(a: Vector3, b: Vector3) -> Array:
	var p: Array = level.path(a, b)
	if p.size() > 0:
		p.pop_back()
	return p


func _door_toward(room_id: String) -> Dictionary:
	var lead = by_role("point")
	if lead == null:
		return {}
	var rooms: Array = level.room_path(level.room_at(lead.global_position), room_id)
	if rooms.size() < 2:
		return {}
	return level.door_between(rooms[0], rooms[1])


# ------------------------------------------------------------------ the tick

func tick(delta: float) -> void:
	_t += delta
	_perceive(delta)
	for f in fighters:
		if f.has_meta("shaky_until") and _t > float(f.get_meta("shaky_until")):
			f.st["react"] = float(f.st["react"]) - 0.35
			f.remove_meta("shaky_until")
	if not pending.is_empty() and not in_contact:
		var p := pending.duplicate()
		pending.clear()
		order(p["kind"], p["target"], p["who"])
	_medic(delta)
	_cuff()
	_gun_swap()
	_kneel_calls()
	_cover_tick(delta)
	_capture_check()
	match task.get("type", "idle"):
		"stack":
			_tick_stack(delta)
		"stacked":
			_face_door()
		"breach":
			_tick_breach(delta)
		"slice":
			_tick_slice(delta)
		"loot":
			_tick_loot(delta)
		"exploit":
			_tick_exploit(delta)
		"flow":
			_tick_flow(delta)
		"clear":
			_tick_clear(delta)
		"move":
			if task.has("goal") and in_contact and level.cover != null and not level.cover.spots.is_empty():
				_move_to_point(task["goal"])          # shot at on the way: bound the rest
			elif alive_fighters().all(func(f) -> bool: return not f.moving()):
				task = {"type": "hold"}
		"grab":
			_tick_grab(delta)
		"bound":
			_tick_bound(delta)
		"advance":
			_tick_advance(delta)
		"fallback":
			if alive_fighters().all(func(f) -> bool: return not f.moving()):
				task = {"type": "hold"}
	for f in fighters:
		f.tick(delta)


func _perceive(delta: float) -> void:
	var any := false
	for f in fighters:
		if not f.alive():
			continue
		var best = null
		var bd := 1e9
		var fwd := Vector3(-sin(f.face_yaw), 0, -cos(f.face_yaw))
		for e in enemies:
			if e.state != "ok" or e.ducked or e.kind == "vip":
				continue              # down behind cover: nothing to see (and the deputy is wanted alive: nobody shoots him unasked)
			var d: float = f.global_position.distance_to(e.global_position)
			if d > 24.0:
				continue
			var to: Vector3 = (e.global_position - f.global_position).normalized()
			if to.dot(fwd) < -0.2 and d > 3.0:
				continue                 # behind them: they don't have eyes back there
			# in the dark you see a few metres, unless a light is on them: yours, theirs, or the building's
			var in_beam: bool = f.light != null and f.light.visible and to.dot(fwd) > 0.96 and d < 22.0
			var their_light: bool = e.light != null and e.light.visible
			# what the cams can see, they can see: ~15 m in the dark, further when a light is on him
			if d > 15.0 and not level.data.get("daylight", false) and not in_beam and not their_light and not e.flashing() and not (level.lit(e.global_position) and d < 22.0):
				continue
			if not level.clear_line(f.eye(), e.chest_pos()):
				continue
			e.set_meta("seen_t", _t)
			e.set_meta("seen_pos", e.global_position)
			var score := d
			if e == focus_target:
				score -= 100.0
			if cover.has(f) and cover[f] is Vector3 and e.global_position.distance_to(cover[f]) < 3.0:
				score -= 50.0
			if score < bd:
				bd = score
				best = e
		if best != null and f.target == null:
			if not in_contact:
				f.bark("contact", {"room": _room_name(level.room_at(best.global_position))}, true)
			f.crouch = 0.45
		f.target = best
		if best != null:
			any = true
		elif cover.has(f) and cover[f] is Vector3:
			f.look_at_point = (cover[f] as Vector3) + Vector3(0, 1.2, 0)
	if any:
		in_contact = true
		_contact_t = 0.0
	else:
		_contact_t += delta
		if _contact_t > 2.5:
			in_contact = false
	if focus_target != null and (not is_instance_valid(focus_target) or focus_target.state != "ok"):
		focus_target = null


func _tick_stack(delta: float) -> void:
	task["t"] = float(task["t"]) + delta
	var ready := true
	for f in alive_fighters():
		if f.moving():
			ready = false
	_face_door()
	if not ready and float(task["t"]) < 14.0:
		return
	if in_contact:
		return
	if not task.get("then", false):
		task["type"] = "stacked"
		if task.get("await_call", false):
			var lead = (task["stack"] as Array)[0] if not (task["stack"] as Array).is_empty() else by_role("point")
			if lead and lead.alive():
				var sugg := {"open": "Quiet open?", "kick": "It's locked. Kick it?", "bang": "Somebody's in there. Flash it?"}.get(task.get("how", "open"), "") as String
				lead.say("At the %s. Your call. %s" % [_door_name(task["door"]).to_lower(), sugg], true)
			log_line.emit("AT THE %s: your call" % _door_name(task["door"]).to_upper())
		return
	if float(task["t"]) < BREATH + _arrive_t():
		return
	_set_breach(task["door"], task.get("how", "open"))


func _arrive_t() -> float:
	return 0.0


func _face_door() -> void:
	var d: Dictionary = task.get("door", {})
	if d.is_empty():
		return
	for f in alive_fighters():
		if f.target == null and not f.moving():
			f.look_at_point = level.door_world(d, 1.3)
			f.crouch = 0.35


func _tick_breach(delta: float) -> void:
	task["t"] = float(task["t"]) + delta
	var d: Dictionary = task["door"]
	var b = _opener(str(task["how"]))
	if b == null:
		return
	var how: String = task["how"]
	var step := int(task["step"])
	if step == 0:
		if d["state"] != "closed":
			task["step"] = 2 if how != "bang" else 1
			return
		if how == "open" and d["locked"]:
			b.bark("locked", {}, true)
			how = "kick"
			task["how"] = "kick"
		if how == "charge" and b.charges <= 0:
			how = "kick"
			task["how"] = "kick"
		var work := 0.7 if how == "kick" else (2.2 if how == "charge" else 0.9)
		if float(task["t"]) < work:
			b.busy = 0.1
			return
		if how == "kick":
			if d["locked"] and rng.randf() < 0.35:
				b.say("Solid door! Again!", true)
				task["t"] = 0.0
				enemy_ai.noise(level.door_world(d), 14.0)
				return
			level.open_door(d, "kick")
			Audio.play_at(level, "kick", level.door_world(d, 1.0), 2.0)
			enemy_ai.noise(level.door_world(d), 14.0)
		elif how == "charge":
			b.charges -= 1
			level.open_door(d, "charge")
			Audio.play_at(level, "bang", level.door_world(d, 1.0), 6.0, 0.7)
			enemy_ai.noise(level.door_world(d), 30.0)
			_stun_room(task["into"], 3.0)
		else:
			level.crack_door(d)          # crack and peek (Operator clip 2): open a hand's width, look first
			task["cracked"] = true
		b.bark("breach", {}, true)
		task["step"] = 1 if how == "bang" else 2
		task["t"] = 0.0
	elif step == 1:
		# a flash through the open door
		if b.flashes <= 0:
			task["step"] = 2
			return
		if float(task["t"]) < 0.8:
			return
		b.flashes -= 1
		b.bark("bang", {}, true)
		var c: Vector2 = (level.room(task["into"])["rect"] as Rect2).get_center()
		var at := Vector3(c.x, 1.0, c.y)
		level.flash(at)
		Audio.play_at(level, "bang", at, 4.0)
		enemy_ai.noise(at, 25.0)
		_stun_room(task["into"], 3.5)
		task["step"] = 2
		task["t"] = 0.0
	else:
		if float(task["t"]) < 0.5:
			return
		if task.get("wait", false):
			b.say("Flash is out. Holding on the door, your call.", true)
			task = {"type": "stacked", "door": d, "into": task["into"], "stack": task.get("stack", [])}
			return
		_set_slice(d, task["into"], task.get("cracked", false), task.get("stack", []))


func _stun_room(room_id: String, t: float) -> void:
	for e in enemies:
		if e.state == "ok" and level.room_at(e.global_position) == room_id:
			e.stun(t)
			enemy_ai.shaken(e, 0.5)


func _tick_flow(delta: float) -> void:
	task["t"] = float(task["t"]) + delta
	var all_in := true
	for f in alive_fighters():
		if f.has_meta("flow_at"):
			if _t >= float(f.get_meta("flow_at")):
				f.go(f.get_meta("flow_path"), WALK)
				f.look_at_point = null
				f.remove_meta("flow_at")
				f.crouch = 0.3
			else:
				all_in = false
		if f.moving() and level.room_at(f.global_position) != task["into"]:
			all_in = false
	if all_in and float(task["t"]) > 1.0:
		task = {"type": "clear", "into": task["into"], "door": task["door"], "t": 0.0}


func _tick_clear(delta: float) -> void:
	var room_id: String = task["into"]
	if level.room(room_id).get("outdoor", false):
		# out on open ground (M4): there's no clearing a street. Take cover, wait for the boss.
		cleared[room_id] = true
		task = {"type": "hold"}
		auto = false
		var by = by_role("point")
		if by:
			by.say("We're out on the road. Your call, boss." if in_contact else "Out. Road's quiet.", true)
		return
	for e in enemies:
		if e.state == "ok" and level.room_at(e.global_position) == room_id:
			task["t"] = 0.0
			# nobody of ours left inside and it's gone quiet: regroup and go again (or wait for you)
			var inside := alive_fighters().filter(func(f) -> bool: return level.room_at(f.global_position) == room_id)
			if inside.is_empty() and not in_contact:
				task["stall"] = float(task.get("stall", 0.0)) + delta
				if float(task["stall"]) > 4.0:
					var p = by_role("point")
					if p:
						p.say("They're still in there. Regrouping.", true)
					if auto:
						var b = by_role("breacher")
						_set_stack(task["door"], "bang" if b and b.flashes > 0 else "open", true)
					else:
						task = {"type": "hold"}
			return
	if in_contact:
		task["t"] = 0.0
		return
	task["t"] = float(task["t"]) + delta
	# sweep the room with the lights while it settles
	for f in alive_fighters():
		if f.target == null and not f.moving() and level.room_at(f.global_position) == room_id:
			var r: Rect2 = level.room(room_id)["rect"]
			f.look_at_point = Vector3(r.get_center().x + sin(_t * 0.6 + f.get_instance_id()) * r.size.x * 0.4, 1.2, r.get_center().y)
	if float(task["t"]) < 3.5:            # even an empty room: hold your corners a few seconds, then call it
		return
	cleared[room_id] = true
	for f in fighters:
		f.light_wanted = false        # clear: lights off
	var f0 = by_role("point")
	if f0:
		f0.bark("clear", {"room": _room_name(room_id)}, true)
		var other = by_role("rear") if by_role("rear") != f0 else by_role("medic")
		if other and other != f0:
			other.say("Room's clear, moving.", true)
	log_line.emit("%s cleared" % _room_name(room_id))
	_room_done(room_id)


## A room is clear: its PCs, then its loot crates, then the objective if it's here, then on.
func _room_done(room_id: String) -> void:
	var f0 = by_role("point")
	var obj_room: String = level.data.get("objective", {}).get("room", "")
	if room_id != obj_room and _exploit_pc(room_id):
		return
	if _loot_crate(room_id):
		return
	# the objective: pick it up
	var obj: Dictionary = level.data.get("objective", {})
	if obj.get("room", "") == room_id and not have_objective and obj.get("kind", "") != "capture":     # a capture ends when he is cuffed (_capture_check)
		task = {"type": "grab", "t": 0.0}
		var g = stick_carrier()
		if g == null:
			g = by_role("rear") if by_role("rear") and level.room_at(by_role("rear").global_position) == room_id else f0
		elif level.room_at(g.global_position) != room_id:
			if f0 and f0 != g:
				f0.say("PC in here. %s, you're up, bring the stick." % _first(g), true)
		g.go(_route(g, level.objective_pos + Vector3(0.6, 0, 0.5)), WALK)
		g.set_meta("grabbing", true)
		task["who"] = g
		return
	if auto:
		_next_doctrine()
	else:
		task = {"type": "hold"}


## Someone walks to the objective and takes it (2 seconds of hands busy).
func _tick_grab(delta: float) -> void:
	var g = task.get("who")
	if g == null or not is_instance_valid(g) or not g.alive():
		task = {"type": "hold"}
		return
	if g.moving() or in_contact:
		return
	if float(task["t"]) == 0.0:
		g.busy = 2.0
		g.crouch = 0.6
	task["t"] = float(task["t"]) + delta
	if float(task["t"]) < 2.0:
		return
	have_objective = true
	g.remove_meta("grabbing")
	var obj: Dictionary = level.data.get("objective", {})
	g.say(str(obj.get("grab_line", "Got the manifests. We're done here.")), true)
	log_line.emit(str(obj.get("grab_log", "Objective: manifests secured")))
	objective_done.emit()
	if obj.get("hold_after", false):
		task = {"type": "hold"}            # wait for the boss (the vault prompt)
	elif auto:
		_next_doctrine()
	else:
		task = {"type": "hold"}


# ------------------------------------------------------------------ care

func _medic(_delta: float) -> void:
	var m = by_role("medic")
	var patients: Array = []
	for f in fighters:
		if (f.state == "down" and not f.stable) or (f.state == "ok" and f.wounds > 0 and f.meds <= 0):
			patients.append(f)
	if task.has("medic_for") and task["medic_for"] != null and task["medic_for"] in patients:
		patients.erase(task["medic_for"])
		patients.push_front(task["medic_for"])
	if patients.is_empty():
		return
	var p = patients[0]
	var who = m if m != null and m.role == "medic" and m.meds > 0 else null
	if who == null:
		# no medic: whoever is closest with a bandage, only when it's quiet
		if in_contact:
			return
		var bd := 1e9
		for f in alive_fighters():
			if f != p and f.meds > 0:
				var d: float = f.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					who = f
	if who == null or who.busy > 0.0:
		return
	var dist: float = who.global_position.distance_to(p.global_position)
	if dist > 0.9:
		if in_contact and p.state == "down" and task.get("medic_for") != p and dist > 3.0:
			return                # wait for the shooting to stop, unless you ordered it
		if not who.moving() or not who.has_meta("patient") or who.get_meta("patient") != p:
			who.set_meta("patient", p)
			who.go(_route(who, p.global_position + (who.global_position - p.global_position).normalized() * 0.6), RUN if p.state == "down" else WALK)
		return
	who.stop()
	who.busy = 4.0 if who.role == "medic" else 6.0
	var item: String = who.use_med()
	who.crouch = 0.9
	var part: String = p.wound_parts[0] if not p.wound_parts.is_empty() else "torso"
	var part_word: String = p.part_name(part)
	# the medic calls it, so you hear your handmade dressing being used (C4; GPT notes)
	who.say("%s on %s's %s. Stay with me." % [(item.substr(0, 1).to_upper() + item.substr(1)) if item.begins_with("your") else "Dressing", _first(p), part_word], true)
	p.get_patched(_first(who), item)
	if who.has_meta("patient"):
		who.remove_meta("patient")
	log_line.emit("%s used %s on %s's %s" % [_first(who), item, _first(p), part_word])


## Anyone who gave up gets zip-tied by the nearest fighter when it's quiet.
func _cuff() -> void:
	if in_contact:
		return
	for e in enemies:
		if e.state != "surrendered":
			continue
		if not e.has_meta("shouted"):
			var near = null
			var bd := 1e9
			for f in alive_fighters():
				var d: float = f.global_position.distance_to(e.global_position)
				if d < bd:
					bd = d
					near = f
			if near:
				near.bark("surrender", {}, true)
			e.set_meta("shouted", true)
		if e.has_meta("cuffer"):
			var c = e.get_meta("cuffer")
			if not is_instance_valid(c) or not c.alive():
				e.remove_meta("cuffer")
			elif e.has_meta("cuff_until"):
				if _t >= float(e.get_meta("cuff_until")):         # cuffing takes a while (user 2026-11-26)
					e.state = "cuffed"
					e.pose_mode = "down"
					cuffs -= 1
					log_line.emit("%s zip-tied" % e.fighter_name)
					e.remove_meta("cuffer")
					e.remove_meta("cuff_until")
			elif not c.moving() and c.busy <= 0.0:
				if c.global_position.distance_to(e.global_position) < 1.0:
					c.busy = CUFF_S + 0.2
					c.crouch = 0.8
					e.set_meta("cuff_until", _t + CUFF_S)
			continue
		if cuffs <= 0:
			if not e.has_meta("nocuff"):
				e.set_meta("nocuff", true)
				var anyone = alive_fighters()[0] if not alive_fighters().is_empty() else null
				if anyone:
					anyone.say("No cuffs left. Stay on the floor!", true)
				log_line.emit("No zip cuffs left: %s stays on the floor" % e.fighter_name)
			continue
		var best = null
		var bd2 := 1e9
		for f in alive_fighters():
			if f.role == "medic" or (f.has_meta("grabbing") and task.get("type") == "grab"):
				continue
			var d: float = f.global_position.distance_to(e.global_position)
			if d < bd2 and level.clear_line(f.eye(), e.chest_pos()):
				bd2 = d
				best = f
		if best and bd2 < 9.0:
			e.set_meta("cuffer", best)
			best.go(_route(best, e.global_position + (best.global_position - e.global_position).normalized() * 0.7), WALK)


## Out of ammo (docs/DEPOT_SLICE.md section 8): a dry fighter shouts and takes a downed guard's SMG or
## carbine, with only a few rounds in it. Risky if a guard was missed. HOLD stops it.
const SWAP_GUNS := {"smg": "guard_smg", "carbine": "bureau_carbine"}
const SWAP_RANGE := 12.0


func _gun_swap() -> void:
	var holding: bool = task.get("type", "") == "hold"
	for f in alive_fighters():
		if f.has_meta("swap_to"):
			var e = f.get_meta("swap_to")
			if holding or not is_instance_valid(e) or e.has_meta("stripped"):
				f.remove_meta("swap_to")
				if holding:
					f.stop()
				continue
			if f.moving() or f.busy > 0.0:
				continue
			if f.global_position.distance_to(e.global_position) > 1.1:
				f.go(_route(f, e.global_position), RUN)
				continue
			_take_gun(f, e)
			continue
		if holding or f.mags > 0 or f.mag_rounds > 0 or f.reloading > 0.0 or f.busy > 0.0 or f.has_meta("patient") or f.has_meta("swapped"):
			continue
		var best = null
		var bd := SWAP_RANGE
		for e in enemies:
			if not (e.state in ["dead", "down", "cuffed"]) or e.has_meta("stripped") or e.has_meta("swap_claimed"):
				continue
			var wid: String = (e.get_meta("def", {}) as Dictionary).get("gear", {}).get("weapon", "")
			if not SWAP_GUNS.has(wid):
				continue
			var d: float = f.global_position.distance_to(e.global_position)
			if d < bd and level.clear_line(f.eye(), e.chest_pos()):
				bd = d
				best = e
		if best == null:
			continue
		best.set_meta("swap_claimed", true)
		f.set_meta("swap_to", best)
		f.say("I'm dry! Taking his!", true)
		log_line.emit("%s is dry, going for a guard's gun" % _first(f))
		f.go(_route(f, best.global_position), RUN)


func _take_gun(f, e) -> void:
	var wid: String = (e.get_meta("def", {}) as Dictionary).get("gear", {}).get("weapon", "smg")
	var ws := Rules.stats({"weapon": wid, "round": "fmj"}, f.trait_name)
	for k in ["weapon", "round", "acc", "dmg", "pen", "armor_dmg", "burst", "rate", "recoil", "mag", "reload", "ads", "jam", "falloff"]:
		f.st[k] = ws[k]
	f.mag_rounds = rng.randi_range(5, 14)       # what was left in it
	f.mags = 0
	f.has_light = false
	f.busy = 1.5
	f.crouch = 0.8
	f.set_weapon_mesh("Gear_Rifle")
	f.set_meta("swapped", SWAP_GUNS[wid])
	f.remove_meta("swap_to")
	e.set_meta("stripped", true)
	f.say("Got it. %d rounds, make them count." % f.mag_rounds, true)
	log_line.emit("%s took a %s (%d rounds)" % [_first(f), str(ws["weapon"]).to_lower(), f.mag_rounds])


func _first(a) -> String:
	if a == null or not is_instance_valid(a):
		return "them"
	return str(a.fighter_name).split(" ")[0].capitalize()


func _door_name(d) -> String:
	return str(d.get("name", "the door")).to_lower() if d is Dictionary else "the door"


func _room_name(id: String) -> String:
	var r: Dictionary = level.room(id)
	return str(r.get("name", id)).to_lower() if not r.is_empty() else id


# ------------------------------------------------------------------ the doctrine pass (C3)
# The user's method (army-taught) and his Operator clip: crack and peek, slice the pie from the threshold, fight
# from the frame on contact, then flow; kneel to reload and a teammate calls you up; exploit every PC.

const SLICE_T := 2.0               # how long the front two work the angles from the doorway
const SLICE_GIVE_UP := 12.0        # contact that long without a shot: go in anyway


## The door is open (or cracked): the front of each side works the room from the threshold before anyone crosses.
func _set_slice(d: Dictionary, into: String, cracked: bool, stack: Array) -> void:
	var st: Array = stack.filter(func(f) -> bool: return f.alive())
	if st.is_empty():
		st = _stack_order()
	var from: String = d["a"] if d["b"] == into else d["b"]
	var lookers: Array = []
	for s in [1.0, -1.0]:
		for f in st:
			if level.door_side(d, from, f.global_position) == s:
				lookers.append(f)
				break
	for f in lookers:
		f.light_wanted = true
		f.crouch = 0.3
	if cracked and not lookers.is_empty():
		lookers[0].say("Peeking.", true)
	task = {"type": "slice", "door": d, "into": into, "stack": st, "lookers": lookers, "t": 0.0, "cracked": cracked,
		"quiet": 0.0, "contact": false}


func _tick_slice(delta: float) -> void:
	task["t"] = float(task["t"]) + delta
	var d: Dictionary = task["door"]
	var into: String = task["into"]
	var r: Rect2 = level.room(into)["rect"]
	var dp: Vector3 = level.door_world(d)
	var nrm: Vector3 = level.door_normal(d, into)
	var tan := Vector3(nrm.z, 0, -nrm.x)
	var from: String = d["a"] if d["b"] == into else d["b"]
	# each looker sweeps from the far side's corner across to his own side (slicing the pie)
	var k := clampf(float(task["t"]) / SLICE_T, 0.0, 1.0)
	for f in task["lookers"]:
		if not f.alive() or f.target != null:
			continue
		var s: float = level.door_side(d, from, f.global_position)
		var far := maxf(r.size.x, r.size.y)
		var aim: Vector3 = dp + nrm * far * 0.7 + tan * (-s) * lerpf(1.6, -1.2, k) * (-1.0)
		aim.x = clampf(aim.x, r.position.x + 0.3, r.end.x - 0.3)
		aim.z = clampf(aim.z, r.position.y + 0.3, r.end.y - 0.3)
		f.look_at_point = Vector3(aim.x, 1.25, aim.z)
	# contact from the doorway: hold the frame and fight, don't flow (Operator clip 4)
	var seen_inside := false
	for e in enemies:
		if e.state == "ok" and level.room_at(e.global_position) == into:
			for f in task["lookers"]:
				if f.alive() and level.clear_line(f.eye(), e.chest_pos()):
					seen_inside = true
	if seen_inside or in_contact:
		if not task["contact"]:
			task["contact"] = true
			var l0 = (task["lookers"] as Array)[0] if not (task["lookers"] as Array).is_empty() else null
			if l0 and l0.alive():
				l0.say("Contact in there! Holding the door!", true)
			log_line.emit("Contact at the %s: fighting from the frame" % _door_name(d))
		task["quiet"] = 0.0
		if float(task["t"]) < SLICE_GIVE_UP:
			return
	else:
		task["quiet"] = float(task["quiet"]) + delta
	if float(task["t"]) < SLICE_T or (task["contact"] and float(task["quiet"]) < 1.5):
		return
	if task.get("cracked", false):
		level.finish_open(d)
	# small rooms are cleared from the door: one look does it (Operator clip 5)
	if r.size.x * r.size.y < 6.0:
		var l1 = (task["lookers"] as Array)[0] if not (task["lookers"] as Array).is_empty() else null
		if l1 and l1.alive():
			l1.say("Small room. Clear from here.", true)
		task = {"type": "clear", "into": into, "door": d, "t": 2.5}
		return
	_set_flow(d, into, false)


## Kneel to reload; once the mag's in they stay down until a teammate calls them up, since only someone
## looking around knows whether standing puts them in a line of fire (the user's method).
func _kneel_calls() -> void:
	for f in alive_fighters():
		if f.reloading > 0.0 and not f.moving() and not f.has_meta("kneel"):
			f.set_meta("kneel", true)
		if not f.has_meta("kneel"):
			continue
		if f.moving():
			f.remove_meta("kneel")              # ordered to move: they get up and go
			f.kneel_want = 0.0
			continue
		f.kneel_want = 1.0
		f.crouch = 0.6
		if f.reloading > 0.0 or in_contact:
			continue
		for g in alive_fighters():
			if g != f and g.global_position.distance_to(f.global_position) < 6.0 and g.target == null:
				g.say("%s, up! You're good." % _first(f), true)
				f.remove_meta("kneel")
				f.kneel_want = 0.0
				f.crouch = 0.3
				break


## After a room is cleared: any PC in it gets exploited (the user: take all data and intel, room by room).
## Returns true if someone went to a PC (the task is now "exploit").
func _exploit_pc(room_id: String) -> bool:
	for pc in level.pcs:
		if pc["done"] or pc["room"] != room_id:
			continue
		var g = stick_carrier()
		if g == null or level.room_near(g.global_position) != room_id:
			var best = null
			var bd := 1e9
			for f in alive_fighters():
				var dd: float = f.global_position.distance_to(pc["stand"])
				if dd < bd:
					bd = dd
					best = f
			g = best
		if g == null:
			return false
		g.say("PC in here. Pulling what's on it.", true)
		g.go(_route(g, pc["stand"]), WALK)
		task = {"type": "exploit", "pc": pc, "who": g, "t": 0.0, "into": room_id}
		return true
	return false


func _tick_exploit(delta: float) -> void:
	var g = task.get("who")
	var pc: Dictionary = task["pc"]
	if g == null or not is_instance_valid(g) or not g.alive():
		task = {"type": "hold"}
		return
	if g.moving() or in_contact:
		return
	g.look_at_point = pc["screen"]
	g.busy = 0.2
	task["t"] = float(task["t"]) + delta
	var need := 6.0 - 2.0 * clampf(float(g.get_meta("tech", 1)) / 5.0, 0.0, 1.0)
	if float(task["t"]) < need:
		return
	pc["done"] = true
	var pc_name := "%s PC" % _room_name(pc["room"]).capitalize()
	if pc_files.has(pc_name):
		pc_name += " %d" % (pc_files.filter(func(x) -> bool: return str(x).begins_with(pc_name)).size() + 1)
	pc_files.append(pc_name)
	g.say("Got it. Files are on the stick.", true)
	log_line.emit("Pulled the files off the %s PC" % _room_name(pc["room"]))
	_room_done(str(task["into"]))


# ------------------------------------------------------------------ loot crates (M4 V4)

var cuffs := 99                     # zip cuffs the crew carries (the fight sets it from the stash); 0 = can't cuff
const CUFF_S := 6.0                 # seconds to cuff someone: that fighter is out of the fight meanwhile


## A crate in this cleared room: the nearest fighter with room in their rig goes and takes it (it takes a few
## seconds, hands busy, paused while there's shooting). Returns true if someone went.
func _loot_crate(room_id: String) -> bool:
	for c in level.loots:
		if c["done"] or c.get("left", false) or c["room"] != room_id:
			continue
		var best = null
		var bd := 1e9
		for f in alive_fighters():
			if int(f.get_meta("carry", 99)) < int(c["cells"]):
				continue
			var dd: float = f.global_position.distance_to(c["pos"])
			if dd < bd:
				bd = dd
				best = f
		if best == null:
			c["left"] = true
			var anyone = alive_fighters()[0] if not alive_fighters().is_empty() else null
			if anyone:
				anyone.say("There's %s here. No room in our rigs. Leaving it." % c["label"], true)
			log_line.emit("Left %s behind: no room to carry it" % c["label"])
			continue
		best.say("%s in here. Grabbing it." % str(c["label"]).capitalize(), true)
		var to: Vector3 = c["pos"] + (best.global_position - c["pos"]).normalized() * 0.7
		best.go(_route(best, to), WALK)
		task = {"type": "loot", "crate": c, "who": best, "t": 0.0, "into": room_id}
		return true
	return false


func _tick_loot(delta: float) -> void:
	var g = task.get("who")
	var c: Dictionary = task["crate"]
	if g == null or not is_instance_valid(g) or not g.alive():
		task = {"type": "hold"}
		return
	if g.moving() or in_contact:
		return
	g.look_at_point = c["pos"] + Vector3(0, 0.3, 0)
	g.busy = 0.2
	g.crouch = 0.7
	task["t"] = float(task["t"]) + delta
	if float(task["t"]) < 3.0 + 1.0 * int(c["cells"]):
		return
	c["done"] = true
	c["by"] = g
	g.set_meta("carry", int(g.get_meta("carry", 99)) - int(c["cells"]))
	var held: Array = g.get_meta("crates", [])
	held.append(c)
	g.set_meta("crates", held)
	if is_instance_valid(c.get("node")):
		(c["node"] as Node3D).visible = false
	g.say("Got %s." % c["label"], true)
	log_line.emit("%s took %s" % [_first(g), c["label"]])
	_room_done(str(task["into"]))


# ------------------------------------------------------------------ leaving: bounding overwatch (C5)
# They don't walk backwards out of a building (the user's method): the crew splits in two; one half covers back the
# way they came while the other moves a few metres past them, calls "Set!", and then they swap. Anyone down is
# carried by the nearest healthy one (slow, no gun). At the van: exfil_done.

const BOUND_LEG := 3.5


func bound_out(abort: bool) -> void:
	# the route out starts from whoever is deepest in the building
	var lead = null
	var far := -1.0
	for a in alive_fighters():
		var dd: float = a.global_position.distance_to(start_pos)
		if dd > far:
			far = dd
			lead = a
	if lead == null:
		return
	var pts: Array = [lead.global_position]
	pts.append_array(_route(lead, start_pos))
	var healthy: Array = fighters.filter(func(f) -> bool: return f.state == "ok")
	healthy.sort_custom(func(p, q) -> bool: return p.global_position.distance_to(start_pos) < q.global_position.distance_to(start_pos))
	var carriers := {}
	for d in fighters:
		if d.state != "down":
			continue
		var best = null
		var bd := 1e9
		for h in healthy:
			if carriers.values().has(h):
				continue
			var dd: float = h.global_position.distance_to(d.global_position)
			if dd < bd:
				bd = dd
				best = h
		if best != null:
			carriers[d] = best
			best.say("I've got %s! Moving!" % _first(d), true)
			best.go(_route(best, d.global_position), RUN)
	var groups := [[], []]
	var k := 0
	for h in healthy:
		if carriers.values().has(h):
			continue
		groups[k % 2].append(h)
		k += 1
	task = {"type": "bound", "path": pts, "groups": groups, "mover": 0, "s": [0.0, 0.0], "carriers": carriers, "abort": abort,
		"picked": {}, "t": 0.0}
	if not groups[0].is_empty():
		groups[0][0].say("Bounding out. Moving!", true)
	log_line.emit("Leaving: bounding back to the van" + (" (abort)" if abort else ""))


func _path_len(pts: Array) -> float:
	var l := 0.0
	for i in range(pts.size() - 1):
		l += (pts[i] as Vector3).distance_to(pts[i + 1])
	return l


func _point_at(pts: Array, s: float) -> Vector3:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := a.distance_to(b)
		if s <= seg or i == pts.size() - 2:
			return a.lerp(b, clampf(s / maxf(seg, 0.001), 0.0, 1.0))
		s -= seg
	return pts[-1]


func _tick_bound(delta: float) -> void:
	task["t"] = float(task["t"]) + delta
	var pts: Array = task["path"]
	var total := _path_len(pts)
	var groups: Array = task["groups"]
	for g in groups:
		g.assign((g as Array).filter(func(f) -> bool: return f.state == "ok"))
	# carriers: pick up, then walk the whole way slowly; the downed come along
	var carriers: Dictionary = task["carriers"]
	var all_home := true
	for d in carriers.keys():
		var c = carriers[d]
		if not is_instance_valid(c) or c.state != "ok":
			continue
		if not task["picked"].has(d):
			if c.global_position.distance_to(d.global_position) < 1.0:
				task["picked"][d] = true
				c.go(_route(c, start_pos), WALK * 0.75)
				c.weapons_free = false
			all_home = false
			continue
		d.global_position = c.global_position + c.global_basis.z * 0.45      # dragged along behind them
		d.rotation.y = c.rotation.y
		if c.global_position.distance_to(start_pos) > 1.6:
			all_home = false
			if not c.moving():
				c.go(_route(c, start_pos + Vector3(randf_range(-0.4, 0.4), 0, 0.3)), WALK * 0.75)     # blocked: try again
	var mover: int = task["mover"]
	var cover: int = 1 - mover
	if groups[0].is_empty() and groups[1].is_empty():
		pass
	elif (groups[mover] as Array).is_empty():
		task["mover"] = cover
	else:
		var moving_now: Array = groups[mover]
		var s: Array = task["s"]
		var target_s := minf(total, float(s[cover]) + BOUND_LEG) if not (groups[cover] as Array).is_empty() else total
		if float(s[mover]) < target_s - 0.01:
			s[mover] = target_s
			var p := _point_at(pts, target_s)
			var nxt := _point_at(pts, minf(total, target_s + 0.5))
			var side := (nxt - p).normalized().cross(Vector3.UP)
			for i in moving_now.size():
				moving_now[i].go(_route(moving_now[i], p + side * (float(i) - 0.5 * (moving_now.size() - 1)) * 0.8), RUN * 0.8)
				moving_now[i].crouch = 0.3
		elif moving_now.all(func(f) -> bool: return not f.moving()):
			# set: the other half moves now (past them, or the last leg to the van)
			if not (groups[cover] as Array).is_empty() and float(s[cover]) < total - 0.05:
				moving_now[0].say("Set!", true)
				groups[cover][0].say("Moving!", true)
				task["mover"] = cover
			elif float(s[mover]) < total - 0.05:
				s[mover] = float(s[mover]) - 0.02     # nobody to cover: just keep going
			for x in moving_now:
				if x.global_position.distance_to(_point_at(pts, float(s[mover]))) > 1.5 and not x.moving():
					x.go(_route(x, _point_at(pts, float(s[mover]))), RUN * 0.8)
		# the covering half watches back the way they came
		var back := _point_at(pts, maxf(0.0, float(s[cover]) - 6.0)) + Vector3(0, 1.3, 0)
		for f in groups[cover]:
			if f.target == null and not f.moving():
				f.look_at_point = back
				f.crouch = 0.55
	for g in groups:
		for f in g:
			if f.global_position.distance_to(start_pos) > 2.2:
				all_home = false
	if all_home and float(task["t"]) > 1.0:
		for c in carriers.values():
			if is_instance_valid(c):
				c.weapons_free = true
		task = {"type": "done", "abort": task["abort"]}
		exfil_done.emit()


# ------------------------------------------------------------------ cover and bounding anywhere (M4 V1)
# The usual fire-and-move: in contact, anyone not busy with the doctrine gets the nearest cover with the
# object between them and the shooter, peeks to shoot, ducks to reload or when rounds keep snapping past.
# A MOVE to a point under fire becomes bounding: one half runs to the next cover forward while the other
# half shoots; then "Set!" and they swap. Out of contact it's a plain walk round the cover.

const FREE_TASKS := ["idle", "hold", "move", "done", "advance"]


## Where the shooting comes from for this fighter: their target, else the nearest enemy seen lately.
func _threat_for(f) -> Variant:
	if f.target != null and is_instance_valid(f.target) and f.target.alive():
		return f.target.global_position
	var best = null
	var bd := 1e9
	for e in enemies:
		if e.state != "ok" or not e.has_meta("seen_t") or _t - float(e.get_meta("seen_t")) > 8.0:
			continue
		var p: Vector3 = e.get_meta("seen_pos")
		var d: float = p.distance_to(f.global_position)
		if d < bd and d < 30.0:
			bd = d
			best = p
	return best


func _cover_tick(delta: float) -> void:
	var cv = level.cover
	if cv == null or cv.spots.is_empty():
		return
	var tt: String = task.get("type", "idle")
	for f in alive_fighters():
		if f.busy > 0.0 or f.stunned > 0.0:
			f.ducked = false
			continue
		var threat = _threat_for(f)
		if threat == null or not tt in FREE_TASKS:
			f.ducked = false
			if threat == null and cv.spot_of(f).size() > 0 and not in_contact:
				cv.release(f)
			continue
		if tt == "advance" and _moving_group().has(f):
			f.ducked = false
			continue
		if f.moving():
			continue
		var s: Dictionary = cv.spot_of(f)
		if s.is_empty() or not cv.good_against(s, threat) or (s["pos"] as Vector3).distance_to(f.global_position) > 0.6:
			var reach := 2.5 if tt == "hold" else 7.0
			var ns: Dictionary = cv.best(f, threat, reach)
			if not ns.is_empty() and (ns["pos"] as Vector3).distance_to(f.global_position) > 0.3:
				cv.claim(ns, f)
				f.ducked = false
				f.go(level.path(f.global_position, ns["pos"]), RUN)
				if rng.randf() < 0.5:
					f.say(["Getting to cover!", "Cover!", "Moving to cover!"][rng.randi() % 3])
				continue
		_peek_or_duck(f, delta)


## Ours are better at it than theirs: short ducks, quick peeks back up.
func _peek_or_duck(f, delta: float) -> void:
	var t := float(f.get_meta("duck_t", 0.0)) - delta
	if f.ducked:
		if t <= 0.0 and f.reloading <= 0.0 and f.suppress < 0.55:
			f.ducked = false
			f.preaim = (float(f.st["ads"]) + float(f.st.get("react", 0.5))) * 0.7
			f.crouch = 0.6
			t = 0.0
	elif f.reloading > 0.0 or (f.suppress > 0.8 and t <= 0.0):
		f.ducked = true
		t = rng.randf_range(0.8, 1.6)
	else:
		f.crouch = 0.6 if f.target != null else 0.8
	f.set_meta("duck_t", t)


func _move_to_point(p: Vector3) -> void:
	# a shut door in the way: stack on it first (they never open one alone)
	var lead = by_role("point")
	if lead and level.path(lead.global_position, p).is_empty():
		var rooms: Array = level.room_path(level.room_near(lead.global_position), level.room_near(p))
		for i in range(rooms.size() - 1):
			var d: Dictionary = level.door_between(rooms[i], rooms[i + 1])
			if not d.is_empty() and d["state"] == "closed":
				lead.say("Door's shut on the way. Stacking on it.", true)
				_set_stack(d, "", false)
				return
	if level.cover != null and not level.cover.spots.is_empty() and in_contact:
		var fs := alive_fighters()
		var groups: Array = [[], []]
		for i in fs.size():
			groups[i % 2].append(fs[i])
		task = {"type": "advance", "goal": p, "mover": 0, "groups": groups, "t": 0.0, "legs": 0}
		groups[0][0].say("Bounding! Cover me!", true)
		if groups[1].size() > 0:
			groups[1][0].say("Covering!", true)
		_send_movers()
		return
	var k := 0
	for f in alive_fighters():
		if level.cover:
			level.cover.release(f)
		f.ducked = false
		var at := p + Vector3((k % 2) * 0.9 - 0.45, 0, int(k / 2) * 0.9 - 0.45)
		f.go(level.path(f.global_position, at), WALK)
		k += 1
	task = {"type": "move", "room": level.room_near(p), "goal": p}
	_ack("push", {"room": _room_name(level.room_near(p))})


func _moving_group() -> Array:
	if task.get("type") != "advance":
		return []
	return task["groups"][int(task["mover"])]


## The movers each take the next cover forward (or the goal itself once it's close).
func _send_movers() -> void:
	var goal: Vector3 = task["goal"]
	var cv = level.cover
	var k := 0
	for f in _moving_group():
		if not f.alive():
			continue
		f.ducked = false
		var threat = _threat_for(f)
		var s: Dictionary = {} if threat == null else cv.best(f, threat, 9.0, goal)
		var to: Vector3
		if s.is_empty() or f.global_position.distance_to(goal) < 4.0:
			to = goal + Vector3((k % 2) * 0.9 - 0.45, 0, int(k / 2) * 0.9 - 0.45)
			cv.release(f)
		else:
			cv.claim(s, f)
			to = s["pos"]
		f.go(level.path(f.global_position, to), RUN)
		k += 1


func _tick_advance(delta: float) -> void:
	task["t"] = float(task["t"]) + delta
	var goal: Vector3 = task["goal"]
	var movers: Array = _moving_group().filter(func(f) -> bool: return f.alive())
	# out of contact for a while: just walk the rest
	if not in_contact:
		_move_to_point(goal)
		return
	if movers.is_empty() or movers.all(func(f) -> bool: return not f.moving()):
		var all_there := alive_fighters().all(func(f) -> bool: return f.global_position.distance_to(goal) < 3.0)
		if all_there or int(task["legs"]) > 12:
			task = {"type": "hold"}
			if not alive_fighters().is_empty():
				alive_fighters()[0].say("We're there. Holding.", true)
			return
		if not movers.is_empty():
			movers[0].say("Set!", true)
		task["mover"] = 1 - int(task["mover"])
		task["legs"] = int(task["legs"]) + 1
		var nxt: Array = _moving_group().filter(func(f) -> bool: return f.alive())
		if nxt.is_empty():
			task["mover"] = 1 - int(task["mover"])
		elif not nxt.is_empty():
			nxt[0].say("Moving!", true)
		_send_movers()


# ------------------------------------------------------------------ a capture objective (M4 V2: the deputy)

var vip_outcome := ""              # "taken" or "dead" once it's settled


func _capture_check() -> void:
	var obj: Dictionary = level.data.get("objective", {})
	if obj.get("kind", "") != "capture" or have_objective:
		return
	for e in enemies:
		if e.id != str(obj.get("who", "")):
			continue
		if e.state == "cuffed":
			vip_outcome = "taken"
			log_line.emit("%s zip-tied. We have him." % e.fighter_name)
		elif e.state == "dead" or e.state == "down":
			vip_outcome = "dead"
			log_line.emit("%s is down. That's the job, one way or another." % e.fighter_name)
		else:
			return
		have_objective = true
		objective_done.emit()
		var by = alive_fighters()[0] if not alive_fighters().is_empty() else null
		if by:
			by.say("Got him! We're leaving!" if vip_outcome == "taken" else "He's done. Let's go!", true)
		bound_out(false)
		return
