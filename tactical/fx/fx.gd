extends RefCounted
## Short-lived visual effects. Presentation only, no game rules here.

static var _mats: Dictionary = {}


static func tracer(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var dir: Vector3 = to - from
	var length: float = dir.length()
	if length < 0.01:
		return
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, length)
	m.mesh = box
	m.material_override = _unshaded(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var up: Vector3 = Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	m.look_at_from_position((from + to) * 0.5, to, up)
	# Pauses with the game, so tracers freeze mid-air when you pause.
	parent.get_tree().create_timer(0.06, false).timeout.connect(m.queue_free)


static func move_marker(parent: Node3D, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.35
	m.mesh = torus
	m.material_override = _unshaded(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3(0.0, 0.06, 0.0)
	parent.get_tree().create_timer(0.4, true).timeout.connect(m.queue_free)


static func _unshaded(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_mats[key] = mat
	return mat
