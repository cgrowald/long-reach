extends "res://v2/stations/station.gd"
## The shelves: your stash. Materials (with grades), the day job, tools, and everything you have
## (made, bought, looted, stolen). Face-lift 2026-11-22: real columns, grade pips, type chips.

const Crafting := preload("res://v2/sim/crafting.gd")

const TYPE_COL := {"intel": Color(0.45, 0.72, 0.7), "gadget": Color(0.5, 0.85, 0.45), "device": Color(0.5, 0.85, 0.45),
	"rig": Color(0.86, 0.6, 0.26), "med": Color(0.9, 0.4, 0.35), "weapon": Color(0.75, 0.7, 0.62), "part": Color(0.75, 0.7, 0.62)}


func build() -> void:
	var body := frame("THE STASH")
	var cage_b := Kit.button("Gear cage >", func() -> void: garage.open_screen("cage"), game)
	add_child(cage_b)
	cage_b.position = Vector2(size.x - 150, 20)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var st = game.state
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 210
	h.add_child(left)
	left.add_child(Kit.heading("Materials"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 1)
	left.add_child(grid)
	var mats: Dictionary = Crafting.data().get("materials", {})
	for k in mats:
		var n := int(st.materials.get(k, 0))
		var col := Pal.TEXT if n > 0 else Pal.DIM
		var nl := Kit.label(Crafting.material_name(k), col, 8)
		nl.custom_minimum_size.x = 120
		grid.add_child(nl)
		var cl := Kit.label(str(n), col, 8)
		cl.custom_minimum_size.x = 16
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(cl)
		var best := 0
		var gs: Array = st.mat_grades.get(k, [0, 0, 0, 0, 0])
		for gi in 5:
			if int(gs[gi]) > 0:
				best = gi + 1
		grid.add_child(_pips(best, 5))
	var econ := load("res://v2/sim/economy.gd")
	var jd: Dictionary = econ.job_def(st.job)
	left.add_child(HSeparator.new())
	left.add_child(Kit.heading("Day job"))
	left.add_child(Kit.label(("%s, %s" % [jd.get("name", ""), jd.get("place", "")]) if not jd.is_empty() else "None.", Pal.TEXT, 8, 205))
	if not jd.is_empty():
		var jr := HBoxContainer.new()
		jr.add_child(Kit.label("Stock grades", Pal.DIM, 8))
		jr.add_child(_pips(int(st.job_grades[1]), 5, int(st.job_grades[0])))
		left.add_child(jr)
	left.add_child(Kit.label("Work suspicion: %d" % int(st.suspicion), Pal.MULT if st.suspicion >= 40.0 else Pal.DIM, 8))
	left.add_child(HSeparator.new())
	left.add_child(Kit.heading("Tools"))
	for t in st.tools:
		var td := Crafting.tool_def(t)
		var tr := HBoxContainer.new()
		var tl := Kit.label(str(td.get("name", t)), Pal.TEXT, 8)
		tl.custom_minimum_size.x = 150
		tr.add_child(tl)
		tr.add_child(Kit.label("x%.2f" % float(td.get("mult", 1.0)), Pal.GREEN if float(td.get("mult", 1.0)) > 1.0 else Pal.DIM, 8))
		left.add_child(tr)
	# everything you hold
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	right.add_child(Kit.heading("On the shelves (%d)" % st.items.size()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	if st.items.is_empty():
		list.add_child(Kit.label("Nothing yet. Make something at a bench.", Pal.DIM, 8))
	for i in range(st.items.size() - 1, -1, -1):
		list.add_child(_item_row(st.items[i]))
	game.sfx.play("drop_002", 0.9, -10.0)


func _item_row(it: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	row.add_child(top)
	var ty := str(it.get("type", "item"))
	var chip := Kit.label(ty.to_upper(), TYPE_COL.get(ty, Pal.DIM), 7)
	chip.custom_minimum_size.x = 52
	top.add_child(chip)
	var nl := Kit.label(str(it.get("name", "?")), Pal.TEXT, 9)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	if ty == "intel":
		top.add_child(Kit.label("%s, from %s" % [str(it.get("tag", "?")).to_upper(), it.get("source", "?")], Pal.DIM, 8))
	else:
		var q := int(float(it.get("quality", 0)) * 100.0)
		top.add_child(Kit.label("found" if q == 0 else ("%d%%%s" % [q, "" if it.get("hand", true) else " batch"]), Pal.DIM, 8))
		top.add_child(_pips(int(it.get("stars", 0)), 5))
	var extra: Array = []
	if it.has("grid"):
		extra.append("grid %dx%d, plates %s" % [int(it["grid"][0]), int(it["grid"][1]), it.get("plates", "none")])
	if it.has("heal"):
		extra.append("heals %d" % int(it["heal"]))
	if it.has("box_slot"):
		extra.append("plugs into the box: %s" % str(it["box_slot"]).to_upper())
	if it.get("device", "") == "drop_stick":
		extra.append("for on-site hacks (air-gapped places)")
	if ty == "intel" and it.get("worth", "") != "":
		extra.append(str(it["worth"]))
	for p in it.get("perks", []):
		extra.append(str(p))
	if not extra.is_empty():
		var el := Kit.label("; ".join(PackedStringArray(extra)), Pal.DIM, 8, 300)
		el.custom_minimum_size.x = 300
		var pad := HBoxContainer.new()
		var sp := Control.new()
		sp.custom_minimum_size.x = 56
		pad.add_child(sp)
		pad.add_child(el)
		row.add_child(pad)
	return row


## n amber pips out of `of` (from `lo` on they're half-lit: a range).
func _pips(n: int, of: int, lo := -1) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(of * 8 + 2, 10)
	c.draw.connect(func() -> void:
		for i in of:
			var col := Color(0.25, 0.18, 0.12)
			if i < n:
				col = Pal.BRASS if lo < 0 or i < lo else Color(Pal.BRASS, 0.5)
			c.draw_circle(Vector2(4 + i * 8, 5), 2.8, col))
	return c
