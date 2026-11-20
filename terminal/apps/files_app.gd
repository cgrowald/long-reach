extends HBoxContainer
## Files: folders, the previous owner's leftovers, Pavel's photos, downloads, metadata, the trash.

const T := preload("res://terminal/os_theme.gd")
const Pics := preload("res://terminal/pics.gd")

var desk
var state
var _dirs: ItemList
var _dir_paths: Array = []
var _files: ItemList
var _file_list: Array = []
var _dir: String = "/Documents"
var _buttons: HBoxContainer
var _status: Label
var _sig: String = ""


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dirs = ItemList.new()
	_dirs.custom_minimum_size = Vector2(190, 0)
	_dirs.item_selected.connect(func(i): _enter(_dir_paths[i]))
	add_child(_dirs)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	_status = T.label("", 13, T.DIM)
	right.add_child(_status)
	_files = ItemList.new()
	_files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_files.item_activated.connect(func(_i): _open())
	right.add_child(_files)
	_buttons = HBoxContainer.new()
	right.add_child(_buttons)
	for b in [["Open", _open], ["Properties", _props], ["Delete", _delete], ["Print", _print]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		_buttons.add_child(btn)
	state.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var listing: Array = [] if _dir == "/Trash" else state.list_dir(_dir)
	var sig := "%s|%d|%d|%s|%s" % [_dir, state.files.size(), state.trash.size(), state.has_flag("show_hidden"), state.dir_locked(_dir)]
	for f in listing:
		sig += str(f.get("stripped", false))
	if sig == _sig:
		return
	_sig = sig
	_dirs.clear()
	_dir_paths.clear()
	for d in state.dirs():
		var p: String = str(d["path"])
		var depth := p.count("/") - 1
		var lock := "  [locked]" if state.dir_locked(p) else ""
		_dirs.add_item("    ".repeat(depth) + p.get_file() + lock)
		_dir_paths.append(p)
	_dirs.add_item("Trash (%d)" % state.trash.size())
	_dir_paths.append("/Trash")
	_dirs.select(_dir_paths.find(_dir))
	_files.clear()
	_file_list.clear()
	if _dir == "/Trash":
		_file_list = state.trash.duplicate()
	elif state.dir_locked(_dir):
		_status.text = "%s is encrypted." % _dir
		return
	else:
		_file_list = listing
	for f in _file_list:
		var nm: String = str(f["path"]).get_file()
		var kind: String = {"image": "picture", "text": "document", "exe": "program"}.get(str(f.get("type", "")), "file")
		_files.add_item("%s      %s" % [nm, kind])
	_status.text = "%s   -   %d item%s" % [_dir, _file_list.size(), "" if _file_list.size() == 1 else "s"]


func _enter(p: String) -> void:
	desk.sfx.play("click")
	_dir = p
	_sig = ""
	_refresh()
	if state.dir_locked(p):
		_ask_password(p)


func _selected() -> Dictionary:
	var s := _files.get_selected_items()
	if s.is_empty() or s[0] >= _file_list.size():
		return {}
	return _file_list[s[0]]


# ------------------------------------------------------------- actions

func _open() -> void:
	var f := _selected()
	if f.is_empty():
		return
	desk.sfx.play("click")
	state.do_actions(f.get("on_open", []))
	match str(f.get("type", "")):
		"text":
			var l := RichTextLabel.new()
			l.add_theme_font_override("normal_font", T.mono())
			l.add_theme_font_size_override("normal_font_size", 14)
			l.selection_enabled = true
			l.text = str(f.get("text", ""))
			l.size_flags_vertical = Control.SIZE_EXPAND_FILL
			desk.open_window(str(f["path"]).get_file(), l, Vector2(560, 420))
		"image":
			var tr := TextureRect.new()
			tr.texture = Pics.make(str(f.get("pic", "")))
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			desk.open_window(str(f["path"]).get_file(), tr, Vector2(500, 380))
		"exe":
			if _dir == "/Trash":
				return
			var prog: String = str(f.get("installs", ""))
			if state.has_flag("installed_" + prog):
				var box := VBoxContainer.new()
				box.add_child(T.label("%s is installed." % prog))
				var ub := Button.new()
				ub.text = "Uninstall"
				box.add_child(ub)
				var w = desk.open_window("Setup", box, Vector2(320, 130))
				ub.pressed.connect(func():
					state.uninstall(prog)
					desk.sfx.play("click")
					w.close())
				return
			var msg: String = state.run_file(str(f["path"]))
			desk.sfx.play("chime", -14.0)
			_info("Setup", msg)
		_:
			_info("Files", "HEARTH OS doesn't know how to open this.")


func _props() -> void:
	var f := _selected()
	if f.is_empty():
		return
	desk.sfx.play("click")
	var box := VBoxContainer.new()
	box.add_child(T.label(str(f["path"]).get_file(), 16))
	var meta: Dictionary = f.get("meta", {})
	if meta.is_empty():
		box.add_child(T.label("No metadata." + ("  (stripped)" if f.get("stripped", false) else ""), 14, T.DIM))
	for k in meta:
		var row := HBoxContainer.new()
		var kl := T.label(str(k) + ":", 14, T.DIM)
		kl.custom_minimum_size = Vector2(110, 0)
		row.add_child(kl)
		var vl := T.label(str(meta[k]), 14)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(vl)
		box.add_child(row)
	var win
	if not meta.is_empty() and state.has_flag("scrub") and _dir != "/Trash":
		var b := Button.new()
		b.text = "Strip metadata (Scrub)"
		b.pressed.connect(func():
			state.strip_meta(str(f["path"]))
			desk.sfx.play("chime", -14.0)
			state.log_lines.append("Stripped the metadata from %s." % str(f["path"]).get_file())
			win.close())
		box.add_child(b)
	win = desk.open_window("Properties", box, Vector2(440, 250))


func _delete() -> void:
	var f := _selected()
	if f.is_empty():
		return
	desk.sfx.play("click")
	if _dir == "/Trash":
		_info("Trash", "Files in the Trash are deleted when you empty it.\n(Type 'wipe' somewhere special to really get rid of things.)")
		return
	state.delete_file(str(f["path"]))


func _print() -> void:
	var f := _selected()
	if f.is_empty() or not str(f.get("type", "")) in ["image", "text"]:
		return
	desk.sfx.play("click")
	var box := VBoxContainer.new()
	var l := T.label("HearthPrint protects you: every printed page carries your citizen serial (0447-2219-KS) in tiny yellow dots.\n\nPrint anyway?")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	box.add_child(l)
	var row := HBoxContainer.new()
	box.add_child(row)
	var yes := Button.new()
	yes.text = "Print"
	var no := Button.new()
	no.text = "Cancel"
	row.add_child(yes)
	row.add_child(no)
	var win = desk.open_window("HearthPrint", box, Vector2(430, 200))
	yes.pressed.connect(func():
		state.add_exposure(1, "printed %s on HearthPrint (your citizen serial in yellow dots)" % str(f["path"]).get_file())
		state.set_flag("printed")
		state.toast.emit("The printer hums. You hide the page in the toolbox.")
		win.close())
	no.pressed.connect(func(): win.close())


func _ask_password(p: String) -> void:
	var box := VBoxContainer.new()
	box.add_child(T.label("%s is encrypted. Password:" % p.get_file()))
	var le := LineEdit.new()
	le.secret = true
	box.add_child(le)
	var err := T.label("", 13, T.DANGER)
	box.add_child(err)
	var b := Button.new()
	b.text = "Unlock"
	box.add_child(b)
	var win = desk.open_window("Encrypted folder", box, Vector2(360, 190))
	var tries := [0]
	var submit := func(_t = ""):
		if state.unlock_dir(p, le.text):
			desk.sfx.play("secret", -8.0)
			_sig = ""
			_refresh()
			win.close()
		else:
			tries[0] += 1
			desk.sfx.play("error")
			err.text = "Wrong password." + ("  (The letter in Documents might help.)" if tries[0] >= 4 else "")
	b.pressed.connect(submit)
	le.text_submitted.connect(submit)
	le.grab_focus.call_deferred()


func _info(title: String, text: String) -> void:
	var l := T.label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk.open_window(title, l, Vector2(400, 170))
