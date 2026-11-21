extends Node3D
## The garage in 3D: loads art/garage.glb, lights it, turns the seated camera between views,
## leans in to the laptop, and finds which object is under the mouse.

signal arrived(view: String)

const GLB := "res://art/garage.glb"
const SEAT := Vector3(0.0, 1.25, 0.28)          # Godot coords (Blender x, z, -y)
const LOOK := {
	"bench": Vector3(-1.05, 1.05, -0.85),
	"laptop": Vector3(0.0, 0.98, -0.85),
	"window": Vector3(2.3, 1.55, -1.25),
	"door": Vector3(2.5, 1.15, 0.2),
}

var camera: Camera3D
var view: String = "laptop"
var using_laptop := false
var screen_mesh: MeshInstance3D
var things: Dictionary = {}           # thing id -> def
var _body_thing: Dictionary = {}      # StaticBody3D -> thing id
var _nodes: Dictionary = {}           # name -> Node3D
var _tween: Tween
var _dof: CameraAttributesPractical
var _focus_dist := 1.0


func setup(screen_texture: Texture2D) -> void:
	var data := _load_json("res://data/terminal/room.json")
	things = data.get("things", {})
	var scene: PackedScene = load(GLB)
	var garage := scene.instantiate()
	add_child(garage)
	for n in garage.find_children("*", "MeshInstance3D", true, false):
		_nodes[str(n.name)] = n
	screen_mesh = _nodes.get("Screen")
	if screen_mesh:
		var m := StandardMaterial3D.new()
		m.albedo_texture = screen_texture
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		screen_mesh.material_override = m
	if _nodes.has("Window_Glass"):
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.35, 0.45, 0.6, 0.22)
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.roughness = 0.1
		_nodes["Window_Glass"].material_override = g
	_make_clickable()
	_lights()
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.02
	add_child(camera)
	# Depth of field with autofocus on whatever is in the middle of your view.
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_near_enabled = true
	_dof.dof_blur_amount = 0.09
	camera.attributes = _dof
	camera.position = SEAT
	camera.look_at(LOOK["laptop"])


func _load_json(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


# ------------------------------------------------------------- lights and mood

func _lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.01, 0.015)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.34, 0.45)
	e.ambient_light_energy = 0.12
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.05, 0.07)
	e.fog_density = 0.05
	env.environment = e
	add_child(env)
	# Bench lamp: warm, pointing down at the work area.
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 6.0
	lamp.spot_range = 3.5
	lamp.spot_angle = 55.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(0.36, 1.33, -0.74)
	lamp.look_at(Vector3(-0.15, 0.9, -0.75))
	var fill := OmniLight3D.new()       # bounce from the bench
	fill.light_color = Color(1.0, 0.7, 0.45)
	fill.light_energy = 0.35
	fill.omni_range = 2.5
	fill.position = Vector3(-0.2, 1.2, -0.5)
	add_child(fill)
	# The laptop's cold glow.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 0.7, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 1.2
	glow.position = Vector3(0.0, 1.05, -0.65)
	add_child(glow)
	# Streetlight through the window.
	var street := OmniLight3D.new()
	street.light_color = Color(0.5, 0.6, 0.85)
	street.light_energy = 1.2
	street.omni_range = 2.5
	street.position = Vector3(1.8, 2.0, -1.6)
	add_child(street)


# ------------------------------------------------------------- picking

func _make_clickable() -> void:
	for id in things:
		var prefixes: Array = things[id].get("nodes", [])
		for nm in _nodes:
			for p in prefixes:
				if str(nm).begins_with(str(p)):
					var mi: MeshInstance3D = _nodes[nm]
					var body := StaticBody3D.new()
					var shape := CollisionShape3D.new()
					var b := BoxShape3D.new()
					var aabb := mi.get_aabb()
					b.size = aabb.size.max(Vector3(0.02, 0.02, 0.02))
					shape.shape = b
					shape.position = aabb.get_center()
					body.add_child(shape)
					mi.add_child(body)
					_body_thing[body] = id
					break


## Which thing is under this point of the 3D viewport ("" for nothing).
func pick(viewport_pos: Vector2) -> String:
	var from := camera.project_ray_origin(viewport_pos)
	var to := from + camera.project_ray_normal(viewport_pos) * 6.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	return str(_body_thing.get(hit["collider"], ""))


func set_visible_node(name: String, on: bool) -> void:
	if _nodes.has(name):
		_nodes[name].visible = on


# ------------------------------------------------------------- views

func turn(dir: int) -> void:
	var order: Array = ["bench", "laptop", "window", "door"]
	var i := clampi(order.find(view) + dir, 0, order.size() - 1)
	look_view(order[i])


func look_view(v: String) -> void:
	view = v
	using_laptop = false
	var target := Transform3D(Basis(), SEAT).looking_at(LOOK[v], Vector3.UP)
	_move_to(target, 0.45, v)


## Lean in so the laptop screen fills the given rect of a viewport of size vp_size.
func use_laptop(screen_rect: Rect2, vp_size: Vector2, instant: bool = false) -> void:
	view = "laptop"
	using_laptop = true
	_move_to(laptop_pose(screen_rect, vp_size), 0.0 if instant else 0.55, "use")


func laptop_pose(screen_rect: Rect2, vp_size: Vector2) -> Transform3D:
	if screen_mesh == null:
		return camera.global_transform
	var arr := screen_mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var g := screen_mesh.global_transform
	var pts: Array = []
	for v in verts:
		pts.append(g * v)
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= pts.size()
	# Screen axes from its extent: "up" is the short side, "right" the long one.
	var a: Vector3 = pts[1] - pts[0]
	var b: Vector3 = pts[2] - pts[0]
	var normal := a.cross(b).normalized()
	if normal.dot(SEAT - center) < 0:
		normal = -normal
	var right := Vector3.RIGHT
	var up := normal.cross(right).normalized()
	if up.y < 0:
		up = -up
	right = up.cross(normal).normalized()
	var h := 0.0
	for p in pts:
		h = maxf(h, absf((p - center).dot(up)) * 2.0)
	var tanh := tan(deg_to_rad(camera.fov) / 2.0)
	var d := h * vp_size.y / (screen_rect.size.y * 2.0 * tanh)
	# Shift so the screen lands on screen_rect's center rather than the viewport center.
	var px_per_unit := vp_size.y / (2.0 * d * tanh)
	var dy := (vp_size.y / 2.0 - screen_rect.get_center().y) / px_per_unit
	var dx := (screen_rect.get_center().x - vp_size.x / 2.0) / px_per_unit
	var origin := center + normal * d - up * dy - right * dx
	return Transform3D(Basis(right, up, normal), origin)


func _move_to(t: Transform3D, secs: float, arrive: String) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if secs <= 0.0:
		camera.global_transform = t
		arrived.emit(arrive)
		return
	var start := camera.global_transform
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(w: float): camera.global_transform = start.interpolate_with(t, w), 0.0, 1.0, secs)
	_tween.tween_callback(func(): arrived.emit(arrive))


func _process(delta: float) -> void:
	if camera == null or _dof == null:
		return
	# Autofocus: find what the middle of the view is looking at, ease the focus there.
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 8.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var want: float = from.distance_to(hit["position"]) if not hit.is_empty() else 3.0
	if using_laptop:
		want = 0.45
	_focus_dist = lerpf(_focus_dist, want, clampf(delta * 4.0, 0.0, 1.0))
	_dof.dof_blur_far_distance = _focus_dist + 0.6
	_dof.dof_blur_far_transition = maxf(0.8, _focus_dist * 0.9)
	_dof.dof_blur_near_distance = maxf(0.05, _focus_dist * 0.55)
	_dof.dof_blur_near_transition = maxf(0.05, _focus_dist * 0.3)
