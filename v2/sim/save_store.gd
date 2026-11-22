extends RefCounted
## Save slots on disk: three manual slots + an autosave. JSON files with a small header for the load screen.
## Tests MUST set `dir` to a test folder first.

const SLOTS := ["auto", "1", "2", "3"]

static var dir := "user://saves_v2"


static func path(slot: String) -> String:
	return "%s/slot_%s.json" % [dir, slot]


static func write(slot: String, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var doc := {
		"meta": {"day": state.get("day", 1), "money": state.get("money", 0),
			"playtime": state.get("playtime", 0.0), "saved_at": Time.get_datetime_string_from_system(false, true)},
		"state": state,
	}
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: can't write %s" % tmp)
		return false
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	# Write then rename, so a crash mid-save never eats the old save.
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(path(slot))
	return DirAccess.rename_absolute(tmp, path(slot)) == OK


static func _read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func meta(slot: String) -> Dictionary:
	return _read(slot).get("meta", {})


static func read_state(slot: String) -> Dictionary:
	return _read(slot).get("state", {})


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


static func delete(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))


## The slot with the newest save (for Continue), or "".
static func latest() -> String:
	var best := ""
	var best_t := -1
	for s in SLOTS:
		if exists(s):
			var t := FileAccess.get_modified_time(path(s))
			if t > best_t:
				best_t = t
				best = s
	return best
