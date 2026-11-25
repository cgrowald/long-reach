extends RefCounted
## The other side (docs/COMBAT_SLICE.md section 8): guards sit, patrol, notice you (lights give you away in
## the dark), hear shots and kicked doors, fight back. Their nerve breaks: a guard may run or give up.
## Bureau escorts never surrender and hunt you instead.

const SIGHT := 20.0
const SIGHT_DAY := 30.0          # outside in daylight (M4)
const LINES := {
	"alert": ["Who's there?", "Hey! HEY!", "Somebody's in the building!"],
	"bureau_alert": ["Bureau! Drop your weapons!", "Contact! Hold them here!"],
	"surrender": ["Don't shoot! I give up!", "Okay! Okay! I'm down!", "Please, I've got kids!"],
	"flee": ["I'm out, I'm out!", "Not paid enough for this!"],
}

var enemies: Array = []
var fighters: Array = []
var level: Node3D
var rng := RandomNumberGenerator.new()
var noises: Array = []          # {pos, r}
var _t := 0.0
var us_fired_t := -100.0         # when one of ours last fired (M4 V1: they never push into live fire)
var advancing = null              # the one enemy moving up right now (they bound one at a time)


func setup(p_enemies: Array, p_fighters: Array, p_level: Node3D) -> void:
	enemies = p_enemies
	fighters = p_fighters
	level = p_level
	rng.seed = 99
	for e in enemies:
		var d: Dictionary = e.get_meta("def")
		e.set_meta("ai", {"mode": d.get("state", "idle"), "morale": 1.0 if e.kind == "bureau" else (0.55 if d.get("timid", false) else 0.85),
			"react": 0.0, "patrol": d.get("patrol", []), "pi": 0, "last_seen": null, "lost": 0.0, "home": e.global_position})
		if d.get("state", "idle") == "idle":
			e.crouch = 0.0
			e.raised = 0.0


## Something loud happened: shots, a kicked door, a bang. Enemies in earshot wake up.
func noise(at: Vector3, radius: float) -> void:
	noises.append({"pos": at, "r": radius})


func tick(delta: float) -> void:
	_t += delta
	for f in fighters:
		if f.shots != int(f.get_meta("seen_shots", 0)):
			f.set_meta("seen_shots", f.shots)
			us_fired_t = _t
	if advancing != null and (not is_instance_valid(advancing) or advancing.state != "ok" or not advancing.moving()):
		advancing = null
	for e in enemies:
		if e.state != "ok":
			continue
		var ai: Dictionary = e.get_meta("ai")
		if e.kind == "vip":
			_vip(e, ai, delta)
			e.tick(delta)
			continue
		# hear
		for n in noises:
			var heard_r: float = float(n["r"])
			if not level.clear_line(e.eye(), (n["pos"] as Vector3) + Vector3(0, 1.2, 0)):
				heard_r *= 0.5          # through a wall
			if e.global_position.distance_to(n["pos"]) < heard_r and ai["mode"] in ["idle", "patrol"]:
				ai["mode"] = "alert"
				ai["last_seen"] = n["pos"]
				e.bark_custom(_line("bureau_alert" if e.kind == "bureau" else "alert"))
		# see
		var seen = _spot(e, ai)
		if seen != null:
			ai["last_seen"] = seen.global_position
			ai["lost"] = 0.0
			if ai["mode"] in ["idle", "patrol", "alert"]:
				ai["mode"] = "react"
				ai["react"] = rng.randf_range(0.5, 1.1) if ai["mode"] != "alert" else 0.25
			if ai["mode"] == "react":
				ai["react"] = float(ai["react"]) - delta
				e.look_at_point = seen.chest_pos()
				if float(ai["react"]) <= 0.0:
					ai["mode"] = "combat"
			if ai["mode"] == "combat":
				e.target = seen
				if not _has_cover():
					e.crouch = 0.45
					e.stop()
		else:
			e.target = null
			if ai["mode"] == "combat":
				ai["lost"] = float(ai["lost"]) + delta
				e.look_at_point = (ai["last_seen"] as Vector3) + Vector3(0, 1.2, 0) if ai["last_seen"] != null else null
				if e.kind == "bureau" and float(ai["lost"]) > 3.0 and quiet() > 4.0 and not e.moving() and ai["last_seen"] != null and not _has_cover():
					e.go(_route(e, ai["last_seen"]), e.WALK)        # hunt
		if _has_cover() and ai["mode"] in ["combat", "alert"]:
			_cover_fight(e, ai, delta, seen)
		match ai["mode"]:
			"patrol":
				_patrol(e, ai)
			"alert":
				e.raised = 1.0
				e.crouch = 0.35
				if ai["last_seen"] != null:
					e.look_at_point = (ai["last_seen"] as Vector3) + Vector3(0, 1.2, 0)
			"flee":
				if not e.moving():
					e.state = "fled"
					e.crouch = 0.9
		e.light_wanted = ai["mode"] in ["alert", "react", "combat"]
		_nerve(e, ai)
		e.tick(delta)
	noises.clear()


func _spot(e, ai: Dictionary):
	if e.ducked:
		return null
	var day: bool = level.data.get("daylight", false)
	var best = null
	var bd := 1e9
	var fwd := Vector3(-sin(e.face_yaw), 0, -cos(e.face_yaw))
	for f in fighters:
		if f.state != "ok":
			continue
		var d: float = e.global_position.distance_to(f.global_position)
		if d > (SIGHT_DAY if day else SIGHT):
			continue
		var to: Vector3 = (f.global_position - e.global_position).normalized()
		var in_view: bool = to.dot(fwd) > 0.2 or d < 2.5 or ai["mode"] in ["combat", "alert", "react"]
		# in the dark, a fighter with no weapon light on is hard to see past a few metres
		var lit: bool = f.light != null and f.light.visible
		if f.ducked:
			continue
		if not in_view or (not lit and not day and d > 6.0 and ai["mode"] in ["idle", "patrol"]) or d > (SIGHT_DAY if day else 14.0):
			continue
		if not level.clear_line(e.eye(), f.chest_pos()):
			continue
		if d < bd:
			bd = d
			best = f
	return best


func _patrol(e, ai: Dictionary) -> void:
	var pts: Array = ai["patrol"]
	if pts.is_empty():
		return
	if not e.moving():
		ai["pi"] = (int(ai["pi"]) + 1) % pts.size()
		var p: Array = pts[ai["pi"]]
		e.go([Vector3(p[0], 0, p[1])], 0.7)
	e.raised = 0.35
	e.look_at_point = null


## Hit, friends down, a flashbang: nerve drops. Guards break; the Bureau doesn't.
func shaken(e, amount: float) -> void:
	if not e.has_meta("ai"):
		return
	var ai: Dictionary = e.get_meta("ai")
	if level.cover and level.cover.in_cover(e):
		amount *= 0.5
	ai["morale"] = float(ai["morale"]) - amount
	if ai["mode"] in ["idle", "patrol"]:
		ai["mode"] = "alert"


func ally_down(at: Vector3) -> void:
	for e in enemies:
		if e.state == "ok" and e.global_position.distance_to(at) < 10.0:
			shaken(e, 0.3)


func _nerve(e, ai: Dictionary) -> void:
	if e.kind == "bureau" or float(ai["morale"]) > 0.25 or ai["mode"] == "flee":
		return
	var d: Dictionary = e.get_meta("def")
	if d.get("timid", false) or rng.randf() < 0.55:
		e.surrender()
		e.bark_custom(_line("surrender"))
	else:
		ai["mode"] = "flee"
		e.target = null
		e.bark_custom(_line("flee"))
		e.go(_route(e, _far_corner(e)), e.RUN)


func _far_corner(e) -> Vector3:
	var room: String = level.room_at(e.global_position)
	var r: Dictionary = level.room(room)
	if r.is_empty():
		return e.global_position
	var rc: Rect2 = (r["rect"] as Rect2).grow(-0.5)
	var best := e.global_position as Vector3
	var bd := -1.0
	for c in [rc.position, Vector2(rc.end.x, rc.position.y), Vector2(rc.position.x, rc.end.y), rc.end]:
		var p := Vector3(c.x, 0, c.y)
		var dmin := 1e9
		for f in fighters:
			if f.state == "ok":
				dmin = minf(dmin, p.distance_to(f.global_position))
		if dmin > bd:
			bd = dmin
			best = p
	return best


func _route(e, to: Vector3) -> Array:
	var a: String = level.room_near(e.global_position)
	var b: String = level.room_near(to)
	var pts: Array = []
	var rooms: Array = level.room_path(a, b)
	for i in range(rooms.size() - 1):
		var d: Dictionary = level.door_between(rooms[i], rooms[i + 1])
		if d.is_empty() or d["state"] == "closed":
			return pts
		pts.append(level.door_world(d))
	pts.append(to)
	return pts


func _line(key: String) -> String:
	var l: Array = LINES[key]
	return l[rng.randi() % l.size()]


# ------------------------------------------------------------------ cover (M4 V1)
# They're worse than us but there are more of them (user 2026-11-25). Each one runs to the nearest cover with
# the object between it and you, then peeks and ducks; slow to come back up when rounds snap past. They never
# push forward while your people are alive and shooting: only after it's been quiet a while, and one at a time.

const QUIET_TO_ADVANCE := 7.0


func _has_cover() -> bool:
	return level.cover != null and not level.cover.spots.is_empty()


## Seconds since one of ours last fired.
func quiet() -> float:
	return _t - us_fired_t


func _cover_fight(e, ai: Dictionary, delta: float, seen) -> void:
	var cv = level.cover
	var threat = seen.global_position if seen != null else ai["last_seen"]
	if threat == null:
		threat = _nearest_fighter(e)
		ai["last_seen"] = threat
	if threat == null or e.busy > 0.0 or e.stunned > 0.0:
		return
	if e.moving():
		return
	var s: Dictionary = cv.spot_of(e)
	var at_spot: bool = not s.is_empty() and (s["pos"] as Vector3).distance_to(e.global_position) < 0.6
	if s.is_empty() or not cv.good_against(s, threat) or not at_spot:
		var ns: Dictionary = cv.best(e, threat, 11.0)
		if not ns.is_empty() and (ns["pos"] as Vector3).distance_to(e.global_position) > 0.3:
			cv.claim(ns, e)
			e.ducked = false
			e.go(level.path(e.global_position, ns["pos"]), e.RUN)
			if rng.randf() < 0.4:
				e.bark_custom(["Cover! Get to cover!", "Behind the bags!", "Get down!"][rng.randi() % 3])
			return
	# move up: only when it's gone quiet, one man at a time, and never the timid
	if quiet() > QUIET_TO_ADVANCE and advancing == null and not e.get_meta("def").get("timid", false) and e.reloading <= 0.0:
		var fwd: Dictionary = cv.best(e, threat, 9.0, threat)
		if not fwd.is_empty():
			cv.claim(fwd, e)
			e.ducked = false
			advancing = e
			e.go(level.path(e.global_position, fwd["pos"]), e.RUN)
			e.bark_custom(["Moving up!", "Go, go!", "I'm moving!"][rng.randi() % 3])
			return
	# peek and duck: worse than ours (longer down, slower up when shot at)
	var t := float(ai.get("duck_t", 0.0)) - delta
	if e.ducked:
		if t <= 0.0 and e.reloading <= 0.0:
			e.ducked = false
			e.crouch = 0.55
			e.preaim = (float(e.st["ads"]) + float(e.st.get("react", 0.5))) * 0.5
			t = rng.randf_range(1.5, 3.2) * (1.0 - e.suppress * 0.5)
	else:
		e.crouch = 0.55
		if e.reloading > 0.0 or t <= 0.0 or (e.suppress > 0.85 and e.target == null):
			e.ducked = true
			e.target = null
			t = rng.randf_range(1.2, 2.6) + e.suppress * 3.0
	ai["duck_t"] = t


func _nearest_fighter(e) -> Variant:
	var best = null
	var bd := 1e9
	for f in fighters:
		if f.state == "ok":
			var d: float = f.global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = f.global_position
	return best


# ------------------------------------------------------------------ the deputy (M4 V2)
# Unarmed. When it goes loud he runs for his hiding place (data "hide"), throwing doors open on the way, and
# cowers there. When one of yours gets close with a clear line he gives up. Nobody on our side shoots him
# unless you tell them to.

const VIP_LINES := {"run": ["Get me out of here!", "Do something! Protect me!", "Inside, inside!"],
	"hide": ["Oh God...", "They won't find me here."],
	"give": ["Don't shoot! Do you know who I am?!", "All right! All right! I'm unarmed!", "I can pay you! Whatever they pay you!"]}


func _vip(e, ai: Dictionary, delta: float) -> void:
	var d: Dictionary = e.get_meta("def")
	match str(ai["mode"]):
		"idle", "patrol", "alert", "react", "combat":
			var loud := not noises.is_empty() or enemies.any(func(o) -> bool: return o != e and o.state == "ok" and o.get_meta("ai")["mode"] in ["combat", "react"])
			if loud or _spot(e, ai) != null:
				ai["mode"] = "run"
				e.bark_custom(VIP_LINES["run"][rng.randi() % 3])
				var to: Vector3 = Vector3(d["hide"][0], 0, d["hide"][1]) if d.has("hide") else e.global_position
				_throw_doors_open(e, to)
				e.go(level.path(e.global_position, to), e.RUN)
		"run":
			if not e.moving():
				ai["mode"] = "hide"
				e.bark_custom(VIP_LINES["hide"][rng.randi() % 2])
		"hide":
			e.crouch = move_toward(e.crouch, 1.0, delta * 3.0)
			for f in fighters:
				if f.state == "ok" and f.global_position.distance_to(e.global_position) < 6.0 and level.clear_line(f.eye(), e.chest_pos()):
					e.surrender()
					e.bark_custom(VIP_LINES["give"][rng.randi() % 3])
					return


## He doesn't wait for a door: every door on his way flies open (you'll see which way he went).
func _throw_doors_open(e, to: Vector3) -> void:
	var rooms: Array = level.room_path(level.room_near(e.global_position), level.room_near(to))
	for i in range(rooms.size() - 1):
		var dr: Dictionary = level.door_between(rooms[i], rooms[i + 1])
		if not dr.is_empty() and dr["state"] == "closed":
			dr["locked"] = false
			level.open_door(dr, "kick")
	if level.cover:
		level.cover.refresh(level._bounds())        # the grid has to know before he picks his way
