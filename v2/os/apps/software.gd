extends "res://v2/os/app.gd"
## Software: the State software center. Install programs; launching the hacking ones needs the box (next build).

var _list: VBoxContainer


func build() -> void:
	var v := vbox()
	v.add_child(P.label("HEARTH Software Center   (every install is reported, for your safety)", P.INK_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var inst: Array = state().os.get("installed", [])
	for p in Fs.data().get("programs", []):
		var prog: Dictionary = p
		var row := HBoxContainer.new()
		_list.add_child(row)
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.draw.connect(func() -> void: P.icon(ic, "program", Vector2(1, 1)))
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		col.add_child(P.label("%s   %s" % [prog["name"], prog["size"]], P.INK))
		col.add_child(P.label(str(prog["desc"]), P.INK_DIM, maxf(80.0, size.x - 90.0)))
		var has: bool = inst.has(prog["id"])
		row.add_child(button("Launch" if has else "Install", func() -> void:
			if has:
				_launch(prog)
			else:
				_install(prog)))
		_list.add_child(HSeparator.new())


func _install(prog: Dictionary) -> void:
	var inst: Array = state().os.get("installed", [])
	if not inst.has(prog["id"]):
		inst.append(prog["id"])
	state().os["installed"] = inst
	os.game.sfx.play("confirmation_002", 1.2, -10.0)
	_fill()


func _launch(prog: Dictionary) -> void:
	if prog["id"] == "solitaire":
		os.alert("Patience", "You win! (Every game is won. That's the point.)", "info")
	else:
		os.alert(prog["name"], "No device found.\n%s needs the box: the machine on the desk that HEARTH can't see. (Hacking missions come in the next build.)" % prog["name"], "warn")
