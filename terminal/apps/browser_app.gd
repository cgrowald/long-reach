extends VBoxContainer
## NetState Browser: the state internet, plus whatever addresses you've learned to type.

const T := preload("res://terminal/os_theme.gd")

var desk
var state
var _addr: LineEdit
var _bar: ProgressBar
var _page: RichTextLabel
var _extra: VBoxContainer
var _history: Array = []
var _current: String = ""
var _loading := 0.0
var _load_total := 0.0
var _pending: String = ""


func setup(d, st, arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	add_child(top)
	for b in [["<", _back], ["Home", func(): go(str(state.sites.get("home", "netstate.vd")))]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		top.add_child(btn)
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.text_submitted.connect(func(t): go(t))
	top.add_child(_addr)
	var gob := Button.new()
	gob.text = "Go"
	gob.focus_mode = Control.FOCUS_NONE
	gob.pressed.connect(func(): go(_addr.text))
	top.add_child(gob)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 4)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	add_child(_bar)
	_extra = VBoxContainer.new()
	add_child(_extra)
	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", T.box(Color(0.99, 0.99, 0.98), Color(0.6, 0.62, 0.62), 1, 0))
	add_child(bg)
	_page = RichTextLabel.new()
	_page.bbcode_enabled = true
	_page.selection_enabled = true
	_page.meta_clicked.connect(_link)
	_page.meta_underlined = true
	bg.add_child(_page)
	go(str(arg) if arg != null else str(state.sites.get("home", "netstate.vd")))


func _process(d: float) -> void:
	if _pending == "":
		return
	_loading += d
	_bar.value = clampf(_loading / _load_total, 0.0, 1.0)
	if _loading >= _load_total:
		var a := _pending
		_pending = ""
		_bar.value = 0.0
		_render(a)


func go(addr: String, push: bool = true) -> void:
	var a: String = state.normalize_addr(addr)
	if a == "":
		return
	if push and _current != "" and _current != a:
		_history.append(_current)
	_addr.text = a
	_pending = a
	_loading = 0.0
	# The garage Wi-Fi is weak; molenet is slow; SafeTunnel is suspiciously fast.
	_load_total = randf_range(0.35, 1.0)
	if state.has_flag("vpn_on"):
		_load_total *= 2.2 if state.vpn_installed() == "molenet" else 0.6
	for c in _extra.get_children():
		c.queue_free()
	_page.text = "[color=#888]Loading %s ...[/color]" % a


func _back() -> void:
	if _history.is_empty():
		return
	go(_history.pop_back(), false)


func _render(a: String) -> void:
	_current = a
	for c in _extra.get_children():
		c.queue_free()
	var p: Dictionary = state.page(a)
	if p.is_empty():
		desk.sfx.play("error")
		_page.text = "[font_size=18][b]Page not found[/b][/font_size]\n\nNetState could not find [b]%s[/b].\n\n[color=#888]Check the address. Only approved addresses are available.[/color]" % a
		return
	if p.get("blocked", false):
		state.visit(a)
		desk.sfx.play("error")
		_page.text = "[center]\n\n[font_size=26][color=#b02020][b]BLOCKED[/b][/color][/font_size]\n\nThis page is blocked by order of the Ministry of Information.\n\n[b]Your visit has been recorded.[/b][/center]"
		return
	if p.has("login") and not state.has_flag("forum_login"):
		_login_form(a, str(p["login"]))
		return
	state.visit(a)
	if p.get("search", false):
		_search_form("")
	var body: String = str(p.get("body", ""))
	if body.contains("{NEWS}"):
		var news := ""
		for n in state.day_def().get("news", []):
			news += "  - %s\n" % str(n)
		body = body.replace("{NEWS}", news)
	if p.get("compose", false):
		body += _posts_text()
		_compose_form()
	_page.text = body


func _link(meta) -> void:
	var m := str(meta)
	desk.sfx.play("click")
	if m.begins_with("go:"):
		go(m.substr(3))
	elif m.begins_with("dl:"):
		state.add_lib_file(m.substr(3))


# ------------------------------------------------------------- forms

func _login_form(a: String, pw: String) -> void:
	_page.text = "[center]\n\n[font_size=22][b]lantern[/b][/font_size]\n\n[color=#888]members only[/color][/center]"
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(T.label("password: "))
	var le := LineEdit.new()
	le.secret = true
	le.custom_minimum_size = Vector2(220, 0)
	row.add_child(le)
	var b := Button.new()
	b.text = "enter"
	row.add_child(b)
	var err := T.label("", 13, T.DANGER)
	row.add_child(err)
	_extra.add_child(row)
	var submit := func(_t = ""):
		if le.text.strip_edges().to_lower() == pw:
			state.set_flag("forum_login")
			desk.sfx.play("chime", -14.0)
			_render(a)
		else:
			desk.sfx.play("error")
			err.text = "  no."
	b.pressed.connect(submit)
	le.text_submitted.connect(submit)
	le.grab_focus.call_deferred()


func _search_form(q: String) -> void:
	var row := HBoxContainer.new()
	var le := LineEdit.new()
	le.text = q
	le.placeholder_text = "Search the Republic's internet"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(le)
	var b := Button.new()
	b.text = "Search"
	row.add_child(b)
	_extra.add_child(row)
	var run := func(_t = ""):
		var res: Array = state.search(le.text)
		desk.sfx.play("click")
		var txt := "[color=#7d8a99]Searches are logged for your safety.[/color]\n\n"
		if res.is_empty():
			txt += "No results for [b]%s[/b]." % _esc(le.text)
		for r in res:
			txt += "[url=go:%s][b]%s[/b][/url]\n[color=#2a6a2a]%s[/color]\n%s\n\n" % [r["url"], r["title"], r["url"], r["snippet"]]
		_page.text = txt
	b.pressed.connect(run)
	le.text_submitted.connect(run)
	le.grab_focus.call_deferred()
	_page.text = "[color=#7d8a99]Searches are logged for your safety.[/color]"


func _posts_text() -> String:
	var txt := ""
	for p in state.posts:
		txt += "\n\n[color=#c9a227]you[/color]   [color=#6fbf73]+%d followers[/color]\n%s" % [int(p["gained"]), _esc(str(p["text"]))]
		if str(p["attach"]) != "":
			txt += "\n[color=#7d8a99][attached: %s][/color]" % str(p["attach"]).get_file()
	return txt


func _compose_form() -> void:
	var box := VBoxContainer.new()
	box.add_child(T.label("Write a post:", 13, T.DIM))
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 64)
	te.placeholder_text = "Where are they?"
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(te)
	var row := HBoxContainer.new()
	row.add_child(T.label("Attach: "))
	var opt := OptionButton.new()
	opt.add_item("(nothing)")
	var paths: Array = [""]
	for path in state.files:
		var f: Dictionary = state.files[path]
		if str(f.get("type", "")) in ["image", "text"] and not str(path).begins_with("/Trash"):
			if str(path).get_base_dir() == "/Documents/do_not_open" and state.dir_locked("/Documents/do_not_open"):
				continue
			opt.add_item(str(path).get_file())
			paths.append(path)
	row.add_child(opt)
	var post := Button.new()
	post.text = "Post"
	row.add_child(post)
	box.add_child(row)
	_extra.add_child(box)
	post.pressed.connect(func():
		var text := te.text.strip_edges()
		if text == "" and opt.selected == 0:
			desk.sfx.play("error")
			return
		state.make_post(text if text != "" else "(no text)", str(paths[opt.selected]))
		desk.sfx.play("chime", -14.0)
		_render(_current))


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
