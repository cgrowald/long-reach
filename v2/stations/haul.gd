extends "res://v2/stations/station.gd"
## The haul (D, coming home): the carton your people carried back, waiting under the lamp by the roller door.
## It lists what came home (it's already in the stash); "Put it away" clears the carton from the room.
## state.flags.haul = {title, lines, day}.


func build() -> void:
	var h: Dictionary = game.state.flags.get("haul", {})
	var v := Kit.panel(self, str(h.get("title", "THE HAUL")), Vector2(280, 0))
	if h.is_empty():
		v.add_child(Kit.label("Nothing here.", Pal.DIM, 9))
	else:
		v.add_child(Kit.label("Brought home on night %d. It's all in the stash now." % int(h.get("day", 0)), Pal.DIM, 8, 270))
		for ln in h.get("lines", []):
			v.add_child(Kit.label("- " + str(ln), Pal.TEXT, 9, 270))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Leave it", close, game))
	r.add_child(Kit.button("Put it away", func() -> void:
		game.state.flags.erase("haul")
		game.sfx.play("drop_002", 0.8, -6.0)
		garage.toast("Put away. The shelves are fuller.")
		close(), game))
