extends Node3D
## WATCH AND DECIDE prototype. You micro the movements, not the individuals:
## select the squad (or one man), right-click a door = they stack on it by doctrine,
## then click a breach plan (door method, grenade, entry order, pie first) and execute.
## Right-click ground = move there. Skill decides how clean it looks. No numbers on screen.

const TestMap := preload("res://tactical/level/test_map.gd")
const NavBuilder := preload("res://tactical/level/nav_builder.gd")
const Unit := preload("res://tactical/units/unit.gd")
const Door := preload("res://tactical/level/door.gd")
const Fx := preload("res://tactical/fx/fx.gd")
const PixelFilter := preload("res://tactical/fx/pixel_filter.gd")
const RoomGraph := preload("res://tactical/watch/room_graph.gd")
const SquadBrain := preload("res://tactical/watch/squad_brain.gd")
const WatchCams := preload("res://tactical/watch/watch_cams.gd")
const BreachPanel := preload("res://tactical/watch/breach_panel.gd")

const NAV_BOUNDS := AABB(Vector3(-35.0, -2.0, -35.0), Vector3(70.0, 6.0, 70.0))
const CLASSES := ["assaulter", "assaulter", "breacher", "marksman"]
const CALLSIGNS := ["ROOK", "MOTH", "KETTLE", "FERRY"]
const TANGO_SPAWNS := [0, 1, 2, 3, 4, 6]          # indices into test_map.tango_spawns (inside the building)
const CAM_HUB := Vector3(-10.9, 0.0, 4.5)        # utility box on the outside of the west wall
const PICK_PX := 42.0

static var preset_choice: String = ""             # survives a restart

var friendlies: Array = []
var hostiles: Array = []
var doors: Array = []
var brain
var graph
var cams
var skills: Dictionary = {}
var preset: String = ""
var over := false

var _map: Node3D
var _hud: CanvasLayer
var _status: Label
var _sel_label: Label
var _mode_label: Label
var _hover_label: Label
var _panel
var _selected: Array = []           # empty = whole squad
var _time := 0.0
var _contact_seen := false
var _slow_left := 0.0
var _slow_cd := 0.0
var _manual_slow := false
var _reveal_left := 0.0
var _bark_labels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	var f := FileAccess.open("res://data/watch/skills.json", FileAccess.READ)
	skills = JSON.parse_string(f.get_as_text())
	_map = TestMap.new()
	_map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_map)
	NavBuilder.bake(_map, NAV_BOUNDS)
	for d in _map.doors:
		var door: Node3D = Door.new()
		door.setup(d["pos"], d["along_x"])
		_map.add_child(door)
		doors.append(door)
	Unit.door_nodes = doors
	graph = RoomGraph.new(doors)
	_build_hub()
	_spawn()
	brain = SquadBrain.new()
	brain.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(brain)
	brain.bark.connect(_on_bark)
	brain.status.connect(func(t): _status.text = t)
	brain.room_cleared.connect(_on_room_cleared)
	cams = WatchCams.new()
	add_child(cams)
	cams.setup(self, graph)
	add_child(PixelFilter.new())
	_build_hud()
	if preset_choice != "":
		_start(preset_choice)
	else:
		_show_picker()


# ------------------------------------------------------------- setup

func _build_hub() -> void:
	var body := StaticBody3D.new()
	body.position = CAM_HUB + Vector3(0.25, 0.7, 0.0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.0, 0.7)
	mesh.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.35, 0.3)
	mesh.material_override = m
	body.add_child(mesh)
	_map.add_child(body)
	var l := Label3D.new()
	l.text = "CAMERA HUB"
	l.font_size = 48
	l.pixel_size = 0.004
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = body.position + Vector3(0, 0.9, 0)
	_map.add_child(l)


func _spawn() -> void:
	var spots: Array = _map.operator_spawns
	for i in 4:
		var u: Node3D = Unit.new()
		u.setup(CALLSIGNS[i], "operator", Unit.Team.BLUE, CLASSES[i])
		u.position = spots[i]
		_map.add_child(u)
		u.fired.connect(_on_fired.bind(u))
		friendlies.append(u)
		var name_l := Label3D.new()
		name_l.text = "%d %s" % [i + 1, CALLSIGNS[i]]
		name_l.font_size = 56
		name_l.pixel_size = 0.004
		name_l.outline_size = 12
		name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_l.position = Vector3(0, 2.15, 0)
		name_l.modulate = Color(0.75, 0.9, 1.0)
		u.add_child(name_l)
	for k in TANGO_SPAWNS:
		var s: Dictionary = _map.tango_spawns[k]
		var t: Node3D = Unit.new()
		t.setup("TANGO", "tango", Unit.Team.RED)
		t.position = s["pos"]
		t.rotation.y = s["yaw"]
		_map.add_child(t)
		t.fired.connect(_on_fired.bind(t))
		t.set_revealed(false)
		hostiles.append(t)


func _show_picker() -> void:
	get_tree().paused = true
	var panel := PanelContainer.new()
	panel.name = "Picker"
	panel.add_theme_stylebox_override("panel", _box())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_lab("WATCH AND DECIDE  -  prototype", 28, Color(0.95, 0.8, 0.35)))
	v.add_child(_lab("Same building, same enemies. Pick who goes in. Then try another squad and compare.", 16, Color(0.85, 0.85, 0.85)))
	for id in ["rookie", "trained", "veteran"]:
		var p: Dictionary = skills["presets"][id]
		var b := Button.new()
		b.text = "%s   -   %s" % [p["name"], p["blurb"]]
		b.custom_minimum_size = Vector2(640, 48)
		b.add_theme_font_size_override("font_size", 18)
		var pid: String = id
		b.pressed.connect(func():
			panel.queue_free()
			preset_choice = pid
			_start(pid))
		v.add_child(b)
	_hud.add_child(panel)
	panel.reset_size()
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2


func _start(id: String) -> void:
	preset = id
	brain.setup(friendlies, hostiles, graph, skills["presets"][id])
	get_tree().paused = false
	_status.text = "Outside the building. Right-click a door to stack on it."
	_refresh_labels()


# ------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if preset == "":
		return
	if e is InputEventMouseMotion:
		_hover(e.position)
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			cams.mouse(e)
		elif not over and e.button_index == MOUSE_BUTTON_LEFT:
			_left_click(e.position, e.shift_pressed)
		elif not over and e.button_index == MOUSE_BUTTON_RIGHT:
			_right_click(e.position)
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if over and k != KEY_R and k != KEY_ESCAPE:
		return
	if _panel.visible and k in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
		_panel.key(k)
		return
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var u = friendlies[k - KEY_1]
			if e.shift_pressed:
				if _selected.has(u):
					_selected.erase(u)
				else:
					_selected.append(u)
			else:
				_selected = [] if _selected == [u] else [u]
		KEY_Q:
			_selected = []
		KEY_H:
			brain.hold(_selected)
			_panel.close()
		KEY_X:
			brain.pull_out()
			_panel.close()
		KEY_T:
			brain.set_loud(not brain.loud)
		KEY_K:
			var hacker = _selected[0] if not _selected.is_empty() else brain.alive().back()
			if hacker != null:
				brain.hack(hacker, CAM_HUB, float(skills["hack"]["seconds"]), _on_hacked)
		KEY_F:
			cams.follow = not cams.follow
		KEY_SPACE:
			get_tree().paused = not get_tree().paused
		KEY_B:
			_manual_slow = not _manual_slow
			_slow_left = 0.0
		KEY_V:
			cams.next_view()
		KEY_E:
			_finish("You called it off.")
		KEY_R:
			get_tree().paused = false
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			if _panel.visible:
				_panel.close()
			else:
				preset_choice = ""
				get_tree().paused = false
				Engine.time_scale = 1.0
				get_tree().reload_current_scene()
	_refresh_labels()


func _who() -> Array:
	return (_selected if not _selected.is_empty() else friendlies).filter(func(u): return not u.is_dead)


func _unit_under(screen: Vector2):
	var cam: Camera3D = get_viewport().get_camera_3d()
	var best = null
	var best_d := PICK_PX
	for u in friendlies:
		if u.is_dead or cam.is_position_behind(u.global_position):
			continue
		var p: Vector2 = cam.unproject_position(u.global_position + Vector3(0, 1.0, 0))
		var d := p.distance_to(screen)
		if d < best_d:
			best_d = d
			best = u
	return best


func _ground_under(screen: Vector2) -> Variant:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t


func _door_near(p: Vector3):
	var best = null
	var best_d := 1.6
	for d in doors:
		var dd: float = Vector2(d.center.x - p.x, d.center.z - p.z).length()
		if dd < best_d:
			best_d = dd
			best = d
	return best


func _left_click(pos: Vector2, add: bool) -> void:
	var u = _unit_under(pos)
	if u == null:
		if not add:
			_selected = []
	elif add:
		if _selected.has(u):
			_selected.erase(u)
		else:
			_selected.append(u)
	else:
		_selected = [u]
	_refresh_labels()


func _right_click(pos: Vector2) -> void:
	var g = _ground_under(pos)
	if g == null:
		return
	var door = _door_near(g)
	var who := _who()
	if who.is_empty():
		return
	if door != null:
		brain.stack_on(door, who)
		_panel.open_for(door, brain, who, graph)
	else:
		_panel.close()
		brain.move_to(who, g)


func _hover(pos: Vector2) -> void:
	var g = _ground_under(pos)
	var txt := ""
	if g != null:
		var door = _door_near(g)
		if door != null:
			var n: Vector3 = door.normal()
			var a: String = graph.room(graph.room_at(door.center + n * 0.8))["name"]
			var b: String = graph.room(graph.room_at(door.center - n * 0.8))["name"]
			txt = "Right-click: stack on this door  (%s / %s)" % [a, b]
	_hover_label.text = txt
	_hover_label.position = pos + Vector2(18, 12)


func execute_plan(plan: Dictionary) -> void:
	brain.execute(plan)


# ------------------------------------------------------------- the running fight

func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.001)
	if _slow_left > 0.0:
		_slow_left -= real
	_slow_cd = maxf(0.0, _slow_cd - real)
	var want := 1.0
	if _manual_slow:
		want = 0.35
	elif _slow_left > 0.0:
		want = float(skills["slowmo"]["scale"])
	if not over and Engine.time_scale != want:
		Engine.time_scale = want
	_mode_label.text = "%s     %s     %s%s" % [
		"LOUD" if brain.loud else "QUIET", cams.view_name(),
		"PAUSED   " if get_tree().paused else "", "SLOW MOTION" if Engine.time_scale < 0.99 else ""]
	if _panel.visible:
		_panel.refresh()


func _physics_process(delta: float) -> void:
	if preset == "" or over:
		return
	_time += delta
	_reveal_left = maxf(0.0, _reveal_left - delta)
	# Fog: you see what your people see, what the camera you're on sees, or everything if you own the cameras.
	for h in hostiles:
		var seen: bool = _reveal_left > 0.0 or cams.sees(h)
		if not seen:
			for f in friendlies:
				if not f.is_dead and f.can_see(h):
					seen = true
					break
		if seen != h.revealed:
			h.set_revealed(seen)
	# First contact: a moment of slow motion to make your call.
	var contact := false
	for f in friendlies:
		if not f.is_dead and f.target != null:
			contact = true
	if contact and not _contact_seen and _slow_cd <= 0.0:
		_slow_left = float(skills["slowmo"]["real_seconds"])
		_slow_cd = float(skills["slowmo"]["cooldown"])
		var who = friendlies.filter(func(f): return not f.is_dead and f.target != null)
		if not who.is_empty():
			_on_bark(who[0], "Contact!")
	_contact_seen = contact
	if hostiles.all(func(h): return h.is_dead):
		_finish("Building clear.")
	elif friendlies.all(func(f): return f.is_dead):
		_finish("Your squad is down.")


func _on_hacked() -> void:
	_reveal_left = float(skills["hack"]["reveal_seconds"])
	_status.text = "Cameras looped. Every camera in the building is showing you where they are."


func _on_room_cleared(id: String) -> void:
	_panel.close()
	var r: Rect2 = graph.room(id)["rect"]
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = r.size
	m.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 0.4, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(r.get_center().x, 0.06, r.get_center().y)
	_map.add_child(m)


func _on_fired(from: Vector3, to: Vector3, _hit: bool, shooter: Node3D) -> void:
	Fx.tracer(_map, from, to, Color(1.0, 0.92, 0.55) if shooter.team == Unit.Team.BLUE else Color(1.0, 0.45, 0.25))


func _on_bark(u, text: String) -> void:
	if u == null or not is_instance_valid(u):
		return
	var l: Label3D = _bark_labels.get(u)
	if l == null or not is_instance_valid(l):
		l = Label3D.new()
		l.font_size = 72
		l.pixel_size = 0.005
		l.outline_size = 16
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3(0, 2.55, 0)
		u.add_child(l)
		_bark_labels[u] = l
	l.text = text
	l.modulate = Color(1.0, 0.95, 0.6, 1.0) if text != "CLEAR!" else Color(0.5, 1.0, 0.55, 1.0)
	var tw := l.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------- the op report

func _finish(why: String) -> void:
	if over:
		return
	over = true
	_panel.close()
	Engine.time_scale = 1.0
	var kia: int = friendlies.filter(func(f): return f.is_dead).size()
	var wounded: int = friendlies.filter(func(f): return not f.is_dead and f.is_wounded()).size()
	var down: int = hostiles.filter(func(h): return h.is_dead).size()
	var st: Dictionary = brain.stats
	var tags: Array = []
	if kia == 0 and wounded == 0:
		tags.append("CLEAN  -  nobody hurt")
	if int(st["hesitations"]) == 0 and int(st["wrong_side"]) == 0 and int(st["funnel"]) == 0:
		tags.append("SMOOTH  -  every entry like a drill")
	if down == hostiles.size():
		tags.append("BUILDING CLEAR")
	if _time < 90.0 and down == hostiles.size():
		tags.append("FAST")
	var score: float = 5.0 - kia * 1.5 - wounded * 0.5 - int(st["hesitations"]) * 0.35 - int(st["wrong_side"]) * 0.35 - int(st["funnel"]) * 0.35
	if down < hostiles.size():
		score -= 1.5
	var stars: int = clampi(int(round(score)), 1, 5)
	var lines: Array = [
		why, "",
		"Squad: %s" % skills["presets"][preset]["name"],
		"Rooms cleared: %d of 4      Enemies down: %d of %d" % [int(st["rooms"]), down, hostiles.size()],
		"Your people: %d dead, %d wounded" % [kia, wounded],
		"Stopped in a doorway: %d      Went the wrong way: %d      Stood in the fatal funnel: %d" % [int(st["hesitations"]), int(st["wrong_side"]), int(st["funnel"])],
		"Time: %d s" % int(_time), "",
	]
	for t in tags:
		lines.append("+ " + t)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_lab("OP REPORT", 26, Color(0.95, 0.8, 0.35)))
	v.add_child(_lab("★".repeat(stars) + "☆".repeat(5 - stars), 40, Color(1.0, 0.8, 0.3)))
	for l in lines:
		v.add_child(_lab(str(l), 17, Color(0.9, 0.9, 0.88) if not str(l).begins_with("+") else Color(0.55, 1.0, 0.6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for id in ["rookie", "trained", "veteran"]:
		var b := Button.new()
		b.text = "Run it with %s" % skills["presets"][id]["name"]
		var pid: String = id
		b.pressed.connect(func():
			preset_choice = pid
			get_tree().paused = false
			get_tree().reload_current_scene())
		row.add_child(b)
	v.add_child(row)
	_hud.add_child(panel)
	panel.reset_size()
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2
	get_tree().paused = true


# ------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var help := _lab("\n".join([
		"LEFT click a soldier = select him (Shift adds)    click empty ground or Q = whole squad    1-4 also select",
		"RIGHT click a door = stack on it, then build the breach plan    RIGHT click ground = move there",
		"H hold   X pull out   T quiet/loud   K hack the camera hub   Space pause   B slow motion   V drone/CCTV",
		"WASD pan   wheel zoom   F follow squad   E end   R restart   Esc pick another squad",
	]), 15, Color(0.9, 0.9, 0.9))
	help.position = Vector2(16, 10)
	_hud.add_child(help)
	_status = _lab("", 19, Color(1.0, 0.85, 0.4))
	_status.position = Vector2(16, 112)
	_hud.add_child(_status)
	_sel_label = _lab("", 17, Color(0.75, 0.9, 1.0))
	_sel_label.position = Vector2(16, 864)
	_hud.add_child(_sel_label)
	_mode_label = _lab("", 17, Color(0.95, 0.95, 0.95))
	_mode_label.position = Vector2(1100, 864)
	_hud.add_child(_mode_label)
	_hover_label = _lab("", 15, Color(0.6, 1.0, 0.65))
	_hud.add_child(_hover_label)
	_panel = BreachPanel.new()
	_panel.main = self
	_hud.add_child(_panel)


func _refresh_labels() -> void:
	for u in friendlies:
		u.set_selected(_selected.has(u) or (_selected.is_empty() and not u.is_dead))
	var who: String = "WHOLE SQUAD" if _selected.is_empty() else ", ".join(_selected.map(func(u): return u.callsign))
	_sel_label.text = "Selected: %s      Squad: %s" % [who, skills["presets"][preset]["name"] if preset != "" else "-"]


func _box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.07, 0.95)
	sb.border_color = Color(0.9, 0.75, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(24)
	return sb


func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
