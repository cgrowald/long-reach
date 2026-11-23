extends Control
## The first fight (docs/COMBAT_SLICE.md sections 1, 5, 8): the Dobrev Freight depot at night.
## Your four run it themselves by doctrine; you watch the feeds from the van and shout.
##   Right mouse (hold): the shout wheel. Pick a shout, then click the door / room / enemy on the main feed.
##   1-4: who you're talking to (again to go back to everyone). Tab or a click on a tile: change the main feed.
##   Space: pause (allowed for now). G: carry on (doctrine). Esc: cancel a shout; twice to abort the op.

const Pal := preload("res://v2/ui/pal.gd")
const PixelView := preload("res://v2/ui/pixel_view.gd")
const Content := preload("res://v2/sim/content.gd")
const Level := preload("res://v2/combat/level.gd")
const Actor := preload("res://v2/combat/actor.gd")
const SquadAI := preload("res://v2/combat/squad_ai.gd")
const EnemyAI := preload("res://v2/combat/enemy_ai.gd")
const Audio := preload("res://v2/combat/combat_audio.gd")
const FEED := preload("res://v2/combat/feedcam.gdshader")
const Loadout := preload("res://v2/sim/loadout.gd")

const SHOUTS := [
	{"id": "stack", "label": "STACK", "needs": "door", "say": "Stack up on that door."},
	{"id": "breach", "label": "BREACH", "needs": "door", "say": "Breach it. Kick it in."},
	{"id": "bang", "label": "BANG & CLEAR", "needs": "door", "say": "Bang it and clear."},
	{"id": "push", "label": "PUSH", "needs": "room", "say": "Push in there."},
	{"id": "hold", "label": "HOLD", "needs": "", "say": "Hold! Hold there."},
	{"id": "fallback", "label": "FALL BACK", "needs": "", "say": "Fall back! Fall back!"},
	{"id": "cover", "label": "COVER", "needs": "point", "say": "Cover that."},
	{"id": "focus", "label": "FOCUS", "needs": "enemy", "say": "Him. Put him down."},
	{"id": "medic", "label": "MEDIC", "needs": "fighter", "say": "Medic! Get to them!"},
	{"id": "go", "label": "CARRY ON", "needs": "", "say": "Carry on. Your call."},
]
const NAME_COL := [Color(0.95, 0.8, 0.45), Color(0.6, 0.85, 1.0), Color(1.0, 0.55, 0.55), Color(0.7, 1.0, 0.6)]
const TILE := Vector2(86, 48)

var game: Node
var data: Dictionary
var view
var world: Node3D
var level: Node3D
var squad: Array = []
var enemies: Array = []
var sq: RefCounted
var en: RefCounted
var feeds: Array = []            # {kind, actor, label, vp, cam, post, tex}
var main_cam: Camera3D
var main_post: ShaderMaterial
var main_i := 3
var hud: Control
var barks: Array = []
var shout_log: Array = []
var events: Array = []
var recipients: Array = []
var paused := false
var t_op := 0.0
var phase := "op"                 # op, report
var outcome := ""
var wheel_open := false
var wheel_c := Vector2.ZERO
var wheel_hover := -1
var pending := -1                 # shout waiting for its target click
var hover_target: Dictionary = {}
var _esc_t := -10.0
var _restart_r := Rect2()
var _title_r := Rect2()
var _env: Environment
var _look_drag := false
var board: Control
const OpsBoard := preload("res://v2/combat/ops_board.gd")


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	data = Content.get_file("combat/depot")
	view = PixelView.new()
	add_child(view)
	world = Node3D.new()
	view.vp.add_child(world)
	view.vp.audio_listener_enable_3d = true
	_environment()
	level = Level.new()
	world.add_child(level)
	level.build(data)
	_spawn()
	en = EnemyAI.new()
	en.setup(enemies, squad, level)
	sq = SquadAI.new()
	var sp: Array = data["start"]["pos"]
	sq.setup(squad, enemies, level, en, Vector3(sp[0], 0, sp[1]))
	sq.log_line.connect(func(t: String) -> void:
		_event(t)
		if t.begins_with("YOU overruled"):
			shout_log.append({"t": t_op, "text": t}))
	sq.objective_done.connect(func() -> void: _event("OBJECTIVE COMPLETE: get out"))
	sq.exfil_done.connect(func() -> void: _end("success"))
	_cameras()
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.ui.add_child(hud)
	hud.draw.connect(_draw_hud)
	board = OpsBoard.new()
	view.ui.add_child(board)
	board.setup(self, _have_blueprint())
	_event("In position. %s." % str(data.get("objective", {}).get("text", "")))


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
	we.environment = e
	_env = e
	world.add_child(we)


func _spawn() -> void:
	var sp: Array = data["start"]["pos"]
	var i := 0
	for d in _squad_defs():
		var a: Node3D = Actor.new()
		world.add_child(a)
		var def: Dictionary = (d as Dictionary).duplicate()
		if not def.has("id"):
			def["id"] = "f%d" % i
		a.setup_actor(def, "us", level)
		a.position = Vector3(float(sp[0]) + (i % 2) * 0.8 - 0.4, 0, float(sp[1]) + 0.3 - int(i / 2) * 0.9)
		a.face_yaw = 0.0
		_wire(a)
		squad.append(a)
		i += 1
	for d in data.get("enemies", []):
		var a: Node3D = Actor.new()
		world.add_child(a)
		a.setup_actor(d, "them", level)
		a.set_meta("def", d)
		var p: Array = d["pos"]
		a.position = Vector3(p[0], 0, p[1])
		a.face_yaw = float(d.get("yaw", 0.0))
		a.rotation.y = a.face_yaw
		_wire(a)
		enemies.append(a)


func _wire(a: Node3D) -> void:
	a.said.connect(_on_said)
	a.hit_taken.connect(func(who, info: Dictionary) -> void:
		if who.team == "us":
			who.bark("hit", {}, not info["blocked"])
			if who == _main_actor():
				main_post.set_shader_parameter("hit_flash", 1.0)
		else:
			en.shaken(who, 0.35))
	a.went_down.connect(func(who) -> void:
		if who.team == "us":
			var other = _someone_else(who)
			if other:
				other.bark("down", {"name": _first(who)}, true)
			_event("%s is down" % _first(who))
		else:
			en.ally_down(who.global_position)
			var f = _nearest_fighter(who.global_position)
			if f:
				f.bark("enemy_down", {}, true)
			_event("%s down" % who.fighter_name))
	a.died.connect(func(who) -> void:
		if who.team == "us":
			_event("%s is dead" % _first(who))
		else:
			_event("%s dead" % who.fighter_name))
	a.fired.connect(func(who, _t) -> void:
		en.noise(who.global_position, 13.0))


# ------------------------------------------------------------------ cameras and feeds

func _post_for(cam: Camera3D, layer: int) -> ShaderMaterial:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = FEED
	q.material_override = m
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.layers = 1 << (layer - 1)
	q.position = Vector3(0, 0, -0.5)
	cam.add_child(q)
	cam.cull_mask = 1 | (1 << (layer - 1))
	return m


func _cameras() -> void:
	main_cam = Camera3D.new()
	main_cam.near = 0.05
	world.add_child(main_cam)
	main_cam.current = true
	main_post = _post_for(main_cam, 2)
	var layer := 3
	for a in squad:
		feeds.append({"kind": "helmet", "actor": a, "label": "CAM %02d  %s" % [feeds.size() + 1, a.fighter_name]})
	for c in data.get("cctv", []):
		feeds.append({"kind": "cctv", "def": c, "label": "%s  %s" % [c["id"], c["label"]]})
	for f in feeds:
		var vp := SubViewport.new()
		vp.size = Vector2i(TILE)
		vp.world_3d = view.vp.find_world_3d()
		vp.audio_listener_enable_3d = false
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vp.msaa_3d = Viewport.MSAA_DISABLED
		add_child(vp)
		var cam := Camera3D.new()
		cam.near = 0.05
		vp.add_child(cam)
		cam.current = true
		f["vp"] = vp
		f["cam"] = cam
		f["post"] = _post_for(cam, layer)
		f["dead_t"] = 0.0
		layer += 1


func _feed_xform(f: Dictionary) -> Transform3D:
	if f["kind"] == "helmet":
		var a = f["actor"]
		var m: Node3D = a.cam_mount
		var tilt := -0.2 if a.state != "down" and a.state != "dead" else 0.0
		return Transform3D(m.global_basis * Basis(Vector3.RIGHT, tilt), m.global_position)
	var c: Dictionary = f["def"]
	var p: Array = c["pos"]
	var l: Array = c["look"]
	return Transform3D.IDENTITY.translated(Vector3(p[0], p[1], p[2])).looking_at(Vector3(l[0], l[1], l[2]), Vector3.UP)


func _apply_feed_look(m: ShaderMaterial, f: Dictionary) -> void:
	var cctv: bool = f["kind"] == "cctv"
	m.set_shader_parameter("mono", 1.0 if cctv else 0.0)
	m.set_shader_parameter("barrel", 0.12 if cctv else 0.28)
	m.set_shader_parameter("round_vignette", 0.35 if cctv else 1.0)
	m.set_shader_parameter("time_s", t_op)
	m.set_shader_parameter("lost", clampf((float(f["dead_t"]) - 2.0) / 1.0, 0.0, 1.0))


func _update_cameras(delta: float) -> void:
	for f in feeds:
		if f["kind"] == "helmet" and f["actor"].state == "dead":
			f["dead_t"] = float(f["dead_t"]) + delta
		var xf := _feed_xform(f)
		(f["cam"] as Camera3D).global_transform = xf
		(f["cam"] as Camera3D).fov = 64.0 if f["kind"] == "cctv" else 86.0
		_apply_feed_look(f["post"], f)
	var mf: Dictionary = feeds[main_i]
	main_cam.global_transform = _feed_xform(mf)
	main_cam.fov = 64.0 if mf["kind"] == "cctv" else 86.0
	_apply_feed_look(main_post, mf)
	var hfv = main_post.get_shader_parameter("hit_flash")
	var hf: float = hfv if hfv != null else 0.0
	main_post.set_shader_parameter("hit_flash", maxf(0.0, hf - delta * 3.0))


func _main_actor():
	var f: Dictionary = feeds[main_i]
	return f["actor"] if f["kind"] == "helmet" else null


# ------------------------------------------------------------------ the loop

func _process(delta: float) -> void:
	for a in squad + enemies:
		a.set_process(not paused)
	if not paused and phase == "op":
		t_op += delta
		en.tick(delta)
		sq.tick(delta)
		_separate()
		if squad.all(func(a) -> bool: return a.state != "ok"):
			_end("failed")
	for b in barks:
		b["t"] = float(b["t"]) + (0.0 if paused else delta)
	barks = barks.filter(func(b: Dictionary) -> bool: return float(b["t"]) < 6.0)
	_update_cameras(delta)
	if board:
		board.size = Vector2(112, hud.size.y - TILE.y - 62)
		board.position = Vector2(hud.size.x - board.size.x - 6, 50)
	if not paused and phase == "op":
		_cctv_spot()
	if pending >= 0:
		hover_target = _pick_target(SHOUTS[pending]["needs"])
	hud.queue_redraw()


## Nobody stands inside anybody: people closer than a shoulder-width push apart.
## Moving as one ("hive mind"): someone walking has right of way, and a teammate standing in the path
## steps aside; two of ours both on the move just flow past each other; standing people keep a
## shoulder's width apart. Enemies and ours always push apart.
func _separate() -> void:
	var people: Array = (squad + enemies).filter(func(a) -> bool: return a.state == "ok" or a.state == "surrendered")
	for i in people.size():
		for j in range(i + 1, people.size()):
			var a = people[i]
			var b = people[j]
			var d: Vector3 = b.global_position - a.global_position
			d.y = 0.0
			var dist := d.length()
			if dist >= 0.6:
				continue
			var dirn := d.normalized() if dist > 0.001 else Vector3(1, 0, 0)
			if a.team == b.team:
				var am: bool = a.moving()
				var bm: bool = b.moving()
				if am and bm:
					continue
				if am != bm:
					# the one standing still makes room, sideways to the walker's line
					var walker = a if am else b
					var stander = b if am else a
					var wdir: Vector3 = (walker.path[0] as Vector3) - walker.global_position
					wdir.y = 0.0
					var side := Vector3(-wdir.z, 0, wdir.x).normalized()
					if side.dot(stander.global_position - walker.global_position) < 0.0:
						side = -side
					stander.nudge(side * 0.04)
					continue
			var push := dirn * (0.55 - dist) * 0.5
			a.nudge(-push)
			b.nudge(push)


func _end(how: String) -> void:
	if phase != "op":
		return
	phase = "report"
	outcome = how
	_event("OP OVER: %s" % how.to_upper())


# ------------------------------------------------------------------ shouting

func _on_said(who, text: String) -> void:
	var col := Color(0.6, 0.6, 0.6)
	var nm := "?"
	if who.team == "us":
		var i: int = squad.find(who)
		col = NAME_COL[i % NAME_COL.size()]
		nm = _first(who).to_upper()
	else:
		nm = "BUREAU" if who.kind == "bureau" else "GUARD"
	barks.append({"name": nm, "text": text, "t": 0.0, "col": col})
	if barks.size() > 6:
		barks.pop_front()
	if who.team == "us":
		Audio.play_at(world, "squelch", main_cam.global_position, -14.0, 1.4)


func _shout(i: int, target = null) -> void:
	var s: Dictionary = SHOUTS[i]
	issue(s["id"], s["label"], s["say"], target)


## Give an order (from the shout wheel or the ops board): log it, say it on the radio, pass it on.
func issue(id: String, label: String, say_line: String, target = null) -> void:
	var who := recipients.duplicate()
	var to_txt := "ALL" if who.is_empty() else ", ".join(PackedStringArray(who.map(func(a) -> String: return _first(a).to_upper())))
	var what := ""
	if target is Dictionary:
		what = str(target.get("name", "")).to_lower()
	elif target is String:
		what = str(level.room(target).get("name", target)).to_lower()
	elif target is Vector3:
		what = "that spot"
	elif target != null:
		what = _first(target) if target.team == "us" else str(target.fighter_name)
	var line := "%s %s" % [label, what]
	shout_log.append({"t": t_op, "text": "YOU > %s: %s" % [to_txt, line.strip_edges()]})
	barks.append({"name": "YOU", "text": say_line, "t": 0.0, "col": Color(1, 1, 1)})
	Audio.play_at(world, "squelch", main_cam.global_position, -10.0)
	sq.order(id, target, who)


## What's under the mouse on the main feed, for the shout that's waiting.
func _pick_target(needs: String) -> Dictionary:
	var mp := view.ui.get_local_mouse_position() as Vector2
	var o := main_cam.project_ray_origin(mp)
	var dir := main_cam.project_ray_normal(mp)
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * 40.0)
	q.collision_mask = 1
	var hit := level.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3
	if not hit.is_empty():
		p = hit["position"]
	elif absf(dir.y) > 0.01:
		p = o + dir * maxf(0.0, -o.y / dir.y)
	else:
		return {}
	match needs:
		"door":
			var best := {}
			var bd := 2.0
			for d in level.doors:
				var dd: float = Vector2(p.x, p.z).distance_to(d["pos"])
				if dd < bd:
					bd = dd
					best = d
			return {"door": best} if not best.is_empty() else {}
		"enemy", "fighter":
			var pool: Array = enemies if needs == "enemy" else squad
			var best = null
			var bd := 1.6
			for a in pool:
				if a.state in ["dead", "cuffed", "fled"] and needs == "enemy":
					continue
				var dd: float = Vector2(p.x, p.z).distance_to(a.pos2())
				if dd < bd:
					bd = dd
					best = a
			return {"actor": best} if best != null else {}
		"room":
			var r: String = level.room_at(p - dir * 0.2)
			return {"room": r} if r != "" else {}
		"point":
			return {"point": p}
	return {}


func _input(e: InputEvent) -> void:
	if phase == "report":
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var mp := view.ui.get_local_mouse_position() as Vector2
			if _restart_r.has_point(mp):
				get_tree().reload_current_scene()
			elif _title_r.has_point(mp):
				_leave()
		elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_leave()
		return
	if e is InputEventMouseButton:
		if board and Rect2(board.position, board.size).has_point(view.ui.get_local_mouse_position()) and not wheel_open:
			return          # the ops board handles its own clicks
		var mp := view.ui.get_local_mouse_position() as Vector2
		if e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed:
				pending = -1
				wheel_open = true
				wheel_c = mp
				wheel_hover = -1
			elif wheel_open:
				wheel_open = false
				if wheel_hover >= 0:
					var s: Dictionary = SHOUTS[wheel_hover]
					if s["needs"] == "":
						_shout(wheel_hover)
					else:
						pending = wheel_hover
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			# a tile?
			for i in feeds.size():
				if _tile_rect(i).has_point(mp):
					main_i = i
					if game:
						game.sfx.play("switch_002", 1.0 + i * 0.05, -10.0)
					get_viewport().set_input_as_handled()
					return
			if pending >= 0:
				var t := _pick_target(SHOUTS[pending]["needs"])
				if not t.is_empty():
					var target = t.values()[0]
					_shout(pending, target)
					pending = -1
				get_viewport().set_input_as_handled()
			else:
				# no shout waiting: press on the feed, drag, let go = ask the wearer to look there
				_look_drag = true
				get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and _look_drag:
			_look_drag = false
			var wearer = _main_actor()
			if wearer != null and wearer.alive():
				var lt := _pick_target("point")
				if not lt.is_empty():
					wearer.order_look(lt["point"])
					shout_log.append({"t": t_op, "text": "YOU > %s: LOOK there" % _first(wearer).to_upper()})
	elif e is InputEventMouseMotion and wheel_open:
		var v: Vector2 = view.ui.get_local_mouse_position() - wheel_c
		if v.length() < 10.0:
			wheel_hover = -1
		else:
			var a := fposmod(atan2(v.y, v.x) + PI * 0.5 + PI / SHOUTS.size(), TAU)
			wheel_hover = int(a / (TAU / SHOUTS.size())) % SHOUTS.size()
	elif e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k >= KEY_1 and k <= KEY_4:
			var a = squad[k - KEY_1]
			if recipients == [a]:
				recipients.clear()
			else:
				recipients = [a]
		elif k == KEY_0 or k == KEY_QUOTELEFT:
			recipients.clear()
		elif k == KEY_TAB:
			main_i = (main_i + 1) % feeds.size()
		elif k == KEY_SPACE or k == KEY_P:
			paused = not paused
		elif k == KEY_B:
			if not sq.objection.is_empty():
				var by = sq.objection["by"]
				shout_log.append({"t": t_op, "text": "YOU > OK, %s's way: %s" % [_first(by).to_upper(), sq.objection["suggest_label"]]})
				sq.accept_suggestion()
		elif k == KEY_G:
			_shout(9)
		elif k == KEY_H:
			_shout(4)
		elif k == KEY_ESCAPE:
			if pending >= 0 or wheel_open:
				pending = -1
				wheel_open = false
			elif t_op - _esc_t < 2.0 or paused:
				_leave()
			else:
				_esc_t = t_op
				_event("Esc again to abort the op")
		else:
			return
		get_viewport().set_input_as_handled()


func _leave() -> void:
	if from_garage:
		_return_home()
		return
	if game:
		game.goto("res://v2/title.tscn")
	else:
		get_tree().quit()


# ------------------------------------------------------------------ helpers

func _event(t: String) -> void:
	events.append({"t": t_op, "text": t})


func _first(a) -> String:
	return str(a.fighter_name).split(" ")[0].capitalize()


func _someone_else(who):
	for a in squad:
		if a != who and a.alive():
			return a
	return null


func _nearest_fighter(p: Vector3):
	var best = null
	var bd := 1e9
	for a in squad:
		if a.alive():
			var d: float = a.global_position.distance_to(p)
			if d < bd:
				bd = d
				best = a
	return best


func _clock(t: float) -> String:
	var s := int(t) + 23 * 3600 + 41 * 60
	return "%02d:%02d:%02d" % [(s / 3600) % 24, (s / 60) % 60, s % 60]


func _tile_rect(i: int) -> Rect2:
	var w := hud.size.x if hud else 533.0
	var h := hud.size.y if hud else 300.0
	var total := feeds.size() * (TILE.x + 3) - 3
	var x0 := (w - total) * 0.5
	return Rect2(Vector2(x0 + i * (TILE.x + 3), h - TILE.y - 4), TILE)


# ------------------------------------------------------------------ the overlay

func _draw_hud() -> void:
	var w := hud.size.x
	var h := hud.size.y
	var col := Color(0.85, 0.95, 0.9)
	var mf: Dictionary = feeds[main_i]
	Pal.text(hud, Vector2(10, 8), mf["label"], 9, Color(0.6, 1.0, 0.6) if mf["kind"] == "cctv" else col)
	if mf["kind"] == "helmet":
		var a = mf["actor"]
		Pal.text(hud, Vector2(10, 19), "%s  %s" % [str(a.role).to_upper(), _status(a)], 8, Color(col, 0.6))
	if fmod(t_op, 1.0) < 0.6:
		hud.draw_circle(Vector2(w - 98, 13), 2.5, Color(0.9, 0.15, 0.1))
	Pal.text(hud, Vector2(w - 92, 8), "REC  " + _clock(t_op), 9, col)
	Pal.text(hud, Vector2(w - 160, 19), "VAN, 40 m out. You're on the radio.", 8, Color(col, 0.45))
	Pal.text(hud, Vector2(0, 8), str(data.get("objective", {}).get("text", "")).to_upper() + ("  [DONE]" if sq.have_objective else ""), 8, Color(1, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, w)
	var task_txt := _task_text()
	Pal.text(hud, Vector2(0, 19), task_txt, 8, Color(col, 0.6), HORIZONTAL_ALIGNMENT_CENTER, w)
	if paused:
		Pal.text(hud, Vector2(0, h * 0.3), "PAUSED  (Space)", 12, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, w)
	# feed tiles
	for i in feeds.size():
		var f: Dictionary = feeds[i]
		var r := _tile_rect(i)
		hud.draw_texture_rect((f["vp"] as SubViewport).get_texture(), r, false)
		var bc := Color(0.3, 0.35, 0.33)
		if i == main_i:
			bc = Color(0.9, 0.9, 0.9)
		var sub := ""
		if f["kind"] == "helmet":
			var a = f["actor"]
			if recipients.has(a):
				bc = Color(1, 0.8, 0.3)
			sub = _status(a)
			if a.state == "down":
				bc = Color(1, 0.3, 0.2) if fmod(t_op, 0.6) < 0.3 else bc
			Pal.text(hud, r.position + Vector2(2, 1), "%d %s" % [i + 1, _first(a).to_upper()], 8, NAME_COL[i % 4])
			# health, mag, meds
			hud.draw_rect(Rect2(r.position + Vector2(2, r.size.y - 5), Vector2((r.size.x - 4) * clampf(a.hp / 100.0, 0, 1), 2)), Color(0.4, 0.9, 0.4) if a.wounds == 0 else Color(1, 0.35, 0.25))
			Pal.text(hud, r.position + Vector2(2, r.size.y - 15), "%d/%d+%d  M%d" % [a.mag_rounds, int(a.st["mag"]), a.mags, a.meds], 8, Color(col, 0.8))
		else:
			Pal.text(hud, r.position + Vector2(2, 1), str(f["def"]["id"]), 8, Color(0.6, 1.0, 0.6))
		hud.draw_rect(r, bc, false, 1.0)
		if sub != "" and sub != "OK":
			Pal.text(hud, r.position + Vector2(2, 11), sub, 8, Color(1, 0.5, 0.4))
	# radio barks
	var y := h - TILE.y - 16
	for k in range(barks.size() - 1, -1, -1):
		var b: Dictionary = barks[k]
		var a := clampf(1.0 - (float(b["t"]) - 4.5) / 1.5, 0.0, 1.0)
		Pal.text(hud, Vector2(10, y), "%s: %s" % [b["name"], b["text"]], 9, Color(b["col"], a))
		y -= 11
	# who you're talking to
	var to := "TALKING TO: ALL (1-4 one person)" if recipients.is_empty() else "TALKING TO: " + _first(recipients[0]).to_upper() + " (0 = all)"
	Pal.text(hud, Vector2(10, 30), to, 8, Color(1, 0.8, 0.3, 0.8))
	Pal.text(hud, Vector2(10, 40), "Right mouse: shout   Tab: feed   Space: pause   G: carry on", 8, Color(col, 0.4))
	if wheel_open:
		_draw_wheel()
	if pending >= 0:
		var mp := hud.get_local_mouse_position()
		var s: Dictionary = SHOUTS[pending]
		var tag := "%s: click %s" % [s["label"], {"door": "a door", "room": "a room", "enemy": "an enemy", "fighter": "one of yours", "point": "a spot"}[s["needs"]]]
		var ok := not hover_target.is_empty()
		if ok:
			var v = hover_target.values()[0]
			if v is Dictionary:
				tag = "%s %s" % [s["label"], str(v.get("name", "")).to_lower()]
			elif v is String:
				tag = "%s %s" % [s["label"], str(level.room(v).get("name", v)).to_lower()]
			elif v is Vector3:
				tag = s["label"] + " here"
			else:
				tag = "%s %s" % [s["label"], _first(v) if v.team == "us" else str(v.fighter_name)]
			# mark it in the feed
			var wp: Vector3 = Vector3.ZERO
			if v is Dictionary:
				wp = level.door_world(v, 1.0)
			elif v is String:
				var c: Vector2 = (level.room(v)["rect"] as Rect2).get_center()
				wp = Vector3(c.x, 1.0, c.y)
			elif v is Vector3:
				wp = v
			else:
				wp = v.chest_pos()
			if not main_cam.is_position_behind(wp):
				var sp := main_cam.unproject_position(wp)
				hud.draw_arc(sp, 9.0 + sin(t_op * 8.0) * 1.5, 0, TAU, 16, Color(1, 0.3, 0.85), 1.0)
		hud.draw_rect(Rect2(mp + Vector2(10, -6), Vector2(tag.length() * 5 + 6, 11)), Color(0, 0, 0, 0.7))
		Pal.text(hud, mp + Vector2(13, -5), tag, 8, Color(1, 0.3, 0.85) if ok else Color(0.8, 0.8, 0.8))
	_draw_objection()
	if phase == "report":
		_draw_report()


func _status(a) -> String:
	match a.state:
		"down":
			return "DOWN (stable)" if a.stable else "DOWN %ds" % int(a.bleed_out)
		"dead":
			return "KIA"
	if a.reloading > 0.0:
		return "RELOADING"
	if a.bandaging > 0.0:
		return "BANDAGING"
	if a.wounds > 0:
		return "BLEEDING"
	if a.target != null:
		return "ENGAGING"
	return "OK"


func _task_text() -> String:
	var t: Dictionary = sq.task
	match t.get("type", ""):
		"stack":
			return "stacking on the %s" % str(t["door"]["name"]).to_lower()
		"stacked":
			return "stacked on the %s: waiting for your call (breach, bang, push)" % str(t["door"]["name"]).to_lower()
		"breach":
			return "breaching the %s (%s)" % [str(t["door"]["name"]).to_lower(), t["how"]]
		"flow":
			return "entering the %s" % str(level.room(t["into"])["name"]).to_lower()
		"clear":
			return "clearing the %s" % str(level.room(t["into"])["name"]).to_lower()
		"grab":
			return "taking the manifests"
		"hold":
			return "holding: waiting for your call (G = carry on)"
		"fallback":
			return "falling back"
		"exfil":
			return "heading out"
	return ""


func _draw_wheel() -> void:
	var n := SHOUTS.size()
	var r_in := 14.0
	var r_out := 62.0
	hud.draw_circle(wheel_c, r_out + 6.0, Color(0, 0, 0, 0.55))
	for i in n:
		var a0 := -PI * 0.5 + (i - 0.5) * TAU / n
		var a1 := a0 + TAU / n
		var mid := (a0 + a1) * 0.5
		var c := Color(1, 0.3, 0.85) if i == wheel_hover else Color(0.85, 0.9, 0.85)
		hud.draw_line(wheel_c + Vector2(cos(a0), sin(a0)) * r_in, wheel_c + Vector2(cos(a0), sin(a0)) * r_out, Color(1, 1, 1, 0.15))
		var lp := wheel_c + Vector2(cos(mid), sin(mid)) * (r_out - 18.0)
		var lab: String = SHOUTS[i]["label"]
		Pal.text(hud, lp - Vector2(lab.length() * 2.5, 4), lab, 8, c)
	Pal.text(hud, wheel_c - Vector2(20, 4), "SHOUT", 8, Color(1, 1, 1, 0.5))


func _draw_report() -> void:
	var w := hud.size.x
	var h := hud.size.y
	var r := Rect2(Vector2(30, 24), Vector2(w - 60, h - 48))
	hud.draw_rect(r, Color(0.04, 0.035, 0.04, 0.94))
	hud.draw_rect(r, Color(0.6, 0.55, 0.4), false, 1.0)
	var head := "OP REPORT - " + ("SUCCESS: THE MANIFESTS ARE OURS" if outcome == "success" else "FAILED")
	Pal.text(hud, r.position + Vector2(8, 6), head, 11, Color(0.5, 1, 0.5) if outcome == "success" else Color(1, 0.4, 0.3))
	Pal.text(hud, r.position + Vector2(8, 20), "%s   %s" % [data.get("name", ""), _clock(t_op)], 8, Color(0.7, 0.7, 0.7))
	var y := r.position.y + 34
	for a in squad:
		var line := "%-12s %-9s %-14s shots %3d  hits %2d  meds left %d" % [a.fighter_name, a.role, _status(a), a.shots, a.hits, a.meds]
		Pal.text(hud, Vector2(r.position.x + 8, y), line, 8, Color(0.9, 0.85, 0.75) if a.state == "ok" else Color(1, 0.45, 0.35))
		y += 10
	y += 4
	var tally := {"dead": 0, "down": 0, "cuffed": 0, "surrendered": 0, "fled": 0, "ok": 0}
	for e in enemies:
		tally[e.state] = int(tally.get(e.state, 0)) + 1
	Pal.text(hud, Vector2(r.position.x + 8, y), "Them: %d dead, %d down, %d zip-tied, %d gave up, %d ran, %d still standing" % [tally["dead"], tally["down"], tally["cuffed"], tally["surrendered"], tally["fled"], tally["ok"]], 8, Color(0.8, 0.8, 0.8))
	y += 14
	Pal.text(hud, Vector2(r.position.x + 8, y), "YOUR SHOUTS", 8, Color(1, 0.8, 0.4))
	y += 10
	for s in shout_log.slice(maxi(0, shout_log.size() - 8)):
		Pal.text(hud, Vector2(r.position.x + 8, y), "%s  %s" % [_clock(s["t"]), s["text"]], 8, Color(0.9, 0.9, 0.9))
		y += 9
	if shout_log.is_empty():
		Pal.text(hud, Vector2(r.position.x + 8, y), "(none: they ran it on their own)", 8, Color(0.6, 0.6, 0.6))
	_restart_r = Rect2(r.end - Vector2(150, 20), Vector2(64, 14))
	_title_r = Rect2(r.end - Vector2(80, 20), Vector2(72, 14))
	for b in [[_restart_r, "Run it again"], [_title_r, "Back home" if from_garage else "Title"]]:
		hud.draw_rect(b[0], Color(0.2, 0.2, 0.2))
		hud.draw_rect(b[0], Color(0.7, 0.7, 0.6), false, 1.0)
		Pal.text(hud, (b[0] as Rect2).position + Vector2(0, 2), b[1], 8, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, (b[0] as Rect2).size.x)


## The plan on the board: the depot's blueprint comes with the hack (the Jobs app). Run from the title
## screen (no save), it's there for testing.
func _have_blueprint() -> bool:
	if game == null or game.state == null:
		return true
	return (game.state.os.get("jobs_done", []) as Array).has("freight_depot")


## Hacked cameras see too: anyone in a camera's view gets marked for the team (and the board).
func _cctv_spot() -> void:
	for f in feeds:
		if f["kind"] != "cctv":
			continue
		var cam: Camera3D = f["cam"]
		var fwd := -cam.global_basis.z
		for e in enemies:
			if e.state != "ok":
				continue
			var to: Vector3 = e.chest_pos() - cam.global_position
			if to.length() < 16.0 and to.normalized().dot(fwd) > 0.8 and level.clear_line(cam.global_position, e.chest_pos()):
				e.set_meta("seen_t", sq._t)
				e.set_meta("seen_pos", e.global_position)


func _draw_objection() -> void:
	var o: Dictionary = sq.objection
	if o.is_empty() or sq._t - float(o["t"]) > 12.0:
		return
	var w := hud.size.x
	var by = o["by"]
	var t1 := "%s OBJECTS: %s" % [_first(by).to_upper(), o["reason"]]
	var t2 := "[B] their way: %s      [same order again] do it anyway" % o["suggest_label"]
	var bw := maxf(t1.length(), t2.length()) * 5.0 + 12.0
	var r := Rect2(Vector2((w - bw) * 0.5, 52), Vector2(bw, 26))
	hud.draw_rect(r, Color(0.1, 0.05, 0.03, 0.88))
	hud.draw_rect(r, Color(1, 0.6, 0.2), false, 1.0)
	Pal.text(hud, r.position + Vector2(6, 3), t1, 8, Color(1, 0.8, 0.5))
	Pal.text(hud, r.position + Vector2(6, 14), t2, 8, Color(0.9, 0.9, 0.9))


## Who goes: your people in their kit when sent from the gear cage; the test squad otherwise.
var from_garage := false

func _squad_defs() -> Array:
	if game and game.state != null and game.has_meta("op_team"):
		from_garage = true
		var out: Array = []
		for pid in game.get_meta("op_team"):
			var p := Loadout.person(game.state, pid)
			if not p.is_empty() and p.get("alive", true):
				out.append(Loadout.to_fighter(game.state, p))
		if not out.is_empty():
			return out
	return data.get("squad", [])


## Back to the garage with what happened: the dead, what got used, the loot, the night spent.
func _return_home() -> void:
	var st = game.state
	var results: Array = []
	for a in squad:
		var start_mags := int(a.st["mags"])
		var used_mags := maxi(0, start_mags - 1 - a.mags)
		var start_meds := int(a.st["meds"])
		results.append({"id": a.id, "state": a.state,
			"used": {"mags": used_mags, "meds": maxi(0, start_meds - a.meds), "flash": maxi(0, int(a.st["flash"]) - a.flashes), "charges": maxi(0, int(a.st["charges"]) - a.charges)}})
	var loot: Array = []
	var loot_map := {"smg": "guard_smg", "carbine": "bureau_carbine", "pistol": "service_pistol"}
	for e in (enemies if outcome == "success" else []):          # you only strip the fallen if you held the field
		if e.state in ["dead", "down", "cuffed", "surrendered"]:
			var wid: String = (e.get_meta("def") as Dictionary).get("gear", {}).get("weapon", "")
			if loot_map.has(wid):
				loot.append(loot_map[wid])
				if wid != "pistol":
					st.supplies["mag_30"] = int(st.supplies.get("mag_30", 0)) + 1
				else:
					st.supplies["mag_pistol"] = int(st.supplies.get("mag_pistol", 0)) + 1
	var notes := Loadout.apply_op(st, results, loot)
	if sq.have_objective:
		st.items.append({"id": st.next_item_id, "name": "Shipping manifests", "type": "intel", "tag": "plan",
			"worth": "Which trucks carry what, and when.", "source": data.get("name", ""), "day": st.day, "stars": 0, "quality": 0.0, "hand": true, "perks": []})
		st.next_item_id += 1
	st.minute = st.end_minute          # an op takes the night
	st.actions = 0
	game.remove_meta("op_team")
	game.set_meta("op_notes", notes)
	game.autosave()
	game.goto("res://v2/garage.tscn")
