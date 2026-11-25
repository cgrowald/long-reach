extends Node3D
## Cover for any place (docs/M4_VARIETY.md V1; COMBAT_SLICE 11 "one AI for any place").
## Built from data (level data "cover": [{kind, pos [x, z], turn deg, len m}]): sandbags, jersey barriers, cars,
## crates, barrels, low walls, a guard booth. Each piece:
##   - blocks walking (an oriented box, used by level.walkable),
##   - stops rounds: low pieces sit on physics layer 2 (you see over them, but they catch shots);
##     tall ones (the booth) on layer 1 like walls (they block sight too),
##   - gives cover spots around it, each one good against threats on the far side.
## Also the walking grid (Godot's AStarGrid2D, a stock A* grid) so people route around cover outdoors.
## The usual cover-shooter pattern: pick a spot with the object between you and the threat, peek, duck.

const LOW_LAYER := 2              # physics layer bit for low cover (rounds stop, eyes see over)
const CELL := 0.5

## kind -> size (x = length, y = height, z = depth), protection when crouched behind it, colour
const KINDS := {
	"sandbags": {"size": Vector3(1.8, 0.95, 0.65), "protect": 0.85, "col": Color(0.42, 0.38, 0.27)},
	"barrier": {"size": Vector3(2.0, 0.85, 0.6), "protect": 0.9, "col": Color(0.55, 0.54, 0.5)},
	"car": {"size": Vector3(4.2, 1.45, 1.8), "protect": 0.8, "col": Color(0.28, 0.33, 0.3)},
	"crate": {"size": Vector3(0.9, 0.9, 0.9), "protect": 0.6, "col": Color(0.4, 0.31, 0.2)},
	"barrel": {"size": Vector3(0.62, 1.0, 0.62), "protect": 0.55, "col": Color(0.25, 0.3, 0.38)},
	"low_wall": {"size": Vector3(3.0, 1.0, 0.3), "protect": 0.9, "col": Color(0.5, 0.46, 0.4)},
	"booth": {"size": Vector3(2.0, 2.4, 2.0), "protect": 1.0, "col": Color(0.33, 0.36, 0.3), "tall": true},
}

var level: Node3D
var pieces: Array = []            # {kind, center: Vector3, half: Vector2 (x along, y depth), yaw, protect, tall, body}
var spots: Array = []             # {pos: Vector3, piece: int, out: Vector3 (away from the piece), taken: actor or null}
var grid: AStarGrid2D
var _origin := Vector2.ZERO


func build(p_level: Node3D, specs: Array) -> void:
	level = p_level
	for s in specs:
		var k: String = s.get("kind", "crate")
		var kd: Dictionary = KINDS.get(k, KINDS["crate"])
		var size: Vector3 = kd["size"]
		if s.has("len"):
			size.x = float(s["len"])
		var p: Array = s["pos"]
		var yaw := deg_to_rad(float(s.get("turn", 0.0)))
		var c := Vector3(p[0], 0, p[1])
		var piece := {"kind": k, "center": c, "half": Vector2(size.x, size.z) * 0.5, "yaw": yaw, "h": size.y,
			"protect": float(kd["protect"]), "tall": kd.get("tall", false)}
		piece["body"] = _mesh(k, size, c, yaw, kd["col"], piece["tall"])
		pieces.append(piece)
	_spots()


## Is p inside a piece (grown by r)? Used by level.walkable.
func blocked(p: Vector3, r := 0.28) -> bool:
	for pc in pieces:
		var l := _local(pc, p)
		if absf(l.x) < float(pc["half"].x) + r and absf(l.y) < float(pc["half"].y) + r:
			return true
	return false


func _local(pc: Dictionary, p: Vector3) -> Vector2:
	var d := p - (pc["center"] as Vector3)
	var cy := cos(float(pc["yaw"]))
	var sy := sin(float(pc["yaw"]))
	# rotate the offset into the piece's frame (yaw about +Y: x' = x cos - z sin ...)
	return Vector2(d.x * cy - d.z * sy, d.x * sy + d.z * cy)


## How much of a round from a to b a piece of cover near b catches (0 = nothing). Crouched = the full value,
## standing = their legs only.
func between(a: Vector3, b: Vector3, crouched: bool) -> float:
	var q := PhysicsRayQueryParameters3D.create(a, Vector3(b.x, 0.55, b.z) if crouched else b - Vector3(0, 0.45, 0))
	q.collision_mask = LOW_LAYER
	var hit := level.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	var hp: Vector3 = hit["position"]
	if Vector2(hp.x, hp.z).distance_to(Vector2(b.x, b.z)) > 2.4:
		return 0.0          # cover far from the target protects nothing (they're out in the open behind it)
	var pr := float((hit["collider"] as Node).get_meta("protect", 0.6))
	return pr if crouched else pr * 0.35


## Where a round that missed into cover lands (for the puff), or null.
func impact(a: Vector3, b: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = LOW_LAYER
	var hit := level.get_world_3d().direct_space_state.intersect_ray(q)
	return null if hit.is_empty() else hit


# ------------------------------------------------------------------ cover spots

func _spots() -> void:
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		if pc["tall"] and pc["kind"] == "booth":
			pass
		var hx: float = pc["half"].x
		var hz: float = pc["half"].y
		var off := 0.5
		var pts: Array = []
		# both long faces, every ~0.9 m
		var n := maxi(1, int(hx * 2.0 / 0.9))
		for k in n:
			var x := -hx + hx * 2.0 * (k + 0.5) / n
			pts.append([Vector2(x, hz + off), Vector2(0, 1)])
			pts.append([Vector2(x, -hz - off), Vector2(0, -1)])
		# the ends
		pts.append([Vector2(hx + off, 0), Vector2(1, 0)])
		pts.append([Vector2(-hx - off, 0), Vector2(-1, 0)])
		for lp in pts:
			var w := _world(pc, lp[0])
			var o := _world(pc, lp[1]) - (pc["center"] as Vector3)
			if level.walkable(w, 0.3):
				spots.append({"pos": w, "piece": i, "out": o.normalized(), "taken": null})


func _world(pc: Dictionary, l: Vector2) -> Vector3:
	var cy := cos(float(pc["yaw"]))
	var sy := sin(float(pc["yaw"]))
	return (pc["center"] as Vector3) + Vector3(l.x * cy + l.y * sy, 0, -l.x * sy + l.y * cy)


## Does this spot have its piece between it and the threat?
func good_against(s: Dictionary, threat: Vector3) -> bool:
	var to := Vector3(threat.x, 0, threat.z) - (s["pos"] as Vector3)
	if to.length() < 2.5:
		return false
	return (-(s["out"] as Vector3)).dot(to.normalized()) > 0.55


## The best free cover spot for `who` against `threat` within `reach` m. toward (optional): prefer spots that
## get closer to it (bounding forward); away = prefer spots further from the threat (falling back).
func best(who, threat: Vector3, reach := 9.0, toward = null) -> Dictionary:
	var me: Vector3 = who.global_position
	var bi := -1
	var bs := 1e9
	for i in spots.size():
		var s: Dictionary = spots[i]
		if s["taken"] != null and s["taken"] != who and is_instance_valid(s["taken"]) and s["taken"].alive():
			continue
		var d := me.distance_to(s["pos"])
		if d > reach or not good_against(s, threat):
			continue
		var score := d
		if toward is Vector3:
			var gain: float = me.distance_to(toward) - (s["pos"] as Vector3).distance_to(toward)
			if gain < 1.5:
				continue                      # not forward enough to be worth the run
			score = d * 0.4 - gain
		score += _crowd(s, who) * 2.0
		if score < bs:
			bs = score
			bi = i
	return {} if bi < 0 else spots[bi]


func _crowd(s: Dictionary, who) -> float:
	var c := 0.0
	for o in spots:
		if o != s and o["taken"] != null and o["taken"] != who and (o["pos"] as Vector3).distance_to(s["pos"]) < 1.0:
			c += 1.0
	return c


func claim(s: Dictionary, who) -> void:
	release(who)
	s["taken"] = who


func release(who) -> void:
	for s in spots:
		if s["taken"] == who:
			s["taken"] = null


func spot_of(who) -> Dictionary:
	for s in spots:
		if s["taken"] == who:
			return s
	return {}


## Is someone standing in a claimed cover spot right now?
func in_cover(who) -> bool:
	var s := spot_of(who)
	return not s.is_empty() and (s["pos"] as Vector3).distance_to(who.global_position) < 0.45


# ------------------------------------------------------------------ walking grid (AStarGrid2D)

func build_grid(bounds: Rect2) -> void:
	grid = AStarGrid2D.new()
	_origin = bounds.position
	grid.region = Rect2i(0, 0, int(ceil(bounds.size.x / CELL)) + 1, int(ceil(bounds.size.y / CELL)) + 1)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	refresh(bounds)


## Re-mark cells (after a door opens).
func refresh(area: Rect2) -> void:
	if grid == null:
		return
	var a := _cell(Vector3(area.position.x, 0, area.position.y))
	var b := _cell(Vector3(area.end.x, 0, area.end.y))
	for x in range(maxi(a.x, 0), mini(b.x + 1, grid.region.size.x)):
		for y in range(maxi(a.y, 0), mini(b.y + 1, grid.region.size.y)):
			grid.set_point_solid(Vector2i(x, y), not level.walkable(_pt(Vector2i(x, y)), 0.25))


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(round((p.x - _origin.x) / CELL)), int(round((p.z - _origin.y) / CELL)))


func _pt(c: Vector2i) -> Vector3:
	return Vector3(_origin.x + c.x * CELL, 0, _origin.y + c.y * CELL)


## A walking route from a to b around cover and walls (smoothed). Empty if there is none.
func path(a: Vector3, b: Vector3) -> Array:
	if grid == null:
		return [b]
	var ca := _free_near(_cell(a))
	var cb := _free_near(_cell(b))
	if ca.x < 0 or cb.x < 0:
		return [b]
	var ids := grid.get_id_path(ca, cb)
	if ids.is_empty():
		return []
	var raw: Array = []
	for c in ids:
		raw.append(_pt(c))
	raw[raw.size() - 1] = b if level.walkable(b, 0.25) else raw[raw.size() - 1]
	# string-pull: skip points while the straight walk stays clear
	var out: Array = []
	var from := a
	var i := 0
	while i < raw.size():
		var j := raw.size() - 1
		while j > i and not _walk_clear(from, raw[j]):
			j -= 1
		out.append(raw[j])
		from = raw[j]
		i = j + 1
	return out


func _walk_clear(a: Vector3, b: Vector3) -> bool:
	var n := int(a.distance_to(b) / 0.25) + 1
	for k in range(1, n + 1):
		if not level.walkable(a.lerp(b, float(k) / n), 0.25):
			return false
	return true


func _free_near(c: Vector2i) -> Vector2i:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(q) and not grid.is_point_solid(q):
					return q
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ looks (placeholder shapes; the art pass is V2)

func _mesh(kind: String, size: Vector3, c: Vector3, yaw: float, col: Color, tall: bool) -> StaticBody3D:
	var root := Node3D.new()
	root.position = c
	root.rotation.y = yaw
	add_child(root)
	var mat: Material = level.flat(col)
	match kind:
		"sandbags":
			# two staggered rows of bags
			for row in 3:
				var nb := int(size.x / 0.45)
				for k in nb:
					var x := -size.x * 0.5 + 0.225 + k * (size.x - 0.45) / maxf(1.0, nb - 1) + (0.1 if row % 2 == 1 else 0.0)
					level.box(Vector3(0.48, 0.3, size.z * 0.9), Vector3(clampf(x, -size.x * 0.5 + 0.24, size.x * 0.5 - 0.24), 0.15 + row * 0.3, 0), level.flat(col.lightened(0.05 * (k % 3))), Vector3(0, 0.08 * ((k + row) % 3 - 1), 0), false, root)
		"car":
			level.box(Vector3(size.x, 0.75, size.z), Vector3(0, 0.55, 0), mat, Vector3.ZERO, false, root)
			level.box(Vector3(size.x * 0.5, 0.55, size.z * 0.9), Vector3(-0.2, 1.17, 0), level.flat(col.darkened(0.25)), Vector3.ZERO, false, root)
			level.box(Vector3(size.x * 0.48, 0.42, size.z * 0.92), Vector3(-0.2, 1.17, 0), level.flat(Color(0.1, 0.12, 0.13)), Vector3.ZERO, false, root)
			for wx in [-1.0, 1.0]:
				for wz in [-1.0, 1.0]:
					level.box(Vector3(0.62, 0.62, 0.22), Vector3(wx * size.x * 0.32, 0.31, wz * size.z * 0.47), level.flat(Color(0.06, 0.06, 0.06)), Vector3.ZERO, false, root)
		"booth":
			level.box(Vector3(size.x, size.y, size.z), Vector3(0, size.y * 0.5, 0), mat, Vector3.ZERO, false, root)
			level.box(Vector3(size.x + 0.3, 0.12, size.z + 0.3), Vector3(0, size.y + 0.06, 0), level.flat(col.darkened(0.4)), Vector3.ZERO, false, root)
			level.box(Vector3(size.x * 0.7, 0.6, 0.05), Vector3(0, 1.5, size.z * 0.5 + 0.01), level.flat(Color(0.5, 0.6, 0.55, 1.0), 0.4), Vector3.ZERO, false, root)
		"barrier":
			level.box(Vector3(size.x, size.y * 0.35, size.z), Vector3(0, size.y * 0.175, 0), mat, Vector3.ZERO, false, root)
			level.box(Vector3(size.x, size.y * 0.65, size.z * 0.45), Vector3(0, size.y * 0.67, 0), mat, Vector3.ZERO, false, root)
			level.box(Vector3(size.x * 0.98, 0.12, size.z * 0.47), Vector3(0, size.y * 0.6, 0), level.flat(Color(0.75, 0.6, 0.15)), Vector3.ZERO, false, root)
		_:
			level.box(size, Vector3(0, size.y * 0.5, 0), mat, Vector3.ZERO, false, root)
	# the body that stops rounds
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 if tall else LOW_LAYER
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	sb.add_child(cs)
	root.add_child(sb)
	sb.set_meta("protect", KINDS.get(kind, KINDS["crate"])["protect"])
	return sb
