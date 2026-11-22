extends Control
## The HEARTH menu: user header, a search box first (Unity dash), the apps grid, then Leave the PC.
## Type to filter, Enter launches the first match.

const P := preload("res://v2/os/os_pal.gd")
const Tile := preload("res://v2/os/icon_tile.gd")

var os: Control
var _search: LineEdit
var _grid: GridContainer
var _first := ""


func setup(p_os: Control) -> void:
	os = p_os
	theme = P.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(160, 184)
	position = Vector2(2, os.size.y - 16.0 - size.y)
	_search = LineEdit.new()
	_search.placeholder_text = "Search applications..."
	_search.text_changed.connect(func(_t: String) -> void: _fill())
	_search.text_submitted.connect(func(_t: String) -> void:
		if _first != "":
			os.launch(_first))
	add_child(_search)
	_search.position = Vector2(6, 30)
	_search.size = Vector2(size.x - 12, 13)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.position = Vector2(6, 48)
	add_child(_grid)
	var leave := Button.new()
	leave.text = "Leave the PC"
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(func() -> void: os.leave())
	add_child(leave)
	leave.position = Vector2(size.x - 70, size.y - 17)
	leave.size = Vector2(64, 13)
	var lock := Button.new()
	lock.text = "Lock"
	lock.focus_mode = Control.FOCUS_NONE
	lock.pressed.connect(func() -> void:
		os.close_menus()
		os.alert("Locked", "Screen lock is disabled by order of the Ministry. Nothing on this computer is private anyway.", "lock"))
	add_child(lock)
	lock.position = Vector2(6, size.y - 17)
	lock.size = Vector2(34, 13)
	_fill()
	_search.grab_focus.call_deferred()


func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_first = ""
	var q := _search.text.strip_edges().to_lower()
	for a in os.data().get("apps", []):
		var def: Dictionary = a
		var hay := (str(def["name"]) + " " + str(def.get("keys", ""))).to_lower()
		if q != "" and not hay.contains(q):
			continue
		if _first == "":
			_first = def["id"]
		var t: Control = Tile.new()
		t.setup(def["icon"], def["name"], false, Vector2(48, 30))
		t.single_click_opens = true
		var locked: bool = def.get("locked", false) and not os.game.state.unlocked.has("hatch")
		t.dim = locked
		t.opened.connect(func() -> void:
			if locked:
				os.close_menus()
				os.alert("War room", "Locked. You need a cell and a room under the floor first.", "lock")
			else:
				os.launch(def["id"]))
		_grid.add_child(t)
	if _grid.get_child_count() == 0 or q != "" and _first == "":
		pass
	queue_redraw()


func _draw() -> void:
	P.bevel(self, Rect2(Vector2.ZERO, size), P.FACE, true)
	P.grad_h(self, Rect2(2, 2, size.x - 4, 25), P.BRAND.darkened(0.25), P.BRAND.lightened(0.1))
	P.icon(self, "user", Vector2(5, 6), 16.0)
	P.text(self, Vector2(24, 3), str(os.data().get("user", "citizen")), Color.WHITE)
	P.text(self, Vector2(24, 14), "HEARTH GNU/State", Color(1, 1, 1, 0.75))
	draw_line(Vector2(4, size.y - 21), Vector2(size.x - 4, size.y - 21), P.FACE_D)
	if _first == "" and _search and _search.text != "":
		P.text(self, Vector2(8, 54), "Nothing found. Try 'web' or 'files'.", P.INK_DIM)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		accept_event()
