extends Node3D
## A building from a layout (data/v2/combat/*.json): rooms are floor rectangles, doors sit on shared walls.
## Builds the grimy walls (merged, door gaps cut, colliders for line of sight), real doors that open, get
## kicked or blown, tube lights, props; and answers the squad's questions: which room, how to get there,
## where to stack on a door, where to stand inside a room. Godot floor plan: x right, z (forward is -z).

const GRIME := preload("res://v2/combat/grime.gdshader")
const H := 2.8
const DOOR_W := 1.0
const DOOR_H := 2.1

var data: Dictionary = {}
var rooms: Array = []           # {id, name, rect: Rect2 (x, z)}
var doors: Array = []           # {id, name, pos: Vector2, axis, a, b, locked, state: closed|open|broken, pivot, slab, body}
var lights: Array = []          # {light, mesh, base, flicker}
var objective_pos := Vector3.ZERO
var _mats := {}
var _t := 0.0


func build(p_data: Dictionary) -> void:
	data = p_data
	for r in data.get("rooms", []):
		var rr: Array = r["rect"]
		rooms.append({"id": r["id"], "name": r.get("name", r["id"]),
			"rect": Rect2(Vector2(minf(rr[0], rr[2]), minf(rr[1], rr[3])), Vector2(absf(rr[2] - rr[0]), absf(rr[3] - rr[1])))})
	for d in data.get("doors", []):
		var dp: Array = d["pos"]
		doors.append({"id": d["id"], "name": d.get("name", d["id"]), "pos": Vector2(dp[0], dp[1]), "axis": d["axis"],
			"a": d["a"], "b": d["b"], "locked": d.get("locked", false), "state": "closed"})
	_floor_and_ceiling()
	_walls()
	for d in doors:
		_door(d)
	_lights()
	_props()


# ------------------------------------------------------------------ queries

func room(id: String) -> Dictionary:
	for r in rooms:
		if r["id"] == id:
			return r
	return {}


func room_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for r in rooms:
		if (r["rect"] as Rect2).has_point(q):
			return r["id"]
	return ""


func door(id: String) -> Dictionary:
	for d in doors:
		if d["id"] == id:
			return d
	return {}


func door_between(a: String, b: String) -> Dictionary:
	for d in doors:
		if (d["a"] == a and d["b"] == b) or (d["a"] == b and d["b"] == a):
			return d
	return {}


## Rooms in order from a to b (breadth first over doors).
func room_path(a: String, b: String) -> Array:
	if a == b:
		return [a]
	var prev := {a: ""}
	var q: Array = [a]
	while not q.is_empty():
		var cur: String = q.pop_front()
		for d in doors:
			var nxt := ""
			if d["a"] == cur:
				nxt = d["b"]
			elif d["b"] == cur:
				nxt = d["a"]
			if nxt != "" and not prev.has(nxt):
				prev[nxt] = cur
				if nxt == b:
					var out: Array = [b]
					var c: String = b
					while prev[c] != "":
						c = prev[c]
						out.push_front(c)
					return out
				q.append(nxt)
	return []


func door_world(d: Dictionary, y := 0.0) -> Vector3:
	return Vector3(d["pos"].x, y, d["pos"].y)


## Unit vector across the door pointing into room `into`.
func door_normal(d: Dictionary, into: String) -> Vector3:
	var r: Rect2 = room(into)["rect"]
	var c := r.get_center()
	if d["axis"] == "x":
		return Vector3(signf(c.x - d["pos"].x), 0, 0)
	return Vector3(0, 0, signf(c.y - d["pos"].y))


## Four stack spots along the wall beside a door, on the `from` side, on the side the squad comes from.
func stack_spots(d: Dictionary, from: String, approach: Vector3) -> Array:
	var n := door_normal(d, from)                     # points back into `from`
	var t := Vector3(n.z, 0, -n.x)                    # along the wall
	var dp := door_world(d)
	if (approach - dp).dot(t) < 0.0:
		t = -t
	var out: Array = []
	for i in 4:
		out.append(dp + n * 0.38 + t * (0.85 + i * 0.72))
	return out


## Where four fighters end up inside a room after flowing through a door: two corners, then deeper.
func entry_spots(d: Dictionary, into: String) -> Array:
	var n := door_normal(d, into)
	var t := Vector3(n.z, 0, -n.x)
	var dp := door_world(d)
	var r: Rect2 = (room(into)["rect"] as Rect2).grow(-0.45)
	var pts := [dp + n * 1.0 + t * 1.3, dp + n * 1.0 - t * 1.3, dp + n * 2.4 + t * 0.6, dp + n * 2.4 - t * 0.6]
	var out: Array = []
	for p in pts:
		var v: Vector3 = p
		out.append(Vector3(clampf(v.x, r.position.x, r.end.x), 0, clampf(v.z, r.position.y, r.end.y)))
	return out


## Clear line from a to b (walls and closed doors block)?
func clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ doors

func open_door(d: Dictionary, how: String) -> void:
	if d["state"] != "closed":
		return
	var pivot: Node3D = d["pivot"]
	var body: StaticBody3D = d["body"]
	body.collision_layer = 0
	match how:
		"charge":
			d["state"] = "broken"
			var slab: Node3D = d["slab"]
			var tw := slab.create_tween()
			tw.tween_property(slab, "position", slab.position + Vector3(0, -0.6, -1.6), 0.25)
			tw.parallel().tween_property(slab, "rotation", Vector3(1.4, 0.6, 0.3), 0.25)
			_boom(door_world(d, 1.2), Color(1.0, 0.7, 0.4), 14.0)
		"kick":
			d["state"] = "open"
			pivot.create_tween().tween_property(pivot, "rotation:y", pivot.rotation.y + d["swing"], 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			d["state"] = "open"
			pivot.create_tween().tween_property(pivot, "rotation:y", pivot.rotation.y + d["swing"], 1.1).set_trans(Tween.TRANS_SINE)


func _boom(at: Vector3, col: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = 9.0
	l.light_volumetric_fog_energy = 4.0
	l.position = at
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


## A flashbang going off in a room.
func flash(at: Vector3) -> void:
	_boom(at, Color(1, 1, 1), 30.0)


# ------------------------------------------------------------------ building

func _mat(kind: int, paint := Color(0.44, 0.43, 0.35)) -> ShaderMaterial:
	var k := str(kind) + str(paint)
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = GRIME
		m.set_shader_parameter("kind", kind)
		m.set_shader_parameter("paint", Vector3(paint.r, paint.g, paint.b))
		_mats[k] = m
	return _mats[k]


func flat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var k := str(col) + str(emit)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.85
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = emit
		_mats[k] = m
	return _mats[k]


func box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, solid := false, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _bounds() -> Rect2:
	var b: Rect2 = rooms[0]["rect"]
	for r in rooms:
		b = b.merge(r["rect"])
	return b


func _floor_and_ceiling() -> void:
	var b := _bounds().grow(0.3)
	var c := b.get_center()
	box(Vector3(b.size.x, 0.1, b.size.y), Vector3(c.x, -0.05, c.y), _mat(1))
	box(Vector3(b.size.x, 0.1, b.size.y), Vector3(c.x, H + 0.05, c.y), _mat(2))


## Every room edge, merged into lines, with door gaps cut out.
func _walls() -> void:
	var lines := {}     # "x:1.25" -> [ [lo, hi], ... ]
	for r in rooms:
		var rc: Rect2 = r["rect"]
		_add_iv(lines, "x:%.2f" % rc.position.x, rc.position.y, rc.end.y)
		_add_iv(lines, "x:%.2f" % rc.end.x, rc.position.y, rc.end.y)
		_add_iv(lines, "z:%.2f" % rc.position.y, rc.position.x, rc.end.x)
		_add_iv(lines, "z:%.2f" % rc.end.y, rc.position.x, rc.end.x)
	for key in lines:
		var axis: String = key.substr(0, 1)
		var at := float(key.substr(2))
		var ivs := _merge(lines[key])
		for d in doors:
			if d["axis"] == axis and absf((d["pos"].x if axis == "x" else d["pos"].y) - at) < 0.05:
				var c: float = d["pos"].y if axis == "x" else d["pos"].x
				ivs = _cut(ivs, c - DOOR_W * 0.5, c + DOOR_W * 0.5)
		var paint := Color(0.44, 0.43, 0.35)
		for iv in ivs:
			var lo: float = iv[0]
			var hi: float = iv[1]
			if hi - lo < 0.02:
				continue
			var mid := (lo + hi) * 0.5
			if axis == "x":
				box(Vector3(0.12, H, hi - lo), Vector3(at, H * 0.5, mid), _mat(0, paint), Vector3.ZERO, true)
			else:
				box(Vector3(hi - lo, H, 0.12), Vector3(mid, H * 0.5, at), _mat(0, paint), Vector3.ZERO, true)


func _add_iv(lines: Dictionary, key: String, a: float, b: float) -> void:
	if not lines.has(key):
		lines[key] = []
	lines[key].append([minf(a, b), maxf(a, b)])


func _merge(ivs: Array) -> Array:
	var s := ivs.duplicate()
	s.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var out: Array = []
	for iv in s:
		if not out.is_empty() and float(iv[0]) <= float(out[-1][1]) + 0.01:
			out[-1][1] = maxf(out[-1][1], iv[1])
		else:
			out.append([iv[0], iv[1]])
	return out


func _cut(ivs: Array, a: float, b: float) -> Array:
	var out: Array = []
	for iv in ivs:
		var lo: float = iv[0]
		var hi: float = iv[1]
		if b <= lo or a >= hi:
			out.append(iv)
			continue
		if a > lo:
			out.append([lo, a])
		if b < hi:
			out.append([b, hi])
	return out


func _door(d: Dictionary) -> void:
	var dp := door_world(d)
	var along := Vector3(0, 0, 1) if d["axis"] == "x" else Vector3(1, 0, 0)
	var thick := Vector3(0.12, 0, 0) if d["axis"] == "x" else Vector3(0, 0, 0.12)
	# header above the gap and a dark frame
	var hs := Vector3(0.12, H - DOOR_H, DOOR_W) if d["axis"] == "x" else Vector3(DOOR_W, H - DOOR_H, 0.12)
	box(hs, dp + Vector3(0, DOOR_H + (H - DOOR_H) * 0.5, 0), _mat(0), Vector3.ZERO, true)
	var frame := flat(Color(0.12, 0.1, 0.09))
	for sgn in [-1.0, 1.0]:
		var fs := Vector3(0.16, DOOR_H, 0.06) if d["axis"] == "x" else Vector3(0.06, DOOR_H, 0.16)
		box(fs, dp + along * (DOOR_W * 0.5) * sgn + Vector3(0, DOOR_H * 0.5, 0), frame)
	# the slab hangs on a pivot at one edge and swings into room b
	var pivot := Node3D.new()
	pivot.position = dp - along * (DOOR_W * 0.5)
	add_child(pivot)
	var ss := Vector3(0.05, DOOR_H - 0.04, DOOR_W - 0.04) if d["axis"] == "x" else Vector3(DOOR_W - 0.04, DOOR_H - 0.04, 0.05)
	var slab := box(ss, along * (DOOR_W * 0.5) + Vector3(0, DOOR_H * 0.5, 0), flat(Color(0.22, 0.19, 0.16) if not d["locked"] else Color(0.25, 0.26, 0.27)), Vector3.ZERO, false, pivot)
	box(Vector3(0.06, 0.04, 0.06), along * (DOOR_W * 0.8) + Vector3(0, 1.0, 0) + thick * 0.6, flat(Color(0.5, 0.45, 0.3)), Vector3.ZERO, false, pivot)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ss
	cs.shape = bs
	body.add_child(cs)
	slab.add_child(body)
	# which way opens into room b
	var into := door_normal(d, d["b"])
	var swing := PI * 0.55
	var test := Basis(Vector3.UP, swing) * along
	if test.dot(into) < 0.0:
		swing = -swing
	d["pivot"] = pivot
	d["slab"] = slab
	d["body"] = body
	d["swing"] = swing


func _lights() -> void:
	for spec in data.get("lights", []):
		var p: Array = spec["pos"]
		var col := Color(0.72, 0.9, 1.0)
		if spec.has("color"):
			var c: Array = spec["color"]
			col = Color(c[0], c[1], c[2])
		var tube := box(Vector3(0.14, 0.05, 1.2), Vector3(p[0], H - 0.02, p[1]), flat(col, 3.0))
		var l := OmniLight3D.new()
		l.position = Vector3(p[0], H - 0.2, p[1])
		l.light_color = col
		l.light_energy = float(spec.get("energy", 0.7))
		l.omni_range = 6.5
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 1.5
		add_child(l)
		lights.append({"light": l, "mesh": tube, "base": float(spec.get("energy", 0.7)), "flicker": spec.get("flicker", false)})


func _props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var wood := flat(Color(0.22, 0.18, 0.14))
	var dark := flat(Color(0.12, 0.1, 0.08))
	for r in rooms:
		var rc: Rect2 = r["rect"]
		if r["id"] == "hall":
			continue
		var c := rc.get_center() + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.8, 0.8))
		box(Vector3(1.4, 0.06, 0.8), Vector3(c.x, 0.76, c.y), wood)
		for lx in [-0.6, 0.6]:
			for lz in [-0.32, 0.32]:
				box(Vector3(0.05, 0.76, 0.05), Vector3(c.x + lx, 0.38, c.y + lz), dark)
		box(Vector3(0.45, 0.06, 0.45), Vector3(c.x - 0.6, 0.45, c.y + 0.7), flat(Color(0.15, 0.15, 0.16)), Vector3(0, rng.randf(), 0))
		for k in 3:
			box(Vector3(0.5, 0.5, 0.4), Vector3(rc.end.x - 0.4, 0.25 + k * 0.5, rc.position.y + 0.5 + rng.randf() * 0.3), flat(Color(0.4, 0.31, 0.2)), Vector3(0, rng.randf() * 0.3, 0))
	# the objective: a stack of manifests on the office desk, a faint lamp on it
	var ob: Dictionary = data.get("objective", {})
	if ob.has("pos"):
		var op: Array = ob["pos"]
		objective_pos = Vector3(op[0], 0.0, op[1])
		box(Vector3(1.2, 0.06, 0.7), objective_pos + Vector3(0, 0.76, 0), wood)
		box(Vector3(0.3, 0.08, 0.22), objective_pos + Vector3(0, 0.83, 0), flat(Color(0.75, 0.72, 0.6)))
	# paper everywhere
	var paper := flat(Color(0.62, 0.6, 0.52))
	var b := _bounds()
	for i in 90:
		box(Vector3(0.21, 0.004, 0.29), Vector3(rng.randf_range(b.position.x, b.end.x), 0.004 + i * 0.0001, rng.randf_range(b.position.y, b.end.y)), paper, Vector3(0, rng.randf() * TAU, 0))


func _process(delta: float) -> void:
	_t += delta
	for l in lights:
		if l["flicker"]:
			var on := fmod(_t * 7.3, 1.0) > 0.12 or sin(_t * 1.1) > 0.6
			if sin(_t * 0.37) > 0.85:
				on = randf() > 0.5
			(l["light"] as OmniLight3D).light_energy = float(l["base"]) if on else 0.05
			(l["mesh"] as MeshInstance3D).visible = on


## Is this spot lit by one of the building's own lights (so you can see someone standing there)?
func lit(p: Vector3) -> bool:
	for l in lights:
		var ol: OmniLight3D = l["light"]
		if ol.light_energy > 0.3 and Vector2(ol.global_position.x, ol.global_position.z).distance_to(Vector2(p.x, p.z)) < 3.2:
			return true
	return false


## Where a person can stand: inside a room (off the walls), or in the gap of an open door.
func walkable(p: Vector3, r := 0.28) -> bool:
	var q := Vector2(p.x, p.z)
	for rm in rooms:
		if (rm["rect"] as Rect2).grow(-r).has_point(q):
			return true
	for d in doors:
		if d["state"] == "closed":
			continue
		var dp: Vector2 = d["pos"]
		var half_w := DOOR_W * 0.5 - r * 0.6
		if d["axis"] == "x":
			if absf(q.y - dp.y) < half_w and absf(q.x - dp.x) < r + 0.35:
				return true
		elif absf(q.x - dp.x) < half_w and absf(q.y - dp.y) < r + 0.35:
			return true
	return false


## The room a point is in, or the nearest one if it's standing in a doorway or against a wall.
func room_near(p: Vector3) -> String:
	var id := room_at(p)
	if id != "":
		return id
	var q := Vector2(p.x, p.z)
	var best := ""
	var bd := 1e9
	for rm in rooms:
		var rc: Rect2 = rm["rect"]
		var c := Vector2(clampf(q.x, rc.position.x, rc.end.x), clampf(q.y, rc.position.y, rc.end.y))
		var dd := c.distance_to(q)
		if dd < bd:
			bd = dd
			best = rm["id"]
	return best


## Stack spots on one side of a door (side = +1 / -1 along the wall), on the `from` side.
func stack_spots_side(d: Dictionary, from: String, side: float) -> Array:
	var n := door_normal(d, from)
	var t := Vector3(n.z, 0, -n.x) * side
	var dp := door_world(d)
	var out: Array = []
	for i in 4:
		out.append(dp + n * 0.38 + t * (0.85 + i * 0.72))
	return out


## Which side of a door (along the wall) a point is on: +1 or -1.
func door_side(d: Dictionary, from: String, p: Vector3) -> float:
	var n := door_normal(d, from)
	var t := Vector3(n.z, 0, -n.x)
	return 1.0 if (p - door_world(d)).dot(t) >= 0.0 else -1.0


## Within reach of a doorway (people file through these single-file and shouldn't shove sideways).
func near_door(p: Vector3, r := 0.9) -> bool:
	for d in doors:
		if Vector2(p.x, p.z).distance_to(d["pos"]) < r:
			return true
	return false
