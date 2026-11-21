extends VBoxContainer
## Probe: kettle's network tool. Pick a target, then map it, type commands, watch the trace meter.
## Rules live in sim/lab_state.gd; this is only the screen.

const T := preload("res://terminal/os_theme.gd")
const LabState := preload("res://sim/lab_state.gd")
const HINT_AFTER := 30.0
const GREEN := Color(0.55, 0.95, 0.6)
const BG := Color(0.04, 0.05, 0.05)

var desk
var state
var lab
var _top: HBoxContainer
var _title: Label
var _trace: ProgressBar
var _trace_label: Label
var _assist: CheckButton
var _body: Control
var _map: MapView
var _out: RichTextLabel
var _hint: Label
var _chips: HFlowContainer
var _patterns: HBoxContainer
var _input: LineEdit
var _idle := 0.0


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = BG
	_top = HBoxContainer.new()
	add_child(_top)
	_title = T.label("PROBE", 15)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(_title)
	_trace_label = T.label("", 13, T.DIM)
	_top.add_child(_trace_label)
	_trace = ProgressBar.new()
	_trace.custom_minimum_size = Vector2(180, 18)
	_trace.max_value = 100
	_trace.show_percentage = false
	_top.add_child(_trace)
	_assist = CheckButton.new()
	_assist.text = "Assist"
	_assist.focus_mode = Control.FOCUS_NONE
	_assist.button_pressed = state.has_flag("assist")
	_assist.tooltip_text = "Buttons for commands you already know. You still need the plan."
	_assist.toggled.connect(func(on):
		state.flags["assist"] = on
		_refresh())
	_top.add_child(_assist)
	var hb := Button.new()
	hb.text = "Hint"
	hb.focus_mode = Control.FOCUS_NONE
	hb.pressed.connect(func(): _show_hint(true))
	_top.add_child(hb)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_show_targets()


func _process(d: float) -> void:
	if lab == null or lab.ended:
		return
	_idle += d
	if _idle > HINT_AFTER and _hint.text == "":
		_show_hint(false)


func _exit_tree() -> void:
	# Closing the window mid-lab = yanking the cable. Logs stay behind.
	if lab != null and not lab.ended:
		lab.run("logout")
		state.flags.erase("lab_active")


# ------------------------------------------------------------- target list

func _show_targets() -> void:
	for c in _body.get_children():
		c.queue_free()
	_title.text = "PROBE  -  targets"
	_trace.visible = false
	_trace_label.text = ""
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_body.add_child(box)
	box.add_child(T.label("Known weak systems:", 15, T.DIM))
	var any := false
	if state.has_flag("annex_known"):
		any = true
		var row := HBoxContainer.new()
		var lab_def: Dictionary = LabState.load_lab("annex")
		var name := T.label("%s   -   %s" % [lab_def.get("name", "Annex"), lab_def.get("blurb", "")], 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		if state.has_flag("annex_burned"):
			row.add_child(T.label("PATCHED (they traced you)", 14, T.DANGER))
		elif state.has_flag("annex_done"):
			row.add_child(T.label("done", 14, T.DIM))
		else:
			var b := Button.new()
			b.text = "Connect"
			b.pressed.connect(func(): _connect("annex"))
			row.add_child(b)
		box.add_child(row)
	if not any:
		var l := T.label("No targets yet. People on lantern talk about weak systems. Listen to them.", 14, T.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	if not state.patterns.is_empty():
		box.add_child(T.label("Your patterns: " + ", ".join(state.patterns.keys()), 13, T.DIM))


# ------------------------------------------------------------- the lab screen

func _connect(id: String) -> void:
	desk.sfx.play("chime", -14.0)
	lab = LabState.new(state, id)
	state.flags["lab_active"] = true
	for c in _body.get_children():
		c.queue_free()
	_title.text = "PROBE  -  %s" % lab.lab.get("name", id)
	_trace.visible = true
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 6)
	_body.add_child(split)
	var map_bg := PanelContainer.new()
	map_bg.custom_minimum_size = Vector2(400, 0)
	map_bg.add_theme_stylebox_override("panel", T.box(BG, Color(0.2, 0.35, 0.25), 1, 0))
	split.add_child(map_bg)
	_map = MapView.new()
	_map.lab = lab
	_map.node_clicked.connect(_on_node_clicked)
	map_bg.add_child(_map)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var out_bg := PanelContainer.new()
	out_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out_bg.add_theme_stylebox_override("panel", T.box(BG, Color(0.2, 0.35, 0.25), 1, 0))
	right.add_child(out_bg)
	_out = RichTextLabel.new()
	_out.scroll_following = true
	_out.selection_enabled = true
	_out.add_theme_font_override("normal_font", T.mono())
	_out.add_theme_font_size_override("normal_font_size", 14)
	_out.add_theme_color_override("default_color", GREEN)
	out_bg.add_child(_out)
	_hint = T.label("", 13, Color(0.85, 0.7, 0.25))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint)
	_chips = HFlowContainer.new()
	right.add_child(_chips)
	_patterns = HBoxContainer.new()
	right.add_child(_patterns)
	_input = LineEdit.new()
	_input.placeholder_text = "type a command (Tab completes)"
	_input.add_theme_font_override("font", T.mono())
	_input.add_theme_stylebox_override("normal", T.box(BG, Color(0.2, 0.4, 0.25), 1, 0))
	_input.add_theme_stylebox_override("focus", T.box(BG, Color(0.3, 0.7, 0.4), 1, 0))
	_input.add_theme_color_override("font_color", GREEN)
	_input.add_theme_color_override("caret_color", GREEN)
	_input.text_submitted.connect(_submit)
	_input.gui_input.connect(_input_keys)
	right.add_child(_input)
	_print("PROBE v0.9 (kettle's build)  -  connected through NetState")
	_print("Target: %s" % lab.lab.get("blurb", ""))
	_print("Every command makes noise. At 100%% trace you're out.  Type 'help' or 'hint'.\n")
	_refresh()
	_input.grab_focus.call_deferred()


func _print(s: String, col: Color = GREEN) -> void:
	_out.push_color(col)
	_out.add_text(s + "\n")
	_out.pop()


func _input_keys(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_TAB:
		_input.text = lab.complete(_input.text)
		_input.caret_column = _input.text.length()
		_input.accept_event()


func _submit(line: String) -> void:
	if lab == null or lab.ended:
		return
	_input.clear()
	var secret: bool = lab.waiting_password()
	_print("> " + ("*".repeat(line.length()) if secret else line), Color(0.8, 0.85, 0.8))
	_handle(lab.run(line))


func _handle(r: Dictionary) -> void:
	for l in r["lines"]:
		_print(str(l), GREEN if r["ok"] else Color(1.0, 0.55, 0.45))
	if r["ok"]:
		_idle = 0.0
		_hint.text = ""
	else:
		desk.sfx.play("error", -14.0)
	for drop in r["drops"]:
		desk.show_loot(drop)
	if lab.ended:
		state.flags.erase("lab_active")
		_input.editable = false
		_print("\n[session over - close Probe or pick another target]", Color(0.85, 0.7, 0.25))
		if lab.outcome == "burned":
			desk.sfx.play("error")
	_refresh()


func _refresh() -> void:
	if lab == null:
		return
	_trace.value = lab.trace
	var col := Color(0.4, 0.8, 0.45) if lab.trace < 50 else (Color(0.9, 0.7, 0.2) if lab.trace < 80 else Color(0.9, 0.25, 0.2))
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	_trace.add_theme_stylebox_override("fill", fill)
	_trace_label.text = "TRACE %d%%  " % int(lab.trace)
	_input.secret = lab.waiting_password()
	_input.placeholder_text = "password" if lab.waiting_password() else "type a command (Tab completes)"
	_map.queue_redraw()
	for c in _chips.get_children():
		c.queue_free()
	for c in _patterns.get_children():
		c.queue_free()
	_chips.visible = _assist.button_pressed
	if _assist.button_pressed and not lab.ended:
		for cmd in state.learned:
			if str(cmd).begins_with("pattern:"):
				continue
			var b := Button.new()
			b.text = str(cmd)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			var word: String = str(cmd)
			b.pressed.connect(func(): _chip(word))
			_chips.add_child(b)
	if not state.patterns.is_empty() and not lab.ended:
		_patterns.add_child(T.label("Patterns:", 12, T.DIM))
		for p in state.patterns:
			var b := Button.new()
			b.text = "%s on <device>" % p
			b.tooltip_text = "Click a device on the map first, then this."
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			var pname: String = str(p)
			b.pressed.connect(func(): _run_pattern(pname))
			_patterns.add_child(b)


func _chip(word: String) -> void:
	desk.sfx.play("click")
	var rest := _input.text.strip_edges()
	var toks := rest.split(" ", false)
	# A chip replaces the command word but keeps the device you already picked.
	if toks.size() > 0 and lab.discovered.has(toks[toks.size() - 1]):
		_input.text = word + " " + toks[toks.size() - 1]
	else:
		_input.text = word + " "
	_input.caret_column = _input.text.length()
	_input.grab_focus()


func _on_node_clicked(n: String) -> void:
	desk.sfx.play("click")
	_map.selected = n
	var toks := _input.text.strip_edges().split(" ", false)
	if toks.size() == 1 and not lab.discovered.has(toks[0]):
		_input.text = toks[0] + " " + n + " "
	else:
		_input.text = n
	_input.caret_column = _input.text.length()
	_input.grab_focus()
	_map.queue_redraw()


func _run_pattern(p: String) -> void:
	if _map.selected == "":
		_print("Pick a device on the map first.", Color(1.0, 0.55, 0.45))
		return
	# The steps type themselves, fast, with a rattle.
	for i in 6:
		desk.sfx.play("key", -12.0)
	_handle(lab.run_pattern(p, _map.selected))


func _show_hint(asked: bool) -> void:
	if lab == null or lab.ended:
		return
	var h: String = lab.hint()
	if h != "":
		_hint.text = "kettle (in your head): " + h
		if asked:
			desk.sfx.play("notify", -16.0)


# ------------------------------------------------------------- the map

class MapView extends Control:
	signal node_clicked(n: String)
	var lab
	var selected := ""
	const BOX := Vector2(104, 30)

	func _ready() -> void:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(380, 300)

	func _pos(n: String) -> Vector2:
		if n == "you":
			return Vector2(size.x * 0.12, size.y * 0.08) + Vector2(0, 0)
		var p: Array = lab.node_def(n).get("pos", [0.5, 0.5])
		return Vector2(float(p[0]) * size.x + 30, float(p[1]) * size.y + 30)

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(8, size.y - 8), "click a device to target it", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.5, 0.35))
		for l in lab.lab.get("links", []):
			var a: String = l[0]
			var b: String = l[1]
			if lab.discovered.has(a) and lab.discovered.has(b):
				draw_line(_pos(a), _pos(b), Color(0.2, 0.5, 0.3), 2.0)
		for n in lab.discovered:
			var c := _pos(n)
			var r := Rect2(c - BOX / 2, BOX)
			var col := Color(0.25, 0.3, 0.28)
			if n == "you":
				col = Color(0.2, 0.35, 0.55)
			elif lab.locked.has(n):
				col = Color(0.55, 0.15, 0.12)
			elif lab.access.has(n):
				col = Color(0.15, 0.5, 0.25)
			draw_rect(r, col)
			draw_rect(r, Color(0.9, 0.9, 0.5) if n == selected else Color(0.4, 0.7, 0.5), false, 2.0 if n == selected else 1.0)
			var label: String = "YOU" if n == "you" else str(lab.node_def(n).get("label", n))
			draw_string(f, Vector2(r.position.x + 6, c.y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, BOX.x - 8, 12, Color(0.85, 1.0, 0.85))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for n in lab.discovered:
				if n != "you" and Rect2(_pos(n) - BOX / 2, BOX).has_point(e.position):
					node_clicked.emit(n)
					return
