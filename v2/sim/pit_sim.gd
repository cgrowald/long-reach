extends RefCounted
## PACKET PIT rules (no nodes, no drawing). Packets bounce through a network of nodes.
## Score = chips x mult. Every send lights a trace lamp; honeypots light more; rows that reach the
## sysadmin line get patched (+1 trace each). Fill the trace and you're TRACED (score halved).

const W := 288.0
const H := 264.0
const COLS := 9
const CELL := 32.0
const BW := 30.0
const BH := 12.0
const ROW_H := 14.0
const TOP := 22.0
const PATCH_ROW := 13
const LAUNCH := Vector2(144, 254)
const R := 2.0
const SPEED := 260.0
const TRACE_MAX := 9
const MAX_BALLS := 60

## t: weight, hp range
const TYPES := {
	"fw": {"w": 50, "hp": [2, 4]},
	"data": {"w": 24, "hp": [2, 2]},
	"exp": {"w": 12, "hp": [3, 3]},
	"honey": {"w": 10, "hp": [1, 1]},
	"vault": {"w": 3, "hp": [7, 7]},
}

var rng := RandomNumberGenerator.new()
var nodes: Array = []
var balls: Array = []
var events: Array = []
var mods := {}
var chips := 0
var mult := 1.0
var trace := 0
var volleys := 0
var combo := 0
var best_combo := 0
var ghost_left := 2
var traced := false
var volley_time := 0.0
## Today's rule and the target's weak spot.
var patch_day := true
var careless := true

var _queue := 0
var _queue_t := 0.0
var _aim := Vector2.UP
var _spawned: Array = []


func setup(seed: int, m: Dictionary) -> void:
	rng.seed = seed
	mods = m
	nodes.clear()
	balls.clear()
	for r in 8:
		_spawn_row(r, 0.62)


func score() -> int:
	return int(chips * mult)


func final_score() -> int:
	return score() / 2 if traced else score()


func busy() -> bool:
	return _queue > 0 or not balls.is_empty()


func rect_of(n: Dictionary) -> Rect2:
	return Rect2(int(n["c"]) * CELL + 1.0, TOP + int(n["row"]) * ROW_H, BW, BH)


func packets_per_send() -> int:
	return 5 + (3 if mods.get("overclock", false) else 0)


func send(dir: Vector2) -> void:
	_aim = dir.normalized()
	if _aim.y > -0.15:
		_aim = Vector2(signf(_aim.x) * 0.99, -0.15).normalized()
	_queue = packets_per_send()
	_queue_t = 0.0
	volley_time = 0.0
	combo = 0
	volleys += 1
	trace += 1
	events.append({"e": "send"})
	if mods.get("overclock", false):
		events.append({"e": "cart", "id": "overclock", "text": "+3 PACKETS"})


## Packets speed up the longer a volley runs, so stragglers don't drag on.
func speed() -> float:
	return SPEED * (1.0 + maxf(0.0, volley_time - 3.0) * 0.6)


func update(dt: float) -> void:
	volley_time += dt
	if _queue > 0:
		_queue_t -= dt
		if _queue_t <= 0.0:
			_queue_t = 0.07
			_queue -= 1
			balls.append({"p": LAUNCH, "v": _aim * SPEED, "splits": 0})
			events.append({"e": "launch"})
	var steps := 4
	var h := dt / steps
	for s in steps:
		for b in balls:
			_step_ball(b, h)
		if not _spawned.is_empty():
			balls.append_array(_spawned)
			_spawned.clear()
		balls = balls.filter(func(b: Dictionary) -> bool: return b["p"].y < H + 6.0)
	nodes = nodes.filter(func(n: Dictionary) -> bool: return int(n["hp"]) > 0)
	for n in nodes:
		n["flash"] = maxf(0.0, float(n["flash"]) - dt * 6.0)


## After a volley: the network creeps down, the sysadmin patches rows that reach the line, a new row spawns.
func end_volley() -> void:
	for n in nodes:
		n["row"] = int(n["row"]) + 1
	var patched := {}
	for n in nodes:
		if int(n["row"]) >= PATCH_ROW:
			patched[int(n["row"])] = true
	nodes = nodes.filter(func(n: Dictionary) -> bool: return int(n["row"]) < PATCH_ROW)
	for r in patched:
		trace += 1
		events.append({"e": "patched", "y": TOP + r * ROW_H})
	_spawn_row(0, minf(0.85, 0.6 + volleys * 0.03))
	if trace >= TRACE_MAX:
		traced = true


func _spawn_row(row: int, density: float) -> void:
	for c in COLS:
		if rng.randf() > density:
			continue
		var t := _pick_type(row)
		var hr: Array = TYPES[t]["hp"]
		var hp := rng.randi_range(int(hr[0]), int(hr[1]))
		if t == "fw" and patch_day:
			hp += 1
		if t == "exp" and careless:
			hp = 1
		nodes.append({"c": c, "row": row, "t": t, "hp": hp, "max": hp, "flash": 0.0})


func _pick_type(row: int) -> String:
	var total := 0
	for t in TYPES:
		if t == "vault" and row > 3:
			continue
		total += int(TYPES[t]["w"])
	var roll := rng.randi_range(1, total)
	for t in TYPES:
		if t == "vault" and row > 3:
			continue
		roll -= int(TYPES[t]["w"])
		if roll <= 0:
			return t
	return "fw"


func _step_ball(b: Dictionary, h: float) -> void:
	var p: Vector2 = b["p"]
	var v: Vector2 = b["v"]
	p += v * h
	if p.x < R:
		p.x = R
		v.x = absf(v.x)
		events.append({"e": "wall"})
	elif p.x > W - R:
		p.x = W - R
		v.x = -absf(v.x)
		events.append({"e": "wall"})
	if p.y < R:
		p.y = R
		v.y = absf(v.y)
		events.append({"e": "wall"})
	for n in nodes:
		if int(n["hp"]) <= 0:
			continue
		var er := rect_of(n).grow(R)
		if not er.has_point(p):
			continue
		var ox := minf(p.x - er.position.x, er.end.x - p.x)
		var oy := minf(p.y - er.position.y, er.end.y - p.y)
		var c := er.get_center()
		if ox < oy:
			if p.x < c.x:
				p.x = er.position.x - 0.01
				v.x = -absf(v.x)
			else:
				p.x = er.end.x + 0.01
				v.x = absf(v.x)
		else:
			if p.y < c.y:
				p.y = er.position.y - 0.01
				v.y = -absf(v.y)
			else:
				p.y = er.end.y + 0.01
				v.y = absf(v.y)
		b["p"] = p
		b["v"] = v
		_hit(n, b)
		p = b["p"]
		v = b["v"]
		break
	# never let a packet skim sideways forever
	var sp := speed()
	if absf(v.y) < sp * 0.22:
		v.y = (signf(v.y) if v.y != 0.0 else -1.0) * sp * 0.22
	v = v.normalized() * sp
	b["p"] = p
	b["v"] = v


func _hit(n: Dictionary, b: Dictionary) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	n["hp"] = int(n["hp"]) - 1
	n["flash"] = 1.0
	var at := rect_of(n).get_center()
	var t: String = n["t"]
	var keylog: bool = mods.get("keylog", false)
	match t:
		"fw":
			_add_chips(2, at)
		"data":
			_add_chips(16 if keylog else 8, at)
			if keylog:
				events.append({"e": "cart", "id": "keylog", "text": ""})
		"exp":
			_add_chips(2, at)
		"vault":
			_add_chips(5, at)
		"honey":
			if mods.get("ghost", false) and ghost_left > 0:
				ghost_left -= 1
				events.append({"e": "cart", "id": "ghost", "text": "GHOSTED", "pos": at})
			else:
				trace += 1
				events.append({"e": "trace", "pos": at})
				if trace >= TRACE_MAX:
					traced = true
	events.append({"e": "hit", "pos": at, "t": t, "combo": combo})
	if int(n["hp"]) <= 0:
		_break(n, b, at)


func _break(n: Dictionary, b: Dictionary, at: Vector2) -> void:
	var t: String = n["t"]
	var text := ""
	match t:
		"fw":
			_add_chips(6, at)
			text = "+6"
			if mods.get("worm", false) and int(b["splits"]) < 2 and balls.size() + _spawned.size() < MAX_BALLS:
				b["splits"] = int(b["splits"]) + 1
				var v: Vector2 = b["v"]
				_spawned.append({"p": b["p"], "v": v.rotated(0.55), "splits": b["splits"]})
				b["v"] = v.rotated(-0.3)
				events.append({"e": "cart", "id": "worm", "text": "SPLIT", "pos": at})
		"data":
			var v := 40 if mods.get("keylog", false) else 20
			_add_chips(v, at)
			text = "+%d" % v
		"exp":
			mult += 1.0
			text = "+1 MULT"
		"vault":
			mult *= 2.0
			text = "x2 MULT"
		"honey":
			text = ""
	events.append({"e": "break", "pos": at, "t": t, "text": text})


func _add_chips(v: int, _at: Vector2) -> void:
	chips += v
