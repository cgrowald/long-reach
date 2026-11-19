extends Node3D
## A thrown grenade: arcs to its landing point, waits for its fuse, then detonates.
## Flashbang: stuns everyone in radius with line of sight to the blast (less if facing away).
## Frag: damage falling off with distance, blocked by walls.
## Numbers come from data/equipment.json.

const GameData := preload("res://sim/game_data.gd")
const LOS_MASK := 1

var kind: String = "flashbang"
var _data: Dictionary = {}
var _from: Vector3
var _to: Vector3
var _thrower
var _arc_height: float = 1.3


func setup(p_kind: String, from: Vector3, to: Vector3, thrower, arc_height: float = 1.3) -> void:
	_arc_height = arc_height
	kind = p_kind
	_data = GameData.equipment(kind)
	_from = from
	_to = to
	_thrower = thrower


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.8) if kind == "flashbang" else Color(0.25, 0.35, 0.2)
	mesh.material_override = mat
	add_child(mesh)
	global_position = _from
	var tween := create_tween()
	tween.tween_method(_arc, 0.0, 1.0, float(_data.get("flight_time", 0.6)))
	tween.tween_interval(float(_data.get("fuse", 1.0)))
	tween.tween_callback(_detonate)


func _arc(t: float) -> void:
	global_position = _from.lerp(_to, t) + Vector3(0.0, sin(t * PI) * _arc_height, 0.0)


func _detonate() -> void:
	var blast: Vector3 = global_position + Vector3(0.0, 0.3, 0.0)
	var radius: float = float(_data.get("radius", 5.0))
	var noise: float = float(_data.get("noise_range", 30.0))
	var space := get_world_3d().direct_space_state
	for u in get_tree().get_nodes_in_group("units"):
		if u.is_dead:
			continue
		var d: float = u.global_position.distance_to(blast)
		if d <= noise:
			u.hear_noise(blast)
		if d > radius:
			continue
		var target: Vector3 = u.global_position + Vector3(0.0, u.chest_height(), 0.0)
		var clear: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(blast, target, LOS_MASK)).is_empty()
		if not clear:
			continue
		if kind == "flashbang":
			var secs: float = float(_data.get("stun_seconds", 4.0))
			if not u.in_fov(blast - u.global_position):
				secs *= float(_data.get("facing_away_factor", 0.5))
			u.stun(secs)
		else:
			var falloff: float = 1.0 - d / radius
			u.take_damage(float(_data.get("damage", 120.0)) * falloff * falloff + 10.0, _thrower)
	_explosion_visual()


func _explosion_visual() -> void:
	for c in get_children():
		c.queue_free()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 0.95, 0.9) if kind == "flashbang" else Color(1.0, 0.55, 0.15, 0.9)
	mesh.material_override = mat
	add_child(mesh)
	var size: float = float(_data.get("radius", 5.0)) * 0.6
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * size, 0.18)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
