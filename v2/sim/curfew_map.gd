extends RefCounted
## The town after curfew, for the sneak dash (v2/stations/outside.gd). No nodes.
## A grid: buildings, streets, alleys, a locked yard gate (a shortcut you can pick), street lamps (light makes
## you easier to see), dark corners (harder), patrols walking loops with torches, and a searchlight.
## Patrols spot you by filling a meter while you're in their torch cone and in line of sight.

const W := 40
const H := 22
const WALL := 1
const ROAD := 0
const GATE := 2

var grid: Array = []          # [y][x]
var lit := {}                 # Vector2i -> 0..1 light
var dark := {}                # Vector2i -> true (shadow)
var home := Vector2i(1, 20)
var yard := Vector2i(38, 1)
var gate := Vector2i(-1, -1)
var gate_open := false
var patrols: Array = []       # {route: [Vector2], seg, t, pos: Vector2, dir: Vector2, meter, chase, lost_t, alert}
var light := {}               # the searchlight {pos: Vector2, ang, speed, range}
var lamps: Array = []         # Vector2i
var rng := RandomNumberGenerator.new()


static func create(p_seed: int, attention: float) -> RefCounted:
	var m = load("res://v2/sim/curfew_map.gd").new()
	m._gen(p_seed, attention)
	return m


func walkable(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return false
	var v: int = grid[c.y][c.x]
	return v == ROAD or (v == GATE and gate_open)


func is_wall(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return true
	var v: int = grid[c.y][c.x]
	return v == WALL or (v == GATE and not gate_open)


func _gen(p_seed: int, attention: float) -> void:
	rng.seed = p_seed
	grid = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(WALL)
		grid.append(row)
	var xs := [0, 9 + rng.randi_range(-1, 1), 19 + rng.randi_range(-1, 1), 29 + rng.randi_range(-1, 1), 38]
	var ys := [0, 10 + rng.randi_range(-1, 0), 20]
	for x in xs:
		for y in H:
			grid[y][x] = ROAD
			grid[y][x + 1] = ROAD
	for y in ys:
		for x in W:
			grid[y][x] = ROAD
			grid[y + 1][x] = ROAD
	# alleys through some blocks
	for bi in xs.size() - 1:
		for bj in ys.size() - 1:
			var x0: int = xs[bi] + 2
			var x1: int = xs[bi + 1] - 1
			var y0: int = ys[bj] + 2
			var y1: int = ys[bj + 1] - 1
			if rng.randf() < 0.65:
				if rng.randf() < 0.5:
					var ay := rng.randi_range(y0 + 1, y1 - 1)
					for x in range(x0, x1 + 1):
						grid[ay][x] = ROAD
				else:
					var ax := rng.randi_range(x0 + 1, x1 - 1)
					for y in range(y0, y1 + 1):
						grid[y][ax] = ROAD
	# the gate: a straight alley through the middle-right block, closed by a padlocked gate
	var gx0: int = xs[2] + 2
	var gx1: int = xs[3] - 1
	var gy := rng.randi_range(ys[0] + 3, ys[1] - 2)
	for x in range(gx0, gx1 + 1):
		grid[gy][x] = ROAD
	gate = Vector2i((gx0 + gx1) / 2, gy)
	grid[gate.y][gate.x] = GATE
	# lamps at the crossings (not all work), light falls off over 3 tiles
	for x in xs:
		for y in ys:
			if rng.randf() < 0.7:
				lamps.append(Vector2i(x, y))
	for l in lamps:
		for dy in range(-3, 5):
			for dx in range(-3, 5):
				var c := Vector2i(l.x + dx, l.y + dy)
				if walkable(c) or grid[clampi(c.y, 0, H - 1)][clampi(c.x, 0, W - 1)] == GATE:
					var d := Vector2(c - l).length()
					lit[c] = maxf(float(lit.get(c, 0.0)), clampf(1.0 - d / 3.5, 0.0, 1.0))
	# shadows: alley tiles and some road edges away from the light
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if not walkable(c) or float(lit.get(c, 0.0)) > 0.2:
				continue
			var walls := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if is_wall(c + d):
					walls += 1
			if walls >= 2 and rng.randf() < 0.55 or walls == 1 and rng.randf() < 0.15:
				dark[c] = true
	# patrols: loops around blocks, more when the Bureau is looking
	var n := 3 + int(attention / 30.0)
	for i in n:
		var bi := rng.randi_range(0, xs.size() - 2)
		var bj := rng.randi_range(0, ys.size() - 2)
		var a := Vector2(xs[bi] + 1.5, ys[bj] + 1.5)
		var b := Vector2(xs[bi + 1] + 0.5, ys[bj + 1] + 0.5)
		var route := [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]
		if rng.randf() < 0.5:
			route.reverse()
		var p := {"route": route, "seg": rng.randi_range(0, 3), "t": rng.randf(), "pos": a, "dir": Vector2.RIGHT,
			"meter": 0.0, "chase": false, "lost_t": 0.0, "speed": rng.randf_range(1.6, 2.2)}
		_place(p)
		patrols.append(p)
	light = {"pos": Vector2(xs[2] + 1.0, ys[1] + 1.0), "ang": rng.randf() * TAU, "speed": 0.45, "range": 9.0}


func _place(p: Dictionary) -> void:
	var r: Array = p["route"]
	var a: Vector2 = r[int(p["seg"]) % r.size()]
	var b: Vector2 = r[(int(p["seg"]) + 1) % r.size()]
	p["pos"] = a.lerp(b, float(p["t"]))
	if (b - a).length() > 0.01:
		p["dir"] = (b - a).normalized()


## Line of sight between two points in tile space (walls block).
func los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(ceil(d.length() * 3.0))
	for i in range(1, steps):
		var q := a + d * (float(i) / steps)
		if is_wall(Vector2i(int(floor(q.x)), int(floor(q.y)))):
			return false
	return true


## How far a torch ray goes before a wall (for the drawing and the cone).
func ray(from: Vector2, dir: Vector2, max_d: float) -> float:
	var d := 0.0
	while d < max_d:
		d += 0.25
		var q := from + dir * d
		if is_wall(Vector2i(int(floor(q.x)), int(floor(q.y)))):
			return d
	return max_d


const CONE := 0.62            # half angle (rad)
const RANGE := 5.5


## Advance patrols and the searchlight. me = the player's position (tile space, centre of tile = +0.5).
## noise = how loud you are (running). Returns "caught" when a chaser reaches you, else "".
func tick(delta: float, me: Vector2, noise: float, hidden: bool) -> String:
	light["ang"] = float(light["ang"]) + float(light["speed"]) * delta
	var result := ""
	for p in patrols:
		var pos: Vector2 = p["pos"]
		var to := me - pos
		var dist := to.length()
		var seen := false
		if dist < RANGE and los(pos, me):
			var ang := absf((p["dir"] as Vector2).angle_to(to))
			if ang < CONE or dist < 1.2:
				seen = true
		var gain := 0.0
		if seen:
			var l := float(lit.get(Vector2i(int(me.x), int(me.y)), 0.0))
			gain = (0.55 + l * 1.2) * (1.0 - dist / (RANGE + 1.0) * 0.6)
			if hidden and dist > 1.5:
				gain *= 0.25
		# the searchlight
		var lp: Vector2 = light["pos"]
		var la := Vector2(cos(float(light["ang"])), sin(float(light["ang"])))
		var lt := me - lp
		if lt.length() < float(light["range"]) and absf(la.angle_to(lt)) < 0.22 and los(lp, me):
			gain = maxf(gain, 1.6)
		# noise turns them to look
		if noise > 0.0 and dist < noise and not p["chase"]:
			p["dir"] = to.normalized()
			p["look_t"] = 1.2
		if p["chase"]:
			if seen:
				p["lost_t"] = 0.0
				p["last"] = me
			else:
				p["lost_t"] = float(p["lost_t"]) + delta
			var goal: Vector2 = p.get("last", me)
			var step := (goal - pos)
			if step.length() > 0.05:
				p["dir"] = step.normalized()
				var nxt: Vector2 = pos + p["dir"] * 3.4 * delta
				if not is_wall(Vector2i(int(floor(nxt.x)), int(floor(nxt.y)))):
					p["pos"] = nxt
			if dist < 0.75:
				result = "caught"
			if float(p["lost_t"]) > 3.0:
				p["chase"] = false
				p["meter"] = 0.0
				p["lost"] = 1.5          # for the "?" bubble
		else:
			p["meter"] = clampf(float(p["meter"]) + (gain * delta * 1.1 if gain > 0.0 else -0.3 * delta), 0.0, 1.0)
			if float(p["meter"]) >= 1.0:
				p["chase"] = true
				p["last"] = me
				p["lost_t"] = 0.0
				p["spotted"] = 1.0
			elif float(p.get("look_t", 0.0)) > 0.0:
				p["look_t"] = float(p["look_t"]) - delta
			else:
				_walk(p, delta)
		p["spotted"] = maxf(0.0, float(p.get("spotted", 0.0)) - delta)
		p["lost"] = maxf(0.0, float(p.get("lost", 0.0)) - delta)
	return result


func _walk(p: Dictionary, delta: float) -> void:
	var r: Array = p["route"]
	var a: Vector2 = r[int(p["seg"]) % r.size()]
	var b: Vector2 = r[(int(p["seg"]) + 1) % r.size()]
	var pos: Vector2 = p["pos"]
	# walk back onto the route after a chase
	var on := Geometry2D.get_closest_point_to_segment(pos, a, b)
	if on.distance_to(pos) > 0.2:
		var d := (on - pos).normalized()
		p["dir"] = d
		p["pos"] = pos + d * float(p["speed"]) * delta
		return
	var seg_len := maxf(0.01, a.distance_to(b))
	p["t"] = clampf(a.distance_to(pos) / seg_len, 0.0, 1.0) + float(p["speed"]) * delta / seg_len
	if float(p["t"]) >= 1.0:
		p["t"] = 0.0
		p["seg"] = (int(p["seg"]) + 1) % r.size()
	_place(p)


func any_chasing() -> bool:
	for p in patrols:
		if p["chase"]:
			return true
	return false


func max_meter() -> float:
	var m := 0.0
	for p in patrols:
		m = maxf(m, 1.0 if p["chase"] else float(p["meter"]))
	return m


## After you're caught: everyone calms down and the one who caught you lets you go (or walks you).
func calm() -> void:
	for p in patrols:
		p["chase"] = false
		p["meter"] = 0.0
