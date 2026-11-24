extends Node
## The fight's main view (docs/CONNECTED_LOOP.md section 9, C1; user 2026-11-24): a raised cutaway of the building,
## roofs off and walls cut low (level.gd LAYER_CUT), and an HQ DRONE mode high overhead. Only what your people
## and hacked cameras have seen shows: unseen rooms stay dark (fog), guards appear only while someone sees them,
## then a fading "?" where they were last seen. Your own people always show (their radio trackers).
## Drag pans, the wheel zooms, a double click fits the building again.

const Level := preload("res://v2/combat/level.gd")
const Pal := preload("res://v2/ui/pal.gd")

var fight: Node
var vp: SubViewport
var cam: Camera3D
var mode := "overview"           # overview, drone
var seen_rooms := {}             # room id -> true
var focus := Vector3.ZERO
var dist := 30.0
var _fit_dist := 30.0
var _fit_focus := Vector3.ZERO
var _fog := {}                   # room id -> MeshInstance3D
var _enemy_vis := {}             # enemy -> Array[VisualInstance3D]
var _t := 0.0

const PITCH := -0.95             # about 54 degrees down
const YAW := PI * 0.5            # looking along -X: the building's long axis runs across the screen
const SEEN_FOR := 0.6            # a guard counts as seen for this long after the last sighting


func setup(p_fight: Node) -> void:
	fight = p_fight
	vp = SubViewport.new()
	vp.size = Vector2i(400, 240)
	vp.world_3d = fight.view.vp.find_world_3d()
	vp.audio_listener_enable_3d = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	cam = Camera3D.new()
	cam.near = 0.1
	cam.far = 120.0
	cam.fov = 46.0
	cam.cull_mask = 1 | Level.LAYER_CUT | Level.LAYER_SEEN
	vp.add_child(cam)
	cam.current = true
	cam.environment = _env()
	var b: Rect2 = fight.level._bounds()
	_fit_focus = Vector3(b.get_center().x, 0.0, b.get_center().y)
	_fit_dist = clampf(maxf(b.size.x, b.size.y) * 0.86, 10.0, 60.0)
	reset()
	_make_fog()
	for e in fight.enemies:
		_cache_enemy(e)


func _cache_enemy(e) -> void:
	var vis: Array = []
	for n in (e as Node).find_children("*", "VisualInstance3D", true, false):
		if not (n is Light3D):
			vis.append(n)
	_enemy_vis[e] = vis


func reset() -> void:
	focus = _fit_focus
	dist = _fit_dist


func texture() -> Texture2D:
	return vp.get_texture()


func fit(px: Vector2i) -> void:
	if px.x > 8 and px.y > 8 and vp.size != px:
		vp.size = px


## A dark lid over every room until someone has seen inside (overview only).
func _make_fog() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.025, 0.03, 0.93)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for r in fight.level.rooms:
		var rc: Rect2 = r["rect"]
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rc.size.x - 0.06, Level.LOW_H + 0.06, rc.size.y - 0.06)
		m.mesh = bm
		m.material_override = mat
		m.position = Vector3(rc.get_center().x, (Level.LOW_H + 0.06) * 0.5, rc.get_center().y)
		m.layers = Level.LAYER_CUT
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fight.level.add_child(m)
		_fog[r["id"]] = m


func pan(delta_px: Vector2, img_size: Vector2) -> void:
	var k := dist * 0.0028 * (480.0 / maxf(img_size.x, 1.0))
	var right := cam.global_basis.x
	var up := Vector3(-cam.global_basis.z.x, 0, -cam.global_basis.z.z).normalized()
	focus -= right * delta_px.x * k
	focus += up * delta_px.y * k * 1.4
	var b: Rect2 = fight.level._bounds().grow(4.0)
	focus.x = clampf(focus.x, b.position.x, b.end.x)
	focus.z = clampf(focus.z, b.position.y, b.end.y)


func zoom(steps: float) -> void:
	dist = clampf(dist * pow(0.88, steps), 6.0, 70.0)


## World point -> overview viewport pixels (behind = (-1, -1)).
func to_px(p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return Vector2(-1, -1)
	return cam.unproject_position(p)


func tick(delta: float) -> void:
	_t += delta
	_seen()
	for id in _fog:
		var m: MeshInstance3D = _fog[id]
		m.visible = not seen_rooms.get(id, false)
	var now: float = fight.sq._t
	for e in fight.enemies:
		if not _enemy_vis.has(e):           # reinforcements arrive later
			_cache_enemy(e)
		var shown: bool = e.has_meta("seen_t") and (now - float(e.get_meta("seen_t")) < SEEN_FOR or e.state != "ok")
		var layers := Level.LAYER_ENEMY | (Level.LAYER_SEEN if shown else 0)
		for v in _enemy_vis[e]:
			(v as VisualInstance3D).layers = layers
	var basis: Basis
	var d := dist
	if mode == "drone":
		var yaw := YAW + _t * 0.05
		basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -1.25)
		d = dist * 1.25
		cam.fov = 38.0
	else:
		basis = Basis(Vector3.UP, YAW) * Basis(Vector3.RIGHT, PITCH)
		cam.fov = 46.0
	cam.global_transform = Transform3D(basis, focus + basis.z * d)      # the camera looks along -z at the focus


## Rooms someone has seen: the room each fighter is in, rooms they can see into through an open doorway close by,
## and rooms a hacked camera looks into.
func _seen() -> void:
	var lv = fight.level
	for a in fight.squad:
		if a.state == "dead":
			continue
		var p: Vector3 = a.global_position
		var r: String = lv.room_near(p)
		if r != "":
			seen_rooms[r] = true
		for d in lv.doors:
			if d["state"] == "closed":
				continue
			var dw: Vector3 = lv.door_world(d)
			if Vector2(dw.x, dw.z).distance_to(Vector2(p.x, p.z)) < 2.2:
				seen_rooms[d["a"]] = true
				seen_rooms[d["b"]] = true
	for f in fight.feeds:
		if f["kind"] == "cctv":
			var l: Array = f["def"]["look"]
			var r2: String = lv.room_at(Vector3(l[0], 0, l[2]))
			if r2 != "":
				seen_rooms[r2] = true


## Marks drawn over the overview image: "?" where a guard was last seen, the drone's reticle.
func draw_marks(ci: CanvasItem, img: Rect2) -> void:
	if img.size.x <= 0.0 or img.size.y <= 0.0:
		return
	var now: float = fight.sq._t
	var sc := img.size / Vector2(vp.size)
	for e in fight.enemies:
		if not e.has_meta("seen_t") or e.state != "ok":
			continue
		var age := now - float(e.get_meta("seen_t"))
		if age < SEEN_FOR or age > 25.0:
			continue
		var px := to_px(e.get_meta("seen_pos") + Vector3(0, 1.0, 0))
		if px.x < 0:
			continue
		var p := img.position + px * sc
		if not img.has_point(p):
			continue
		var a := clampf(1.0 - age / 25.0, 0.25, 1.0)
		ci.draw_circle(p, 6.0, Color(0.9, 0.25, 0.2, 0.35 * a))
		Pal.text(ci, p - Vector2(4, 6), "?", 10, Color(1.0, 0.45, 0.35, a))
	if mode == "drone":
		var c := img.get_center()
		var col := Color(0.75, 0.95, 0.8, 0.7)
		ci.draw_arc(c, 18.0, 0.0, TAU, 32, col, 1.0)
		for s in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			ci.draw_line(c + s * 24.0, c + s * 34.0, col, 1.0)
		Pal.text(ci, img.position + Vector2(6, img.size.y - 14), "HQ DRONE   ALT %dm   ORBIT" % int(dist * 1.25), 8, col)


## The overview's own light: brighter and clearer than the helmet cams (it's a planning view), no fog.
func _env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.022, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.58, 0.52)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.5
	e.glow_enabled = true
	e.glow_intensity = 0.4
	return e


## Your people on the overview: a coloured ring at their feet and their number and name (radio trackers).
func draw_squad(ci: CanvasItem, img: Rect2, cols: Array, main_actor) -> void:
	if img.size.x <= 0.0 or img.size.y <= 0.0:
		return
	var sc := img.size / Vector2(vp.size)
	for i in fight.squad.size():
		var a = fight.squad[i]
		var px := to_px(a.global_position + Vector3(0, 2.1, 0))
		if px.x < 0:
			continue
		var p := img.position + px * sc
		if not img.has_point(p):
			continue
		var col: Color = cols[i % cols.size()]
		if a.state == "dead":
			col = Color(0.5, 0.5, 0.5)
		var name := str(a.fighter_name).split(" ")[0]
		var label := "%d %s" % [i + 1, name]
		var w := label.length() * 5.2 + 8
		var r := Rect2(p - Vector2(w * 0.5, 14), Vector2(w, 11))
		ci.draw_rect(r, Color(0, 0, 0, 0.6))
		ci.draw_rect(r, col, false, 2.0 if a == main_actor else 1.0)
		Pal.text(ci, r.position + Vector2(4, 0), label, 8, col)
		ci.draw_line(Vector2(p.x, r.end.y), Vector2(p.x, p.y + 4), Color(col, 0.7), 1.0)
		if a.state == "down":
			Pal.text(ci, r.position + Vector2(0, -11), "DOWN", 8, Color(1.0, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER, w)
