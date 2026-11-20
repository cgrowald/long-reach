extends HBoxContainer
## Bottom-left operator cards: callsign, health bar, status. Click to select
## (Shift = add), double-click to follow.

var _units: Array = []
var _selection
var _cards: Array[Dictionary] = []


func setup(units: Array, selection) -> void:
	_units = units
	_selection = selection


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 8)
	for i in _units.size():
		_add_card(_units[i], i + 1)


func _add_card(u, number: int) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150.0, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.85)
	style.border_color = Color(1.0, 0.85, 0.2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)

	var name_label := Label.new()
	name_label.text = "%d  %s · %s" % [number, u.callsign, u.class_label]
	name_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_label)

	var bar := ProgressBar.new()
	bar.max_value = u.max_hp
	bar.value = u.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.85, 0.4)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bar.add_theme_stylebox_override("background", bg)
	vb.add_child(bar)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	vb.add_child(status)

	card.gui_input.connect(_on_card_input.bind(u))
	add_child(card)
	_cards.append({"unit": u, "style": style, "bar": bar, "fill": fill, "status": status, "card": card})


func _on_card_input(event: InputEvent, u) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or u.is_dead:
		return
	if mb.double_click:
		_selection.select_only(u)
		_selection.follow(u)
	elif mb.shift_pressed:
		_selection.toggle(u)
	else:
		_selection.select_only(u)


func _process(_delta: float) -> void:
	for c in _cards:
		var u = c["unit"]
		var bar: ProgressBar = c["bar"]
		bar.value = u.hp
		var fill: StyleBoxFlat = c["fill"]
		fill.bg_color = Color(0.9, 0.25, 0.2).lerp(Color(0.3, 0.85, 0.4), clampf(u.hp / u.max_hp, 0.0, 1.0))
		var kit: Array[String] = []
		for k in [["flashbang", "Flash"], ["frag", "Frag"], ["breach_charge", "Charge"]]:
			if u.items.has(k[0]):
				kit.append("%s %d" % [k[1], u.item_count(k[0])])
		(c["status"] as Label).text = "%s\n%s" % [u.get_status_text(), "   ".join(kit)]
		(c["style"] as StyleBoxFlat).set_border_width_all(2 if _selection.is_selected(u) else 0)
		(c["card"] as Control).modulate = Color(0.55, 0.55, 0.55) if u.is_dead else Color.WHITE
	position = Vector2(16.0, get_viewport_rect().size.y - size.y - 16.0)
