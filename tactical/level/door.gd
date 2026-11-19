extends Node3D
## A hinged door filling a doorway. Closed: blocks movement visuals and line of sight
## (collision layer 1). Units open it quietly or kick it (fast, loud).
## Navmesh is baked before doors exist, so paths go through doorways regardless.

const WIDTH := 1.15
const HEIGHT := 2.05
const THICKNESS := 0.08
const COLOR := Color(0.5, 0.36, 0.2)

var center: Vector3 = Vector3.ZERO
var along_x: bool = true
var is_open: bool = false

var _pivot: Node3D
var _col: CollisionShape3D


func setup(p_center: Vector3, p_along_x: bool) -> void:
	center = p_center
	along_x = p_along_x


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


func _swing(duration: float, angle: float) -> void:
	if is_open:
		return
	is_open = true
	_col.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y + angle, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
