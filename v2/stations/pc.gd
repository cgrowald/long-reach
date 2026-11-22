extends "res://v2/stations/station.gd"
## The PC: HEARTH GNU/State desktop on the CRT. Apps open placeholder windows from data/v2/world.json.

const Crt := preload("res://v2/ui/crt_screen.gd")

var _crt
var _win: Control
var _paid := false


func build() -> void:
	_crt = Crt.new()
	add_child(_crt)
	_crt.place(Rect2(Vector2(36, 14), size - Vector2(72, 28)))
	var top := Kit.label("HEARTH GNU/State 4.1   citizen terminal   %s" % game.state.clock_text(), Pal.PHOS, 8)
	top.position = Vector2(10, 8)
	_crt.add_child(top)
	var icons := VBoxContainer.new()
	icons.position = Vector2(10, 26)
	_crt.add_child(icons)
	for app in Content.world().get("apps", []):
		var a: Dictionary = app
		var locked: bool = a.get("locked", false) and not game.state.unlocked.has("hatch")
		var b := Kit.button(("[ ] " if locked else "[>] ") + a["name"], func() -> void: _open(a, locked), game)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.x = 82
		icons.add_child(b)
	var hint := Kit.label("Esc: lean back", Pal.SCREEN_LINE.lightened(0.3), 8)
	hint.position = Vector2(10, _crt.size.y - 16)
	_crt.add_child(hint)
	game.sfx.play("maximize_006", 0.8, -10.0)


func _open(app: Dictionary, locked: bool) -> void:
	if locked:
		game.deny()
		garage.toast("Locked. Needs a cell and the war room.")
		return
	if app["id"] == "war":
		garage.open_screen("warroom")
		return
	if not _paid:
		if not garage.spend(def.get("hours", 0.5)):
			return
		_paid = true
	if _win:
		_win.queue_free()
	_win = PanelContainer.new()
	_win.position = Vector2(104, 26)
	_win.custom_minimum_size = Vector2(_crt.size.x - 120, _crt.size.y - 50)
	_crt.add_child(_win)
	var v := VBoxContainer.new()
	_win.add_child(v)
	var bar := Kit.row(v)
	var t := Kit.label(app["name"].to_upper(), Pal.PHOS, 10)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	bar.add_child(Kit.button("x", func() -> void: back(), game))
	v.add_child(HSeparator.new())
	for line in app.get("lines", []):
		v.add_child(Kit.label(str(line), Pal.TEXT, 9, _crt.size.x - 140))
	v.add_child(Kit.label("(placeholder app)", Pal.DIM, 8))
	game.sfx.play("open_001", 1.1, -10.0)
	_crt.shake(1.5)


func back() -> bool:
	if _win and is_instance_valid(_win):
		_win.queue_free()
		_win = null
		game.sfx.play("close_001", 1.0, -10.0)
		return true
	return false
