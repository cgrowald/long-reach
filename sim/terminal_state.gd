extends RefCounted
## T1 game state: the night on the laptop. Pure data + rules, no nodes.
## Content (days, conversations, sites, files) comes from data/terminal/*.json.

signal toast(text: String)
signal message_arrived(contact: String)
signal changed

const DATA_DIR := "res://data/terminal/"
const NIGHT_START := 21 * 60 + 30       # 21:30
const SLEEPY_AT := 26 * 60              # 02:00 (minutes past midnight of the day)
const NIGHT_END := 26 * 60 + 30         # 02:30 forced shutdown
const LAST_DAY := 4

static var save_path: String = "user://t1_save.json"

var days: Dictionary = {}
var convo_data: Dictionary = {}
var sites: Dictionary = {}
var file_lib: Dictionary = {}
var shell_data: Dictionary = {}

# --- persistent state ---
var day: int = 1
var minute: int = NIGHT_START
var battery: float = 41.0
var plugged: bool = false
var password: String = ""
var sticky: String = ""
var exposure: int = 0
var followers: int = 0
var flags: Dictionary = {}
var fired: Dictionary = {}            # trigger ids already fired
var convos: Dictionary = {}           # contact -> {"log": [{from,text}], "replies": node_id or "", "unread": int, "started": bool}
var queue: Array = []                 # [{at, contact, text, node_last}]
var files: Dictionary = {}            # path -> file dict
var trash: Array = []                 # file dicts
var notebook: Array = []
var searches: Array = []
var posts: Array = []
var secrets: Dictionary = {}
var log_lines: Array = []             # what happened (for the end summary)


func _init() -> void:
	days = _load("days.json")
	convo_data = _load("conversations.json")
	sites = _load("sites.json")
	file_lib = _load("files.json")
	shell_data = _load("shell.json")


static func _load(name: String) -> Dictionary:
	var f := FileAccess.open(DATA_DIR + name, FileAccess.READ)
	if f == null:
		push_error("missing " + name)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


# ---------------------------------------------------------------- new game / days

func new_game() -> void:
	day = 1
	minute = NIGHT_START
	battery = 41.0
	plugged = false
	flags = {}
	fired = {}
	convos = {}
	queue = []
	files = {}
	trash = []
	notebook = []
	searches = []
	posts = []
	secrets = {}
	log_lines = []
	exposure = 0
	followers = 0
	for f in file_lib.get("start", []):
		_put_file(f)
	for f in file_lib.get("start_trash", []):
		trash.append(f.duplicate(true))
	for c in convo_data.get("contacts", {}):
		convos[c] = {"log": [], "replies": "", "unread": 0, "started": false}


func day_def() -> Dictionary:
	return days.get("days", {}).get(str(day), {})


## Called when the laptop opens for the night (after the day card).
func begin_night() -> void:
	minute = NIGHT_START
	var d := day_def()
	_do(d.get("on_night", []))
	check_triggers()
	changed.emit()


## Close the lid: the night ends. Returns false when the prototype is over.
func end_night() -> bool:
	# Unsent replies stay; queued messages that did not arrive arrive tomorrow night.
	for q in queue:
		q["at"] = NIGHT_START + 2
	day += 1
	if not plugged:
		battery = maxf(battery - 4.0, 0.0)
	save()
	return day <= LAST_DAY


func is_over() -> bool:
	return day > LAST_DAY


# ---------------------------------------------------------------- time

## Advance the laptop clock. Returns true when the night is forced to end.
func advance(mins: int) -> bool:
	for i in mins:
		minute += 1
		if plugged:
			battery = minf(100.0, battery + 0.5)
		else:
			battery = maxf(0.0, battery - 0.2 * (1.5 if has_flag("vpn_on") else 1.0))
		_deliver_queue()
		check_triggers()
		if minute == SLEEPY_AT:
			toast.emit("It's 2 a.m. Your eyes are burning. Close the lid soon.")
	changed.emit()
	return minute >= NIGHT_END or battery <= 0.0


func clock_text() -> String:
	var m := minute % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


# ---------------------------------------------------------------- flags / exposure

func has_flag(f: String) -> bool:
	return flags.has(f) and flags[f] != false and flags[f] != null


func set_flag(f: String, v = true) -> void:
	flags[f] = v
	check_triggers()
	changed.emit()


func add_exposure(n: int, why: String) -> void:
	exposure += n
	log_lines.append("Exposure +%d: %s" % [n, why])
	changed.emit()


## 0 = calm, 1 = watched, 2 = noticed, 3 = hunted (for the eye icon; no numbers on screen).
func exposure_level() -> int:
	if exposure >= 10:
		return 3
	if exposure >= 6:
		return 2
	if exposure >= 2:
		return 1
	return 0


func find_secret(id: String, label: String) -> void:
	if secrets.has(id):
		return
	secrets[id] = label
	toast.emit("Secret found: " + label)


# ---------------------------------------------------------------- triggers + actions

func check_triggers() -> void:
	var lists: Array = [days.get("global_triggers", []), day_def().get("triggers", [])]
	for list in lists:
		for t in list:
			var id: String = str(t.get("id", ""))
			if id == "" or fired.has(id):
				continue
			if t.has("day_min") and day < int(t["day_min"]):
				continue
			if t.has("at") and minute < _parse_time(str(t["at"])):
				continue
			if not _cond(t.get("if", {})):
				continue
			fired[id] = true
			_do(t.get("do", []))


func _parse_time(s: String) -> int:
	var p := s.split(":")
	var h := int(p[0])
	if h < 12:
		h += 24
	return h * 60 + int(p[1])


func cond(c: Dictionary) -> bool:
	return _cond(c)


func _cond(c: Dictionary) -> bool:
	for k in c:
		var want = c[k]
		if str(k).begins_with("!"):
			if has_flag(str(k).substr(1)) == bool(want):
				return false
		elif want is bool:
			if has_flag(k) != want:
				return false
		elif flags.get(k) != want:
			return false
	return true


func do_actions(actions: Array) -> void:
	_do(actions)


func _do(actions: Array) -> void:
	for a in actions:
		if a.has("set"):
			for k in a["set"]:
				flags[k] = a["set"][k]
		if a.has("exposure"):
			add_exposure(int(a["exposure"]), str(a.get("why", "something you did")))
		if a.has("msg"):
			start_node(str(a["msg"]), int(a.get("delay", 1)))
		if a.has("add_file"):
			add_lib_file(str(a["add_file"]))
		if a.has("notebook"):
			add_note(str(a["notebook"]))
		if a.has("toast"):
			toast.emit(str(a["toast"]))
		if a.has("followers"):
			followers += int(a["followers"])
		if a.has("secret"):
			find_secret(str(a["secret"]), str(a.get("secret_label", a["secret"])))
	changed.emit()


func add_note(text: String) -> void:
	if not notebook.has(text):
		notebook.append(text)
		toast.emit("Notebook: " + text)


# ---------------------------------------------------------------- messages

func contact_def(c: String) -> Dictionary:
	return convo_data.get("contacts", {}).get(c, {})


func contact_name(c: String) -> String:
	var d := contact_def(c)
	if has_flag("named_" + c) or d.get("name_known", false):
		return str(d.get("name", c))
	return str(d.get("number", c))


func node(id: String) -> Dictionary:
	return convo_data.get("nodes", {}).get(id, {})


## Schedule a conversation node: its lines arrive one minute apart, then its replies unlock.
func start_node(id: String, delay: int = 1) -> void:
	var n := node(id)
	if n.is_empty():
		push_error("no node " + id)
		return
	var c: String = str(n["contact"])
	var t: int = minute + delay
	var lines: Array = n.get("msgs", [])
	if lines.is_empty():
		queue.append({"at": t, "contact": c, "text": "", "node_last": id})
	for i in lines.size():
		queue.append({"at": t + i, "contact": c, "text": str(lines[i]), "node_last": id if i == lines.size() - 1 else ""})


func _deliver_queue() -> void:
	var keep: Array = []
	for q in queue:
		if int(q["at"]) > minute:
			keep.append(q)
			continue
		var c: String = str(q["contact"])
		var cv: Dictionary = convos[c]
		cv["started"] = true
		if str(q["text"]) != "":
			cv["log"].append({"from": c, "text": str(q["text"])})
			cv["unread"] = int(cv["unread"]) + 1
			message_arrived.emit(c)
		var last: String = str(q.get("node_last", ""))
		if last != "":
			var n := node(last)
			_do(n.get("do", []))
			if n.has("replies"):
				cv["replies"] = last
			elif n.has("next"):
				start_node(str(n["next"]), int(n.get("next_delay", 1)))
	queue = keep


func is_typing(c: String) -> bool:
	for q in queue:
		if str(q["contact"]) == c and int(q["at"]) - minute <= 2 and str(q["text"]) != "":
			return true
	return false


func replies_for(c: String) -> Array:
	var id: String = str(convos[c]["replies"])
	if id == "":
		return []
	return node(id).get("replies", []).filter(func(r): return _cond(r.get("if", {})))


## The player picks reply #i in the conversation with c.
func reply(c: String, i: int) -> void:
	var r: Dictionary = replies_for(c)[i]
	var cv: Dictionary = convos[c]
	cv["replies"] = ""
	cv["log"].append({"from": "me", "text": str(r["text"])})
	_do(r.get("do", []))
	if r.has("goto"):
		start_node(str(r["goto"]), int(r.get("delay", 2)))
	check_triggers()
	changed.emit()


## Typing a number into "New chat". Returns the contact id, or "" with an error text in flags.
func dial(number: String) -> String:
	var digits := _digits(number)
	for c in convo_data.get("contacts", {}):
		var d: Dictionary = convo_data["contacts"][c]
		if _digits(str(d.get("number", ""))) == digits and digits != "":
			if d.has("dial_requires") and not has_flag(str(d["dial_requires"])):
				return ""
			var cv: Dictionary = convos[c]
			if not cv["started"]:
				cv["started"] = true
				if d.has("opener"):
					cv["replies"] = str(d["opener"])
			return c
	return ""


func dial_special(number: String) -> String:
	var digits := _digits(number)
	return str(convo_data.get("special_numbers", {}).get(digits, ""))


static func _digits(s: String) -> String:
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += ch
	return out


func unread_total() -> int:
	var n := 0
	for c in convos:
		n += int(convos[c]["unread"])
	return n


# ---------------------------------------------------------------- files

func _put_file(f: Dictionary) -> void:
	var d: Dictionary = f.duplicate(true)
	files[str(d["path"])] = d


func add_lib_file(id: String) -> void:
	var f: Dictionary = file_lib.get("library", {}).get(id, {})
	if f.is_empty():
		push_error("no file " + id)
		return
	if files.has(str(f["path"])):
		return
	_put_file(f)
	toast.emit("New file: " + str(f["path"]).get_file())


func dirs() -> Array:
	return file_lib.get("dirs", [])


func list_dir(dir: String) -> Array:
	var out: Array = []
	for p in files:
		var f: Dictionary = files[p]
		if str(p).get_base_dir() == dir:
			if f.get("hidden", false) and not has_flag("show_hidden"):
				continue
			out.append(f)
	out.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
	return out


func dir_locked(dir: String) -> bool:
	for d in dirs():
		if str(d["path"]) == dir and d.has("password"):
			return not has_flag("unlocked:" + dir)
	return false


func unlock_dir(dir: String, pw: String) -> bool:
	for d in dirs():
		if str(d["path"]) == dir and d.has("password"):
			if pw.strip_edges().to_lower() == str(d["password"]).to_lower():
				flags["unlocked:" + dir] = true
				_do(d.get("on_unlock", []))
				return true
			return false
	return false


func delete_file(path: String) -> void:
	if not files.has(path):
		return
	trash.append(files[path])
	files.erase(path)
	changed.emit()


func strip_meta(path: String) -> void:
	if files.has(path):
		files[path]["meta"] = {}
		files[path]["stripped"] = true
		changed.emit()


func file_has_meta(f: Dictionary) -> bool:
	return not f.get("meta", {}).is_empty()


## Running an installer from Files.
func run_file(path: String) -> String:
	var f: Dictionary = files.get(path, {})
	var prog: String = str(f.get("installs", ""))
	if prog == "":
		return "This file can't be run."
	if has_flag("installed_" + prog):
		return "Already installed."
	flags["installed_" + prog] = true
	var p: Dictionary = file_lib.get("programs", {}).get(prog, {})
	_do(p.get("on_install", []))
	if p.get("illegal", false) and day >= 4:
		log_lines.append("Installed %s, which has been illegal since this morning." % p.get("name", prog))
	check_triggers()
	changed.emit()
	return str(p.get("installed_text", "Installed."))


func uninstall(prog: String) -> void:
	flags.erase("installed_" + prog)
	if prog == "safetunnel" or prog == "molenet":
		flags.erase("vpn_on")
	var p: Dictionary = file_lib.get("programs", {}).get(prog, {})
	_do(p.get("on_uninstall", []))
	changed.emit()


func vpn_installed() -> String:
	for v in ["molenet", "safetunnel"]:
		if has_flag("installed_" + v):
			return v
	return ""


## Wipe: everything you made or downloaded is gone; trash emptied.
func wipe() -> void:
	trash.clear()
	for p in files.keys():
		if not files[p].get("system", false):
			files.erase(p)
	flags["wiped"] = true
	log_lines.append("You wiped the laptop.")
	changed.emit()


# ---------------------------------------------------------------- web

func normalize_addr(a: String) -> String:
	var s := a.strip_edges().to_lower()
	for pre in ["https://", "http://", "www."]:
		if s.begins_with(pre):
			s = s.substr(pre.length())
	while s.ends_with("/"):
		s = s.left(-1)
	return s


func page(addr: String) -> Dictionary:
	return sites.get("pages", {}).get(normalize_addr(addr), {})


func visit(addr: String) -> void:
	var a := normalize_addr(addr)
	var p := page(a)
	if p.is_empty():
		return
	var key := "visited:%s:%d" % [a, day]
	var first_today := not flags.has(key)
	flags[key] = true
	if p.get("blocked", false) and first_today:
		add_exposure(1, "visited a blocked page (%s)" % a)
	if p.get("forum", false) and first_today and not has_flag("vpn_on"):
		add_exposure(1, "opened the forum without a VPN")
	if p.get("forum", false) and first_today and has_flag("vpn_on") and vpn_installed() == "safetunnel":
		add_exposure(2, "opened the forum through SafeTunnel (it was theirs)")
	_do(p.get("on_visit", []))
	check_triggers()


## NetState search. Returns result dicts. Logged; flagged words raise exposure.
func search(q: String) -> Array:
	var ql := q.strip_edges().to_lower()
	if ql == "":
		return []
	searches.append(q)
	var flagged := false
	for w in sites.get("flagged_words", []):
		if ql.contains(str(w)):
			flagged = true
	if flagged and not has_flag("citizencare_killed") and not has_flag("vpn_on"):
		add_exposure(1, "searched NetState for \"%s\"" % q)
		set_flag("searched_flagged")
	elif flagged and has_flag("vpn_on") and vpn_installed() == "safetunnel":
		add_exposure(1, "searched for \"%s\" through SafeTunnel" % q)
	var out: Array = []
	for entry in sites.get("search", []):
		for kw in entry.get("keywords", []):
			if ql.contains(str(kw)):
				for r in entry.get("results", []):
					if not out.has(r):
						out.append(r)
				break
	return out


func make_post(text: String, attach: String) -> Dictionary:
	var gained := 15 + mini(text.length() / 8, 15)
	var post := {"text": text, "attach": attach, "day": day}
	if attach != "" and files.has(attach):
		gained += 30
		var f: Dictionary = files[attach]
		if file_has_meta(f):
			add_exposure(4, "posted %s with its metadata (the camera serial and GPS)" % attach.get_file())
			flags["posted_meta"] = true
			post["meta"] = true
		else:
			flags["posted_clean"] = true
	followers += gained
	post["gained"] = gained
	posts.append(post)
	flags["posted"] = true
	log_lines.append("Posted to the forum: +%d followers." % gained)
	check_triggers()
	changed.emit()
	return post


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {"day": day, "battery": battery, "plugged": plugged, "password": password, "sticky": sticky,
		"exposure": exposure, "followers": followers, "flags": flags, "fired": fired, "convos": convos,
		"queue": queue, "files": files, "trash": trash, "notebook": notebook, "searches": searches,
		"posts": posts, "secrets": secrets, "log": log_lines}


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return false
	day = int(d.get("day", 1))
	battery = float(d.get("battery", 40.0))
	plugged = bool(d.get("plugged", false))
	password = str(d.get("password", ""))
	sticky = str(d.get("sticky", ""))
	exposure = int(d.get("exposure", 0))
	followers = int(d.get("followers", 0))
	flags = d.get("flags", {})
	fired = d.get("fired", {})
	convos = d.get("convos", {})
	queue = d.get("queue", [])
	files = d.get("files", {})
	trash = d.get("trash", [])
	notebook = d.get("notebook", [])
	searches = d.get("searches", [])
	posts = d.get("posts", [])
	secrets = d.get("secrets", {})
	log_lines = d.get("log", [])
	for c in convo_data.get("contacts", {}):
		if not convos.has(c):
			convos[c] = {"log": [], "replies": "", "unread": 0, "started": false}
	return true


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
