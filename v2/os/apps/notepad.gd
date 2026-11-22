extends "res://v2/os/app.gd"
## Notes: a plain text editor. Files under /home/citizen can be saved (they go in the save game);
## anything else opens read-only. With no file, it's a new note saved as notes_N.txt in your home.

var path := ""
var _edit: TextEdit
var _status: Label
var _dirty := false


func build() -> void:
	path = arg
	var v := vbox()
	var bar := HBoxContainer.new()
	v.add_child(bar)
	bar.add_child(button("Save", save))
	bar.add_child(button("Open folder", func() -> void: os.launch("files", path.get_base_dir() if path != "" else Fs.HOME)))
	_status = P.label("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status)
	_edit = TextEdit.new()
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.text = Fs.read(state(), path) if path != "" else ""
	_edit.editable = path == "" or Fs.can_write(path)
	_edit.text_changed.connect(func() -> void:
		_dirty = true
		_refresh())
	v.add_child(_edit)
	_refresh()


func _refresh() -> void:
	var nm := path.get_file() if path != "" else "untitled"
	win.title = "Notes - " + nm + (" *" if _dirty else "")
	win.queue_redraw()
	if not _edit.editable:
		_status.text = "read only (owned by hearthd)"
	else:
		_status.text = "unsaved" if _dirty else "saved"


func save() -> void:
	if not _edit.editable:
		os.alert("Notes", "You don't have permission to change this file. Your curiosity has been noted.", "warn")
		return
	if path == "":
		var i := 1
		while Fs.exists(state(), Fs.HOME + "/note_%d.txt" % i):
			i += 1
		path = Fs.HOME + "/note_%d.txt" % i
	Fs.write(state(), path, _edit.text)
	_dirty = false
	_refresh()
