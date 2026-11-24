extends Node3D
## The v2 garage in 3D (docs/CONNECTED_LOOP.md section 7): loads art/garage_v3.glb, gives it its surface looks
## (kind_look.gd) and a light in every lamp bulb, and lets you walk it in first person (a capsule that bumps into
## walls and furniture). The centre of the view picks a station within reach; using one glides the camera to that
## station's close-up (lean), and back again (unlean).
## Stations are the empties St_<id> in the .glb (every mesh under one belongs to it); data/v2/stations.json holds
## their close-ups in Blender coords; b2g() converts.

signal lean_finished

const Content := preload("res://v2/sim/content.gd")
const Crafting := preload("res://v2/sim/crafting.gd")
const KindLook := preload("res://v2/world/kind_look.gd")
const GLB := "res://art/garage_v3.glb"
const DITHER := preload("res://v2/world/dither.gdshader")

const EYE := 1.62                # eye height (m)
const SPEED := 2.4               # walking speed (m/s)
const REACH := 2.3               # how far away you can use a station from (m)
const RADIUS := 0.25
const SEW_STAGES := ["Sew_Starter", "Sew_Improved", "Sew_Upgraded"]
const TITLE_SPOT := [-2.6, -3.9, 1.75]
const TITLE_LOOK := [0.6, 2.0, 1.0]

var camera: Camera3D
var player: CharacterBody3D
var leaning := ""                # station id we're leaned into, or ""
var hovered := ""
var marked := ""                 # a station the TONIGHT board pointed you at
var look_sensitivity := 1.0
var base_fov := 70.0
var title_mode := false          # slow drift for the title screen
var walk_enabled := false        # the garage turns walking on when no screen or menu is up
var move_override := Vector2.ZERO   # tests: walk without keys (x = strafe right, y = forward)

var _stations: Dictionary = {}   # id -> station def (not hidden)
var _meshes: Dictionary = {}     # station id -> Array[MeshInstance3D]
var _body_station: Dictionary = {}   # StaticBody3D -> station id ("" = the room)
var _stage_shapes: Dictionary = {}   # sewing stage name -> Array[CollisionShape3D]
var _stage_nodes: Dictionary = {}    # sewing stage name -> Node3D
var _yaw := 0.0
var _pitch := 0.0
var _guide_t := 0.0              # > 0 while the view turns to a marked station
var _guide_yaw := 0.0
var _guide_pitch := 0.0
var _mark_t := 0.0
var _lean_t := 0.0               # 0 = walking, 1 = leaned in
var _lean_dir := 0
var _lean_from := Transform3D()
var _lean_to := Transform3D()
var _bob := 0.0
var _trauma := 0.0
var _time := 0.0
var _post: ShaderMaterial
var _hover_mat: StandardMaterial3D
var _mark_mat: StandardMaterial3D
var _bench_lights := {}          # station id -> [SpotLight3D]: the bench's own lamp, bright while you work there


static func b2g(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[2]), -float(a[1]))


func setup() -> void:
	var data := Content.stations()
	for s in data.get("stations", []):
		if not s.get("hidden", false):
			_stations[s["id"]] = s
	var scene: PackedScene = load(GLB)
	var garage := scene.instantiate()
	add_child(garage)
	KindLook.apply(garage)
	_environment()
	_bodies(garage)
	_bulbs(garage)
	_player(data)
	camera = Camera3D.new()
	camera.near = 0.03
	camera.far = 40.0
	add_child(camera)
	_post_quad()
	_hover_mat = StandardMaterial3D.new()
	_hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_hover_mat.albedo_color = Color(0.16, 0.11, 0.05)
	_mark_mat = _hover_mat.duplicate() as StandardMaterial3D
	_process(0.0)


# ------------------------------------------------------------------ look

func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.01, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.32, 0.3)
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	e.fog_enabled = true
	e.fog_light_color = Color(0.1, 0.06, 0.07)
	e.fog_density = 0.025
	env.environment = e
	add_child(env)


## A light in every lamp bulb (art/src/make_garage_v3.py names them *Hang_Bulb* / *Lamp_Bulb*). The light is a
## child of the bulb, so it hides with the bulb (the sewing table's stages). A desk lamp on a bench also gets a
## spot onto the bench's work point: dim while you walk, a bright pool while you work there.
func _bulbs(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := str(m.name)
		var hang := nm.contains("Hang_Bulb")
		if not hang and not nm.contains("Lamp_Bulb"):
			continue
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.74, 0.46)
		l.light_energy = 1.7 if hang else 0.5
		l.omni_range = 4.2 if hang else 1.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = hang
		m.add_child(l)
		var id := _station_of(m)
		if hang or id == "" or not _stations[id].has("work"):
			continue
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.64, 0.32)
		spot.light_energy = LAMP_IDLE
		spot.spot_range = 1.8
		spot.spot_angle = 55.0
		spot.spot_attenuation = 0.9
		spot.shadow_enabled = true
		m.add_child(spot)
		var at := m.global_position
		var target := b2g(_stations[id]["work"])
		if not at.is_equal_approx(target):
			spot.look_at_from_position(at, target, Vector3.UP if absf((target - at).normalized().y) < 0.99 else Vector3.FORWARD)
		if not _bench_lights.has(id):
			_bench_lights[id] = []
		_bench_lights[id].append(spot)


func _post_quad() -> void:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	q.mesh = mesh
	_post = ShaderMaterial.new()
	_post.shader = DITHER
	q.material_override = _post
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(0, 0, -0.5)
	camera.add_child(q)


func set_flash(x: float) -> void:
	_post.set_shader_parameter("flash", x)


func set_darken(x: float) -> void:
	_post.set_shader_parameter("darken", x)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


# ------------------------------------------------------------------ stations, collision, picking

## The station a mesh belongs to: a prefix in a station's "objects" wins, else the nearest St_<id> above it.
func _station_of(m: Node) -> String:
	var nm := str(m.name)
	for id in _stations:
		for prefix in _stations[id].get("objects", []):
			if nm.begins_with(prefix):
				return id
	var n := m.get_parent()
	while n != null and n != self:
		var pn := str(n.name)
		if pn.begins_with("St_"):
			var id := pn.substr(3)
			if _stations.has(id):
				return id
		n = n.get_parent()
	return ""


func _stage_of(m: Node) -> String:
	var n := m.get_parent()
	while n != null and n != self:
		if SEW_STAGES.has(str(n.name)):
			return str(n.name)
		n = n.get_parent()
	return ""


## One StaticBody3D per station (and one for the room) with a box per mesh: you bump into them, and the view's
## ray picks them. Flat things on the floor (rugs, mats) and things up near the ceiling get no box.
func _bodies(root: Node) -> void:
	var room := _body("")
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	room.add_child(floor_shape)
	var by_id := {"": room}
	for node in SEW_STAGES:
		_stage_shapes[node] = []
		_stage_nodes[node] = root.find_child(node, true, false)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var id := _station_of(m)
		if id != "":
			if not _meshes.has(id):
				_meshes[id] = []
			_meshes[id].append(m)
		var gt := m.global_transform
		var aabb := m.get_aabb()
		var world_box := gt * aabb
		if world_box.end.y < 0.06 or world_box.position.y > 1.9:
			continue
		if not by_id.has(id):
			by_id[id] = _body(id)
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = (aabb.size * gt.basis.get_scale()).max(Vector3(0.04, 0.04, 0.04))
		shape.shape = b
		shape.transform = Transform3D(gt.basis.orthonormalized(), gt * aabb.get_center())
		(by_id[id] as StaticBody3D).add_child(shape)
		var stage := _stage_of(m)
		if stage != "":
			_stage_shapes[stage].append(shape)


func _body(id: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_body_station[body] = id
	return body


## Show the sewing table's stage you've earned (Crafting.bench_stage), and only its boxes collide.
func refresh_stages(state) -> void:
	var stage := Crafting.bench_stage(state, "armor") if state != null else 0
	for i in SEW_STAGES.size():
		var on := i == stage
		var n: Node3D = _stage_nodes.get(SEW_STAGES[i])
		if n:
			n.visible = on
		for s in _stage_shapes[SEW_STAGES[i]]:
			(s as CollisionShape3D).disabled = not on


func sew_stage_visible() -> String:
	for nm in SEW_STAGES:
		var n: Node3D = _stage_nodes.get(nm)
		if n and n.visible:
			return nm
	return ""


## The station in the centre of the view, within reach, or "".
func aim() -> String:
	if camera == null:
		return ""
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	return _body_station.get(hit["collider"], "")


func set_hover(id: String) -> void:
	if id == hovered:
		return
	var old := hovered
	hovered = id
	_paint(old)
	_paint(id)


func _paint(id: String) -> void:
	if id == "":
		return
	var mat: Material = null
	if id == hovered:
		mat = _hover_mat
	elif id == marked:
		mat = _mark_mat
	for m in _meshes.get(id, []):
		(m as MeshInstance3D).material_overlay = mat


## The TONIGHT board sent you to a station: turn the view to it and make it glow until you use it.
func guide_to(id: String) -> void:
	if not _stations.has(id):
		return
	var old := marked
	marked = id
	_paint(old)
	_paint(id)
	_mark_t = 0.0
	var d := station_center(id) - _eye_pos()
	_guide_yaw = _yaw + wrapf(atan2(-d.x, -d.z) - _yaw, -PI, PI)
	_guide_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
	_guide_t = 0.6


func clear_mark() -> void:
	var old := marked
	marked = ""
	_paint(old)


func station_center(id: String) -> Vector3:
	var ms: Array = _meshes.get(id, [])
	var c := Vector3.ZERO
	var n := 0
	for m in ms:
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		c += mi.global_transform * mi.get_aabb().get_center()
		n += 1
	if n == 0:
		return b2g(_stations.get(id, {}).get("look", [0, 0, 1]))
	return c / n


## Screen position (viewport pixels) of a station's centre, for labels.
func station_screen_pos(id: String) -> Vector2:
	if not _meshes.has(id):
		return Vector2(-100, -100)
	var c := station_center(id)
	if camera.is_position_behind(c):
		return Vector2(-100, -100)
	return camera.unproject_position(c)


## Show or hide every garage mesh whose name starts with prefix.
func set_prefix_visible(prefix: String, on: bool) -> void:
	for n in find_children(prefix + "*", "MeshInstance3D", true, false):
		(n as Node3D).visible = on


# ------------------------------------------------------------------ walking

func _player(data: Dictionary) -> void:
	player = CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = 1.75
	shape.shape = cap
	shape.position = Vector3(0, 0.875, 0)
	player.add_child(shape)
	add_child(player)
	if title_mode:
		return
	player.global_position = b2g(data.get("spawn", [-3.0, -4.2, 0.0]))
	face_point(b2g(data.get("spawn_look", [0, 2, 1.2])))


## Put the player somewhere (Blender coords) facing a point (tests, after an op).
func place(at_b: Array, look_b: Array) -> void:
	player.global_position = b2g(at_b)
	player.velocity = Vector3.ZERO
	face_point(b2g(look_b))


func face_point(p: Vector3) -> void:
	var d := p - _eye_pos()
	_yaw = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)


## Mouse look (relative motion in window pixels).
func look(rel: Vector2) -> void:
	var k := 0.0024 * look_sensitivity
	_yaw -= rel.x * k
	_pitch = clampf(_pitch - rel.y * k, deg_to_rad(-80.0), deg_to_rad(80.0))
	_guide_t = 0.0


func _eye_pos() -> Vector3:
	if player == null:
		return Vector3(0, EYE, 0)
	return player.global_position + Vector3(0, EYE, 0)


func _eye_transform() -> Transform3D:
	if title_mode:
		var p := b2g(TITLE_SPOT)
		var d := b2g(TITLE_LOOK) - p
		var yaw := atan2(-d.x, -d.z) + sin(_time * 0.06) * 0.55
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), p)
	var basis := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	var bob := Vector3(0, sin(_bob * 2.0) * 0.018 + sin(_time * 0.9) * 0.004, 0)
	return Transform3D(basis, _eye_pos() + bob)


func _physics_process(delta: float) -> void:
	if player == null or title_mode:
		return
	var input := move_override
	if input == Vector2.ZERO and walk_enabled and leaning == "" and _lean_dir == 0:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			input.y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			input.y -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			input.x += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			input.x -= 1.0
	if leaning != "" or _lean_dir != 0:
		input = Vector2.ZERO
	input = input.limit_length(1.0)
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var want := (fwd * input.y + right * input.x) * SPEED
	var k := 1.0 - exp(-(12.0 if input != Vector2.ZERO else 16.0) * delta)
	player.velocity.x = lerpf(player.velocity.x, want.x, k)
	player.velocity.z = lerpf(player.velocity.z, want.z, k)
	player.velocity.y = 0.0 if player.is_on_floor() else player.velocity.y - 9.8 * delta
	player.move_and_slide()
	var sp := Vector2(player.velocity.x, player.velocity.z).length()
	_bob += delta * sp * 3.2


# ------------------------------------------------------------------ using a station (the lean)

func lean(id: String) -> void:
	var s: Dictionary = _stations.get(id, {})
	if s.is_empty():
		s = Content.station(id)
	if s.is_empty():
		return
	leaning = id
	set_hover("")
	if marked == id:
		clear_mark()
	_lean_from = camera.global_transform if camera else _eye_transform()
	_lean_to = _look_xf(s["cam"], s["look"])
	_lean_dir = 1
	_lean_t = 0.0


## While leaned in: glide to another close-up (e.g. down onto the bench top to work).
func refocus(cam_b: Array, look_b: Array) -> void:
	if leaning == "":
		return
	_lean_from = camera.global_transform
	_lean_to = _look_xf(cam_b, look_b)
	_lean_dir = 1
	_lean_t = 0.0


static func _look_xf(cam_b: Array, look_b: Array) -> Transform3D:
	var pos := b2g(cam_b)
	var at := b2g(look_b)
	var up := Vector3.UP if absf((at - pos).normalized().y) < 0.99 else Vector3.FORWARD
	return Transform3D(Basis(), pos).looking_at(at, up)


func unlean() -> void:
	if leaning == "":
		return
	leaning = ""
	_lean_from = camera.global_transform
	_lean_dir = -1
	_lean_t = 0.0


func is_moving() -> bool:
	return _lean_dir != 0


## Old API (the swivel chair had a mouse-follow look); benches still call it. Nothing to do now.
func set_cursor(_pos: Vector2, _view_size: Vector2) -> void:
	pass


func _process(delta: float) -> void:
	_time += delta
	if _guide_t > 0.0:
		var g := 1.0 - exp(-9.0 * delta)
		_yaw = lerp_angle(_yaw, _guide_yaw, g)
		_pitch = lerpf(_pitch, _guide_pitch, g)
		_guide_t -= delta
	if marked != "":
		_mark_t += delta
		var p := 0.5 + 0.5 * sin(_mark_t * 6.0)
		_mark_mat.albedo_color = Color(0.25, 0.16, 0.04) * p
	var t := _eye_transform()
	if _lean_dir != 0:
		_lean_t = clampf(_lean_t + delta / 0.45, 0.0, 1.0)
	if _lean_dir > 0 or (leaning != "" and _lean_dir == 0):
		t = _lean_from.interpolate_with(_lean_to, _ease(_lean_t))
		if _lean_t >= 1.0 and _lean_dir > 0:
			_lean_dir = 0
			lean_finished.emit()
	elif _lean_dir < 0:
		t = _lean_from.interpolate_with(_eye_transform(), _ease(_lean_t))
		if _lean_t >= 1.0:
			_lean_dir = 0
	if _trauma > 0.001:
		var s := _trauma * _trauma
		t.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.02 * s
		t.basis = t.basis * Basis(Vector3.FORWARD, randf_range(-1, 1) * 0.02 * s)
		_trauma = maxf(0.0, _trauma - delta * 1.8)
	if camera:
		camera.global_transform = t
		var lean_k := 0.0
		if leaning != "":
			lean_k = _ease(_lean_t) if _lean_dir > 0 else 1.0
		elif _lean_dir < 0:
			lean_k = 1.0 - _ease(_lean_t)
		camera.fov = base_fov - 8.0 * lean_k
	_bench_lamp_tick(delta)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# ------------------------------------------------------------------ bench lamps

const LAMP_IDLE := 0.8
const LAMP_WORK := 6.0


func _bench_lamp_tick(delta: float) -> void:
	var k := 1.0 - exp(-delta * 4.0)
	for id in _bench_lights:
		var on: bool = leaning == id
		for spot in _bench_lights[id]:
			(spot as SpotLight3D).light_energy = lerpf((spot as SpotLight3D).light_energy, LAMP_WORK if on else LAMP_IDLE, k)
