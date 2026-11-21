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
const WAGE := 60                       # sandbox: a day at the plant
const WorldGen := preload("res://sim/world_gen.gd")

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
var learned: Array = []              # commands you know (assist chips)
var patterns: Dictionary = {}         # name -> steps you can replay
var loot: Array = []                  # drops you have found
# --- sandbox (the open PC) ---
var mode: String = "story"            # "story" = the old scripted week, "sandbox" = systemic
var world: Dictionary = {}            # generated town (sim/world_gen.gd)
var money: int = 0
var inventory: Dictionary = {}        # item id -> count
var stations: Dictionary = {}         # station id -> true when its kit is bought
var jobs: Array = []                  # repair jobs waiting at the hacking station
var leads: Array = []                 # business ids someone pointed you at
var dyn_contacts: Dictionary = {}     # generated contacts: id -> {"name", "number"}
var made: Dictionary = {}             # recipe id -> times made
var bureau_sent: int = 0              # highest Bureau warning level already sent
var flagged_today: int = 0
var _sb_cache: Dictionary = {}


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
	learned = []
	patterns = {}
	loot = []
	exposure = 0
	followers = 0
	for f in file_lib.get("start", []):
		_put_file(f)
	for f in file_lib.get("start_trash", []):
		trash.append(f.duplicate(true))
	for c in convo_data.get("contacts", {}):
		convos[c] = {"log": [], "replies": "", "unread": 0, "started": false}


func day_def() -> Dictionary:
	if mode == "sandbox":
		return _sb_day()
	return days.get("days", {}).get(str(day), {})


## Called when the laptop opens for the night (after the day card).
func begin_night() -> void:
	minute = NIGHT_START
	flags.erase("lab_active")
	var d := day_def()
	_do(d.get("on_night", []))
	if mode == "sandbox":
		flagged_today = 0
		_systemic_messages()
		_bureau_check()
	check_triggers()
	changed.emit()


## Close the lid: the night ends. Returns false when the prototype is over.
func end_night() -> bool:
	# Unsent replies stay; queued messages that did not arrive arrive tomorrow night.
	for q in queue:
		q["at"] = NIGHT_START + 2
	day += 1
	minute = NIGHT_START
	if not plugged:
		battery = maxf(battery - 4.0, 0.0)
	if mode == "sandbox":
		money += WAGE
		_sb_cache = {}
	save()
	return mode == "sandbox" or day <= LAST_DAY


func is_over() -> bool:
	return mode != "sandbox" and day > LAST_DAY


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


const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


## The calendar date right now (past midnight counts as the next day).
func date_dict() -> Dictionary:
	var s: Dictionary = days.get("start_date", {"year": 2041, "month": 10, "day": 14})
	var start := Time.get_unix_time_from_datetime_dict({"year": int(s["year"]), "month": int(s["month"]), "day": int(s["day"]), "hour": 12})
	var offset_days: int = (day - 1) + minute / (24 * 60)
	return Time.get_datetime_dict_from_unix_time(start + offset_days * 86400)


## e.g. "Mon 14 Oct 2041  21:36"
func datetime_text() -> String:
	var d := date_dict()
	return "%s %d %s %d   %s" % [WEEKDAYS[int(d["weekday"])], int(d["day"]), MONTHS[int(d["month"]) - 1], int(d["year"]), clock_text()]


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
		if a.has("money"):
			money += int(a["money"])
		if a.has("job"):
			var j: Dictionary = a["job"].duplicate(true)
			j["pay"] = int(j.get("pay", 0))
			jobs.append(j)
			toast.emit("Repair job: %s (waiting at the HACKING station)" % j.get("device", "a device"))
		if a.has("lead"):
			var b: String = str(a["lead"])
			if b != "" and not leads.has(b):
				leads.append(b)
				var bd: Dictionary = WorldGen.find(world, "businesses", b)
				if not bd.is_empty():
					add_note("Lead: %s, %s (%s)" % [bd["name"], bd["street"], bd["weakness"]])
		if a.has("lottery"):
			flags["lottery_tickets"] = int(flags.get("lottery_tickets", 0)) + 1
	changed.emit()


func add_note(text: String) -> void:
	if not notebook.has(text):
		notebook.append(text)
		toast.emit("Notebook: " + text)


# ---------------------------------------------------------------- messages

func contact_def(c: String) -> Dictionary:
	return convo_data.get("contacts", {}).get(c, {})


func contact_name(c: String) -> String:
	if dyn_contacts.has(c):
		return str(dyn_contacts[c]["name"])
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
		if q.has("dyn_replies"):
			cv["dyn"] = q["dyn_replies"]
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
	if not convos[c].get("dyn", []).is_empty():
		return convos[c]["dyn"]
	var id: String = str(convos[c]["replies"])
	if id == "":
		return []
	return node(id).get("replies", []).filter(func(r): return _cond(r.get("if", {})))


## The player picks reply #i in the conversation with c.
func reply(c: String, i: int) -> void:
	var r: Dictionary = replies_for(c)[i]
	var cv: Dictionary = convos[c]
	var was_dyn: bool = not cv.get("dyn", []).is_empty()
	cv["dyn"] = []
	if not was_dyn:
		cv["replies"] = ""
	cv["log"].append({"from": "me", "text": str(r["text"])})
	_do(r.get("do", []))
	if r.has("answer"):
		var t: int = minute + 2
		for line in r["answer"]:
			queue.append({"at": t, "contact": c, "text": str(line), "node_last": ""})
			t += 1
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
	var a := normalize_addr(addr)
	if a.begins_with("netstate.vd/biz/"):
		return biz_page(a.substr(16))
	if a.begins_with("netstate.vd/citizens/"):
		return citizen_page(a.substr(21))
	return sites.get("pages", {}).get(a, {})


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
	if mode == "sandbox" and ql.length() >= 3:
		for r in world_search(ql):
			if not out.has(r):
				out.append(r)
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
	if attach != "" and files.has(attach) and files[attach].has("stars"):
		var st: int = int(files[attach]["stars"])
		var bonus: int = st * st * 10
		if files[attach].get("traits", []).has("verified"):
			bonus = int(bonus * 1.5)
		gained += bonus
		flags["posted_loot_" + str(files[attach].get("loot", ""))] = true
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
		"posts": posts, "secrets": secrets, "log": log_lines,
		"learned": learned, "patterns": patterns, "loot": loot,
		"mode": mode, "world": world, "money": money, "inventory": inventory, "stations": stations, "jobs": jobs,
		"leads": leads, "dyn_contacts": dyn_contacts, "made": made, "bureau_sent": bureau_sent}


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
	learned = d.get("learned", [])
	patterns = d.get("patterns", {})
	loot = d.get("loot", [])
	mode = str(d.get("mode", "story"))
	world = d.get("world", {})
	money = int(d.get("money", 0))
	inventory = d.get("inventory", {})
	stations = d.get("stations", {})
	jobs = d.get("jobs", [])
	leads = d.get("leads", [])
	dyn_contacts = d.get("dyn_contacts", {})
	made = d.get("made", {})
	bureau_sent = int(d.get("bureau_sent", 0))
	for c in dyn_contacts:
		if not convos.has(c):
			convos[c] = {"log": [], "replies": "", "unread": 0, "started": false}
	for c in convo_data.get("contacts", {}):
		if not convos.has(c):
			convos[c] = {"log": [], "replies": "", "unread": 0, "started": false}
	return true


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ================================================================ SANDBOX: the open PC
# Systemic days, generated town and internet, market, workshop, Bureau warnings.

const OS_DIR := "res://data/os/"
static var _os_cache: Dictionary = {}


static func os_data(name: String) -> Dictionary:
	if not _os_cache.has(name):
		var f := FileAccess.open(OS_DIR + name, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else {}
		_os_cache[name] = d if d is Dictionary else {}
	return _os_cache[name]


func new_sandbox(seed: int = -1) -> void:
	new_game()
	mode = "sandbox"
	world = WorldGen.generate(seed if seed >= 0 else randi())
	var hooks := os_data("hooks.json")
	money = int(hooks.get("start_money", 150))
	inventory = {}
	stations = {}
	jobs = hooks.get("start_jobs", []).duplicate(true)
	leads = []
	made = {}
	bureau_sent = 0
	dyn_contacts = {}
	for id in hooks.get("fixed_contacts", {}):
		_ensure_contact(id, str(hooks["fixed_contacts"][id]["name"]))
	_sb_cache = {}


func _ensure_contact(id: String, name: String) -> void:
	if not dyn_contacts.has(id):
		dyn_contacts[id] = {"name": name}
	if not convos.has(id):
		convos[id] = {"log": [], "replies": "", "unread": 0, "started": false}


## Today, made up from the world: the day card, the rule, the news, the opening-story hooks.
func _sb_day() -> Dictionary:
	if not _sb_cache.is_empty() and int(_sb_cache.get("_day", -1)) == day:
		return _sb_cache
	var dd := date_dict()
	var wd: String = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][int(dd["weekday"])]
	var n: Dictionary = WorldGen.day_news(world, day)
	var card: Array = []
	if day == 1:
		card = days.get("days", {}).get("1", {}).get("card", [])
	else:
		var head: String = str(n["news"][1]) if n["news"].size() > 1 else ""
		card = [{"text": "Morning. The radio reads today's rule:\n\n%s\n\nYou work your shift at the plant. +%d VM.\n\n%s" % [n["rule"], WAGE, head]}]
	_sb_cache = {"_day": day, "weekday": wd, "news": n["news"], "rule": n["rule"], "card": card,
		"triggers": os_data("hooks.json").get("triggers", [])}
	return _sb_cache


## A few systemic messages each night, picked by weight and conditions, slots filled from the town.
func _systemic_messages() -> void:
	var chat := os_data("chat.json")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.get("seed", 1)) * 77 + day
	var range_n: Array = chat.get("per_night", [2, 3])
	var count: int = rng.randi_range(int(range_n[0]), int(range_n[1]))
	var pool: Array = chat.get("templates", []).filter(func(t): return _cond(t.get("if", {})))
	var t_at: int = minute + 3
	for k in count:
		if pool.is_empty():
			break
		var total := 0.0
		for t in pool:
			total += float(t.get("weight", 1))
		var roll := rng.randf() * total
		var pick: Dictionary = pool[0]
		for t in pool:
			roll -= float(t.get("weight", 1))
			if roll <= 0.0:
				pick = t
				break
		pool.erase(pick)
		_send_template(pick, rng, t_at)
		t_at += rng.randi_range(6, 25)


func _send_template(t: Dictionary, rng: RandomNumberGenerator, at: int) -> void:
	var from: String = str(t.get("from", "state"))
	var slots := {"rule": str(_sb_day().get("rule", ""))}
	var people: Array = world.get("people", [])
	var biz: Array = world.get("businesses", [])
	if from == "neighbor" and not people.is_empty():
		var p: Dictionary = people[rng.randi() % people.size()]
		from = "person:" + str(p["id"])
		_ensure_contact(from, "%s %s" % [p["first"], p["last"]])
		slots["first"] = str(p["first"])
		slots["street"] = str(p["street"])
	if not people.is_empty():
		var o: Dictionary = people[rng.randi() % people.size()]
		slots["other"] = "%s %s" % [o["first"], o["last"]]
		slots["other_trait"] = "they %s" % str(WorldGen.data()["traits"].get(o["trait"], "said something"))
	var targets: Array = biz.filter(func(b): return WorldGen.data()["business_kinds"].get(b["kind"], {}).get("target", false) or b["kind"] in ["electronics", "hardware", "cafe", "lounge", "hospital"])
	if not targets.is_empty():
		var b: Dictionary = targets[rng.randi() % targets.size()]
		slots["business"] = str(b["name"])
		slots["business_id"] = str(b["id"])
		if not slots.has("street"):
			slots["street"] = str(b["street"])
	var devices: Array = os_data("chat.json").get("devices", ["radio"])
	slots["device"] = str(devices[rng.randi() % devices.size()])
	slots["pay"] = str(rng.randi_range(15, 45))
	slots["from"] = from
	if not dyn_contacts.has(from):
		_ensure_contact(from, from)
	var msgs: Array = t.get("msgs", []).map(func(m): return _fill(str(m), slots))
	var replies: Array = []
	for r in t.get("replies", []):
		replies.append(_fill_deep(r, slots))
	for i in msgs.size():
		var q := {"at": at + i, "contact": from, "text": msgs[i], "node_last": ""}
		if i == msgs.size() - 1 and not replies.is_empty():
			q["dyn_replies"] = replies
		queue.append(q)


func _fill(s: String, slots: Dictionary) -> String:
	for k in slots:
		s = s.replace("{%s}" % k, str(slots[k]))
	return s


func _fill_deep(v, slots: Dictionary):
	if v is String:
		return _fill(v, slots)
	if v is Array:
		return v.map(func(x): return _fill_deep(x, slots))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _fill_deep(v[k], slots)
		return out
	return v


## The Bureau writes when your file grows.
func _bureau_check() -> void:
	var lvl: int = exposure_level()
	if lvl > bureau_sent:
		bureau_sent = lvl
		var lines: Array = os_data("chat.json").get("bureau", {}).get(str(lvl), [])
		var t := minute + 2
		for l in lines:
			queue.append({"at": t, "contact": "bureau", "text": str(l), "node_last": ""})
			t += 1


# ---------------------------------------------------------------- market

func catalog() -> Dictionary:
	return os_data("market.json").get("items", {})


func item_name(id: String) -> String:
	if catalog().has(id):
		return str(catalog()[id]["name"])
	var r: Dictionary = os_data("stations.json").get("recipes", {}).get(id, {})
	return str(r.get("name", id))


## Shops in this town that sell an item ("grey" = lantern market, "dark" = darknet).
func sellers(id: String) -> Array:
	var out: Array = []
	var it: Dictionary = catalog().get(id, {})
	for b in world.get("businesses", []):
		if str(b["kind"]) in it.get("from", []):
			out.append(str(b["name"]))
	if "grey" in it.get("from", []) and has_flag("grey_market"):
		out.append("lantern market (cash, no questions)")
	return out


func can_buy(id: String) -> bool:
	return not sellers(id).is_empty()


func buy(id: String) -> String:
	var it: Dictionary = catalog().get(id, {})
	if it.is_empty():
		return "NOT FOUND."
	if not can_buy(id):
		return "NOT AVAILABLE. No seller you know of carries this."
	var price: int = int(it["price"])
	if money < price:
		return "REQUEST NOT APPROVED. REASON: INSUFFICIENT FUNDS (%d of %d VM)." % [money, price]
	money -= price
	inventory[id] = int(inventory.get(id, 0)) + 1
	var leg: String = str(it.get("legality", "legal"))
	if leg == "flagged":
		flagged_today += 1
		if flagged_today > int(os_data("market.json").get("flagged_free_per_day", 2)):
			add_exposure(1, "bought several registered items in one day (%s)" % it["name"])
	elif leg == "illegal":
		add_exposure(1, "bought %s from a grey seller" % it["name"])
	for inc in it.get("includes", {}):
		inventory[inc] = int(inventory.get(inc, 0)) + int(it["includes"][inc])
	if it.has("station"):
		stations[str(it["station"])] = true
		toast.emit("Station opened: %s" % str(os_data("stations.json")["stations"][it["station"]]["name"]))
	changed.emit()
	return "PURCHASE APPROVED. %s. Remaining: %d VM." % [it["name"], money]


# ---------------------------------------------------------------- workshop

func station_list() -> Dictionary:
	return os_data("stations.json").get("stations", {})


func recipes_for(station: String) -> Array:
	var out: Array = []
	var all: Dictionary = os_data("stations.json").get("recipes", {})
	for id in all:
		if str(all[id]["station"]) == station:
			var r: Dictionary = all[id].duplicate()
			r["id"] = id
			out.append(r)
	return out


## Can you make it right now? {"ok": bool, "missing": [text], "why": text}
func recipe_status(id: String) -> Dictionary:
	var r: Dictionary = os_data("stations.json").get("recipes", {}).get(id, {})
	var missing: Array = []
	if not stations.has(str(r.get("station", ""))):
		return {"ok": false, "missing": [], "why": "Station not set up. Buy its kit on the Market."}
	if r.has("requires") and not made.has(str(r["requires"])):
		return {"ok": false, "missing": [], "why": "You haven't worked out how yet (make a %s first)." % item_name(str(r["requires"]))}
	if r.get("needs_job", false) and jobs.is_empty():
		return {"ok": false, "missing": [], "why": "No repair jobs waiting."}
	for p in r.get("parts", {}):
		var have: int = int(inventory.get(p, 0))
		var need: int = int(r["parts"][p])
		if have < need:
			missing.append("%s (%d/%d)" % [item_name(p), have, need])
	for tool in r.get("tools", []):
		if int(inventory.get(tool, 0)) < 1:
			missing.append("%s (tool)" % item_name(tool))
	return {"ok": missing.is_empty(), "missing": missing, "why": "" if missing.is_empty() else "Missing parts."}


## Make it. (Placeholder until the bench minigames: instant, costs its hours from the night.)
func make(id: String) -> String:
	var st := recipe_status(id)
	if not st["ok"]:
		return "CANNOT START. " + str(st["why"])
	var r: Dictionary = os_data("stations.json")["recipes"][id]
	for p in r.get("parts", {}):
		inventory[p] = int(inventory.get(p, 0)) - int(r["parts"][p])
		if int(inventory[p]) <= 0:
			inventory.erase(p)
	made[id] = int(made.get(id, 0)) + 1
	var out := ""
	if r.get("needs_job", false):
		var j: Dictionary = jobs.pop_front()
		money += int(j.get("pay", 0))
		_do(j.get("on_done", []))
		out = "Fixed: %s. +%d VM." % [j.get("device", "device"), int(j.get("pay", 0))]
	else:
		inventory[id] = int(inventory.get(id, 0)) + 1
		out = "Made: %s." % r["name"]
	advance(int(r.get("hours", 1)) * 60)
	changed.emit()
	return out


# ---------------------------------------------------------------- generated internet

func biz_page(id: String) -> Dictionary:
	var b: Dictionary = WorldGen.find(world, "businesses", id)
	if b.is_empty():
		return {}
	var kind: Dictionary = WorldGen.data()["business_kinds"].get(b["kind"], {})
	var body := "[font_size=20][b]%s[/b][/font_size]\n[color=#6b6b5f]%s  -  %s %d, %s[/color]\n\n%s\n\n" % [b["name"], kind.get("label", ""), b["street"], int(b["number"]), world.get("town", ""), b["flavor"]]
	var stock: Array = []
	for item in catalog():
		if str(b["kind"]) in catalog()[item].get("from", []):
			stock.append("  - %s   [color=#6b6b5f]%d VM[/color]" % [catalog()[item]["name"], int(catalog()[item]["price"])])
	if not stock.is_empty():
		body += "[b]IN STOCK[/b]  (order through the Market app)\n" + "\n".join(stock) + "\n\n"
	body += "[b]STAFF[/b]\n"
	for pid in b["staff"]:
		var p: Dictionary = WorldGen.find(world, "people", pid)
		if not p.is_empty():
			body += "  [url=go:netstate.vd/citizens/%s]%s %s[/url], %s\n" % [p["id"], p["first"], p["last"], str(p["job"]).split(" at ")[0]]
	if leads.has(id):
		body += "\n[color=#a03020]YOUR NOTE: %s[/color]" % b["weakness"]
	body += "\n\n[color=#6b6b5f]Page approved by the Ministry of Information. Last updated: 2033.[/color]"
	return {"title": b["name"], "body": body}


func citizen_page(id: String) -> Dictionary:
	var p: Dictionary = WorldGen.find(world, "people", id)
	if p.is_empty():
		return {}
	var body := "[b]CITIZEN DIRECTORY[/b]  -  public record\n\nName: %s %s\nAge: %d\nResidence: %s\nOccupation: %s\nStatus: [color=#3c7a3c]IN GOOD STANDING[/color]\n\n[color=#6b6b5f]Further details: restricted. Darknet users know more.[/color]" % [p["first"], p["last"], int(p["age"]), p["street"], p["job"]]
	return {"title": "%s %s" % [p["first"], p["last"]], "body": body}


func world_search(q: String) -> Array:
	var out: Array = []
	for b in world.get("businesses", []):
		var label: String = WorldGen.business_label(str(b["kind"])).to_lower()
		if str(b["name"]).to_lower().contains(q) or label.contains(q) or str(b["street"]).to_lower().contains(q) or str(b["kind"]).contains(q):
			out.append({"title": b["name"], "url": "netstate.vd/biz/" + str(b["id"]), "snippet": "%s - %s" % [WorldGen.business_label(str(b["kind"])), b["street"]]})
	for p in world.get("people", []):
		if ("%s %s" % [p["first"], p["last"]]).to_lower().contains(q) or str(p["last"]).to_lower() == q:
			out.append({"title": "%s %s - Citizen Directory" % [p["first"], p["last"]], "url": "netstate.vd/citizens/" + str(p["id"]), "snippet": str(p["job"])})
	return out
