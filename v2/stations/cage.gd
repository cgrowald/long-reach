extends "res://v2/stations/station.gd"
## The gear cage, laid out like art bible 17 (docs/ART_BIBLE.md, docs/DEPOT_SLICE.md section 8):
## the fighter stands in 3D in the middle of the cage, slot tiles on lines around them (left: head, clothes,
## primary, sidearm; right: face, back, rig, plate), the STASH grid on the right, your people's portraits
## along the bottom. Rules stay in v2/sim/loadout.gd.
##   click a stash tile: wear it (gear), or pick it up to pack (supplies, meds, the drop stick)
##   click a slot: the stash shows only what fits it; right-click a slot: take it off
##   the RIG slot opens the rig grid over the top of the stash; click a cell to pack, right-click to take out
## The stick carrier (whoever has the drop stick packed) shows on their portrait, their name and in the grid.

const Loadout := preload("res://v2/sim/loadout.gd")
const Soldier := preload("res://v2/combat/soldier.gd")
const Rules := preload("res://v2/combat/rules.gd")
const Face := preload("res://v2/ui/face.gd")
const DepotRun := preload("res://v2/sim/depot_run.gd")

const SLOT_NAMES := {"primary": "PRIMARY", "sidearm": "SIDEARM", "head": "HEAD", "face": "FACE", "rig": "RIG",
	"plate": "PLATE", "back": "BACK", "clothes": "CLOTHES"}
const LEFT := ["head", "clothes", "primary", "sidearm"]
const RIGHT := ["face", "back", "rig", "plate"]
## Where each slot's line meets the body (the fighter stands at the origin, facing the camera).
const ANCHOR := {"head": Vector3(0.0, 1.72, 0.0), "face": Vector3(0.05, 1.58, 0.12), "clothes": Vector3(-0.2, 1.25, 0.1),
	"back": Vector3(0.2, 1.42, -0.05), "primary": Vector3(-0.3, 1.0, 0.1), "rig": Vector3(0.1, 1.12, 0.14),
	"sidearm": Vector3(-0.2, 0.9, 0.05), "plate": Vector3(0.05, 1.3, 0.15)}
const TILE := 38.0
const SCELL := 34.0           # stash tile
const RCELL := 20.0           # rig grid cell
const STASH_COLS := 5
const LINE := Color(0.86, 0.6, 0.26)
const PANEL := Color(0.07, 0.075, 0.07, 0.94)

var sel := 0
var _vp: SubViewport
var _stage: Node3D
var _cam: Camera3D
var _model: Node3D
var _tex: TextureRect
var _info: VBoxContainer
var _msg := ""
var _msg_t := 0.0
var _holding := {}            # {gear, item?} picked up from the stash, to pack
var _filter := ""             # a slot: the stash shows only what fits it
var _rig_open := false
var _hover := Vector2(-1, -1)
var _hits: Array = []         # [Rect2, kind, value] rebuilt every draw
var _scroll := 0
var _tip := ""
var _t := 0.0


func build() -> void:
	var title := Kit.title_tag("GEAR CAGE", 14)
	title.position = Vector2(12, 8)
	add_child(title)
	# the cage, in 3D, behind everything on the left
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_make_stage()
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.show_behind_parent = true
	add_child(_tex)
	# who they are (top left, under the title)
	_info = VBoxContainer.new()
	_info.position = Vector2(14, 40)
	_info.custom_minimum_size.x = 96
	_info.add_theme_constant_override("separation", 1)
	add_child(_info)
	var back_b := Kit.button("< Shelves", func() -> void: garage.open_screen("stash"), game)
	add_child(back_b)
	var x_b := Kit.button("X", close, game)
	add_child(x_b)
	var send := Kit.button("Send them: depot raid", _send, game)
	add_child(send)
	var plan_b := Kit.button("Plan file", func() -> void:
		var pf := DepotRun.plan_files(game.state)
		if not pf.is_empty():
			show_plan(pf[-1]), game)
	add_child(plan_b)
	plan_b.visible = not DepotRun.plan_files(game.state).is_empty()
	var lay := func() -> void:
		_tex.position = Vector2.ZERO
		_tex.size = Vector2(_stash_rect().position.x - 8, size.y)
		_vp.size = Vector2i(maxi(64, int(_tex.size.x * 2.0)), maxi(64, int(_tex.size.y * 2.0)))   # twice the UI units: crisper than the garage, still chunky
		back_b.position = Vector2(size.x - 120, 6)
		x_b.position = Vector2(size.x - 26, 6)
		send.position = Vector2(size.x - 168, size.y - 26)
		plan_b.position = Vector2(size.x - 236, size.y - 26)
	resized.connect(lay)
	lay.call()
	if game.state.people.is_empty():
		_msg = "Nobody yet. (Older save: start a new game.)"
	_refresh()
	game.sfx.play("drop_002", 0.7, -8.0)


func _make_stage() -> void:
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.05, 3.7)
	_cam.fov = 36.0
	_cam.h_offset = -0.4         # the fighter stands right of centre, clear of the info column
	_stage.add_child(_cam)
	_cam.look_at(Vector3(0, 0.98, 0))
	_cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.04, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.42, 0.3)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.25, 0.17, 0.1)
	e.fog_density = 0.04
	env.environment = e
	_stage.add_child(env)
	# the bulb over them (bible 17: a warm cone from above)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.3, 3.0, 0.9)
	lamp.light_color = Color(1.0, 0.76, 0.45)
	lamp.light_energy = 5.0
	lamp.spot_range = 6.0
	lamp.spot_angle = 32.0
	lamp.shadow_enabled = true
	_stage.add_child(lamp)
	lamp.look_at(Vector3(0, 0.6, 0))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 1.6, 1.5)
	fill.light_color = Color(0.5, 0.42, 0.36)
	fill.light_energy = 0.4
	_stage.add_child(fill)
	var wall_l := OmniLight3D.new()       # a second bulb over the shelves, so the cage reads behind them
	wall_l.position = Vector3(-2.2, 2.2, -0.6)
	wall_l.light_color = Color(1.0, 0.7, 0.4)
	wall_l.light_energy = 1.4
	wall_l.omni_range = 3.5
	_stage.add_child(wall_l)
	var shade := _box(Vector3(0.5, 0.12, 0.5), Vector3(0.3, 3.05, 0.9), Color(0.12, 0.1, 0.08))
	shade.rotation.x = 0.1
	_box(Vector3(0.22, 0.04, 0.22), Vector3(0.3, 2.98, 0.9), Color(1.0, 0.85, 0.6), 3.0)
	# floor, a painted yellow line, the back wall
	_box(Vector3(9, 0.02, 7), Vector3(0, -0.01, -1.0), Color(0.19, 0.16, 0.13))
	var ln := _box(Vector3(3.2, 0.021, 0.09), Vector3(-1.9, 0.0, 0.7), Color(0.75, 0.6, 0.15))
	ln.rotation.y = 0.45
	_box(Vector3(9, 4, 0.1), Vector3(0, 2.0, -2.4), Color(0.17, 0.14, 0.11))
	# chain-link cage walls left and right, with posts
	var wire := Color(0.32, 0.31, 0.29)
	for side in [-1.0, 1.0]:
		for i in 18:
			var b := _box(Vector3(0.012, 2.6, 0.012), Vector3(side * 1.75, 1.3, -2.0 + i * 0.11), wire)
			b.rotation.x = 0.35 * side
		for i in 18:
			var b2 := _box(Vector3(0.012, 2.6, 0.012), Vector3(side * 1.75, 1.3, -2.0 + i * 0.11), wire)
			b2.rotation.x = -0.35 * side
		_box(Vector3(0.06, 2.8, 0.06), Vector3(side * 1.75, 1.4, -0.05), Color(0.25, 0.23, 0.2))
		_box(Vector3(0.06, 2.8, 0.06), Vector3(side * 1.75, 1.4, -2.0), Color(0.25, 0.23, 0.2))
	# shelves with boxes behind the left wire, crates at its foot (Dobrev boxes, bible 17)
	for y in [0.5, 1.2, 1.9]:
		_box(Vector3(1.2, 0.04, 0.45), Vector3(-2.4, y, -1.4), Color(0.3, 0.24, 0.17))
	for i in 5:
		var w := 0.25 + 0.1 * (i % 3)
		_box(Vector3(w, 0.25, 0.3), Vector3(-2.85 + i * 0.25, 0.65 + (i % 3) * 0.7, -1.4), Color(0.5, 0.4, 0.27).darkened(0.1 * (i % 2)))
	_box(Vector3(0.6, 0.45, 0.45), Vector3(-2.3, 0.225, -0.6), Color(0.62, 0.5, 0.33))
	_box(Vector3(0.6, 0.45, 0.45), Vector3(-2.3, 0.675, -0.6), Color(0.58, 0.47, 0.31))
	_box(Vector3(0.62, 0.06, 0.46), Vector3(-2.3, 0.3, -0.6), Color(0.6, 0.18, 0.14))
	# a coat on a hook behind the right wire
	_box(Vector3(0.45, 0.9, 0.12), Vector3(2.3, 1.6, -1.6), Color(0.33, 0.3, 0.22))


func _box(sz: Vector3, pos: Vector3, col: Color, emit := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emit
	m.material_override = mat
	m.position = pos
	_stage.add_child(m)
	return m


func _person() -> Dictionary:
	var people: Array = game.state.people
	if people.is_empty():
		return {}
	sel = clampi(sel, 0, people.size() - 1)
	return people[sel]


# ------------------------------------------------------------------ layout

func _stash_rect() -> Rect2:
	var w := STASH_COLS * SCELL + 20.0
	return Rect2(size.x - w - 12, 34, w, size.y - 34 - 34)


func _rig_rect() -> Rect2:
	var sr := _stash_rect()
	var gs := Loadout.grid_size(game.state, _person()) if not _person().is_empty() else Vector2i.ZERO
	return Rect2(sr.position + Vector2(10, 22), Vector2(sr.size.x - 20, 36 + maxi(1, gs.y) * RCELL))


func _grid_origin() -> Vector2:
	var rr := _rig_rect()
	var gs := Loadout.grid_size(game.state, _person())
	return Vector2(rr.position.x + (rr.size.x - gs.x * RCELL) * 0.5, rr.position.y + 16)


## The slot tiles: two columns either side of the fighter.
func _slot_rect(slot: String) -> Rect2:
	var cx := _anchor_at(Vector3(0, 1.0, 0)).x
	var left := LEFT.has(slot)
	var i: int = LEFT.find(slot) if left else RIGHT.find(slot)
	var x := cx - 100 - TILE if left else cx + 100
	return Rect2(Vector2(x, 54 + i * 64), Vector2(TILE, TILE))


## A body point on screen (UI units), through the stage camera.
func _anchor(slot: String) -> Vector2:
	return _anchor_at(ANCHOR[slot])


func _anchor_at(w: Vector3) -> Vector2:
	var p: Vector2 = _cam.unproject_position(w)
	return p * (_tex.size / Vector2(_vp.size))


func _portrait_rect(i: int) -> Rect2:
	return Rect2(Vector2(14 + i * 48, size.y - 62), Vector2(42, 48))


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var st = game.state
	for c in _info.get_children():
		c.queue_free()
	var p := _person()
	if not p.is_empty():
		_info.add_child(Kit.label(str(p["name"]), Pal.TEXT, 10, 96))
		_info.add_child(Kit.label(str(p.get("role", "")).to_upper() + "  " + str(p.get("trait", "")), Pal.AMBER, 8))
		var tech := int(p.get("tech", 0))
		var has_stick := not Loadout.stick_of(st, p).is_empty()
		_info.add_child(Kit.label("Tech %d%s" % [tech, "" if has_stick else (", can carry" if tech >= 1 else ", no stick")], Pal.DIM, 8, 96))
		if has_stick:
			_info.add_child(Kit.label("STICK CARRIER", Pal.GREEN, 9))
		var mot = p.get("motive", {})
		if mot is Dictionary and not mot.is_empty():
			_info.add_child(Kit.label("In it for: " + str(mot.get("name", "")), Pal.DIM, 8, 96))
		if int(p.get("injury_days", 0)) > 0:
			_info.add_child(Kit.label("HURT: %d days, %d health" % [int(p["injury_days"]), int(p.get("hp", 100))], Color(1.0, 0.5, 0.35), 8, 96))
			var med := _best_med()
			if not med.is_empty():
				_info.add_child(Kit.button("Treat (%s %s)" % [str(med.get("name", "")).split(" ")[0], "*".repeat(int(med.get("stars", 0)))], func() -> void:
					var off := Loadout.treat(game.state, p, med)
					_say("%d day%s off their recovery." % [off, "" if off == 1 else "s"])
					_refresh(), game))
		_info.add_child(Kit.label("Ops: %d" % int(p.get("ops", 0)), Pal.DIM, 8))
	_rebuild_model()
	queue_redraw()


func _rebuild_model() -> void:
	if _model and is_instance_valid(_model):
		_model.queue_free()
	var p := _person()
	if p.is_empty():
		return
	_model = Soldier.new()
	_stage.add_child(_model)
	_model.setup(Loadout.to_fighter(game.state, p))
	_model.raised = 0.0
	_model.crouch = 0.0
	if _model.light:
		_model.light.visible = false


func _stats_text() -> String:
	var p := _person()
	if p.is_empty():
		return ""
	var def := Loadout.to_fighter(game.state, p)
	if not def["armed"]:
		return "No gun.\n They follow and help\n (patch, zip-tie),\n but can't fight."
	var s := Rules.stats(def["gear"], str(p.get("trait", "")))
	return "%s\nacc %d  dmg %d\nready %.2fs\nmags %d  meds %d\nflash %d\nplate: %s" % [s["weapon"], int(float(s["acc"]) * 100.0), int(s["dmg"]),
		float(s["ads"]) + float(s.get("react", 0.5)), int(s["mags"]), int(s["meds"]), int(s["flash"]), s["plate_name"]]


func _say(t: String) -> void:
	_msg = t
	_msg_t = 3.0


# ------------------------------------------------------------------ the stash list

## Everything the stash grid shows: [{kind: "gear"|"supply"|"pack", gear, item?, count?, slot?}]
func _stash_entries() -> Array:
	var st = game.state
	var out: Array = []
	for it in st.items:
		var gid := str(it.get("gear", ""))
		var d := Loadout.gdef(gid)
		if d.get("slot", "") != "" and str(it.get("on", "")) == "":
			out.append({"kind": "gear", "gear": gid, "item": it, "slot": d["slot"]})
	for gid in st.supplies:
		if int(st.supplies[gid]) > 0 and Loadout.gdef(gid).has("cells"):
			out.append({"kind": "supply", "gear": gid, "count": int(st.supplies[gid])})
	for it in Loadout.packable_items(st):
		out.append({"kind": "pack", "gear": str(it["gear"]), "item": it})
	if _filter != "":
		var f: Array = []
		for e in out:
			if e.get("slot", "") == _filter:
				f.append(e)
		return f
	return out


func _stash_click(e: Dictionary) -> void:
	var st = game.state
	var p := _person()
	if p.is_empty():
		return
	if e["kind"] == "gear":
		var why := Loadout.equip(st, p, e["item"])
		if why != "":
			_say(why)
			game.deny()
		else:
			game.sfx.play("switch_002", 1.0, -8.0)
			_filter = ""
			_scroll = 0
		_refresh()
		return
	# something to pack: pick it up and open the rig
	if Loadout.grid_size(st, p).x == 0:
		_say("No rig on. Put a rig on them first (the RIG slot).")
		game.deny()
		return
	_holding = {"gear": e["gear"]}
	if e.has("item"):
		_holding["item"] = int(e["item"]["id"])
	_rig_open = true
	game.click()
	queue_redraw()


func _slot_click(slot: String, right: bool) -> void:
	var st = game.state
	var p := _person()
	if p.is_empty():
		return
	if right:
		if not Loadout.worn(st, p, slot).is_empty():
			Loadout.unequip(st, p, slot)
			game.sfx.play("drop_002", 1.2, -10.0)
			_refresh()
		return
	game.click()
	_scroll = 0
	if slot == "rig" and Loadout.grid_size(st, p).x > 0:
		_rig_open = not _rig_open
		_filter = ""
	else:
		_filter = "" if _filter == slot else slot
		_rig_open = false
	queue_redraw()


func _auto_pack() -> void:
	var st = game.state
	var p := _person()
	if p.is_empty():
		return
	var ammo: String = ""
	var prim := Loadout.worn(st, p, "primary")
	if prim.is_empty():
		prim = Loadout.worn(st, p, "sidearm")
	if not prim.is_empty():
		ammo = Loadout.gdef(prim["gear"]).get("ammo", "")
	var want: Array = []
	for k in 3:
		if ammo != "":
			want.append({"gear": ammo})
	for it in Loadout.packable_items(st):
		if it["gear"] == "drop_stick":
			continue                 # the stick goes to whoever you choose, by hand
		want.append({"gear": it["gear"], "item": int(it["id"])})
		break
	for gid in ["flash", "charge"]:
		if int(st.supplies.get(gid, 0)) > 0:
			want.append({"gear": gid})
	for w in want:
		var spot := Loadout.free_spot(st, p, w["gear"])
		if spot.x >= 0:
			Loadout.pack(st, p, w["gear"], spot.x, spot.y, int(w.get("item", -1)))
	game.sfx.play("switch_002", 1.1, -8.0)
	_refresh()


# ------------------------------------------------------------------ input

func back() -> bool:
	if put_paper_down():
		return true
	if not _holding.is_empty() or _rig_open or _filter != "":
		_holding = {}
		_rig_open = false
		_filter = ""
		queue_redraw()
		return true
	return false


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = e.position
		return
	if not (e is InputEventMouseButton and e.pressed):
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _stash_rect().has_point(e.position):
			_scroll = maxi(0, _scroll + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			accept_event()
			queue_redraw()
		return
	var right: bool = e.button_index == MOUSE_BUTTON_RIGHT
	if e.button_index != MOUSE_BUTTON_LEFT and not right:
		return
	for h in _hits:
		if not (h[0] as Rect2).has_point(e.position):
			continue
		accept_event()
		match str(h[1]):
			"person":
				sel = int(h[2])
				_holding = {}
				_filter = ""
				_rig_open = false
				game.click()
				_refresh()
			"slot":
				_slot_click(str(h[2]), right)
			"stash":
				if not right:
					_stash_click(h[2])
			"cell":
				_cell_click(h[2], right)
			"rig_close":
				_rig_open = false
				_holding = {}
				queue_redraw()
			"auto":
				_auto_pack()
			"clear_filter":
				_filter = ""
				queue_redraw()
			"take_off":
				_slot_click(_filter, true)
		return
	# clicking empty space drops what you hold
	if not _holding.is_empty():
		_holding = {}
		queue_redraw()


func _cell_click(c: Vector2i, right: bool) -> void:
	var st = game.state
	var p := _person()
	if right:
		for i in p["grid"].size():
			var ge: Dictionary = p["grid"][i]
			var cc := Loadout.cells(ge["gear"])
			if Rect2i(int(ge["x"]), int(ge["y"]), cc.x, cc.y).has_point(c):
				Loadout.unpack(st, p, i)
				game.sfx.play("drop_002", 1.3, -10.0)
				_refresh()
				return
		return
	if _holding.is_empty():
		return
	var why := Loadout.pack(st, p, _holding["gear"], c.x, c.y, int(_holding.get("item", -1)))
	if why != "":
		_say(why)
		game.deny()
	else:
		game.sfx.play("switch_002", 1.2, -8.0)
		if _holding.has("item") or int(st.supplies.get(_holding["gear"], 0)) <= 0:
			_holding = {}
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	if _model and is_instance_valid(_model):
		_model.rotation.y = PI + sin(_t * 0.4) * 0.35          # facing you, turning a little to show the sides
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_hits = []
	_tip = ""
	var st = game.state
	var p := _person()
	# frame and the dark behind the stash
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(Pal.BRASS, 0.6), false, 1.0)
	var grad := _tex.size.x
	for i in 12:
		draw_rect(Rect2(grad - 12 + i, 0, 1, size.y), Color(0.04, 0.035, 0.03, i / 12.0))
	draw_rect(Rect2(grad, 0, size.x - grad, size.y), Color(0.04, 0.035, 0.03))
	if p.is_empty():
		_draw_msg()
		return
	var n_stats := _stats_text().split("\n").size()
	_tile(Rect2(Vector2(8, 34), Vector2(108, _info.size.y + 14 + n_stats * 10)), Color(LINE, 0.4), Color(0.04, 0.035, 0.03, 0.82))
	_draw_slots(st, p)
	_draw_portraits(st)
	_draw_stash(st, p)
	if _rig_open:
		_draw_rig(st, p)
	# their numbers, under who they are
	var sy := _info.position.y + _info.size.y + 6
	draw_line(Vector2(14, sy - 3), Vector2(110, sy - 3), Color(LINE, 0.4), 1.0)
	for ln in _stats_text().split("\n"):
		Pal.text(self, Vector2(14, sy), ln, 7, Pal.TEXT if not ln.begins_with(" ") else Pal.DIM, HORIZONTAL_ALIGNMENT_LEFT, 100)
		sy += 10
	# tip line (hovered tile) and messages
	var sr := _stash_rect()
	if _tip != "":
		Pal.wrap(self, Vector2(sr.position.x, sr.end.y + 4), _tip, 7, Pal.DIM, sr.size.x - 180, 2)
	_draw_msg()
	if not _holding.is_empty():
		var mp := get_local_mouse_position()
		_icon(str(_holding["gear"]), Rect2(mp + Vector2(6, 6), Vector2(22, 22)), Pal.GREEN)


func _draw_msg() -> void:
	if _msg_t > 0.0 or (_msg != "" and game.state.people.is_empty()):
		var w := Pal.font().get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16
		var r := Rect2(Vector2((_tex.size.x - w) * 0.5, size.y - 120), Vector2(w, 18))
		draw_rect(r, Color(0, 0, 0, 0.85))
		draw_rect(r, Pal.MULT, false, 1.0)
		Pal.text(self, r.position + Vector2(8, 4), _msg, 9, Pal.MULT)


## A tile with a cut corner (bible 17's slot frames).
func _tile(r: Rect2, col: Color, fill := Color(0.06, 0.06, 0.055, 0.9), w := 1.5) -> void:
	var k := 6.0
	var pts := PackedVector2Array([r.position, Vector2(r.end.x - k, r.position.y), Vector2(r.end.x, r.position.y + k), r.end, Vector2(r.position.x + k, r.end.y), Vector2(r.position.x, r.end.y - k)])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, col, w)


func _draw_slots(st, p: Dictionary) -> void:
	for slot in LEFT + RIGHT:
		var r := _slot_rect(slot)
		var it := Loadout.worn(st, p, slot)
		var hov := r.has_point(_hover)
		var on: bool = _filter == slot or (slot == "rig" and _rig_open)
		# the line: out of the tile, an elbow, to the body
		var a := _anchor(slot)
		var left := LEFT.has(slot)
		var s0 := Vector2(r.end.x if left else r.position.x, r.get_center().y)
		var s1 := s0 + Vector2(10 if left else -10, 0)
		var lc := Color(LINE, 0.9 if hov or on else 0.55)
		draw_line(s0, s1, lc, 1.0)
		draw_line(s1, a, lc, 1.0)
		draw_circle(a, 1.6, lc)
		_tile(r, Pal.AMBER if hov or on else LINE, Color(0.06, 0.06, 0.055, 0.92), 2.0 if on else 1.5)
		var icol := Color(0.85, 0.8, 0.68) if not it.is_empty() else Color(0.4, 0.36, 0.3)
		_icon(str(it.get("gear", "")) if not it.is_empty() else "slot_" + slot, r.grow(-6), icol)
		# label and what's in it
		var tx := r.position.x if left else r.position.x
		Pal.text(self, Vector2(tx, r.end.y + 1), SLOT_NAMES[slot], 6, Color(LINE, 0.85), HORIZONTAL_ALIGNMENT_CENTER, TILE)
		if not it.is_empty():
			var nm := str(it.get("name", ""))
			var nx := r.position.x - 34 if left else r.position.x - 34
			Pal.text(self, Vector2(nx, r.end.y + 8), nm, 6, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, TILE + 68)
			if int(it.get("stars", 0)) > 0:
				Pal.dots(self, Vector2(r.end.x - 2, r.position.y + 3), int(it["stars"]), int(it["stars"]), 1.5)
		if slot == "rig" and not it.is_empty():
			var gs := Loadout.grid_size(st, p)
			Pal.text(self, r.position + Vector2(2, 2), "%dx%d" % [gs.x, gs.y], 6, Pal.AMBER)
			if not Loadout.stick_of(st, p).is_empty():
				Pal.text(self, Vector2(r.position.x, r.end.y - 9), "USB", 6, Pal.GREEN, HORIZONTAL_ALIGNMENT_RIGHT, TILE - 3)
		if hov:
			_tip = "%s: %s.  Click: %s.  Right-click: take it off." % [SLOT_NAMES[slot], it.get("name", "empty") if not it.is_empty() else "empty",
				"open the rig grid" if slot == "rig" and not it.is_empty() else "show what fits"]
		_hits.append([r, "slot", slot])


func _draw_portraits(st) -> void:
	var people: Array = st.people
	var back := Rect2(Vector2(8, size.y - 68), Vector2(people.size() * 48 + 8, 60))
	_tile(back, Color(LINE, 0.5), Color(0.05, 0.045, 0.04, 0.85))
	for i in people.size():
		var q: Dictionary = people[i]
		var r := _portrait_rect(i)
		var alive: bool = q.get("alive", true)
		var head: String = str(Loadout.to_fighter(st, q).get("head", ""))
		Face.draw(self, r, str(q["name"]), head, not alive)
		var hov := r.has_point(_hover) and alive
		draw_rect(r, Pal.AMBER if i == sel else (Color(LINE, 0.9) if hov else Color(0.3, 0.27, 0.22)), false, 2.0 if i == sel else 1.0)
		var first := str(q["name"]).split(" ")[0]
		draw_rect(Rect2(r.position.x, r.end.y - 9, r.size.x, 9), Color(0, 0, 0, 0.7))
		Pal.text(self, Vector2(r.position.x, r.end.y - 9), first.substr(0, 7), 6, Pal.TEXT if alive else Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if not alive:
			Pal.text(self, r.position + Vector2(2, 2), "KIA", 7, Pal.MULT)
		elif int(q.get("injury_days", 0)) > 0:
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(18, 9)), Color(0, 0, 0, 0.75))
			Pal.text(self, r.position + Vector2(3, 2), "%dd" % int(q["injury_days"]), 6, Color(1.0, 0.5, 0.35))
		if alive and not Loadout.stick_of(st, q).is_empty():
			draw_rect(Rect2(Vector2(r.end.x - 20, r.position.y + 2), Vector2(18, 9)), Color(0, 0, 0, 0.75))
			Pal.text(self, Vector2(r.end.x - 20, r.position.y + 2), "USB", 6, Pal.GREEN, HORIZONTAL_ALIGNMENT_CENTER, 18)
		if alive:
			_hits.append([r, "person", i])
			if hov:
				_tip = "%s, %s. Tech %d.%s" % [q["name"], str(q.get("role", "")), int(q.get("tech", 0)), " Carries the drop stick." if not Loadout.stick_of(st, q).is_empty() else ""]


func _draw_stash(st, p: Dictionary) -> void:
	var sr := _stash_rect()
	_tile(sr, Color(LINE, 0.7), PANEL)
	draw_string(Pal.bold(), sr.position + Vector2(10, 16), "STASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.AMBER)
	draw_line(sr.position + Vector2(8, 21), Vector2(sr.end.x - 8, sr.position.y + 21), Color(LINE, 0.5), 1.0)
	var top := sr.position.y + 26
	if _filter != "":
		var fr := Rect2(Vector2(sr.position.x + 62, sr.position.y + 5), Vector2(64, 13))
		_tile(fr, Pal.AMBER, Color(0.15, 0.1, 0.05))
		Pal.text(self, fr.position + Vector2(0, 2), "%s  x" % SLOT_NAMES[_filter], 6, Pal.AMBER, HORIZONTAL_ALIGNMENT_CENTER, fr.size.x)
		_hits.append([fr, "clear_filter", null])
		if not Loadout.worn(st, p, _filter).is_empty():
			var tr := Rect2(Vector2(fr.end.x + 4, fr.position.y), Vector2(50, 13))
			_tile(tr, LINE, Color(0.12, 0.08, 0.05))
			Pal.text(self, tr.position + Vector2(0, 2), "take off", 6, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
			_hits.append([tr, "take_off", null])
	if _rig_open:
		top = _rig_rect().end.y + 8
	var entries := _stash_entries()
	var rows_fit := maxi(1, int((sr.end.y - top - 6) / SCELL))
	var rows := int(ceil(entries.size() / float(STASH_COLS)))
	_scroll = clampi(_scroll, 0, maxi(0, rows - rows_fit))
	var x0 := sr.position.x + 10
	for i in range(_scroll * STASH_COLS, mini(entries.size(), (_scroll + rows_fit) * STASH_COLS)):
		var k := i - _scroll * STASH_COLS
		var r := Rect2(Vector2(x0 + (k % STASH_COLS) * SCELL, top + int(k / STASH_COLS) * SCELL), Vector2(SCELL - 3, SCELL - 3))
		var e: Dictionary = entries[i]
		var hov := r.has_point(_hover)
		var held: bool = not _holding.is_empty() and str(_holding.get("gear", "")) == e["gear"] and (not e.has("item") or int(_holding.get("item", -1)) == int(e["item"]["id"]))
		draw_rect(r, Color(0.1, 0.1, 0.09) if not hov else Color(0.16, 0.14, 0.1))
		draw_rect(r, Pal.GREEN if held else (Pal.AMBER if hov else Color(LINE, 0.45)), false, 1.0)
		_icon(e["gear"], r.grow(-5), Color(0.82, 0.77, 0.65))
		if e["kind"] == "supply":
			Pal.text(self, Vector2(r.position.x, r.end.y - 9), "x%d" % int(e["count"]), 6, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2)
		elif e.has("item") and int(e["item"].get("stars", 0)) > 0:
			Pal.dots(self, Vector2(r.end.x - 2, r.position.y + 3), int(e["item"]["stars"]), int(e["item"]["stars"]), 1.3)
		if e["gear"] == "drop_stick":
			Pal.text(self, r.position + Vector2(2, 1), "USB", 6, Pal.GREEN)
		if hov:
			var nm: String = str(e["item"].get("name", "")) if e.has("item") else str(Loadout.gdef(e["gear"]).get("name", e["gear"]))
			var how := "click to wear (%s)" % SLOT_NAMES.get(e.get("slot", ""), "") if e["kind"] == "gear" else "click, then a rig cell, to pack"
			if e["gear"] == "drop_stick":
				how = "pack it in ONE fighter's rig (tech 1+): they plug into the vault PC"
			_tip = "%s: %s" % [nm, how]
		_hits.append([r, "stash", e])
	if entries.is_empty():
		Pal.wrap(self, Vector2(x0, top + 4), "Nothing here for this slot. Make it at a bench, buy it, or loot it." if _filter != "" else "The stash is empty.", 8, Pal.DIM, sr.size.x - 20)
	if rows > rows_fit:
		Pal.text(self, Vector2(sr.position.x, sr.end.y - 10), "wheel: more (%d/%d)" % [_scroll + rows_fit, rows], 6, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT, sr.size.x - 8)


func _draw_rig(st, p: Dictionary) -> void:
	var rr := _rig_rect()
	_tile(rr, Pal.AMBER, Color(0.09, 0.08, 0.06, 0.98), 2.0)
	var rig := Loadout.worn(st, p, "rig")
	Pal.text(self, rr.position + Vector2(6, 3), "RIG: " + str(rig.get("name", "")), 7, Pal.AMBER, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 24)
	var xr := Rect2(Vector2(rr.end.x - 14, rr.position.y + 2), Vector2(12, 12))
	Pal.text(self, xr.position, "x", 8, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 12)
	_hits.append([xr, "rig_close", null])
	var gs := Loadout.grid_size(st, p)
	var o := _grid_origin()
	for y in gs.y:
		for x in gs.x:
			var cr := Rect2(o + Vector2(x, y) * RCELL, Vector2(RCELL, RCELL))
			draw_rect(cr, Color(0.12, 0.13, 0.11))
			draw_rect(cr, Color(0.3, 0.32, 0.28), false, 1.0)
			_hits.append([cr, "cell", Vector2i(x, y)])
	for ge in p["grid"]:
		var c := Loadout.cells(ge["gear"])
		var gr := Rect2(o + Vector2(int(ge["x"]), int(ge["y"])) * RCELL + Vector2(1, 1), Vector2(c.x, c.y) * RCELL - Vector2(2, 2))
		var d := Loadout.gdef(ge["gear"])
		var col := Color(0.4, 0.36, 0.24)
		if d.has("med"):
			col = Color(0.5, 0.2, 0.17)
		elif d.has("flash") or d.has("charge"):
			col = Color(0.28, 0.3, 0.38)
		elif ge["gear"] == "drop_stick":
			col = Color(0.2, 0.42, 0.2)
		draw_rect(gr, col)
		draw_rect(gr, col.lightened(0.35), false, 1.0)
		_icon(ge["gear"], gr.grow(-2), Color(1, 1, 1, 0.85))
	# a ghost of what you hold
	if not _holding.is_empty():
		var g := Rect2(o, Vector2(gs) * RCELL)
		if g.has_point(_hover):
			var cx := int((_hover.x - o.x) / RCELL)
			var cy := int((_hover.y - o.y) / RCELL)
			var c := Loadout.cells(_holding["gear"])
			var ok := Loadout.fits(st, p, _holding["gear"], cx, cy)
			draw_rect(Rect2(o + Vector2(cx, cy) * RCELL, Vector2(c.x, c.y) * RCELL), Color(0.4, 1, 0.4, 0.35) if ok else Color(1, 0.3, 0.3, 0.35))
	var hint := "pick a cell" if not _holding.is_empty() else "right-click = take out"
	Pal.text(self, Vector2(rr.position.x + 6, rr.end.y - 12), hint, 6, Pal.DIM)
	var ar := Rect2(Vector2(rr.end.x - 58, rr.end.y - 15), Vector2(52, 12))
	_tile(ar, LINE, Color(0.15, 0.1, 0.05))
	Pal.text(self, ar.position + Vector2(0, 1), "auto-pack", 6, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, ar.size.x)
	_hits.push_front([ar, "auto", null])
	_hits.push_front([xr, "rig_close", null])


# ------------------------------------------------------------------ icons (line-art glyphs, bible 17)

func _icon(gid: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var w := r.size.x
	var h := r.size.y
	var lw := 1.5
	var kind := gid
	var d := Loadout.gdef(gid)
	if gid.begins_with("slot_"):
		kind = gid.substr(5)
		col = Color(col, 0.6)
	elif d.has("slot"):
		kind = str(d["slot"])
		if gid in ["cap", "beanie"]:
			kind = gid
	match kind:
		"primary":
			var y := c.y
			draw_rect(Rect2(r.position.x, y - h * 0.08, w * 0.95, h * 0.14), col)                 # body and barrel
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, y - h * 0.08), Vector2(r.position.x + w * 0.22, y - h * 0.02), Vector2(r.position.x + w * 0.2, y + h * 0.22), Vector2(r.position.x, y + h * 0.2)]), col)
			draw_rect(Rect2(r.position.x + w * 0.45, y + h * 0.05, w * 0.1, h * 0.25), col)    # mag
			draw_rect(Rect2(r.position.x + w * 0.32, y + h * 0.05, w * 0.07, h * 0.18), col)   # grip
		"sidearm":
			draw_rect(Rect2(c.x - w * 0.35, c.y - h * 0.2, w * 0.7, h * 0.18), col)
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.3, c.y - h * 0.02), Vector2(c.x - w * 0.08, c.y - h * 0.02), Vector2(c.x - w * 0.02, c.y + h * 0.32), Vector2(c.x - w * 0.24, c.y + h * 0.32)]), col)
		"head":
			draw_arc(Vector2(c.x, c.y + h * 0.12), w * 0.34, PI, TAU, 14, col, lw)
			draw_line(Vector2(c.x - w * 0.42, c.y + h * 0.12), Vector2(c.x + w * 0.42, c.y + h * 0.12), col, lw)
			draw_line(Vector2(c.x - w * 0.34, c.y + h * 0.12), Vector2(c.x - w * 0.34, c.y + h * 0.26), col, lw)
			draw_line(Vector2(c.x + w * 0.34, c.y + h * 0.12), Vector2(c.x + w * 0.34, c.y + h * 0.26), col, lw)
		"cap":
			draw_arc(Vector2(c.x, c.y + h * 0.1), w * 0.28, PI, TAU, 12, col, lw)
			draw_line(Vector2(c.x - w * 0.28, c.y + h * 0.1), Vector2(c.x + w * 0.45, c.y + h * 0.14), col, lw)
		"beanie":
			draw_arc(Vector2(c.x, c.y + h * 0.15), w * 0.3, PI, TAU, 12, col, lw)
			draw_rect(Rect2(c.x - w * 0.32, c.y + h * 0.1, w * 0.64, h * 0.14), col, false, lw)
			draw_circle(Vector2(c.x, c.y - h * 0.2), 2.0, col)
		"face":
			draw_arc(c, w * 0.34, 0, TAU, 16, col, lw)
			draw_circle(c + Vector2(-w * 0.13, -h * 0.08), w * 0.08, col)
			draw_circle(c + Vector2(w * 0.13, -h * 0.08), w * 0.08, col)
			draw_rect(Rect2(c.x - w * 0.1, c.y + h * 0.12, w * 0.2, h * 0.18), col)
		"clothes":
			var pts := PackedVector2Array([Vector2(c.x - w * 0.15, r.position.y + h * 0.1), Vector2(c.x - w * 0.45, r.position.y + h * 0.25), Vector2(c.x - w * 0.38, r.position.y + h * 0.45),
				Vector2(c.x - w * 0.26, r.position.y + h * 0.4), Vector2(c.x - w * 0.26, r.end.y - h * 0.08), Vector2(c.x + w * 0.26, r.end.y - h * 0.08), Vector2(c.x + w * 0.26, r.position.y + h * 0.4),
				Vector2(c.x + w * 0.38, r.position.y + h * 0.45), Vector2(c.x + w * 0.45, r.position.y + h * 0.25), Vector2(c.x + w * 0.15, r.position.y + h * 0.1)])
			pts.append(pts[0])
			draw_polyline(pts, col, lw)
			draw_line(Vector2(c.x, r.position.y + h * 0.18), Vector2(c.x, r.end.y - h * 0.08), col, 1.0)
		"rig":
			draw_rect(Rect2(c.x - w * 0.3, c.y - h * 0.32, w * 0.6, h * 0.66), col, false, lw)
			for k in 2:
				draw_rect(Rect2(c.x - w * 0.24 + k * w * 0.26, c.y + h * 0.0, w * 0.2, h * 0.24), col, false, 1.0)
			draw_line(Vector2(c.x - w * 0.12, c.y - h * 0.32), Vector2(c.x - w * 0.12, c.y - h * 0.45), col, lw)
			draw_line(Vector2(c.x + w * 0.12, c.y - h * 0.32), Vector2(c.x + w * 0.12, c.y - h * 0.45), col, lw)
		"plate":
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.3, c.y - h * 0.35), Vector2(c.x + w * 0.3, c.y - h * 0.35), Vector2(c.x + w * 0.3, c.y + h * 0.15), Vector2(c.x, c.y + h * 0.38), Vector2(c.x - w * 0.3, c.y + h * 0.15)]), Color(col, 0.35))
			draw_polyline(PackedVector2Array([Vector2(c.x - w * 0.3, c.y - h * 0.35), Vector2(c.x + w * 0.3, c.y - h * 0.35), Vector2(c.x + w * 0.3, c.y + h * 0.15), Vector2(c.x, c.y + h * 0.38), Vector2(c.x - w * 0.3, c.y + h * 0.15), Vector2(c.x - w * 0.3, c.y - h * 0.35)]), col, lw)
		"back":
			draw_rect(Rect2(c.x - w * 0.3, c.y - h * 0.25, w * 0.6, h * 0.62), col, false, lw)
			draw_rect(Rect2(c.x - w * 0.3, c.y - h * 0.25, w * 0.6, h * 0.22), col, false, lw)
			draw_rect(Rect2(c.x - w * 0.15, c.y + h * 0.12, w * 0.3, h * 0.16), col, false, 1.0)
			draw_arc(Vector2(c.x, c.y - h * 0.25), w * 0.12, PI, TAU, 8, col, lw)
		"clip_5", "shells", "mag_pistol":
			draw_rect(Rect2(c.x - w * 0.16, c.y - h * 0.3, w * 0.32, h * 0.6), col, false, lw)
			for k in 3:
				draw_line(Vector2(c.x - w * 0.1, c.y - h * 0.18 + k * h * 0.14), Vector2(c.x + w * 0.1, c.y - h * 0.18 + k * h * 0.14), col, 1.0)
		"mag_30":
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.14, c.y - h * 0.4), Vector2(c.x + w * 0.12, c.y - h * 0.4), Vector2(c.x + w * 0.22, c.y + h * 0.4), Vector2(c.x - w * 0.04, c.y + h * 0.4)]), Color(col, 0.5))
		"bandage", "dressing":
			draw_rect(Rect2(c.x - w * 0.1, c.y - h * 0.32, w * 0.2, h * 0.64), col)
			draw_rect(Rect2(c.x - w * 0.32, c.y - h * 0.1, w * 0.64, h * 0.2), col)
		"flash":
			draw_rect(Rect2(c.x - w * 0.15, c.y - h * 0.22, w * 0.3, h * 0.55), col, false, lw)
			draw_line(Vector2(c.x - w * 0.1, c.y - h * 0.3), Vector2(c.x + w * 0.2, c.y - h * 0.38), col, lw)
		"charge":
			draw_rect(Rect2(c.x - w * 0.22, c.y - h * 0.2, w * 0.44, h * 0.4), col, false, lw)
			draw_line(Vector2(c.x + w * 0.22, c.y), Vector2(c.x + w * 0.38, c.y - h * 0.3), col, 1.0)
		"drop_stick":
			draw_rect(Rect2(c.x - w * 0.14, c.y - h * 0.1, w * 0.28, h * 0.42), col)
			draw_rect(Rect2(c.x - w * 0.09, c.y - h * 0.3, w * 0.18, h * 0.2), col, false, 1.0)
		"picks":
			for k in 3:
				draw_line(Vector2(c.x - w * 0.3, c.y - h * 0.2 + k * h * 0.15), Vector2(c.x + w * 0.3, c.y - h * 0.2 + k * h * 0.15), col, 1.0)
				draw_line(Vector2(c.x + w * 0.3, c.y - h * 0.2 + k * h * 0.15), Vector2(c.x + w * 0.36, c.y - h * 0.26 + k * h * 0.15), col, 1.0)
		_:
			draw_rect(r.grow(-w * 0.2), col, false, lw)


# ------------------------------------------------------------------ send them

func _send() -> void:
	var st = game.state
	var team: Array = []
	var lock: int = DepotRun.locked_for(st)
	if lock > 0:
		_say("The depot is locked down after the last raid. %d more night%s." % [lock, "" if lock == 1 else "s"])
		game.deny()
		return
	for p in st.people:
		if Loadout.fit_for_duty(p) and team.size() < 4:
			team.append(p["id"])
	if team.is_empty():
		_say("Nobody fit to send. The hurt need time, or treatment.")
		game.deny()
		return
	var carrier := Loadout.stick_carrier(st)
	if carrier.is_empty() or not team.has(carrier["id"]):
		if not has_meta("warned_stick"):
			set_meta("warned_stick", true)
			_say("Nobody going carries a drop stick: the vault PC can't be hit. Send again to go anyway.")
			game.deny()
			return
	game.set_meta("op_team", team)
	game.goto("res://v2/combat/fight.tscn")


## The best med item in the stash (for treating the hurt between ops).
func _best_med() -> Dictionary:
	var best := {}
	var packed := {}
	for q in game.state.people:
		for e in q.get("grid", []):
			if e.has("item"):
				packed[int(e["item"])] = true
	for it in game.state.items:
		if it.get("type", "") == "med" and not it.has("on") and not packed.has(int(it.get("id", -1))):
			if best.is_empty() or int(it.get("stars", 0)) > int(best.get("stars", 0)):
				best = it
	return best
