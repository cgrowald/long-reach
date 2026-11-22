extends "res://v2/stations/station.gd"
## The door into the house: go to bed. The night runs, the game autosaves, the next day starts.


func build() -> void:
	var st = game.state
	var v := Kit.panel(self, "GO INSIDE", Vector2(220, 0))
	var left: float = st.hours_left()
	if left > 0.01:
		v.add_child(Kit.label("It's %s. You still have %s hours tonight." % [st.clock_text(), _h(left)], Pal.TEXT, 10, 210))
	else:
		v.add_child(Kit.label("It's %s. Hana left the hall light on for you." % st.clock_text(), Pal.TEXT, 10, 210))
	v.add_child(Kit.label("Sleeping ends the day and saves the game.", Pal.DIM, 8, 210))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Not yet", close, game))
	r.add_child(Kit.button("Sleep", func() -> void: garage.sleep(), game))
