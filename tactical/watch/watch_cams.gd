extends Node
## Views for watch-and-decide: a drone that follows the squad, and the building's own CCTV
## cameras (grainy). A CCTV camera shows everyone in its room. V cycles. Mouse wheel zooms the drone.

const CCTV := [
	{"name": "CAM 1  WEST HALL", "room": "west", "pos": Vector3(-9.6, 2.8, 6.6), "look": Vector3(-5.0, 0.6, -1.0)},
	{"name": "CAM 2  OFFICE", "room": "office", "pos": Vector3(9.6, 2.8, 6.6), "look": Vector3(2.0, 0.6, 2.5)},
	{"name": "CAM 3  SAFE ROOM", "room": "safe", "pos": Vector3(9.6, 2.8, -6.6), "look": Vector3(6.0, 0.6, -2.5)},
]
const GRAIN := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 tint = vec3(g * 0.85, g * 1.05, g * 0.9);
	float n = rnd(SCREEN_UV * 900.0 + vec2(TIME * 37.0, TIME * 11.0)) * 0.12;
	float scan = sin(SCREEN_UV.y * 900.0) * 0.04;
	float vig = smoothstep(0.9, 0.35, distance(SCREEN_UV, vec2(0.5)));
	COLOR = vec4((tint + n + scan) * (0.6 + 0.4 * vig), 1.0);
}
"""

var main
var graph
var view := 0
var drone: Camera3D
var _cams: Array = []
var _overlay: CanvasLayer
var _cam_label: Label
var _height := 16.0
var _focus := Vector3(0, 0, 14)


func setup(p_main, p_graph) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = p_main
	graph = p_graph
	drone = Camera3D.new()
	drone.fov = 55.0
	main.add_child(drone)
	drone.make_current()
	for c in CCTV:
		var cam := Camera3D.new()
		cam.fov = 78.0
		main.add_child(cam)
		cam.global_position = c["pos"]
		cam.look_at(c["look"])
		_cams.append(cam)
	_overlay = CanvasLayer.new()
	_overlay.layer = 1
	_overlay.visible = false
	main.add_child(_overlay)
	var rect := ColorRect.new()
	var sh := Shader.new()
	sh.code = GRAIN
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(rect)
	_cam_label = Label.new()
	_cam_label.add_theme_font_size_override("font_size", 22)
	_cam_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_cam_label.position = Vector2(24, 800)
	_overlay.add_child(_cam_label)
	_place_drone(1.0)


func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.001)
	_place_drone(clampf(real * 3.0, 0.0, 1.0))
	if view > 0:
		var t := Time.get_datetime_dict_from_system()
		_cam_label.text = "%s     14 OCT 2041  %02d:%02d:%02d     REC" % [CCTV[view - 1]["name"], 23, t["minute"], t["second"]]


func _place_drone(w: float) -> void:
	if main.brain != null and not main.brain.alive().is_empty():
		_focus = _focus.lerp(main.brain.centroid(), w)
	drone.global_position = _focus + Vector3(0.0, _height, _height * 0.62)
	drone.look_at(_focus)


func mouse(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP:
		_height = maxf(6.0, _height / 1.12)
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_height = minf(40.0, _height * 1.12)


func next_view() -> void:
	view = (view + 1) % (_cams.size() + 1)
	if view == 0:
		drone.make_current()
	else:
		_cams[view - 1].make_current()
	_overlay.visible = view > 0


func view_name() -> String:
	return "DRONE" if view == 0 else str(CCTV[view - 1]["name"])


## The CCTV camera you're watching shows everyone in its room.
func sees(h) -> bool:
	if view == 0 or h.is_dead:
		return false
	return graph.room_at(h.global_position) == str(CCTV[view - 1]["room"])
