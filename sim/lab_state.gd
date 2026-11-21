extends RefCounted
## One hacking lab session (data/labs/<id>.json): a network map you discover, typed commands,
## a trace meter, hints, patterns, and loot. Pure rules; terminal/apps/probe_app.gd shows it.

const Loot := preload("res://sim/loot.gd")

var state                    # TerminalState
var lab: Dictionary = {}
var flags: Dictionary = {}   # lab-local progress flags
var discovered: Dictionary = {"you": true}
var access: Dictionary = {}
var locked: Dictionary = {}
var fails: Dictionary = {}
var trace := 0.0
var ended := false
var outcome := ""            # "done" or "burned"
var drops: Array = []
var _pending_login: Dictionary = {}
var _opened: String = ""     # the last thing you opened ("search" works on it)


static func load_lab(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/labs/%s.json" % id, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _init(st, id: String) -> void:
	state = st
	lab = load_lab(id)
	discovered[str(lab.get("entry", ""))] = true
	for v in lab.get("start_known", []):
		learn(str(v))


func node_def(n: String) -> Dictionary:
	return lab.get("nodes", {}).get(n, {})


func visible_nodes() -> Array:
	return discovered.keys().filter(func(n): return n != "you")


func learn(chip: String) -> void:
	if not state.learned.has(chip):
		state.learned.append(chip)


func all_verbs() -> Array:
	var out: Array = ["help", "logout"]
	for n in lab.get("nodes", {}):
		for v in lab["nodes"][n].get("commands", {}):
			if not out.has(v):
				out.append(v)
	return out


func waiting_password() -> bool:
	return not _pending_login.is_empty()


func hint() -> String:
	for h in lab.get("hints", []):
		if not flags.has(str(h.get("until", ""))):
			return str(h.get("text", ""))
	return ""


# ------------------------------------------------------------- running commands

## Run one typed line. Returns {"lines": [String], "ok": bool, "drops": [Dictionary]}.
func run(line: String) -> Dictionary:
	var res := {"lines": [], "ok": false, "drops": []}
	if ended:
		res["lines"].append("Disconnected.")
		return res
	if waiting_password():
		return _finish_login(line.strip_edges(), res)
	var toks := line.strip_edges().to_lower().split(" ", false)
	if toks.is_empty():
		return res
	var verb: String = toks[0]
	if verb == "help":
		res["lines"].append("Commands you know: " + ", ".join(state.learned))
		res["lines"].append("Form: <command> <device> [extra].  Tab completes.  Type 'hint' if stuck.")
		res["ok"] = true
		return res
	if verb == "hint":
		res["lines"].append("HINT: " + hint())
		res["ok"] = true
		return res
	if verb in ["logout", "exit", "disconnect"]:
		_logout(res)
		return res
	if toks.size() < 2:
		res["lines"].append("%s what? (try: %s <device>)" % [verb, verb])
		return res
	var target: String = toks[1]
	if verb == "search" and not discovered.has(target) and _opened != "":
		toks.insert(1, _opened)
		target = _opened
	if not discovered.has(target) or target == "you":
		var sug := suggest(target, visible_nodes())
		res["lines"].append("No device called '%s' on the map.%s" % [target, ("  Did you mean '%s'?" % sug) if sug != "" else ""])
		return res
	var cmds: Dictionary = node_def(target).get("commands", {})
	if not cmds.has(verb):
		var sugv := suggest(verb, cmds.keys())
		res["lines"].append("'%s' does nothing on %s.%s" % [verb, target, ("  Did you mean '%s'?" % sugv) if sugv != "" else ""])
		return res
	var c: Dictionary = cmds[verb]
	if locked.has(target):
		res["lines"].append("%s is locked." % target)
		return res
	for r in c.get("requires", []):
		if not flags.has(str(r)):
			res["lines"].append("Not yet. You can't do that from where you are.")
			return res
	if c.has("requires_any") and not c["requires_any"].any(func(r): return flags.has(str(r))):
		res["lines"].append("Not yet. You need a way in first.")
		return res
	if c.has("once") and flags.has(str(c["once"])):
		res["lines"].append("Already done.")
		return res
	if verb == "login":
		var user: String = toks[2] if toks.size() > 2 else ""
		if user == "":
			res["lines"].append("login %s <user>" % target)
			return res
		learn("login")
		_pending_login = {"node": target, "user": user}
		res["lines"].append("password for %s@%s:" % [user, target])
		res["ok"] = true
		return res
	if verb == "search":
		var term: String = " ".join(toks.slice(2)) if toks.size() > 2 else ""
		if term == "":
			res["lines"].append("search %s <name>" % target)
			return res
		var results: Dictionary = c.get("results", {})
		var r: Dictionary = results.get(term, results.get("*", {}))
		_apply(c, target, res)
		res["lines"].append(str(r.get("text", "")))
		for fl in r.get("set", []):
			flags[str(fl)] = true
		state.do_actions(r.get("do", []))
		res["ok"] = true
		_check_burn(res)
		return res
	_apply(c, target, res)
	if verb == "open":
		_opened = target
	res["lines"].append(str(c.get("text", "")))
	res["ok"] = true
	_check_burn(res)
	return res


func _finish_login(pw: String, res: Dictionary) -> Dictionary:
	var n: String = str(_pending_login["node"])
	var user: String = str(_pending_login["user"])
	_pending_login = {}
	var c: Dictionary = node_def(n)["commands"]["login"]
	var norm := pw.to_lower().strip_edges()
	var good: bool = user == str(c.get("user", "")) and c.get("password", []).any(func(p): return norm == str(p))
	if good:
		access[n] = true
		_apply(c, n, res)
		res["lines"].append(str(c.get("text", "Logged in.")))
		res["ok"] = true
		if c.has("pattern"):
			_save_pattern(str(c["pattern"]), n, user, pw, res)
	else:
		fails[n] = int(fails.get(n, 0)) + 1
		trace += float(c.get("fail_trace", 5))
		state.advance(1)
		res["lines"].append(str(c.get("fail_text", "Access denied.")) + ("  (%d left)" % (int(c["max_fails"]) - int(fails[n])) if c.has("max_fails") and int(fails[n]) < int(c["max_fails"]) else ""))
		if c.has("max_fails") and int(fails[n]) >= int(c["max_fails"]):
			locked[n] = true
			res["lines"].append(str(c.get("lock_text", "LOCKED.")))
			for fl in c.get("lock_set", []):
				state.set_flag(str(fl))
	_check_burn(res)
	return res


func _apply(c: Dictionary, target: String, res: Dictionary) -> void:
	trace += float(c.get("trace", 0))
	if int(c.get("time", 0)) > 0:
		state.advance(int(c["time"]))
	for fl in c.get("set", []):
		flags[str(fl)] = true
	for l in c.get("learn", []):
		learn(str(l))
	for n in c.get("reveal", []):
		if not discovered.has(n):
			discovered[str(n)] = true
	state.do_actions(c.get("do", []))
	if c.has("loot"):
		var drop: Dictionary = Loot.generate(state, str(c["loot"]), {"trace": trace, "wiped": flags.has("logs_wiped")})
		if not drop.is_empty():
			drops.append(drop)
			res["drops"].append(drop)


func _check_burn(res: Dictionary) -> void:
	if trace < 100.0 or ended:
		return
	trace = 100.0
	ended = true
	outcome = "burned"
	var b: Dictionary = lab.get("burn", {})
	state.add_exposure(int(b.get("exposure", 2)), str(b.get("why", "a lab traced you")))
	state.set_flag("%s_burned" % lab.get("id", "lab"))
	res["lines"].append("\n!! TRACE 100% !! The connection drops. Somewhere a screen just showed your street.")


func _logout(res: Dictionary) -> void:
	ended = true
	outcome = "done"
	var id: String = str(lab.get("id", "lab"))
	state.set_flag("%s_done" % id)
	flags["done"] = true
	if access.size() > 0 and not flags.has("logs_wiped"):
		var l: Dictionary = lab.get("lead", {})
		state.add_exposure(int(l.get("exposure", 1)), str(l.get("why", "you left logs behind")))
	res["lines"].append("Logged out. Trace at %d%%." % int(trace))
	res["ok"] = true


# ------------------------------------------------------------- patterns

func _save_pattern(name: String, node: String, user: String, pw: String, res: Dictionary) -> void:
	if state.patterns.has(name):
		return
	state.patterns[name] = ["scan {t}", "login {t} %s" % user, pw]
	learn("pattern: " + name)
	res["lines"].append("\n>> PATTERN LEARNED: '%s'. Next time it's one click: scan, log in, type the password." % name)


## Replay a saved pattern against a target. Stops at the first step that fails.
func run_pattern(name: String, target: String) -> Dictionary:
	var out := {"lines": [">> running pattern '%s' on %s" % [name, target]], "ok": true, "drops": []}
	for step in state.patterns.get(name, []):
		var line: String = str(step).replace("{t}", target)
		out["lines"].append("> " + (line if not waiting_password() else "********"))
		var r := run(line)
		out["lines"].append_array(r["lines"])
		out["drops"].append_array(r["drops"])
		if not r["ok"]:
			out["lines"].append(">> pattern broke here. Something about this target is different.")
			out["ok"] = false
			return out
	return out


# ------------------------------------------------------------- typing help

## Closest word within 2 edits, or "".
static func suggest(word: String, options: Array) -> String:
	var best := ""
	var best_d := 3
	for o in options:
		var d := _dist(word, str(o))
		if d < best_d:
			best_d = d
			best = str(o)
	return best if best != word else ""


static func _dist(a: String, b: String) -> int:
	var prev: Array = []
	for j in b.length() + 1:
		prev.append(j)
	for i in range(1, a.length() + 1):
		var cur: Array = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost))
		prev = cur
	return prev[b.length()]


## Tab completion for the word being typed.
func complete(text: String) -> String:
	var toks := text.split(" ")
	var last := toks[toks.size() - 1].to_lower()
	var pool: Array = all_verbs() if toks.size() == 1 else visible_nodes()
	var hits: Array = pool.filter(func(p): return str(p).begins_with(last))
	if hits.size() == 1:
		toks[toks.size() - 1] = str(hits[0])
		return " ".join(toks) + " "
	return text
