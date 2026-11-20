extends Control
## The network board: the enemy organization as an org chart. The Emir on top, his four
## lieutenants under him, their cells below. Unknown people are silhouettes; intel fills
## in names and faces; the dead and captured are stamped. Click a card for details.

const WorldSim := preload("res://sim/world_sim.gd")
const Network := preload("res://sim/network.gd")
const Portrait := preload("res://people/portrait.gd")
const UiTheme := preload("res://world/ui_theme.gd")

const GOLD := Color(1.0, 0.82, 0.3)
const DIM := Color(0.62, 0.66, 0.7)
const RED := Color(0.95, 0.4, 0.35)
const BLUE := Color(0.5, 0.72, 1.0)
const DARK := Color(0.62, 0.5, 0.85)
const CARD := Vector2(262, 100)
const DETAIL_W := 380.0
const BRANCH_ORDER: Array[String] = ["finance", "operations", "recruitment", "logistics"]

var _campaign
var _net
var _board: Control
var _detail: VBoxContainer
var _cards: Dictionary = {}     # node id -> Control
var _selected: int = -1


func _ready() -> void:
	_campaign = get_node("/root/Campaign")
	_net = _campaign.world.network
	theme = UiTheme.make()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var back := Button.new()
	back.text = "<  MAP"
	back.custom_minimum_size = Vector2(110, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file(_campaign.MAP_SCENE))
	header.add_child(back)
	header.add_child(_label("THE NETWORK", 26, GOLD))
	header.add_child(_label("//  %s" % Network.org_name().to_upper(), 15, DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	header.add_child(_legend())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_board = Control.new()
	_board.draw.connect(_draw_links)
	scroll.add_child(_board)

	var dpanel := PanelContainer.new()
	dpanel.custom_minimum_size = Vector2(DETAIL_W, 0)
	dpanel.add_theme_stylebox_override("panel", _box(Color(0.09, 0.11, 0.14), Color(0.22, 0.26, 0.3)))
	body.add_child(dpanel)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dpanel.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_detail)

	_layout.call_deferred()
	_show_detail(-1)


# ---------------------------------------------------------------- layout

func _layout() -> void:
	for c in _board.get_children():
		c.queue_free()
	_cards.clear()
	var width: float = maxf(4.0 * (CARD.x + 16.0), get_viewport_rect().size.x - DETAIL_W - 60.0)
	var col_w: float = width / 4.0
	var leader: Dictionary = _net.leader()
	_place(leader, Vector2(width * 0.5 - CARD.x * 0.5, 8.0))
	var bottom: float = 0.0
	for i in BRANCH_ORDER.size():
		var b: String = BRANCH_ORDER[i]
		var x0: float = col_w * i + (col_w - CARD.x) * 0.5
		var title := _label(b.to_upper() + " BRANCH", 13, DIM)
		title.position = Vector2(x0, 130.0)
		_board.add_child(title)
		# Heads of the branch, past and present.
		var heads: Array = _net.nodes.filter(func(x): return int(x["tier"]) == 1 and str(x["branch"]) == b)
		heads.sort_custom(func(a, c): return Network.is_alive(a) and not Network.is_alive(c))
		var y: float = 156.0
		for j in heads.size():
			_place(heads[j], Vector2(x0, y + j * (CARD.y + 12.0)))
		y += heads.size() * (CARD.y + 12.0) + 24.0
		var cells: Array = _net.nodes.filter(func(x): return int(x["tier"]) == 2 and str(x["branch"]) == b)
		var shown: Array = cells.filter(func(x): return Network.is_suspected(x))
		shown.sort_custom(func(a, c): return _rank(a) > _rank(c))
		for j in shown.size():
			_place(shown[j], Vector2(x0, y + j * (CARD.y + 12.0)))
		y += shown.size() * (CARD.y + 12.0)
		var unknown: int = cells.size() - shown.size()
		var alive_unknown: int = cells.filter(func(x): return not Network.is_suspected(x) and Network.is_alive(x)).size()
		if unknown > 0:
			var u := _label("+ %d unidentified cell%s" % [alive_unknown, "" if alive_unknown == 1 else "s"], 13, DIM)
			u.position = Vector2(x0, y + 4.0)
			_board.add_child(u)
			y += 30.0
		bottom = maxf(bottom, y)
	_board.custom_minimum_size = Vector2(width, bottom + 20.0)
	_board.queue_redraw()


func _rank(x: Dictionary) -> float:
	if Network.is_located(x):
		return 300.0 + float(x["intel"])
	if Network.is_alive(x):
		return 200.0 + float(x["intel"])
	return float(x["intel"])


func _place(x: Dictionary, pos: Vector2) -> void:
	var card := _card(x)
	card.position = pos
	card.size = CARD
	card.custom_minimum_size = CARD
	card.clip_contents = true
	_board.add_child(card)
	_cards[int(x["id"])] = card


func _card(x: Dictionary) -> Control:
	var known: bool = Network.is_located(x) or not Network.is_alive(x)
	var panel := PanelContainer.new()
	var border: Color = _state_color(x)
	var sel: bool = int(x["id"]) == _selected
	var style := _box(Color(0.1, 0.12, 0.15) if not sel else Color(0.16, 0.17, 0.12), border, 2 if (sel or Network.is_located(x)) else 1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(int(x["id"])))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_face(x, 72.0))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var head: String = "'%s'" % x["alias"] if known else "UNIDENTIFIED"
	info.add_child(_label(head, 15, GOLD if Network.is_alive(x) and known else Color.WHITE))
	var role: String = str(x["title"]) if int(x["tier"]) < 2 else Network.type_name(str(x["type"]))
	info.add_child(_label(role, 12, DIM))
	if int(x["tier"]) == 2 or Network.is_suspected(x):
		info.add_child(_label(WorldSim.region_name(str(x["region"])), 12, Color.WHITE))
	else:
		info.add_child(_label("location unknown", 12, DIM))
	info.add_child(_label(_state_text(x), 12, border))
	return panel


func _face(x: Dictionary, size: float) -> Control:
	var known: bool = Network.is_located(x) or not Network.is_alive(x)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if known:
		var tr := TextureRect.new()
		tr.texture = Portrait.make(int(x["seed"]), not Network.is_alive(x))
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(size, size)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	else:
		var q := ColorRect.new()
		q.color = Color(0.15, 0.17, 0.2)
		q.size = Vector2(size, size)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(q)
		var l := _label("?", int(size * 0.55), Color(0.35, 0.38, 0.42))
		l.size = Vector2(size, size)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(l)
	if not Network.is_alive(x):
		var stamp := _label("KIA" if str(x["status"]) == "killed" else "CAPTURED", int(size * 0.2), RED if str(x["status"]) == "killed" else BLUE)
		stamp.size = Vector2(size, size)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.add_theme_color_override("font_outline_color", Color.BLACK)
		stamp.add_theme_constant_override("outline_size", 6)
		stamp.rotation = -0.3
		stamp.pivot_offset = Vector2(size, size) * 0.5
		holder.add_child(stamp)
	return holder


func _state_color(x: Dictionary) -> Color:
	match str(x["status"]):
		"killed":
			return RED
		"captured":
			return BLUE
		"dark":
			return DARK
	if Network.is_located(x):
		return GOLD
	return Color(0.42, 0.46, 0.5)


func _state_text(x: Dictionary) -> String:
	match str(x["status"]):
		"killed":
			return "KILLED"
		"captured":
			return "IN CUSTODY"
		"dark":
			return "GONE DARK  ·  intel %d%%" % int(x["intel"])
	if Network.is_located(x):
		return "LOCATED  ·  TARGETABLE"
	return "intel %d%%  ·  60%% locates" % int(x["intel"])


func _draw_links() -> void:
	for id in _cards:
		var x: Dictionary = _net.node(int(id))
		var a: Control = _cards[id]
		for lid in x["links"]:
			if int(lid) <= int(id) or not _cards.has(int(lid)):
				continue
			var y: Dictionary = _net.node(int(lid))
			var b: Control = _cards[int(lid)]
			var hier: bool = int(x["parent"]) == int(lid) or int(y["parent"]) == int(id)
			var col := Color(0.55, 0.6, 0.66, 0.5) if hier else Color(0.85, 0.65, 0.3, 0.45)
			if int(id) == _selected or int(lid) == _selected:
				col = Color(1.0, 0.85, 0.35, 0.95)
			var p0: Vector2 = a.position + CARD * 0.5
			var p1: Vector2 = b.position + CARD * 0.5
			if hier:
				_board.draw_line(p0, p1, col, 2.0, true)
			else:
				_board.draw_dashed_line(p0, p1, col, 1.5, 6.0, true, true)


# ---------------------------------------------------------------- detail panel

func _show_detail(id: int) -> void:
	var prev: int = _selected
	_selected = id
	if prev != id and is_inside_tree():
		_layout()
	for c in _detail.get_children():
		c.queue_free()
	var w = _campaign.world
	if id < 0:
		_detail.add_child(_label("HOW THE BOARD WORKS", 15, GOLD))
		for t in [
			"Every card is a person and the cell he runs. Lines are who knows whom: solid = chain of command, dashed = a contact.",
			"Intel grows while the carrier covers a region, when you raid there, and when you take down someone linked.",
			"At 25% intel a cell shows up here. At 60% he is LOCATED: you know his name, his face, where he sleeps. Only located people can be targeted.",
			"CAPTURE a target and interrogation fills in his contacts (a lot). KILL is a simpler raid but turns up less.",
			"Take down a lieutenant and his branch stalls until someone is promoted. Each one you capture brings you closer to the Emir.",
			"Raids make the cells around the target go dark for a while. Lieutenants' deaths are avenged.",
		]:
			_detail.add_child(_wrap(str(t), 13, DIM, DETAIL_W - 30.0))
		return
	var x: Dictionary = _net.node(id)
	var known: bool = Network.is_located(x) or not Network.is_alive(x)
	_detail.add_child(_face(x, 140.0))
	_detail.add_child(_label("'%s'" % x["alias"] if known else "UNIDENTIFIED", 22, GOLD))
	if known:
		_detail.add_child(_label(str(x["name"]), 16, Color.WHITE))
	var role: String = (str(x["title"]) + ", ") if str(x["title"]) != "" else ""
	_detail.add_child(_label("%s%s" % [role, Network.type_name(str(x["type"]))], 14, DIM))
	_detail.add_child(_label(_state_text(x), 14, _state_color(x)))
	if str(x.get("fate", "")) != "":
		_detail.add_child(_label(str(x["fate"]), 13, DIM))
	if Network.is_suspected(x) or int(x["tier"]) == 2:
		var city: String = (str(x["city"]) + ", ") if known else ""
		_detail.add_child(_label("Location: %s%s" % [city, WorldSim.region_name(str(x["region"]))], 14, Color.WHITE))
	else:
		_detail.add_child(_label("Location: unknown", 14, DIM))
	if Network.is_alive(x):
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = float(x["intel"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(DETAIL_W - 40.0, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOLD if Network.is_located(x) else Color(0.5, 0.6, 0.7)
		bar.add_theme_stylebox_override("fill", fill)
		_detail.add_child(bar)
		_detail.add_child(_label("Cell size %d / 3  ·  ~%d guards" % [int(x["size"]), _net.tangos_for(x)], 13, DIM))
	_detail.add_child(_wrap(str(Network.type_def(str(x["type"])).get("blurb", "")), 13, DIM, DETAIL_W - 30.0))
	var plotting: Array = w.plots.filter(func(p): return int(p.get("node", -1)) == id)
	for p in plotting:
		if w.plot_known(p, _campaign.has_global_intel()):
			_detail.add_child(_wrap("PLANNING AN ATTACK on %s in %d week%s." % [p["city"], int(p["weeks"]), "" if int(p["weeks"]) == 1 else "s"], 14, RED, DETAIL_W - 30.0))
	var contacts: Array = []
	for lid in x["links"]:
		var l: Dictionary = _net.node(int(lid))
		if not l.is_empty() and Network.is_suspected(l):
			contacts.append("'%s'" % l["alias"] if Network.is_located(l) or not Network.is_alive(l) else Network.label(l))
	if not contacts.is_empty():
		_detail.add_child(_label("KNOWN CONTACTS", 13, GOLD))
		_detail.add_child(_wrap(", ".join(contacts), 13, Color.WHITE, DETAIL_W - 30.0))

	if Network.is_located(x):
		if w.in_range(str(x["region"])):
			var b := Button.new()
			b.text = "PLAN AN OPERATION  >"
			b.custom_minimum_size = Vector2(0, 40)
			b.pressed.connect(func():
				_campaign.map_focus = str(x["region"])
				get_tree().change_scene_to_file(_campaign.MAP_SCENE))
			_detail.add_child(b)
		else:
			_detail.add_child(_wrap("Out of the carrier's reach. Sail toward %s to hit him." % WorldSim.region_name(str(x["region"])), 13, RED, DETAIL_W - 30.0))
	if Network.is_suspected(x) and Network.is_alive(x):
		var m := Button.new()
		m.text = "Show on map"
		m.pressed.connect(func():
			_campaign.map_focus = str(x["region"])
			get_tree().change_scene_to_file(_campaign.MAP_SCENE))
		_detail.add_child(m)


# ---------------------------------------------------------------- widgets

func _legend() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for pair in [["LOCATED", GOLD], ["SUSPECTED", Color(0.6, 0.64, 0.7)], ["GONE DARK", DARK], ["KILLED", RED], ["CAPTURED", BLUE]]:
		row.add_child(_label("■ " + str(pair[0]), 13, pair[1]))
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, font_size: int, color: Color, width: float) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _box(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s
