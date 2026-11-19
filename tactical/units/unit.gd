extends Node3D
## A soldier on the tactical map (friendly or hostile).
## Follows navmesh paths, spots hostiles (range + vision cone + line of sight),
## and fights automatically. Stats come from data/unit_types.json + data/weapons.json.

signal fired(from_pos: Vector3, to_pos: Vector3, hit: bool)
signal died(unit: Node3D)

const GameData := preload("res://sim/game_data.gd")
const CombatRules := preload("res://sim/combat_rules.gd")

enum Team { BLUE, RED }

const EYE_HEIGHT := 1.55
const CHEST_HEIGHT := 1.2
const LOS_MASK := 1
const ARRIVE_DIST := 0.12
const TURN_RATE := 12.0
const SCAN_INTERVAL := 0.2
const HEARING_RANGE := 20.0
const WOUNDED_FRACTION := 0.4
const PERSONAL_SPACE := 0.7

var callsign: String = "UNIT"
var type_id: String = ""
var team: int = Team.BLUE
var max_hp: float = 100.0
var hp: float = 100.0
var weapon: Dictionary = {}
var speed: float = 3.0
var reaction_time: float = 0.5
var vision_range: float = 40.0
var vision_cone_deg: float = 360.0
var team_color: Color = Color.WHITE

var alerted: bool = false
var is_dead: bool = false
var target = null  # another unit (untyped: same script)

var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _waypoints: Array[Vector3] = []
var _moving: bool = false
var _desired_yaw: float = 0.0

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
	speed = float(t.get("speed", 3.0))
	reaction_time = float(t.get("reaction_time", 0.5))
	vision_range = float(t.get("vision_range", 40.0))
	vision_cone_deg = float(t.get("vision_cone_deg", 360.0))
	team_color = GameData.color_from(t)


func _ready() -> void:
	add_to_group("units")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_desired_yaw = rotation.y
	_scan_timer = randf() * SCAN_INTERVAL
	_build_visuals()


# ---------------------------------------------------------------- orders & queries

func order_move(destination: Vector3, queue: bool) -> void:
	if is_dead:
		return
	if queue and (_moving or not _waypoints.is_empty()):
		_waypoints.append(destination)
		return
	_waypoints.clear()
	_start_path_to(destination)


func stop() -> void:
	_waypoints.clear()
	_moving = false


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
	if is_wounded():
		s += " / WOUNDED"
	return s


## Current position, remaining path, then queued waypoints (for the path overlay).
func get_planned_points() -> Array[Vector3]:
	var pts: Array[Vector3] = [global_position]
	if _moving:
		for i in range(_path_index, _path.size()):
			pts.append(_path[i])
	for w in _waypoints:
		pts.append(w)
	return pts


func set_selected(value: bool) -> void:
	_ring.visible = value and not is_dead


func can_see(other) -> bool:
	if other == null or other.is_dead:
		return false
	var to_other: Vector3 = other.global_position - global_position
	if to_other.length() > vision_range:
		return false
	if not _in_vision_cone(to_other):
		return false
	return has_line_of_sight(other)


func has_line_of_sight(other) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, EYE_HEIGHT, 0.0),
		other.global_position + Vector3(0.0, CHEST_HEIGHT, 0.0),
		LOS_MASK)
	return space.intersect_ray(query).is_empty()


func take_damage(amount: float, source) -> void:
	if is_dead:
		return
	hp -= amount
	alerted = true
	_scan_timer = 0.0
	if source != null and target == null and not source.is_dead:
		_desired_yaw = _yaw_toward(source.global_position - global_position)
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
	rotation.y = lerp_angle(rotation.y, _desired_yaw, 1.0 - exp(-TURN_RATE * delta))


func _start_path_to(destination: Vector3) -> void:
	var map: RID = get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, destination, true)
	_path_index = 0
	_moving = not _path.is_empty()


func _update_movement(delta: float) -> void:
	if not _moving:
		return
	if _path_index >= _path.size():
		_moving = false
		if not _waypoints.is_empty():
			_start_path_to(_waypoints.pop_front())
		return
	var point: Vector3 = _path[_path_index]
	var to_point: Vector3 = point - global_position
	to_point.y = 0.0
	var dist: float = to_point.length()
	if dist < ARRIVE_DIST:
		_path_index += 1
		return
	var move_speed: float = speed
	if is_wounded():
		move_speed *= 0.6
	if target != null:
		move_speed *= 0.75
	var step: float = minf(move_speed * delta, dist)
	var pos: Vector3 = global_position + to_point / dist * step
	pos.y = 0.0
	global_position = pos
	if target == null:
		_desired_yaw = _yaw_toward(to_point)


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

	if target == null:
		return
	_desired_yaw = _yaw_toward(target.global_position - global_position)

	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		return
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
	var chance: float = CombatRules.hit_chance(weapon, distance, _moving, t.is_moving())
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
		if not u.is_dead and u.global_position.distance_to(global_position) <= HEARING_RANGE:
			u.alerted = true


func _in_vision_cone(to_other: Vector3) -> bool:
	if alerted or vision_cone_deg >= 359.0:
		return true
	var flat := Vector3(to_other.x, 0.0, to_other.z)
	if flat.length_squared() < 0.0001:
		return true
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	return rad_to_deg(forward.normalized().angle_to(flat.normalized())) <= vision_cone_deg * 0.5


func _yaw_toward(dir: Vector3) -> float:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return _desired_yaw
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
