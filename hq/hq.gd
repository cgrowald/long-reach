extends Control
## HQ: your people. Roster cards, operator details and service record, memorial wall,
## recruiting, and picking the squad to deploy. Built in code (no hand-made layout).

const Portrait := preload("res://people/portrait.gd")
const GameData := preload("res://sim/game_data.gd")

const GOLD := Color(1.0, 0.82, 0.3)
const DIM := Color(0.62, 0.66, 0.7)
const OK_GREEN := Color(0.45, 0.9, 0.5)
const WOUND := Color(1.0, 0.6, 0.3)
const DEAD := Color(0.9, 0.35, 0.3)
const STAT_LABELS := {"marksmanship": "Marksmanship", "cqb": "Close quarters", "composure": "Composure", "endurance": "Endurance", "tradecraft": "Tradecraft"}

var _campaign
var _squad: Array[int] = []
var _focused: int = -1
var _tab: String = "roster"
var _confirm_new: bool = false

var _grid: GridContainer
var _detail: VBoxContainer
var _date_label: Label
var _squad_label: Label
var _deploy_btn: Button
var _new_btn: Button
var _roster_tab: Button
var _memorial_tab: Button


func _ready() -> void:
	_campaign = get_node("/root/Campaign")
	_build()
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_label("LONG REACH  ·  HQ", 26, GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_date_label = _label("", 18, Color.WHITE)
	header.add_child(_date_label)

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	_roster_tab = _button("ROSTER", func(): _set_tab("roster"))
	_memorial_tab = _button("MEMORIAL", func(): _set_tab("memorial"))
	tabs.add_child(_roster_tab)
	tabs.add_child(_memorial_tab)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	body.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(_grid)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.13, 0.16), Color(0.25, 0.3, 0.35)))
	body.add_child(right_panel)
	var right := ScrollContainer.new()
	right_panel.add_child(right)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	right.add_child(_detail)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	_squad_label = _label("", 16, Color.WHITE)
	footer.add_child(_squad_label)
	var fs := Control.new()
	fs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fs)
	footer.add_child(_button("Recruit", _on_recruit))
	_new_btn = _button("New campaign", _on_new_campaign)
	footer.add_child(_new_btn)
	_deploy_btn = _button("DEPLOY", _on_deploy)
	_deploy_btn.custom_minimum_size = Vector2(180, 44)
	_deploy_btn.add_theme_font_size_override("font_size", 20)
	footer.add_child(_deploy_btn)


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	var ro = _campaign.roster
	_date_label.text = "%s     ·     Operations run: %d     ·     Fallen: %d" % [ro.date_string(), ro.missions_run, ro.fallen().size()]
	_memorial_tab.text = "MEMORIAL (%d)" % ro.fallen().size()
	_roster_tab.disabled = _tab == "roster"
	_memorial_tab.disabled = _tab == "memorial"
	for c in _grid.get_children():
		c.queue_free()
	var people: Array = ro.living() if _tab == "roster" else ro.fallen()
	for r in people:
		_grid.add_child(_card(r))
	if people.is_empty():
		_grid.add_child(_label("No names on the wall. Keep it that way." if _tab == "memorial" else "No one left.", 16, DIM))
	_squad = _squad.filter(func(id): return ro.get_by_id(id) != null and ro.get_by_id(id).is_available())
	var names: Array = _squad.map(func(id): return ro.get_by_id(id).callsign)
	_squad_label.text = "Squad (%d/%d):  %s" % [_squad.size(), _campaign.SQUAD_SIZE, ", ".join(names) if not names.is_empty() else "click an operator, then Add to squad"]
	_deploy_btn.disabled = _squad.is_empty()
	_show_detail(_focused)


func _card(r) -> Control:
	var in_squad: bool = _squad.has(r.id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(390, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var border: Color = GOLD if in_squad else (Color(0.5, 0.7, 0.9) if r.id == _focused else Color(0.22, 0.26, 0.3))
	card.add_theme_stylebox_override("panel", _box(Color(0.11, 0.14, 0.17), border, 2 if (in_squad or r.id == _focused) else 1))
	card.gui_input.connect(func(e): _on_card_input(e, r.id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_portrait(r, 72))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(_label("\"%s\"%s" % [r.callsign, "   ★ SQUAD" if in_squad else ""], 18, GOLD if in_squad else Color.WHITE))
	col.add_child(_label("%s %s  ·  %s" % [r.first_name, r.last_name, r.class_name_label()], 14, Color.WHITE))
	col.add_child(_label("%s  ·  age %d" % [r.agency_name(), r.age(_campaign.roster.year())], 12, DIM))
	col.add_child(_status_label(r))
	col.add_child(_label("Operations %d  ·  Kills %d" % [r.missions, r.kills], 12, DIM))
	return card


func _status_label(r) -> Label:
	match r.status:
		"active":
			return _label("READY", 13, OK_GREEN)
		"recovering":
			return _label("RECOVERING · %d days" % r.recovery_days, 13, WOUND)
		"kia":
			return _label("KILLED IN ACTION · %s" % r.died_on, 13, DEAD)
	return _label(r.status, 13, DIM)


func _show_detail(id: int) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var r = _campaign.roster.get_by_id(id)
	if r == null:
		_detail.add_child(_label("Select an operator to see their file.", 16, DIM))
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_detail.add_child(top)
	top.add_child(_portrait(r, 128))
	var info := VBoxContainer.new()
	top.add_child(info)
	info.add_child(_label(r.full_name(), 20, GOLD))
	info.add_child(_label("%s  ·  age %d  ·  %s" % [r.class_name_label(), r.age(_campaign.roster.year()), r.hometown], 14, Color.WHITE))
	info.add_child(_label(r.agency_name(), 14, Color.WHITE))
	info.add_child(_label(str(GameData.agencies().get(r.agency, {}).get("blurb", "")), 12, DIM))
	info.add_child(_status_label(r))
	if r.status == "kia":
		info.add_child(_label("Fell during %s." % r.died_in, 13, DEAD))
	elif _tab == "roster":
		var in_squad: bool = _squad.has(r.id)
		var b := _button("Remove from squad" if in_squad else "Add to squad", func(): _toggle_squad(r.id))
		b.disabled = not in_squad and (not r.is_available() or _squad.size() >= _campaign.SQUAD_SIZE)
		info.add_child(b)

	_detail.add_child(_section("STATS"))
	for key in STAT_LABELS:
		var row := HBoxContainer.new()
		var name_l := _label(STAT_LABELS[key], 13, Color.WHITE)
		name_l.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_l)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = r.stat(key)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.85, 0.55, 0.25).lerp(Color(0.45, 0.85, 0.5), clampf((r.stat(key) - 30) / 50.0, 0.0, 1.0))
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.18, 0.2, 0.23)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		row.add_child(_label("  %d" % r.stat(key), 13, Color.WHITE))
		_detail.add_child(row)

	var traits_d: Dictionary = GameData.traits()
	_detail.add_child(_section("TRAITS"))
	if r.traits.is_empty():
		_detail.add_child(_label("None yet.", 13, DIM))
	for t in r.traits:
		var td: Dictionary = traits_d.get(t, {})
		_detail.add_child(_label("%s: %s" % [td.get("name", t), td.get("desc", "")], 13, DEAD if bool(td.get("negative", false)) else Color.WHITE))
	if not r.injuries.is_empty():
		_detail.add_child(_section("PERMANENT INJURIES"))
		var perm: Dictionary = GameData.injuries().get("permanent", {})
		for inj in r.injuries:
			_detail.add_child(_label("%s: %s" % [perm.get(inj, {}).get("name", inj), perm.get(inj, {}).get("desc", "")], 13, WOUND))

	_detail.add_child(_section("SERVICE RECORD"))
	for i in range(r.service_log.size() - 1, -1, -1):
		var l := _label(r.service_log[i], 13, Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		_detail.add_child(l)


# ---------------------------------------------------------------- actions

func _on_card_input(e: InputEvent, id: int) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_focused = id
		if (e as InputEventMouseButton).double_click and _tab == "roster":
			_toggle_squad(id)
			return
		_refresh()


func _toggle_squad(id: int) -> void:
	var r = _campaign.roster.get_by_id(id)
	if _squad.has(id):
		_squad.erase(id)
	elif r != null and r.is_available() and _squad.size() < _campaign.SQUAD_SIZE:
		_squad.append(id)
	_refresh()


func _set_tab(t: String) -> void:
	_tab = t
	_focused = -1
	_refresh()


func _on_recruit() -> void:
	var r = _campaign.recruit()
	if r != null:
		_focused = r.id
	_refresh()


func _on_new_campaign() -> void:
	if not _confirm_new:
		_confirm_new = true
		_new_btn.text = "Click again: erase everyone?"
		return
	_confirm_new = false
	_new_btn.text = "New campaign"
	_campaign.new_campaign()
	_squad.clear()
	_focused = -1
	_refresh()


func _on_deploy() -> void:
	if not _squad.is_empty():
		_campaign.deploy(_squad.duplicate())


# ---------------------------------------------------------------- widgets

func _portrait(r, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Portrait.make(r.portrait_seed, r.status == "kia")
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _section(text: String) -> Control:
	var l := _label(text, 14, GOLD)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 10)
	m.add_child(l)
	return m


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 36)
	b.pressed.connect(cb)
	return b


func _box(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s
