extends "res://v2/stations/station.gd"
## The gear cage (docs/RUNDOWN.md section 9): pick one of your people, put gear on them, pack their rig.
## They stand in 3D in the middle, turning slowly, wearing exactly what you gave them; the fight uses
## the same kit. Left: your people. Right: the slots, the rig grid, and what you can pack.
## Click a slot to change it. Click a supply, then a grid cell, to pack it. Right-click a packed thing to take it out.

const Loadout := preload("res://v2/sim/loadout.gd")
const Soldier := preload("res://v2/combat/soldier.gd")
const Rules := preload("res://v2/combat/rules.gd")
const SLOT_NAMES := {"primary": "PRIMARY", "sidearm": "SIDEARM", "head": "HEAD", "face": "FACE", "rig": "RIG",
	"plate": "PLATE", "back": "BACK", "clothes": "CLOTHES"}
const CELL := 13.0

var sel := 0
var _vp: SubViewport
var _stage: Node3D
var _model: Node3D
var _tex: TextureRect
var _people_box: VBoxContainer
var _slots_box: VBoxContainer
var _pack_box: VBoxContainer
var _picker: PanelContainer
var _stats_l: Label
var _msg := ""
var _msg_t := 0.0
var _holding := {}               # {gear, item} chosen to pack
var _grid_origin := Vector2.ZERO
var _t := 0.0


func build() -> void:
	var st = game.state
	var title := Kit.title_tag("The gear cage", 12)
	title.position = Vector2(12, 6)
	add_child(title)
	var back_b := Kit.button("< Shelves", func() -> void: garage.open_screen("stash"), game)
	add_child(back_b)
	back_b.position = Vector2(size.x - 150, 8)
	var x_b := Kit.button("X", close, game)
	add_child(x_b)
	x_b.position = Vector2(size.x - 28, 8)
	# your people
	_people_box = VBoxContainer.new()
	_people_box.position = Vector2(12, 34)
	_people_box.custom_minimum_size.x = 120
	add_child(_people_box)
	# the 3D stand
	_vp = SubViewport.new()
	_vp.size = Vector2i(150, 206)
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_make_stage()
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.position = Vector2(142, 40)
	_tex.size = Vector2(150, 206)
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_tex)
	# slots, grid, packing
	_slots_box = VBoxContainer.new()
	_slots_box.position = Vector2(304, 34)
	_slots_box.custom_minimum_size.x = 190
	_slots_box.add_theme_constant_override("separation", 1)
	add_child(_slots_box)
	_pack_box = VBoxContainer.new()
	_pack_box.position = Vector2(size.x - 138, 34)
	_pack_box.custom_minimum_size.x = 130
	_pack_box.add_theme_constant_override("separation", 1)
	add_child(_pack_box)
	_stats_l = Kit.label("", Pal.TEXT, 8, 300)
	_stats_l.position = Vector2(142, 252)
	add_child(_stats_l)
	var send := Kit.button("Send them: depot raid", _send, game)
	add_child(send)
	send.position = Vector2(size.x - 180, size.y - 28)
	if st.people.is_empty():
		_msg = "Nobody yet. (Older save: start a new game.)"
	_refresh()
	game.sfx.play("drop_002", 0.7, -8.0)


func _make_stage() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 2.6)
	cam.fov = 40.0
	_stage.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.05, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.42, 0.35)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_stage.add_child(env)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.6, 2.6, 1.2)
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 3.0
	lamp.spot_angle = 35.0
	lamp.shadow_enabled = true
	_stage.add_child(lamp)
	lamp.look_at(Vector3(0, 0.9, 0))
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3, 3)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.18, 0.16)
	floor_m.material_override = fm
	_stage.add_child(floor_m)
	# chain-link behind them: it's a cage
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.35, 0.36, 0.36)
	for i in 13:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 2.4, 0.012)
		bar.mesh = bm
		bar.material_override = wire
		bar.position = Vector3(-1.2 + i * 0.2, 1.2, -0.7)
		_stage.add_child(bar)


func _person() -> Dictionary:
	var people: Array = game.state.people
	if people.is_empty():
		return {}
	sel = clampi(sel, 0, people.size() - 1)
	return people[sel]


## A procedural face (v2/ui/face.gd) for one of your people, wearing what is on their head.
func _face_ctl(p: Dictionary, sz: Vector2) -> Control:
	var c := Control.new()
	c.custom_minimum_size = sz
	var head: String = str(load("res://v2/sim/loadout.gd").to_fighter(game.state, p).get("head", ""))
	var dead: bool = not p.get("alive", true)
	c.draw.connect(func() -> void:
		load("res://v2/ui/face.gd").draw(c, Rect2(Vector2.ZERO, sz), str(p["name"]), head, dead)
		c.draw_rect(Rect2(Vector2.ZERO, sz), Pal.DIM, false, 1.0))
	return c


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var st = game.state
	for c in _people_box.get_children():
		c.queue_free()
	_people_box.add_child(Kit.heading("Your people"))
	for i in st.people.size():
		var p: Dictionary = st.people[i]
		var b := Kit.button(("> " if i == sel else "  ") + str(p["name"]).split(" ")[0] + ("" if p.get("alive", true) else "  (KIA)") + ("  (hurt %dd)" % int(p.get("injury_days", 0)) if p.get("alive", true) and int(p.get("injury_days", 0)) > 0 else ""), func() -> void:
			sel = i
			_holding = {}
			_refresh(), game)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not p.get("alive", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_child(_face_ctl(p, Vector2(16, 18)))
		row.add_child(b)
		_people_box.add_child(row)
	var p := _person()
	if not p.is_empty():
		_people_box.add_child(_face_ctl(p, Vector2(44, 50)))
		_people_box.add_child(Kit.label(str(p.get("role", "")).to_upper() + "  " + str(p.get("trait", "")), Pal.AMBER, 8))
		var tech := int(p.get("tech", 0))
		var has_stick := not Loadout.stick_of(st, p).is_empty()
		_people_box.add_child(Kit.label("Tech %d%s" % [tech, "  STICK CARRIER" if has_stick else ("  (can carry the stick)" if tech >= 1 else "  (too low for a stick)")], Pal.GREEN if has_stick else Pal.DIM, 8, 120))
		var mot = p.get("motive", {})
		if mot is Dictionary and not mot.is_empty():
			_people_box.add_child(Kit.label("In it for: " + str(mot.get("name", "")), Pal.DIM, 8, 120))
		if int(p.get("injury_days", 0)) > 0:
			_people_box.add_child(Kit.label("HURT: %d days, %d health" % [int(p["injury_days"]), int(p.get("hp", 100))], Color(1.0, 0.5, 0.35), 8, 120))
			var med := _best_med()
			if not med.is_empty():
				_people_box.add_child(Kit.button("Treat (%s %s)" % [str(med.get("name", "")).split(" ")[0], "*".repeat(int(med.get("stars", 0)))], func() -> void:
					var off := Loadout.treat(game.state, p, med)
					_say("%d day%s off their recovery." % [off, "" if off == 1 else "s"])
					_refresh(), game))
		_people_box.add_child(Kit.label(str(p.get("line", "")), Pal.DIM, 8, 100))
		_people_box.add_child(Kit.label("Ops: %d" % int(p.get("ops", 0)), Pal.DIM, 8))
	# slots
	for c in _slots_box.get_children():
		c.queue_free()
	_slots_box.add_child(Kit.heading("Wearing  (click to change)"))
	if not p.is_empty():
		for slot in SLOT_NAMES:
			var it := Loadout.worn(st, p, slot)
			var nm: String = it.get("name", "-") if not it.is_empty() else "-"
			if not it.is_empty() and int(it.get("stars", 0)) > 0:
				nm += " " + "*".repeat(int(it["stars"]))
			var b := Kit.button("%-8s %s" % [SLOT_NAMES[slot], nm], func() -> void: _pick(slot), game)
			b.clip_text = true
			b.custom_minimum_size.x = 150
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 8)
			_slots_box.add_child(b)
	# what can be packed
	for c in _pack_box.get_children():
		c.queue_free()
	_pack_box.add_child(Kit.heading("Pack"))
	_pack_box.add_child(Kit.label("pick, then a cell", Pal.DIM, 7))
	for gid in st.supplies:
		var n := int(st.supplies[gid])
		if n <= 0:
			continue
		var d := Loadout.gdef(gid)
		var lab := "%s x%d" % [d.get("name", gid), n]
		var b := Kit.button(lab, func() -> void: _hold({"gear": gid}), game)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 8)
		if _holding.get("gear", "") == gid and not _holding.has("item"):
			b.add_theme_color_override("font_color", Pal.GREEN)
		_pack_box.add_child(b)
	for it in Loadout.packable_items(st):
		var item: Dictionary = it
		var b := Kit.button("%s %s" % [item["name"], "*".repeat(int(item.get("stars", 0)))], func() -> void: _hold({"gear": item["gear"], "item": int(item["id"])}), game)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 8)
		if int(_holding.get("item", -1)) == int(item["id"]):
			b.add_theme_color_override("font_color", Pal.GREEN)
		_pack_box.add_child(b)
	var auto := Kit.button("Auto-pack", _auto_pack, game)
	_pack_box.add_child(auto)
	_rebuild_model()
	_stats()
	queue_redraw()


func _rebuild_model() -> void:
	if _model and is_instance_valid(_model):
		_model.queue_free()
	var p := _person()
	if p.is_empty():
		return
	var def := Loadout.to_fighter(game.state, p)
	_model = Soldier.new()
	_stage.add_child(_model)
	_model.setup(def)
	_model.raised = 0.4
	_model.crouch = 0.0
	if _model.light:
		_model.light.visible = false


func _stats() -> void:
	var p := _person()
	if p.is_empty():
		_stats_l.text = ""
		return
	var def := Loadout.to_fighter(game.state, p)
	var s := Rules.stats(def["gear"], str(p.get("trait", "")))
	if not def["armed"]:
		_stats_l.text = "No gun. They'll follow and help (patch, zip-tie), but can't fight."
	else:
		_stats_l.text = "%s   acc %d  dmg %d  ready %.2fs\nmags %d  meds %d  flash %d   plate: %s" % [s["weapon"], int(float(s["acc"]) * 100.0), int(s["dmg"]),
			float(s["ads"]) + float(s.get("react", 0.5)), int(s["mags"]), int(s["meds"]), int(s["flash"]), s["plate_name"]]


# ------------------------------------------------------------------ slots

func _pick(slot: String) -> void:
	if _picker and is_instance_valid(_picker):
		_picker.queue_free()
	var st = game.state
	var p := _person()
	_picker = PanelContainer.new()
	add_child(_picker)
	_picker.position = Vector2(274, 40)
	var v := VBoxContainer.new()
	_picker.add_child(v)
	v.add_child(Kit.label(SLOT_NAMES[slot] + ": choose", Pal.AMBER, 9))
	v.add_child(Kit.button("(nothing)", func() -> void:
		Loadout.unequip(st, p, slot)
		_close_picker(), game))
	var opts := Loadout.options(st, slot)
	for it in opts:
		var item: Dictionary = it
		var d := Loadout.gdef(item["gear"])
		var b := Kit.button("%s %s" % [item["name"], "*".repeat(int(item.get("stars", 0)))], func() -> void:
			var why := Loadout.equip(st, p, item)
			if why != "":
				_say(why)
				game.deny()
			else:
				game.sfx.play("switch_002", 1.0, -8.0)
			_close_picker(), game)
		b.tooltip_text = str(d.get("blurb", ""))
		v.add_child(b)
	if opts.is_empty():
		v.add_child(Kit.label("Nothing in the stash for this. Make it at a bench, buy it, or loot it.", Pal.DIM, 8, 180))
	v.add_child(Kit.button("Cancel", _close_picker, game))


func _close_picker() -> void:
	if _picker and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null
	_refresh()


func _say(t: String) -> void:
	_msg = t
	_msg_t = 3.0


# ------------------------------------------------------------------ the rig grid

func _hold(h: Dictionary) -> void:
	_holding = h
	game.click()
	_refresh()


func _grid_rect() -> Rect2:
	var gs := Loadout.grid_size(game.state, _person()) if not _person().is_empty() else Vector2i.ZERO
	return Rect2(Vector2(304, 212), Vector2(gs.x, gs.y) * CELL)


func _auto_pack() -> void:
	var st = game.state
	var p := _person()
	if p.is_empty():
		return
	var def := Loadout.to_fighter(st, p)
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
	_refresh()


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	var st = game.state
	var p := _person()
	if p.is_empty():
		return
	var r := _grid_rect()
	if not r.has_point(e.position):
		return
	var cx := int((e.position.x - r.position.x) / CELL)
	var cy := int((e.position.y - r.position.y) / CELL)
	if e.button_index == MOUSE_BUTTON_RIGHT:
		for i in p["grid"].size():
			var ge: Dictionary = p["grid"][i]
			var c := Loadout.cells(ge["gear"])
			if Rect2i(int(ge["x"]), int(ge["y"]), c.x, c.y).has_point(Vector2i(cx, cy)):
				Loadout.unpack(st, p, i)
				game.sfx.play("drop_002", 1.3, -10.0)
				_refresh()
				break
		accept_event()
	elif e.button_index == MOUSE_BUTTON_LEFT and not _holding.is_empty():
		var why := Loadout.pack(st, p, _holding["gear"], cx, cy, int(_holding.get("item", -1)))
		if why != "":
			_say(why)
			game.deny()
		else:
			game.sfx.play("switch_002", 1.2, -8.0)
			if _holding.has("item") or int(st.supplies.get(_holding["gear"], 0)) <= 0:
				_holding = {}
		_refresh()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	if _model and is_instance_valid(_model):
		_model.rotation.y = PI + sin(_t * 0.5) * 0.8          # facing you, turning to show the sides
	queue_redraw()


func _draw() -> void:
	var st = game.state
	var p := _person()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.045, 0.035, 0.95))
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Pal.BRASS, false, 1.0)
	Pal.brackets(self, Rect2(_tex.position - Vector2(3, 3), _tex.size + Vector2(6, 6)), Pal.AMBER, 8.0, 2.0)
	if not p.is_empty():
		Pal.text(self, Vector2(142, 26), str(p["name"]).to_upper(), 9, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 150)
	# the rig grid
	var r := _grid_rect()
	Pal.text(self, Vector2(304, 200), "RIG GRID" + ("  (no rig: they carry only what's loaded)" if r.size.x == 0 else "  right-click = take out"), 8, Pal.DIM)
	if r.size.x > 0 and not p.is_empty():
		var gs := Loadout.grid_size(st, p)
		for y in gs.y:
			for x in gs.x:
				var cr := Rect2(r.position + Vector2(x, y) * CELL, Vector2(CELL, CELL))
				draw_rect(cr, Color(0.12, 0.13, 0.11))
				draw_rect(cr, Color(0.3, 0.32, 0.28), false, 1.0)
		for ge in p["grid"]:
			var c := Loadout.cells(ge["gear"])
			var gr := Rect2(r.position + Vector2(int(ge["x"]), int(ge["y"])) * CELL + Vector2(1, 1), Vector2(c.x, c.y) * CELL - Vector2(2, 2))
			var d := Loadout.gdef(ge["gear"])
			var col := Color(0.45, 0.4, 0.25)
			if d.has("med"):
				col = Color(0.55, 0.2, 0.18)
			elif d.has("flash") or d.has("charge"):
				col = Color(0.3, 0.32, 0.4)
			draw_rect(gr, col)
			draw_rect(gr, col.lightened(0.3), false, 1.0)
			Pal.text(self, gr.position + Vector2(1, 1), _abbr(ge["gear"]), 8, Color(1, 1, 1, 0.9))
		# ghost of what you're holding
		if not _holding.is_empty():
			var mp := get_local_mouse_position()
			if r.has_point(mp):
				var cx := int((mp.x - r.position.x) / CELL)
				var cy := int((mp.y - r.position.y) / CELL)
				var c := Loadout.cells(_holding["gear"])
				var ok := Loadout.fits(st, p, _holding["gear"], cx, cy)
				draw_rect(Rect2(r.position + Vector2(cx, cy) * CELL, Vector2(c.x, c.y) * CELL), Color(0.4, 1, 0.4, 0.35) if ok else Color(1, 0.3, 0.3, 0.35))
	if _msg_t > 0.0 or (_msg != "" and st.people.is_empty()):
		Pal.text(self, Vector2(12, size.y - 20), _msg, 9, Pal.MULT)


func _abbr(gid: String) -> String:
	var a: String = {"clip_5": "CL", "shells": "SH", "mag_30": "MAG", "mag_pistol": "PM", "bandage": "+", "dressing": "++", "flash": "FL", "charge": "CH", "drop_stick": "USB"}.get(gid, "?")
	return a


# ------------------------------------------------------------------ send them

func _send() -> void:
	var st = game.state
	var team: Array = []
	var lock: int = load("res://v2/sim/depot_run.gd").locked_for(st)
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
