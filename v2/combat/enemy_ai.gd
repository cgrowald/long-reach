extends RefCounted
## The other side (docs/COMBAT_SLICE.md section 8): guards sit, patrol, notice you (lights give you away in
## the dark), hear shots and kicked doors, fight back. Their nerve breaks: a guard may run or give up.
## Bureau escorts never surrender and hunt you instead.

const SIGHT := 20.0
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
	for e in enemies:
		if e.state != "ok":
			continue
		var ai: Dictionary = e.get_meta("ai")
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
				e.crouch = 0.45
				e.stop()
		else:
			e.target = null
			if ai["mode"] == "combat":
				ai["lost"] = float(ai["lost"]) + delta
				e.look_at_point = (ai["last_seen"] as Vector3) + Vector3(0, 1.2, 0) if ai["last_seen"] != null else null
				if e.kind == "bureau" and float(ai["lost"]) > 3.0 and not e.moving() and ai["last_seen"] != null:
					e.go(_route(e, ai["last_seen"]), e.WALK)        # hunt
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
		_nerve(e, ai)
		e.tick(delta)
	noises.clear()


func _spot(e, ai: Dictionary):
	var best = null
	var bd := 1e9
	var fwd := Vector3(-sin(e.face_yaw), 0, -cos(e.face_yaw))
	for f in fighters:
		if f.state != "ok":
			continue
		var d: float = e.global_position.distance_to(f.global_position)
		if d > SIGHT:
			continue
		var to: Vector3 = (f.global_position - e.global_position).normalized()
		var in_view: bool = to.dot(fwd) > 0.2 or d < 2.5 or ai["mode"] in ["combat", "alert", "react"]
		# in the dark, a fighter with no weapon light on is hard to see past a few metres
		var lit: bool = f.light != null and f.light.visible
		if not in_view or (not lit and d > 6.0 and ai["mode"] in ["idle", "patrol"]) or d > 14.0:
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
