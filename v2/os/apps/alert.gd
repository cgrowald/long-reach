extends "res://v2/os/app.gd"
## A message box: icon, text, OK.


func build() -> void:
	var ic: String = get_meta("icon", "info")
	var h := HBoxContainer.new()
	h.position = Vector2(4, 4)
	add_child(h)
	var icon_c := Control.new()
	icon_c.custom_minimum_size = Vector2(18, 18)
	icon_c.draw.connect(func() -> void: P.icon(icon_c, ic, Vector2(1, 1)))
	h.add_child(icon_c)
	var l := P.label(arg, P.INK, 150)
	h.add_child(l)
	var ok := button("OK", func() -> void: win.close())
	ok.custom_minimum_size = Vector2(40, 0)
	add_child(ok)
	# grow the window to fit the text
	await get_tree().process_frame
	var need := maxf(h.size.y + 26.0, 50.0)
	win.size = Vector2(win.size.x, need + 19.0)
	ok.position = Vector2((size.x - 40) * 0.5, size.y - 16)
