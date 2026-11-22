extends "res://v2/os/app.gd"
## StateNet: back / forward / home, an address bar, pages from data/v2/os.json "sites".
## Some pages hide a link in faint text; that's how the real internet starts.

var url := ""
var _back: Array = []
var _fwd: Array = []
var _addr: LineEdit
var _page: VBoxContainer
var _scroll: ScrollContainer


func build() -> void:
	var v := vbox()
	var bar := HBoxContainer.new()
	v.add_child(bar)
	bar.add_child(button("<", func() -> void:
		if not _back.is_empty():
			_fwd.append(url)
			go(_back.pop_back(), false)))
	bar.add_child(button(">", func() -> void:
		if not _fwd.is_empty():
			_back.append(url)
			go(_fwd.pop_back(), false)))
	bar.add_child(button("Home", func() -> void: go(str(Fs.data().get("home_page", "hearth.gov")))))
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.text_submitted.connect(func(t: String) -> void: go(t.strip_edges().trim_prefix("http://").trim_prefix("https://").trim_suffix("/")))
	bar.add_child(_addr)
	var well := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.WIN
	sb.border_color = P.FACE_D
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	well.add_theme_stylebox_override("panel", sb)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(well)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page)
	go(arg if arg != "" else str(Fs.data().get("home_page", "hearth.gov")), false)


func go(u: String, remember := true) -> void:
	if remember and url != "" and u != url:
		_back.append(url)
		_fwd.clear()
	url = u
	_addr.text = "http://" + u
	for c in _page.get_children():
		c.queue_free()
	var sites: Dictionary = Fs.data().get("sites", {})
	var wrap_w := maxf(80.0, size.x - 24.0)
	if not sites.has(u):
		_title("404")
		_page.add_child(P.label("This page does not exist. It never existed. Please stop looking for it.", P.INK, wrap_w))
		win.title = "StateNet - not found"
		win.queue_redraw()
		return
	var s: Dictionary = sites[u]
	_title(s.get("title", u))
	win.title = "StateNet - " + str(s.get("title", u))
	win.queue_redraw()
	for line in s.get("body", []):
		_page.add_child(P.label(str(line), P.INK, wrap_w))
	_page.add_child(HSeparator.new())
	for l in s.get("links", []):
		_link(str(l[0]), str(l[1]), P.LINK)
	for l in s.get("hidden", []):
		_link(str(l[0]), str(l[1]), Color(P.WIN.darkened(0.06)))
	_scroll.scroll_vertical = 0


func _title(t: String) -> void:
	var l := P.label(t, P.BRAND.darkened(0.2))
	_page.add_child(l)


func _link(text: String, to: String, col: Color) -> void:
	var b := LinkButton.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", col)
	b.add_theme_font_size_override("font_size", P.FS)
	b.underline = LinkButton.UNDERLINE_MODE_ON_HOVER if col != P.LINK else LinkButton.UNDERLINE_MODE_ALWAYS
	b.pressed.connect(func() -> void:
		os.game.click()
		go(to))
	_page.add_child(b)
