extends Control
## Combat look test (docs/COMBAT_SLICE.md build step 1): four named fighters in their gear stacking down a
## dark, dingy corridor, seen through helmet cams (1-4) or a hacked CCTV camera (5). Judge the look
## against docs/refs/combat/03. F = a fire burst, Space = pause, Esc = back to the title.

const Pal := preload("res://v2/ui/pal.gd")
const PixelView := preload("res://v2/ui/pixel_view.gd")
const Soldier := preload("res://v2/combat/soldier.gd")
const GRIME := preload("res://v2/combat/grime.gdshader")
const FEED := preload("res://v2/combat/feedcam.gdshader")

const SQUAD := [
	{"name": "JONAS BRENN", "role": "point", "camo": "multicam", "head": "helmet", "back": "", "x": -0.42},
	{"name": "ADA LIND", "role": "breacher", "camo": "multicam", "head": "helmet", "mask": true, "back": "hydration", "x": 0.42},
	{"name": "MIRA KOVAC", "role": "medic", "camo": "multicam", "head": "helmet", "back": "medbag", "x": -0.38},
	{"name": "IVO PETRAK", "role": "rear", "camo": "multicam", "head": "helmet", "back": "pack", "x": 0.36},
]
const DOORS_Z := [-4.0, -10.0, -16.0]
const LEN := 24.0

var game: Node
var view
var world: Node3D
var cam: Camera3D
var post: ShaderMaterial
var hud: Control
var squad: Array = []
var lights: Array = []          # flickering tubes: {light, mesh, base}
var view_i := 3                 # 0-3 helmet cams, 4 = CCTV
var paused := false
var lead_z := 1.0
var _t := 0.0
var _mats := {}


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = PixelView.new()
	add_child(view)
	world = Node3D.new()
	view.vp.add_child(world)
	_environment()
	_corridor()
	_squad()
	cam = Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.05
	world.add_child(cam)
	cam.current = true
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	q.mesh = qm
	post = ShaderMaterial.new()
	post.shader = FEED
	q.material_override = post
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(0, 0, -0.5)
	cam.add_child(q)
	var fill := OmniLight3D.new()           # the cheap sensor's low-light gain: your own rifle and hands show
	fill.light_energy = 0.12
	fill.omni_range = 1.3
	fill.light_color = Color(0.7, 0.85, 0.9)
	fill.position = Vector3(0, 0.05, -0.5)
	cam.add_child(fill)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.ui.add_child(hud)
	hud.draw.connect(_draw_hud)


# ------------------------------------------------------------------ the place

func _environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.32, 0.36)
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.45
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.022
	e.volumetric_fog_albedo = Color(0.7, 0.75, 0.8)
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 32.0
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.05
	we.environment = e
	world.add_child(we)


func _mat(kind: int, paint := Color(0.44, 0.43, 0.35)) -> ShaderMaterial:
	var k := str(kind) + str(paint)
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = GRIME
		m.set_shader_parameter("kind", kind)
		m.set_shader_parameter("paint", Vector3(paint.r, paint.g, paint.b))
		_mats[k] = m
	return _mats[k]


func _flat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	world.add_child(mi)
	return mi


func _corridor() -> void:
	var wall := _mat(0)
	var room_wall := _mat(0, Color(0.36, 0.39, 0.36))
	var z0 := 2.5
	var z1 := z0 - LEN
	var zc := (z0 + z1) * 0.5
	_box(Vector3(11, 0.1, LEN), Vector3(3.0, -0.05, zc), _mat(1))
	_box(Vector3(11, 0.1, LEN), Vector3(3.0, 2.85, zc), _mat(2))
	_box(Vector3(0.1, 2.8, LEN), Vector3(-1.25, 1.4, zc), wall)               # left wall
	_box(Vector3(2.6, 2.8, 0.1), Vector3(0, 1.4, z0), wall)                   # behind the stack
	_box(Vector3(2.6, 2.8, 0.1), Vector3(-0.85, 1.4, z1), wall)               # far end, with a doorway
	_box(Vector3(0.9, 0.7, 0.1), Vector3(0.0, 2.45, z1), wall)
	_box(Vector3(0.6, 2.8, 0.1), Vector3(0.95, 1.4, z1), wall)
	# right wall with three doorways into dark rooms
	var edges := [z0]
	for dz in DOORS_Z:
		edges.append(dz + 0.5)
		edges.append(dz - 0.5)
	edges.append(z1)
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		_box(Vector3(0.1, 2.8, a - b), Vector3(1.25, 1.4, (a + b) * 0.5), wall)
	for dz in DOORS_Z:
		_box(Vector3(0.1, 0.7, 1.0), Vector3(1.25, 2.45, dz), wall)          # header
		var frame := _flat(Color(0.12, 0.1, 0.09))
		_box(Vector3(0.16, 2.1, 0.06), Vector3(1.25, 1.05, dz + 0.5), frame)
		_box(Vector3(0.16, 2.1, 0.06), Vector3(1.25, 1.05, dz - 0.5), frame)
		_box(Vector3(0.16, 0.06, 1.06), Vector3(1.25, 2.1, dz), frame)
		var slab := _box(Vector3(0.05, 2.05, 0.95), Vector3(1.75, 1.03, dz + 0.75), _flat(Color(0.2, 0.17, 0.15)))
		slab.rotation.y = -1.1
	# the rooms behind: side walls, a back wall, a table and a chair in the dark
	for wz in [-1.0, -7.0, -13.0, -19.0]:
		_box(Vector3(4.0, 2.8, 0.1), Vector3(3.25, 1.4, wz), room_wall)
	_box(Vector3(0.1, 2.8, LEN), Vector3(5.25, 1.4, zc), room_wall)
	for dz in DOORS_Z:
		var tz: float = dz + randf_range(-1.0, 1.0)
		_box(Vector3(1.4, 0.06, 0.8), Vector3(3.6, 0.76, tz), _flat(Color(0.22, 0.18, 0.14)))
		for lx in [-0.6, 0.6]:
			for lz in [-0.32, 0.32]:
				_box(Vector3(0.05, 0.76, 0.05), Vector3(3.6 + lx, 0.38, tz + lz), _flat(Color(0.12, 0.1, 0.08)))
		_box(Vector3(0.45, 0.06, 0.45), Vector3(2.8, 0.45, tz + 0.6), _flat(Color(0.15, 0.15, 0.16)), Vector3(0, 0.4, 0))
	# pipes along the ceiling, with brackets
	var rust := _flat(Color(0.36, 0.2, 0.12))
	var rust_d := _flat(Color(0.25, 0.16, 0.11))
	for p in [[-1.02, 2.55, 0.09, rust], [-0.8, 2.66, 0.06, rust_d], [1.05, 2.7, 0.05, rust_d]]:
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = p[2]
		cy.bottom_radius = p[2]
		cy.height = LEN
		cy.radial_segments = 7
		mi.mesh = cy
		mi.material_override = p[3]
		mi.position = Vector3(p[0], p[1], zc)
		mi.rotation.x = PI * 0.5
		world.add_child(mi)
	for bz in range(int(z0) - 1, int(z1), -2):
		_box(Vector3(0.3, 0.04, 0.05), Vector3(-1.05, 2.72, bz), _flat(Color(0.1, 0.1, 0.1)))
	# fluorescent tubes: one dying, one steady at the far end
	for spec in [[-7.5, 0.55, true], [-19.5, 1.0, false]]:
		var lz: float = spec[0]
		var tube := _box(Vector3(0.14, 0.05, 1.2), Vector3(0, 2.78, lz), _flat(Color(0.75, 0.92, 1.0), 3.0))
		var l := OmniLight3D.new()
		l.position = Vector3(0, 2.6, lz)
		l.light_color = Color(0.72, 0.9, 1.0)
		l.light_energy = spec[1]
		l.omni_range = 6.5
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 1.5
		world.add_child(l)
		lights.append({"light": l, "mesh": tube, "base": spec[1], "flicker": spec[2]})
	# paper, grit and a few chunks on the floor
	var paper := _flat(Color(0.7, 0.68, 0.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 70:
		var pz := rng.randf_range(z1 + 0.5, z0 - 0.5)
		var px := rng.randf_range(-1.1, 1.1) if rng.randf() < 0.75 else rng.randf_range(1.4, 5.0)
		_box(Vector3(0.21, 0.004, 0.29), Vector3(px, 0.004 + i * 0.0001, pz), paper, Vector3(0, rng.randf() * TAU, 0))
	for i in 14:
		_box(Vector3(0.12, 0.06, 0.1) * rng.randf_range(0.6, 1.6), Vector3(rng.randf_range(-1.1, 1.1), 0.03, rng.randf_range(z1, z0)), _flat(Color(0.3, 0.29, 0.27)), Vector3(rng.randf(), rng.randf() * TAU, 0))


# ------------------------------------------------------------------ the stack

func _squad() -> void:
	for i in SQUAD.size():
		var s: Node3D = Soldier.new()
		world.add_child(s)
		s.setup(SQUAD[i])
		s.move_speed = 0.9
		squad.append(s)
	_place()


func _place() -> void:
	for i in squad.size():
		var s: Node3D = squad[i]
		var d: Dictionary = SQUAD[i]
		s.position = Vector3(float(d["x"]), 0, lead_z + i * 1.25)


func _process(delta: float) -> void:
	_t += delta
	if not paused:
		lead_z -= delta * 0.9
		if lead_z < -19.0:
			lead_z = 1.0
		_place()
	for i in squad.size():
		var s: Node3D = squad[i]
		s.move_speed = 0.0 if paused else 0.9
		s.set_process(not paused)
		var yaw := 0.0
		match i:
			0:
				yaw = sin(_t * 0.4) * 0.08
			1:
				# cover the doors on the right as they come up
				for dz in DOORS_Z:
					var ahead: float = s.position.z - dz
					if ahead > -0.5 and ahead < 3.5:
						yaw = -clampf(atan2(1.25 - s.position.x, maxf(0.3, ahead)), 0.0, 1.2)
			2:
				yaw = 0.12 + sin(_t * 0.5 + 1.0) * 0.06
			3:
				yaw = -0.1 + sin(_t * 0.35) * 0.05
		s.aim_yaw = lerpf(s.aim_yaw, yaw, minf(1.0, delta * 4.0))
	for l in lights:
		if l["flicker"]:
			var on := fmod(_t * 7.3, 1.0) > 0.12 or sin(_t * 1.1) > 0.6
			if sin(_t * 0.37) > 0.85:
				on = randf() > 0.5
			(l["light"] as OmniLight3D).light_energy = float(l["base"]) if on else 0.05
			(l["mesh"] as MeshInstance3D).visible = on
	_update_camera(delta)
	post.set_shader_parameter("time_s", _t)
	hud.queue_redraw()


func _update_camera(_delta: float) -> void:
	if view_i < 4:
		var s: Node3D = squad[view_i]
		var m: Node3D = s.cam_mount
		var shake := Vector3(sin(_t * 9.0) * 0.004, absf(sin(_t * 4.5)) * 0.008, 0) * (0.0 if paused else 1.0)
		cam.global_transform = Transform3D(m.global_basis * Basis(Vector3.RIGHT, -0.2), m.global_position + shake)
		cam.fov = 86.0
		post.set_shader_parameter("mono", 0.0)
		post.set_shader_parameter("barrel", 0.28)
		post.set_shader_parameter("round_vignette", 1.0)
		post.set_shader_parameter("tint", Vector3(0.9, 1.0, 1.02))
	else:
		cam.global_transform = Transform3D.IDENTITY.translated(Vector3(0.95, 2.5, -20.9)).looking_at(Vector3(-0.1, 1.0, lead_z + 1.0), Vector3.UP)
		cam.fov = 64.0
		post.set_shader_parameter("mono", 1.0)
		post.set_shader_parameter("barrel", 0.12)
		post.set_shader_parameter("round_vignette", 0.35)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.keycode
	if k >= KEY_1 and k <= KEY_5:
		view_i = k - KEY_1
		if game:
			game.sfx.play("switch_002", 1.0 + view_i * 0.05, -8.0)
	elif k == KEY_SPACE:
		paused = not paused
	elif k == KEY_F:
		for s in squad:
			s.fire()
	elif k == KEY_ESCAPE:
		if game:
			game.goto("res://v2/title.tscn")
		else:
			get_tree().quit()
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ the feed overlay

func _draw_hud() -> void:
	var w := hud.size.x
	var h := hud.size.y
	var col := Color(0.85, 0.95, 0.9)
	var clock := "23:%02d:%02d" % [41 + int(_t / 60.0) % 18, int(_t) % 60]
	if view_i < 4:
		var d: Dictionary = SQUAD[view_i]
		Pal.text(hud, Vector2(14, 10), "CAM %02d  %s" % [view_i + 1, d["name"]], 9, col)
		Pal.text(hud, Vector2(14, 21), str(d["role"]).to_upper(), 8, Color(col, 0.6))
	else:
		Pal.text(hud, Vector2(14, 10), "CCTV-07  DOBREV FREIGHT  B2 CORRIDOR", 9, Color(0.6, 1.0, 0.6))
		Pal.text(hud, Vector2(14, 21), "HACKED FEED", 8, Color(0.6, 1.0, 0.6, 0.6))
	if fmod(_t, 1.0) < 0.6:
		hud.draw_circle(Vector2(w - 66, 15), 3.0, Color(0.9, 0.15, 0.1))
	Pal.text(hud, Vector2(w - 60, 10), "REC  " + clock, 9, col)
	Pal.text(hud, Vector2(14, h - 16), "1-4 helmet cams   5 CCTV   F fire   Space pause   Esc back", 8, Color(col, 0.55))
