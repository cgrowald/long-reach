extends Node
## Player input: selection, movement, looking and the action wheel.
## Works while paused (plan everything during pause).
##
## LEFT = feet
##   Left click soldier          select (Shift = add/remove)      Double-click  select + follow
##   Left click ground           move selected there (Shift = queue, Ctrl = wait for GO)
##   Left DRAG from a soldier    draw his route freehand (Shift = add to plan, Ctrl = wait for GO)
##   Left DRAG on empty ground   box select
## RIGHT = eyes
##   Right click ground          look at that point now
##   Right DRAG from a route     from that spot on the route, watch the point you drag to
##   (or from a soldier)         (from a soldier: starting now)
##   Shift + right (click/drag)  same, but PIE it: rifle up, slow, covering that point (dotted line)
##   Right click DOOR / SOLDIER  action wheel (door: Shift = queue, Ctrl = on GO)
##   1-9 select   F follow   Tab cycle follow   Esc clear / cancel
signal selection_changed

const Fx := preload("res://tactical/fx/fx.gd")
const Unit := preload("res://tactical/units/unit.gd")
const BOX_THRESHOLD := 6.0
const LOOK_DRAG_THRESHOLD := 14.0
const DRAW_SAMPLE_DIST := 0.5
const ROUTE_PICK_PX := 14.0
const PICK_RADIUS_PX := 32.0
const DOOR_PICK_RADIUS_PX := 45.0
const FORMATION_SPACING := 1.1
const MARKER_COLOR := Color(0.4, 0.85, 1.0)
const FACE_MARKER_COLOR := Color(1.0, 0.85, 0.3)
const THROW_MARKER_COLOR := Color(1.0, 1.0, 1.0)
const NO_THROW_COLOR := Color(1.0, 0.2, 0.2)

const DOOR_LABELS := {
	"open": "Open", "kick": "Kick", "breach": "Breach charge", "stack": "Stack up",
	"flash_in": "Flash in", "frag_in": "Frag in",
	"open_flash": "Open + flash", "kick_flash": "Kick + flash",
}

var selected: Array = []

var _rig
var _units: Array = []
var _box
var _wheel
var _hint: Label
var _world: Node3D
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _right_start: Vector2 = Vector2.ZERO
var _right_down: bool = false
var _pending_throw: String = ""
var _drawing: bool = false
var _draw_origin: Vector2 = Vector2.ZERO
var _draw_unit = null  # soldier the left-drag started on
var _draw_screen := PackedVector2Array()
var _draw_world := PackedVector3Array()


func setup(rig, friendly_units: Array, box, world: Node3D, wheel, hint: Label) -> void:
	_rig = rig
	_units = friendly_units
	_box = box
	_world = world
	_wheel = wheel
	_hint = hint
	_wheel.chosen.connect(_on_wheel_chosen)


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
	if _pending_throw != "":
		_hint.text = "Left-click where to throw the %s   (right-click to cancel)" % \
			("flashbang" if _pending_throw == "flashbang" else "frag grenade")
	else:
		_hint.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if _wheel.is_open():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left(mb)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right(mb)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var pos: Vector2 = mm.position
		if _dragging:
			_box.show_rect(_drag_start, pos)
		elif _draw_unit != null and (_drawing or pos.distance_to(_draw_origin) > BOX_THRESHOLD):
			_extend_drawing(pos)
		elif _right_down and pos.distance_to(_right_start) > LOOK_DRAG_THRESHOLD:
			_box.show_look_line(_right_start, pos, mm.shift_pressed)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


# ---------------------------------------------------------------- left = feet

func _handle_left(mb: InputEventMouseButton) -> void:
	if mb.pressed and _pending_throw != "":
		var point: Variant = _ground_point(mb.position)
		if point != null:
			_throw(_pending_throw, point)
		_pending_throw = ""
		return
	if mb.pressed:
		if mb.double_click:
			var picked = _pick_unit(mb.position)
			if picked != null:
				select_only(picked)
				follow(picked)
			_draw_unit = null
			_dragging = false
			return
		var on_unit = _pick_unit(mb.position)
		if on_unit != null:
			_draw_unit = on_unit  # click = select him, drag = draw his route
			_draw_origin = mb.position
			_drawing = false
			return
		_drag_start = mb.position
		_dragging = true
	elif _draw_unit != null:
		var unit = _draw_unit
		_draw_unit = null
		if _drawing:
			_drawing = false
			_box.hide_line()
			var group: Array = selected.duplicate() if selected.has(unit) else [unit]
			if not selected.has(unit):
				select_only(unit)
			if _draw_world.size() >= 2:
				for u in group:
					u.order_path(_draw_world, mb.shift_pressed, mb.ctrl_pressed)
				Fx.move_marker(_world, _draw_world[_draw_world.size() - 1], MARKER_COLOR)
		elif mb.shift_pressed:
			toggle(unit)
		else:
			select_only(unit)
	elif _dragging:
		_dragging = false
		_box.hide_rect()
		if mb.position.distance_to(_drag_start) > BOX_THRESHOLD:
			_box_select(Rect2(_drag_start, mb.position - _drag_start).abs(), mb.shift_pressed)
		elif not selected.is_empty():
			var point: Variant = _ground_point(mb.position)
			if point != null:
				_issue_move(point, mb.shift_pressed, NAN, mb.ctrl_pressed)


# ---------------------------------------------------------------- right = eyes

func _handle_right(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		if _pending_throw != "":
			_pending_throw = ""
			return
		_right_start = mb.position
		_right_down = true
		return
	if not _right_down:
		return
	_right_down = false
	_box.hide_look_line()
	var pie: bool = mb.shift_pressed
	var dragged: bool = mb.position.distance_to(_right_start) > LOOK_DRAG_THRESHOLD

	if not dragged:
		var unit = _pick_unit(_right_start)
		if unit != null:
			if not selected.has(unit):
				select_only(unit)
			_open_unit_wheel(_right_start)
			return
		if not selected.is_empty():
			var door = _pick_door(_right_start)
			if door != null:
				_open_door_wheel(_right_start, door, mb.shift_pressed, mb.ctrl_pressed)
				return
		var look: Variant = _ground_point(_right_start)
		if look != null and not selected.is_empty():
			for u in selected:
				u.look_now(look, pie)
			Fx.move_marker(_world, look, FACE_MARKER_COLOR)
		return

	var target: Variant = _ground_point(mb.position)
	if target == null:
		return
	# Dragged from a point on someone's route: watch the target from that spot onward.
	var hit: Dictionary = _pick_route(_right_start)
	if not hit.is_empty():
		hit["unit"].add_focus_mark(hit["anchor"], target, pie)
		Fx.move_marker(_world, target, FACE_MARKER_COLOR)
		return
	# Dragged from a soldier (or anywhere): watch it starting now.
	var from_unit = _pick_unit(_right_start)
	var who: Array = [from_unit] if from_unit != null and not selected.has(from_unit) else selected
	for u in who:
		u.look_now(target, pie)
	Fx.move_marker(_world, target, FACE_MARKER_COLOR)

# ---------------------------------------------------------------- wheels

func _open_door_wheel(pos: Vector2, door, queue: bool, hold: bool) -> void:
	var verbs: Array[String] = []
	if door.is_open:
		verbs.assign(["stack", "flash_in", "frag_in"])
	else:
		verbs.assign(["open", "kick", "breach", "open_flash", "kick_flash", "stack"])
	var opts: Array = []
	for v in verbs:
		var label: String = DOOR_LABELS[v]
		opts.append({"id": v, "label": label, "enabled": v == "stack" or _performer(v, door) != null})
	var title: String = "DOOR" + ("  (wait for GO)" if hold else "") + ("  (queued)" if queue else "")
	_wheel.open(pos, title, opts, {"kind": "door", "door": door, "queue": queue, "hold": hold})


func _open_unit_wheel(pos: Vector2) -> void:
	var first = selected[0]
	var any_flash: bool = selected.any(func(u): return u.can_do("flashbang"))
	var any_frag: bool = selected.any(func(u): return u.can_do("frag"))
	var opts: Array = [
		{"id": "stance", "label": "Stand up" if first.crouched else "Crouch", "enabled": true},
		{"id": "pace", "label": "Walk" if first.pace == Unit.Pace.RUN else "Run", "enabled": true},
		{"id": "fire", "label": "Weapons free" if first.hold_fire else "Hold fire", "enabled": true},
		{"id": "flashbang", "label": "Flashbang", "enabled": any_flash},
		{"id": "frag", "label": "Frag", "enabled": any_frag},
		{"id": "stop", "label": "Stop / cancel", "enabled": true},
	]
	var title: String = first.callsign if selected.size() == 1 else "%d SOLDIERS" % selected.size()
	if selected.size() == 1 and first.class_label != "":
		title += " · " + first.class_label
	_wheel.open(pos, title, opts, {"kind": "unit"})


func _on_wheel_chosen(id: String, ctx: Dictionary) -> void:
	if ctx.get("kind", "") == "door":
		_do_door(id, ctx["door"], bool(ctx["queue"]), bool(ctx["hold"]))
	else:
		_do_unit(id)


func _do_door(verb: String, door, queue: bool, hold: bool) -> void:
	if verb == "stack":
		var alive: Array = selected.filter(func(u): return not u.is_dead)
		alive.sort_custom(func(a, b): return a.global_position.distance_to(door.center) < b.global_position.distance_to(door.center))
		for i in alive.size():
			alive[i].order_door("stack", door, queue, hold, i)
	else:
		var p = _performer(verb, door)
		if p == null:
			return
		p.order_door(verb, door, queue, hold)
	Fx.move_marker(_world, door.center, MARKER_COLOR)


## Closest selected soldier whose class can do this door action.
func _performer(verb: String, door):
	var best = null
	var best_d: float = INF
	for u in selected:
		if not u.can_do(verb):
			continue
		var d: float = u.global_position.distance_to(door.center)
		if d < best_d:
			best_d = d
			best = u
	return best


func _do_unit(id: String) -> void:
	var first = selected[0]
	match id:
		"stance":
			var crouch: bool = not first.crouched
			for u in selected:
				u.set_stance(crouch)
		"pace":
			var run: bool = first.pace == Unit.Pace.WALK
			for u in selected:
				u.set_pace(Unit.Pace.RUN if run else Unit.Pace.WALK)
		"fire":
			var hold: bool = not first.hold_fire
			for u in selected:
				u.hold_fire = hold
		"flashbang", "frag":
			_pending_throw = id
		"stop":
			for u in selected:
				u.stop()


# ---------------------------------------------------------------- keys

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
		if _pending_throw != "":
			_pending_throw = ""
			return
		_rig.release()
		select_only(null)


# ---------------------------------------------------------------- helpers

func _extend_drawing(pos: Vector2) -> void:
	if not _drawing:
		_drawing = true
		_draw_screen = PackedVector2Array([_draw_origin])
		_draw_world = PackedVector3Array([_draw_unit.global_position])
	var g: Variant = _ground_point(pos)
	if g == null:
		return
	if _draw_world.is_empty() or _draw_world[_draw_world.size() - 1].distance_to(g) >= DRAW_SAMPLE_DIST:
		_draw_world.append(g)
		_draw_screen.append(pos)
		_box.show_line(_draw_screen)


## Closest point on any friendly's planned route under the mouse (selected soldiers first).
func _pick_route(screen_pos: Vector2) -> Dictionary:
	var cam: Camera3D = _rig.camera
	var best: Dictionary = {}
	var best_d: float = ROUTE_PICK_PX
	var order: Array = selected.duplicate()
	for u in _units:
		if not order.has(u):
			order.append(u)
	for u in order:
		if u.is_dead:
			continue
		var pts: Array[Vector3] = u.get_planned_points()
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if cam.is_position_behind(a) or cam.is_position_behind(b):
				continue
			var sa: Vector2 = cam.unproject_position(a)
			var sb: Vector2 = cam.unproject_position(b)
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(screen_pos, sa, sb)
			var d: float = q.distance_to(screen_pos)
			if d < best_d:
				best_d = d
				var seg_len: float = sa.distance_to(sb)
				var t: float = 0.0 if seg_len < 0.001 else sa.distance_to(q) / seg_len
				best = {"unit": u, "anchor": a.lerp(b, t)}
	return best


func _set_selection(units: Array) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected = units
	for u in selected:
		u.set_selected(true)
	selection_changed.emit()


## The first selected soldier able to make the throw does it.
func _throw(kind: String, point: Vector3) -> void:
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
	var basis_yaw: float = face_yaw if not is_nan(face_yaw) else _rig.rotation.y
	for i in n:
		var offset := Vector3(
			(float(i % cols) - float(cols - 1) * 0.5) * FORMATION_SPACING,
			0.0,
			float(i / cols) * FORMATION_SPACING).rotated(Vector3.UP, basis_yaw)
		var dest: Vector3 = NavigationServer3D.map_get_closest_point(map, point + offset)
		selected[i].order_move(dest, queue, face_yaw, hold)
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


func _pick_door(screen_pos: Vector2):
	var cam: Camera3D = _rig.camera
	var best = null
	var best_dist: float = DOOR_PICK_RADIUS_PX
	for d in Unit.door_nodes:
		var p: Vector3 = d.center + Vector3(0.0, 1.0, 0.0)
		if cam.is_position_behind(p):
			continue
		var dist: float = cam.unproject_position(p).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best


## Where the mouse ray hits the ground plane (y = 0), or null.
func _ground_point(screen_pos: Vector2) -> Variant:
	var cam: Camera3D = _rig.camera
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var normal: Vector3 = cam.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)
