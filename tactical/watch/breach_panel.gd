extends PanelContainer
## The breach plan: after "stack on this door", click your combo and execute.
## Door: open / kick / charge.  Grenade: none / flash / frag.  Entry order: click soldiers in order
## (1-4 keys too), e.g. 1-3-4-2.  Pie first or not.  Enter executes. Doctrine defaults are preset.

var main
var _brain
var _graph
var _door
var _who: Array = []
var method := "open"
var grenade := "none"
var pie := true
var order: Array = []

var _title: Label
var _state: Label
var _method_btns: Dictionary = {}
var _gren_btns: Dictionary = {}
var _order_row: HBoxContainer
var _order_label: Label
var _pie_box: CheckBox
var _exec: Button


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.07, 0.93)
	sb.border_color = Color(0.55, 0.9, 0.6)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = _lab("BREACH PLAN", 20, Color(0.6, 1.0, 0.65))
	v.add_child(_title)
	_state = _lab("", 14, Color(0.8, 0.8, 0.8))
	v.add_child(_state)
	v.add_child(_row("Door:", [["open", "Open"], ["kick", "Kick"], ["charge", "Breach charge"]], _method_btns, func(id): method = id))
	v.add_child(_row("Grenade:", [["none", "None"], ["flashbang", "Flashbang"], ["frag", "Frag"]], _gren_btns, func(id): grenade = id))
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 6)
	orow.add_child(_lab("Entry order:", 15, Color(0.9, 0.9, 0.9)))
	_order_row = HBoxContainer.new()
	_order_row.add_theme_constant_override("separation", 6)
	orow.add_child(_order_row)
	var reset := Button.new()
	reset.text = "Reset"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func():
		order.clear()
		refresh())
	orow.add_child(reset)
	v.add_child(orow)
	_order_label = _lab("", 15, Color(1.0, 0.85, 0.4))
	v.add_child(_order_label)
	_pie_box = CheckBox.new()
	_pie_box.text = "Slice the pie on the doorway first (skipped after a grenade)"
	_pie_box.focus_mode = Control.FOCUS_NONE
	_pie_box.button_pressed = true
	_pie_box.toggled.connect(func(on): pie = on)
	v.add_child(_pie_box)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	_exec = Button.new()
	_exec.text = "EXECUTE  (Enter)"
	_exec.custom_minimum_size = Vector2(200, 40)
	_exec.focus_mode = Control.FOCUS_NONE
	_exec.pressed.connect(_execute)
	brow.add_child(_exec)
	var cancel := Button.new()
	cancel.text = "Cancel (Esc)"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close)
	brow.add_child(cancel)
	v.add_child(brow)


func _row(title: String, opts: Array, store: Dictionary, on_pick: Callable) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	var t := _lab(title, 15, Color(0.9, 0.9, 0.9))
	t.custom_minimum_size = Vector2(96, 0)
	r.add_child(t)
	var group := ButtonGroup.new()
	for o in opts:
		var b := Button.new()
		b.text = o[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		var id: String = o[0]
		b.pressed.connect(func():
			on_pick.call(id)
			refresh())
		r.add_child(b)
		store[id] = b
	return r


## Show the panel for this door with doctrine defaults: open quietly, pie it, go in stack order.
func open_for(door, brain, who: Array, graph) -> void:
	_door = door
	_brain = brain
	_graph = graph
	_who = who
	method = "kick" if brain.loud else "open"
	grenade = "flashbang" if brain.loud else "none"
	pie = not brain.loud
	_pie_box.button_pressed = pie
	order = []
	for c in _order_row.get_children():
		c.queue_free()
	for u in who:
		var b := Button.new()
		b.text = u.callsign
		b.focus_mode = Control.FOCUS_NONE
		var unit = u
		b.pressed.connect(func(): _add(unit))
		_order_row.add_child(b)
	visible = true
	refresh()
	reset_size()
	position = Vector2((get_viewport().get_visible_rect().size.x - size.x) / 2, get_viewport().get_visible_rect().size.y - size.y - 50)


func close() -> void:
	visible = false


func _add(u) -> void:
	if order.has(u):
		order.erase(u)
	else:
		order.append(u)
	refresh()


## Keys while the panel is open: 1-4 add to the entry order, Backspace undoes, Enter executes.
func key(k: int) -> void:
	match k:
		KEY_ENTER, KEY_KP_ENTER:
			_execute()
		KEY_BACKSPACE:
			if not order.is_empty():
				order.pop_back()
				refresh()
		_:
			var i: int = k - KEY_1
			if i >= 0 and i < main.friendlies.size() and _who.has(main.friendlies[i]):
				_add(main.friendlies[i])


func refresh() -> void:
	if not visible or _door == null:
		return
	var n: Vector3 = _door.normal()
	var a: String = _graph.room(_graph.room_at(_door.center + n * 0.8))["name"]
	var b: String = _graph.room(_graph.room_at(_door.center - n * 0.8))["name"]
	_title.text = "BREACH PLAN  -  door between %s and %s" % [b, a]
	_state.text = "Stacked. Waiting for your plan." if _brain.stacked() else "They're stacking up. You can plan now; they go when you execute."
	for id in _method_btns:
		_method_btns[id].button_pressed = id == method
	var has_charge: bool = _who.any(func(u): return u.can_do("breach"))
	_method_btns["charge"].disabled = not has_charge
	_method_btns["charge"].tooltip_text = "" if has_charge else "Nobody on this stack carries a charge."
	for id in _gren_btns:
		_gren_btns[id].button_pressed = id == grenade
		if id != "none":
			_gren_btns[id].disabled = not _who.any(func(u): return u.can_do(id))
	var shown: Array = order.duplicate()
	for u in _who:
		if not shown.has(u) and not u.is_dead:
			shown.append(u)
	var parts: Array = []
	for i in shown.size():
		parts.append("%d %s%s" % [i + 1, shown[i].callsign, "" if order.has(shown[i]) else "?"])
	_order_label.text = "In:  " + "   ".join(parts) + ("" if order.size() == shown.size() else "    (? = not picked yet, goes in stack order)")
	for c in _order_row.get_children():
		var pos := -1
		for i in order.size():
			if order[i].callsign == c.text.split(" ")[c.text.split(" ").size() - 1]:
				pos = i
		c.modulate = Color(0.6, 1.0, 0.65) if pos >= 0 else Color.WHITE


func _execute() -> void:
	if _brain == null:
		return
	var full: Array = order.duplicate()
	for u in _who:
		if not full.has(u):
			full.append(u)
	main.execute_plan({"method": method, "grenade": grenade, "order": full, "pie": pie})
	close()


func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
