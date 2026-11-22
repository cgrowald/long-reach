extends "res://v2/stations/station.gd"
## The desk phone: a green LCD with messages (placeholder, from data/v2/world.json).


func build() -> void:
	var v := Kit.panel(self, "", Vector2(230, 0))
	var lcd := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.45, 0.3)
	sb.border_color = Color(0.1, 0.12, 0.09)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	lcd.add_theme_stylebox_override("panel", sb)
	v.add_child(lcd)
	var lv := VBoxContainer.new()
	lcd.add_child(lv)
	var ink := Color(0.08, 0.12, 0.07)
	lv.add_child(Kit.label("MESSAGES", ink, 10))
	for m in Content.world().get("messages", []):
		lv.add_child(Kit.label("%s:" % m["from"], ink.lightened(0.15), 8))
		lv.add_child(Kit.label(str(m["text"]), ink, 9, 210))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Hang up", close, game))
	game.sfx.play("bong_001", 1.6, -14.0)
