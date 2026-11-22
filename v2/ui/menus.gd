extends RefCounted
## Shared overlay menus: settings, save / load slots, a yes/no confirm, a message box.
## Each returns a full-screen Control; it frees itself when closed and calls on_close.

const Kit := preload("res://v2/ui/kit.gd")
const Pal := preload("res://v2/ui/pal.gd")
const SaveStore := preload("res://v2/sim/save_store.gd")


static func _overlay(parent: Control) -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.z_index = 40
	parent.add_child(o)
	Kit.dim(o)
	return o


static func _close(o: Control, on_close: Callable) -> void:
	o.queue_free()
	if on_close.is_valid():
		on_close.call()


# ------------------------------------------------------------------ settings

static func settings(parent: Control, game: Node, on_close := Callable()) -> Control:
	var o := _overlay(parent)
	var v := Kit.panel(o, "SETTINGS", Vector2(250, 0))
	var s = game.settings
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)

	var slider := func(label: String, key: String, lo: float, hi: float, step: float, fmt: String) -> void:
		grid.add_child(Kit.label(label))
		var h := HBoxContainer.new()
		var sl := HSlider.new()
		sl.min_value = lo
		sl.max_value = hi
		sl.step = step
		sl.value = float(s.get_v(key))
		sl.custom_minimum_size = Vector2(90, 9)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.focus_mode = Control.FOCUS_NONE
		var val := Kit.label(fmt % sl.value, Pal.AMBER)
		val.custom_minimum_size.x = 28
		sl.value_changed.connect(func(x: float) -> void:
			s.set_v(key, int(x) if step >= 1.0 else x)
			val.text = fmt % x
			game.apply_settings()
			game.sfx.play("tick_001", 1.0 + x / maxf(hi, 0.01) * 0.5, -10.0, 0.05))
		h.add_child(sl)
		h.add_child(val)
		grid.add_child(h)

	var toggle := func(label: String, key: String) -> void:
		grid.add_child(Kit.label(label))
		var c := CheckButton.new()
		c.button_pressed = bool(s.get_v(key))
		c.focus_mode = Control.FOCUS_NONE
		c.toggled.connect(func(on: bool) -> void:
			s.set_v(key, on)
			game.clunk()
			game.apply_settings())
		grid.add_child(c)

	grid.add_child(Kit.label("SOUND", Pal.DIM, 8))
	grid.add_child(Control.new())
	slider.call("Master", "master", 0.0, 1.0, 0.05, "%.2f")
	slider.call("Music / room", "music", 0.0, 1.0, 0.05, "%.2f")
	slider.call("Effects", "sfx", 0.0, 1.0, 0.05, "%.2f")
	grid.add_child(Kit.label("PICTURE", Pal.DIM, 8))
	grid.add_child(Control.new())
	toggle.call("Fullscreen", "fullscreen")
	toggle.call("Vsync", "vsync")
	slider.call("Pixel size", "pixel", 2.0, 4.0, 1.0, "%d")
	slider.call("Field of view", "fov", 55.0, 90.0, 1.0, "%d")
	toggle.call("Screen shake", "shake")
	grid.add_child(Kit.label("CONTROLS", Pal.DIM, 8))
	grid.add_child(Control.new())
	slider.call("Look sensitivity", "sensitivity", 0.0, 2.0, 0.1, "%.1f")
	toggle.call("Show hints", "hints")

	v.add_child(HSeparator.new())
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Defaults", func() -> void:
		s.values = s.DEFAULTS.duplicate()
		game.apply_settings()
		_close(o, Callable())
		settings(parent, game, on_close), game))
	r.add_child(Kit.button("Back", func() -> void: _close(o, on_close), game))
	o.set_meta("back", func() -> void: _close(o, on_close))
	return o


# ------------------------------------------------------------------ save / load

static func slots(parent: Control, game: Node, saving: bool, on_close := Callable()) -> Control:
	var o := _overlay(parent)
	var v := Kit.panel(o, "SAVE GAME" if saving else "LOAD GAME", Vector2(260, 0))
	for slot in SaveStore.SLOTS:
		if saving and slot == "auto":
			continue
		var m := SaveStore.meta(slot)
		var name := "Autosave" if slot == "auto" else "Slot %s" % slot
		var text := "%-9s  --- empty ---" % name
		if not m.is_empty():
			var pt := int(m.get("playtime", 0.0))
			text = "%-9s  Day %d  %d cr  %d:%02d  %s" % [name, int(m.get("day", 1)), int(m.get("money", 0)),
				pt / 3600, (pt / 60) % 60, str(m.get("saved_at", "")).substr(5, 11)]
		var b := Kit.button(text, func() -> void:
			if saving:
				var ok: bool = game.save_slot(slot)
				game.sfx.play("confirmation_002" if ok else "error_004", 1.0, -6.0)
				_close(o, Callable())
				message(parent, game, "Saved to %s." % name if ok else "Couldn't save.", on_close)
			else:
				_close(o, Callable())
				game.load_slot(slot), game)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not saving and m.is_empty()
		v.add_child(b)
	v.add_child(HSeparator.new())
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Back", func() -> void: _close(o, on_close), game))
	o.set_meta("back", func() -> void: _close(o, on_close))
	return o


# ------------------------------------------------------------------ small boxes

static func confirm(parent: Control, game: Node, question: String, on_yes: Callable, on_close := Callable(), yes := "Yes", no := "No") -> Control:
	var o := _overlay(parent)
	var v := Kit.panel(o, "", Vector2(200, 0))
	v.add_child(Kit.label(question, Pal.TEXT, 10, 200))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button(no, func() -> void: _close(o, on_close), game))
	r.add_child(Kit.button(yes, func() -> void:
		_close(o, Callable())
		on_yes.call(), game))
	o.set_meta("back", func() -> void: _close(o, on_close))
	return o


static func message(parent: Control, game: Node, text: String, on_close := Callable(), title := "") -> Control:
	var o := _overlay(parent)
	var v := Kit.panel(o, title, Vector2(200, 0))
	v.add_child(Kit.label(text, Pal.TEXT, 10, 220))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("OK", func() -> void: _close(o, on_close), game))
	o.set_meta("back", func() -> void: _close(o, on_close))
	return o


## Closes the top overlay under parent (Esc). Returns true if one was open.
static func back_top(parent: Control) -> bool:
	for i in range(parent.get_child_count() - 1, -1, -1):
		var c := parent.get_child(i)
		if c.has_meta("back") and not c.is_queued_for_deletion():
			(c.get_meta("back") as Callable).call()
			return true
	return false
