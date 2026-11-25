extends RefCounted
## People who aren't fighters (M4 Q10, user 2026-11-25): bar patrons, the barman, a passer-by.
## Nobody is just a target (GAME_DESIGN pillar 4). When it goes loud they get down and cover their heads,
## or run for the nearest way out; a stray round can hit them, and that costs you (district mood, recruits).
## Nobody shoots at them on purpose: they're never in anyone's target list.

const LINES := {
	"hide": ["Get down! Get down!", "Oh God, oh God...", "Don't shoot, please!", "Under the table!"],
	"run": ["Run!", "Out the back, go!", "Move, move!"],
	"hurt": ["I'm hit! I'm just a customer!", "Help me... please...", "Why? Why us?"],
}

var people: Array = []
var level: Node3D
var rng := RandomNumberGenerator.new()
var hurt: Array = []             # who got hit by a stray round (the report, the district)


func setup(p_people: Array, p_level: Node3D) -> void:
	people = p_people
	level = p_level
	rng.seed = 31
	for c in people:
		c.set_meta("mode", "calm")
		c.weapons_free = false
		c.raised = 0.0
		c.hit_taken.connect(func(who, _info: Dictionary) -> void:
			if not hurt.has(who):
				hurt.append(who)
			who.bark_custom(_line("hurt")))


## Something loud (the enemy brain's noise list is shared through fight.gd).
func noise(at: Vector3, radius: float) -> void:
	for c in people:
		if c.state != "ok" or c.get_meta("mode") != "calm":
			continue
		var r := radius if level.clear_line(c.eye(), at + Vector3(0, 1.2, 0)) else radius * 0.6
		if c.global_position.distance_to(at) > r:
			continue
		c.set_meta("react", rng.randf_range(0.2, 0.9))
		c.set_meta("mode", "startled")


func tick(delta: float) -> void:
	for c in people:
		if c.state != "ok":
			c.tick(delta)
			continue
		match str(c.get_meta("mode")):
			"startled":
				var t := float(c.get_meta("react")) - delta
				c.set_meta("react", t)
				if t <= 0.0:
					var out = _exit_for(c)
					if out != null and rng.randf() < 0.45:
						c.set_meta("mode", "run")
						c.bark_custom(_line("run"))
						c.go(level.path(c.global_position, out), c.RUN)
					else:
						c.set_meta("mode", "hide")
						c.bark_custom(_line("hide"))
			"run":
				if not c.moving():
					c.state = "fled"          # out the door and gone
					c.visible = false
			"hide":
				c.crouch = move_toward(c.crouch, 1.0, delta * 3.0)
				c.pose_mode = "hands_up"
		c.tick(delta)


## The way out nearest them that isn't toward the shooting: an outside spot through an open door.
func _exit_for(c) -> Variant:
	var room: String = level.room_at(c.global_position)
	var best = null
	var bd := 1e9
	for d in level.doors:
		if d["state"] == "closed" and d["locked"]:
			continue
		var other := ""
		if d["a"] == room:
			other = d["b"]
		elif d["b"] == room:
			other = d["a"]
		if other == "" or not level.room(other).get("outdoor", false):
			continue
		var p: Vector3 = level.door_world(d) + level.door_normal(d, other) * 6.0
		var dd: float = p.distance_to(c.global_position)
		if dd < bd:
			bd = dd
			best = p
	return best


## Rounds that missed: anyone standing close to the line past the target can be hit.
func stray(from: Vector3, to: Vector3, shooter) -> void:
	var ab := (to - from)
	var far := from + ab.normalized() * (ab.length() + 6.0)
	for c in people:
		if c.state != "ok" or not c.visible:
			continue
		var p: Vector3 = c.chest_pos() - Vector3(0, 0.3 * c.crouch, 0)
		var seg := far - from
		var t := clampf((p - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if t < 0.05 or (from + seg * t).distance_to(p) > 0.45:
			continue
		if not level.clear_line(from, p):
			continue
		if rng.randf() < (0.18 if c.crouch > 0.6 else 0.4):
			c.take_hit(shooter)
			return


func _line(key: String) -> String:
	var l: Array = LINES[key]
	return l[rng.randi() % l.size()]
