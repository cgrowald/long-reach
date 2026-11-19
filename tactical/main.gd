extends Node3D
## M1 tactical mission: builds the map, bakes navigation, spawns both sides,
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

const NAV_BOUNDS := AABB(Vector3(-35.0, -2.0, -35.0), Vector3(70.0, 6.0, 70.0))
const TRACER_BLUE := Color(1.0, 0.92, 0.55)
const TRACER_RED := Color(1.0, 0.45, 0.25)
const FOG_INTERVAL := 3  # physics frames between fog-of-war updates

var friendlies: Array = []
var hostiles: Array = []
var mission_over: bool = false

var _map: Node3D
var _rig
var _selection
var _status_label: Label
var _banner: Label
var _fog_tick: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_map = TestMap.new()
	_map.name = "Level"
	_map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_map)
	NavBuilder.bake(_map, NAV_BOUNDS)
	Unit.doors = _map.doors
	_spawn_units()

	_rig = CameraRig.new()
	_rig.name = "CameraRig"
	add_child(_rig)
	_rig.position = Vector3(0.0, 0.0, 10.0)

	var hud := CanvasLayer.new()
	add_child(hud)
	var box := SelectionBox.new()
	hud.add_child(box)

	_selection = SelectionController.new()
	_selection.name = "Selection"
	_selection.setup(_rig, friendlies, box, _map)
	add_child(_selection)

	var vision := VisionOverlay.new()
	vision.setup(friendlies, _selection)
	add_child(vision)

	var overlay := PathOverlay.new()
	overlay.setup(friendlies, _selection)
	add_child(overlay)

	var panel := SquadPanel.new()
	panel.setup(friendlies, _selection)
	hud.add_child(panel)

	_build_hud_text(hud)


func _spawn_units() -> void:
	var map := _map as Node3D
	var ops: Array[Vector3] = _map.operator_spawns
	for i in ops.size():
		var u: Node3D = Unit.new()
		u.name = "Alpha%d" % (i + 1)
		u.setup("ALPHA-%d" % (i + 1), "operator", Unit.Team.BLUE)
		u.position = ops[i]
		map.add_child(u)
		u.fired.connect(_on_unit_fired.bind(u))
		friendlies.append(u)

	var tangos: Array[Dictionary] = _map.tango_spawns
	for i in tangos.size():
		var t: Node3D = Unit.new()
		t.name = "Tango%d" % (i + 1)
		t.setup("TANGO-%d" % (i + 1), "tango", Unit.Team.RED)
		t.position = tangos[i]["pos"]
		t.rotation.y = tangos[i]["yaw"]
		map.add_child(t)
		t.fired.connect(_on_unit_fired.bind(t))
		t.set_revealed(false)
		hostiles.append(t)


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
	elif key.physical_keycode == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- HUD / mission state

func _build_hud_text(hud: CanvasLayer) -> void:
	var help := Label.new()
	help.text = "\n".join([
		"Left click / drag  select (Shift adds)    Right click  move (Shift queues)    Right DRAG  move + face that way",
		"Alt + right click  look toward point    V  walk / run    H  hold fire    Space  pause (plan while paused)",
		"WASD  pan    Q/E  rotate    Middle-drag  orbit    Wheel  zoom    Double-click / F  follow    Tab  cycle",
		"1-4  select    Esc  clear    R  restart",
	])
	help.position = Vector2(16.0, 12.0)
	_style_label(help, 15)
	hud.add_child(help)

	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 128.0)
	_style_label(_status_label, 16)
	hud.add_child(_status_label)

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
	var red_alive: int = _count_alive(hostiles)

	var lines: Array[String] = []
	lines.append("PAUSED" if get_tree().paused else "LIVE")
	lines.append("Hostiles remaining: %d / %d" % [red_alive, hostiles.size()])
	lines.append("FPS %d" % Engine.get_frames_per_second())
	_status_label.text = "\n".join(lines)
	_status_label.add_theme_color_override(
		"font_color", Color(1.0, 0.8, 0.2) if get_tree().paused else Color.WHITE)

	if mission_over:
		return
	if red_alive == 0:
		_end_mission("AREA SECURE", Color(0.4, 1.0, 0.5), blue_alive)
	elif blue_alive == 0:
		_end_mission("MISSION FAILED", Color(1.0, 0.35, 0.3), blue_alive)


func _end_mission(title: String, color: Color, survivors: int) -> void:
	mission_over = true
	_banner.text = "%s\n%d / %d operators alive\nPress R to restart" % [title, survivors, friendlies.size()]
	_banner.add_theme_color_override("font_color", color)


func _count_alive(units: Array) -> int:
	var n: int = 0
	for u in units:
		if not u.is_dead:
			n += 1
	return n
