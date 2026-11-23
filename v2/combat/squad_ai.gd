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
	elif kind in RISKY and not skip_check:
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
			auto = false
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
			task = {"type": "fallback"}
			for f in alive_fighters():
				f.go(_route(f, start_pos + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(0.0, 1.0))), RUN)
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
		task = {"type": "exfil"}
		for f in alive_fighters():
			f.go(_route(f, start_pos + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(0.0, 1.0))), WALK)
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
		_set_stack(door, how, true)


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
	var n := mini(order_.size(), 3)               # the rear man holds the hall
	for i in order_.size():
		var f = order_[i]
		if i < n:
			var inside: Vector3 = level.door_world(d) + level.door_normal(d, into) * 0.35
			f.set_meta("flow_at", _t + ENTRY_GAP * i)
			f.set_meta("flow_path", [level.door_world(d) - level.door_normal(d, into) * 0.4, inside, spots[i]])
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
	for i in range(rooms.size() - 1):
		var d: Dictionary = level.door_between(rooms[i], rooms[i + 1])
		if not d.is_empty():
			var n: Vector3 = level.door_normal(d, rooms[i + 1])
			pts.append(level.door_world(d) - n * 0.4)
			pts.append(level.door_world(d) + n * 0.5)
	pts.append(to)
	return pts


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
	match task.get("type", "idle"):
		"stack":
			_tick_stack(delta)
		"stacked":
			_face_door()
		"breach":
			_tick_breach(delta)
		"flow":
			_tick_flow(delta)
		"clear":
			_tick_clear(delta)
		"move":
			if alive_fighters().all(func(f) -> bool: return not f.moving()):
				task = {"type": "hold"}
		"grab":
			_tick_grab(delta)
		"exfil":
			if alive_fighters().all(func(f) -> bool: return not f.moving()):
				task = {"type": "done"}
				exfil_done.emit()
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
			if e.state != "ok":
				continue
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
			if d > 15.0 and not in_beam and not their_light and not e.flashing() and not (level.lit(e.global_position) and d < 22.0):
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
			level.open_door(d, "open")
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
		_set_flow(d, task["into"], false)


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
	# the objective: pick it up
	var obj: Dictionary = level.data.get("objective", {})
	if obj.get("room", "") == room_id and not have_objective:
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
	who.meds -= 1
	who.crouch = 0.9
	who.say("Got you, got you. Stay with me.", true)
	p.get_patched()
	if who.has_meta("patient"):
		who.remove_meta("patient")
	log_line.emit("%s patched %s" % [_first(who), _first(p)])


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
			elif not c.moving() and c.busy <= 0.0:
				if c.global_position.distance_to(e.global_position) < 1.0:
					c.busy = 2.5
					c.crouch = 0.8
					e.state = "cuffed"
					e.pose_mode = "down"
					log_line.emit("%s zip-tied" % e.fighter_name)
					e.remove_meta("cuffer")
			continue
		var best = null
		var bd2 := 1e9
		for f in alive_fighters():
			if f.role == "medic" or f.has_meta("grabbing"):
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
