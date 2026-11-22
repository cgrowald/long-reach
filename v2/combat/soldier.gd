extends Node3D
## A fighter (docs/COMBAT_SLICE.md section 6): a joint rig built in code, faceted body segments and gear
## from art/soldier.glb hung on it, camo painted per face, a weapon light and a helmet-cam mount.
## Procedural animation: tactical walk, aim with the rifle (2-bone IK puts the hands on the rifle), sway.
## Forward is -Z. Limb segments hang down -Y from their joint.

const KIT := preload("res://art/soldier.glb")
const UPPER := 0.29
const LOWER := 0.26

## Per-face palettes by material name. "camo" is patterned; the rest just vary a little per face.
const CAMO := {
	"multicam": [Color(0.33, 0.32, 0.24), Color(0.26, 0.24, 0.17), Color(0.38, 0.36, 0.27), Color(0.2, 0.22, 0.15), Color(0.13, 0.12, 0.1)],
	"woodland": [Color(0.3, 0.33, 0.22), Color(0.2, 0.23, 0.15), Color(0.35, 0.29, 0.2), Color(0.1, 0.1, 0.08), Color(0.28, 0.3, 0.2)],
	"black": [Color(0.12, 0.12, 0.13), Color(0.09, 0.09, 0.1), Color(0.15, 0.15, 0.16), Color(0.07, 0.07, 0.08), Color(0.11, 0.11, 0.12)],
}
const FLAT := {
	"coyote": Color(0.36, 0.3, 0.21), "ranger": Color(0.21, 0.24, 0.17), "black": Color(0.07, 0.07, 0.075),
	"skin": Color(0.5, 0.38, 0.3), "glove": Color(0.15, 0.14, 0.12), "red": Color(0.6, 0.09, 0.07),
	"metal": Color(0.26, 0.27, 0.28), "strap": Color(0.2, 0.2, 0.17), "tan": Color(0.6, 0.52, 0.38),
}

static var _src := {}           # part name -> original Mesh from the glb
static var _cache := {}         # "part|camo" -> painted ArrayMesh
static var _vc_mat: StandardMaterial3D
static var _lens_mat: StandardMaterial3D
static var _noise: FastNoiseLite

var fighter_name := ""
var loadout: Dictionary = {}
var hips: Node3D
var chest: Node3D
var neck: Node3D
var shoulder := {}
var elbow := {}
var wrist := {}
var hip := {}
var knee := {}
var ankle := {}
var rifle: Node3D
var light: SpotLight3D
var cam_mount: Node3D

# animation state (set by whoever drives the soldier)
var move_speed := 0.0            # m/s, forward along the body's facing
var aim_yaw := 0.0               # radians, relative to the body
var aim_pitch := -0.05
var raised := 1.0                # 1 = rifle up (aiming), 0 = low ready
var crouch := 0.25               # 0 = upright, 1 = deep tactical crouch
var _phase := 0.0
var _t := 0.0
var _sway_seed := 0.0


## loadout: {name, camo, head: helmet|cap|none, mask: bool, back: pack|medbag|hydration|"", knees: bool}
func setup(p_loadout: Dictionary) -> void:
	loadout = p_loadout
	fighter_name = str(loadout.get("name", "?"))
	_sway_seed = randf() * 100.0
	var camo: String = loadout.get("camo", "multicam")
	hips = _joint(self, Vector3(0, 1.0, 0))
	_hang(hips, "Body_Pelvis", camo)
	_hang(hips, "Gear_Belt", camo)
	chest = _joint(hips, Vector3(0, 0.02, 0))
	_hang(chest, "Body_Chest", camo)
	_hang(chest, "Gear_Carrier", camo)
	match str(loadout.get("back", "")):
		"pack":
			_hang(chest, "Gear_Pack", camo)
		"medbag":
			_hang(chest, "Gear_MedBag", camo)
		"hydration":
			_hang(chest, "Gear_Hydration", camo)
	neck = _joint(chest, Vector3(0, 0.5, 0))
	_hang(neck, "Body_Head", camo)
	match str(loadout.get("head", "helmet")):
		"helmet":
			_hang(neck, "Gear_Helmet", camo)
		"cap":
			_hang(neck, "Gear_Cap", camo)
	if loadout.get("mask", false):
		_hang(neck, "Gear_GasMask", camo)
	cam_mount = _joint(neck, Vector3(0.15, 0.215, -0.1))
	for s in ["L", "R"]:
		var sx := -1.0 if s == "L" else 1.0
		shoulder[s] = _joint(chest, Vector3(0.2 * sx, 0.42, 0))
		_hang(shoulder[s], "Body_UpperArm_" + s, camo)
		elbow[s] = _joint(shoulder[s], Vector3(0, -UPPER, 0))
		_hang(elbow[s], "Body_LowerArm_" + s, camo)
		wrist[s] = _joint(elbow[s], Vector3(0, -LOWER, 0))
		_hang(wrist[s], "Body_Hand_" + s, camo)
		hip[s] = _joint(hips, Vector3(0.1 * sx, -0.06, 0))
		_hang(hip[s], "Body_Thigh_" + s, camo)
		knee[s] = _joint(hip[s], Vector3(0, -0.42, 0))
		_hang(knee[s], "Body_Shin_" + s, camo)
		if loadout.get("knees", true):
			_hang(knee[s], "Gear_KneePad_" + s, camo)
		ankle[s] = _joint(knee[s], Vector3(0, -0.4, 0))
		_hang(ankle[s], "Body_Boot_" + s, camo)
	rifle = _joint(chest, Vector3(0.13, 0.37, -0.1))
	_hang(rifle, "Gear_Rifle", camo)
	light = SpotLight3D.new()
	light.position = Vector3(0.042, -0.01, -0.75)
	light.light_color = Color(0.92, 0.95, 1.0)
	light.light_energy = 2.4
	light.spot_range = 18.0
	light.spot_angle = 17.0
	light.spot_angle_attenuation = 2.2
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 2.2
	rifle.add_child(light)
	_pose(0.0)


func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = at
	parent.add_child(j)
	return j


func _hang(j: Node3D, part: String, camo: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = painted(part, camo)
	mi.name = part
	j.add_child(mi)
	return mi


# ------------------------------------------------------------------ meshes (painted once, cached)

static func _load_kit() -> void:
	if not _src.is_empty():
		return
	var inst := KIT.instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		_src[n.name] = (n as MeshInstance3D).mesh
	inst.free()
	_vc_mat = StandardMaterial3D.new()
	_vc_mat.vertex_color_use_as_albedo = true
	_vc_mat.vertex_color_is_srgb = true
	_vc_mat.roughness = 0.88
	_lens_mat = StandardMaterial3D.new()
	_lens_mat.albedo_color = Color(0.8, 0.9, 1.0)
	_lens_mat.emission_enabled = true
	_lens_mat.emission = Color(0.8, 0.9, 1.0)
	_lens_mat.emission_energy_multiplier = 1.5
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 6.0
	_noise.seed = 11


static func painted(part: String, camo: String) -> Mesh:
	_load_kit()
	var key := part + "|" + camo
	if _cache.has(key):
		return _cache[key]
	var src: Mesh = _src.get(part)
	if src == null:
		push_error("soldier: no part %s in art/soldier.glb" % part)
		return BoxMesh.new()
	var out := ArrayMesh.new()
	var pal: Array = CAMO.get(camo, CAMO["multicam"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for si in src.get_surface_count():
		var mname := ""
		var smat := src.surface_get_material(si)
		if smat:
			mname = smat.resource_name
		var mdt := MeshDataTool.new()
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(si))
		mdt.create_from_surface(am, 0)
		for f in mdt.get_face_count():
			var c := Vector3.ZERO
			for k in 3:
				c += mdt.get_vertex(mdt.get_face_vertex(f, k))
			c /= 3.0
			var col: Color
			if mname == "camo":
				var n := _noise.get_noise_3dv(c * 1.0 + Vector3(rng.randf() * 0.02, 0, 0))
				var n2 := _noise.get_noise_3dv(c * 2.3 + Vector3(31, 7, 3))
				var idx := 0
				if n > 0.35:
					idx = 2
				elif n < -0.4:
					idx = 4
				elif n2 > 0.25:
					idx = 1
				elif n2 < -0.3:
					idx = 3
				col = pal[idx]
			else:
				col = FLAT.get(mname, Color(0.4, 0.4, 0.4))
			col = col * rng.randf_range(0.9, 1.08)
			col.a = 1.0
			for k in 3:
				mdt.set_vertex_color(mdt.get_face_vertex(f, k), col)
		var painted_mesh := ArrayMesh.new()
		mdt.commit_to_surface(painted_mesh)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, painted_mesh.surface_get_arrays(0))
		out.surface_set_material(out.get_surface_count() - 1, _lens_mat if mname == "lens" else _vc_mat)
	_cache[key] = out
	return out


# ------------------------------------------------------------------ animation

var _kick := 0.0
var _burst := 0
var _burst_t := 0.0
var _flash: OmniLight3D


## A short burst: muzzle flash lighting the walls, the rifle kicking back each round.
func fire(rounds := 4) -> void:
	_burst = rounds
	_burst_t = randf() * 0.08
	if _flash == null:
		_flash = OmniLight3D.new()
		_flash.light_color = Color(1.0, 0.75, 0.4)
		_flash.omni_range = 7.0
		_flash.light_volumetric_fog_energy = 3.0
		_flash.position = Vector3(0, 0, -0.98)
		_flash.light_energy = 0.0
		rifle.add_child(_flash)


func _process(delta: float) -> void:
	_t += delta
	_phase += delta * move_speed * 4.2
	if _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst -= 1
			_burst_t = 0.085
			_kick = 1.0
			_flash.light_energy = 9.0
	if _flash:
		_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 160.0)
	_kick = maxf(0.0, _kick - delta * 12.0)
	_pose(delta)


func _pose(_delta: float) -> void:
	if hips == null:
		return
	var moving := clampf(move_speed / 1.2, 0.0, 1.0)
	var s := sin(_phase)
	# hips: lower when crouched, bob while walking
	hips.position.y = 1.0 - crouch * 0.11 - absf(cos(_phase)) * 0.025 * moving
	hips.rotation = Vector3(0, s * 0.06 * moving, 0)
	# legs: a bent-knee tactical walk
	for side in ["L", "R"]:
		var ph := _phase + (0.0 if side == "L" else PI)
		var sw := sin(ph) * 0.42 * moving
		var lift := maxf(0.0, -sin(ph + 0.6)) * 0.75 * moving
		(hip[side] as Node3D).rotation = Vector3(crouch * 0.32 + sw, 0, 0)
		(knee[side] as Node3D).rotation = Vector3(-(crouch * 0.6 + lift), 0, 0)
		(ankle[side] as Node3D).rotation = Vector3(crouch * 0.28 - sw * 0.4 + lift * 0.5, 0, 0)
	# torso leans into the rifle and turns toward the aim; a little breathing and sway
	var sway := Vector2(sin(_t * 1.3 + _sway_seed) * 0.02 + sin(_t * 2.9 + _sway_seed) * 0.01, sin(_t * 1.7 + _sway_seed) * 0.015)
	chest.rotation = Vector3(-0.12 - crouch * 0.08 + sway.y, aim_yaw * 0.85 - hips.rotation.y + sway.x, 0)
	neck.rotation = Vector3(-0.04 + aim_pitch * 0.6, aim_yaw * 0.15, 0)
	# rifle: shouldered and pointed along the aim, or dipped to low ready
	var pitch := lerpf(-0.45, aim_pitch + 0.12 + crouch * 0.08, raised)
	rifle.rotation = Vector3(pitch + _kick * 0.06, 0.04, 0)
	rifle.position = Vector3(0.12, lerpf(0.3, 0.37, raised), lerpf(-0.05, -0.1, raised) + _kick * 0.035)
	# hands on the rifle (2-bone IK), elbows out and down
	var grip := rifle.to_global(Vector3(0, -0.1, -0.31))
	var fore := rifle.to_global(Vector3(-0.01, -0.09, -0.6))
	var down := -chest.global_basis.y
	_ik("R", grip, (down + chest.global_basis.x * 0.6).normalized())
	_ik("L", fore, (down - chest.global_basis.x * 0.9).normalized())


## Two-bone IK: point the upper arm and forearm so the wrist lands on target, the elbow toward pole.
func _ik(side: String, target: Vector3, pole: Vector3) -> void:
	var sh: Node3D = shoulder[side]
	var el: Node3D = elbow[side]
	var s := sh.global_position
	var d := target - s
	var dist := clampf(d.length(), 0.08, UPPER + LOWER - 0.002)
	var dir := d.normalized()
	var cos_a := (UPPER * UPPER + dist * dist - LOWER * LOWER) / (2.0 * UPPER * dist)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var p := (pole - dir * pole.dot(dir)).normalized()
	var e := s + dir * cos(a) * UPPER + p * sin(a) * UPPER
	var hand := s + dir * dist
	sh.global_transform = Transform3D(_down_basis(e - s, p), s)
	el.global_transform = Transform3D(_down_basis(hand - e, p), el.global_position)


## A basis whose -Y runs along v (a limb hanging toward v), +Z as close to hint as it can.
static func _down_basis(v: Vector3, hint: Vector3) -> Basis:
	var y := -v.normalized()
	var z := (hint - y * hint.dot(y))
	if z.length() < 0.001:
		z = Vector3.FORWARD
	z = z.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	return Basis(x, y, z)
