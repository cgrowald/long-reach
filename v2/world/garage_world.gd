extends Node3D
## The v2 garage in 3D: loads art/garage_v2.glb, adds the gritty dithered materials and the light,
## turns the swivel-chair camera between four walls, leans in to stations, and picks what's under the mouse.
## Positions in data/v2/stations.json are Blender coords; b2g() converts them.

signal lean_finished

const Content := preload("res://v2/sim/content.gd")
const GLB := "res://art/garage_v2.glb"
const DITHER := preload("res://v2/world/dither.gdshader")

var camera: Camera3D
var facing := 0                  # index into facings
var leaning := ""                # station id we're leaned into, or ""
var hovered := ""
var look_sensitivity := 1.0
var base_fov := 70.0
var title_mode := false          # slow drift for the title screen

var _facings: Array = []
var _stations: Dictionary = {}   # id -> station def
var _meshes: Dictionary = {}     # station id -> Array[MeshInstance3D]
var _body_station: Dictionary = {}
var _seat := Vector3.ZERO
var _yaw := 0.0
var _yaw_target := 0.0
var _pitch := 0.0
var _pitch_target := 0.0
var _cursor := Vector2.ZERO      # -1..1 from the view centre
var _lean_t := 0.0               # 0 = in the chair, 1 = leaned in
var _lean_dir := 0
var _lean_from := Transform3D()
var _lean_to := Transform3D()
var _trauma := 0.0
var _time := 0.0
var _post: ShaderMaterial
var _hover_mat: StandardMaterial3D
var _bulb: OmniLight3D


static func b2g(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[2]), -float(a[1]))


func setup() -> void:
	var data := Content.stations()
	_facings = data.get("facings", [])
	_seat = b2g(data.get("seat", [0, 0, 1.2]))
	for s in data.get("stations", []):
		_stations[s["id"]] = s
	var scene: PackedScene = load(GLB)
	var garage := scene.instantiate()
	add_child(garage)
	_materials(garage)
	_lights()
	_clickables(garage)
	camera = Camera3D.new()
	camera.near = 0.03
	camera.far = 40.0
	add_child(camera)
	_post_quad()
	_hover_mat = StandardMaterial3D.new()
	_hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_hover_mat.albedo_color = Color(0.16, 0.11, 0.05)
	set_facing(0, true)


# ------------------------------------------------------------------ look

func _grit() -> Texture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_VALUE
	n.frequency = 0.35
	n.fractal_octaves = 2
	var t := NoiseTexture2D.new()
	t.width = 32
	t.height = 32
	t.seamless = true
	t.noise = n
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.6, 0.62))
	ramp.set_color(1, Color(1, 1, 1))
	t.color_ramp = ramp
	return t


func _materials(root: Node) -> void:
	var grit := _grit()
	var done := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			if not done.has(src):
				var d := src.duplicate() as StandardMaterial3D
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				d.roughness = 1.0
				d.metallic = 0.0
				d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				if not d.emission_enabled:
					d.albedo_texture = grit
					d.uv1_triplanar = true
					d.uv1_world_triplanar = true
					d.uv1_scale = Vector3(2.2, 2.2, 2.2)
				else:
					d.emission_energy_multiplier = maxf(d.emission_energy_multiplier, 1.0) * 1.6
				done[src] = d
			m.set_surface_override_material(i, done[src])


func _lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.01, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.22, 0.42)
	e.ambient_light_energy = 0.22
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	e.fog_enabled = true
	e.fog_light_color = Color(0.09, 0.05, 0.1)
	e.fog_density = 0.06
	e.volumetric_fog_enabled = false
	env.environment = e
	add_child(env)
	# The bare bulb: warm, hard, the one light in the room.
	_bulb = OmniLight3D.new()
	_bulb.light_color = Color(1.0, 0.78, 0.52)
	_bulb.light_energy = 2.4
	_bulb.omni_range = 6.0
	_bulb.omni_attenuation = 1.4
	_bulb.shadow_enabled = true
	_bulb.position = b2g([0, 0.35, 2.05])
	add_child(_bulb)
	# Sodium street light through the window: orange, slanting down across the desk.
	var street := SpotLight3D.new()
	street.light_color = Color(1.0, 0.5, 0.15)
	street.light_energy = 9.0
	street.spot_range = 7.0
	street.spot_angle = 32.0
	street.shadow_enabled = true
	add_child(street)
	street.position = b2g([1.6, 3.6, 2.6])
	street.look_at(b2g([0.6, 0.6, 0.2]))
	# The CRT's red glow.
	_omni(Color(1.0, 0.3, 0.2), 1.2, 1.4, [-0.35, 1.05, 1.0])
	# The scope on the hacking bench.
	_omni(Color(0.4, 1.0, 0.35), 0.5, 0.9, [2.2, 1.35, 1.1])
	# Warm light under the house door.
	_omni(Color(1.0, 0.7, 0.4), 0.8, 1.3, [-1.7, -2.4, 0.1])
	# Street glow under the roller door.
	_omni(Color(1.0, 0.5, 0.15), 0.7, 1.6, [0.9, -2.4, 0.1])


func _omni(col: Color, energy: float, rng: float, at: Array) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = b2g(at)
	add_child(l)
	return l


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


# ------------------------------------------------------------------ picking

func _clickables(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var id := _station_for(str(m.name))
		if id == "":
			continue
		if not _meshes.has(id):
			_meshes[id] = []
		_meshes[id].append(m)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		var aabb := m.get_aabb()
		b.size = aabb.size.max(Vector3(0.04, 0.04, 0.04))
		shape.shape = b
		shape.position = aabb.get_center()
		body.add_child(shape)
		m.add_child(body)
		_body_station[body] = id


func _station_for(node_name: String) -> String:
	for id in _stations:
		for prefix in _stations[id].get("objects", []):
			if node_name.begins_with(prefix):
				return id
	return ""


## Station id under a point of the (low-res) viewport, or "".
func pick(pos: Vector2) -> String:
	if camera == null:
		return ""
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 8.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	return _body_station.get(hit["collider"], "")


func set_hover(id: String) -> void:
	if id == hovered:
		return
	for m in _meshes.get(hovered, []):
		(m as MeshInstance3D).material_overlay = null
	hovered = id
	for m in _meshes.get(id, []):
		(m as MeshInstance3D).material_overlay = _hover_mat


## Screen position (viewport pixels) of a station's centre, for labels.
func station_screen_pos(id: String) -> Vector2:
	var ms: Array = _meshes.get(id, [])
	if ms.is_empty():
		return Vector2(-100, -100)
	var c := Vector3.ZERO
	for m in ms:
		c += (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb().get_center()
	c /= ms.size()
	if camera.is_position_behind(c):
		return Vector2(-100, -100)
	return camera.unproject_position(c)


# ------------------------------------------------------------------ camera

func facing_name(i := -999) -> String:
	var f: Dictionary = _facings[wrapi(facing if i == -999 else i, 0, _facings.size())]
	return f.get("name", "")


func facing_count() -> int:
	return _facings.size()


func set_facing(i: int, instant := false) -> void:
	facing = wrapi(i, 0, _facings.size())
	var target := b2g(_facings[facing]["look"])
	var d := target - _seat
	var yaw := atan2(-d.x, -d.z)
	# Turn the short way round.
	var diff := wrapf(yaw - _yaw_target, -PI, PI)
	_yaw_target += diff
	_pitch_target = atan2(d.y, Vector2(d.x, d.z).length())
	if instant:
		_yaw = _yaw_target
		_pitch = _pitch_target


func turn(dir: int) -> void:
	set_facing(facing + dir)


func station_facing(id: String) -> int:
	var f: String = _stations.get(id, {}).get("facing", "")
	for i in _facings.size():
		if _facings[i]["id"] == f:
			return i
	return facing


func lean(id: String) -> void:
	var s: Dictionary = _stations.get(id, {})
	if s.is_empty():
		return
	leaning = id
	set_hover("")
	_lean_from = _chair_transform()
	var pos := b2g(s["cam"])
	_lean_to = Transform3D(Basis(), pos).looking_at(b2g(s["look"]), Vector3.UP)
	_lean_dir = 1
	_lean_t = 0.0


## While leaned in: glide to another close-up (e.g. down onto the bench top to work).
func refocus(cam_b: Array, look_b: Array) -> void:
	if leaning == "":
		return
	_lean_from = camera.global_transform
	_lean_to = Transform3D(Basis(), b2g(cam_b)).looking_at(b2g(look_b), Vector3.UP)
	_lean_dir = 1
	_lean_t = 0.0


## Show or hide every garage mesh whose name starts with prefix (e.g. a tarp once a bench is opened).
func set_prefix_visible(prefix: String, on: bool) -> void:
	for n in find_children(prefix + "*", "MeshInstance3D", true, false):
		(n as Node3D).visible = on


func unlean() -> void:
	if leaning == "":
		return
	leaning = ""
	_lean_dir = -1
	_lean_t = 0.0


func is_moving() -> bool:
	return _lean_dir != 0


func set_cursor(pos: Vector2, view_size: Vector2) -> void:
	_cursor = ((pos / view_size) * 2.0 - Vector2.ONE).clamp(Vector2(-1, -1), Vector2(1, 1))


func _chair_transform() -> Transform3D:
	var look := look_sensitivity * (0.0 if title_mode else 1.0)
	var yaw := _yaw - _cursor.x * deg_to_rad(14.0) * look
	var pitch := _pitch - _cursor.y * deg_to_rad(9.0) * look
	var breath := sin(_time * 0.9) * 0.004
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	return Transform3D(basis, _seat + Vector3(0, breath, 0))


func _process(delta: float) -> void:
	_time += delta
	if title_mode:
		_yaw_target += delta * 0.03
	_yaw = lerp_angle(_yaw, _yaw_target, 1.0 - exp(-7.0 * delta))
	_pitch = lerpf(_pitch, _pitch_target, 1.0 - exp(-7.0 * delta))
	var t := _chair_transform()
	if _lean_dir != 0:
		_lean_t = clampf(_lean_t + delta / 0.45, 0.0, 1.0)
		if _lean_dir < 0:
			_lean_from = _chair_transform()
	if _lean_dir > 0 or leaning != "":
		var k := _ease(_lean_t)
		t = _lean_from.interpolate_with(_lean_to, k)
		if _lean_t >= 1.0 and _lean_dir > 0:
			_lean_dir = 0
			lean_finished.emit()
	elif _lean_dir < 0:
		var k := _ease(_lean_t)
		t = _lean_to.interpolate_with(_chair_transform(), k)
		if _lean_t >= 1.0:
			_lean_dir = 0
	if _trauma > 0.001:
		var s := _trauma * _trauma
		t.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.02 * s
		t.basis = t.basis * Basis(Vector3.FORWARD, randf_range(-1, 1) * 0.02 * s)
		_trauma = maxf(0.0, _trauma - delta * 1.8)
	camera.global_transform = t
	var lean_k := _ease(_lean_t) if (leaning != "" or _lean_dir != 0) else 0.0
	if _lean_dir < 0:
		lean_k = 1.0 - _ease(_lean_t)
	camera.fov = base_fov - 8.0 * lean_k
	# The bulb flickers now and then.
	_bulb.light_energy = 2.4 * (0.55 if fmod(_time, 7.3) < 0.08 else 1.0)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
