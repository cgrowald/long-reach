extends Control
## HEARTH OS: boot text -> login -> desktop (wallpaper, icons, windows, taskbar, start menu, right-click menu).
## Hosted by v2/stations/pc.gd. Costs no time. on_leave is called when you pick "Leave the PC".

const P := preload("res://v2/os/os_pal.gd")
const Fs := preload("res://v2/os/fs.gd")
const Win := preload("res://v2/os/os_window.gd")
const Tile := preload("res://v2/os/icon_tile.gd")
const Taskbar := preload("res://v2/os/taskbar.gd")
const StartMenu := preload("res://v2/os/start_menu.gd")
const CtxMenu := preload("res://v2/os/ctx_menu.gd")

const APPS := {
	"files": preload("res://v2/os/apps/files.gd"),
	"terminal": preload("res://v2/os/apps/terminal.gd"),
	"browser": preload("res://v2/os/apps/browser.gd"),
	"mail": preload("res://v2/os/apps/mail.gd"),
	"notepad": preload("res://v2/os/apps/notepad.gd"),
	"software": preload("res://v2/os/apps/software.gd"),
	"monitor": preload("res://v2/os/apps/monitor.gd"),
	"settings": preload("res://v2/os/apps/settings.gd"),
	"viewer": preload("res://v2/os/apps/viewer.gd"),
	"alert": preload("res://v2/os/apps/alert.gd"),
}
const TASKBAR_H := 14.0

var game: Node
var on_leave: Callable
var on_war: Callable
var phase := "boot"
var _t := 0.0
var _boot_lines: Array = []
var _login: Control
var _pw: LineEdit
var _pw_msg := ""
var _icons: Control
var windows_layer: Control
var taskbar: Control
var start_menu: Control
var _ctx: Control
var _tiles: Array = []
var _spawn := 0


func setup(p_game: Node, skip_boot: bool) -> void:
	game = p_game
	theme = P.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_boot_lines = Fs.data().get("boot", [])
	if skip_boot:
		_show_desktop()
	else:
		phase = "boot"
		game.sfx.play("maximize_006", 0.6, -10.0)


func data() -> Dictionary:
	return Fs.data()


func app_def(id: String) -> Dictionary:
	for a in data().get("apps", []):
		if a["id"] == id:
			return a
	return {}


# ------------------------------------------------------------------ boot and login

func _process(delta: float) -> void:
	_t += delta
	if phase == "boot":
		if _t > _boot_lines.size() * 0.16 + 0.8:
			_show_login()
		queue_redraw()
	elif phase == "login":
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if phase == "boot":
			_show_login()
			accept_event()
		elif phase == "desk":
			close_menus()
			for t in _tiles:
				(t as Control).call("set_selected", false)
			if e.button_index == MOUSE_BUTTON_RIGHT:
				_desktop_menu(get_global_mouse_position())
			accept_event()


func _show_login() -> void:
	if phase == "login":
		return
	phase = "login"
	_t = 0.0
	_login = Control.new()
	_login.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_login.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_login)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(130, 0)
	box.position = (size - Vector2(130, 60)) * 0.5 + Vector2(0, 14)
	_login.add_child(box)
	var name_l := P.label(str(data().get("user", "citizen")), Color.WHITE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_l)
	_pw = LineEdit.new()
	_pw.secret = true
	_pw.placeholder_text = "password"
	_pw.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw.text_submitted.connect(func(_s: String) -> void: try_login())
	box.add_child(_pw)
	var go := Button.new()
	go.text = "Log in"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(try_login)
	box.add_child(go)
	_pw.grab_focus()
	game.sfx.play("open_001", 0.9, -10.0)


func try_login() -> void:
	if _pw.text.strip_edges().to_lower() == str(data().get("password", "")).to_lower():
		game.sfx.play("confirmation_002", 1.0, -8.0)
		_login.queue_free()
		_login = null
		_show_desktop()
	else:
		_pw_msg = "Wrong password. This attempt has been noted." if _pw.text != "" else "Type the password (it's on the sticky note)."
		_pw.text = ""
		game.deny()


func _show_desktop() -> void:
	phase = "desk"
	_icons = Control.new()
	_icons.position = Vector2.ZERO
	_icons.size = size - Vector2(0, TASKBAR_H)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icons)
	var x := 4.0
	var y := 4.0
	for d in data().get("desktop", []):
		var def: Dictionary = d
		var t: Control = Tile.new()
		t.setup(def["icon"], def["name"], true)
		t.position = Vector2(x, y)
		_icons.add_child(t)
		_tiles.append(t)
		t.picked.connect(func() -> void: _select_tile(t))
		t.opened.connect(func() -> void: launch(def["app"], def.get("arg", "")))
		y += 34.0
		if y + 34.0 > size.y - TASKBAR_H:
			y = 4.0
			x += 46.0
	windows_layer = Control.new()
	windows_layer.position = Vector2.ZERO
	windows_layer.size = size - Vector2(0, TASKBAR_H)
	windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(windows_layer)
	taskbar = Taskbar.new()
	add_child(taskbar)
	taskbar.setup(self)
	taskbar.position = Vector2(0, size.y - TASKBAR_H)
	taskbar.size = Vector2(size.x, TASKBAR_H)
	queue_redraw()


func _select_tile(t: Control) -> void:
	close_menus()
	for o in _tiles:
		(o as Control).call("set_selected", o == t)
	game.hover()


# ------------------------------------------------------------------ windows

## Open an app. Returns the window (or null for things that aren't windows).
func launch(id: String, a := "") -> Control:
	close_menus()
	if id == "war":
		if on_war.is_valid():
			on_war.call()
		return null
	var script: Script = APPS.get(id)
	if script == null:
		alert("HEARTH", "No application is registered for '%s'." % id, "warn")
		return null
	# Single-instance apps just come to the front.
	if id in ["mail", "software", "monitor", "settings"]:
		for w in windows():
			if w.app_id == id:
				focus_window(w)
				return w
	var def := app_def(id)
	var sz: Array = def.get("size", [240, 160])
	var w: Control = Win.new()
	var wsize := Vector2(minf(float(sz[0]), windows_layer.size.x - 10), minf(float(sz[1]), windows_layer.size.y - 10))
	w.setup(def.get("name", id), def.get("icon", "file"), wsize)
	w.app_id = id
	var off := Vector2(60 + (_spawn % 6) * 14, 8 + (_spawn % 6) * 12)
	_spawn += 1
	off.x = minf(off.x, windows_layer.size.x - wsize.x - 2)
	off.y = minf(off.y, windows_layer.size.y - wsize.y - 2)
	w.position = off.max(Vector2.ZERO).round()
	windows_layer.add_child(w)
	var app: Control = script.new()
	w.set_app(app)
	app.setup(self, w, a)
	w.focus_me.connect(func() -> void: focus_window(w))
	w.closed.connect(func() -> void: _on_closed.call_deferred())
	focus_window(w)
	game.sfx.play("open_001", 1.1, -12.0)
	return w


func alert(t: String, text: String, ic := "info") -> Control:
	var w: Control = Win.new()
	var wsize := Vector2(190, 70)
	w.setup(t, ic, wsize)
	w.app_id = "alert"
	w.position = ((windows_layer.size - wsize) * 0.5).round()
	windows_layer.add_child(w)
	var app: Control = APPS["alert"].new()
	w.set_app(app)
	app.set_meta("icon", ic)
	app.setup(self, w, text)
	w.focus_me.connect(func() -> void: focus_window(w))
	w.closed.connect(func() -> void: _on_closed.call_deferred())
	focus_window(w)
	game.sfx.play("error_004" if ic == "warn" else "open_001", 1.0, -10.0)
	return w


func windows() -> Array:
	var out: Array = []
	if windows_layer == null:
		return out
	for c in windows_layer.get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func focus_window(w: Control) -> void:
	if w.minimized:
		w.set_minimized(false)
	windows_layer.move_child(w, -1)
	for o in windows():
		o.set_active(o == w)
	if taskbar:
		taskbar.queue_redraw()


func top_window() -> Control:
	var ws := windows()
	for i in range(ws.size() - 1, -1, -1):
		if not ws[i].minimized:
			return ws[i]
	return null


func _on_closed() -> void:
	var t := top_window()
	if t:
		focus_window(t)
	if taskbar:
		taskbar.queue_redraw()


## Click anywhere in a window brings it forward (children eat the click, so check here first).
func _input(e: InputEvent) -> void:
	if phase != "desk" or windows_layer == null:
		return
	if e is InputEventMouseButton and e.pressed:
		var mp := windows_layer.get_local_mouse_position()
		var ws := windows()
		for i in range(ws.size() - 1, -1, -1):
			var w: Control = ws[i]
			if w.visible and Rect2(w.position, w.size).has_point(mp):
				if not w.active:
					focus_window(w)
				break


## Open a file or folder in the right app.
func open_path(path: String) -> void:
	var st: RefCounted = game.state
	if Fs.is_dir(st, path):
		launch("files", path)
		return
	match Fs.kind_of(path.get_file()):
		"image":
			launch("viewer", path)
		"program":
			var body := Fs.read(st, path)
			if body.begins_with("prog:update"):
				alert("HEARTH Update", "Installing update 7731...\nDone. Nothing has changed. You feel slightly watched.", "info")
			else:
				alert(path.get_file(), "You can't run this from here. Programs that matter run through the box.", "warn")
		_:
			launch("notepad", path)


# ------------------------------------------------------------------ menus

func toggle_start() -> void:
	if start_menu and is_instance_valid(start_menu):
		close_menus()
		return
	close_menus()
	start_menu = StartMenu.new()
	add_child(start_menu)
	start_menu.setup(self)
	game.click()


func close_menus() -> void:
	if start_menu and is_instance_valid(start_menu):
		start_menu.queue_free()
	start_menu = null
	if _ctx and is_instance_valid(_ctx):
		_ctx.queue_free()
	_ctx = null


func context_menu(at: Vector2, items: Array) -> void:
	close_menus()
	_ctx = CtxMenu.new()
	add_child(_ctx)
	_ctx.setup(self, items)
	var p := at - global_position
	_ctx.position = Vector2(minf(p.x, size.x - _ctx.size.x - 1), minf(p.y, size.y - _ctx.size.y - 1)).round()


func _desktop_menu(at: Vector2) -> void:
	context_menu(at, [
		["Open Terminal", func() -> void: launch("terminal")],
		["Open Home", func() -> void: launch("files", Fs.HOME)],
		["New note", func() -> void: launch("notepad", "")],
		["Change wallpaper", func() -> void: cycle_wallpaper()],
		["About HEARTH", func() -> void: alert("About HEARTH", "%s\nOne OS for one people.\nUsed by every terminal, kiosk, camera and kettle in Valdenmark." % data().get("version", ""), "hearth")],
	])


## Esc: close a menu first. Returns true if it handled it.
func back() -> bool:
	if (start_menu and is_instance_valid(start_menu)) or (_ctx and is_instance_valid(_ctx)):
		close_menus()
		return true
	return false


func leave() -> void:
	close_menus()
	if on_leave.is_valid():
		on_leave.call()


func cycle_wallpaper() -> void:
	var st: RefCounted = game.state
	st.os["wallpaper"] = (int(st.os.get("wallpaper", 0)) + 1) % P.WALLPAPERS.size()
	queue_redraw()


func set_wallpaper(i: int) -> void:
	game.state.os["wallpaper"] = i
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if phase == "boot":
		draw_rect(r, Color(0.02, 0.02, 0.03))
		var n := int(_t / 0.16)
		for i in mini(n, _boot_lines.size()):
			var ln: String = _boot_lines[i]
			var col := Color(0.75, 0.75, 0.75)
			if ln.begins_with("[  OK"):
				col = Color(0.55, 0.9, 0.5)
			elif ln.begins_with("[ FAIL"):
				col = Color(0.95, 0.35, 0.3)
			elif ln.begins_with("[ WARN"):
				col = Color(0.95, 0.8, 0.3)
			P.text(self, Vector2(6, 6 + i * 9), ln, col)
		if fmod(_t, 0.5) < 0.25:
			draw_rect(Rect2(6, 6 + mini(n, _boot_lines.size()) * 9, 5, 8), Color(0.75, 0.75, 0.75))
		P.text(self, Vector2(size.x - 70, size.y - 12), "click to skip", Color(0.4, 0.4, 0.4))
		return
	_draw_wallpaper(r)
	if phase == "login":
		var c := size * 0.5
		var panel := Rect2(c - Vector2(80, 46), Vector2(160, 96))
		draw_rect(panel, Color(0, 0, 0, 0.35))
		draw_rect(panel, Color(1, 1, 1, 0.25), false, 1.0)
		P.icon(self, "user", c - Vector2(12, 42), 24.0)
		P.text(self, Vector2(panel.position.x, panel.end.y + 4), _pw_msg, Color(1, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		P.text(self, Vector2(6, 6), str(data().get("version", "")), Color(1, 1, 1, 0.7))
		P.text(self, Vector2(6, size.y - 12), game.state.clock_text(), Color(1, 1, 1, 0.7))
		_draw_sticky(Vector2(size.x - 62, 8))


func _draw_wallpaper(r: Rect2) -> void:
	var i := int(game.state.os.get("wallpaper", 0)) % P.WALLPAPERS.size()
	var wp: Dictionary = P.WALLPAPERS[i]
	P.grad_v(self, r, wp["a"], wp["b"])
	var lc: Color = wp["line"]
	# big sweeping arcs (the old Linux wallpaper curves)
	for k in 6:
		var cc := Vector2(size.x * (0.15 + k * 0.17), size.y * (1.6 - k * 0.12))
		draw_arc(cc, size.y * (0.9 + k * 0.18), PI * 1.1, PI * 1.9, 48, lc, 1.0)
		draw_arc(Vector2(size.x * (1.1 - k * 0.1), -size.y * 0.4), size.y * (0.8 + k * 0.15), PI * 0.15, PI * 0.85, 48, lc, 1.0)
	# the state emblem, faint
	var c := Vector2(size.x * 0.62, size.y * 0.46)
	draw_circle(c, 34, Color(1, 1, 1, 0.06))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -24), c + Vector2(13, 6), c + Vector2(0, 18), c + Vector2(-13, 6)]), Color(1, 1, 1, 0.08))
	P.text(self, Vector2(c.x - 60, c.y + 40), "ONE HEARTH. ONE PEOPLE.", Color(1, 1, 1, 0.22), HORIZONTAL_ALIGNMENT_CENTER, 120)


func _draw_sticky(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(56, 34)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(p, Vector2(56, 34)), Color(1.0, 0.92, 0.45))
	P.text(self, p + Vector2(4, 3), "pw:", P.INK)
	P.text(self, p + Vector2(4, 13), str(data().get("password", "")), Color(0.15, 0.15, 0.55))
	P.text(self, p + Vector2(4, 23), "- kettle", P.INK_DIM)
