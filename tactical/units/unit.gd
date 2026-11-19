extends Node3D
## A soldier on the tactical map (friendly or hostile).
##
## Eyes & angles model:
## - Sees hostiles inside its field-of-view cone (fov_deg, vision_range) or anywhere
##   within peripheral_range, if line of sight is clear.
## - Turns at a limited rate and can only fire when the target is inside a narrow
##   firing arc, so where a soldier is looking decides who shoots first.
## - While walking it slices the pie: it aims at doorways ahead instead of along its path.
## - Each move leg can carry a facing (where to look on arrival).
## Stats come from data/unit_types.json + data/weapons.json.

signal fired(from_pos: Vector3, to_pos: Vector3, hit: bool)
signal died(unit: Node3D)

const GameData := preload("res://sim/game_data.gd")
const CombatRules := preload("res://sim/combat_rules.gd")

enum Team { BLUE, RED }
enum Pace { WALK, RUN }

const EYE_HEIGHT := 1.55
const CHEST_HEIGHT := 1.2
const LOS_MASK := 1
const ARRIVE_DIST := 0.12
const SCAN_INTERVAL := 0.15
const HEARING_RANGE := 20.0
const WOUNDED_FRACTION := 0.4
const PERSONAL_SPACE := 0.7
const FIRE_ARC_DEG := 12.0
const PIE_RANGE := 5.5
const PIE_MIN_DIST := 0.9
const RUN_TURN_FACTOR := 0.6

## Doorway centers on the current map (set by main). Used for slicing the pie.
static var doors: Array[Vector3] = []

var callsign: String = "UNIT"
var type_id: String = ""
var team: int = Team.BLUE
var max_hp: float = 100.0
var hp: float = 100.0
var weapon: Dictionary = {}
var walk_speed: float = 2.2
var run_speed: float = 4.5
var turn_rate: float = deg_to_rad(360.0)
var reaction_time: float = 0.5
var vision_range: float = 40.0
var fov_deg: float = 100.0
var peripheral_range: float = 4.0
var team_color: Color = Color.WHITE

var pace: int = Pace.WALK
var hold_fire: bool = false
var alerted: bool = false
var is_dead: bool = false
var revealed: bool = true
var ever_seen: bool = false
var target = null  # another unit (untyped: same script)

var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _leg: Dictionary = {}  # {"pos": Vector3, "face": float (NAN = none)}
var _waypoints: Array[Dictionary] = []
var _moving: bool = false
var _move_yaw: float = 0.0
var _idle_yaw: float = 0.0

var _scan_timer: float = 0.0
var _reaction_timer: float = 0.0
var _shot_timer: float = 0.0
var _burst_left: int = 0

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _tag: Label3D
var _flash_tween: Tween


func setup(p_callsign: String, p_type_id: String, p_team: int) -> void:
	callsign = p_callsign
	type_id = p_type_id
	team = p_team
	var t: Dictionary = GameData.unit_type(type_id)
	max_hp = float(t.get("hp", 100))
	hp = max_hp
	weapon = GameData.weapon(str(t.get("weapon", "")))
	walk_speed = float(t.get("walk_speed", 2.2))
	run_speed = float(t.get("run_speed", 4.5))
	turn_rate = deg_to_rad(float(t.get("turn_rate_deg", 360.0)))
	reaction_time = float(t.get("reaction_time", 0.5))
	vision_range = float(t.get("vision_range", 40.0))
	fov_deg = float(t.get("fov_deg", 100.0))
	peripheral_range = float(t.get("peripheral_range", 4.0))
	team_color = GameData.color_from(t)


func _ready() -> void:
	add_to_group("units")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_idle_yaw = rotation.y
	_move_yaw = rotation.y
	_scan_timer = randf() * SCAN_INTERVAL
	_build_visuals()


# ---------------------------------------------------------------- orders

## Move to destination. face_yaw (radians) = where to look on arrival; NAN = keep travel direction.
func order_move(destination: Vector3, queue: bool, face_yaw: float = NAN) -> void:
	if is_dead:
		return
	var leg: Dictionary = {"pos": destination, "face": face_yaw}
	if queue and (_moving or not _waypoints.is_empty()):
		_waypoints.append(leg)
		return
	_waypoints.clear()
	_start_leg(leg)


## Look toward a point. If moving, applies to the end of the planned route.
func order_face(point: Vector3) -> void:
	if is_dead:
		return
	var yaw: float = _yaw_toward(point - global_position)
	if not _waypoints.is_empty():
		_waypoints[_waypoints.size() - 1]["face"] = _yaw_toward(point - _waypoints[_waypoints.size() - 1]["pos"])
	elif _moving:
		_leg["face"] = _yaw_toward(point - _leg["pos"])
	else:
		_idle_yaw = yaw


func stop() -> void:
	_waypoints.clear()
	_moving = false
	_leg = {}
	_idle_yaw = rotation.y


func set_pace(p: int) -> void:
	pace = p


# ---------------------------------------------------------------- queries

func is_moving() -> bool:
	return _moving


func is_wounded() -> bool:
	return not is_dead and hp < max_hp * WOUNDED_FRACTION


func get_status_text() -> String:
	if is_dead:
		return "DOWN"
	var s: String = "HOLDING"
	if target != null:
		s = "ENGAGING"
	elif _moving:
		s = "MOVING"
	var flags: Array[String] = [s]
	if pace == Pace.RUN:
		flags.append("RUN")
	if hold_fire:
		flags.append("HOLD FIRE")
	if is_wounded():
		flags.append("WOUNDED")
	return " · ".join(flags)


## Current position, remaining path, then queued waypoints (for the path overlay).
func get_planned_points() -> Array[Vector3]:
	var pts: Array[Vector3] = [global_position]
	if _moving:
		for i in range(_path_index, _path.size()):
			pts.append(_path[i])
	for w in _waypoints:
		pts.append(w["pos"])
	return pts


## [position, yaw] pairs for every planned leg that ends with a facing order.
func get_planned_facings() -> Array:
	var out: Array = []
	if _moving and not is_nan(float(_leg.get("face", NAN))):
		out.append([_leg["pos"], _leg["face"]])
	for w in _waypoints:
		if not is_nan(float(w["face"])):
			out.append([w["pos"], w["face"]])
	return out


func set_selected(value: bool) -> void:
	_ring.visible = value and not is_dead


## Fog of war: hidden hostiles are not drawn.
func set_revealed(value: bool) -> void:
	revealed = value
	if value:
		ever_seen = true
	var show: bool = value or (is_dead and ever_seen)
	_visual.visible = show
	_tag.visible = show


func can_see(other) -> bool:
	if other == null or other.is_dead:
		return false
	var to_other: Vector3 = other.global_position - global_position
	var dist: float = to_other.length()
	if dist > vision_range:
		return false
	if dist > peripheral_range and not in_fov(to_other):
		return false
	return has_line_of_sight(other)


func in_fov(to_other: Vector3) -> bool:
	var flat := Vector3(to_other.x, 0.0, to_other.z)
	if flat.length_squared() < 0.0001:
		return true
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	return rad_to_deg(forward.normalized().angle_to(flat.normalized())) <= fov_deg * 0.5


func has_line_of_sight(other) -> bool:
	return _clear_line(
		global_position + Vector3(0.0, EYE_HEIGHT, 0.0),
		other.global_position + Vector3(0.0, CHEST_HEIGHT, 0.0))


# ---------------------------------------------------------------- reactions

func hear_noise(source_pos: Vector3) -> void:
	if is_dead:
		return
	alerted = true
	# Hostiles turn toward gunfire they hear (roughly). Friendlies keep their assigned angles.
	if team == Team.RED and target == null and not _moving:
		_idle_yaw = _yaw_toward(source_pos - global_position) + randf_range(-0.35, 0.35)


func take_damage(amount: float, source) -> void:
	if is_dead:
		return
	hp -= amount
	alerted = true
	_scan_timer = 0.0
	if source != null and target == null and not source.is_dead:
		_idle_yaw = _yaw_toward(source.global_position - global_position)
	_flash()
	if hp <= 0.0:
		_die()


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_update_movement(delta)
	_separate_from_others()
	_update_combat(delta)
	_update_facing(delta)


func _start_leg(leg: Dictionary) -> void:
	_leg = leg
	var map: RID = get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, leg["pos"], true)
	_path_index = 0
	_moving = not _path.is_empty()
	if not _moving:
		_arrive()


func _arrive() -> void:
	_moving = false
	var face: float = float(_leg.get("face", NAN))
	_idle_yaw = rotation.y if is_nan(face) else face
	_leg = {}
	if not _waypoints.is_empty():
		_start_leg(_waypoints.pop_front())


func _update_movement(delta: float) -> void:
	if not _moving:
		return
	if _path_index >= _path.size():
		_arrive()
		return
	var point: Vector3 = _path[_path_index]
	var to_point: Vector3 = point - global_position
	to_point.y = 0.0
	var dist: float = to_point.length()
	if dist < ARRIVE_DIST:
		_path_index += 1
		return
	var move_speed: float = run_speed if pace == Pace.RUN else walk_speed
	if is_wounded():
		move_speed *= 0.6
	var step: float = minf(move_speed * delta, dist)
	var pos: Vector3 = global_position + to_point / dist * step
	pos.y = 0.0
	global_position = pos
	_move_yaw = _yaw_toward(to_point)


func _update_facing(delta: float) -> void:
	var desired: float = _idle_yaw
	if target != null:
		desired = _yaw_toward(target.global_position - global_position)
	elif _moving:
		var pie: Variant = _pie_point()
		desired = _move_yaw if pie == null else _yaw_toward((pie as Vector3) - global_position)
	var rate: float = turn_rate
	if _moving and pace == Pace.RUN:
		rate *= RUN_TURN_FACTOR
	rotation.y = rotate_toward(rotation.y, desired, rate * delta)


## Slicing the pie: while walking, aim at the nearest doorway ahead that is in view.
func _pie_point() -> Variant:
	if pace == Pace.RUN:
		return null
	var forward := Vector3(-sin(_move_yaw), 0.0, -cos(_move_yaw))
	var eye: Vector3 = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var best: Variant = null
	var best_dist: float = PIE_RANGE
	for d in doors:
		var to_door: Vector3 = d - global_position
		to_door.y = 0.0
		var dist: float = to_door.length()
		if dist < PIE_MIN_DIST or dist > best_dist:
			continue
		if forward.dot(to_door / dist) < 0.2:
			continue
		if not _clear_line(eye, d + Vector3(0.0, EYE_HEIGHT, 0.0)):
			continue
		best = d
		best_dist = dist
	return best


## Keeps living units from standing inside each other, then snaps back onto the navmesh.
func _separate_from_others() -> void:
	var push := Vector3.ZERO
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or u.is_dead:
			continue
		var away: Vector3 = global_position - u.global_position
		away.y = 0.0
		var d: float = away.length()
		if d >= PERSONAL_SPACE:
			continue
		if d < 0.001:
			away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			d = 0.001
		push += away.normalized() * (PERSONAL_SPACE - d) * 0.5
	if push == Vector3.ZERO:
		return
	var map: RID = get_world_3d().navigation_map
	var pos: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position + push)
	pos.y = 0.0
	global_position = pos


func _update_combat(delta: float) -> void:
	if target != null and (not is_instance_valid(target) or target.is_dead):
		target = null

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		var best = _find_target()
		if best != target:
			target = best
			_burst_left = 0
			if target != null:
				_reaction_timer = reaction_time * (0.5 if alerted else 1.0)

	if target == null or hold_fire:
		return
	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		return
	var aim_yaw: float = _yaw_toward(target.global_position - global_position)
	if absf(angle_difference(rotation.y, aim_yaw)) > deg_to_rad(FIRE_ARC_DEG):
		return  # still turning onto target
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _burst_left <= 0:
		_burst_left = randi_range(int(weapon.get("burst_min", 2)), int(weapon.get("burst_max", 4)))
	_fire_at(target)
	_burst_left -= 1
	if _burst_left > 0:
		_shot_timer = float(weapon.get("shot_interval", 0.1))
	else:
		_shot_timer = float(weapon.get("burst_pause", 0.5)) * randf_range(0.8, 1.3)


func _find_target():
	if target != null and can_see(target):
		return target
	var best = null
	var best_dist: float = INF
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or u.is_dead or u.team == team:
			continue
		var d: float = global_position.distance_to(u.global_position)
		if d >= best_dist:
			continue
		if can_see(u):
			best = u
			best_dist = d
	return best


func _fire_at(t) -> void:
	_alert_nearby()
	var distance: float = global_position.distance_to(t.global_position)
	var move_factor: float = 1.0
	if _moving:
		move_factor = CombatRules.RUN_ACCURACY if pace == Pace.RUN else CombatRules.WALK_ACCURACY
	var chance: float = CombatRules.hit_chance(weapon, distance, move_factor, t.is_moving())
	var hit: bool = randf() < chance

	var forward: Vector3 = -global_transform.basis.z
	var from: Vector3 = global_position + Vector3(0.0, 1.4, 0.0) + forward * 0.45
	var aim: Vector3 = t.global_position + Vector3(0.0, CHEST_HEIGHT, 0.0)
	var to: Vector3
	if hit:
		to = aim + Vector3(randf_range(-0.1, 0.1), randf_range(-0.2, 0.3), randf_range(-0.1, 0.1))
	else:
		var side: Vector3 = (aim - from).cross(Vector3.UP).normalized()
		var miss: Vector3 = side * randf_range(-1.2, 1.2) + Vector3(0.0, randf_range(-0.6, 0.8), 0.0)
		to = from + ((aim + miss) - from) * 1.3
	fired.emit(from, to, hit)
	if hit:
		t.take_damage(CombatRules.roll_damage(weapon), self)


func _alert_nearby() -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if u != self and u.global_position.distance_to(global_position) <= HEARING_RANGE:
			u.hear_noise(global_position)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _yaw_toward(dir: Vector3) -> float:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return rotation.y
	return atan2(-dir.x, -dir.z)


func _die() -> void:
	is_dead = true
	hp = 0.0
	_moving = false
	_waypoints.clear()
	target = null
	if _flash_tween != null:
		_flash_tween.kill()
	_body_mat.albedo_color = team_color.darkened(0.65)
	_visual.rotation.x = -PI * 0.5
	_visual.position.y = 0.3
	_ring.visible = false
	_tag.modulate = Color(0.6, 0.6, 0.6, 0.7)
	set_revealed(revealed)
	died.emit(self)


# ---------------------------------------------------------------- visuals

func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_body_mat.albedo_color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body_mat, "albedo_color", team_color, 0.15)


func _build_visuals() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = team_color
	_body_mat.roughness = 0.8
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	body.mesh = capsule
	body.material_override = _body_mat
	body.position.y = 0.9
	_visual.add_child(body)

	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.08, 0.08, 0.1)
	var visor := MeshInstance3D.new()
	var visor_box := BoxMesh.new()
	visor_box.size = Vector3(0.36, 0.12, 0.14)
	visor.mesh = visor_box
	visor.material_override = visor_mat
	visor.position = Vector3(0.0, 1.55, -0.26)
	_visual.add_child(visor)

	var gun := MeshInstance3D.new()
	var gun_box := BoxMesh.new()
	gun_box.size = Vector3(0.07, 0.09, 0.7)
	gun.mesh = gun_box
	gun.material_override = visor_mat
	gun.position = Vector3(0.18, 1.3, -0.45)
	_visual.add_child(gun)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.2)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.position.y = 0.05
	_ring.visible = false
	add_child(_ring)

	_tag = Label3D.new()
	_tag.text = callsign
	_tag.position.y = 2.3
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0012
	_tag.font_size = 22
	_tag.outline_size = 6
	_tag.modulate = team_color.lightened(0.45)
	add_child(_tag)
