extends VBoxContainer
## The hidden factory dev console. A tiny fake shell.

const T := preload("res://terminal/os_theme.gd")

var desk
var state
var _out: RichTextLabel
var _in: LineEdit
var _wipe_armed := false


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", T.box(Color(0.04, 0.05, 0.05), Color(0.2, 0.2, 0.2), 1, 0))
	add_child(bg)
	_out = RichTextLabel.new()
	_out.scroll_following = true
	_out.selection_enabled = true
	_out.add_theme_font_override("normal_font", T.mono())
	_out.add_theme_font_size_override("normal_font_size", 14)
	_out.add_theme_color_override("default_color", Color(0.55, 0.95, 0.6))
	bg.add_child(_out)
	_in = LineEdit.new()
	_in.add_theme_font_override("font", T.mono())
	_in.add_theme_stylebox_override("normal", T.box(Color(0.04, 0.05, 0.05), Color(0.2, 0.4, 0.25), 1, 0))
	_in.add_theme_stylebox_override("focus", T.box(Color(0.04, 0.05, 0.05), Color(0.3, 0.7, 0.4), 1, 0))
	_in.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	_in.add_theme_color_override("caret_color", Color(0.55, 0.95, 0.6))
	_in.text_submitted.connect(_run)
	add_child(_in)
	_print(str(state.shell_data.get("motd", "")))
	_in.grab_focus.call_deferred()


func _print(s: String) -> void:
	_out.add_text(s + "\n")


func _run(line: String) -> void:
	_in.clear()
	desk.sfx.play("key")
	var cmd := line.strip_edges()
	_print("> " + cmd)
	if cmd == "":
		return
	var low := cmd.to_lower()
	var parts := low.split(" ", false)
	if _wipe_armed:
		_wipe_armed = false
		if cmd == "WIPE":
			state.wipe()
			desk.sfx.play("error")
			_print("Wiping... done. Everything you made or downloaded is gone. Elena's files too.\nThe notebook on the bench is still there. Paper doesn't wipe.")
		else:
			_print("Wipe cancelled.")
		return
	match parts[0]:
		"help":
			_print(str(state.shell_data.get("help", "")))
		"whoami":
			_print("tomas  (citizen 0447-2219-KS)  status: IN GOOD STANDING" + ("  [watch: active]" if state.exposure_level() >= 2 else ""))
		"date":
			_print("%s, day %d of the new rules. %s" % [state.day_def().get("weekday", "?"), state.day, state.clock_text()])
		"clear":
			_out.clear()
		"exit":
			get_parent().get_parent().close()
		"fortune":
			var f: Array = state.shell_data.get("fortunes", [])
			_print(str(f[randi() % f.size()]))
		"ls":
			if parts.size() > 1 and parts[1] == "-a":
				if not state.has_flag("show_hidden"):
					state.set_flag("show_hidden")
					state.find_secret("hidden_files", "Hidden files")
				_print("hidden files are now shown in Files.")
				for p in state.files:
					if state.files[p].get("hidden", false):
						_print("  " + str(p))
			else:
				_print("Documents/  Pictures/  Downloads/   (try ls -a)")
		"ps":
			_print("PID   NAME")
			_print("101   hearth_shell")
			_print("144   netstate")
			_print("207   fan_ctrl")
			if not state.has_flag("citizencare_killed"):
				_print("233   citizencare        <- uploads to ministry.vd")
			if state.has_flag("vpn_on"):
				_print("301   %s" % state.vpn_installed())
		"scan":
			if state.has_flag("citizencare_killed"):
				_print("Scanning... nothing is reporting on you. (From this machine.)")
			else:
				_print("Scanning... 1 process sends your searches, sites and files to ministry.vd every 10 minutes: citizencare")
		"kill":
			if parts.size() > 1 and parts[1] == "citizencare":
				if state.has_flag("citizencare_killed"):
					_print("citizencare is not running.")
				else:
					state.set_flag("citizencare_killed")
					state.add_exposure(1, "stopped CitizenCare (somewhere, a log went quiet)")
					state.find_secret("citizencare", "Killed CitizenCare")
					_print("citizencare stopped.\nNetState searches will no longer be reported from this machine.\nSomewhere, a log just went quiet. Someone may notice the silence.")
			elif parts.size() > 1:
				_print("kill: you can't stop " + parts[1] + ".")
			else:
				_print("kill what?")
		"wipe":
			_wipe_armed = true
			_print("This destroys every file you made or downloaded, and empties the Trash for good.\nType WIPE (capitals) to confirm.")
		_:
			var eggs: Dictionary = state.shell_data.get("easter", {})
			if eggs.has(low):
				_print(str(eggs[low]))
				if low == "nightjar":
					state.find_secret("nightjar", "nightjar answered")
			else:
				_print("unknown command: %s   (try 'help')" % parts[0])
