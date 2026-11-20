extends Control
## The end of a campaign: the Emir is down (victory) or Washington shut the program down
## (defeat). A summary of the war and a button to start over.

const Network := preload("res://sim/network.gd")
const Portrait := preload("res://people/portrait.gd")
const UiTheme := preload("res://world/ui_theme.gd")

const GOLD := Color(1.0, 0.82, 0.3)
const DIM := Color(0.62, 0.66, 0.7)
const RED := Color(0.95, 0.4, 0.35)


func _ready() -> void:
	var campaign = get_node("/root/Campaign")
	theme = UiTheme.make()
	var w = campaign.world
	var net = w.network
	var won: bool = w.outcome == "victory"

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(900, 0)
	center.add_child(col)

	col.add_child(_label("CAMPAIGN OVER", 16, DIM))
	col.add_child(_label("THE NETWORK IS BROKEN" if won else "PROGRAM SHUT DOWN", 44, GOLD if won else RED))
	var leader: Dictionary = net.leader()
	var text: String
	if won:
		text = "%s, '%s' (%s), is %s. Without him %s splinters into feuding cells that will never again reach this far. Week %d." % [
			leader.get("title", "The Emir"), leader.get("alias", ""), leader.get("name", ""),
			"in custody" if str(leader.get("status", "")) == "captured" else "dead", Network.org_name(), w.week + 1]
	else:
		text = "After %d weeks at a critical threat level, oversight pulled the plug. The network is still out there; someone else will have to finish it." % int(Network.rule("defeat_weeks", 4))
	col.add_child(_wrap(text, 17, Color.WHITE))

	var down: Array = net.nodes.filter(func(x): return not Network.is_alive(x))
	col.add_child(_label("Weeks: %d   ·   Operations: %d   ·   Attacks landed: %d   ·   Plots stopped: %d   ·   Operators lost: %d" % [
		w.week + 1, campaign.roster.missions_run, w.attacks_landed, w.plots_foiled, campaign.roster.fallen().size()], 16, DIM))
	col.add_child(_label("Network members taken down: %d (captured %d)" % [down.size(), down.filter(func(x): return str(x["status"]) == "captured").size()], 16, DIM))
	var faces := HFlowContainer.new()
	faces.add_theme_constant_override("h_separation", 8)
	faces.add_theme_constant_override("v_separation", 8)
	for x in down:
		var tr := TextureRect.new()
		tr.texture = Portrait.make(int(x["seed"]), true)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(56, 56)
		tr.tooltip_text = "'%s' %s" % [x["alias"], x["name"]]
		faces.add_child(tr)
	col.add_child(faces)

	var fallen: Array = campaign.roster.fallen()
	if not fallen.is_empty():
		col.add_child(_label("In memory of: " + ", ".join(fallen.map(func(r): return r.full_name())), 14, DIM))

	var btn := Button.new()
	btn.text = "START A NEW CAMPAIGN"
	btn.custom_minimum_size = Vector2(300, 48)
	btn.pressed.connect(func():
		campaign.new_campaign()
		get_tree().change_scene_to_file(campaign.MAP_SCENE))
	col.add_child(btn)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	return l
