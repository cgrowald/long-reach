extends "res://v2/stations/station.gd"
## The clipboard on the wall: tonight's rule, hours, needs, and last night's ledger. Paper look.


func build() -> void:
	var st = game.state
	var v := Kit.panel(self, "", Vector2(240, 0))
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.PAPER
	sb.set_content_margin_all(8)
	paper.add_theme_stylebox_override("panel", sb)
	v.add_child(paper)
	var pv := VBoxContainer.new()
	paper.add_child(pv)
	pv.add_child(Kit.label("DAY %d   %s   %s h left" % [st.day, st.clock_text(), _h(st.hours_left())], Pal.INK, 10))
	var rule: Dictionary = st.rule()
	pv.add_child(Kit.label("Rule of the day: %s" % rule.get("title", "-"), Color(0.5, 0.08, 0.06), 9, 220))
	pv.add_child(Kit.label(str(rule.get("text", "")), Pal.INK, 8, 220))
	pv.add_child(Kit.label("Needs:", Pal.INK, 9))
	for n in Content.world().get("needs", []):
		pv.add_child(Kit.label("- " + str(n), Pal.INK, 8, 220))
	if not st.ledger.is_empty():
		var last: Dictionary = st.ledger[-1]
		pv.add_child(Kit.label("Last night (day %d):" % int(last["day"]), Pal.INK, 9))
		for line in last["lines"]:
			pv.add_child(Kit.label("- " + str(line), Pal.INK, 8, 220))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Back", close, game))
	game.sfx.play("drop_002", 1.3, -12.0)
