extends RefCounted
## Gives a loaded model its surface looks (wood grain, cloth weave, worn metal, chipped paint) from its
## material names: art/src/make_sewing.py names materials <kind>_<colour>. Glowing materials are left alone.
## Usage: KindLook.apply(node) after instancing a .glb.

const SHADER := preload("res://v2/world/kind_look.gdshader")
const KINDS := {"plain": 0, "wood": 1, "fabric": 2, "metal": 3, "paint": 4}

static var _cache := {}


static func apply(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				var sm := _swap(m, mi.name)
				if sm:
					mi.set_surface_override_material(s, sm)
	for c in n.get_children():
		apply(c)


static func _swap(m: Material, obj_name: String) -> Material:
	if not (m is StandardMaterial3D):
		return null
	var std := m as StandardMaterial3D
	if std.emission_enabled:
		return null
	var nm := std.resource_name
	var kind := nm.split("_")[0]
	if not KINDS.has(kind):
		return null
	var key := "%s|%d" % [nm, hash(obj_name) % 4]
	if _cache.has(key):
		return _cache[key]
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	sm.set_shader_parameter("albedo", std.albedo_color)
	sm.set_shader_parameter("kind", KINDS[kind])
	sm.set_shader_parameter("seed", float(hash(obj_name) % 4))
	_cache[key] = sm
	return sm


## The kind look for one material built in code (name it <kind>_<colour> in resource_name); the material
## itself if its kind isn't known. For meshes that use material_override (v2/combat/level.gd).
static func look(m: StandardMaterial3D, salt := "") -> Material:
	var sm := _swap(m, salt)
	return sm if sm else m
