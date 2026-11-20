extends Node3D
## A soldier on the tactical map (friendly or hostile).
##
## Control philosophy: ONLY seeing and shooting are automatic. A soldier spots hostiles
## inside its vision cone (or peripheral range) with line of sight, turns onto them
## and fires. Everything else (doors, breaching, grenades, stance, pace, facing)
## happens only when ordered. A soldier whose path runs into a closed door stops.
##
## Classes (data/classes.json) set weapon, kit and which actions the soldier can do.
## Hit chance scales with how exposed the target is (head / chest / legs visible).

signal fired(from_pos: Vector3, to_pos: Vector3, hit: bool)
signal died(unit: Node3D)

const GameData := preload("res://sim/game_data.gd")
const CombatRules := preload("res://sim/combat_rules.gd")
const Grenade := preload("res://tactical/units/grenade.gd")

enum Team { BLUE, RED }
enum Pace { WALK, RUN }

const EYE_STAND := 1.55
const EYE_CROUCH := 1.1
const CHEST_STAND := 1.2
const CHEST_CROUCH := 0.8
const LEGS := 0.45
const LOS_MASK := 1
const ARRIVE_DIST := 0.12
const SCAN_INTERVAL := 0.15
const HEARING_RANGE := 20.0
const WOUNDED_FRACTION := 0.4
const PERSONAL_SPACE := 0.7
const FIRE_ARC_DEG := 12.0
const RUN_TURN_FACTOR := 0.6
const CROUCH_SPEED := 0.55
const DOOR_REACH := 1.0
const STACK_DIST := 0.95
const STACK_SPACING := 0.8
const THROW_IN_DIST := 2.5
const CROUCH_SCALE := 0.65
const FLAT_ARC := 0.3
const LOB_ARC := 1.6

## Map info shared by all units (set by main).
static var door_nodes: Array = []  # door.gd instances

var callsign: String = "UNIT"
var type_id: String = ""
var class_id: String = ""
var class_label: String = ""
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
var items: Dictionary = {}          # flashbang / frag / breach_charge counts
var actions: Array[String] = []     # what this soldier's class can do

var pace: int = Pace.WALK
var hold_fire: bool = false
var alerted: bool = false
var crouched: bool = false
var is_dead: bool = false
var revealed: bool = true
var ever_seen: bool = false
var stunned: float = 0.0
var target = null  # another unit (untyped: same script)

var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _leg: Dictionary = {}  # {"pos", "face" (NAN = none), "hold": bool, "action": Dictionary}
var _waypoints: Array[Dictionary] = []
var _moving: bool = false
var _holding: bool = false
var _blocked_by = null      # closed door in the way
var _action: Dictionary = {}  # current door / throw action
var _action_timer: float = 0.0
var _move_yaw: float = 0.0
var _idle_yaw: float = 0.0

var _scan_timer: float = 0.0
var _reaction_timer: float = 0.0
var _shot_timer: float = 0.0
var _burst_left: int = 0

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _flash_tween: Tween


func setup(p_callsign: String, p_type_id: String, p_team: int, p_class_id: String = "") -> void:
	callsign = p_callsign
	type_id = p_type_id
	class_id = p_class_id
	team = p_team
	var stats: Dictionary = GameData.unit_type(type_id).duplicate()
	if class_id != "":
		var c: Dictionary = GameData.class_def(class_id)
		for k in c:
			stats[k] = c[k]
		class_label = str(c.get("name", class_id))
	max_hp = float(stats.get("hp", 100))
	hp = max_hp
	weapon = GameData.weapon(str(stats.get("weapon", "")))
	walk_speed = float(stats.get("walk_speed", 2.2))
	run_speed = float(stats.get("run_speed", 4.5))
	turn_rate = deg_to_rad(float(stats.get("turn_rate_deg", 360.0)))
	reaction_time = float(stats.get("reaction_time", 0.5))
	vision_range = float(stats.get("vision_range", 40.0))
	fov_deg = float(stats.get("fov_deg", 100.0))
	peripheral_range = float(stats.get("peripheral_range", 4.0))
	team_color = GameData.color_from(stats)
	var it: Variant = stats.get("items", {})
	items = (it as Dictionary).duplicate() if typeof(it) == TYPE_DICTIONARY else {}
	actions.clear()
	for a in stats.get("actions", []):
		actions.append(str(a))


func _ready() -> void:
	add_to_group("units")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_idle_yaw = rotation.y
	_move_yaw = rotation.y
	_scan_timer = randf() * SCAN_INTERVAL
	_build_visuals()


# ---------------------------------------------------------------- capabilities

func can_do(verb: String) -> bool:
	if is_dead:
		return false
	match verb:
		"breach":
			return actions.has("breach") and item_count("breach_charge") > 0
		"open_flash":
			return actions.has("open") and can_do("flashbang")
		"kick_flash":
			return actions.has("kick") and can_do("flashbang")
		"flash_in", "flashbang":
			return actions.has("flashbang") and item_count("flashbang") > 0
		"frag_in", "frag":
			return actions.has("frag") and item_count("frag") > 0
	return actions.has(verb)


func item_count(kind: String) -> int:
	return int(items.get(kind, 0))


# ---------------------------------------------------------------- orders

## Move to destination. face_yaw = where to look on arrival (NAN = keep travel direction).
## hold = wait there until go() (go-code).
func order_move(destination: Vector3, queue: bool, face_yaw: float = NAN, hold: bool = false) -> void:
	_enqueue({"pos": destination, "face": face_yaw, "hold": hold, "action": {}}, queue)


## Door orders: walk to this side of the door, then do the verb.
## verb: open | kick | breach | flash_in | frag_in | stack.  index: place in a stack line.
func order_door(verb: String, door, queue: bool, hold: bool, index: int = 0) -> void:
	var from: Vector3 = _planned_end() if queue else global_position
	var n: Vector3 = door.normal()
	var map: RID = get_world_3d().navigation_map
	# Stack on whichever side we can reach by the shorter walk (= the near side).
	var side: float = 1.0
	var best_len: float = INF
	for s in [1.0, -1.0]:
		var p: Vector3 = NavigationServer3D.map_get_closest_point(map, door.center + n * s * STACK_DIST)
		var len: float = _path_length(NavigationServer3D.map_get_path(map, from, p, true))
		if len < best_len:
			best_len = len
			side = s
	var stack: Vector3 = door.center + n * side * (STACK_DIST + STACK_SPACING * float(index))
	stack = NavigationServer3D.map_get_closest_point(map, stack)
	stack.y = 0.0
	var face: float = _yaw_toward(door.center - stack)
	var action: Dictionary = {}
	if verb != "stack":
		action = {"verb": verb, "door": door, "side": side, "hold": hold, "phase": ""}
	_enqueue({"pos": stack, "face": face, "hold": hold and verb == "stack", "action": action}, queue)


## Look toward a point. If moving, applies to the end of the planned route.
func order_face(point: Vector3) -> void:
	if is_dead:
		return
	if not _waypoints.is_empty():
		var last: Dictionary = _waypoints[_waypoints.size() - 1]
		last["face"] = _yaw_toward(point - (last["pos"] as Vector3))
	elif _moving:
		_leg["face"] = _yaw_toward(point - (_leg["pos"] as Vector3))
	else:
		_idle_yaw = _yaw_toward(point - global_position)


## Go-code: waiting soldiers continue; armed breach charges detonate.
func go() -> void:
	if not _holding or is_dead:
		return
	_holding = false
	if _action.get("phase", "") == "armed":
		_action_timer = 0.25
		return
	_continue_route()


func stop() -> void:
	_waypoints.clear()
	_moving = false
	_holding = false
	_action = {}
	_leg = {}
	_blocked_by = null
	_idle_yaw = rotation.y


func set_pace(p: int) -> void:
	pace = p


func set_stance(crouch: bool) -> void:
	crouched = crouch
	if _visual != null and not is_dead:
		_visual.scale.y = CROUCH_SCALE if crouched else 1.0


## Throw a grenade at a ground point now. Returns false if not possible.
func throw_grenade(kind: String, point: Vector3) -> bool:
	if is_dead or stunned > 0.0 or not can_do(kind):
		return false
	var data: Dictionary = GameData.equipment(kind)
	var land: Vector3 = point + Vector3(0.0, 0.1, 0.0)
	if global_position.distance_to(land) > float(data.get("throw_range", 12.0)):
		return false
	var hand: Vector3 = global_position + Vector3(0.0, eye_height() - 0.1, 0.0)
	# Flat throw (through doorways) or a lob (over low cover); either must be unobstructed.
	var arc: float = LOB_ARC
	var apex: Vector3 = (hand + land) * 0.5 + Vector3(0.0, LOB_ARC, 0.0)
	if _clear_line(hand, land + Vector3(0.0, 0.3, 0.0)):
		arc = FLAT_ARC
	elif not (_clear_line(hand, apex) and _clear_line(apex, land + Vector3(0.0, 0.3, 0.0))):
		return false
	items[kind] = item_count(kind) - 1
	if not _moving:
		_idle_yaw = _yaw_toward(point - global_position)
	var g := Grenade.new()
	g.setup(kind, hand, land, self, arc)
	get_parent().add_child(g)
	return true


# ---------------------------------------------------------------- queries

func eye_height() -> float:
	return EYE_CROUCH if crouched else EYE_STAND


func chest_height() -> float:
	return CHEST_CROUCH if crouched else CHEST_STAND


func is_moving() -> bool:
	return _moving and not _holding and _blocked_by == null and _action.is_empty()


func is_holding() -> bool:
	return _holding


func is_drawn() -> bool:
	return _visual.visible


func is_wounded() -> bool:
	return not is_dead and hp < max_hp * WOUNDED_FRACTION


func get_status_text() -> String:
	if is_dead:
		return "DOWN"
	var s: String = "HOLDING"
	if stunned > 0.0:
		s = "STUNNED"
	elif not _action.is_empty():
		s = _action_status()
	elif target != null:
		s = "ENGAGING"
	elif _holding:
		s = "WAITING FOR GO"
	elif _blocked_by != null:
		s = "BLOCKED BY DOOR"
	elif _moving:
		s = "MOVING"
	var flags: Array[String] = [s]
	if crouched:
		flags.append("CROUCHED")
	if pace == Pace.RUN:
		flags.append("RUN")
	if hold_fire:
		flags.append("HOLD FIRE")
	if is_wounded():
		flags.append("WOUNDED")
	return " · ".join(flags)


func _action_status() -> String:
	match str(_action.get("verb", "")):
		"open", "open_flash":
			return "OPENING DOOR"
		"kick", "kick_flash":
			return "KICKING DOOR"
		"breach":
			if _action.get("phase", "") == "armed":
				return "CHARGE SET · WAITING FOR GO" if _holding else "CHARGE SET"
			return "PLACING CHARGE"
		"flash_in":
			return "THROWING FLASHBANG"
		"frag_in":
			return "THROWING FRAG"
	return "BUSY"


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


## Positions where the route waits for the go-code.
func get_planned_holds() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _holding:
		out.append(global_position)
	elif _moving and _leg_waits(_leg):
		out.append(_leg["pos"])
	for w in _waypoints:
		if _leg_waits(w):
			out.append(w["pos"])
	return out


func _leg_waits(leg: Dictionary) -> bool:
	if bool(leg.get("hold", false)):
		return true
	var a: Variant = leg.get("action", {})
	return typeof(a) == TYPE_DICTIONARY and bool((a as Dictionary).get("hold", false))


func set_selected(value: bool) -> void:
	_ring.visible = value and not is_dead


## Fog of war: hidden hostiles are not drawn.
func set_revealed(value: bool) -> void:
	revealed = value
	if value:
		ever_seen = true
	_visual.visible = value or (is_dead and ever_seen)


func can_see(other) -> bool:
	if other == null or other.is_dead:
		return false
	var to_other: Vector3 = other.global_position - global_position
	var dist: float = to_other.length()
	if dist > vision_range:
		return false
	if dist > peripheral_range and not in_fov(to_other):
		return false
	return other.exposure_from(global_position + Vector3(0.0, eye_height(), 0.0)) > 0.0


func in_fov(to_other: Vector3) -> bool:
	var flat := Vector3(to_other.x, 0.0, to_other.z)
	if flat.length_squared() < 0.0001:
		return true
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	return rad_to_deg(forward.normalized().angle_to(flat.normalized())) <= fov_deg * 0.5


## Fraction (0..1) of this unit's head / chest / legs visible from a viewpoint.
func exposure_from(eye: Vector3) -> float:
	var visible: int = 0
	for h in [eye_height(), chest_height(), LEGS]:
		if _clear_line(eye, global_position + Vector3(0.0, h, 0.0)):
			visible += 1
	return float(visible) / 3.0


# ---------------------------------------------------------------- reactions

func hear_noise(source_pos: Vector3) -> void:
	if is_dead:
		return
	alerted = true
	# Hostiles turn toward noise they hear (roughly). Friendlies keep their assigned angles.
	if team == Team.RED and target == null and not _moving:
		_idle_yaw = _yaw_toward(source_pos - global_position) + randf_range(-0.35, 0.35)


func take_damage(amount: float, source) -> void:
	if is_dead:
		return
	hp -= amount
	alerted = true
	_scan_timer = 0.0
	if source != null and source != self and target == null and not source.is_dead:
		_idle_yaw = _yaw_toward(source.global_position - global_position)
	_flash(Color.WHITE)
	if hp <= 0.0:
		_die()


func stun(seconds: float) -> void:
	if is_dead:
		return
	stunned = maxf(stunned, seconds)
	target = null
	_burst_left = 0
	_flash(Color(1.0, 1.0, 0.6))


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if stunned > 0.0:
		stunned -= delta
		return
	if not _action.is_empty():
		_update_action(delta)
	else:
		_update_movement(delta)
	_separate_from_others()
	_update_combat(delta)
	_update_facing(delta)


func _enqueue(leg: Dictionary, queue: bool) -> void:
	if is_dead:
		return
	if queue and (_moving or _holding or not _action.is_empty() or not _waypoints.is_empty()):
		_waypoints.append(leg)
		return
	_waypoints.clear()
	_holding = false
	_action = {}
	_blocked_by = null
	_start_leg(leg)


static func _path_length(path: PackedVector3Array) -> float:
	if path.is_empty():
		return INF
	var total: float = 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


func _planned_end() -> Vector3:
	if not _waypoints.is_empty():
		return _waypoints[_waypoints.size() - 1]["pos"]
	if _moving:
		return _leg["pos"]
	return global_position


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
	_blocked_by = null
	var face: float = float(_leg.get("face", NAN))
	_idle_yaw = rotation.y if is_nan(face) else face
	var leg: Dictionary = _leg
	_leg = {}
	var action: Dictionary = leg.get("action", {})
	if not action.is_empty():
		_begin_action(action)
		return
	if bool(leg.get("hold", false)):
		_holding = true
		return
	_continue_route()


func _continue_route() -> void:
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
	var dir: Vector3 = to_point / dist
	_blocked_by = _closed_door_ahead(dir)
	if _blocked_by != null:
		_idle_yaw = _yaw_toward(_blocked_by.center - global_position)
		return  # wait until someone opens it
	var move_speed: float = run_speed if pace == Pace.RUN else walk_speed
	if crouched:
		move_speed *= CROUCH_SPEED
	if is_wounded():
		move_speed *= 0.6
	var step: float = minf(move_speed * delta, dist)
	var pos: Vector3 = global_position + dir * step
	pos.y = 0.0
	global_position = pos
	_move_yaw = _yaw_toward(to_point)


func _closed_door_ahead(dir: Vector3):
	var a: Variant = _leg.get("action", {})
	var own_door = (a as Dictionary).get("door") if typeof(a) == TYPE_DICTIONARY else null
	for d in door_nodes:
		if d.is_open or d == own_door:
			continue  # never blocked by the door we were sent to work on
		var to_door: Vector3 = d.center - global_position
		to_door.y = 0.0
		var dist: float = to_door.length()
		if dist < DOOR_REACH and (dist < 0.05 or dir.dot(to_door / dist) > 0.3):
			return d
	return null


# ---------------------------------------------------------------- door / throw actions

func _begin_action(action: Dictionary) -> void:
	_action = action
	var verb: String = action["verb"]
	match verb:
		"open", "open_flash":
			_action_timer = float(GameData.equipment("open_door").get("time", 1.0))
		"kick", "kick_flash":
			_action_timer = float(GameData.equipment("kick_door").get("time", 0.5))
		"breach":
			_action["phase"] = "place"
			_action_timer = float(GameData.equipment("breach_charge").get("place_time", 2.0))
		_:
			_action_timer = 0.3


func _update_action(delta: float) -> void:
	var door = _action["door"]
	var verb: String = _action["verb"]
	if verb in ["open", "kick"] and door.is_open:
		_finish_action()
		return
	if verb in ["open_flash", "kick_flash"] and door.is_open:
		_after_door_opened(true, 0.2)  # someone else opened it; just flash
		return
	if _holding:
		return
	_action_timer -= delta
	if _action_timer > 0.0:
		return
	match verb:
		"open", "open_flash":
			door.open()
			_after_door_opened(verb == "open_flash", 0.5)
		"kick", "kick_flash":
			var kick: Dictionary = GameData.equipment("kick_door")
			_alert_nearby(float(kick.get("noise_range", 15.0)))
			if randf() < float(kick.get("success_chance", 0.7)):
				door.kick()
				_after_door_opened(verb == "kick_flash", 0.2)
			else:
				_action_timer = float(kick.get("time", 0.5))  # try again
		"breach":
			if _action["phase"] == "place":
				items["breach_charge"] = item_count("breach_charge") - 1
				_action["phase"] = "armed"
				_action_timer = float(GameData.equipment("breach_charge").get("detonate_delay", 0.6))
				_holding = bool(_action.get("hold", false))
			else:
				_detonate_charge(door, float(_action["side"]))
				_finish_action()
		"flash_in", "frag_in":
			var kind: String = "flashbang" if verb == "flash_in" else "frag"
			var far: float = -float(_action["side"])
			throw_grenade(kind, door.center + door.normal() * far * THROW_IN_DIST)
			_finish_action()
		_:
			_finish_action()


## After opening: either done, or chain into a flashbang through the doorway.
func _after_door_opened(then_flash: bool, delay: float) -> void:
	if then_flash and can_do("flashbang"):
		_action["verb"] = "flash_in"
		_action_timer = delay
	else:
		_finish_action()


func _finish_action() -> void:
	_action = {}
	_continue_route()


## Breach charge: door destroyed; people on the far side close to it are stunned / hurt.
func _detonate_charge(door, side: float) -> void:
	var data: Dictionary = GameData.equipment("breach_charge")
	var n: Vector3 = door.normal()
	var far: float = -side
	var blast: Vector3 = door.center + n * far * 0.3 + Vector3(0.0, 1.0, 0.0)
	door.blow()
	var radius: float = float(data.get("radius", 4.5))
	var dmg_radius: float = float(data.get("damage_radius", 2.0))
	var noise: float = float(data.get("noise_range", 35.0))
	for u in get_tree().get_nodes_in_group("units"):
		if u.is_dead:
			continue
		var rel: Vector3 = u.global_position - door.center
		var d: float = rel.length()
		if d <= noise:
			u.hear_noise(door.center)
		if rel.dot(n) * far <= 0.0 or d > radius:
			continue
		if not _clear_line(blast, u.global_position + Vector3(0.0, u.chest_height(), 0.0)):
			continue
		u.stun(float(data.get("stun_seconds", 3.5)))
		if d <= dmg_radius:
			u.take_damage(float(data.get("damage", 60.0)) * (1.0 - d / dmg_radius) + 10.0, self)


# ---------------------------------------------------------------- facing & combat

func _update_facing(delta: float) -> void:
	var desired: float = _idle_yaw
	if target != null:
		desired = _yaw_toward(target.global_position - global_position)
	elif not _action.is_empty():
		desired = _yaw_toward(_action["door"].center - global_position)
	elif _moving and _blocked_by == null:
		desired = _move_yaw
	var rate: float = turn_rate
	if _moving and pace == Pace.RUN:
		rate *= RUN_TURN_FACTOR
	rotation.y = rotate_toward(rotation.y, desired, rate * delta)


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
	var eye: Vector3 = global_position + Vector3(0.0, eye_height(), 0.0)
	var exposure: float = t.exposure_from(eye)
	if exposure <= 0.0:
		return
	_alert_nearby(HEARING_RANGE)
	var distance: float = global_position.distance_to(t.global_position)
	var move_factor: float = 1.0
	if is_moving():
		move_factor = CombatRules.RUN_ACCURACY if pace == Pace.RUN else CombatRules.WALK_ACCURACY
	var chance: float = CombatRules.hit_chance(weapon, distance, move_factor, t.is_moving()) * exposure
	var hit: bool = randf() < chance

	var forward: Vector3 = -global_transform.basis.z
	var from: Vector3 = global_position + Vector3(0.0, eye_height() - 0.15, 0.0) + forward * 0.45
	var aim: Vector3 = t.global_position + Vector3(0.0, t.chest_height(), 0.0)
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


func _alert_nearby(radius: float) -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if u != self and u.global_position.distance_to(global_position) <= radius:
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
	stunned = 0.0
	_moving = false
	_holding = false
	_action = {}
	_blocked_by = null
	_waypoints.clear()
	target = null
	if _flash_tween != null:
		_flash_tween.kill()
	_body_mat.albedo_color = team_color.darkened(0.65)
	_visual.scale.y = 1.0
	_visual.rotation.x = -PI * 0.5
	_visual.position.y = 0.3
	_ring.visible = false
	set_revealed(revealed)
	died.emit(self)


# ---------------------------------------------------------------- visuals

func _flash(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_body_mat.albedo_color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body_mat, "albedo_color", team_color, 0.25)


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

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.1)
	var visor := MeshInstance3D.new()
	var visor_box := BoxMesh.new()
	visor_box.size = Vector3(0.36, 0.12, 0.14)
	visor.mesh = visor_box
	visor.material_override = dark
	visor.position = Vector3(0.0, 1.55, -0.26)
	_visual.add_child(visor)

	# Weapon silhouette hints at the class: long rifle, stubby shotgun, standard rifle.
	var gun_len: float = 0.7
	if class_id == "marksman":
		gun_len = 1.0
	elif class_id == "breacher":
		gun_len = 0.55
	var gun := MeshInstance3D.new()
	var gun_box := BoxMesh.new()
	gun_box.size = Vector3(0.07, 0.09, gun_len)
	gun.mesh = gun_box
	gun.material_override = dark
	gun.position = Vector3(0.18, 1.3, -0.1 - gun_len * 0.5)
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
