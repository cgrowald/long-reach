extends "res://v2/os/app.gd"
## Files: back / up / home, an address bar, a grid of folders and files. Double-click opens.

const Tile := preload("res://v2/os/icon_tile.gd")

var path := Fs.HOME
var _hist: Array = []
var _addr: LineEdit
var _grid: HFlowContainer
var _status: Label
var _tiles: Array = []


func build() -> void:
	path = arg if arg != "" else Fs.HOME
	var v := vbox()
	var bar := HBoxContainer.new()
	v.add_child(bar)
	bar.add_child(button("<", go_back))
	bar.add_child(button("^", func() -> void: go(path.get_base_dir() if path != "/" else "/")))
	bar.add_child(button("Home", func() -> void: go(Fs.HOME)))
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.text_submitted.connect(func(t: String) -> void: go(Fs.norm(path, t)))
	bar.add_child(_addr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var well := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.WIN
	sb.border_color = P.FACE_D
	sb.set_border_width_all(1)
	well.add_theme_stylebox_override("panel", sb)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(well)
	well.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	_status = P.label("")
	v.add_child(_status)
	go(path, false)


func go(p: String, remember := true) -> void:
	var st := state()
	if not Fs.is_dir(st, p):
		if Fs.exists(st, p):
			os.open_path(p)
		else:
			os.alert("Files", "'%s' does not exist. It never existed." % p, "warn")
		_addr.text = path
		return
	if remember and p != path:
		_hist.append(path)
	path = p
	_addr.text = path
	win.title = "Files - " + (path.get_file() if path != "/" else "/")
	win.icon = "home" if path == Fs.HOME else "folder"
	win.queue_redraw()
	for c in _grid.get_children():
		c.queue_free()
	_tiles.clear()
	var entries := Fs.list(st, path)
	for e in entries:
		var en: Dictionary = e
		var t: Control = Tile.new()
		t.setup(en["kind"], en["name"], false, Vector2(48, 34))
		_grid.add_child(t)
		_tiles.append(t)
		t.picked.connect(func() -> void:
			for o in _tiles:
				o.set_selected(o == t))
		var open_fn := func() -> void:
			if en["dir"]:
				go(en["path"])
			else:
				os.open_path(en["path"])
		var props_fn := func() -> void:
			var owner_s := "citizen" if str(en["path"]).begins_with(Fs.HOME) else "hearthd"
			os.alert(en["name"], "Location: %s\nType: %s\nOwner: %s" % [path, "folder" if en["dir"] else en["kind"], owner_s], "info")
		t.opened.connect(open_fn)
		t.menu.connect(func(at: Vector2) -> void: os.context_menu(at, [["Open", open_fn], ["Properties", props_fn]]))
	_status.text = "%d items   %s" % [entries.size(), "" if Fs.can_write(path + "/x") else "(read only)"]


func go_back() -> void:
	if _hist.is_empty():
		return
	go(_hist.pop_back(), false)
