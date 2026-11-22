extends "res://v2/stations/station.gd"
## The roller door: going out. Walled off with placeholder text until we build it (decided 2026-11-21).


func build() -> void:
	var v := Kit.panel(self, "GOING OUT", Vector2(240, 0))
	v.add_child(Kit.label("Not built yet.", Pal.MULT, 10))
	v.add_child(Kit.label("Later: the town map. Click a place, play a short hands-on scene there (a break-in, a meeting, a shift), then come back.", Pal.TEXT, 9, 230))
	v.add_child(Kit.label("Districts: " + ", ".join(PackedStringArray(Content.world().get("districts", []))), Pal.DIM, 8, 230))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Stay in", close, game))
	game.sfx.play("switch_002", 0.5, -10.0)
