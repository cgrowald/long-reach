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
const DepotOp := preload("res://v2/combat/depot_op.gd")

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
const TILE := Vector2(88, 40)

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
var main_vp: SubViewport          # the big feed renders here (FIELD LINK panel), not full screen
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
var op: RefCounted = null          # the depot raid layer (v2/combat/depot_op.gd) when sent from the garage
const OpsBoard := preload("res://v2/combat/ops_board.gd")


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	data = Content.get_file("combat/depot")
	if game and game.state != null and game.has_meta("op_team"):
		op = DepotOp.new()
		data = op.prepare(self, data)
	view = PixelView.new()
	add_child(view)
	world = Node3D.new()
	view.vp.add_child(world)
	view.vp.audio_listener_enable_3d = false
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
	if op:
		hud.draw.connect(func() -> void: op.draw(hud))
	board = OpsBoard.new()
	view.ui.add_child(board)
	board.setup(self, _have_blueprint())
	if op:
		op.start()
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
		a.set_meta("head", str(def.get("head", "helmet")))
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
	main_vp = SubViewport.new()
	main_vp.size = Vector2i(350, 165)
	main_vp.world_3d = view.vp.find_world_3d()
	main_vp.audio_listener_enable_3d = true
	main_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	main_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(main_vp)
	main_vp.add_child(main_cam)
	main_cam.keep_aspect = Camera3D.KEEP_WIDTH
	main_cam.current = true
	main_post = _post_for(main_cam, 2)
	var layer := 3
	for a in squad:
		feeds.append({"kind": "helmet", "actor": a, "label": "CAM %02d  %s" % [feeds.size() + 1, a.fighter_name]})
	for c in data.get("cctv", []):
		if op and not _has_eyes():
			continue            # no EYES on this depot: no cameras
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
	main_cam.fov = 80.0 if mf["kind"] == "cctv" else 100.0
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
		if op:
			op.tick(delta)
		_separate()
		if squad.all(func(a) -> bool: return a.state != "ok"):
			_end("failed")
	for b in barks:
		b["t"] = float(b["t"]) + (0.0 if paused else delta)
	barks = barks.filter(func(b: Dictionary) -> bool: return float(b["t"]) < 6.0)
	_update_cameras(delta)
	if board:
		var mr := _map_rect()
		board.position = mr.position + Vector2(2, 15)
		board.size = mr.size - Vector2(4, 17)
		board.visible = phase != "report"
	_fit_main_vp()
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
	var m3 := _ui_to_main(mp)
	if m3.x < 0.0:
		return {}
	var o := main_cam.project_ray_origin(m3)
	var dir := main_cam.project_ray_normal(m3)
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
	if op and op.input(e, view.ui.get_local_mouse_position()):
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
			# a squad row? (their cam goes big)
			for i in squad.size():
				if _squad_row(i).has_point(mp):
					for k in feeds.size():
						if feeds[k]["kind"] == "helmet" and feeds[k]["actor"] == squad[i]:
							main_i = k
					if game:
						game.sfx.play("switch_002", 1.0 + i * 0.05, -10.0)
					get_viewport().set_input_as_handled()
					return
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


# ------------------------------------------------------------------ FIELD LINK layout (mission face-lift)
# User 2026-11-22: the "UPRISING / FIELD LINK" sheet: one big helmet cam, the map as paper recon,
# a squad list, a strip of feeds; every fighter has a face, and when their cam dies the face stays.

const UI_BG := Color(0.07, 0.085, 0.085)
const UI_PANEL := Color(0.1, 0.12, 0.12)
const UI_LINE := Color(0.72, 0.68, 0.56)
const UI_TEXT := Color(0.9, 0.87, 0.78)
const UI_DIM := Color(0.6, 0.58, 0.52)
const UI_AMBER := Color(0.95, 0.72, 0.3)
const UI_TEAL := Color(0.45, 0.72, 0.7)
const UI_RED := Color(0.9, 0.3, 0.22)
const STRIP_H := 76.0
const Face := preload("res://v2/ui/face.gd")


func _top_rect() -> Rect2:
	return Rect2(4, 3, hud.size.x - 8, 24)


func _main_rect() -> Rect2:
	var w := floorf((hud.size.x - 12) * 0.68)
	return Rect2(4, 31, w, hud.size.y - 31 - STRIP_H - 24)


func _main_img() -> Rect2:
	var m := _main_rect()
	return Rect2(m.position + Vector2(1, 27), m.size - Vector2(2, 28))


func _side_x() -> float:
	return _main_rect().end.x + 4


func _map_rect() -> Rect2:
	var x := _side_x()
	return Rect2(x, 31, hud.size.x - 4 - x, floorf(_main_rect().size.y * 0.46))


func _squad_rect() -> Rect2:
	var mr := _map_rect()
	return Rect2(mr.position.x, mr.end.y + 4, mr.size.x, _main_rect().end.y - mr.end.y - 4)


func _squad_row(i: int) -> Rect2:
	var r := _squad_rect()
	var h := minf(26.0, (r.size.y - 40) / maxf(1, squad.size()))
	return Rect2(r.position.x + 3, r.position.y + 15 + i * (h + 2), r.size.x - 6, h)


func _tile_rect(i: int) -> Rect2:
	var n := maxi(1, feeds.size())
	var w := floorf((hud.size.x - 8 - (n - 1) * 4) / n)
	return Rect2(4 + i * (w + 4), hud.size.y - STRIP_H - 20, w, STRIP_H)


func _tile_img(i: int) -> Rect2:
	var r := _tile_rect(i)
	return Rect2(r.position + Vector2(1, 19), Vector2(r.size.x - 2, r.size.y - 32))


## Mouse (UI units) -> the main feed's viewport pixels, or (-1,-1) if off the feed.
func _ui_to_main(p: Vector2) -> Vector2:
	var img := _main_img()
	if not img.has_point(p) or main_vp == null:
		return Vector2(-1, -1)
	return (p - img.position) * Vector2(main_vp.size) / img.size


func _main_to_ui(p: Vector2) -> Vector2:
	var img := _main_img()
	return img.position + p * img.size / Vector2(main_vp.size)


func _fit_main_vp() -> void:
	if main_vp == null or hud == null or hud.size.x < 10:
		return
	var px := 3.0
	if game:
		px = float(game.settings.get_v("pixel"))
	var want := Vector2i((_main_img().size * PixelView.UI_SCALE / px).round())
	if want.x > 8 and want.y > 8 and main_vp.size != want:
		main_vp.size = want


func _elapsed() -> String:
	var s := int(t_op)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func _bars(p: Vector2, level_: int, col: Color) -> void:
	for k in 4:
		var hh := 3.0 + k * 2.0
		hud.draw_rect(Rect2(p + Vector2(k * 3.5, 9 - hh), Vector2(2.5, hh)), col if k < level_ else Color(col, 0.2))


func _signal(a) -> int:
	if a == null:
		return 4
	if a.state == "dead":
		return 0
	if a.state == "down":
		return 1
	return 3 if a.wounds > 0 else 4


func _face(a, r: Rect2) -> void:
	Face.draw(hud, r, str(a.fighter_name), str(a.get_meta("head", "helmet")), a.state == "dead")
	hud.draw_rect(r, UI_LINE, false, 1.0)


func _state_word(a) -> Array:
	match a.state:
		"dead":
			return ["KIA", UI_DIM]
		"down":
			return ["DOWN", UI_RED]
	if a.wounds > 0:
		return ["BLEEDING", UI_RED]
	if a.reloading > 0.0:
		return ["RELOADING", UI_AMBER]
	if a.target != null:
		return ["ENGAGING", UI_AMBER]
	return ["STEADY", UI_TEAL]


func _panel(r: Rect2, title := "", hot := false) -> void:
	hud.draw_rect(r, UI_PANEL)
	hud.draw_rect(r, UI_AMBER if hot else UI_LINE, false, 2.0 if hot else 1.0)
	if title != "":
		Pal.text(hud, r.position + Vector2(5, 2), title, 9, UI_TEXT)
		hud.draw_line(r.position + Vector2(3, 13.5), Vector2(r.end.x - 3, r.position.y + 13.5), Color(UI_LINE, 0.5), 1.0)


func _draw_hud() -> void:
	var w := hud.size.x
	var h := hud.size.y
	hud.draw_rect(Rect2(Vector2.ZERO, hud.size), UI_BG)
	# ---- the top bar
	var tb := _top_rect()
	_panel(tb)
	Pal.text(hud, tb.position + Vector2(6, 6), "UPRISING / FIELD LINK", 10, UI_TEXT)
	var obj := str(data.get("objective", {}).get("text", "")).to_upper() + ("  [DONE]" if sq.have_objective else "")
	var cx := tb.position.x + tb.size.x * 0.36
	var dc := Vector2(cx, tb.get_center().y)
	hud.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -5), dc + Vector2(5, 0), dc + Vector2(0, 5), dc + Vector2(-5, 0)]), UI_AMBER)
	hud.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -2.5), dc + Vector2(2.5, 0), dc + Vector2(0, 2.5), dc + Vector2(-2.5, 0)]), UI_PANEL)
	Pal.text(hud, Vector2(cx + 10, tb.position.y + 1), obj, 8, UI_AMBER, HORIZONTAL_ALIGNMENT_LEFT, tb.end.x - cx - 140)
	Pal.text(hud, Vector2(cx + 10, tb.position.y + 12), _task_text(), 8, UI_DIM, HORIZONTAL_ALIGNMENT_LEFT, tb.end.x - cx - 140)
	var pr := Rect2(tb.end.x - 118, tb.position.y + 4, 16, 16)
	hud.draw_rect(pr, UI_LINE, false, 1.0)
	if paused:
		hud.draw_colored_polygon(PackedVector2Array([pr.position + Vector2(5, 4), pr.position + Vector2(12, 8), pr.position + Vector2(5, 12)]), UI_TEXT)
	else:
		hud.draw_rect(Rect2(pr.position + Vector2(4, 4), Vector2(3, 8)), UI_TEXT)
		hud.draw_rect(Rect2(pr.position + Vector2(9, 4), Vector2(3, 8)), UI_TEXT)
	Pal.text(hud, Vector2(tb.end.x - 96, tb.position.y + 6), "ELAPSED  " + _elapsed(), 9, UI_TEXT)
	# ---- the main feed
	var mr := _main_rect()
	var img := _main_img()
	var mf: Dictionary = feeds[main_i]
	_panel(mr, "", true)
	if main_vp:
		hud.draw_texture_rect(main_vp.get_texture(), img, false)
	var hx := mr.position.x + 4
	if mf["kind"] == "helmet":
		var a = mf["actor"]
		_face(a, Rect2(mr.position + Vector2(3, 3), Vector2(22, 22)))
		hx += 26
		Pal.text(hud, Vector2(hx, mr.position.y + 3), "%02d / %s" % [main_i + 1, str(a.fighter_name).to_upper()], 10, UI_TEXT)
		Pal.text(hud, Vector2(hx, mr.position.y + 15), "%s  -  HELMET CAM" % str(a.role).to_upper(), 8, UI_TEAL)
		var sig := _signal(a)
		_bars(Vector2(mr.end.x - 104, mr.position.y + 6), sig, UI_TEXT)
		Pal.text(hud, Vector2(mr.end.x - 86, mr.position.y + 6), ["LOST", "POOR", "FAIR", "GOOD", "GOOD"][sig], 8, UI_TEAL)
		if a.state == "dead":
			Pal.text(hud, Vector2(img.position.x, img.get_center().y - 20), "SIGNAL LOST", 14, UI_RED, HORIZONTAL_ALIGNMENT_CENTER, img.size.x)
			Face.draw(hud, Rect2(img.get_center() - Vector2(24, 0), Vector2(48, 54)), str(a.fighter_name), str(a.get_meta("head", "helmet")), true)
	else:
		_cam_icon(Vector2(hx + 2, mr.position.y + 7))
		hx += 22
		Pal.text(hud, Vector2(hx, mr.position.y + 3), str(mf["def"]["id"]).to_upper(), 10, Color(0.6, 1.0, 0.6))
		Pal.text(hud, Vector2(hx, mr.position.y + 15), "FIXED CAMERA  -  %s" % str(mf["def"]["label"]).to_upper(), 8, UI_DIM)
	if fmod(t_op, 1.0) < 0.6 or paused:
		hud.draw_circle(Vector2(mr.end.x - 42, mr.position.y + 11), 3.0, UI_RED)
	Pal.text(hud, Vector2(mr.end.x - 36, mr.position.y + 6), "REC", 8, UI_RED)
	# radio subtitles, bottom left of the feed, with the speaker's face
	var y := img.end.y - 16
	var shown := 0
	for k in range(barks.size() - 1, -1, -1):
		if shown >= 3:
			break
		var b: Dictionary = barks[k]
		var al := clampf(1.0 - (float(b["t"]) - 4.5) / 1.5, 0.0, 1.0)
		var who = _by_name(str(b["name"]))
		var line := "%s: %s" % [b["name"], b["text"]]
		var tw := minf(img.size.x - 30, line.length() * 5.6 + 8)
		hud.draw_rect(Rect2(img.position.x + 4, y - 2, tw + 18, 14), Color(0, 0, 0, 0.55 * al))
		if who != null:
			Face.draw(hud, Rect2(img.position.x + 5, y - 1, 12, 12), str(who.fighter_name), str(who.get_meta("head", "helmet")), who.state == "dead")
		Pal.text(hud, Vector2(img.position.x + 20, y), line, 9, Color(b["col"], al), HORIZONTAL_ALIGNMENT_LEFT, tw)
		y -= 16
		shown += 1
	if paused:
		Pal.text(hud, Vector2(img.position.x, img.position.y + img.size.y * 0.35), "PAUSED  (Space)", 12, UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER, img.size.x)
	# ---- the map
	var mp_r := _map_rect()
	_panel(mp_r, "OPS MAP / RECON")
	# ---- the squad
	var sr := _squad_rect()
	_panel(sr, "SQUAD")
	for i in squad.size():
		var a = squad[i]
		var r := _squad_row(i)
		var on: bool = mf["kind"] == "helmet" and mf["actor"] == a
		hud.draw_rect(r, Color(UI_AMBER, 0.08) if on else Color(0, 0, 0, 0))
		hud.draw_rect(r, UI_AMBER if on else (Color(UI_AMBER, 0.7) if recipients.has(a) else Color(UI_LINE, 0.35)), false, 2.0 if on else 1.0)
		var nb := Rect2(r.position + Vector2(3, 4), Vector2(r.size.y - 8, r.size.y - 8))
		hud.draw_rect(nb, UI_LINE, false, 1.0)
		Pal.text(hud, nb.position + Vector2(0, (nb.size.y - 10) * 0.5), str(i + 1), 8, UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER, nb.size.x)
		_face(a, Rect2(Vector2(nb.end.x + 3, r.position.y + 2), Vector2(r.size.y - 4, r.size.y - 4)))
		var nx := nb.end.x + r.size.y + 3
		var sw: Array = _state_word(a)
		if sw[1] == UI_RED:
			_warn(Vector2(nx + 3, r.get_center().y))
			nx += 10
		Pal.text(hud, Vector2(nx, r.get_center().y - 5), _first(a).to_upper(), 9, UI_TEXT)
		_bars(Vector2(r.end.x - 74, r.get_center().y - 5), _signal(a), UI_TEXT)
		if a.state == "down" and fmod(t_op, 0.6) < 0.3:
			pass
		else:
			Pal.text(hud, Vector2(r.end.x - 58, r.get_center().y - 5), sw[0], 8, sw[1])
	var to := "TALKING TO: ALL" if recipients.is_empty() else "TALKING TO: " + _first(recipients[0]).to_upper()
	var tr := Rect2(sr.position.x + 3, sr.end.y - 17, sr.size.x * 0.55, 14)
	hud.draw_rect(tr, UI_LINE, false, 1.0)
	Pal.text(hud, tr.position + Vector2(4, 2), to, 8, UI_AMBER)
	# ---- the feed strip
	for i in feeds.size():
		var f: Dictionary = feeds[i]
		var r := _tile_rect(i)
		var ti := _tile_img(i)
		var on := i == main_i
		hud.draw_rect(r, UI_PANEL)
		hud.draw_texture_rect((f["vp"] as SubViewport).get_texture(), ti, false)
		var cap := ""
		if f["kind"] == "helmet":
			var a = f["actor"]
			_face(a, Rect2(r.position + Vector2(2, 1), Vector2(16, 17)))
			Pal.text(hud, r.position + Vector2(21, 3), "%d %s" % [i + 1, _first(a).to_upper()], 9, UI_TEXT)
			if _state_word(a)[1] == UI_RED:
				_warn(Vector2(r.end.x - 26, r.position.y + 8))
			_bars(Vector2(r.end.x - 17, r.position.y + 3), _signal(a), UI_TEXT)
			cap = _title(str(level.room(level.room_at(a.global_position)).get("name", "")))
			if a.state == "dead":
				hud.draw_rect(ti, Color(0.03, 0.03, 0.03, clampf(float(f["dead_t"]) / 2.5, 0.0, 0.85)))
				var fs := minf(ti.size.y - 6, 40.0)
				Face.draw(hud, Rect2(ti.get_center() - Vector2(fs * 0.45, fs * 0.5), Vector2(fs * 0.9, fs)), str(a.fighter_name), str(a.get_meta("head", "helmet")), true)
				Pal.text(hud, Vector2(ti.position.x, ti.end.y - 11), "SIGNAL LOST", 8, UI_RED, HORIZONTAL_ALIGNMENT_CENTER, ti.size.x)
			else:
				Pal.text(hud, Vector2(r.end.x - 52, r.end.y - 12), "%d+%d" % [a.mag_rounds, a.mags], 8, UI_DIM, HORIZONTAL_ALIGNMENT_RIGHT, 48)
				hud.draw_rect(Rect2(ti.position + Vector2(0, ti.size.y - 2), Vector2(ti.size.x * clampf(a.hp / 100.0, 0, 1), 2)), UI_TEAL if a.wounds == 0 else UI_RED)
		else:
			_cam_icon(r.position + Vector2(4, 4))
			Pal.text(hud, r.position + Vector2(20, 2), str(f["def"]["id"]).to_upper(), 9, UI_TEXT)
			_bars(Vector2(r.end.x - 17, r.position.y + 3), 3, UI_TEXT)
			cap = _title(str(f["def"]["label"]))
		Pal.text(hud, Vector2(r.position.x + 3, r.end.y - 12), cap, 8, UI_TEXT, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44)
		hud.draw_rect(r, UI_AMBER if on else UI_LINE, false, 2.0 if on else 1.0)
	# ---- key hints
	var hb := Rect2(4, h - 17, w - 8, 15)
	_panel(hb)
	var hx2 := hb.position.x + 6
	for kv in [["1-4", "Talk to one"], ["Tab", "Next feed"], ["R-mouse", "Shout"], ["Space", "Pause"], ["G", "Carry on"], ["Esc", "Back"]]:
		Pal.text(hud, Vector2(hx2, hb.position.y + 3), kv[0], 8, UI_TEXT)
		hx2 += kv[0].length() * 5.0 + 6
		Pal.text(hud, Vector2(hx2, hb.position.y + 3), kv[1], 8, UI_TEAL)
		hx2 += kv[1].length() * 5.0 + 16
	# ---- shouts, the target marker, objections, the report
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
				var sp := _main_to_ui(main_cam.unproject_position(wp))
				hud.draw_arc(sp, 9.0 + sin(t_op * 8.0) * 1.5, 0, TAU, 16, Color(1, 0.3, 0.85), 1.0)
		hud.draw_rect(Rect2(mp + Vector2(10, -6), Vector2(tag.length() * 5.5 + 6, 12)), Color(0, 0, 0, 0.75))
		Pal.text(hud, mp + Vector2(13, -5), tag, 8, Color(1, 0.3, 0.85) if ok else Color(0.8, 0.8, 0.8))
	_draw_objection()
	if phase == "report":
		_draw_report()


## "B2 CORRIDOR" -> "B2 Corridor".
func _title(s: String) -> String:
	var out: Array = []
	for wd in s.to_lower().split(" "):
		out.append(wd.substr(0, 1).to_upper() + wd.substr(1))
	return " ".join(PackedStringArray(out))


func _by_name(n: String):
	for a in squad:
		if _first(a).to_upper() == n.to_upper() or str(a.fighter_name).to_upper() == n.to_upper():
			return a
	return null


func _warn(c: Vector2) -> void:
	hud.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 4), c + Vector2(-5, 4)]), UI_RED)
	hud.draw_rect(Rect2(c + Vector2(-0.5, -2), Vector2(1.2, 3)), UI_PANEL)


func _cam_icon(p: Vector2) -> void:
	hud.draw_rect(Rect2(p, Vector2(10, 6)), UI_TEXT)
	hud.draw_colored_polygon(PackedVector2Array([p + Vector2(10, 1), p + Vector2(14, -1), p + Vector2(14, 7), p + Vector2(10, 5)]), UI_TEXT)
	hud.draw_line(p + Vector2(3, 6), p + Vector2(1, 10), UI_TEXT, 1.0)


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
	hud.draw_rect(Rect2(Vector2.ZERO, hud.size), Color(0, 0, 0, 0.55))
	var r := Rect2(Vector2(40, 30), Vector2(w - 80, h - 60))
	_panel(r)
	var good := outcome == "success"
	var head := "OP REPORT  -  " + (("WE GOT OUT" if op else "THE MANIFESTS ARE OURS") if good else "FAILED")
	Pal.text(hud, r.position + Vector2(10, 8), head, 12, Color(0.55, 0.9, 0.55) if good else UI_RED)
	Pal.text(hud, r.position + Vector2(10, 24), "%s   elapsed %s" % [data.get("name", ""), _elapsed()], 8, UI_DIM)
	# your people: a card each, with their face (greyed if they didn't come home)
	var cw := minf(120.0, (r.size.x - 20 - (squad.size() - 1) * 6) / maxf(1, squad.size()))
	for i in squad.size():
		var a = squad[i]
		var cr := Rect2(r.position + Vector2(10 + i * (cw + 6), 40), Vector2(cw, 62))
		hud.draw_rect(cr, Color(0, 0, 0, 0.25))
		hud.draw_rect(cr, UI_RED if a.state == "dead" else UI_LINE, false, 1.0)
		Face.draw(hud, Rect2(cr.position + Vector2(4, 4), Vector2(30, 34)), str(a.fighter_name), str(a.get_meta("head", "helmet")), a.state == "dead")
		Pal.text(hud, cr.position + Vector2(38, 4), _first(a).to_upper(), 9, UI_TEXT, HORIZONTAL_ALIGNMENT_LEFT, cw - 40)
		var sw: Array = _state_word(a)
		Pal.text(hud, cr.position + Vector2(38, 16), "KIA" if a.state == "dead" else ("HOME" if a.state == "ok" else sw[0]), 8, UI_RED if a.state != "ok" else UI_TEAL)
		Pal.text(hud, cr.position + Vector2(38, 27), str(a.role), 8, UI_DIM)
		Pal.text(hud, cr.position + Vector2(4, 42), "shots %d  hits %d" % [a.shots, a.hits], 8, UI_DIM, HORIZONTAL_ALIGNMENT_LEFT, cw - 8)
		Pal.text(hud, cr.position + Vector2(4, 51), "meds left %d" % a.meds, 8, UI_DIM)
	var y := r.position.y + 110
	var tally := {"dead": 0, "down": 0, "cuffed": 0, "surrendered": 0, "fled": 0, "ok": 0}
	for e in enemies:
		tally[e.state] = int(tally.get(e.state, 0)) + 1
	Pal.text(hud, Vector2(r.position.x + 10, y), "THEM: %d dead, %d down, %d zip-tied, %d gave up, %d ran, %d still standing" % [tally["dead"], tally["down"], tally["cuffed"], tally["surrendered"], tally["fled"], tally["ok"]], 8, UI_TEXT)
	y += 16
	Pal.text(hud, Vector2(r.position.x + 10, y), "YOUR SHOUTS", 8, UI_AMBER)
	y += 11
	for s in shout_log.slice(maxi(0, shout_log.size() - 7)):
		Pal.text(hud, Vector2(r.position.x + 10, y), "%s  %s" % [_clock(s["t"]), s["text"]], 8, UI_TEXT, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20)
		y += 10
	if shout_log.is_empty():
		Pal.text(hud, Vector2(r.position.x + 10, y), "(none: they ran it on their own)", 8, UI_DIM)
	_restart_r = Rect2(r.end - Vector2(196, 24), Vector2(90, 16))
	_title_r = Rect2(r.end - Vector2(100, 24), Vector2(90, 16))
	for b in [[_restart_r, "Run it again", false], [_title_r, "Back home" if from_garage else "Title", true]]:
		var br: Rect2 = b[0]
		hud.draw_rect(br, Color(0.78, 0.45, 0.2) if b[2] else UI_PANEL)
		hud.draw_rect(br, UI_LINE, false, 1.0)
		Pal.text(hud, br.position + Vector2(0, 3), b[1], 8, UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)


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
		if op:
			results[-1].merge(op.fighter_result(a))
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
	if op:
		notes.append_array(op.results(outcome))
	if sq.have_objective and op == null:
		st.items.append({"id": st.next_item_id, "name": "Shipping manifests", "type": "intel", "tag": "plan",
			"worth": "Which trucks carry what, and when.", "source": data.get("name", ""), "day": st.day, "stars": 0, "quality": 0.0, "hand": true, "perks": []})
		st.next_item_id += 1
	st.minute = st.end_minute          # an op takes the night
	st.actions = 0
	game.remove_meta("op_team")
	game.set_meta("op_notes", notes)
	game.autosave()
	game.goto("res://v2/garage.tscn")


## EYES: did you link this depot's cameras from the PC (the EYES program on a depot target)?
func _has_eyes() -> bool:
	if game == null or game.state == null:
		return true
	for id in game.state.os.get("cameras", []):
		if "depot" in str(id):
			return true
	return false
