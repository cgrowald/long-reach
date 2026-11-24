extends Control
## The sewing table, top-down (M1b, docs/BENCH_SEWING.md; ReStroy + Assemble With Care, the user's picks).
## Its own little 3D world: the table (art/sewing.glb, one stage), the job's base piece in the middle, the loose
## parts laid out around it (art/sewing_parts.glb), your hands. Data: recipe["table"] in data/v2/recipes.json.
##   left-click a part: lift it; it follows the cursor above the table
##   wheel: turn it; right-drag: tip it over to look at any side; right-click: put it back where it lay
##   left-click again: put it down. On its dashed amber outline it snaps in (how close = the fit score)
##   then stitch: rings come round its edge one by one; click each as its closing circle meets it
## Emits finished(scores) with one 0..1 score per part (fit and stitching together) for Crafting.formula.

signal finished(scores: Array)

const Pal := preload("res://v2/ui/pal.gd")
const KindLook := preload("res://v2/world/kind_look.gd")

const TOP := 0.78                 # the table top (metres)
const LIFT := 0.13                # how high a held part floats
const SNAP_DIST := 0.08           # within this (and the angle below) it snaps onto its outline
const SNAP_YAW := 30.0
const RING_TIME := 1.0            # seconds for a stitch ring's circle to close
const RES := 2.0                  # 3D resolution per UI unit
const BASE_AT := Vector3(-0.05, 0.0, 0.13)
const SLOTS := [Vector2(-0.56, -0.02), Vector2(0.48, 0.2), Vector2(-0.56, 0.22), Vector2(0.48, -0.02), Vector2(0.62, 0.2), Vector2(-0.42, 0.3)]

var game: Node
var recipe: Dictionary = {}
var vp: SubViewport
var tex: TextureRect
var cam: Camera3D
var world: Node3D
var base: Node3D
var parts: Array = []             # {node, def, home: Vector3, home_yaw, done, fit, stitch: []}
var mend := false                 # mending a torn item instead of making one (v2/sim/wear.gd job())
var targets: Array = []           # mend: the tears {spot, name, at, done, tear, colour}
var palette_src := {}             # mend: colour -> a hidden template scrap
var patched: Array = []           # mend: [{spot, colour}] as they get done (read by the bench)
var base_scale := 1.0             # mend: big pieces (the jacket) are shown smaller so the scraps fit beside them
const MEND_SLOTS := [Vector2(0.6, -0.05), Vector2(0.6, 0.17), Vector2(-0.64, 0.24)]
var held = null                   # the part dict in hand
var hand_r: Node3D
var hand_l: Node3D
var phase := "fit"                # fit, stitch, done
var stitch_part = null
var rings: Array = []             # Vector3 points round the fitted part
var ring_i := 0
var ring_t := 0.0
var scores: Array = []
var yaw_target := 0.0
var _mouse := Vector2.ZERO
var _rdrag := false
var _rmoved := 0.0
var _tilt := Vector2.ZERO         # tumble while held (x, z radians)
var _float: Array = []            # [text, pos, t, col]
var _t := 0.0
var _done_t := -1.0


func setup(p_game: Node, p_recipe: Dictionary) -> void:
	game = p_game
	recipe = p_recipe
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	tex = TextureRect.new()
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.show_behind_parent = true
	add_child(tex)
	world = Node3D.new()
	vp.add_child(world)
	_build_world()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	tex.position = Vector2.ZERO
	tex.size = size
	vp.size = Vector2i(maxi(64, int(size.x * RES)), maxi(64, int(size.y * RES)))


# ------------------------------------------------------------------ the scene

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.035, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.47, 0.4)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.13, 0.11)
	floor_m.material_override = fm
	world.add_child(floor_m)
	# the table: one stage, moved to the origin; the clutter that sits where you work is cleared away
	var tables := (load("res://art/sewing.glb") as PackedScene).instantiate()
	world.add_child(tables)
	var stage := stage_name()
	for c in tables.get_children():
		c.visible = c.name == stage
		if c.name == stage:
			(c as Node3D).position = Vector3.ZERO
			for k in c.get_children():
				var n := str(k.name)
				if n.begins_with("Runner") or n.begins_with("BluePatch") or n.begins_with("Sc_"):
					k.visible = false
	KindLook.apply(tables)
	_bulbs(tables)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.8, 0.75)
	fill.rotation_degrees = Vector3(-70, 20, 0)
	world.add_child(fill)
	# the job
	var lib := (load("res://art/sewing_parts.glb") as PackedScene).instantiate()
	var t: Dictionary = recipe.get("table", {})
	base = _take(lib, str(t.get("base", "")))
	if base:
		_lay(base, BASE_AT, 0.0)
	var i := 0
	for name in t.get("props", []):
		var pr := _take(lib, str(name))
		if pr:
			_lay(pr, Vector3(0.55, 0, -0.02), 0.0)
	mend = bool(t.get("mend", false))
	if mend:
		_build_mend(lib, t)
	for pd in t.get("parts", []):
		var n := _take(lib, str(pd["part"]))
		if n == null:
			continue
		var s: Vector2 = SLOTS[i % SLOTS.size()]
		var long := _size(n).z > 0.18
		var home := Vector3(s.x, 0, s.y)
		var hy := 90.0 if long else 0.0
		_lay(n, home, hy)
		parts.append({"node": n, "def": pd, "home": home, "home_yaw": hy, "done": false, "fit": 0.0, "stitch": []})
		i += 1
	hand_r = _take(lib, "Hand_R")
	hand_l = _take(lib, "Hand_L")
	if hand_l:
		hand_l.position = Vector3(-0.42, TOP + 0.03, 0.42)
		hand_l.rotation_degrees = Vector3(0, 18, 0)
	lib.queue_free()
	KindLook.apply(world)
	cam = Camera3D.new()
	cam.fov = 42.0
	world.add_child(cam)
	cam.position = Vector3(0.0, TOP + 1.2, 0.8)
	cam.look_at(Vector3(0.0, TOP, 0.1))
	cam.current = true


## Mending (data/v2/wear.json, v2/sim/wear.gd job()): the torn item in the middle with a ragged tear at each
## torn spot and the old patches already on it; scraps in three colours laid out as a palette. Pick up any
## colour, put it over any tear, stitch it. A fresh scrap of that colour takes its place.
const TEAR_BAKED := 53.0          # the Jacket_Tear mesh's own angle on the table (art/src/make_sewing_parts.py)


func _build_mend(lib: Node, t: Dictionary) -> void:
	if base and _size(base).x > 0.8:
		base_scale = 0.75
		base.scale = Vector3(base_scale, 1.0, base_scale)
	var sc := func(at: Array) -> Array: return [float(at[0]) * base_scale, float(at[1]) * base_scale, float(at[2])]
	var tear_src := lib.find_child("Jacket_Tear", true, false) as Node3D
	var top := _base_top()
	for td in t.get("tears", []):
		var at: Array = sc.call(td["at"])
		var tn := tear_src.duplicate() as Node3D
		world.add_child(tn)
		tn.position = Vector3(BASE_AT.x + float(at[0]), top + 0.001, BASE_AT.z + float(at[1]))
		tn.rotation = Vector3(0, deg_to_rad(float(at[2]) + 90.0 - TEAR_BAKED), 0)
		tn.scale = Vector3(base_scale, 1.0, base_scale)
		targets.append({"spot": td["spot"], "name": td["name"], "at": at, "done": false, "tear": tn, "colour": ""})
	var pal: Dictionary = t.get("palette", {})
	for pa in t.get("patches", []):
		var src := lib.find_child(str(pal.get(pa["colour"], "Patch_Blue")), true, false) as Node3D
		if src:
			var pn := src.duplicate() as Node3D
			world.add_child(pn)
			var at2: Array = sc.call(pa["at"])
			_lay(pn, Vector3(BASE_AT.x + float(at2[0]), 0, BASE_AT.z + float(at2[1])), float(at2[2]), top)
	var i := 0
	for colour in pal:
		var src2 := lib.find_child(str(pal[colour]), true, false) as Node3D
		if src2 == null:
			continue
		var keep := src2.duplicate() as Node3D            # a template for fresh scraps of this colour
		keep.visible = false
		world.add_child(keep)
		palette_src[colour] = keep
		var s: Vector2 = MEND_SLOTS[i % MEND_SLOTS.size()]
		_new_scrap(colour, Vector3(s.x, 0, s.y))
		i += 1


func _new_scrap(colour: String, home: Vector3) -> void:
	var n := (palette_src[colour] as Node3D).duplicate() as Node3D
	n.visible = true
	world.add_child(n)
	_lay(n, home, 0.0)
	parts.append({"node": n, "def": {"part": colour, "name": colour + " scrap", "at": [0, 0, 0]}, "home": home, "home_yaw": 0.0,
		"done": false, "fit": 0.0, "stitch": [], "palette": colour})


## The open tear nearest to where a scrap is held.
func _nearest_tear(n: Node3D):
	var best = null
	var bd := 1e9
	for tg in targets:
		if tg["done"]:
			continue
		var at: Array = tg["at"]
		var d := Vector2(n.position.x - BASE_AT.x - float(at[0]), n.position.z - BASE_AT.z - float(at[1])).length()
		if d < bd:
			bd = d
			best = tg
	return best


## Which table you have (upgrades come with bench upgrades later; docs/BENCH_SEWING.md build step 5).
func stage_name() -> String:
	return "Sew_Starter"


func _bulbs(n: Node) -> void:
	if str(n.name).begins_with("Lamp_Bulb"):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.76, 0.48)
		l.light_energy = 1.7
		l.omni_range = 2.4
		l.shadow_enabled = true
		(n as Node3D).add_child(l)
	for c in n.get_children():
		_bulbs(c)


## Take a named piece out of the parts library into this world.
func _take(lib: Node, name: String) -> Node3D:
	var src := lib.find_child(name, true, false) as Node3D
	if src == null:
		push_warning("sew_table: no part " + name)
		return null
	var n := src.duplicate() as Node3D
	n.name = name
	world.add_child(n)
	return n


func _size(n: Node3D) -> Vector3:
	var a := _aabb_local(n)
	return a.size


func _aabb_local(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in [n] + n.find_children("*", "MeshInstance3D", true, false):
		if c is MeshInstance3D:
			var a: AABB = (c as MeshInstance3D).get_aabb()
			if c != n:
				a = (c as Node3D).transform * a
			out = a if first else out.merge(a)
			first = false
	return out


## Lay a piece flat on the table at p (x, z), turned by yaw degrees.
func _lay(n: Node3D, p: Vector3, yaw: float, on := TOP) -> void:
	var a := _aabb_local(n)
	n.rotation = Vector3(0, deg_to_rad(yaw), 0)
	n.position = Vector3(p.x, on - a.position.y, p.z)


func _base_top() -> float:
	return TOP + _size(base).y if base else TOP


func _target(p: Dictionary) -> Vector3:
	var at: Array = p["def"]["at"]
	return Vector3(BASE_AT.x + float(at[0]), 0, BASE_AT.z + float(at[1]))


# ------------------------------------------------------------------ picking

func _vp_pos(ui: Vector2) -> Vector2:
	return ui * Vector2(vp.size) / size


func _ray(ui: Vector2) -> Array:
	var vpp := _vp_pos(ui)
	return [cam.project_ray_origin(vpp), cam.project_ray_normal(vpp)]


## Where the cursor ray meets the horizontal plane at height y.
func _on_plane(ui: Vector2, y: float) -> Vector3:
	var r := _ray(ui)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	if absf(d.y) < 0.0001:
		return o
	return o + d * ((y - o.y) / d.y)


func _part_at(ui: Vector2):
	var r := _ray(ui)
	var best = null
	var bd := 1e9
	for p in parts:
		if p["done"]:
			continue
		var n: Node3D = p["node"]
		var box := n.global_transform * _aabb_local(n).grow(0.01)
		var hit = box.intersects_ray(r[0], r[1])
		if hit != null:
			var d: float = (hit as Vector3).distance_to(r[0])
			if d < bd:
				bd = d
				best = p
	return best


func to_ui(w: Vector3) -> Vector2:
	return cam.unproject_position(w) * size / Vector2(vp.size)


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = e.position
		if _rdrag and held != null:
			_rmoved += e.relative.length()
			_tilt += Vector2(e.relative.y, -e.relative.x) * 0.03
		accept_event()
		return
	if not (e is InputEventMouseButton):
		return
	_mouse = e.position
	accept_event()
	if phase == "done":
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if held != null and e.pressed:
			yaw_target += 15.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -15.0
			game.sfx.play("tick_004", 1.4, -16.0)
		return
	if e.button_index == MOUSE_BUTTON_RIGHT:
		if e.pressed:
			_rdrag = true
			_rmoved = 0.0
		else:
			_rdrag = false
			if held != null and _rmoved < 4.0:
				_put_back(held)
		return
	if e.button_index != MOUSE_BUTTON_LEFT or not e.pressed:
		return
	if phase == "stitch":
		_stitch_click(e.position)
		return
	if held == null:
		var p = _part_at(e.position)
		if p != null:
			_lift(p)
	else:
		_drop(held)


func _lift(p: Dictionary) -> void:
	held = p
	yaw_target = rad_to_deg((p["node"] as Node3D).rotation.y)
	_tilt = Vector2.ZERO
	game.sfx.play("drop_002", 1.5, -10.0)


func _put_back(p: Dictionary) -> void:
	held = null
	var n: Node3D = p["node"]
	var tw := create_tween()
	var a := _aabb_local(n)
	tw.tween_property(n, "position", Vector3(p["home"].x, TOP - a.position.y, p["home"].z), 0.18)
	tw.parallel().tween_property(n, "rotation", Vector3(0, deg_to_rad(p["home_yaw"]), 0), 0.18)
	game.sfx.play("drop_002", 1.1, -12.0)


func _drop(p: Dictionary) -> void:
	var n: Node3D = p["node"]
	if p.has("palette"):
		# a scrap goes over whichever open tear it's nearest
		var tg = _nearest_tear(n)
		if tg == null:
			_put_back(p)
			return
		p["def"] = {"part": p["palette"], "name": p["def"]["name"], "at": tg["at"]}
		p["target"] = tg
	var tgt := _target(p)
	var d := Vector2(n.position.x - tgt.x, n.position.z - tgt.z).length()
	var want := float(p["def"]["at"][2])
	var yd := absf(wrapf(yaw_target - want, -180.0, 180.0))
	held = null
	if d <= SNAP_DIST and yd <= SNAP_YAW:
		# snaps onto its outline: how close you put it is the fit
		p["fit"] = clampf(1.0 - 0.6 * d / SNAP_DIST - 0.4 * yd / SNAP_YAW, 0.0, 1.0)
		var a := _aabb_local(n)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position", Vector3(tgt.x, _base_top() - a.position.y, tgt.z), 0.16)
		tw.parallel().tween_property(n, "rotation", Vector3(0, deg_to_rad(want), 0), 0.16)
		tw.tween_callback(func() -> void: _start_stitch(p))
		if p.has("palette"):
			_new_scrap(str(p["palette"]), p["home"])     # a fresh scrap of that colour takes its place
		game.sfx.play("switch_002", 1.0, -4.0)
		_pop(["CLICK", "SNUG", "GOOD", "PERFECT"][clampi(int(p["fit"] * 4.0), 0, 3)], to_ui(Vector3(tgt.x, _base_top(), tgt.z)), Pal.GREEN if p["fit"] > 0.6 else Pal.AMBER)
	else:
		# not on its outline: put down where it is
		var a2 := _aabb_local(n)
		var tw2 := create_tween()
		tw2.tween_property(n, "position:y", TOP - a2.position.y, 0.12)
		tw2.parallel().tween_property(n, "rotation", Vector3(0, deg_to_rad(yaw_target), 0), 0.12)
		game.sfx.play("drop_002", 0.9, -10.0)
		if d < 0.25:
			_pop("NOT QUITE: LINE IT UP" if yd <= SNAP_YAW else "TURN IT (WHEEL)", to_ui(n.position), Pal.MULT)


# ------------------------------------------------------------------ stitching

func _start_stitch(p: Dictionary) -> void:
	phase = "stitch"
	stitch_part = p
	rings.clear()
	var n: Node3D = p["node"]
	var a := _aabb_local(n)
	var y := _base_top() + a.size.y + 0.002
	var hx := a.size.x * 0.5 - 0.012
	var hz := a.size.z * 0.5 - 0.012
	var c := Vector3(n.position.x, y, n.position.z)
	var per := 2.0 * (hx + hz) * 2.0
	var count := clampi(int(per / 0.07), 6, 12)
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var rot := Basis(Vector3.UP, n.rotation.y)
	for k in count:
		var t := float(k) / count * 4.0
		var i := int(t)
		var f := t - i
		var pt: Vector3 = corners[i].lerp(corners[(i + 1) % 4], f)
		rings.append(c + rot * pt)
	ring_i = 0
	ring_t = 0.0


func _stitch_click(ui: Vector2) -> void:
	if ring_i >= rings.size():
		return
	var rp := to_ui(rings[ring_i])
	var dist := ui.distance_to(rp)
	if dist > 18.0:
		_pop("MISS", ui, Pal.MULT)
		game.deny()
		return
	var timing := 1.0 - absf(ring_t / RING_TIME - 1.0) * 1.6        # best when the circle closes on it
	var aim := 1.0 - dist / 18.0
	var s := clampf(0.55 * clampf(timing, 0.0, 1.0) + 0.45 * aim, 0.0, 1.0)
	_ring_done(s)


func _ring_done(s: float) -> void:
	stitch_part["stitch"].append(s)
	var a: Vector3 = rings[ring_i]
	var b: Vector3 = rings[(ring_i + 1) % rings.size()] if ring_i + 1 < rings.size() else rings[0]
	_sew(a, b, s)
	game.sfx.play("tick_004", 1.0 + ring_i * 0.06, -6.0 if s > 0.6 else -12.0)
	_pop(["ROUGH", "OK", "NEAT", "CLEAN"][clampi(int(s * 4.0), 0, 3)], to_ui(a), Pal.GREEN if s > 0.6 else Pal.DIM)
	ring_i += 1
	ring_t = 0.0
	if ring_i >= rings.size():
		_part_done()


## Real stitches on the piece: cream dashes from one ring to the next (wobblier when rough).
func _sew(a: Vector3, b: Vector3, s: float) -> void:
	var pn: Node3D = stitch_part["node"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.89, 0.78)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.016, 0.003, 0.004)
	var d := b - a
	var ang := atan2(-d.z, d.x)
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = m
		pn.add_child(mi)
		var jitter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (1.0 - s) * 0.006
		mi.global_position = a.lerp(b, (k + 0.5) / 3.0) + Vector3(0, 0.002, 0) + jitter
		mi.global_rotation = Vector3(0, ang, 0)


func _part_done() -> void:
	var p: Dictionary = stitch_part
	var st: Array = p["stitch"]
	var avg := 0.0
	for v in st:
		avg += float(v)
	avg /= maxf(1.0, st.size())
	p["done"] = true
	scores.append(clampf(0.5 * float(p["fit"]) + 0.5 * avg, 0.0, 1.0))
	if p.has("target"):
		var tg: Dictionary = p["target"]
		tg["done"] = true
		tg["colour"] = p["palette"]
		(tg["tear"] as Node3D).visible = false
		patched.append({"spot": tg["spot"], "colour": p["palette"]})
	stitch_part = null
	rings.clear()
	phase = "fit"
	game.sfx.play("confirmation_002", 1.0 + scores.size() * 0.08, -8.0)
	var left := 0
	for q in (targets if mend else parts):
		if not q["done"]:
			left += 1
	if left == 0:
		phase = "done"
		_done_t = 0.0


func _pop(text: String, at: Vector2, col: Color) -> void:
	_float.append([text, at, 0.0, col])


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	_t += delta
	if held != null:
		var n: Node3D = held["node"]
		var on := _on_plane(_mouse, _base_top() + LIFT)
		n.position = n.position.lerp(Vector3(on.x, on.y + 0.02 * sin(_t * 3.0), on.z), minf(1.0, delta * 14.0))
		var cur := n.rotation.y
		var want := deg_to_rad(yaw_target)
		var yaw := lerp_angle(cur, want, minf(1.0, delta * 12.0))
		if not _rdrag:
			_tilt = _tilt.lerp(Vector2.ZERO, minf(1.0, delta * 4.0))
		n.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _tilt.x) * Basis(Vector3.BACK, _tilt.y)
	if hand_r:
		var hp := _on_plane(_mouse, TOP + 0.035)
		if held != null:
			hp = (held["node"] as Node3D).position + Vector3(0.05, -0.02, 0.09)
		hand_r.position = hand_r.position.lerp(hp + Vector3(0.03, 0, 0.08), minf(1.0, delta * 16.0))
		hand_r.rotation_degrees = Vector3(0, -12, 0)
	if phase == "stitch" and ring_i < rings.size():
		ring_t += delta
		if ring_t > RING_TIME * 1.6:
			_pop("LATE", to_ui(rings[ring_i]), Pal.MULT)
			_ring_done(0.25)
	if phase == "done" and _done_t >= 0.0:
		_done_t += delta
		if _done_t > 0.7:
			_done_t = -1.0
			finished.emit(scores)
	for f in _float:
		f[2] += delta
	_float = _float.filter(func(f) -> bool: return f[2] < 0.9)
	queue_redraw()


func _draw() -> void:
	# outlines: dashed amber where the held part goes (or every waiting part's place, faint)
	if mend:
		# every open tear gets an outline the size of a scrap: bright while you hold one
		if phase != "stitch":
			var sample: Dictionary = held if held != null else (parts[0] if not parts.is_empty() else {})
			for tg in targets:
				if not tg["done"] and not sample.is_empty():
					_outline(sample, Color(Pal.AMBER, 0.95 if held != null else 0.4), held != null, tg["at"])
	else:
		for p in parts:
			if p["done"] or (phase == "stitch"):
				continue
			var strong: bool = held == p
			_outline(p, Color(Pal.AMBER, 0.95 if strong else 0.3), strong)
	# stitch rings
	if phase == "stitch":
		for k in rings.size():
			var rp := to_ui(rings[k])
			if k < ring_i:
				continue
			if k == ring_i:
				var close := clampf(ring_t / RING_TIME, 0.0, 1.6)
				var r := lerpf(26.0, 7.0, minf(close, 1.0))
				draw_arc(rp, r, 0, TAU, 24, Color(Pal.AMBER, 0.9), 1.5)
				draw_arc(rp, 7.0, 0, TAU, 18, Pal.TEXT, 2.0)
				draw_circle(rp, 2.0, Pal.AMBER)
			else:
				draw_arc(rp, 5.0, 0, TAU, 12, Color(Pal.TEXT, 0.35), 1.0)
	# the job ticket and checklist (top left), like ReStroy
	var rows: Array = []        # [text, done, now]
	if mend:
		for tg in targets:
			var now2: bool = stitch_part != null and stitch_part.get("target") == tg
			rows.append(["%s Patch the %s%s" % ["[x]" if tg["done"] else ("[>]" if now2 else "[ ]"), tg["name"], ("  (" + str(tg["colour"]) + ")") if tg["done"] else ""], tg["done"], now2])
	else:
		for p in parts:
			var now: bool = (stitch_part == p) or (held == p)
			var verb := "Stitch" if stitch_part == p else "Fit and stitch"
			rows.append(["%s %s the %s" % ["[x]" if p["done"] else ("[>]" if now else "[ ]"), verb, str(p["def"].get("name", ""))], p["done"], now])
	var box := Rect2(Vector2(10, 10), Vector2(200, 30 + rows.size() * 13))
	draw_rect(box, Color(0.08, 0.06, 0.045, 0.9))
	draw_rect(box, Pal.BRASS, false, 1.0)
	Pal.text(self, box.position + Vector2(7, 5), "SEWING TABLE  /  " + str(recipe.get("name", "")).to_upper(), 8, Pal.AMBER, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 10)
	for i in rows.size():
		var y := box.position.y + 20 + i * 13
		Pal.text(self, Vector2(box.position.x + 7, y), str(rows[i][0]), 8, Pal.GREEN if rows[i][1] else (Pal.TEXT if rows[i][2] else Pal.DIM), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 12)
	# what to do now
	var hint := "Pick a scrap colour, then lay it over a tear." if mend else "Click a piece to pick it up."
	if held != null:
		hint = "Put it on its amber outline and click.  Wheel: turn.  Right-drag: tip it over.  Right-click: put it back."
	elif phase == "stitch":
		hint = "Stitch: click each ring as the circle closes on it."
	elif phase == "done":
		hint = "Done."
	var hr := Rect2(Vector2(10, size.y - 26), Vector2(size.x - 20, 18))
	draw_rect(hr, Color(0.05, 0.04, 0.03, 0.85))
	Pal.text(self, hr.position + Vector2(8, 4), hint + "   Esc: stop", 8, Pal.TEXT, HORIZONTAL_ALIGNMENT_LEFT, hr.size.x - 12)
	for f in _float:
		var a := 1.0 - float(f[2]) / 0.9
		Pal.text(self, (f[1] as Vector2) + Vector2(-40, -14 - float(f[2]) * 18.0), str(f[0]), 9, Color(f[3], a), HORIZONTAL_ALIGNMENT_CENTER, 80)


## The dashed footprint of where a part goes, projected from the 3D target.
func _outline(p: Dictionary, col: Color, strong: bool, at_override: Array = []) -> void:
	var n: Node3D = p["node"]
	var a := _aabb_local(n)
	var at: Array = at_override if not at_override.is_empty() else p["def"]["at"]
	var tgt := Vector3(BASE_AT.x + float(at[0]), 0, BASE_AT.z + float(at[1]))
	var y := _base_top() + 0.003
	var hx := a.size.x * 0.5
	var hz := a.size.z * 0.5
	var rot := Basis(Vector3.UP, deg_to_rad(float(at[2])))
	var c := Vector3(tgt.x, y, tgt.z)
	var pts: Array = []
	for v in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		pts.append(to_ui(c + rot * v))
	var dash := 5.0
	var off := fmod(_t * 14.0, dash * 2.0) if strong else 0.0
	for i in 4:
		var s: Vector2 = pts[i]
		var e: Vector2 = pts[(i + 1) % 4]
		var L := s.distance_to(e)
		var dir := (e - s) / maxf(L, 0.001)
		var d := -off
		while d < L:
			var d0 := maxf(d, 0.0)
			var d1 := minf(d + dash, L)
			if d1 > d0:
				draw_line(s + dir * d0, s + dir * d1, col, 2.0 if strong else 1.0)
			d += dash * 2.0
