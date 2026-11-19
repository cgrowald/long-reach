extends Node
## Player input for selecting friendly units and giving them orders.
## Works while paused (orders can be planned during pause).
##
##   Left click            select unit (Shift = add/remove)
##   Left drag             box select (Shift = add)
##   Double-click          select + camera follow
##   Right click ground    move selected (Shift = queue waypoint)
##   1-9                   select unit by number (Shift = add)
##   F                     follow selected     Tab  cycle follow     Esc  clear

signal selection_changed

const Fx := preload("res://tactical/fx/fx.gd")
const BOX_THRESHOLD := 6.0
const PICK_RADIUS_PX := 40.0
const FORMATION_SPACING := 1.1
const MARKER_COLOR := Color(0.4, 0.85, 1.0)

var selected: Array = []

var _rig  # camera rig script
var _units: Array = []
var _box  # selection_box.gd Control
var _world: Node3D
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false


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
	# Drop units that died while selected.
	var alive: Array = selected.filter(func(u): return not u.is_dead)
	if alive.size() != selected.size():
		_set_selection(alive)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _dragging:
		_box.show_rect(_drag_start, (event as InputEventMouseMotion).position)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
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
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var point: Variant = _ground_point(mb.position)
		if point != null and not selected.is_empty():
			_issue_move(point, mb.shift_pressed)


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


func _set_selection(units: Array) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected = units
	for u in selected:
		u.set_selected(true)
	selection_changed.emit()


func _cycle_follow() -> void:
	var alive: Array = _units.filter(func(u): return not u.is_dead)
	if alive.is_empty():
		return
	var idx: int = alive.find(_rig.follow_target)
	var next = alive[(idx + 1) % alive.size()]
	select_only(next)
	follow(next)


func _issue_move(point: Vector3, queue: bool) -> void:
	var map: RID = _world.get_world_3d().navigation_map
	var n: int = selected.size()
	var cols: int = ceili(sqrt(float(n)))
	for i in n:
		var offset := Vector3(
			(float(i % cols) - float(cols - 1) * 0.5) * FORMATION_SPACING,
			0.0,
			float(i / cols) * FORMATION_SPACING)
		var dest: Vector3 = NavigationServer3D.map_get_closest_point(map, point + offset)
		selected[i].order_move(dest, queue)
	Fx.move_marker(_world, point, MARKER_COLOR)


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
