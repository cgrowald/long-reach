extends VBoxContainer
## Market (Approved): buy parts, tools and station kits from the town's shops, and grey goods
## from the lantern market once someone vouches for you. Registered items get noticed.

const T := preload("res://terminal/os_theme.gd")

var desk
var state
var _wallet: Label
var _search: LineEdit
var _cats: ItemList
var _cat_ids: Array = []
var _list: ItemList
var _ids: Array = []
var _detail: RichTextLabel
var _buy: Button
var _result: Label
var _show_inventory := false


func setup(d, st, arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	add_child(top)
	_wallet = T.label("", 16)
	_wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_wallet)
	_search = LineEdit.new()
	_search.placeholder_text = "search the approved catalog"
	_search.custom_minimum_size = Vector2(260, 0)
	_search.text_changed.connect(func(_t): _fill())
	top.add_child(_search)
	var inv := Button.new()
	inv.text = "My things"
	inv.toggle_mode = true
	inv.focus_mode = Control.FOCUS_NONE
	inv.toggled.connect(func(on):
		_show_inventory = on
		_fill())
	top.add_child(inv)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_cats = ItemList.new()
	_cats.custom_minimum_size = Vector2(170, 0)
	_cats.item_selected.connect(func(_i): _fill())
	body.add_child(_cats)
	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i): _show(i))
	body.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(0, 110)
	add_child(_detail)
	var row := HBoxContainer.new()
	add_child(row)
	_buy = Button.new()
	_buy.text = "Order"
	_buy.disabled = true
	_buy.pressed.connect(_order)
	row.add_child(_buy)
	_result = T.label("", 13, T.DIM)
	_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_result)
	_cat_ids = [""]
	_cats.add_item("All departments")
	var cats: Dictionary = state.os_data("market.json").get("categories", {})
	for c in cats:
		_cat_ids.append(c)
		_cats.add_item(str(cats[c]))
	_cats.select(0)
	if arg != null:
		_search.text = str(arg)
	state.changed.connect(_refresh_wallet)
	_refresh_wallet()
	_fill()


func _refresh_wallet() -> void:
	if is_inside_tree():
		_wallet.text = "Account balance: %d VM" % state.money


func _fill() -> void:
	_list.clear()
	_ids.clear()
	var cat: String = _cat_ids[_cats.get_selected_items()[0]] if not _cats.get_selected_items().is_empty() else ""
	var q := _search.text.strip_edges().to_lower()
	var cat_items: Dictionary = state.catalog()
	if _show_inventory:
		for id in state.inventory:
			_ids.append(id)
			_list.add_item("%s   x%d" % [state.item_name(id), int(state.inventory[id])])
		if _ids.is_empty():
			_list.add_item("(nothing yet)")
		return
	for id in cat_items:
		var it: Dictionary = cat_items[id]
		if cat != "" and str(it["cat"]) != cat:
			continue
		if q != "" and not str(it["name"]).to_lower().contains(q) and not str(id).contains(q):
			continue
		var tag := ""
		match str(it.get("legality", "legal")):
			"flagged":
				tag = "   [REGISTERED]"
			"illegal":
				tag = "   [GREY]"
		var avail: String = "" if state.can_buy(id) else "   - no seller you know"
		_ids.append(id)
		_list.add_item("%s   %d VM%s%s" % [it["name"], int(it["price"]), tag, avail])
		if not state.can_buy(id):
			_list.set_item_custom_fg_color(_list.item_count - 1, T.DIM)


func _show(i: int) -> void:
	if i >= _ids.size():
		return
	var id: String = _ids[i]
	var it: Dictionary = state.catalog().get(id, {})
	if it.is_empty():
		_detail.text = "[b]%s[/b]\nYou made this, or found it." % state.item_name(id)
		_buy.disabled = true
		return
	var sellers: Array = state.sellers(id)
	var leg: String = {"legal": "Legal.", "flagged": "[color=#a03020]Registered to your citizen number.[/color]", "illegal": "[color=#a03020]Not legal. Grey sellers only.[/color]"}.get(str(it.get("legality", "legal")), "")
	_detail.text = "[b]%s[/b]   %d VM\n%s\n%s\nSold by: %s" % [it["name"], int(it["price"]), it["desc"], leg,
		", ".join(sellers) if not sellers.is_empty() else "[color=#6b6b5f]nobody you know (yet)[/color]"]
	_buy.disabled = sellers.is_empty()


func _order() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty() or sel[0] >= _ids.size():
		return
	var msg: String = state.buy(_ids[sel[0]])
	_result.text = msg
	desk.sfx.play("chime" if msg.begins_with("PURCHASE") else "error", -12.0)
	_fill()
