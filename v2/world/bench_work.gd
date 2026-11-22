extends Node3D
## The 3D work area on a bench top: the piece you're working on, a task light, the mouse-to-bench-plane
## mapping, and the step (verb) currently running. Local frame: origin on the bench top, +X = screen right,
## -Z = away from you, +Y = up.

signal step_done(score: float)
signal popup(text: String, world_pos: Vector3, good: bool)

const Verbs := preload("res://v2/world/verbs.gd")

var camera: Camera3D
var piece: Node3D
var piece_kind := ""
var verb                           # the running Verbs.* node
var hit := Vector3.ZERO            # cursor on the bench plane (local)
var has_hit := false
var _light: SpotLight3D
var _mats := {}


## anchor: bench top point (Godot coords). cam_pos: where the camera will sit (to orient the frame).
func setup(p_camera: Camera3D, anchor: Vector3, cam_pos: Vector3, kind: String) -> void:
	camera = p_camera
	var away := anchor - cam_pos
	away.y = 0.0
	away = away.normalized()
	global_transform = Transform3D(Basis.looking_at(away, Vector3.UP), anchor)
	_light = SpotLight3D.new()
	_light.light_color = Color(1.0, 0.86, 0.66)
	_light.light_energy = 1.8
	_light.spot_range = 1.6
	_light.spot_angle = 40.0
	_light.shadow_enabled = true
	add_child(_light)
	_light.position = Vector3(0.1, 0.75, 0.15)
	_light.look_at(global_position, Vector3.FORWARD)
	make_piece(kind)


func make_piece(kind: String) -> void:
	if piece:
		piece.queue_free()
	piece_kind = kind
	piece = Node3D.new()
	add_child(piece)
	match kind:
		"cloth":
			box(Vector3(0.3, 0.004, 0.22), Color(0.36, 0.42, 0.5), Vector3(0, 0.002, 0), piece)
		"bag":
			box(Vector3(0.32, 0.004, 0.26), Color(0.2, 0.36, 0.55), Vector3(0, 0.002, 0), piece)
			for i in 6:
				box(Vector3(0.32, 0.0045, 0.006), Color(0.85, 0.85, 0.85), Vector3(0, 0.002, -0.12 + i * 0.048), piece)
		"metal":
			box(Vector3(0.2, 0.04, 0.08), Color(0.5, 0.52, 0.55), Vector3(0, 0.02, 0), piece)
		"board":
			box(Vector3(0.16, 0.006, 0.1), Color(0.12, 0.4, 0.2), Vector3(0, 0.003, 0), piece)
		_:
			box(Vector3(0.2, 0.02, 0.12), Color(0.5, 0.5, 0.5), Vector3(0, 0.01, 0), piece)


func top() -> float:
	match piece_kind:
		"metal":
			return 0.04
		"board":
			return 0.006
	return 0.004


# ------------------------------------------------------------------ steps

func start_step(step: Dictionary) -> void:
	if verb:
		verb.queue_free()
	verb = Verbs.make(step.get("verb", "fit"))
	add_child(verb)
	verb.done.connect(func(s: float) -> void: step_done.emit(s))
	verb.begin(self, step)


func stop() -> void:
	if verb:
		verb.queue_free()
		verb = null


func pointer(vp_pos: Vector2) -> void:
	var origin := camera.project_ray_origin(vp_pos)
	var dir := camera.project_ray_normal(vp_pos)
	var plane := Plane(Vector3.UP, global_position.y + top())
	var p = plane.intersects_ray(origin, dir)
	has_hit = p != null
	if has_hit:
		hit = to_local(p)
		if verb and not verb._finished:
			verb.moved()


func press() -> void:
	if verb and has_hit and not verb._finished:
		verb.holding = true
		verb.press()


func release() -> void:
	if verb and verb.holding:
		verb.holding = false
		verb.release()


func key_action() -> void:
	if verb and not verb._finished:
		verb.key()


func say(text: String, at: Vector3, good: bool) -> void:
	popup.emit(text, to_global(at), good)


# ------------------------------------------------------------------ mesh helpers

func mat(col: Color, glow := false) -> StandardMaterial3D:
	var key := str(col) + str(glow)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 1.0
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


func box(size: Vector3, col: Color, pos: Vector3, parent: Node = null, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat(col, glow)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func cyl(r: float, h: float, col: Color, pos: Vector3, parent: Node = null, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat(col, glow)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi
