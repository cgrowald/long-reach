extends Control
## The garage at night: a pixel-art 3D room (terminal/room3d.gd) with the laptop OS rendered into a
## viewport that shows on the 3D screen and, when you lean in, as a crisp overlay you can use.
## Also runs the night clock, boot/login, the day cards between nights, and the end summary.

const T := preload("res://terminal/os_theme.gd")
const State := preload("res://sim/terminal_state.gd")
const Desktop := preload("res://terminal/desktop.gd")
const DayCard := preload("res://terminal/day_card.gd")
const Sfx := preload("res://terminal/sfx.gd")
const Room3D := preload("res://terminal/room3d.gd")

const SCREEN := Rect2(144, 26, 1312, 738)
const MIN_PER_SEC := 1.0     # laptop clock: one game minute per real second
const PIXEL := 3             # the 3D room renders at 1/3 resolution for the pixel-art look

var state
var sfx
var screen: Control
var desktop: Control
var room
var _room_box: SubViewportContainer
var _os_box: SubViewportContainer
var _os_vp: SubViewport
var _desk_row: HBoxContainer
var _hint: Label
var _lean_btn: Button
var _hover: Label
var _overlay: Control
var _debug: Label
var _acc := 0.0
var _night_running := false
var _ticks_backtick: Array = []
var _login_stage := false
var _boot_tween: Tween


func _ready() -> void:
	theme = T.make()
	sfx = Sfx.new()
	add_child(sfx)
	state = State.new()
	var vs := get_viewport_rect().size

	# The OS lives in its own viewport so it can be shown on the 3D laptop and as an overlay.
	_os_box = SubViewportContainer.new()
	_os_box.position = SCREEN.position
	_os_box.size = SCREEN.size
	_os_box.stretch = true
	_os_vp = SubViewport.new()
	_os_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_os_vp.gui_embed_subwindows = false
	_os_box.add_child(_os_vp)
	screen = Control.new()
	screen.size = SCREEN.size
	screen.clip_contents = true
	screen.theme = T.make()
	_os_vp.add_child(screen)

	# The garage, rendered small and scaled up with hard pixels.
	_room_box = SubViewportContainer.new()
	_room_box.size = vs
	_room_box.stretch = true
	_room_box.stretch_shrink = PIXEL
	_room_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rvp := SubViewport.new()
	rvp.msaa_3d = Viewport.MSAA_DISABLED
	_room_box.add_child(rvp)
	add_child(_room_box)
	room = Room3D.new()
	rvp.add_child(room)
	room.setup(_os_vp.get_texture())
	room.arrived.connect(_on_camera_arrived)
	add_child(_os_box)
	_show_os(false)

	_build_hud()
	_debug = T.label("", 12, Color(0.6, 1.0, 0.6))
	_debug.position = Vector2(8, 8)
	_debug.visible = false
	add_child(_debug)
	_title()


# ------------------------------------------------------------- the room

func _build_hud() -> void:
	_desk_row = HBoxContainer.new()
	_desk_row.position = Vector2(30, 846)
	_desk_row.size = Vector2(1540, 44)
	_desk_row.add_theme_constant_override("separation", 14)
	add_child(_desk_row)
	_hint = T.label("", 15, Color(0.8, 0.78, 0.7))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_desk_row.add_child(_hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desk_row.add_child(spacer)
	_lean_btn = _hud_button("Lean back  (Esc)", Color(0.22, 0.24, 0.26))
	_lean_btn.pressed.connect(_lean_back)
	var lid := _hud_button("Close the lid  (end the night)", Color(0.35, 0.2, 0.18))
	lid.pressed.connect(_close_lid)
	_desk_row.visible = false
	_hover = T.label("", 15, Color(1.0, 0.92, 0.7))
	_hover.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_hover.add_theme_constant_override("shadow_offset_x", 2)
	_hover.add_theme_constant_override("shadow_offset_y", 2)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover)


func _hud_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", T.box(col, col.lightened(0.25), 1, 3))
	b.add_theme_stylebox_override("hover", T.box(col.lightened(0.1), Color(1, 0.9, 0.6), 1, 3))
	b.add_theme_stylebox_override("pressed", T.box(col.darkened(0.2), Color(1, 0.9, 0.6), 1, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(0.95, 0.93, 0.88))
	_desk_row.add_child(b)
	return b


func _show_os(on: bool) -> void:
	_os_box.modulate.a = 1.0 if on else 0.0
	_os_box.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if not on:
		_os_vp.gui_release_focus()
	if _lean_btn:
		_lean_btn.visible = on
		_hint.text = "" if on else "A / D  look around      click things      click the laptop to use it"
	if _hover:
		_hover.text = ""


func _use_laptop(instant: bool = false) -> void:
	_close_overlay()
	room.use_laptop(SCREEN, get_viewport_rect().size, instant)


func _lean_back() -> void:
	if not room.using_laptop:
		return
	_show_os(false)
	room.look_view("laptop")


func _on_camera_arrived(v: String) -> void:
	if v == "use":
		_show_os(true)


func _refresh_desk() -> void:
	room.set_visible_node("Charger_Cable", state.plugged)


func _toggle_charger() -> void:
	state.plugged = not state.plugged
	sfx.play("toggle")
	_refresh_desk()
	state.toast.emit("Charger plugged in." if state.plugged else "Charger unplugged.")
	state.changed.emit()


func _interact(id: String) -> void:
	match id:
		"laptop":
			if _night_running or _login_stage:
				sfx.play("click")
				_use_laptop()
		"notebook":
			_show_notebook()
		"sticky":
			_show_sticky()
		"charger":
			_toggle_charger()
		"":
			pass
		_:
			var t: Dictionary = room.things.get(id, {})
			var text: String = str(t.get("text", ""))
			var alt: Dictionary = t.get("text_if", {})
			if not alt.is_empty() and state.has_flag(str(alt.get("flag", ""))):
				text = str(alt["text"])
			sfx.play("paper")
			_paper(str(t.get("name", id)), [text])


func _gui_input(e: InputEvent) -> void:
	if room == null or room.using_laptop or not _desk_row.visible:
		return
	if e is InputEventMouseMotion:
		var id: String = room.pick(e.position / PIXEL)
		_hover.text = str(room.things.get(id, {}).get("name", "")) if id != "" else ""
		_hover.position = e.position + Vector2(18, 10)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_interact(room.pick(e.position / PIXEL))


func _paper(title: String, lines: Array) -> void:
	_close_overlay()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(Color(0.93, 0.9, 0.8), Color(0.5, 0.45, 0.35), 2, 2))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	col.add_child(T.label(title, 20, Color(0.2, 0.18, 0.14)))
	for l in lines:
		var lab := T.label(str(l), 17, Color(0.15, 0.2, 0.45))
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(520, 0)
		col.add_child(lab)
	var close := Button.new()
	close.text = "Put it down"
	close.pressed.connect(_close_overlay)
	col.add_child(close)
	add_child(p)
	p.reset_size()
	p.position = Vector2(60, 830 - p.size.y)
	_overlay = p


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _show_notebook() -> void:
	sfx.play("paper")
	_paper("Notebook", state.notebook if not state.notebook.is_empty() else ["(empty)"])


func _show_sticky() -> void:
	sfx.play("paper")
	if state.sticky == "":
		_paper("Sticky note", ["Blank. You kept your password in your head."])
	else:
		_paper("Sticky note on the bench", ["laptop: " + state.sticky])


# ------------------------------------------------------------- flow

func _clear_screen() -> void:
	if _boot_tween and _boot_tween.is_valid():
		_boot_tween.kill()
	for c in screen.get_children():
		c.queue_free()
	desktop = null


func _title() -> void:
	_night_running = false
	_desk_row.visible = false
	var card := DayCard.new()
	add_child(card)
	var opts: Array = [{"text": "New game"}]
	if State.has_save():
		opts.insert(0, {"text": "Continue (day %d)" % _saved_day()})
	card.show_title("UPRISING", "T1 prototype: the laptop\n\nA terminal-only slice of the first week. Headphones recommended.", opts)
	card.chosen.connect(func(i):
		card.queue_free()
		if State.has_save() and i == 0:
			state.load_save()
		else:
			State.delete_save()
			state.new_game()
		_start_day())


func _saved_day() -> int:
	var tmp = State.new()
	tmp.load_save()
	return tmp.day


func _start_day() -> void:
	if state.is_over():
		_summary()
		return
	_clear_screen()
	_desk_row.visible = false
	var card := DayCard.new()
	add_child(card)
	card.play(state, state.day_def().get("card", []))
	card.finished.connect(func():
		card.queue_free()
		_boot())


func _boot() -> void:
	_clear_screen()
	_desk_row.visible = true
	_refresh_desk()
	_use_laptop(true)
	sfx.play("lid", -6.0)
	sfx.fan(true)
	var bios := RichTextLabel.new()
	bios.size = SCREEN.size
	bios.add_theme_font_override("normal_font", T.mono())
	bios.add_theme_font_size_override("normal_font_size", 16)
	bios.add_theme_color_override("default_color", Color(0.75, 0.78, 0.8))
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.size = SCREEN.size
	screen.add_child(bg)
	bg.add_child(bios)
	var lines := ["LUMO BIOS v2.11   (c) State Electronics Combine", "", "CPU ........ OK", "Memory ..... 4096 MB OK",
		"Battery .... %d%%" % int(state.battery), "Network .... weak signal", "", "Loading HEARTH OS 7.2 ..."]
	sfx.play("beep", -12.0)
	var tw := create_tween()
	_boot_tween = tw
	for l in lines:
		tw.tween_callback(func():
			if is_instance_valid(bios):
				bios.add_text(l + "\n"))
		tw.tween_interval(0.16)
	tw.tween_interval(0.4)
	tw.tween_callback(_logo)
	bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and tw.is_valid():
			tw.kill()
			_logo())


func _logo() -> void:
	_clear_screen()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.2, 0.23)
	bg.size = SCREEN.size
	screen.add_child(bg)
	var l := T.label("HEARTH OS", 52, Color(0.92, 0.94, 0.9))
	l.position = Vector2(SCREEN.size.x / 2 - 150, SCREEN.size.y / 2 - 70)
	bg.add_child(l)
	var s := T.label("A connected citizen is a safe citizen.", 18, Color(0.7, 0.8, 0.8))
	s.position = Vector2(SCREEN.size.x / 2 - 160, SCREEN.size.y / 2)
	bg.add_child(s)
	sfx.play("chime", -12.0)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(_login)


func _login() -> void:
	_clear_screen()
	_login_stage = true
	_ticks_backtick.clear()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.2, 0.23)
	bg.size = SCREEN.size
	screen.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(SCREEN.size.x / 2 - 170, SCREEN.size.y / 2 - 110)
	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 10)
	bg.add_child(box)
	var creating: bool = state.password == ""
	box.add_child(T.label("Welcome" if not creating else "Set up this device", 26, Color.WHITE))
	box.add_child(T.label("User: tomas" if not creating else "Choose a password for user 'tomas':", 15, Color(0.75, 0.82, 0.82)))
	var le := LineEdit.new()
	le.secret = true
	le.placeholder_text = "password"
	box.add_child(le)
	var write_down := CheckBox.new()
	write_down.text = "Write it on a sticky note on the bench"
	write_down.add_theme_color_override("font_color", Color(0.85, 0.88, 0.88))
	write_down.visible = creating
	box.add_child(write_down)
	var err := T.label("", 14, Color(1.0, 0.55, 0.5))
	err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(err)
	var go := Button.new()
	go.text = "Log in" if not creating else "Save password"
	box.add_child(go)
	var forgot := Button.new()
	forgot.text = "Forgot password?"
	forgot.visible = false
	box.add_child(forgot)
	var fails := [0]
	var submit := func(_t = ""):
		if creating:
			if le.text.length() < 3:
				sfx.play("error")
				err.text = "At least 3 characters."
				return
			state.password = le.text
			if write_down.button_pressed:
				state.sticky = le.text
			_refresh_desk()
			_enter_desktop()
		elif le.text == state.password:
			_enter_desktop()
		else:
			fails[0] += 1
			sfx.play("error")
			err.text = "Incorrect password."
			le.clear()
			forgot.visible = fails[0] >= 3
	go.pressed.connect(submit)
	le.text_submitted.connect(submit)
	forgot.pressed.connect(func():
		err.text = "Visit any Citizen Service Center with your ID card and this device. A technician will reset it.\n(They will make a copy of everything on it. For your safety.)"
		var reset := Button.new()
		reset.text = "Take it to the Service Center (lose a day's pay, and your privacy)"
		box.add_child(reset)
		forgot.visible = false
		reset.pressed.connect(func():
			state.add_exposure(3, "had the Citizen Service Center reset your laptop (they kept a copy)")
			state.password = ""
			_login()))
	le.grab_focus.call_deferred()


func _enter_desktop() -> void:
	_login_stage = false
	_clear_screen()
	sfx.play("chime", -10.0)
	desktop = Desktop.new()
	desktop.size = SCREEN.size
	screen.add_child(desktop)
	desktop.setup(state, sfx)
	desktop.shutdown_requested.connect(_close_lid)
	state.begin_night()
	_night_running = true


func _process(d: float) -> void:
	if not _night_running:
		return
	_acc += d * MIN_PER_SEC
	if state.has_flag("lab_active"):
		_acc = 0.0   # during a hacking lab, time moves per command instead
	if _acc >= 1.0:
		var n := int(_acc)
		_acc -= n
		if state.battery < 15.0 and not state.plugged:
			state.flags["battery_low"] = true
		if state.advance(n):
			_forced_end()
	if _debug.visible:
		_debug.text = "DEBUG (F9)  day %d  %s  exposure %d (lvl %d)  followers %d  battery %.1f\nflags: %s\nsecrets: %s" % [
			state.day, state.clock_text(), state.exposure, state.exposure_level(), state.followers, state.battery,
			", ".join(state.flags.keys().filter(func(k): return not str(k).begins_with("visited:"))), ", ".join(state.secrets.values())]


func _forced_end() -> void:
	_night_running = false
	var why := "The screen goes black. The battery is dead.\n\nAnything you hadn't finished is gone." if state.battery <= 0.0 \
		else "You wake up at the bench with your cheek on the keyboard. It's almost dawn."
	if state.battery <= 0.0:
		state.log_lines.append("The battery died on day %d." % state.day)
	_end_night(why)


func _close_lid() -> void:
	if not _night_running:
		return
	_night_running = false
	_end_night("")


func _end_night(note: String) -> void:
	_close_overlay()
	sfx.play("lid", -6.0)
	sfx.fan(false)
	_clear_screen()
	_show_os(false)
	room.look_view("laptop")
	_desk_row.visible = false
	var more: bool = state.end_night()
	if note != "":
		var card := DayCard.new()
		add_child(card)
		card.play(state, [{"text": note}])
		card.finished.connect(func():
			card.queue_free()
			if more:
				_start_day()
			else:
				_summary())
	elif more:
		_start_day()
	else:
		_summary()


func _summary() -> void:
	_clear_screen()
	_desk_row.visible = false
	var lines: Array = []
	lines.append("You made it through the first four nights.")
	lines.append("")
	lines.append("HOW VISIBLE YOU ARE: " + ["barely noticed", "watched", "noticed - a file has your name on it", "hunted"][state.exposure_level()])
	lines.append("Followers on lantern: %d" % state.followers)
	if state.has_flag("pavel_capital"):
		lines.append("Pavel: moved from Station 4 to the CAPITAL, Facility 1, on 3 October.")
	elif state.has_flag("found_pavel"):
		lines.append("Pavel: transferred to STATION 4, Grenz Road." + ("  You have proof." if state.has_flag("station4_proof") else ""))
	else:
		lines.append("Pavel: still no record.")
	lines.append("")
	lines.append("WHAT THE MINISTRY KNOWS ABOUT YOU:")
	var ex: Array = state.log_lines.filter(func(l): return str(l).begins_with("Exposure"))
	if ex.is_empty():
		lines.append("   Nothing. Yet.")
	for l in ex:
		lines.append("   " + str(l).substr(str(l).find(":") + 2))
	if state.convos.get("hana", {}).get("log", []).size() > 0 and not state.has_flag("deleted_hana"):
		lines.append("   Hana's messages are still on your laptop. She asked you to delete them.")
	lines.append("")
	if state.has_flag("annex_done") or state.has_flag("annex_burned"):
		lines.append("THE ANNEX: " + ("they traced you and patched the kiosk." if state.has_flag("annex_burned") else "you got in and out."))
	if state.has_flag("duda_locked"):
		lines.append("   Mrs. Duda (Lena's teacher) will be questioned about her password tomorrow.")
	for l in state.loot:
		lines.append("   LOOT: %s  %s" % ["*".repeat(int(l["stars"])), l["name"]])
	lines.append("")
	lines.append("SECRETS FOUND: %d of 7" % state.secrets.size())
	for s in state.secrets.values():
		lines.append("   " + str(s))
	lines.append("")
	lines.append("This is where T1 ends. Tell Claude what was fun, what was confusing, and what you wanted to do but couldn't.")
	var card := DayCard.new()
	add_child(card)
	card.show_title("END OF T1", "\n".join(lines), [{"text": "Back to title"}])
	card.chosen.connect(func(_i):
		card.queue_free()
		_title())


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F9:
			_debug.visible = not _debug.visible
		if e.keycode == KEY_ESCAPE:
			if is_instance_valid(_overlay):
				_close_overlay()
			elif room.using_laptop and _desk_row.visible:
				_lean_back()
		if not room.using_laptop and _desk_row.visible:
			if e.keycode in [KEY_A, KEY_LEFT]:
				_close_overlay()
				room.turn(-1)
			elif e.keycode in [KEY_D, KEY_RIGHT]:
				_close_overlay()
				room.turn(1)


func _input(e: InputEvent) -> void:
	# The factory dev console: triple-tap the backtick on the login screen.
	if _login_stage and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_QUOTELEFT:
		var now := Time.get_ticks_msec()
		_ticks_backtick.append(now)
		_ticks_backtick = _ticks_backtick.filter(func(t): return now - int(t) < 1500)
		if _ticks_backtick.size() >= 3 and not state.has_flag("console_unlocked"):
			state.set_flag("console_unlocked")
			state.find_secret("console", "The factory dev console")
			sfx.play("secret", -8.0)
		get_viewport().set_input_as_handled()
	if desktop != null and e is InputEventKey and e.pressed and not e.echo and e.keycode != KEY_F9:
		if e.unicode > 0:
			sfx.play("key", -16.0)
