extends Node
## Player input for selecting friendly units and giving them orders.
## Works while paused (orders can be planned during pause).
##
##   Left click            select unit (Shift = add/remove)
##   Left drag             box select (Shift = add)
##   Double-click          select + camera follow
##   Right click ground    move selected (Shift = queue waypoint)
##   Right drag            move, then face the drag direction on arrival
##   Alt + right click     look toward that point (no move; end of route if moving)
##   Ctrl + right click    move there and WAIT for the go-code (Enter)
##   G / T                 throw flashbang / frag at the cursor
##   K                     toggle kicking doors (fast, loud) vs opening quietly
##   V                     toggle walk / run          H  toggle hold fire
##   1-9                   select unit by number (Shift = add)
##   F                     follow selected     Tab  cycle follow     Esc  clear

signal selection_changed

const Fx := preload("res://tactical/fx/fx.gd")
const Unit := preload("res://tactical/units/unit.gd")
const BOX_THRESHOLD := 6.0
const FACE_DRAG_THRESHOLD := 14.0
const PICK_RADIUS_PX := 40.0
const FORMATION_SPACING := 1.1
const MARKER_COLOR := Color(0.4, 0.85, 1.0)
const FACE_MARKER_COLOR := Color(1.0, 0.85, 0.3)
const THROW_MARKER_COLOR := Color(1.0, 1.0, 1.0)
const NO_THROW_COLOR := Color(1.0, 0.2, 0.2)

var selected: Array = []

var _rig  # camera rig script
var _units: Array = []
var _box  # selection_box.gd Control
var _world: Node3D
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _right_start: Vector2 = Vector2.ZERO
var _right_down: bool = false


func setup(rig, friendly_units: Array, box, world: Node3D) -> void:
	_rig = rig
	_units = friendly_units
	_box = box
	_world = world


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_selected(u) -> bool:
	return selected.has(u)


func select_only(u) -> void:
	_set_selection([u] if u != null else [])


func toggle(u) -> void:
	var next: Array = selected.duplicate()
	if next.has(u):
		next.erase(u)
	else:
		next.append(u)
	_set_selection(next)


func follow(u) -> void:
	if u != null:
		_rig.follow(u)


func _process(_delta: float) -> void:
	var alive: Array = selected.filter(func(u): return not u.is_dead)
	if alive.size() != selected.size():
		_set_selection(alive)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		if _dragging:
			_box.show_rect(_drag_start, pos)
		elif _right_down and pos.distance_to(_right_start) > FACE_DRAG_THRESHOLD:
			_box.show_arrow(_right_start, pos)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_handle_left(mb)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right(mb)


func _handle_left(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		if mb.double_click:
			var picked = _pick_unit(mb.position)
			if picked != null:
				select_only(picked)
				follow(picked)
			_dragging = false
			return
		_drag_start = mb.position
		_dragging = true
	elif _dragging:
		_dragging = false
		_box.hide_rect()
		if mb.position.distance_to(_drag_start) > BOX_THRESHOLD:
			_box_select(Rect2(_drag_start, mb.position - _drag_start).abs(), mb.shift_pressed)
		else:
			var picked = _pick_unit(mb.position)
			if mb.shift_pressed:
				if picked != null:
					toggle(picked)
			else:
				select_only(picked)


func _handle_right(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		_right_start = mb.position
		_right_down = true
		return
	if not _right_down:
		return
	_right_down = false
	_box.hide_arrow()
	if selected.is_empty():
		return
	var start: Variant = _ground_point(_right_start)
	if start == null:
		return
	if mb.alt_pressed:
		_issue_face(start)
		return
	var face_yaw: float = NAN
	if mb.position.distance_to(_right_start) > FACE_DRAG_THRESHOLD:
		var end: Variant = _ground_point(mb.position)
		if end != null:
			var dir: Vector3 = (end as Vector3) - (start as Vector3)
			face_yaw = atan2(-dir.x, -dir.z)
	_issue_move(start, mb.shift_pressed, face_yaw, mb.ctrl_pressed)


func _handle_key(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	var code: Key = key.physical_keycode
	if code >= KEY_1 and code <= KEY_9:
		var idx: int = code - KEY_1
		if idx < _units.size() and not _units[idx].is_dead:
			if key.shift_pressed:
				toggle(_units[idx])
			else:
				select_only(_units[idx])
	elif code == KEY_F:
		if not selected.is_empty():
			follow(selected[0])
	elif code == KEY_TAB:
		_cycle_follow()
	elif code == KEY_ESCAPE:
		_rig.release()
		select_only(null)
	elif code == KEY_V:
		_toggle_pace()
	elif code == KEY_H:
		_toggle_hold_fire()
	elif code == KEY_K:
		_toggle_kick()
	elif code == KEY_G:
		_throw("flashbang")
	elif code == KEY_T:
		_throw("frag")


func _set_selection(units: Array) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected = units
	for u in selected:
		u.set_selected(true)
	selection_changed.emit()


func _toggle_pace() -> void:
	if selected.is_empty():
		return
	# If any selected unit walks, everyone runs; otherwise everyone walks.
	var any_walk: bool = selected.any(func(u): return u.pace == Unit.Pace.WALK)
	for u in selected:
		u.set_pace(Unit.Pace.RUN if any_walk else Unit.Pace.WALK)


func _toggle_hold_fire() -> void:
	if selected.is_empty():
		return
	var any_free: bool = selected.any(func(u): return not u.hold_fire)
	for u in selected:
		u.hold_fire = any_free


func _toggle_kick() -> void:
	if selected.is_empty():
		return
	var any_quiet: bool = selected.any(func(u): return not u.kick_doors)
	for u in selected:
		u.kick_doors = any_quiet


## The first selected soldier who can make the throw (has one, in range, clear line) throws.
func _throw(kind: String) -> void:
	var point: Variant = _ground_point(get_viewport().get_mouse_position())
	if point == null or selected.is_empty():
		return
	for u in selected:
		if u.throw_grenade(kind, point):
			Fx.move_marker(_world, point, THROW_MARKER_COLOR)
			return
	Fx.move_marker(_world, point, NO_THROW_COLOR)


func _cycle_follow() -> void:
	var alive: Array = _units.filter(func(u): return not u.is_dead)
	if alive.is_empty():
		return
	var idx: int = alive.find(_rig.follow_target)
	var next = alive[(idx + 1) % alive.size()]
	select_only(next)
	follow(next)


func _issue_move(point: Vector3, queue: bool, face_yaw: float = NAN, hold: bool = false) -> void:
	var map: RID = _world.get_world_3d().navigation_map
	var n: int = selected.size()
	var cols: int = ceili(sqrt(float(n)))
	# Spread the group sideways relative to the facing (or the camera) so the line faces forward.
	var basis_yaw: float = face_yaw if not is_nan(face_yaw) else _rig.rotation.y
	for i in n:
		var offset := Vector3(
			(float(i % cols) - float(cols - 1) * 0.5) * FORMATION_SPACING,
			0.0,
			float(i / cols) * FORMATION_SPACING).rotated(Vector3.UP, basis_yaw)
		var dest: Vector3 = NavigationServer3D.map_get_closest_point(map, point + offset)
		selected[i].order_move(dest, queue, face_yaw, hold)
	Fx.move_marker(_world, point, MARKER_COLOR)


func _issue_face(point: Vector3) -> void:
	for u in selected:
		u.order_face(point)
	Fx.move_marker(_world, point, FACE_MARKER_COLOR)


func _box_select(rect: Rect2, additive: bool) -> void:
	var cam: Camera3D = _rig.camera
	var next: Array = selected.duplicate() if additive else []
	for u in _units:
		if u.is_dead or next.has(u):
			continue
		var p: Vector3 = u.global_position + Vector3(0.0, 0.9, 0.0)
		if cam.is_position_behind(p):
			continue
		if rect.has_point(cam.unproject_position(p)):
			next.append(u)
	_set_selection(next)


func _pick_unit(screen_pos: Vector2):
	var cam: Camera3D = _rig.camera
	var best = null
	var best_dist: float = PICK_RADIUS_PX
	for u in _units:
		if u.is_dead:
			continue
		var p: Vector3 = u.global_position + Vector3(0.0, 0.9, 0.0)
		if cam.is_position_behind(p):
			continue
		var d: float = cam.unproject_position(p).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = u
	return best


## Where the mouse ray hits the ground plane (y = 0), or null.
func _ground_point(screen_pos: Vector2) -> Variant:
	var cam: Camera3D = _rig.camera
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var normal: Vector3 = cam.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)
