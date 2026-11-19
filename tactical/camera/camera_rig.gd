extends Node3D
## Free tactical camera with optional lock-on follow.
## Keeps working while the game is paused (process_mode ALWAYS).
##
## Controls:
##   WASD / arrows   pan (breaks follow)
##   Q / E           rotate
##   Middle mouse    drag to rotate and tilt
##   Mouse wheel     zoom

@export var pan_speed: float = 22.0
@export var key_rotate_speed: float = 1.8
@export var mouse_sensitivity: float = 0.005
@export var zoom_min: float = 4.0
@export var zoom_max: float = 70.0
@export var zoom_step: float = 1.15
@export var follow_sharpness: float = 8.0

var camera: Camera3D
var follow_target: Node3D = null

var _pitch_node: Node3D
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-55.0)
var _distance: float = 30.0
var _target_distance: float = 30.0
var _rotating: bool = false

const PITCH_MIN := -85.0
const PITCH_MAX := -12.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	camera = Camera3D.new()
	camera.far = 500.0
	_pitch_node.add_child(camera)
	camera.make_current()
	_apply_transform()


func follow(target: Node3D) -> void:
	follow_target = target


func release() -> void:
	follow_target = null


func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0

	if input != Vector2.ZERO:
		follow_target = null
		var speed: float = pan_speed * (_distance / 30.0)
		var move := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, _yaw)
		position += move * speed * delta

	if Input.is_physical_key_pressed(KEY_Q):
		_yaw += key_rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_E):
		_yaw -= key_rotate_speed * delta

	if follow_target != null:
		if is_instance_valid(follow_target):
			var t: float = 1.0 - exp(-follow_sharpness * delta)
			position = position.lerp(follow_target.global_position, t)
		else:
			follow_target = null

	_distance = lerpf(_distance, _target_distance, 1.0 - exp(-10.0 * delta))
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_distance = clampf(_target_distance / zoom_step, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_distance = clampf(_target_distance * zoom_step, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = mb.pressed
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - mm.relative.y * mouse_sensitivity, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func _apply_transform() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_node.rotation = Vector3(_pitch, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, _distance)
