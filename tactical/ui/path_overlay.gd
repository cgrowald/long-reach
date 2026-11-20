extends MeshInstance3D
## Draws each friendly unit's planned route on the ground (bright when selected).
## Redrawn every frame, including while paused, so you see orders as you plan them.

const LIFT := Vector3(0.0, 0.08, 0.0)
const COLOR_SELECTED := Color(0.4, 0.85, 1.0, 0.95)
const COLOR_OTHER := Color(0.4, 0.85, 1.0, 0.3)
const END_MARK := 0.25
const COLOR_FACE := Color(1.0, 0.85, 0.3, 0.95)
const COLOR_FACE_DIM := Color(1.0, 0.85, 0.3, 0.35)
const FACE_LEN := 1.4
const COLOR_HOLD := Color(1.0, 0.4, 0.3, 0.95)
const HOLD_MARK := 0.4
const COLOR_FOCUS := Color(1.0, 0.85, 0.3, 0.95)
const COLOR_FOCUS_DIM := Color(1.0, 0.85, 0.3, 0.35)
const DIAMOND := 0.3

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
		if pts.size() < 2 and not u.is_holding():
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
		# Focus (pie) points: diamond on the route + sight line to the watched point.
		var bright: bool = _selection.is_selected(u)
		var fc: Color = COLOR_FOCUS if bright else COLOR_FOCUS_DIM
		for m in u.get_focus_marks():
			var a: Vector3 = (m["pos"] as Vector3) + LIFT
			for k in 4:
				var d0 := Vector3(DIAMOND, 0, 0).rotated(Vector3.UP, PI * 0.5 * k)
				var d1 := Vector3(DIAMOND, 0, 0).rotated(Vector3.UP, PI * 0.5 * (k + 1))
				verts.append(a + d0)
				verts.append(a + d1)
				cols.append(fc)
				cols.append(fc)
			if m["focus"] != null:
				verts.append(a)
				verts.append((m["focus"] as Vector3) + LIFT)
				cols.append(Color(fc, fc.a * 0.6))
				cols.append(Color(fc, fc.a * 0.6))
		var active: Variant = u.get_active_focus()
		if active != null and bright:
			verts.append(u.global_position + LIFT)
			verts.append((active as Vector3) + LIFT)
			cols.append(Color(COLOR_FOCUS, 0.5))
			cols.append(Color(COLOR_FOCUS, 0.5))
		# Go-code hold points: a box around the spot.
		for h in u.get_planned_holds():
			var c: Vector3 = h + LIFT
			var corners: Array[Vector3] = [
				c + Vector3(-HOLD_MARK, 0, -HOLD_MARK), c + Vector3(HOLD_MARK, 0, -HOLD_MARK),
				c + Vector3(HOLD_MARK, 0, HOLD_MARK), c + Vector3(-HOLD_MARK, 0, HOLD_MARK)]
			for k in 4:
				verts.append(corners[k])
				verts.append(corners[(k + 1) % 4])
				cols.append(COLOR_HOLD)
				cols.append(COLOR_HOLD)
		# Facing arrows where a leg ends with a "look this way" order.
		var face_color: Color = COLOR_FACE if _selection.is_selected(u) else COLOR_FACE_DIM
		for f in u.get_planned_facings():
			var p: Vector3 = (f[0] as Vector3) + LIFT
			var yaw: float = f[1]
			var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var tip: Vector3 = p + dir * FACE_LEN
			var side: Vector3 = dir.cross(Vector3.UP) * 0.3
			for seg in [[p, tip], [tip, tip - dir * 0.4 + side], [tip, tip - dir * 0.4 - side]]:
				verts.append(seg[0])
				verts.append(seg[1])
				cols.append(face_color)
				cols.append(face_color)
	if verts.is_empty():
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES, _mat)
	for i in verts.size():
		_imesh.surface_set_color(cols[i])
		_imesh.surface_add_vertex(verts[i])
	_imesh.surface_end()
