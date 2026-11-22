extends "res://v2/stations/station.gd"
## The war room (late game placeholder). Reached through the floor hatch or the PC once unlocked.
## A map table of the town's districts, your cells, send-away (XCOM-style) and a big op you watch.


func build() -> void:
	if not game.state.unlocked.has("hatch"):
		locked_panel()
		return
	var body := frame("THE WAR ROOM (placeholder)")
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var map := Control.new()
	map.custom_minimum_size = Vector2(250, 200)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.draw.connect(func() -> void: _draw_map(map))
	h.add_child(map)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 200
	h.add_child(right)
	right.add_child(Kit.label("CELLS", Pal.AMBER, 10))
	for sq in Content.world().get("squads", []):
		var s: Dictionary = sq
		var p := PanelContainer.new()
		right.add_child(p)
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(Kit.label("%s  %s" % [s["name"], "*".repeat(int(s.get("stars", 0)))], Pal.TEXT, 9))
		v.add_child(Kit.label(", ".join(PackedStringArray(s.get("people", []))), Pal.DIM, 8))
		v.add_child(Kit.button("Send away (3 days)", func() -> void:
			Menus.message(self, game, "Placeholder report:\n%s went to the depot.\nThey came back with nothing, because nothing is simulated yet." % s["name"], Callable(), "OP REPORT"), game))
	right.add_child(HSeparator.new())
	right.add_child(Kit.label("BIG OPS", Pal.AMBER, 10))
	right.add_child(Kit.button("Watch an op (combat prototype)", func() -> void:
		Menus.confirm(self, game, "Open the old combat prototype? It has no way back on its own: press F10 to return here.",
			func() -> void: game.run_external("res://tactical/watch/watch_main.tscn")), game))
	game.sfx.play("open_001", 0.7, -8.0)


func _draw_map(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.1, 0.12, 0.1))
	var names: Array = Content.world().get("districts", [])
	var cols := 3
	var cw := (r.size.x - 16) / cols
	var ch := (r.size.y - 16) / ceilf(names.size() / float(cols))
	for i in names.size():
		var cell := Rect2(Vector2(8 + (i % cols) * cw, 8 + (i / cols) * ch), Vector2(cw - 4, ch - 4))
		var ours := i == 0
		c.draw_rect(cell, Color(0.45, 0.15, 0.1, 0.6) if ours else Color(0.2, 0.24, 0.2))
		c.draw_rect(cell, Pal.METAL_L, false, 1.0)
		Pal.text(c, cell.position + Vector2(4, 4), str(names[i]), 8, Pal.TEXT)
		Pal.text(c, cell.position + Vector2(4, 16), "yours" if ours else "regime", 8, Pal.AMBER if ours else Pal.DIM)
	Pal.text(c, Vector2(8, r.end.y - 12), "the town turns your colour place by place", 8, Pal.DIM)
