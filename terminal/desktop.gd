extends Control
## The HEARTH OS desktop: wallpaper, icons, windows, taskbar, tray, start menu, toasts.

signal shutdown_requested

const T := preload("res://terminal/os_theme.gd")
const Pics := preload("res://terminal/pics.gd")
const OsWindow := preload("res://terminal/os_window.gd")
const APPS := {
	"messages": {"title": "Messages", "script": "res://terminal/apps/messages_app.gd", "size": Vector2(720, 500), "tile": "MSG", "color": Color(0.2, 0.55, 0.45)},
	"browser": {"title": "NetState Browser", "script": "res://terminal/apps/browser_app.gd", "size": Vector2(860, 560), "tile": "NET", "color": Color(0.2, 0.4, 0.7)},
	"files": {"title": "Files", "script": "res://terminal/apps/files_app.gd", "size": Vector2(700, 440), "tile": "FILES", "color": Color(0.75, 0.6, 0.2)},
	"console": {"title": "dev console", "script": "res://terminal/apps/console_app.gd", "size": Vector2(640, 400), "tile": ">_", "color": Color(0.12, 0.12, 0.12)},
	"mines": {"title": "Field Clearance", "script": "res://terminal/apps/mines_app.gd", "size": Vector2(330, 400), "tile": "FIELD", "color": Color(0.45, 0.5, 0.3)},
	"probe": {"title": "Probe", "script": "res://terminal/apps/probe_app.gd", "size": Vector2(1040, 640), "tile": "PROBE", "color": Color(0.1, 0.35, 0.2)},
}
const TASKBAR_H := 32

var state
var sfx
var windows_layer: Control
var _taskbar_buttons: HBoxContainer
var _tray: HBoxContainer
var _clock: Label
var _battery: Label
var _vpn_btn: Button
var _eye: Control
var _icons: VBoxContainer
var _start_menu: PanelContainer
var _toasts: VBoxContainer
var _badge: Label
var _last_level := 0


func setup(st, sound) -> void:
	state = st
	sfx = sound
	theme = T.make()
	clip_contents = true

	var wall := TextureRect.new()
	wall.texture = Pics.make("dog")
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wall.size = size
	wall.modulate = Color(0.75, 0.75, 0.78)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	wall.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _hide_start())
	add_child(wall)

	_icons = VBoxContainer.new()
	_icons.position = Vector2(14, 14)
	_icons.add_theme_constant_override("separation", 10)
	add_child(_icons)

	windows_layer = Control.new()
	windows_layer.size = Vector2(size.x, size.y - TASKBAR_H)
	windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(windows_layer)

	_build_taskbar()
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(size.x - 380, size.y - TASKBAR_H - 260)
	_toasts.size = Vector2(370, 250)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	state.toast.connect(toast)
	state.message_arrived.connect(func(_c): sfx.play("pip", -8.0))
	state.changed.connect(_refresh)
	_rebuild_icons()
	_refresh()


# ------------------------------------------------------------- icons

func _rebuild_icons() -> void:
	for c in _icons.get_children():
		c.queue_free()
	var ids: Array = ["messages", "browser", "files", "mines"]
	if state.has_flag("console_unlocked"):
		ids.append("console")
	if state.has_flag("probe_installed"):
		ids.append("probe")
	for id in ids:
		_icons.add_child(_make_icon(id))


func _make_icon(id: String) -> Control:
	var a: Dictionary = APPS[id]
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(84, 74)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = "Double-click to open"
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(46, 46)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = a["color"]
	s.border_color = Color(0, 0, 0, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	tile.add_theme_stylebox_override("panel", s)
	var glyph := T.label(str(a["tile"]), 12, Color.WHITE)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.size = Vector2(46, 46)
	tile.add_child(glyph)
	if id == "messages":
		_badge = T.label("", 12, Color.WHITE)
		var bs := StyleBoxFlat.new()
		bs.bg_color = T.DANGER
		bs.set_corner_radius_all(8)
		bs.content_margin_left = 5
		bs.content_margin_right = 5
		_badge.add_theme_stylebox_override("normal", bs)
		_badge.position = Vector2(32, -6)
		tile.add_child(_badge)
	box.add_child(tile)
	var name := T.label(str(a["title"]).split(" ")[0], 13, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name.add_theme_constant_override("shadow_offset_x", 1)
	name.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(name)
	box.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			sfx.play("click")
			if e.double_click:
				open_app(id))
	return box


# ------------------------------------------------------------- windows

func open_app(id: String, arg = null) -> Control:
	_hide_start()
	for w in windows_layer.get_children():
		if w.app_id == id and arg == null:
			_focus(w)
			return w.content.get_child(0)
	var a: Dictionary = APPS[id]
	var w := OsWindow.new()
	windows_layer.add_child(w)
	var n := windows_layer.get_child_count()
	w.position = Vector2(140 + (n % 6) * 34, 30 + (n % 6) * 26)
	w.setup(str(a["title"]), id, a["size"])
	sfx.play("open", -14.0)
	var app: Control = load(str(a["script"])).new()
	w.content.add_child(app)
	app.setup(self, state, arg)
	w.focused.connect(func(): _focus(w))
	w.closed.connect(func(): sfx.play("close", -14.0))
	w.closed.connect(func(): call_deferred("_refresh_taskbar"))
	_focus(w)
	_refresh_taskbar()
	return app


## A plain window holding any control (viewers, dialogs).
func open_window(title: String, body: Control, size_px: Vector2) -> Control:
	var w := OsWindow.new()
	windows_layer.add_child(w)
	w.position = (windows_layer.size - size_px) / 2.0 + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	w.setup(title, "window", size_px)
	w.closed.connect(func(): sfx.play("close", -16.0))
	sfx.play("open", -16.0)
	w.content.add_child(body)
	w.focused.connect(func(): _focus(w))
	_focus(w)
	return w


func _focus(w) -> void:
	w.move_to_front()
	for o in windows_layer.get_children():
		o.set_active(o == w)


func _refresh_taskbar() -> void:
	for c in _taskbar_buttons.get_children():
		c.queue_free()
	for w in windows_layer.get_children():
		if w.is_queued_for_deletion() or w.app_id == "window":
			continue
		var b := Button.new()
		b.text = w.title_label.text
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): _focus(w))
		_taskbar_buttons.add_child(b)


# ------------------------------------------------------------- taskbar + tray

func _build_taskbar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, size.y - TASKBAR_H)
	bar.size = Vector2(size.x, TASKBAR_H)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.78, 0.8, 0.79)
	s.border_color = Color(0.95, 0.95, 0.95)
	s.border_width_top = 2
	bar.add_theme_stylebox_override("panel", s)
	add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(4, 3)
	row.size = Vector2(size.x - 8, TASKBAR_H - 6)
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	var start := Button.new()
	start.text = "HEARTH"
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font_size", 13)
	start.pressed.connect(_toggle_start)
	row.add_child(start)
	_taskbar_buttons = HBoxContainer.new()
	_taskbar_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_taskbar_buttons)
	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 10)
	row.add_child(_tray)
	_vpn_btn = Button.new()
	_vpn_btn.focus_mode = Control.FOCUS_NONE
	_vpn_btn.add_theme_font_size_override("font_size", 12)
	_vpn_btn.pressed.connect(_toggle_vpn)
	_tray.add_child(_vpn_btn)
	var wifi := WifiIcon.new()
	wifi.custom_minimum_size = Vector2(22, 24)
	wifi.tooltip_text = "Wi-Fi: weak (the garage)"
	_tray.add_child(wifi)
	_eye = EyeIcon.new()
	_eye.custom_minimum_size = Vector2(28, 24)
	_eye.tooltip_text = "CitizenCare is protecting you."
	_tray.add_child(_eye)
	_battery = T.label("", 13)
	_tray.add_child(_battery)
	_clock = T.label("", 13)
	_tray.add_child(_clock)

	_start_menu = PanelContainer.new()
	_start_menu.visible = false
	var ms := T.box(Color(0.88, 0.89, 0.87), Color(0.2, 0.22, 0.24), 2, 0)
	_start_menu.add_theme_stylebox_override("panel", ms)
	var col := VBoxContainer.new()
	_start_menu.add_child(col)
	var head := T.label("HEARTH OS 7.2", 13, T.DIM)
	col.add_child(head)
	for item in [["About HEARTH OS", "about"], ["Citizen Portal", "portal"], ["Close the lid (end the night)", "shutdown"]]:
		var b := Button.new()
		b.text = item[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var what: String = item[1]
		b.pressed.connect(func(): _start_item(what))
		col.add_child(b)
	add_child(_start_menu)


func _toggle_start() -> void:
	sfx.play("click")
	_start_menu.visible = not _start_menu.visible
	if _start_menu.visible:
		_start_menu.reset_size()
		_start_menu.position = Vector2(4, size.y - TASKBAR_H - _start_menu.size.y - 2)
		_start_menu.move_to_front()


func _hide_start() -> void:
	if _start_menu:
		_start_menu.visible = false


func _start_item(what: String) -> void:
	_hide_start()
	match what:
		"about":
			var l := RichTextLabel.new()
			l.bbcode_enabled = true
			l.text = "[b]HEARTH OS 7.2[/b]\nState-approved operating system of the Republic of Valdenmark.\n\nThis device is protected by [b]CitizenCare[/b], which keeps you safe by sharing your activity with the people who keep you safe.\n\n[color=#666]Build 7.2.2030-KS. Factory diagnostics: disabled. (Probably.)[/color]"
			l.size_flags_vertical = Control.SIZE_EXPAND_FILL
			open_window("About", l, Vector2(420, 230))
		"portal":
			var b = open_app("browser")
			b.go("netstate.vd/portal")
		"shutdown":
			shutdown_requested.emit()


func _toggle_vpn() -> void:
	sfx.play("toggle")
	if state.vpn_installed() == "":
		return
	if state.has_flag("vpn_on"):
		state.flags.erase("vpn_on")
		state.changed.emit()
	else:
		state.set_flag("vpn_on")


func _refresh() -> void:
	if not is_inside_tree():
		return
	_clock.text = state.datetime_text()
	_battery.text = ("+" if state.plugged else "") + "%d%%" % int(state.battery)
	_battery.add_theme_color_override("font_color", T.DANGER if state.battery < 15 and not state.plugged else T.INK)
	var v: String = state.vpn_installed()
	_vpn_btn.visible = v != ""
	if v != "":
		var on: bool = state.has_flag("vpn_on")
		_vpn_btn.text = ("%s: ON" if on else "%s: off") % ("SafeTunnel" if v == "safetunnel" else "molenet")
	var lvl: int = state.exposure_level()
	_eye.level = lvl
	_eye.dimmed = state.has_flag("vpn_on") or state.has_flag("citizencare_killed")
	if lvl > _last_level:
		_eye.flash()
	_last_level = lvl
	_eye.queue_redraw()
	if _badge:
		var u: int = state.unread_total()
		_badge.text = str(u)
		_badge.visible = u > 0
	var want := 4 + (1 if state.has_flag("console_unlocked") else 0) + (1 if state.has_flag("probe_installed") else 0)
	if _icons.get_child_count() != want:
		_rebuild_icons()


func toast(text: String) -> void:
	if not is_inside_tree():
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(Color(0.12, 0.14, 0.16, 0.95), T.ACCENT if text.begins_with("Secret") else Color(0.4, 0.45, 0.5), 1, 3))
	var l := T.label(text, 13, Color(0.92, 0.93, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	if text.begins_with("Secret"):
		sfx.play("secret", -8.0)
	else:
		sfx.play("notify", -20.0)
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------- tray drawings

class EyeIcon extends Control:
	var level := 0
	var dimmed := false
	var _flash := 0.0

	func flash() -> void:
		_flash = 1.0
		set_process(true)

	func _process(d: float) -> void:
		_flash = maxf(0.0, _flash - d * 0.6)
		queue_redraw()
		if _flash <= 0.0:
			set_process(false)

	func _draw() -> void:
		var c := Vector2(size.x / 2, size.y / 2)
		var base: Color = [Color(0.35, 0.4, 0.42), Color(0.75, 0.6, 0.2), Color(0.85, 0.4, 0.15), Color(0.85, 0.15, 0.12)][level]
		if dimmed:
			base = base.lerp(Color(0.6, 0.62, 0.62), 0.6)
		var col: Color = base.lerp(Color(1, 0.2, 0.1), _flash * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0)))
		var w := 11.0
		var pts := PackedVector2Array()
		for i in 17:
			var t := PI * i / 16.0
			pts.append(c + Vector2(-cos(t) * w, -sin(t) * 6.0))
		for i in 17:
			var t := PI * i / 16.0
			pts.append(c + Vector2(cos(t) * w, sin(t) * 6.0))
		draw_colored_polygon(pts, Color(0.95, 0.95, 0.92))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.15, 0.15, 0.15), 1.5)
		draw_circle(c, 3.0 + level * 0.8, col)
		draw_circle(c, 1.5, Color(0.05, 0.05, 0.05))


class WifiIcon extends Control:
	func _draw() -> void:
		var bars := 2
		for i in 4:
			var h := 4.0 + i * 4.0
			var col := Color(0.15, 0.17, 0.18) if i < bars else Color(0.6, 0.62, 0.62)
			draw_rect(Rect2(2 + i * 5, size.y - 4 - h, 3, h), col)


# ------------------------------------------------------------- loot

const LootCard := preload("res://terminal/loot_card.gd")
var _loot_queue: Array = []
var _loot_open := false


func show_loot(drop: Dictionary) -> void:
	_loot_queue.append(drop)
	if not _loot_open:
		_next_loot()


func _next_loot() -> void:
	if _loot_queue.is_empty():
		_loot_open = false
		return
	_loot_open = true
	var card := LootCard.new()
	card.size = size
	add_child(card)
	card.show_drop(_loot_queue.pop_front(), sfx)
	card.closed.connect(func(): call_deferred("_next_loot"))
