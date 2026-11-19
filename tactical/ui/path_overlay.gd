extends MeshInstance3D
## Draws each friendly unit's planned route on the ground (bright when selected).
## Redrawn every frame, including while paused, so you see orders as you plan them.

const LIFT := Vector3(0.0, 0.08, 0.0)
const COLOR_SELECTED := Color(0.4, 0.85, 1.0, 0.95)
const COLOR_OTHER := Color(0.4, 0.85, 1.0, 0.3)
const END_MARK := 0.25

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
	_mat.no_depth_test = true


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for u in _units:
		if u.is_dead:
			continue
		var pts: Array[Vector3] = u.get_planned_points()
		if pts.size() < 2:
			continue
		var color: Color = COLOR_SELECTED if _selection.is_selected(u) else COLOR_OTHER
		for i in pts.size() - 1:
			verts.append(pts[i] + LIFT)
			verts.append(pts[i + 1] + LIFT)
			cols.append(color)
			cols.append(color)
		var end: Vector3 = pts[pts.size() - 1] + LIFT
		for d in [Vector3(END_MARK, 0.0, END_MARK), Vector3(END_MARK, 0.0, -END_MARK)]:
			verts.append(end - d)
			verts.append(end + d)
			cols.append(color)
			cols.append(color)
	if verts.is_empty():
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _mat)
	for i in verts.size():
		_imesh.surface_set_color(cols[i])
		_imesh.surface_add_vertex(verts[i])
	_imesh.surface_end()
