extends RefCounted
## The HEARTH filesystem: a read-only tree from data/v2/os.json ("fs": folders are objects, files are strings),
## plus your own edits under /home/citizen, saved in state.os["edits"] (path -> text).

const Content := preload("res://v2/sim/content.gd")
const HOME := "/home/citizen"


static func data() -> Dictionary:
	return Content.get_file("os")


## Resolve a path typed relative to cwd: handles ~, ., .., absolute paths.
static func norm(cwd: String, path: String) -> String:
	var p := path.strip_edges()
	if p == "" or p == "~":
		return HOME
	if p.begins_with("~/"):
		p = HOME + p.substr(1)
	elif not p.begins_with("/"):
		p = cwd.rstrip("/") + "/" + p
	var out: Array = []
	for part in p.split("/", false):
		if part == "." or part == "":
			continue
		if part == "..":
			if not out.is_empty():
				out.pop_back()
		else:
			out.append(part)
	return "/" + "/".join(PackedStringArray(out))


static func node(state: RefCounted, path: String) -> Variant:
	var cur: Variant = data().get("fs", {})
	for part in path.split("/", false):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			# new files you made yourself
			var edits: Dictionary = state.os.get("edits", {}) if state else {}
			return edits[path] if edits.has(path) else null
	if cur is String and state:
		var edits: Dictionary = state.os.get("edits", {})
		if edits.has(path):
			return edits[path]
	return cur


static func is_dir(state: RefCounted, path: String) -> bool:
	return node(state, path) is Dictionary


static func exists(state: RefCounted, path: String) -> bool:
	return node(state, path) != null


## [{name, dir, kind, path}], folders first.
static func list(state: RefCounted, path: String) -> Array:
	var n: Variant = node(state, path)
	var out: Array = []
	if not n is Dictionary:
		return out
	var names: Array = (n as Dictionary).keys()
	# files you created here
	if state:
		var edits: Dictionary = state.os.get("edits", {})
		for p in edits:
			var ps: String = p
			if ps.get_base_dir() == path and not names.has(ps.get_file()):
				names.append(ps.get_file())
	for nm in names:
		var name: String = nm
		var full := (path.rstrip("/") + "/" + name)
		var d := is_dir(state, full)
		out.append({"name": name, "dir": d, "kind": "folder" if d else kind_of(name), "path": full})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["dir"] != b["dir"]:
			return a["dir"]
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return out


static func read(state: RefCounted, path: String) -> String:
	var n: Variant = node(state, path)
	if not n is String:
		return ""
	var s: String = n
	if s.begins_with("@") and data().has(s.substr(1)):
		return str(data()[s.substr(1)])
	return s


static func can_write(path: String) -> bool:
	return path.begins_with(HOME + "/")


static func write(state: RefCounted, path: String, text: String) -> bool:
	if not can_write(path):
		return false
	if not state.os.has("edits"):
		state.os["edits"] = {}
	state.os["edits"][path] = text
	return true


static func kind_of(name: String) -> String:
	match name.get_extension().to_lower():
		"txt", "conf", "log", "md":
			return "text"
		"img", "jpg", "png":
			return "image"
		"prog", "bin", "sh":
			return "program"
		"note":
			return "note"
	return "file"
