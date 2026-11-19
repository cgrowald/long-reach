extends Node3D
## Placeholder unit: capsule body, visor showing facing (-Z), name tag, selection ring.
## M0 only walks a patrol loop so pause and follow-cam can be tested.
## Real movement/orders arrive in M1.

var callsign: String = "OP"
var team_color: Color = Color(0.25, 0.5, 0.95)
var patrol_points: Array[Vector3] = []
var speed: float = 2.5

var _patrol_index: int = 0
var _ring: MeshInstance3D


func setup(p_callsign: String, p_color: Color, p_points: Array[Vector3]) -> void:
	callsign = p_callsign
	team_color = p_color
	patrol_points = p_points


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_visuals()
	if not patrol_points.is_empty():
		global_position = patrol_points[0]
		_patrol_index = 1 % patrol_points.size()


func set_selected(value: bool) -> void:
	_ring.visible = value


func _process(delta: float) -> void:
	if patrol_points.size() < 2:
		return
	var target: Vector3 = patrol_points[_patrol_index]
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist < 0.05:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		return
	var step: float = minf(speed * delta, dist)
	global_position += to_target / dist * step
	look_at(global_position + to_target, Vector3.UP)


func _build_visuals() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = team_color
	body_mat.roughness = 0.8

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	body.mesh = capsule
	body.material_override = body_mat
	body.position.y = 0.9
	add_child(body)

	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.08, 0.08, 0.1)
	var visor := MeshInstance3D.new()
	var visor_box := BoxMesh.new()
	visor_box.size = Vector3(0.36, 0.12, 0.14)
	visor.mesh = visor_box
	visor.material_override = visor_mat
	visor.position = Vector3(0.0, 1.55, -0.26)
	add_child(visor)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.2)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.position.y = 0.03
	_ring.visible = false
	add_child(_ring)

	var tag := Label3D.new()
	tag.text = callsign
	tag.position.y = 2.25
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 40
	tag.outline_size = 8
	tag.modulate = team_color.lightened(0.4)
	add_child(tag)
