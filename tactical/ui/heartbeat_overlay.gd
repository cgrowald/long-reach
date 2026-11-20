extends MeshInstance3D
## Heartbeat sensor display: hidden hostiles within range of a sensor carrier show as
## pulsing red blips, drawn through walls. Only position, no facing or weapon info.

const PULSE_SECONDS := 1.1
const BLIP_MIN := 0.35
const BLIP_MAX := 1.5
const CORE := 0.4
const LIFT := Vector3(0.0, 0.12, 0.0)
const COLOR := Color(1.0, 0.2, 0.15)

var _friendlies: Array = []
var _hostiles: Array = []
var _imesh: ImmediateMesh
var _mat: StandardMaterial3D


func setup(friendlies: Array, hostiles: Array) -> void:
	_friendlies = friendlies
	_hostiles = hostiles


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


## Hostiles currently picked up by any living sensor carrier (and not already seen).
func detected() -> Array:
	var out: Array = []
	for h in _hostiles:
		if h.is_dead or h.revealed:
			continue
		for f in _friendlies:
			if not f.is_dead and f.heartbeat_range > 0.0 \
					and f.global_position.distance_to(h.global_position) <= f.heartbeat_range:
				out.append(h)
				break
	return out


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	var hits: Array = detected()
	for h in _hostiles:
		h.sensed = hits.has(h)
	if hits.is_empty():
		return
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, PULSE_SECONDS) / PULSE_SECONDS
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for h in hits:
		var p: Vector3 = h.global_position + LIFT
		_disc(p, 0.0, CORE, Color(COLOR, 0.95))                                  # solid core
		var r: float = lerpf(BLIP_MIN, BLIP_MAX, t)
		_disc(p, r - 0.12, r, Color(COLOR, 0.9 * (1.0 - t)))                       # expanding ring
		var r2: float = lerpf(BLIP_MIN, BLIP_MAX, fmod(t + 0.5, 1.0))
		_disc(p, r2 - 0.08, r2, Color(COLOR, 0.6 * (1.0 - fmod(t + 0.5, 1.0))))   # second ring
	_imesh.surface_end()


## Filled ring (or disc when inner = 0) as triangles on the ground plane.
func _disc(center: Vector3, inner: float, outer: float, c: Color) -> void:
	var seg: int = 24
	for k in seg:
		var a0: float = TAU * k / seg
		var a1: float = TAU * (k + 1) / seg
		var o0: Vector3 = center + Vector3(cos(a0), 0, sin(a0)) * outer
		var o1: Vector3 = center + Vector3(cos(a1), 0, sin(a1)) * outer
		var i0: Vector3 = center + Vector3(cos(a0), 0, sin(a0)) * inner
		var i1: Vector3 = center + Vector3(cos(a1), 0, sin(a1)) * inner
		for v in [o0, o1, i0, i0, o1, i1]:
			_imesh.surface_set_color(c)
			_imesh.surface_add_vertex(v)
