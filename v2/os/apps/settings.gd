extends "res://v2/os/app.gd"
## Preferences: a control panel of icons (reference 1). Appearance really changes the wallpaper;
## the rest are small in-world jokes about who's actually in charge of your computer.

const Tile := preload("res://v2/os/icon_tile.gd")

const ITEMS := [
	["paint", "Appearance"], ["clock", "Date & Time"], ["computer", "Desktop"], ["mouse", "Mouse"],
	["network", "Network"], ["sound", "Sound"], ["user", "Users"], ["lock", "Privacy"],
]
const TEXT := {
	"Date & Time": "Date and time are set by the State.\nThe State is never late.",
	"Desktop": "Desktop icons: on.\nPortrait of the Marshal: on (cannot be changed).",
	"Mouse": "Mouse speed: approved.\nDouble-click speed: approved.",
	"Network": "Connected: StateNet (wired).\nMonitored: yes.\nExternal devices: ignored (whitelist bug #4471, won't fix).",
	"Sound": "System sounds: on.\nNational anthem at boot: scheduled for a future update.",
	"Users": "citizen (you): standard user\nhearthd: supervisor\nroot: none of your business",
	"Privacy": "Privacy settings have been moved.\nThey are now kept safely by the Ministry.",
}

var _grid: HFlowContainer
var _detail: VBoxContainer


func build() -> void:
	var v := vbox()
	var bar := HBoxContainer.new()
	v.add_child(bar)
	bar.add_child(button("All settings", _show_grid))
	var well := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.WIN
	sb.border_color = P.FACE_D
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	well.add_theme_stylebox_override("panel", sb)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(well)
	var stack := Control.new()
	well.add_child(stack)
	_grid = HFlowContainer.new()
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_grid)
	_detail = VBoxContainer.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_detail)
	for it in ITEMS:
		var t: Control = Tile.new()
		t.setup(it[0], it[1], false, Vector2(52, 34))
		t.opened.connect(func() -> void: open_item(it[1]))
		_grid.add_child(t)
	_show_grid()


func _show_grid() -> void:
	_grid.visible = true
	_detail.visible = false
	win.title = "Preferences"
	win.queue_redraw()


func open_item(item: String) -> void:
	_grid.visible = false
	_detail.visible = true
	for c in _detail.get_children():
		c.queue_free()
	win.title = "Preferences - " + item
	win.queue_redraw()
	if item == "Appearance":
		_detail.add_child(P.label("Wallpaper:", P.INK))
		var cur := int(state().os.get("wallpaper", 0))
		for i in P.WALLPAPERS.size():
			var nm: String = P.WALLPAPERS[i]["name"]
			_detail.add_child(button(("(o) " if i == cur else "( ) ") + nm, func() -> void:
				os.set_wallpaper(i)
				open_item("Appearance")))
		_detail.add_child(P.label("Theme: HEARTH Classic (the only theme)", P.INK_DIM))
		return
	_detail.add_child(P.label(str(TEXT.get(item, "")), P.INK, maxf(80.0, size.x - 20.0)))
