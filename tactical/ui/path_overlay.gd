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
const DASH := 0.2
const PIE_ICON := 0.55

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


func _line(verts: PackedVector3Array, cols: PackedColorArray, a: Vector3, b: Vector3, c: Color) -> void:
	verts.append(a)
	verts.append(b)
	cols.append(c)
	cols.append(c)


## Sight line from a to b. Pie: dotted, with a pie icon (circle + filled slice) at b.
func _sight(verts: PackedVector3Array, cols: PackedColorArray, a: Vector3, b: Vector3, c: Color, pie: bool) -> void:
	if not pie:
		_line(verts, cols, a, b, c)
		return
	var length: float = a.distance_to(b)
	var dashes: int = maxi(1, int(length / (DASH * 2.0)))
	for i in dashes:
		var t0: float = float(i) / float(dashes)
		var t1: float = t0 + 0.5 / float(dashes)
		_line(verts, cols, a.lerp(b, t0), a.lerp(b, t1), c)
	var r: float = PIE_ICON
	var prev: Vector3 = b + Vector3(r, 0, 0)
	for k in range(1, 17):
		var p: Vector3 = b + Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0)) * r
		_line(verts, cols, prev, p, c)
		prev = p
	for k in 4:  # filled-looking slice: fan of lines
		var ang: float = -PI * 0.5 + k * (PI * 0.5 / 3.0)
		_line(verts, cols, b, b + Vector3(cos(ang), 0, sin(ang)) * r, c)


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for u in _units:
		if u.is_dead:
			continue
		var pts: Array[Vector3] = u.get_planned_points()
		var bright: bool = _selection.is_selected(u)
		var color: Color = COLOR_SELECTED if bright else COLOR_OTHER
		if pts.size() >= 2:
			for i in pts.size() - 1:
				_line(verts, cols, pts[i] + LIFT, pts[i + 1] + LIFT, color)
			var end: Vector3 = pts[pts.size() - 1] + LIFT
			_line(verts, cols, end - Vector3(END_MARK, 0, END_MARK), end + Vector3(END_MARK, 0, END_MARK), color)
			_line(verts, cols, end - Vector3(END_MARK, 0, -END_MARK), end + Vector3(END_MARK, 0, -END_MARK), color)
		var fc: Color = COLOR_FOCUS if bright else COLOR_FOCUS_DIM
		# Look / pie points along the route: diamond on the route, line to the watched point.
		# Look = solid line; pie = dotted line with a pie icon on the target.
		for m in u.get_focus_marks():
			var a: Vector3 = (m["pos"] as Vector3) + LIFT
			for k in 4:
				var d0 := Vector3(DIAMOND, 0, 0).rotated(Vector3.UP, PI * 0.5 * k)
				var d1 := Vector3(DIAMOND, 0, 0).rotated(Vector3.UP, PI * 0.5 * (k + 1))
				_line(verts, cols, a + d0, a + d1, fc)
			if m["focus"] != null:
				_sight(verts, cols, a, (m["focus"] as Vector3) + LIFT, fc, bool(m.get("pie", false)))
		# Old-style pie maneuver legs (still supported by the unit).
		for pt in u.get_pie_targets():
			_sight(verts, cols, (pt[0] as Vector3) + LIFT, (pt[1] as Vector3) + LIFT, fc, true)
		var active: Variant = u.get_active_focus()
		if active != null and bright:
			_sight(verts, cols, u.global_position + LIFT, (active as Vector3) + LIFT, Color(fc, 0.6), u.is_focus_pie())
		if pts.size() < 2 and not u.is_holding():
			continue		# Go-code hold points: a box around the spot.
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
