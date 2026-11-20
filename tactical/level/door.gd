extends Node3D
## A hinged door filling a doorway. Closed: blocks line of sight (collision layer 1)
## and soldiers stop in front of it until ordered to open, kick or breach it.
## Navmesh is baked before doors exist, so paths go through doorways regardless.

const WIDTH := 1.24  # slightly wider than the 1.2 m doorway so no sight line slips past the edges
const HEIGHT := 2.05
const THICKNESS := 0.08
const COLOR := Color(0.5, 0.36, 0.2)

var center: Vector3 = Vector3.ZERO
var along_x: bool = true
var is_open: bool = false
var destroyed: bool = false

var _pivot: Node3D
var _col: CollisionShape3D


func setup(p_center: Vector3, p_along_x: bool) -> void:
	center = p_center
	along_x = p_along_x


## Unit vector perpendicular to the wall (which side you're on = sign of dot product).
func normal() -> Vector3:
	return Vector3.BACK if along_x else Vector3.RIGHT


func _ready() -> void:
	add_to_group("doors")
	var axis: Vector3 = Vector3.RIGHT if along_x else Vector3.BACK
	_pivot = Node3D.new()
	_pivot.position = center - axis * (WIDTH * 0.5)
	_pivot.rotation.y = 0.0 if along_x else -PI * 0.5
	add_child(_pivot)

	var body := StaticBody3D.new()
	body.position = Vector3(WIDTH * 0.5, HEIGHT * 0.5, 0.0)
	body.set_meta("material", "wood")
	_pivot.add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, HEIGHT, THICKNESS)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)

	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	_col.shape = shape
	body.add_child(_col)


func open() -> void:
	_swing(0.6, PI * 0.5)


func kick() -> void:
	_swing(0.12, PI * 0.6)


## Breach charge: the door is gone.
func blow() -> void:
	if destroyed:
		return
	destroyed = true
	is_open = true
	_col.set_deferred("disabled", true)
	_pivot.visible = false
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.7, 0.3, 0.9)
	flash.material_override = mat
	add_child(flash)
	flash.global_position = center + Vector3(0.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 3.0, 0.2)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)


func _swing(duration: float, angle: float) -> void:
	if is_open:
		return
	is_open = true
	_col.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y + angle, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
