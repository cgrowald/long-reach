extends Control
## After-action report: what happened to each person on the operation.

const Portrait := preload("res://people/portrait.gd")

const GOLD := Color(1.0, 0.82, 0.3)
const DIM := Color(0.62, 0.66, 0.7)
const OUTCOME_COLORS := {"OK": Color(0.45, 0.9, 0.5), "WOUNDED": Color(1.0, 0.6, 0.3), "KIA": Color(0.9, 0.35, 0.3)}


func _ready() -> void:
	var campaign = get_node("/root/Campaign")
	var rep: Dictionary = campaign.last_report

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(_label("AFTER-ACTION REPORT", 16, DIM))
	col.add_child(_label(str(rep.get("operation", "Operation")), 30, GOLD))
	var success: bool = bool(rep.get("success", false))
	col.add_child(_label("%s   ·   %s" % [rep.get("date", ""), "OBJECTIVE COMPLETE" if success else "OBJECTIVE NOT COMPLETED"], 18,
		Color(0.45, 0.9, 0.5) if success else Color(0.9, 0.35, 0.3)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	for e in rep.get("entries", []):
		rows.add_child(_entry_row(campaign, e))

	col.add_child(_label("Time passes. The calendar moves to %s; the wounded keep healing." % rep.get("next_date", ""), 14, DIM))
	var back := Button.new()
	back.text = "Return to HQ"
	back.custom_minimum_size = Vector2(220, 44)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): get_tree().change_scene_to_file(campaign.HQ_SCENE))
	col.add_child(back)


func _entry_row(campaign, e: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.12, 0.15)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var r = campaign.roster.get_by_id(int(e["id"]))
	var tr := TextureRect.new()
	tr.texture = Portrait.make(r.portrait_seed if r != null else 0, str(e["outcome"]) == "KIA")
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(72, 72)
	row.add_child(tr)
	var info := VBoxContainer.new()
	row.add_child(info)
	info.add_child(_label(str(e["name"]), 18, Color.WHITE))
	var outcome: String = str(e["outcome"])
	var kills: int = int(e.get("kills", 0))
	info.add_child(_label("%s   ·   %d kill%s" % [outcome, kills, "" if kills == 1 else "s"], 15, OUTCOME_COLORS.get(outcome, Color.WHITE)))
	var notes: Array = e.get("notes", [])
	if not notes.is_empty():
		info.add_child(_label("   ".join(notes), 13, DIM))
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
