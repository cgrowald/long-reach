extends Control
## The loot reveal: the screen dims, a card flips open in its tier color, the Archivist grades it.

signal closed

const T := preload("res://terminal/os_theme.gd")
const Loot := preload("res://sim/loot.gd")

var _card: PanelContainer


func show_drop(drop: Dictionary, sfx) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = size
	add_child(dim)
	var stars: int = int(drop.get("stars", 1))
	var tier: Dictionary = Loot.tier(stars)
	var col := Color(str(tier.get("color", "#ffffff")))
	_card = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.07, 0.08)
	s.border_color = col
	s.set_border_width_all(4)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(col, 0.5)
	s.shadow_size = 24 if stars >= 4 else 10
	s.set_content_margin_all(22)
	_card.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(520, 0)
	_card.add_child(v)
	var head := T.label("NEW FIND", 14, Color(0.7, 0.7, 0.7))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var st := T.label("★".repeat(stars) + "☆".repeat(5 - stars), 34, col)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var tl := T.label(str(tier.get("name", "")).to_upper(), 22, col)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var nm := T.label(str(drop.get("name", "")), 20, Color(0.95, 0.94, 0.9))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var ty := T.label(str(drop.get("type", "")), 14, Color(0.6, 0.6, 0.6))
	ty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ty)
	for t in drop.get("traits", []):
		var d: Dictionary = Loot.trait_def(str(t))
		var row := T.label("+ %s:  %s" % [d.get("name", t), d.get("desc", "")], 14, Color(0.85, 0.82, 0.6))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(row)
	var arch := T.label("THE ARCHIVIST:  \"%s\"" % drop.get("archivist", ""), 14, Color(0.6, 0.75, 0.7))
	arch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(arch)
	var where := T.label("Saved to Files: %s" % str(drop.get("file", "")), 12, Color(0.5, 0.5, 0.5))
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(where)
	var b := Button.new()
	b.text = "Take it"
	b.pressed.connect(func():
		closed.emit()
		queue_free())
	v.add_child(b)
	for l in v.get_children():
		if l is Label and l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size = Vector2(520, 0)
	add_child(_card)
	_card.scale = Vector2(0.05, 1.0)
	_card.modulate.a = 0.0
	await get_tree().process_frame
	_card.reset_size()
	_card.pivot_offset = _card.size / 2
	_card.position = (size - _card.size) / 2
	_card.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_card, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.12)
	sfx.play("secret" if stars >= 4 else "chime", -6.0 if stars >= 4 else -10.0)
