extends Node3D
## M0 test map: gray-box building + outdoor cover, 4 friendly operators on patrol,
## 3 placeholder enemies, free camera with lock-on, pause.
##
## Everything is built in code for now so the scene file stays trivial.
## Later milestones move maps into proper .tscn levels / generated maps.

const CameraRig := preload("res://tactical/camera/camera_rig.gd")
const Operator := preload("res://tactical/units/operator.gd")
const MATERIALS_PATH := "res://data/materials.json"

const WALL_HEIGHT := 3.0
const DOOR_WIDTH := 1.2
const DOOR_HEIGHT := 2.1
const EXTERIOR_T := 0.3
const INTERIOR_T := 0.15

const FRIENDLY_COLOR := Color(0.25, 0.5, 0.95)
const ENEMY_COLOR := Color(0.85, 0.2, 0.2)

var material_data: Dictionary = {}
var operators: Array[Operator] = []
var selected: Operator = null

var _rig: CameraRig
var _level: Node3D
var _mat_cache: Dictionary = {}
var _status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_materials()
	_level = Node3D.new()
	_level.name = "Level"
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_level)

	_build_environment()
	_build_ground()
	_build_building()
	_build_cover()
	_spawn_units()

	_rig = CameraRig.new()
	_rig.name = "CameraRig"
	add_child(_rig)

	_build_hud()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var code: Key = key.physical_keycode
		if code == KEY_SPACE:
			get_tree().paused = not get_tree().paused
		elif code == KEY_TAB:
			_cycle_follow()
		elif code == KEY_F:
			if selected != null:
				_rig.follow(selected)
		elif code == KEY_ESCAPE:
			_rig.release()
			_select(null)
		elif code >= KEY_1 and code <= KEY_9:
			var idx: int = code - KEY_1
			if idx < operators.size():
				_select(operators[idx])
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var picked: Operator = _pick_operator(mb.position)
			_select(picked)
			if picked != null and mb.double_click:
				_rig.follow(picked)


func _select(op: Operator) -> void:
	if selected != null and is_instance_valid(selected):
		selected.set_selected(false)
	selected = op
	if selected != null:
		selected.set_selected(true)


func _cycle_follow() -> void:
	if operators.is_empty():
		return
	var idx: int = operators.find(_rig.follow_target)
	var next: Operator = operators[(idx + 1) % operators.size()]
	_select(next)
	_rig.follow(next)


func _pick_operator(screen_pos: Vector2) -> Operator:
	var cam: Camera3D = _rig.camera
	var best: Operator = null
	var best_dist: float = 40.0
	for op in operators:
		var world_pos: Vector3 = op.global_position + Vector3(0.0, 0.9, 0.0)
		if cam.is_position_behind(world_pos):
			continue
		var d: float = cam.unproject_position(world_pos).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = op
	return best


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var help := Label.new()
	help.text = "\n".join([
		"WASD / arrows  pan      Q / E  rotate      Middle-drag  orbit      Wheel  zoom",
		"Click  select      Double-click / F  follow      Tab  cycle follow      Esc  release",
		"1-4  select operator      Space  pause",
	])
	help.position = Vector2(16, 12)
	_style_label(help)
	layer.add_child(help)

	_status_label = Label.new()
	_status_label.position = Vector2(16, 90)
	_style_label(_status_label)
	layer.add_child(_status_label)


func _style_label(label: Label) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 16)


func _process(_delta: float) -> void:
	var lines: Array[String] = []
	lines.append("PAUSED" if get_tree().paused else "LIVE")
	if selected != null:
		lines.append("Selected: %s" % selected.callsign)
	var following := _rig.follow_target as Operator
	if following != null:
		lines.append("Following: %s" % following.callsign)
	lines.append("FPS %d" % Engine.get_frames_per_second())
	_status_label.text = "\n".join(lines)
	_status_label.add_theme_color_override(
		"font_color", Color(1.0, 0.8, 0.2) if get_tree().paused else Color.WHITE)


# ---------------------------------------------------------------- data

func _load_materials() -> void:
	var text: String = FileAccess.get_file_as_string(MATERIALS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not parse %s" % MATERIALS_PATH)
		return
	material_data = parsed


func _material(key: String) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	var entry: Variant = material_data.get(key)
	if typeof(entry) == TYPE_DICTIONARY and entry.has("color"):
		var c: Array = entry["color"]
		mat.albedo_color = Color(float(c[0]), float(c[1]), float(c[2]))
	else:
		push_warning("Unknown material '%s'" % key)
		mat.albedo_color = Color.MAGENTA
	_mat_cache[key] = mat
	return mat


# ---------------------------------------------------------------- world building

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
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

	var body := StaticBody3D.new()
	body.name = "Ground"
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := WorldBoundaryShape3D.new()
	col.shape = shape
	body.add_child(col)
	_level.add_child(body)

	# Building floor slab so the interior reads as a different surface.
	_add_box("Floor", Vector3(20.0, 0.04, 14.0), Vector3(0.0, 0.02, 0.0), "concrete", false)


## Building footprint: x -10..10, z -7..7. No roof (top-down view).
func _build_building() -> void:
	# Exterior brick walls, door gaps by center coordinate.
	_wall_along_x(-7.0, -10.0, 10.0, [-4.0], EXTERIOR_T, "brick")
	_wall_along_x(7.0, -10.0, 10.0, [3.0], EXTERIOR_T, "brick")
	_wall_along_z(-10.0, -7.0, 7.0, [0.0], EXTERIOR_T, "brick")
	_wall_along_z(10.0, -7.0, 7.0, [], EXTERIOR_T, "brick")
	# Interior drywall partitions.
	_wall_along_z(-2.0, -7.0, 7.0, [-3.5, 3.5], INTERIOR_T, "drywall")
	_wall_along_x(0.0, -2.0, 10.0, [6.0], INTERIOR_T, "drywall")
	_wall_along_z(4.0, -7.0, 0.0, [-3.5], INTERIOR_T, "drywall")
	# Interior furniture as low cover.
	_add_box("Desk", Vector3(1.6, 0.8, 0.8), Vector3(-6.0, 0.4, 4.0), "wood")
	_add_box("Counter", Vector3(3.0, 1.0, 0.6), Vector3(6.5, 0.5, 4.5), "wood")
	_add_box("Safe", Vector3(0.9, 1.3, 0.9), Vector3(8.8, 0.65, -6.0), "steel")


func _build_cover() -> void:
	# Concrete barriers north of the building.
	for x in [-6.0, 0.0, 6.0]:
		_add_box("Barrier", Vector3(3.0, 1.0, 0.6), Vector3(x, 0.5, -15.0), "concrete")
	# Sandbag positions south.
	for x in [-4.0, 4.0]:
		_add_box("Sandbags", Vector3(4.0, 0.9, 0.8), Vector3(x, 0.45, 15.0), "sandbag")
	# A parked car east.
	_add_box("CarBody", Vector3(4.2, 0.9, 1.8), Vector3(18.0, 0.75, 4.0), "car_body")
	_add_box("CarCabin", Vector3(2.2, 0.7, 1.6), Vector3(17.8, 1.55, 4.0), "glass")
	# Crate stack west.
	_add_box("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-18.0, 0.6, -3.0), "wood")
	_add_box("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-18.0, 0.6, -1.6), "wood")
	_add_box("Crate", Vector3(1.2, 1.2, 1.2), Vector3(-18.0, 1.8, -2.3), "wood")
	# Shipping container.
	_add_box("Container", Vector3(6.0, 2.6, 2.4), Vector3(-16.0, 1.3, 12.0), "steel")


func _spawn_units() -> void:
	# Friendlies patrol a loop around the building (outside the walls, inside the cover ring).
	var loop: Array[Vector3] = [
		Vector3(-13.0, 0.0, -10.0), Vector3(13.0, 0.0, -10.0),
		Vector3(13.0, 0.0, 10.0), Vector3(-13.0, 0.0, 10.0),
	]
	for i in 4:
		var pts: Array[Vector3] = []
		for j in loop.size():
			pts.append(loop[(i + j) % loop.size()])
		var op: Operator = Operator.new()
		op.name = "Alpha%d" % (i + 1)
		op.setup("ALPHA-%d" % (i + 1), FRIENDLY_COLOR, pts)
		_level.add_child(op)
		operators.append(op)

	# Placeholder enemies, stationary inside rooms.
	var no_patrol: Array[Vector3] = []
	var enemy_spots: Array[Vector3] = [Vector3(-6.0, 0.0, -3.0), Vector3(7.0, 0.0, -4.0), Vector3(3.0, 0.0, 4.0)]
	for i in enemy_spots.size():
		var tango: Operator = Operator.new()
		tango.name = "Tango%d" % (i + 1)
		tango.setup("TANGO-%d" % (i + 1), ENEMY_COLOR, no_patrol)
		tango.position = enemy_spots[i]
		tango.rotation.y = randf() * TAU
		_level.add_child(tango)


# ---------------------------------------------------------------- helpers

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

	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)

	_level.add_child(body)
	return body


func _wall_segments(start: float, end: float, doors: Array) -> Array[Vector2]:
	var segs: Array[Vector2] = []
	var sorted_doors: Array = doors.duplicate()
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


func _wall_along_x(z: float, x0: float, x1: float, doors: Array, t: float, mat_key: String) -> void:
	for seg in _wall_segments(x0 - t * 0.5, x1 + t * 0.5, doors):
		var length: float = seg.y - seg.x
		_add_box("Wall", Vector3(length, WALL_HEIGHT, t), Vector3((seg.x + seg.y) * 0.5, WALL_HEIGHT * 0.5, z), mat_key)
	for d in doors:
		_add_lintel(Vector3(float(d), 0.0, z), Vector3(DOOR_WIDTH, 0.0, t), mat_key)


func _wall_along_z(x: float, z0: float, z1: float, doors: Array, t: float, mat_key: String) -> void:
	for seg in _wall_segments(z0, z1, doors):
		var length: float = seg.y - seg.x
		_add_box("Wall", Vector3(t, WALL_HEIGHT, length), Vector3(x, WALL_HEIGHT * 0.5, (seg.x + seg.y) * 0.5), mat_key)
	for d in doors:
		_add_lintel(Vector3(x, 0.0, float(d)), Vector3(t, 0.0, DOOR_WIDTH), mat_key)


func _add_lintel(center: Vector3, footprint: Vector3, mat_key: String) -> void:
	var h: float = WALL_HEIGHT - DOOR_HEIGHT
	_add_box("Lintel", Vector3(footprint.x, h, footprint.z), Vector3(center.x, DOOR_HEIGHT + h * 0.5, center.z), mat_key)
