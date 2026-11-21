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
var follow := true
var _dof: CameraAttributesPractical
var _rain: GPUParticles3D


func setup(p_main, p_graph) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = p_main
	graph = p_graph
	drone = Camera3D.new()
	drone.fov = 55.0
	main.add_child(drone)
	drone.make_current()
	# Depth of field: sharp where the squad is, soft in front and behind.
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_near_enabled = true
	_dof.dof_blur_amount = 0.2
	drone.attributes = _dof
	_grade_and_weather()
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
	var pan := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		pan.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		pan.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		pan.x += 1.0
	if pan != Vector3.ZERO:
		follow = false
		_focus += pan.normalized() * _height * 0.04
	elif follow and main.brain != null and not main.brain.alive().is_empty():
		_focus = _focus.lerp(main.brain.centroid(), w)
	drone.global_position = _focus + Vector3(0.0, _height, _height * 0.62)
	drone.look_at(_focus)
	if _dof != null:
		var dist: float = drone.global_position.distance_to(_focus)
		# Tilt-shift: a thin sharp band around the squad, soft above and below.
		_dof.dof_blur_far_distance = dist + 2.5
		_dof.dof_blur_far_transition = 6.0
		_dof.dof_blur_near_distance = maxf(0.5, dist - 3.5)
		_dof.dof_blur_near_transition = 3.0
	if _rain != null:
		_rain.global_position = _focus + Vector3(0, 12, 2)


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


## The muted, slightly cold look of the reference footage, and rain over the squad.
func _grade_and_weather() -> void:
	for we in main.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = we.environment
		env.adjustment_enabled = true
		env.adjustment_saturation = 0.72
		env.adjustment_contrast = 1.12
		env.adjustment_brightness = 0.95
		env.fog_enabled = true
		env.fog_light_color = Color(0.62, 0.66, 0.7)
		env.fog_density = 0.006
	_rain = GPUParticles3D.new()
	_rain.amount = 1400
	_rain.lifetime = 1.4
	_rain.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = pm
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.55)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.material = m
	_rain.draw_pass_1 = streak
	main.add_child(_rain)
