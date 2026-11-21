extends RefCounted
## Which room is where, and which doors connect them. Rooms are rectangles on the ground (x, z).
## The squad brain uses this to turn "go that way" into "clear the next room that way".

const OUTSIDE := "outside"

## The gray-box test building (tactical/level/test_map.gd). Later: generated buildings.
const TEST_ROOMS := [
	{"id": "west", "name": "WEST HALL", "rect": Rect2(-10.0, -7.0, 8.0, 14.0)},
	{"id": "office", "name": "OFFICE", "rect": Rect2(-2.0, 0.0, 12.0, 7.0)},
	{"id": "records", "name": "RECORDS", "rect": Rect2(-2.0, -7.0, 6.0, 7.0)},
	{"id": "safe", "name": "SAFE ROOM", "rect": Rect2(4.0, -7.0, 6.0, 7.0)},
]

var rooms: Array = []
var links: Array = []      # {"door": door node, "a": room id, "b": room id}


func _init(door_nodes: Array, room_defs: Array = TEST_ROOMS) -> void:
	rooms = room_defs
	for d in door_nodes:
		var n: Vector3 = d.normal()
		var a := room_at(d.center + n * 0.8)
		var b := room_at(d.center - n * 0.8)
		links.append({"door": d, "a": a, "b": b})


func room(id: String) -> Dictionary:
	for r in rooms:
		if r["id"] == id:
			return r
	return {"id": OUTSIDE, "name": "OUTSIDE", "rect": Rect2()}


func room_at(p: Vector3) -> String:
	for r in rooms:
		if (r["rect"] as Rect2).has_point(Vector2(p.x, p.z)):
			return str(r["id"])
	return OUTSIDE


func center(id: String) -> Vector3:
	var r: Rect2 = room(id)["rect"]
	var c := r.get_center()
	return Vector3(c.x, 0.0, c.y)


## Doors out of a room: [{"door", "to", "into": unit normal pointing into the other room}]
func exits(from_room: String) -> Array:
	var out: Array = []
	for l in links:
		var to := ""
		if l["a"] == from_room:
			to = l["b"]
		elif l["b"] == from_room:
			to = l["a"]
		else:
			continue
		var d = l["door"]
		var n: Vector3 = d.normal()
		var into: Vector3 = n if room_at(d.center + n * 0.8) == to else -n
		out.append({"door": d, "to": to, "into": into})
	return out


## Pick the exit that best matches a direction on the ground. Prefers rooms not yet cleared.
func best_exit(from_room: String, from_pos: Vector3, dir: Vector3, cleared: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for e in exits(from_room):
		var to_door: Vector3 = e["door"].center - from_pos
		to_door.y = 0.0
		var score: float = dir.dot(to_door.normalized()) * 2.0 - to_door.length() * 0.03
		if cleared.has(e["to"]) or e["to"] == OUTSIDE:
			score -= 1.0
		if score > best_score:
			best_score = score
			best = e
	return best


## Clamp a point inside a room, keeping a margin from the walls.
func clamp_in(id: String, p: Vector3, margin: float = 0.7) -> Vector3:
	var r: Rect2 = room(id)["rect"]
	if r.size == Vector2.ZERO:
		return p
	return Vector3(clampf(p.x, r.position.x + margin, r.end.x - margin), 0.0, clampf(p.z, r.position.y + margin, r.end.y - margin))
