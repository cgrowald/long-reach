extends HBoxContainer
## Workshop Planner v0.1: your garage stations, what each can make, what's missing.
## Making is instant for now (the hands-on bench minigames come in step 3); it costs its hours.

const T := preload("res://terminal/os_theme.gd")

var desk
var state
var _stations: ItemList
var _st_ids: Array = []
var _recipes: ItemList
var _rc_ids: Array = []
var _detail: RichTextLabel
var _make: Button
var _buy_missing: Button
var _result: Label


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stations = ItemList.new()
	_stations.custom_minimum_size = Vector2(240, 0)
	_stations.item_selected.connect(func(_i): _fill_recipes())
	add_child(_stations)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	_recipes = ItemList.new()
	_recipes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recipes.item_selected.connect(func(i): _show(i))
	right.add_child(_recipes)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(0, 150)
	right.add_child(_detail)
	var row := HBoxContainer.new()
	right.add_child(row)
	_make = Button.new()
	_make.text = "Make it"
	_make.disabled = true
	_make.pressed.connect(_do_make)
	row.add_child(_make)
	_buy_missing = Button.new()
	_buy_missing.text = "Find missing parts on the Market"
	_buy_missing.disabled = true
	_buy_missing.pressed.connect(_find_missing)
	row.add_child(_buy_missing)
	_result = T.label("", 13, T.DIM)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_result)
	_fill_stations()


func _fill_stations() -> void:
	var keep := _stations.get_selected_items()
	_stations.clear()
	_st_ids.clear()
	var all: Dictionary = state.station_list()
	for id in all:
		var s: Dictionary = all[id]
		var open: bool = state.stations.has(id)
		_st_ids.append(id)
		_stations.add_item("%s   %s" % [s["name"], "OPEN" if open else "(no kit)"])
		if not open:
			_stations.set_item_custom_fg_color(_stations.item_count - 1, T.DIM)
	_stations.select(keep[0] if not keep.is_empty() else 0)
	_fill_recipes()


func _fill_recipes() -> void:
	_recipes.clear()
	_rc_ids.clear()
	var sid: String = _st_ids[_stations.get_selected_items()[0]] if not _stations.get_selected_items().is_empty() else "hacking"
	var s: Dictionary = state.station_list()[sid]
	var kit: String = str(s["kit"])
	var header := "[b]%s[/b]  -  %s\n" % [s["name"], s["blurb"]]
	if not state.stations.has(sid):
		header += "[color=#a03020]Not set up. Kit: %s (%d VM) on the Market.[/color]\n" % [state.item_name(kit), int(state.catalog().get(kit, {}).get("price", 0))]
	if sid == "hacking" and not state.jobs.is_empty():
		header += "Repair jobs waiting: " + ", ".join(state.jobs.map(func(j): return "%s (%d VM)" % [j["device"], int(j.get("pay", 0))]))
	_detail.text = header
	for r in state.recipes_for(sid):
		var stt: Dictionary = state.recipe_status(r["id"])
		_rc_ids.append(r["id"])
		var made: int = int(state.made.get(r["id"], 0))
		_recipes.add_item("%s   %dh%s%s" % [r["name"], int(r.get("hours", 1)), "   READY" if stt["ok"] else "", "   (made %d)" % made if made > 0 else ""])
		if not stt["ok"]:
			_recipes.set_item_custom_fg_color(_recipes.item_count - 1, T.DIM)
	_make.disabled = true
	_buy_missing.disabled = true


func _show(i: int) -> void:
	var id: String = _rc_ids[i]
	var r: Dictionary = state.os_data("stations.json")["recipes"][id]
	var stt: Dictionary = state.recipe_status(id)
	var parts: Array = []
	for p in r.get("parts", {}):
		parts.append("%s x%d (have %d)" % [state.item_name(p), int(r["parts"][p]), int(state.inventory.get(p, 0))])
	for tool in r.get("tools", []):
		parts.append("%s (tool, %s)" % [state.item_name(tool), "have" if int(state.inventory.get(tool, 0)) > 0 else "missing"])
	_detail.text = "[b]%s[/b]   %d hours of your night\n%s\nNeeds: %s\n%s" % [r["name"], int(r.get("hours", 1)), r.get("desc", ""),
		", ".join(parts) if not parts.is_empty() else "nothing",
		"[color=#3c7a3c]Ready.[/color] [color=#6b6b5f](Placeholder: the hands-on bench game comes in step 3.)[/color]" if stt["ok"] else "[color=#a03020]%s %s[/color]" % [stt["why"], ", ".join(stt["missing"])]]
	_make.disabled = not stt["ok"]
	_buy_missing.disabled = stt["missing"].is_empty()


func _do_make() -> void:
	var sel := _recipes.get_selected_items()
	if sel.is_empty():
		return
	var msg: String = state.make(_rc_ids[sel[0]])
	_result.text = msg
	desk.sfx.play("chime" if not msg.begins_with("CANNOT") else "error", -12.0)
	_fill_stations()


func _find_missing() -> void:
	var sel := _recipes.get_selected_items()
	if sel.is_empty():
		return
	var r: Dictionary = state.os_data("stations.json")["recipes"][_rc_ids[sel[0]]]
	for p in r.get("parts", {}):
		if int(state.inventory.get(p, 0)) < int(r["parts"][p]):
			desk.open_app("market", state.item_name(p).split(" ")[0])
			return
	for tool in r.get("tools", []):
		if int(state.inventory.get(tool, 0)) < 1:
			desk.open_app("market", state.item_name(tool).split(" ")[0])
			return
