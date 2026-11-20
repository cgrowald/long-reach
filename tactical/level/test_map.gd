extends Node3D
## Gray-box test map: one building (brick shell, drywall rooms) and outdoor cover.
## Builds itself in _ready. Exposes spawn points for main to place units.
## Every wall/cover piece is a StaticBody3D on collision layer 1 tagged with meta "material".

const GameData := preload("res://sim/game_data.gd")

const WALL_HEIGHT := 3.0
const DOOR_WIDTH := 1.2
const DOOR_HEIGHT := 2.1
const EXTERIOR_T := 0.3
const INTERIOR_T := 0.15
const LOW_COVER_MIN := 0.5
const LOW_COVER_MAX := 1.35

## Friendly insertion point, south of the building behind the sandbags.
var operator_spawns: Array[Vector3] = [
	Vector3(-5.0, 0.0, 19.0), Vector3(-3.5, 0.0, 19.0),
	Vector3(3.5, 0.0, 19.0), Vector3(5.0, 0.0, 19.0),
]
## Hostiles: position + facing (yaw, radians; 0 = facing north / -Z).
var tango_spawns: Array[Dictionary] = [
	{"pos": Vector3(-6.0, 0.0, -3.0), "yaw": PI * 0.5},
	{"pos": Vector3(-7.0, 0.0, 4.5), "yaw": -PI * 0.5},
	{"pos": Vector3(1.0, 0.0, -4.5), "yaw": PI},
	{"pos": Vector3(7.0, 0.0, -4.0), "yaw": PI * 0.75},
	{"pos": Vector3(6.5, 0.0, 3.4), "yaw": PI},
	{"pos": Vector3(-4.5, 0.0, -5.5), "yaw": PI * 0.25},
	{"pos": Vector3(2.5, 0.0, -2.0), "yaw": PI * 0.5},
	{"pos": Vector3(8.5, 0.0, 5.5), "yaw": PI * 0.75},
	{"pos": Vector3(12.5, 0.0, -2.0), "yaw": -PI * 0.5},
	{"pos": Vector3(-13.0, 0.0, -8.0), "yaw": PI * 0.8},
]
## Where the named target of an operation waits: the back room with the safe.
var hvt_spawn: Dictionary = {"pos": Vector3(7.5, 0.0, -2.5), "yaw": PI * 0.85}

## Doorways filled while building walls: {"pos": Vector3 (y = 0), "along_x": bool}.
var doors: Array[Dictionary] = []
## Low cover a soldier can crouch behind (sandbags, barriers, desks...).
var low_cover: Array[AABB] = []

var _mat_cache: Dictionary = {}


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_building()
	_build_cover()


func _build_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)


func _build_ground() -> void:
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.48, 0.45, 0.36)
	ground_mat.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(140.0, 140.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = ground_mat
	add_child(mesh)

	# Collision slab whose top face is y = 0 (navmesh walks on it).
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(0.0, -0.5, 0.0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(140.0, 1.0, 140.0)
	col.shape = shape
	body.add_child(col)
	add_child(body)

	# Building floor slab, visual only.
	_add_box("Floor", Vector3(20.0, 0.04, 14.0), Vector3(0.0, 0.02, 0.0), "concrete", false)


## Building footprint: x -10..10, z -7..7. No roof (top-down view).
func _build_building() -> void:
	_wall_along_x(-7.0, -10.0, 10.0, [-4.0], EXTERIOR_T, "brick")
	_wall_along_x(7.0, -10.0, 10.0, [3.0], EXTERIOR_T, "brick")
	_wall_along_z(-10.0, -7.0, 7.0, [0.0], EXTERIOR_T, "brick")
	_wall_along_z(10.0, -7.0, 7.0, [], EXTERIOR_T, "brick")
	_wall_along_z(-2.0, -7.0, 7.0, [-3.5, 3.5], INTERIOR_T, "drywall")
	_wall_along_x(0.0, -2.0, 10.0, [6.0], INTERIOR_T, "drywall")
	_wall_along_z(4.0, -7.0, 0.0, [-3.5], INTERIOR_T, "drywall")
	_add_box("Desk", Vector3(1.6, 0.8, 0.8), Vector3(-6.0, 0.4, 4.0), "wood")
	_add_box("Counter", Vector3(3.0, 1.0, 0.6), Vector3(6.5, 0.5, 4.5), "wood")
	_add_box("Safe", Vector3(0.9, 1.3, 0.9), Vector3(8.8, 0.65, -6.0), "steel")


func _build_cover() -> void:
	for x in [-6.0, 0.0, 6.0]:
		_add_box("Barrier", Vector3(3.0, 1.0, 0.6), Vector3(x, 0.5, -15.0), "concrete")
	for x in [-4.0, 4.0]:
		_add_box("Sandbags", Vector3(4.0, 0.9, 0.8), Vector3(x, 0.45, 15.0), "sandbag")
	_add_box("CarBody", Vector3(4.2, 0.9, 1.8), Vector3(18.0, 0.75, 4.0), "car_body")
	_add_box("CarCabin", Vector3(2.2, 0.7, 1.6), Vector3(17.8, 1.55, 4.0), "glass")
	_add_box("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-18.0, 0.6, -3.0), "wood")
	_add_box("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-18.0, 0.6, -1.6), "wood")
	_add_box("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-18.0, 1.8, -2.3), "wood")
	_add_box("Container", Vector3(6.0, 2.6, 2.4), Vector3(-16.0, 1.3, 12.0), "steel")


# ---------------------------------------------------------------- helpers

func _material(key: String) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	var entry: Variant = GameData.materials().get(key)
	if typeof(entry) == TYPE_DICTIONARY:
		mat.albedo_color = GameData.color_from(entry)
	else:
		push_warning("Unknown material '%s'" % key)
		mat.albedo_color = Color.MAGENTA
	_mat_cache[key] = mat
	return mat


func _add_box(box_name: String, size: Vector3, pos: Vector3, mat_key: String, collide: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	body.set_meta("material", mat_key)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(mat_key)
	body.add_child(mesh)
	if collide and size.y >= LOW_COVER_MIN and size.y <= LOW_COVER_MAX:
		low_cover.append(AABB(pos - size * 0.5, size))
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	add_child(body)
	return body


func _wall_segments(start: float, end: float, gaps: Array) -> Array[Vector2]:
	var segs: Array[Vector2] = []
	var sorted_doors: Array = gaps.duplicate()
	sorted_doors.sort()
	var cursor: float = start
	for d in sorted_doors:
		var gap_start: float = float(d) - DOOR_WIDTH * 0.5
		if gap_start > cursor:
			segs.append(Vector2(cursor, gap_start))
		cursor = float(d) + DOOR_WIDTH * 0.5
	if end > cursor:
		segs.append(Vector2(cursor, end))
	return segs


func _wall_along_x(z: float, x0: float, x1: float, door_centers: Array, t: float, mat_key: String) -> void:
	for seg in _wall_segments(x0 - t * 0.5, x1 + t * 0.5, door_centers):
		_add_box("Wall", Vector3(seg.y - seg.x, WALL_HEIGHT, t), Vector3((seg.x + seg.y) * 0.5, WALL_HEIGHT * 0.5, z), mat_key)
	for d in door_centers:
		_add_lintel(Vector3(float(d), 0.0, z), Vector3(DOOR_WIDTH, 0.0, t), mat_key)
		doors.append({"pos": Vector3(float(d), 0.0, z), "along_x": true})


func _wall_along_z(x: float, z0: float, z1: float, door_centers: Array, t: float, mat_key: String) -> void:
	for seg in _wall_segments(z0, z1, door_centers):
		_add_box("Wall", Vector3(t, WALL_HEIGHT, seg.y - seg.x), Vector3(x, WALL_HEIGHT * 0.5, (seg.x + seg.y) * 0.5), mat_key)
	for d in door_centers:
		_add_lintel(Vector3(x, 0.0, float(d)), Vector3(t, 0.0, DOOR_WIDTH), mat_key)
		doors.append({"pos": Vector3(x, 0.0, float(d)), "along_x": false})


func _add_lintel(center: Vector3, footprint: Vector3, mat_key: String) -> void:
	var h: float = WALL_HEIGHT - DOOR_HEIGHT
	_add_box("Lintel", Vector3(footprint.x, h, footprint.z), Vector3(center.x, DOOR_HEIGHT + h * 0.5, center.z), mat_key)
