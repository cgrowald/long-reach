extends "res://v2/stations/station.gd"
## A bench (docs/DRIVE.md section 3). Pick a recipe, then do it by hand in 3D on the bench top, step by step.
## The steps' scores x your tool x the material = quality -> stars, perks, (rig grid). Into the stash.
## After 3 good crafts a recipe can be batched at your average quality.

const Crafting := preload("res://v2/sim/crafting.gd")
const Materials := preload("res://v2/sim/materials.gd")
const Economy := preload("res://v2/sim/economy.gd")
const BenchWork := preload("res://v2/world/bench_work.gd")
const GarageWorld := preload("res://v2/world/garage_world.gd")
const Fx := preload("res://v2/ui/fx.gd")

var _grade := -1.0                # average material grade used for the craft in progress
var _list: Control
var _work                       # BenchWork while crafting
var _recipe: Dictionary = {}
var _step := 0
var _scores: Array = []
var _result: Control
var _t := 0.0


func build() -> void:
	if not game.state.is_unlocked(def):
		locked_panel()
		return
	_show_list()


# ------------------------------------------------------------------ the recipe list

func _show_list() -> void:
	if _list:
		_list.queue_free()
	_list = Control.new()
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	var pc := PanelContainer.new()
	pc.position = Vector2(10, 10)
	pc.custom_minimum_size = Vector2(230, 0)
	_list.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var bar := Kit.row(v)
	var t := Kit.label(def.get("name", "").to_upper(), Pal.PHOS, 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	bar.add_child(Kit.button("X", close, game))
	v.add_child(HSeparator.new())
	var st = game.state
	for r in Crafting.recipes_for(def.get("bench", "")):
		var rec: Dictionary = r
		var m := Crafting.mastery(st, rec["id"])
		var head := Kit.row(v)
		var name_l := Kit.label("%s  T%d" % [rec["name"], int(rec.get("tier", 1))], Pal.AMBER, 10)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		head.add_child(Kit.label("1 night action" if Economy.action_cost(float(rec.get("hours", 1.0))) > 0 else "free", Pal.DIM, 8))
		if not Crafting.unlocked(st, rec):
			var after := Crafting.recipe(rec.get("after", ""))
			v.add_child(Kit.label("Locked: make a good %s first (3 stars+)." % after.get("name", "?"), Pal.DIM, 8, 220))
			v.add_child(HSeparator.new())
			continue
		var needs: Array = []
		for k in rec.get("needs", {}):
			needs.append("%s %d/%d %s" % [Crafting.material_name(k), int(st.materials.get(k, 0)), int(rec["needs"][k]), Materials.stars(Materials.best(st, k))])
		var miss := Crafting.missing(st, rec)
		v.add_child(Kit.label(", ".join(PackedStringArray(needs)), Pal.MULT if not miss.is_empty() else Pal.TEXT, 8, 220))
		if miss.is_empty():
			var bg := Crafting.best_grade(st, rec)
			var gtxt := "Material %.1f stars: x%.2f" % [bg, Materials.grade_mult(bg)]
			var gbg: Dictionary = rec.get("grid_by_grade", {})
			if not gbg.is_empty() and gbg.has(str(clampi(int(round(bg)), 1, 5))):
				var gg: Array = gbg[str(clampi(int(round(bg)), 1, 5))]
				gtxt += "   rig grid %dx%d" % [int(gg[0]), int(gg[1])]
			v.add_child(Kit.label(gtxt, Pal.GREEN.darkened(0.2), 8, 220))
		var tool := Crafting.tool_def(rec.get("tool", "hands"))
		var avg := float(m["sum"]) / maxf(1.0, float(m["made"]))
		var mastery_text := "made %d, good %d/%d" % [int(m["made"]), int(m["good"]), Crafting.BATCH_AFTER]
		if int(m["made"]) > 0:
			mastery_text += ", avg %d%%" % int(avg * 100.0)
		v.add_child(Kit.label("%s x%.2f   %s" % [tool.get("name", "?"), Crafting.tool_mult(st, rec), mastery_text], Pal.DIM, 8, 220))
		var r2 := Kit.row(v)
		var make := Kit.button("Make by hand", func() -> void: _make(rec), game)
		make.disabled = not miss.is_empty()
		r2.add_child(make)
		if Crafting.can_batch(st, rec):
			var b := Kit.button("Batch", func() -> void: _batch(rec), game)
			b.disabled = not miss.is_empty()
			r2.add_child(b)
		v.add_child(HSeparator.new())
	v.add_child(Kit.label("Shelves (west wall) hold what you make. F1 > +materials.", Pal.DIM, 8, 220))


# ------------------------------------------------------------------ making it

func _make(r: Dictionary) -> void:
	if not garage.spend(float(r.get("hours", 1.0))):
		return
	_grade = Crafting.consume(game.state, r)
	_recipe = r
	_step = 0
	_scores.clear()
	_list.queue_free()
	_list = null
	var world = garage.world
	world.refocus(def["work_cam"], def["work_look"])
	_work = BenchWork.new()
	world.add_child(_work)
	_work.setup(world.camera, GarageWorld.b2g(def["work"]), GarageWorld.b2g(def["work_cam"]), r.get("piece", "metal"))
	_work.step_done.connect(_on_step_done)
	_work.popup.connect(_on_popup)
	garage.hands.track = true
	garage.hands.set_shown(true)
	game.clunk()
	_work.start_step(r["steps"][0])


func _on_step_done(score: float) -> void:
	_scores.append(score)
	_step += 1
	if _step < (_recipe["steps"] as Array).size():
		game.sfx.play("confirmation_002", 1.0 + _step * 0.1, -8.0)
		_work.start_step(_recipe["steps"][_step])
	else:
		_work.stop()
		_finish()


func _on_popup(text: String, world_pos: Vector3, good: bool) -> void:
	var cam: Camera3D = garage.world.camera
	if cam.is_position_behind(world_pos):
		return
	Fx.float_text(self, cam.unproject_position(world_pos), text, Pal.GREEN if good else Pal.MULT, 10)


func _finish() -> void:
	var f := Crafting.formula(game.state, _recipe, _scores, _grade)
	var item := Crafting.finish(game.state, _recipe, f["quality"], true, _grade)
	_show_result(item, f)


func _batch(r: Dictionary) -> void:
	if not garage.spend(float(r.get("hours", 1.0)) * 0.5):
		return
	var bg := Crafting.consume(game.state, r)
	var item := Crafting.batch(game.state, r, bg)
	game.sfx.play("confirmation_002", 0.9, -6.0)
	garage.toast("Batched: %s %s" % [item["name"], "*".repeat(int(item["stars"]))])
	_show_list()


## The Balatro moment: the formula rolls up, then the stars slam in one by one.
func _show_result(item: Dictionary, f: Dictionary) -> void:
	garage.hands.track = false
	_result = Control.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_result)
	var pc := PanelContainer.new()
	pc.position = Vector2(size.x - 220, 14)
	pc.custom_minimum_size = Vector2(206, 0)
	_result.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(Kit.label(_recipe["name"].to_upper(), Pal.PHOS, 11))
	var rows: Array = [
		["STEPS", f["steps"], Pal.CHIPS],
		["x TOOL", f["tool"], Pal.MULT],
		["x MATERIAL", f["material"], Pal.MULT],
		["= QUALITY", f["quality"], Pal.AMBER],
	]
	var labels: Array = []
	for row in rows:
		var h := Kit.row(v)
		var a := Kit.label(row[0], Pal.DIM, 9)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		var b := Kit.label("", row[2], 12)
		h.add_child(b)
		h.modulate.a = 0.0
		labels.append([h, b, float(row[1]), row[0] != "STEPS" and row[0] != "= QUALITY"])
	var stars_l := Kit.label("", Pal.AMBER, 18)
	v.add_child(stars_l)
	var info := VBoxContainer.new()
	info.modulate.a = 0.0
	v.add_child(info)
	for p in item.get("perks", []):
		info.add_child(Kit.label("+ " + str(p), Pal.GREEN, 8, 200))
	if item.has("grid"):
		info.add_child(Kit.label("Rig grid %dx%d, plates: %s" % [int(item["grid"][0]), int(item["grid"][1]), item.get("plates", "none")], Pal.TEXT, 8, 200))
		info.add_child(_grid_preview(item["grid"]))
	if item.has("heal"):
		info.add_child(Kit.label("Heals %d" % int(item["heal"]), Pal.TEXT, 8))
	if item.has("box_slot"):
		info.add_child(Kit.label("Plugs into the box (desk): %s slot" % str(item["box_slot"]).to_upper(), Pal.TEXT, 8, 200))
	var m := Crafting.mastery(game.state, _recipe["id"])
	info.add_child(Kit.label("Mastery: %d / %d good crafts%s" % [int(m["good"]), Crafting.BATCH_AFTER,
		"  (batching unlocked)" if Crafting.can_batch(game.state, _recipe) else ""], Pal.DIM, 8, 200))
	var r := Kit.row(info)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Into the stash", _done_result, game))
	# Animate (bound to the result panel, so closing it early stops the animation).
	var tw := _result.create_tween()
	for i in labels.size():
		var e: Array = labels[i]
		tw.tween_property(e[0], "modulate:a", 1.0, 0.1)
		tw.tween_method(func(x: float) -> void:
			e[1].text = ("x%.2f" % x) if e[3] else ("%d%%" % int(round(x * 100.0))), 0.0, e[2], 0.35)
		tw.tween_callback(func() -> void:
			game.sfx.play("tick_004", 1.0 + i * 0.15, -4.0)
			garage.shake(0.12))
	var n := int(item["stars"])
	for s in n:
		tw.tween_interval(0.16)
		tw.tween_callback(func() -> void:
			stars_l.text = "*".repeat(s + 1) + " ".repeat(5 - s - 1) + "  %d STAR%s" % [s + 1, "S" if s > 0 else ""]
			game.sfx.play("glass_002", 1.0 + s * 0.18, -2.0)
			garage.shake(0.15 + s * 0.08))
	tw.tween_property(info, "modulate:a", 1.0, 0.2)


func _grid_preview(g: Array) -> Control:
	var c := Control.new()
	var cols := int(g[0])
	var rows := int(g[1])
	c.custom_minimum_size = Vector2(cols * 12 + 2, rows * 12 + 2)
	c.draw.connect(func() -> void:
		for y in rows:
			for x in cols:
				c.draw_rect(Rect2(Vector2(1 + x * 12, 1 + y * 12), Vector2(11, 11)), Pal.METAL_D)
				c.draw_rect(Rect2(Vector2(1 + x * 12, 1 + y * 12), Vector2(11, 11)), Pal.METAL_L, false, 1.0))
	return c


func _done_result() -> void:
	if _result:
		_result.queue_free()
		_result = null
	_end_work()
	_show_list()


func _end_work() -> void:
	if _work:
		_work.queue_free()
		_work = null
	garage.hands.track = false
	garage.hands.set_shown(false)
	garage.world.refocus(def["cam"], def["look"])


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if _work == null or _result != null:
		return
	if event is InputEventMouseMotion:
		_work.pointer(event.position)
		garage.hands.cursor = event.position
		garage.world.set_cursor(size * 0.5, size)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_work.pointer(event.position)
		if event.pressed:
			_work.press()
		else:
			_work.release()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if _work and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_work.key_action()
		get_viewport().set_input_as_handled()


func back() -> bool:
	if _result:
		_done_result()
		return true
	if _work:
		Menus.confirm(self, game, "Stop working? The materials are already used.", func() -> void:
			_end_work()
			_show_list())
		return true
	return false


func close() -> void:
	if _work:
		_work.queue_free()
		_work = null
	garage.hands.track = false
	super.close()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The label and drag arrow for the "act here" marker (the ring itself is 3D, in bench_work).
func _draw_cue() -> void:
	var c: Dictionary = _work.cue()
	if c.is_empty():
		return
	var cam: Camera3D = garage.world.camera
	var p0: Vector3 = c["pos"]
	var wp: Vector3 = _work.to_global(p0)
	if cam.is_position_behind(wp):
		return
	var sp := cam.unproject_position(wp)
	var col := Color(1.0, 0.3, 0.85)
	if c.has("drag"):
		var ep := cam.unproject_position(_work.to_global(p0 + (c["drag"] as Vector3)))
		_arrow(sp, ep, col)
		if c.get("both", false):
			_arrow(sp, sp - (ep - sp), col)
	var text: String = c.get("text", "")
	if text == "":
		return
	var w := float(text.length()) * 5.0 + 8.0
	var pos := sp + Vector2(14, -26)
	pos.x = clampf(pos.x, 4.0, size.x - w - 4.0)
	draw_line(sp + Vector2(4, -6), pos + Vector2(0, 11), col, 1.0)
	draw_rect(Rect2(pos, Vector2(w, 13)), Color(0.05, 0.02, 0.05, 0.85))
	draw_rect(Rect2(pos, Vector2(w, 13)), col, false, 1.0)
	Pal.text(self, pos + Vector2(4, 1), text, 8, col)


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	if d.length() < 6.0:
		return
	var n := d.normalized()
	var phase := fmod(_t * 1.5, 1.0)            # a dash that runs along it, so it reads as motion
	draw_line(a + n * 6.0, b, Color(col, 0.5), 1.0)
	draw_circle(a + n * 6.0 + d * phase * 0.85, 1.5, col)
	var side := Vector2(-n.y, n.x)
	draw_colored_polygon(PackedVector2Array([b, b - n * 6.0 + side * 3.5, b - n * 6.0 - side * 3.5]), col)


# ------------------------------------------------------------------ step HUD

func _draw() -> void:
	if _work == null or _result != null or _work.verb == null:
		return
	var verb = _work.verb
	var steps: Array = _recipe["steps"]
	var s: Dictionary = steps[_step]
	var bar := Rect2(Vector2(10, 8), Vector2(size.x - 20, 34))
	draw_rect(bar, Color(0.04, 0.03, 0.04, 0.85))
	draw_rect(bar, Pal.METAL_L, false, 1.0)
	Pal.text(self, bar.position + Vector2(6, 3), "STEP %d/%d  %s" % [_step + 1, steps.size(), str(s.get("verb", "")).to_upper()], 10, Pal.AMBER)
	Pal.text(self, bar.position + Vector2(110, 3), str(s.get("text", "")), 10, Pal.TEXT)
	Pal.text(self, bar.position + Vector2(6, 18), verb.hint, 8, Pal.TEXT)
	_draw_cue()
	var prog: String = verb.progress()
	if prog != "":
		Pal.text(self, Vector2(bar.end.x - 60, bar.position.y + 18), prog, 8, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 54)
	# Step pips.
	for i in steps.size():
		var c := Vector2(bar.end.x - 12 - (steps.size() - 1 - i) * 12, bar.position.y + 9)
		Pal.lamp(self, c, 3.5, i <= _step, Pal.GREEN if i < _step else Pal.AMBER)
	var g: Dictionary = verb.gauge()
	if not g.is_empty():
		var gr := Rect2(Vector2(size.x - 30, 60), Vector2(14, 160))
		draw_rect(gr, Color(0.03, 0.03, 0.04, 0.9))
		var band: Vector2 = g["band"]
		var y0 := gr.end.y - gr.size.y * band.y
		draw_rect(Rect2(Vector2(gr.position.x, y0), Vector2(gr.size.x, gr.size.y * (band.y - band.x))), Color(0.3, 0.85, 0.35, 0.75))
		var v := clampf(float(g["value"]), 0.0, 1.0)
		var vy := gr.end.y - gr.size.y * v
		draw_rect(Rect2(Vector2(gr.position.x - 3, vy - 1), Vector2(gr.size.x + 6, 3)), Pal.TEXT)
		draw_rect(gr, Pal.METAL_L, false, 1.0)
		Pal.text(self, Vector2(gr.position.x - 30, gr.end.y + 4), str(g.get("label", "")), 8, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 44)
	Pal.text(self, Vector2(10, size.y - 14), "Esc: stop working", 8, Pal.DIM)
