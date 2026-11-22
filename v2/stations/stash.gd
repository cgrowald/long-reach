extends "res://v2/stations/station.gd"
## The shelves: your stash. Materials, tools, and everything you've made (with stars and perks).

const Crafting := preload("res://v2/sim/crafting.gd")


func build() -> void:
	var body := frame("THE STASH")
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 10)
	body.add_child(h)
	var st = game.state
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 150
	h.add_child(left)
	left.add_child(Kit.label("MATERIALS", Pal.AMBER, 10))
	var mats: Dictionary = Crafting.data().get("materials", {})
	for k in mats:
		var n := int(st.materials.get(k, 0))
		left.add_child(Kit.label("%-20s %d" % [Crafting.material_name(k), n], Pal.TEXT if n > 0 else Pal.DIM, 8))
	left.add_child(HSeparator.new())
	left.add_child(Kit.label("TOOLS", Pal.AMBER, 10))
	for t in st.tools:
		var td := Crafting.tool_def(t)
		left.add_child(Kit.label("%s  x%.2f" % [td.get("name", t), float(td.get("mult", 1.0))], Pal.TEXT, 8))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	right.add_child(Kit.label("MADE (%d)" % st.items.size(), Pal.AMBER, 10))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if st.items.is_empty():
		list.add_child(Kit.label("Nothing yet. Make something at a bench.", Pal.DIM, 8))
	for i in range(st.items.size() - 1, -1, -1):
		var it: Dictionary = st.items[i]
		var stars := "*".repeat(int(it.get("stars", 1)))
		var line := "%s  %s  %d%%%s" % [it.get("name", "?"), stars, int(float(it.get("quality", 0)) * 100.0), "" if it.get("hand", true) else "  (batch)"]
		if it.get("type", "") == "intel":
			line = "%s  [INTEL: %s, from %s]" % [it.get("name", "?"), it.get("tag", "?"), it.get("source", "?")]
		list.add_child(Kit.label(line, Pal.TEXT, 9))
		var extra: Array = []
		if it.has("grid"):
			extra.append("grid %dx%d, plates %s" % [int(it["grid"][0]), int(it["grid"][1]), it.get("plates", "none")])
		if it.has("heal"):
			extra.append("heals %d" % int(it["heal"]))
		if it.has("box_slot"):
			extra.append("plugs into the box: %s" % str(it["box_slot"]).to_upper())
		for p in it.get("perks", []):
			extra.append(str(p))
		if not extra.is_empty():
			list.add_child(Kit.label("   " + "; ".join(PackedStringArray(extra)), Pal.DIM, 8, 240))
	game.sfx.play("drop_002", 0.9, -10.0)
