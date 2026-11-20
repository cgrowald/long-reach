extends Control
## The main campaign screen: the world map, the carrier, this week's briefing and the
## operation to run. One operation per week; the squad is picked at HQ.

const MapView := preload("res://world/map_view.gd")
const WorldSim := preload("res://sim/world_sim.gd")
const Research := preload("res://people/research.gd")
const UiTheme := preload("res://world/ui_theme.gd")
const Network := preload("res://sim/network.gd")
const Portrait := preload("res://people/portrait.gd")

const GOLD := Color(1.0, 0.82, 0.3)
const DIM := Color(0.62, 0.66, 0.7)
const RED := Color(0.95, 0.4, 0.35)
const OK_GREEN := Color(0.45, 0.9, 0.5)
const MAP_SIZE := Vector2(0, 515)
const COL_W := 470.0

var _campaign
var _map: MapView
var _date_label: Label
var _threat_bar: ProgressBar
var _threat_label: Label
var _panel: VBoxContainer
var _brief: VBoxContainer
var _ops: VBoxContainer
var _hq_btn: Button
var _end_btn: Button
var _confirm_end: bool = false
var _notice: String = ""


func _ready() -> void:
	_campaign = get_node("/root/Campaign")
	if _campaign.world.outcome != "":
		get_tree().change_scene_to_file.call_deferred(_campaign.END_SCENE)
		return
	theme = UiTheme.make()
	_build()
	_map.world = _campaign.world
	if not _campaign.current_op.is_empty():
		_map.selected_region = str(_campaign.current_op["region"])
	if _campaign.map_focus != "":
		_map.selected_region = _campaign.map_focus
		_map.focus_region.call_deferred(_campaign.map_focus)
		_campaign.map_focus = ""
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.09)
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

	# Header: title, date/funding, threat, buttons.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	header.add_child(_label("LONG REACH", 26, GOLD))
	_date_label = _label("", 16, Color.WHITE)
	header.add_child(_date_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	header.add_child(_label("THREAT", 14, DIM))
	_threat_bar = ProgressBar.new()
	_threat_bar.max_value = 100
	_threat_bar.show_percentage = false
	_threat_bar.custom_minimum_size = Vector2(160, 14)
	_threat_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.18, 0.2, 0.23)
	_threat_bar.add_theme_stylebox_override("background", bgs)
	header.add_child(_threat_bar)
	_threat_label = _label("", 15, Color.WHITE)
	header.add_child(_threat_label)
	var net_btn := _button("NETWORK", func(): get_tree().change_scene_to_file(_campaign.NETWORK_SCENE))
	net_btn.custom_minimum_size = Vector2(130, 40)
	header.add_child(net_btn)
	_hq_btn = _button("HQ", _go_hq)
	header.add_child(_hq_btn)
	_end_btn = _button("END WEEK", _on_end_week)
	_end_btn.custom_minimum_size = Vector2(170, 40)
	header.add_child(_end_btn)

	_map = MapView.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.region_clicked.connect(_on_region_clicked)
	_map.zone_clicked.connect(_on_zone_clicked)
	root.add_child(_map)

	# Under the map: briefing | selected region or zone | operations.
	var bottom := HBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	_brief = _column(bottom, Color(0.08, 0.1, 0.13))
	_panel = _column(bottom, Color(0.1, 0.13, 0.16))
	_ops = _column(bottom, Color(0.08, 0.1, 0.13))


func _column(parent: Control, bg: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(bg, Color(0.22, 0.26, 0.3)))
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	scroll.add_child(col)
	return col


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	var ro = _campaign.roster
	var w = _campaign.world
	_map.global_intel = _campaign.has_global_intel()
	_map.planned_region = str(_campaign.current_op.get("region", ""))
	_map.planned_city = str(_campaign.current_op.get("city", ""))
	_map.refresh()
	_date_label.text = "%s  ·  week %d  ·  Funding %s" % [
		ro.date_string(), w.week + 1, _money(ro.funding)]
	_threat_bar.value = w.threat
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.75, 0.3).lerp(Color(0.9, 0.25, 0.2), w.threat / 100.0)
	_threat_bar.add_theme_stylebox_override("fill", fill)
	_threat_label.text = "%s (%d)" % [w.threat_label(), int(w.threat)]
	var planned: bool = not _campaign.current_op.is_empty()
	_hq_btn.text = "HQ: PICK SQUAD  >" if planned else "HQ"
	if not _confirm_end:
		_end_btn.text = "END WEEK"
	_build_brief()
	_build_panel()


func _build_brief() -> void:
	_clear(_brief)
	var w = _campaign.world
	var gi: bool = _campaign.has_global_intel()
	if _notice != "":
		_brief.add_child(_wrap(_notice, 15, GOLD, COL_W))
	_brief.add_child(_label("THIS WEEK'S BRIEFING", 14, DIM))
	for line in w.news:
		var s: String = str(line)
		var col: Color = Color.WHITE
		if s.begins_with("ATTACK") or s.begins_with("WASHINGTON"):
			col = RED
		elif s.begins_with("LOCATED") or s.begins_with("NEW LEAD"):
			col = GOLD
		_brief.add_child(_wrap("·  " + s, 14, col, COL_W))
	var known: Array = w.plots.filter(func(p): return w.plot_known(p, gi))
	if not known.is_empty():
		_brief.add_child(_label("KNOWN ATTACK PLOTS", 14, DIM))
		for p in known:
			var src: String = w.plot_source(p)
			_brief.add_child(_wrap("·  %s, %s: %d week%s until it happens.%s" % [p["city"], WorldSim.region_name(str(p["region"])), int(p["weeks"]), "" if int(p["weeks"]) == 1 else "s", ("  Behind it: " + src + ".") if src != "" else ""], 14, RED, COL_W))
	var hidden: int = w.plots.size() - known.size()
	if hidden > 0:
		_brief.add_child(_wrap("·  Chatter suggests %d more plot%s we can't place. Build intel: carrier coverage, raids, captures." % [hidden, "" if hidden == 1 else "s"], 14, DIM, COL_W))


func _build_panel() -> void:
	_clear(_panel)
	_clear(_ops)
	var w = _campaign.world
	if _map.selected_zone != "":
		_zone_panel(_map.selected_zone)
	elif _map.selected_region != "":
		_region_panel(_map.selected_region)
	else:
		_overview_panel()

	var op: Dictionary = _campaign.current_op
	if not op.is_empty():
		_ops.add_child(_label("THIS WEEK'S OPERATION", 14, GOLD))
		_ops.add_child(_wrap("%s: %s, %s" % [op.get("name", ""), op.get("title", ""), op.get("city", "")], 16, Color.WHITE, COL_W))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var go := _button("Pick squad at HQ  >", _go_hq)
		go.custom_minimum_size = Vector2(220, 36)
		row.add_child(go)
		row.add_child(_button("Cancel", func():
			_campaign.cancel_operation()
			_refresh()))
		_ops.add_child(row)
	_ops.add_child(_section("TARGETS IN RANGE"))
	var ops: Array = w.operations_in_range(_campaign.has_global_intel())
	var named: Array = ops.filter(func(o): return str(o["kind"]) != "safehouse")
	if named.is_empty():
		_ops.add_child(_wrap("No located targets in the carrier's reach yet. Keep the carrier on station to build intel, raid a suspected safehouse to turn up leads, or sail toward the leads you have.", 14, DIM, COL_W))
	for o in named:
		var what: String
		if str(o["kind"]) == "plot":
			what = "STOP ATTACK in %s (%d wk)" % [o["city"], int(o["weeks"])]
		else:
			var x: Dictionary = w.network.node(int(o["node"]))
			what = "'%s'  ·  %s%s" % [o["hvt"]["alias"], Network.type_name(str(x["type"])), ("  ·  " + str(x["title"]).to_upper()) if int(x["tier"]) < 2 else ""]
		var b := _button("%s  ·  %s" % [what, WorldSim.region_name(str(o["region"]))], _select_region.bind(str(o["region"])))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(COL_W, 30)
		if str(o["kind"]) == "plot":
			b.add_theme_color_override("font_color", RED)
		_ops.add_child(b)
	var blind: Array = ops.filter(func(o): return str(o["kind"]) == "safehouse")
	if not blind.is_empty():
		_ops.add_child(_section("SUSPECTED PRESENCE (blind raids)"))
		for o in blind:
			var b := _button("%s  ·  strength %d" % [WorldSim.region_name(str(o["region"])), int(o["strength"])], _select_region.bind(str(o["region"])))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(COL_W, 28)
			_ops.add_child(b)


func _select_region(r: String) -> void:
	_map.selected_zone = ""
	_map.selected_region = r
	_map.focus_region(r)
	_refresh()


func _region_panel(r: String) -> void:
	var w = _campaign.world
	var net = w.network
	var reg: Dictionary = WorldSim.region(r)
	var th: Dictionary = WorldSim.theater_of(r)
	var s: int = int(w.strength.get(r, 0))
	_panel.add_child(_label(str(reg.get("name", r)), 20, GOLD))
	_panel.add_child(_wrap("%s theater: %s" % [th.get("name", ""), th.get("roe", "")], 13, DIM, COL_W))
	var status: String = ("Enemy strength %d / 5" % s) if s > 0 else "No known enemy presence"
	_panel.add_child(_label(status + ("   ·   IN RANGE" if w.in_range(r) else "   ·   OUT OF RANGE"), 16, RED if s > 0 else OK_GREEN))

	# What we know about the network here.
	var here: Array = net.nodes_in(r)
	var known: Array = here.filter(func(x): return Network.is_suspected(x))
	for x in known:
		_panel.add_child(_node_row(x))
	if here.size() > known.size():
		var n: int = here.size() - known.size()
		_panel.add_child(_label("+ %d unidentified cell%s" % [n, "" if n == 1 else "s"], 13, DIM))
	var plot: Dictionary = w.plot_in(r)
	if not plot.is_empty() and w.plot_known(plot, _campaign.has_global_intel()):
		_panel.add_child(_wrap("ATTACK PLOT: %s, %d week%s left." % [plot["city"], int(plot["weeks"]), "" if int(plot["weeks"]) == 1 else "s"], 15, RED, COL_W))

	if not w.in_range(r):
		var zones: Array = []
		for z in WorldSim.zones():
			if WorldSim.zones()[z].get("covers", []).has(r):
				zones.append(w.zone_name(z))
		_panel.add_child(_wrap("The carrier reaches here from: %s." % ", ".join(zones), 14, DIM, COL_W))
		return
	var reward: String = _money(int(Research.funding_rule("success_bonus") * float(th.get("reward", 1.0))))
	for op in w.operations_for(r, _campaign.has_global_intel()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		match str(op["kind"]):
			"node":
				row.add_child(_plan_btn("KILL '%s'" % op["hvt"]["alias"], op, "kill"))
				row.add_child(_plan_btn("CAPTURE", op, "capture"))
				row.add_child(_label("~%d hostiles" % int(op["tangos"]), 13, DIM))
			"plot":
				row.add_child(_plan_btn("STOP THE ATTACK in %s" % op["city"], op, ""))
				row.add_child(_label("~%d hostiles" % int(op["tangos"]), 13, DIM))
			_:
				row.add_child(_plan_btn("Blind raid", op, ""))
				row.add_child(_label("~%d hostiles · hits a random cell, turns up intel" % int(op["tangos"]), 12, DIM))
		_panel.add_child(row)
	_panel.add_child(_label("Success pays %s.  Capture = big intel on his contacts." % reward, 12, DIM))


func _plan_btn(text: String, op: Dictionary, mode: String) -> Button:
	var b := _button(text, func():
		_campaign.plan_operation(op, mode)
		_notice = ""
		_refresh())
	b.custom_minimum_size = Vector2(0, 32)
	var cur: Dictionary = _campaign.current_op
	if not cur.is_empty() and str(cur.get("kind", "")) == str(op["kind"]) and int(cur.get("node", -1)) == int(op.get("node", -1)) \
			and str(cur.get("region", "")) == str(op["region"]) and (mode == "" or str(cur.get("mode", "")) == mode):
		b.text = "PLANNED"
		b.disabled = true
	return b


## One known person / cell: portrait once located, alias, type, intel.
func _node_row(x: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if Network.is_located(x):
		var tr := TextureRect.new()
		tr.texture = Portrait.make(int(x["seed"]))
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(34, 34)
		row.add_child(tr)
	else:
		var q := ColorRect.new()
		q.color = Color(0.16, 0.18, 0.2)
		q.custom_minimum_size = Vector2(34, 34)
		row.add_child(q)
	var tier_txt: String = (str(x["title"]) + "  ·  ") if int(x["tier"]) < 2 else ""
	var who: String = ("'%s'  %s" % [x["alias"], x["name"]]) if Network.is_located(x) else "Suspected"
	var state: String = "LOCATED"
	if not Network.is_located(x):
		state = "GONE DARK" if str(x["status"]) == "dark" else "intel %d%%" % int(x["intel"])
	var col: Color = GOLD if Network.is_located(x) else Color.WHITE
	row.add_child(_wrap("%s  ·  %s%s, size %d  ·  %s" % [who, tier_txt, Network.type_name(str(x["type"])), int(x["size"]), state], 13, col, COL_W - 50))
	return row


func _zone_panel(z: String) -> void:
	var w = _campaign.world
	var zd: Dictionary = WorldSim.zones().get(z, {})
	_panel.add_child(_label(str(zd.get("name", z)), 22, Color(0.45, 0.7, 1.0)))
	_panel.add_child(_label("Sea zone", 12, DIM))
	_panel.add_child(_wrap("Covers: " + ", ".join(zd.get("covers", []).map(func(r): return WorldSim.region_name(r))), 14, Color.WHITE, COL_W))
	if z == w.carrier_zone:
		_panel.add_child(_label("The carrier is here.", 15, GOLD))
	elif w.can_move_to(z):
		_panel.add_child(_wrap("One week's sailing. Cells in the new reach will notice and may lie low this week.", 13, DIM, COL_W))
		_panel.add_child(_button("Move the carrier here", func():
			_campaign.move_carrier(z)
			_map.selected_zone = ""
			_notice = "The carrier is moving to the %s." % zd.get("name", z)
			_refresh()))
	elif w.carrier_moved:
		_panel.add_child(_label("The carrier has already moved this week.", 14, DIM))
	else:
		_panel.add_child(_label("Too far: the carrier moves one zone per week.", 14, DIM))


# ---------------------------------------------------------------- actions

func _on_region_clicked(r: String) -> void:
	_map.selected_zone = ""
	_map.selected_region = r
	_refresh()


func _on_zone_clicked(z: String) -> void:
	_map.selected_region = ""
	_map.selected_zone = z
	_refresh()


func _go_hq() -> void:
	get_tree().change_scene_to_file(_campaign.HQ_SCENE)


func _on_end_week() -> void:
	if not _campaign.current_op.is_empty() and not _confirm_end:
		_confirm_end = true
		_end_btn.text = "Skip the op? Click again"
		return
	_confirm_end = false
	var out: Dictionary = _campaign.end_week()
	var bits: Array[String] = ["A week passes."]
	if int(out["funding_lost"]) > 0:
		bits.append("An attack cost us $%dk." % int(int(out["funding_lost"]) / 1000.0))
	for name in out["research_finished"]:
		bits.append("Research complete: %s!" % name)
	_notice = "  ".join(bits)
	if _campaign.world.outcome != "":
		get_tree().change_scene_to_file(_campaign.END_SCENE)
		return
	_refresh()


# ---------------------------------------------------------------- widgets

func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


func _money(n: int) -> String:
	if absi(n) >= 1000000:
		return "$%.2fM" % (n / 1000000.0)
	return "$%dk" % int(round(n / 1000.0))


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


func _section(text: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 12)
	m.add_child(_label(text, 14, GOLD))
	return m


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 36)
	b.pressed.connect(cb)
	return b


func _box(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10 if width > 0 else 0)
	return s


## Default middle panel: the big picture plus how to play a week.
func _overview_panel() -> void:
	var w = _campaign.world
	var net = w.network
	var gi: bool = _campaign.has_global_intel()
	_panel.add_child(_label("THE HUNT FOR %s" % str(net.leader().get("title", "THE EMIR")).to_upper(), 14, GOLD))
	var down: int = net.nodes.filter(func(x): return str(x.get("title", "")) != "" and int(x["tier"]) <= 1 and not Network.is_alive(x)).size()
	var located: int = net.alive_nodes().filter(func(x): return Network.is_located(x)).size()
	var leader: Dictionary = net.leader()
	var where: String = "unknown"
	if Network.is_located(leader):
		where = "LOCATED in %s" % WorldSim.region_name(str(leader["region"]))
	elif Network.is_suspected(leader):
		where = "suspected in %s (intel %d%%)" % [WorldSim.region_name(str(leader["region"])), int(leader["intel"])]
	_panel.add_child(_label("Leader: %s" % where, 15, GOLD if Network.is_suspected(leader) else Color.WHITE))
	_panel.add_child(_label("Lieutenants taken down: %d  ·  located targets: %d" % [down, located], 15, Color.WHITE))
	_panel.add_child(_label("Network active in %d of 24 regions  ·  total strength %d" % [w.active_regions().size(), w.total_strength()], 15, Color.WHITE))
	var known: int = w.plots.filter(func(p): return w.plot_known(p, gi)).size()
	_panel.add_child(_label("Attack plots known: %d  ·  suspected: %d  ·  landed: %d  ·  stopped: %d" % [known, w.plots.size() - known, w.attacks_landed, w.plots_foiled], 14, RED if known > 0 else Color.WHITE))
	if net.couriers_weeks > 0:
		_panel.add_child(_label("They are using couriers: intel at half speed for %d more weeks." % net.couriers_weeks, 13, RED))
	_panel.add_child(_section("HOW TO WIN"))
	_panel.add_child(_wrap("Find and take down the Emir. Nobody knows where he is: capture his lieutenants and interrogate them to find out. Captures reveal the people linked to the target; kills reveal less. See NETWORK for the whole board.", 13, DIM, COL_W))
	_panel.add_child(_section("THIS WEEK"))
	_panel.add_child(_wrap("1.  Move the carrier if you want (glowing SAIL HERE boxes). Coverage slowly locates targets.", 13, DIM, COL_W))
	_panel.add_child(_wrap("2.  Pick a target in range (right column), choose KILL or CAPTURE.", 13, DIM, COL_W))
	_panel.add_child(_wrap("3.  Pick the squad at HQ and deploy. Or END WEEK to skip.", 13, DIM, COL_W))
