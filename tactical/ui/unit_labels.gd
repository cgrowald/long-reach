extends Control
## Callsigns drawn in screen space above each visible unit (crisp even with the pixel filter).

const OFFSET := Vector3(0.0, 2.3, 0.0)
const FONT_SIZE := 13

var _rig
var _units: Array = []


func setup(rig, units: Array) -> void:
	_rig = rig
	_units = units


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw_heartbeat(cam: Camera3D, font: Font, u) -> void:
	var world: Vector3 = u.global_position + Vector3(0.0, 1.2, 0.0)
	if cam.is_position_behind(world):
		return
	var p: Vector2 = cam.unproject_position(world)
	var text: String = "HEARTBEAT"
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var pos := Vector2(p.x - w * 0.5, p.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.3, 0.25))


func _draw() -> void:
	var cam: Camera3D = _rig.camera
	var font: Font = get_theme_default_font()
	for u in _units:
		if not u.is_drawn():
			if u.sensed and not u.is_dead:
				_draw_heartbeat(cam, font, u)
			continue
		var world: Vector3 = u.global_position + OFFSET
		if cam.is_position_behind(world):
			continue
		var p: Vector2 = cam.unproject_position(world)
		var text: String = u.callsign
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var pos := Vector2(p.x - w * 0.5, p.y)
		var color: Color = u.team_color.lightened(0.5)
		if u.is_dead:
			color = Color(0.6, 0.6, 0.6, 0.7)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, 0.85))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
