extends "res://v2/os/app.gd"
## Terminal: a small gamified shell over the HEARTH filesystem. Up arrow = history, Tab = finish a name.

const BG := Color(0.03, 0.04, 0.05)
const FG := Color(0.78, 0.8, 0.78)
const OK := Color(0.5, 0.95, 0.45)

var cwd := Fs.HOME
var _out: RichTextLabel
var _in: LineEdit
var _prompt: Label
var _hist: Array = []
var _hi := -1


func build() -> void:
	cwd = Fs.HOME
	var v := vbox()
	v.add_theme_constant_override("separation", 0)
	_out = RichTextLabel.new()
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.scroll_following = true
	_out.selection_enabled = true
	_out.add_theme_color_override("default_color", FG)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(3)
	_out.add_theme_stylebox_override("normal", sb)
	v.add_child(_out)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	v.add_child(row)
	_prompt = P.label("", OK)
	var psb := StyleBoxFlat.new()
	psb.bg_color = BG
	psb.content_margin_left = 3
	_prompt.add_theme_stylebox_override("normal", psb)
	row.add_child(_prompt)
	_in = LineEdit.new()
	_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var isb := StyleBoxFlat.new()
	isb.bg_color = BG
	_in.add_theme_stylebox_override("normal", isb)
	_in.add_theme_stylebox_override("focus", isb)
	_in.add_theme_color_override("font_color", FG)
	_in.add_theme_color_override("caret_color", OK)
	_in.keep_editing_on_text_submit = true
	_in.text_submitted.connect(_submit)
	_in.gui_input.connect(_keys)
	row.add_child(_in)
	_print("[color=#7fd]%s[/color]" % Fs.data().get("version", ""))
	_print(Fs.read(state(), "/etc/motd"))
	_print("Type [color=#ffd060]help[/color], or open the commands note (tray, bottom right).")
	_update_prompt()
	_in.grab_focus.call_deferred()


func _update_prompt() -> void:
	var short := cwd.replace(Fs.HOME, "~")
	_prompt.text = "citizen@hearth:%s$ " % short


func _print(s: String) -> void:
	_out.append_text(s + "\n")


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _submit(line: String) -> void:
	_in.text = ""
	_print("[color=#80f070]%s[/color]%s" % [_esc(_prompt.text), _esc(line)])
	var l := line.strip_edges()
	if l != "":
		_hist.append(l)
	_hi = -1
	run(l)
	_update_prompt()


## Run one command line (also used by tests).
func run(l: String) -> void:
	if l == "":
		return
	var parts := l.split(" ", false)
	var cmd: String = parts[0].to_lower()
	var a: String = " ".join(parts.slice(1)) if parts.size() > 1 else ""
	var st := state()
	match cmd:
		"help":
			_print("ls  cd  pwd  cat  open  clear  whoami  date  uname  ps  kill  pkg  man  history  echo  notes  exit")
		"ls", "dir":
			var p := Fs.norm(cwd, a) if a != "" else cwd
			if not Fs.is_dir(st, p):
				_print("ls: %s: no such folder" % _esc(a))
				return
			var names: Array = []
			for e in Fs.list(st, p):
				var en: Dictionary = e
				names.append(("[color=#7fb0ff]%s/[/color]" % _esc(en["name"])) if en["dir"] else _esc(en["name"]))
			_print("  ".join(PackedStringArray(names)) if not names.is_empty() else "(empty)")
		"cd":
			var p := Fs.norm(cwd, a)
			if p.begins_with("/home/hearthd"):
				_print("cd: permission denied. (hearthd thanks you for your interest)")
			elif Fs.is_dir(st, p):
				cwd = p
			else:
				_print("cd: %s: no such folder" % _esc(a))
		"pwd":
			_print(cwd)
		"cat", "type", "more", "less":
			if a == "":
				_print("cat: which file? (try ls first)")
				return
			var p := Fs.norm(cwd, a)
			if Fs.is_dir(st, p):
				_print("cat: %s is a folder (use cd)" % _esc(a))
			elif not Fs.exists(st, p):
				_print("cat: %s: no such file" % _esc(a))
			elif Fs.kind_of(p) in ["image", "program"]:
				_print("cat: that's not text. Try: open %s" % _esc(a))
			else:
				_print(_esc(Fs.read(st, p)))
		"open", "xdg-open":
			var p := Fs.norm(cwd, a if a != "" else ".")
			if Fs.exists(st, p):
				os.open_path(p)
			else:
				_print("open: %s: no such file" % _esc(a))
		"clear", "cls":
			_out.clear()
		"whoami":
			_print("citizen (loyalty score: pending review)")
		"date":
			_print("Day %d, %s. The time is the correct time." % [st.day, st.clock_text()])
		"uname":
			_print(Fs.data().get("version", ""))
		"ps", "top":
			_print("[color=#ffd060]%-20s %-9s %4s %6s[/color]" % ["NAME", "USER", "CPU%", "MEM"])
			for pr in Fs.data().get("processes", []):
				_print("%-20s %-9s %4d %5dK" % [pr["name"], pr["user"], int(pr["cpu"]), int(pr["mem"])])
		"kill", "pkill", "killall":
			if a.begins_with("hearthd") or a.begins_with("loyalty"):
				_print("[color=#ff6050]kill: permission denied. This incident has been reported.[/color]")
				os.game.state.attention = minf(100.0, os.game.state.attention + 1.0)
			elif a == "printerd":
				_print("printerd stopped. Nobody noticed.")
			elif a == "":
				_print("kill: kill what? (see ps)")
			else:
				_print("kill: %s: no such process" % _esc(a))
		"pkg", "apt", "apt-get":
			_pkg(a)
		"man":
			var m: Dictionary = Fs.data().get("man", {})
			_print(_esc(str(m.get(a, "No manual entry for '%s'. Manuals are a privilege." % a))))
		"history":
			for i in _hist.size():
				_print("%3d  %s" % [i + 1, _esc(_hist[i])])
		"echo":
			_print(_esc(a))
		"notes":
			os.launch("notepad", Fs.HOME + "/commands.txt")
		"exit", "logout":
			win.close()
		"sudo", "su":
			_print("[color=#ff6050]citizen is not in the sudoers file. This incident will be reported.[/color]")
		"rm", "del":
			_print("rm: deleting is disabled. Everything is kept. Forever.")
		_:
			_print("%s: command not found. Type help." % _esc(cmd))


func _pkg(a: String) -> void:
	var st := state()
	var inst: Array = st.os.get("installed", [])
	if a == "" or a == "list":
		for p in Fs.data().get("programs", []):
			_print("%-10s %-8s %s %s" % [p["name"], p["size"], "[installed]" if inst.has(p["id"]) else "", _esc(p["desc"])])
		return
	if a.begins_with("install "):
		var nm := a.substr(8).strip_edges()
		for p in Fs.data().get("programs", []):
			if p["name"] == nm or p["id"] == nm:
				if not inst.has(p["id"]):
					inst.append(p["id"])
					st.os["installed"] = inst
				_print("Downloading %s... done. Installed. (reported to hearthd: yes)" % nm)
				return
		_print("pkg: no package called '%s'. Try pkg list." % _esc(nm))
		return
	_print("usage: pkg list | pkg install NAME")


func _keys(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	var k: int = e.keycode
	if k == KEY_UP and not _hist.is_empty():
		_hi = _hist.size() - 1 if _hi < 0 else maxi(0, _hi - 1)
		_in.text = _hist[_hi]
		_in.caret_column = _in.text.length()
		_in.accept_event()
	elif k == KEY_DOWN and _hi >= 0:
		_hi += 1
		_in.text = _hist[_hi] if _hi < _hist.size() else ""
		if _hi >= _hist.size():
			_hi = -1
		_in.caret_column = _in.text.length()
		_in.accept_event()
	elif k == KEY_TAB:
		_complete()
		_in.accept_event()


func _complete() -> void:
	var t := _in.text
	var sp := t.rfind(" ")
	var word := t.substr(sp + 1)
	var base_dir := cwd
	var stem := word
	if word.contains("/"):
		base_dir = Fs.norm(cwd, word.get_base_dir())
		stem = word.get_file()
	var hits: Array = []
	for e in Fs.list(state(), base_dir):
		if str(e["name"]).begins_with(stem):
			hits.append(e)
	if hits.size() == 1:
		var en: Dictionary = hits[0]
		var done := str(en["name"]) + ("/" if en["dir"] else "")
		var prefix := word.substr(0, word.length() - stem.length())
		_in.text = t.substr(0, sp + 1) + prefix + done
		_in.caret_column = _in.text.length()
	elif hits.size() > 1:
		var names: Array = []
		for h in hits:
			names.append(str(h["name"]))
		_print("  ".join(PackedStringArray(names)))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
