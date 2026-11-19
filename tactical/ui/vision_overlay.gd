extends MeshInstance3D
## Draws each friendly soldier's field-of-view cone on the ground, clipped by walls,
## so you can see exactly which angles are covered. Low cover does not block view.

const RAYS := 40
const DRAW_RANGE := 14.0  # drawn length only; real sight range comes from unit data
const RAY_HEIGHT := 1.5
const LIFT := 0.06
const COLOR_SELECTED := Color(1.0, 1.0, 0.9, 0.22)
const COLOR_OTHER := Color(1.0, 1.0, 0.9, 0.07)

var _units: Array = []
var _selection
var _imesh: ImmediateMesh
var _mat: StandardMaterial3D


func setup(units: Array, selection) -> void:
	_units = units
	_selection = selection


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


# Physics step: raycasts are only safe here.
func _physics_process(_delta: float) -> void:
	_imesh.clear_surfaces()
	var space := get_world_3d().direct_space_state
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for u in _units:
		if u.is_dead:
			continue
		var color: Color = COLOR_SELECTED if _selection.is_selected(u) else COLOR_OTHER
		var center: Vector3 = u.global_position
		var eye: Vector3 = center + Vector3(0.0, RAY_HEIGHT, 0.0)
		var half: float = deg_to_rad(u.fov_deg) * 0.5
		var reach: float = minf(u.vision_range, DRAW_RANGE)
		var prev := Vector3.ZERO
		for i in RAYS + 1:
			var yaw: float = u.rotation.y - half + (2.0 * half) * float(i) / float(RAYS)
			var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var end: Vector3 = eye + dir * reach
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, end, 1))
			var p: Vector3 = (hit["position"] as Vector3) if not hit.is_empty() else end
			p.y = LIFT
			if i > 0:
				verts.append(Vector3(center.x, LIFT, center.z))
				verts.append(prev)
				verts.append(p)
				cols.append(color)
				cols.append(color)
				cols.append(color)
			prev = p
	if verts.is_empty():
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for i in verts.size():
		_imesh.surface_set_color(cols[i])
		_imesh.surface_add_vertex(verts[i])
	_imesh.surface_end()
