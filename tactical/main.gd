extends Node3D
## Tactical mission: builds the map, bakes navigation, places doors, spawns both sides,
## wires up camera / selection / HUD, and decides win or loss.

const CameraRig := preload("res://tactical/camera/camera_rig.gd")
const TestMap := preload("res://tactical/level/test_map.gd")
const NavBuilder := preload("res://tactical/level/nav_builder.gd")
const Unit := preload("res://tactical/units/unit.gd")
const SelectionController := preload("res://tactical/control/selection_controller.gd")
const SelectionBox := preload("res://tactical/ui/selection_box.gd")
const SquadPanel := preload("res://tactical/ui/squad_panel.gd")
const PathOverlay := preload("res://tactical/ui/path_overlay.gd")
const VisionOverlay := preload("res://tactical/ui/vision_overlay.gd")
const Fx := preload("res://tactical/fx/fx.gd")
const Door := preload("res://tactical/level/door.gd")
const PixelFilter := preload("res://tactical/fx/pixel_filter.gd")
const UnitLabels := preload("res://tactical/ui/unit_labels.gd")
const RadialMenu := preload("res://tactical/ui/radial_menu.gd")
const HeartbeatOverlay := preload("res://tactical/ui/heartbeat_overlay.gd")

const NAV_BOUNDS := AABB(Vector3(-35.0, -2.0, -35.0), Vector3(70.0, 6.0, 70.0))
const TRACER_BLUE := Color(1.0, 0.92, 0.55)
const TRACER_RED := Color(1.0, 0.45, 0.25)
const FOG_INTERVAL := 3  # physics frames between fog-of-war updates
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0]
const SQUAD_CLASSES: Array[String] = ["assaulter", "breacher", "assaulter", "marksman"]

var friendlies: Array = []
var hostiles: Array = []
var hvt = null                 # the operation's named target (null = none)
var hvt_mode: String = ""     # "kill" or "capture"
var mission_over: bool = false

var _map: Node3D
var _rig
var _selection
var _status_label: Label
var _banner: Label
var _fog_tick: int = 0
var _campaign = null
var _end_btn: Button
var _sensor_assigned: bool = false
var _speed_idx: int = 2
var _objective: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_campaign = get_node_or_null("/root/Campaign")

	_map = TestMap.new()
	_map.name = "Level"
	_map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_map)
	Engine.time_scale = SPEEDS[_speed_idx]
	NavBuilder.bake(_map, NAV_BOUNDS)  # before doors, so paths go through doorways
	_spawn_doors()
	_spawn_units()

	_rig = CameraRig.new()
	_rig.name = "CameraRig"
	add_child(_rig)
	_rig.position = Vector3(0.0, 0.0, 10.0)

	add_child(PixelFilter.new())
	var hud := CanvasLayer.new()
	hud.layer = 1
	add_child(hud)
	var labels := UnitLabels.new()
	labels.setup(_rig, friendlies + hostiles)
	hud.add_child(labels)
	var box := SelectionBox.new()
	hud.add_child(box)

	_selection = SelectionController.new()
	_selection.name = "Selection"
	var hint := Label.new()
	hint.position = Vector2(16.0, 240.0)
	_style_label(hint, 18)
	hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hud.add_child(hint)
	var wheel := RadialMenu.new()
	_selection.setup(_rig, friendlies, box, _map, wheel, hint)
	_selection.hvt = hvt
	add_child(_selection)

	var vision := VisionOverlay.new()
	vision.setup(friendlies, _selection)
	add_child(vision)

	var heartbeat := HeartbeatOverlay.new()
	heartbeat.setup(friendlies, hostiles)
	add_child(heartbeat)

	var overlay := PathOverlay.new()
	overlay.setup(friendlies, _selection)
	add_child(overlay)

	var panel := SquadPanel.new()
	panel.setup(friendlies, _selection)
	hud.add_child(panel)

	_build_hud_text(hud)
	_end_btn = Button.new()
	_end_btn.text = "END OPERATION" if _in_campaign() else "RESTART"
	_end_btn.custom_minimum_size = Vector2(190, 40)
	_end_btn.position = Vector2(get_viewport().get_visible_rect().size.x - 210.0, 16.0)
	_end_btn.pressed.connect(_end_operation)
	hud.add_child(_end_btn)
	if _in_campaign():
		var op := Label.new()
		op.text = _campaign.operation_name
		op.position = Vector2(get_viewport().get_visible_rect().size.x - 420.0, 24.0)
		_style_label(op, 18)
		op.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
		hud.add_child(op)
	hud.add_child(wheel)  # last, so it draws on top


func _spawn_doors() -> void:
	var nodes: Array = []
	for d in _map.doors:
		var door: Node3D = Door.new()
		door.setup(d["pos"], d["along_x"])
		_map.add_child(door)
		nodes.append(door)
	Unit.door_nodes = nodes


func _spawn_units() -> void:
	var map := _map as Node3D
	var ops: Array[Vector3] = _map.operator_spawns
	# Campaign: deploy the operators picked at HQ. Standalone: a default test squad.
	var records: Array = _campaign.deployed_records() if _in_campaign() else []
	var count: int = records.size() if not records.is_empty() else ops.size()
	for i in count:
		var u: Node3D = Unit.new()
		u.name = "Alpha%d" % (i + 1)
		var spawn: Vector3 = ops[i % ops.size()] + Vector3(0.0, 0.0, 1.5 * float(i / ops.size()))
		if records.is_empty():
			u.setup("ALPHA-%d" % (i + 1), "operator", Unit.Team.BLUE, SQUAD_CLASSES[i % SQUAD_CLASSES.size()])
		else:
			var r = records[i]
			u.setup(r.callsign.to_upper(), "operator", Unit.Team.BLUE, r.class_id)
			u.record_id = r.id
			u.apply_modifiers(r.modifiers())
		u.position = spawn
		if _in_campaign():
			var fx: Dictionary = _campaign.tech_effects()
			# Sensor: lead Assaulter carries the prototype; Mk II puts one on every Assaulter.
			var carries: bool = u.class_id == "assaulter" and (float(fx.get("heartbeat_all", 0.0)) > 0.0 or not _sensor_assigned)
			u.apply_tech(fx, carries)
			if carries and u.heartbeat_range > 0.0:
				_sensor_assigned = true
		map.add_child(u)
		u.fired.connect(_on_unit_fired.bind(u))
		friendlies.append(u)

	# Campaign operation: enemy count from the region's strength, skill from the theater.
	var tangos: Array[Dictionary] = _map.tango_spawns.duplicate()
	var tango_mods: Dictionary = {}
	if _in_campaign() and not _campaign.current_op.is_empty():
		var op: Dictionary = _campaign.current_op
		tangos.shuffle()
		var want: int = int(op.get("tangos", tangos.size()))
		if str(op.get("kind", "")) == "node":
			hvt_mode = str(op.get("mode", "kill"))
			want -= 1  # the target himself is one of them
		tangos.resize(clampi(want, 1, tangos.size()))
		tango_mods = _campaign.WorldSim.theater_of(str(op.get("region", ""))).get("tango", {})
	for i in tangos.size():
		var t: Node3D = Unit.new()
		t.name = "Tango%d" % (i + 1)
		t.setup("TANGO-%d" % (i + 1), "tango", Unit.Team.RED)
		if not tango_mods.is_empty():
			t.apply_modifiers(tango_mods)
		t.position = tangos[i]["pos"]
		t.rotation.y = tangos[i]["yaw"]
		map.add_child(t)
		t.fired.connect(_on_unit_fired.bind(t))
		t.set_revealed(false)
		hostiles.append(t)
	if hvt_mode != "":
		_spawn_hvt(_campaign.current_op, tango_mods)


func _in_campaign() -> bool:
	return _campaign != null and _campaign.is_deployed()


## End the operation and hand results back to the campaign (or restart when standalone).
func _end_operation() -> void:
	if not _in_campaign():
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	var results: Array = []
	for u in friendlies:
		results.append({"id": u.record_id, "alive": not u.is_dead, "hp": u.hp, "max_hp": u.max_hp, "kills": u.kills})
	var success: bool = _objective_done() and _count_alive(friendlies) > 0
	_campaign.finish_mission(results, success, _hvt_outcome())


func _on_unit_fired(from: Vector3, to: Vector3, _hit: bool, shooter: Node3D) -> void:
	var color: Color = TRACER_BLUE if shooter.team == Unit.Team.BLUE else TRACER_RED
	Fx.tracer(_map, from, to, color)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_SPACE:
		get_tree().paused = not get_tree().paused
	elif key.physical_keycode == KEY_R and not _in_campaign():
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER:
		for f in friendlies:
			f.go()
	elif key.physical_keycode == KEY_MINUS or key.physical_keycode == KEY_KP_SUBTRACT:
		_set_speed(_speed_idx - 1)
	elif key.physical_keycode == KEY_EQUAL or key.physical_keycode == KEY_KP_ADD:
		_set_speed(_speed_idx + 1)


func _set_speed(idx: int) -> void:
	_speed_idx = clampi(idx, 0, SPEEDS.size() - 1)
	Engine.time_scale = SPEEDS[_speed_idx]


# ---------------------------------------------------------------- HUD / mission state

func _build_hud_text(hud: CanvasLayer) -> void:
	var help := Label.new()
	help.text = "\n".join([
		"LEFT = feet:  click ground  move    drag from a soldier  draw his route    drag on empty ground  box select    (Shift queue, Ctrl wait for GO)",
		"RIGHT = eyes:  click ground  look there    drag from a route / soldier to a point  watch it from there    Shift + right  PIE it (dotted line)",
		"Right click a DOOR / SOLDIER  action wheel    Enter  GO    Space  pause    - / =  game speed    P  pixel look    R  restart",
		"WASD Q/E wheel middle-drag  camera    F / Tab / double-click  follow    1-4  select    Esc  cancel",
	])
	help.position = Vector2(16.0, 12.0)
	_style_label(help, 15)
	hud.add_child(help)

	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 160.0)
	_style_label(_status_label, 16)
	hud.add_child(_status_label)

	_objective = Label.new()
	_objective.position = Vector2(16.0, 104.0)
	_style_label(_objective, 17)
	_objective.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	hud.add_child(_objective)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_banner, 48)
	_banner.add_theme_constant_override("outline_size", 10)
	hud.add_child(_banner)


func _style_label(label: Label, font_size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", font_size)


## Fog of war: a hostile is drawn only while some living friendly can see it.
func _physics_process(_delta: float) -> void:
	_fog_tick += 1
	if _fog_tick % FOG_INTERVAL != 0:
		return
	for h in hostiles:
		var seen: bool = false
		for f in friendlies:
			if not f.is_dead and f.can_see(h):
				seen = true
				break
		if seen != h.revealed:
			h.set_revealed(seen)


func _process(_delta: float) -> void:
	var blue_alive: int = _count_alive(friendlies)
	var red_alive: int = _armed_alive()

	var lines: Array[String] = []
	lines.append(("PAUSED" if get_tree().paused else "LIVE") + "   speed %sx" % str(SPEEDS[_speed_idx]))
	lines.append("Armed hostiles remaining: %d" % red_alive)
	_objective.text = _objective_text()
	lines.append("FPS %d" % Engine.get_frames_per_second())
	_status_label.text = "\n".join(lines)
	_status_label.add_theme_color_override(
		"font_color", Color(1.0, 0.8, 0.2) if get_tree().paused else Color.WHITE)

	if mission_over:
		return
	if _objective_done():
		var title: String = "AREA SECURE"
		match _hvt_outcome():
			"captured":
				title = "HVT CAPTURED"
			"killed":
				title = "HVT KILLED"
		_end_mission(title, Color(0.4, 1.0, 0.5), blue_alive)
	elif blue_alive == 0:
		_end_mission("MISSION FAILED", Color(1.0, 0.35, 0.3), blue_alive)


func _end_mission(title: String, color: Color, survivors: int) -> void:
	mission_over = true
	var how: String = "Click END OPERATION to return to HQ" if _in_campaign() else "Press R to restart"
	_banner.text = "%s\n%d / %d operators alive\n%s" % [title, survivors, friendlies.size(), how]
	_banner.add_theme_color_override("font_color", color)


func _count_alive(units: Array) -> int:
	var n: int = 0
	for u in units:
		if not u.is_dead:
			n += 1
	return n


## The named target: armed (kill raid) or hiding unarmed (capture raid), in the back room.
func _spawn_hvt(op: Dictionary, mods: Dictionary) -> void:
	var info: Dictionary = op.get("hvt", {})
	var t: Node3D = Unit.new()
	t.name = "HVT"
	t.setup("HVT", "tango", Unit.Team.RED)
	if not mods.is_empty():
		t.apply_modifiers(mods)
	t.make_hvt(str(info.get("alias", "Target")), hvt_mode == "kill")
	t.position = _map.hvt_spawn["pos"]
	t.rotation.y = _map.hvt_spawn["yaw"]
	_map.add_child(t)
	t.fired.connect(_on_unit_fired.bind(t))
	t.set_revealed(false)
	if t.unarmed:
		t.set_stance(true)
	hostiles.append(t)
	hvt = t


## Hostiles still able to fight (a restrained or unarmed target does not count).
func _armed_alive() -> int:
	var n: int = 0
	for u in hostiles:
		if not u.is_dead and not u.unarmed and not u.captured:
			n += 1
	return n


## "killed" / "captured" / "escaped", or "" when there is no named target.
func _hvt_outcome() -> String:
	if hvt == null:
		return ""
	if hvt.captured:
		return "captured"
	if hvt.is_dead:
		return "killed"
	return "escaped"


func _objective_text() -> String:
	if hvt == null:
		return "OBJECTIVE: clear the building."
	var who: String = hvt.callsign.replace("HVT  ", "")
	match _hvt_outcome():
		"captured":
			return "OBJECTIVE: %s is restrained. Clear the building." % who
		"killed":
			return "OBJECTIVE: %s is down%s. Clear the building." % [who, " (we wanted him alive)" if hvt_mode == "capture" else ""]
	if hvt_mode == "capture":
		return "OBJECTIVE: capture %s ALIVE. He is unarmed; your soldiers will not shoot him.\nSelect a soldier, then RIGHT-CLICK the gold HVT  >  Restrain. Frags and breach blasts can still kill him." % who
	return "OBJECTIVE: kill %s (gold) and clear the building." % who


func _objective_done() -> bool:
	if _armed_alive() > 0:
		return false
	return hvt == null or hvt.is_dead or hvt.captured
