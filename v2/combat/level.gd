extends Node3D
## A building from a layout (data/v2/combat/*.json): rooms are floor rectangles, doors sit on shared walls.
## Builds the grimy walls (merged, door gaps cut, colliders for line of sight), real doors that open, get
## kicked or blown, tube lights, props; and answers the squad's questions: which room, how to get there,
## where to stack on a door, where to stand inside a room. Godot floor plan: x right, z (forward is -z).

const KindLook := preload("res://v2/world/kind_look.gd")
const KIT := "res://art/depot_kit.glb"
const Cover := preload("res://v2/combat/cover.gd")
const LOW_H := 1.1                # wall height the overview camera sees (the roof and the top of the walls cut away)
const LAYER_FULL := 8            # render layer 4: whole walls and the ceiling (helmet cams, CCTV)
const LAYER_CUT := 16            # render layer 5: the low cut walls and the fog (the overview only)
const LAYER_ENEMY := 32          # render layer 6: guards (the helmet cams always; the overview only once seen)
const LAYER_SEEN := 64           # render layer 7: a guard someone is looking at right now (the overview sees it)
const H := 2.8
const DOOR_W := 1.0
const DOOR_H := 2.1

var data: Dictionary = {}
var rooms: Array = []           # {id, name, rect: Rect2 (x, z)}
var doors: Array = []           # {id, name, pos: Vector2, axis, a, b, locked, state: closed|open|broken, pivot, slab, body}
var lights: Array = []          # {light, mesh, base, flicker}
var objective_pos := Vector3.ZERO
var pcs: Array = []              # desk PCs your people can exploit: {room, stand, screen, done}
var cover: Node3D                # cover pieces, cover spots and the walking grid (v2/combat/cover.gd, M4 V1)
var civ: RefCounted = null        # the civilians' brain (stray rounds can hit them), when there are any
var _mats := {}
var _t := 0.0


func build(p_data: Dictionary) -> void:
	data = p_data
	for r in data.get("rooms", []):
		var rr: Array = r["rect"]
		rooms.append({"id": r["id"], "name": r.get("name", r["id"]),
			"rect": Rect2(Vector2(minf(rr[0], rr[2]), minf(rr[1], rr[3])), Vector2(absf(rr[2] - rr[0]), absf(rr[3] - rr[1]))), "outdoor": r.get("outdoor", false)})
	for d in data.get("doors", []):
		var dp: Array = d["pos"]
		var arch: bool = d.get("arch", false)       # a wide opening with no door in it (M4 V3: open-plan rooms)
		doors.append({"id": d["id"], "name": d.get("name", d["id"]), "pos": Vector2(dp[0], dp[1]), "axis": d["axis"],
			"a": d["a"], "b": d["b"], "locked": d.get("locked", false) and not arch, "state": "open" if arch else "closed",
			"w": float(d.get("w", DOOR_W)), "arch": arch})
	_floor_and_ceiling()
	_walls()
	for d in doors:
		_door(d)
	_lights()
	_props()
	cover = Cover.new()
	add_child(cover)
	cover.build(self, data.get("cover", []))
	cover.build_grid(_bounds().grow(0.5))


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
		var nexts: Array = []
		for d in doors:
			if d["a"] == cur:
				nexts.append(d["b"])
			elif d["b"] == cur:
				nexts.append(d["a"])
		nexts.append_array(open_links(cur))
		for nxt in nexts:
			if not prev.has(nxt):
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


## Open ground touching open ground (street, yard, alley): you just walk across, no door.
func open_links(id: String) -> Array:
	var out: Array = []
	var r := room(id)
	if r.is_empty() or not r["outdoor"]:
		return out
	for o in rooms:
		if o["outdoor"] and o["id"] != id and (r["rect"] as Rect2).grow(0.05).intersects(o["rect"]):
			out.append(o["id"])
	return out


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
	_door_changed(d)
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

## Walls, floor and ceiling in the garage's style (kind_look.gd: chipped paint, worn concrete).
## kind 0 = painted wall, 1 = concrete floor, 2 = ceiling.
func _mat(kind: int, paint := Color(0.44, 0.43, 0.35)) -> Material:
	var k := str(kind) + str(paint)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		match kind:
			0:
				m.albedo_color = paint
				m.resource_name = "paint_wall%d" % (hash(str(paint)) % 1000)
			1:
				m.albedo_color = Color(0.3, 0.29, 0.27)
				m.resource_name = "paint_floor"
			_:
				m.albedo_color = Color(0.16, 0.16, 0.17)
				m.resource_name = "paint_ceiling"
		_mats[k] = KindLook.look(m, "depot%d" % kind)
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
	var any_out := rooms.any(func(r) -> bool: return r["outdoor"])
	if not any_out:
		var b := _bounds().grow(0.3)
		var c := b.get_center()
		box(Vector3(b.size.x, 0.1, b.size.y), Vector3(c.x, -0.05, c.y), _mat(1))
		box(Vector3(b.size.x, 0.1, b.size.y), Vector3(c.x, H + 0.05, c.y), _mat(2)).layers = LAYER_FULL    # no roof on the overview
		return
	# a street or a yard: a floor per room, a roof only over the indoor ones, and a wide apron of ground around
	var ob := _bounds().grow(14.0)
	box(Vector3(ob.size.x, 0.1, ob.size.y), Vector3(ob.get_center().x, -0.07, ob.get_center().y), flat(Color(0.24, 0.23, 0.2)))
	for r in rooms:
		var rc: Rect2 = (r["rect"] as Rect2).grow(0.06)
		var cc := rc.get_center()
		box(Vector3(rc.size.x, 0.1, rc.size.y), Vector3(cc.x, -0.05, cc.y), flat(Color(0.2, 0.2, 0.21)) if r["outdoor"] else _mat(1))
		if not r["outdoor"]:
			box(Vector3(rc.size.x, 0.1, rc.size.y), Vector3(cc.x, H + 0.05, cc.y), _mat(2)).layers = LAYER_FULL


## Every room edge, merged into lines, with door gaps cut out.
func _walls() -> void:
	var lines := {}     # "x:1.25" -> [ [lo, hi], ... ]
	for r in rooms:
		if r["outdoor"]:
			continue           # a street or a yard: open, no walls of its own
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
				ivs = _cut(ivs, c - float(d["w"]) * 0.5, c + float(d["w"]) * 0.5)
		var paint := Color(0.44, 0.43, 0.35)
		for iv in ivs:
			var lo: float = iv[0]
			var hi: float = iv[1]
			if hi - lo < 0.02:
				continue
			var mid := (lo + hi) * 0.5
			var full: MeshInstance3D
			var low: MeshInstance3D
			if axis == "x":
				full = box(Vector3(0.12, H, hi - lo), Vector3(at, H * 0.5, mid), _mat(0, paint), Vector3.ZERO, true)
				low = box(Vector3(0.1, LOW_H, hi - lo), Vector3(at, LOW_H * 0.5, mid), _mat(0, paint))
			else:
				full = box(Vector3(hi - lo, H, 0.12), Vector3(mid, H * 0.5, at), _mat(0, paint), Vector3.ZERO, true)
				low = box(Vector3(hi - lo, LOW_H, 0.1), Vector3(mid, LOW_H * 0.5, at), _mat(0, paint))
			full.layers = LAYER_FULL      # the helmet cams see whole walls; the overview sees them cut low
			low.layers = LAYER_CUT


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
	if d["arch"]:
		# an opening: just the header across the top
		var w: float = d["w"]
		var hs0 := Vector3(0.12, H - DOOR_H, w) if d["axis"] == "x" else Vector3(w, H - DOOR_H, 0.12)
		box(hs0, dp + Vector3(0, DOOR_H + (H - DOOR_H) * 0.5, 0), _mat(0), Vector3.ZERO, true).layers = LAYER_FULL
		return
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
	_dress()
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
		var ol: Light3D = l["light"]
		if ol.light_energy > 0.3 and Vector2(ol.global_position.x, ol.global_position.z).distance_to(Vector2(p.x, p.z)) < 3.2:
			return true
	return false


## Where a person can stand: inside a room (off the walls), or in the gap of an open door.
func walkable(p: Vector3, r := 0.28) -> bool:
	var q := Vector2(p.x, p.z)
	if cover and cover.blocked(p, r):
		return false
	for rm in rooms:
		if (rm["rect"] as Rect2).grow(-r).has_point(q):
			return true
	# open ground (street, yard, alley) runs straight on into the next bit of open ground: only building walls stop you
	for rm in rooms:
		if rm["outdoor"] and (rm["rect"] as Rect2).has_point(q):
			var by_wall := false
			for o in rooms:
				if not o["outdoor"] and (o["rect"] as Rect2).grow(r).has_point(q):
					by_wall = true
					break
			if not by_wall:
				return true
	for d in doors:
		if d["state"] == "closed":
			continue
		var dp: Vector2 = d["pos"]
		var half_w := float(d["w"]) * 0.5 - r * 0.6
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


# ------------------------------------------------------------------ dressing (C1: the garage's style)

## Depth of each kit piece (m), to stand it against a wall. Pieces face into the room.
const KIT_DEPTH := {"crate": 0.6, "crate_stack": 1.0, "shelf": 0.5, "desk": 0.7, "desk_pc": 0.7, "chair": 1.5,
	"lockers": 0.5, "cabinet": 0.62, "fridge": 0.62, "break_table": 2.6, "notice_board": 0.06, "extinguisher": 0.2,
	"pipes": 0.24, "bin": 0.36, "counter": 0.66, "bottle_shelf": 0.3, "cafe_table": 0.7, "bed": 1.96, "gun_rack": 0.32,
	"bench": 0.45, "pallet": 1.0}
const KIT_WIDTH := {"crate": 0.6, "crate_stack": 1.2, "shelf": 1.4, "desk": 1.3, "desk_pc": 1.3, "chair": 0.5,
	"lockers": 1.5, "cabinet": 0.5, "fridge": 0.65, "break_table": 1.3, "notice_board": 1.0, "extinguisher": 0.2,
	"pipes": 3.0, "bin": 0.35, "counter": 2.46, "bottle_shelf": 2.0, "cafe_table": 1.6, "bed": 0.9, "gun_rack": 1.6,
	"bench": 1.8, "pallet": 1.2}

var _kit: Node3D


func _kit_piece(name: String) -> Node3D:
	if _kit == null:
		var ps: PackedScene = load(KIT)
		_kit = ps.instantiate()
	var src := _kit.find_child("Kit_" + name, true, false) as Node3D
	if src == null:
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D()
	add_child(n)
	KindLook.apply(n)
	return n


## Every room's furniture from data (rooms[].dress: {kit, wall n/s/e/w, at 0..1 along it}), against its wall,
## nudged off any door on that wall. Pieces have no colliders: the squad walks by doctrine, not around props.
func _dress() -> void:
	for r in data.get("rooms", []):
		var rm := room(r["id"])
		var rc: Rect2 = rm["rect"]
		var bare: bool = r["id"] in data.get("bare_rooms", [])     # e.g. the vault fills the office in the depot raid
		for it in ([] if bare else r.get("dress", [])):
			var kit: String = it["kit"]
			var wall: String = it.get("wall", "n")
			var t := float(it.get("at", 0.5))
			var depth: float = KIT_DEPTH.get(kit, 0.6)
			var half_w: float = KIT_WIDTH.get(kit, 0.6) * 0.5
			var along_len := rc.size.x if wall in ["n", "s"] else rc.size.y
			var along := clampf(t * along_len, half_w + 0.1, along_len - half_w - 0.1)
			along = _off_doors(rc, wall, along, half_w)
			var p := Vector3.ZERO
			var yaw := 0.0
			match wall:
				"n":
					p = Vector3(rc.position.x + along, 0, rc.position.y + 0.07 + depth * 0.5)
				"s":
					p = Vector3(rc.position.x + along, 0, rc.end.y - 0.07 - depth * 0.5)
					yaw = PI
				"w":
					p = Vector3(rc.position.x + 0.07 + depth * 0.5, 0, rc.position.y + along)
					yaw = PI * 0.5
				_:
					p = Vector3(rc.end.x - 0.07 - depth * 0.5, 0, rc.position.y + along)
					yaw = -PI * 0.5
			if it.get("center", false):
				p = Vector3(rc.get_center().x, 0, rc.get_center().y)
			if it.has("spot"):            # free-standing, at a fraction across the room (generated buildings)
				var sp: Array = it["spot"]
				p = Vector3(rc.position.x + float(sp[0]) * rc.size.x, 0, rc.position.y + float(sp[1]) * rc.size.y)
			var n := _kit_piece(kit)
			if n == null:
				continue
			# kit pieces are built with their back at +Y (Blender) = -Z here, centred: shift so the back touches the wall
			n.position = p
			n.rotation.y = yaw + float(it.get("turn", 0.0)) * PI / 180.0
			if kit == "desk_pc":
				var fwd := Basis(Vector3.UP, n.rotation.y) * Vector3(0, 0, 1)
				pcs.append({"room": r["id"], "stand": p + fwd * 0.85, "screen": p + Vector3(0, 1.0, 0), "done": false})
		_room_lamps(r, rc)
	if _kit:
		_kit.free()      # the source pieces were only copied from
		_kit = null


## Slide a piece along its wall so it doesn't block a door on that wall.
func _off_doors(rc: Rect2, wall: String, along: float, half_w: float) -> float:
	for d in doors:
		var dp: Vector2 = d["pos"]
		var on_wall := false
		var c := 0.0
		match wall:
			"n":
				on_wall = d["axis"] == "z" and absf(dp.y - rc.position.y) < 0.05
				c = dp.x - rc.position.x
			"s":
				on_wall = d["axis"] == "z" and absf(dp.y - rc.end.y) < 0.05
				c = dp.x - rc.position.x
			"w":
				on_wall = d["axis"] == "x" and absf(dp.x - rc.position.x) < 0.05
				c = dp.y - rc.position.y
			_:
				on_wall = d["axis"] == "x" and absf(dp.x - rc.end.x) < 0.05
				c = dp.y - rc.position.y
		var dw := float(d["w"]) * 0.5
		if on_wall and absf(along - c) < half_w + dw + 0.35:
			along = c + (1.0 if along >= c else -1.0) * (half_w + dw + 0.4)
	return along


## A shaded hanging lamp over each room (every ~6 m down a long hall) throwing a warm pool down.
func _room_lamps(r: Dictionary, rc: Rect2) -> void:
	if r.get("lamps", 1) == 0:
		return
	var long_z := rc.size.y > rc.size.x
	var n := maxi(1, int(maxf(rc.size.x, rc.size.y) / 6.0))
	for k in n:
		var f := (k + 0.5) / n
		var at := Vector3(rc.get_center().x, 0, rc.position.y + rc.size.y * f) if long_z else Vector3(rc.position.x + rc.size.x * f, 0, rc.get_center().y)
		var lamp := _kit_piece("lamp")
		if lamp == null:
			return
		lamp.position = at
		var pool := SpotLight3D.new()
		pool.light_color = Color(1.0, 0.74, 0.46)
		pool.light_energy = float(r.get("lamp_energy", 3.2))
		pool.spot_range = 3.6
		pool.spot_angle = 64.0
		pool.spot_attenuation = 0.8
		pool.shadow_enabled = true
		pool.position = at + Vector3(0, 2.0, 0)
		pool.rotation = Vector3(-PI * 0.5, 0, 0)
		add_child(pool)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.74, 0.46)
		glow.light_energy = 0.5
		glow.omni_range = 1.3
		glow.position = at + Vector3(0, 2.02, 0)
		add_child(glow)
		lights.append({"light": pool, "mesh": null, "base": pool.light_energy, "flicker": false})


## Crack a door a hand's width (crack and peek): it counts as open for sight, the opener looks through first.
func crack_door(d: Dictionary) -> void:
	if d["state"] != "closed":
		return
	var pivot: Node3D = d["pivot"]
	(d["body"] as StaticBody3D).collision_layer = 0
	d["state"] = "open"
	_door_changed(d)
	d["rot0"] = pivot.rotation.y
	pivot.create_tween().tween_property(pivot, "rotation:y", pivot.rotation.y + float(d["swing"]) * 0.22, 0.6).set_trans(Tween.TRANS_SINE)


## Push a cracked door the rest of the way.
func finish_open(d: Dictionary) -> void:
	if not d.has("rot0"):
		return
	var pivot: Node3D = d["pivot"]
	pivot.create_tween().tween_property(pivot, "rotation:y", float(d["rot0"]) + float(d["swing"]), 0.5).set_trans(Tween.TRANS_SINE)
	d.erase("rot0")


# ------------------------------------------------------------------ cover and routes (M4 V1)

func _door_changed(d: Dictionary) -> void:
	if cover:
		var p: Vector2 = d["pos"]
		cover.call_deferred("refresh", Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)))


## A walking route around walls and cover (the grid). Indoor doctrine still uses rooms and doors.
func path(a: Vector3, b: Vector3) -> Array:
	return cover.path(a, b) if cover else [b]


func is_outdoor(p: Vector3) -> bool:
	var r := room(room_near(p))
	return not r.is_empty() and r["outdoor"]
