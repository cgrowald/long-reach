extends RefCounted
## Loads and caches the JSON files in res://data. Pure data access, no scene dependencies.

const MATERIALS_PATH := "res://data/materials.json"
const WEAPONS_PATH := "res://data/weapons.json"
const UNIT_TYPES_PATH := "res://data/unit_types.json"
const EQUIPMENT_PATH := "res://data/equipment.json"
const CLASSES_PATH := "res://data/classes.json"

static var _cache: Dictionary = {}


static func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		result = parsed
	else:
		push_error("GameData: could not parse %s" % path)
	_cache[path] = result
	return result


static func materials() -> Dictionary:
	return load_json(MATERIALS_PATH)


static func weapon(id: String) -> Dictionary:
	return _entry(WEAPONS_PATH, id)


static func unit_type(id: String) -> Dictionary:
	return _entry(UNIT_TYPES_PATH, id)


static func equipment(id: String) -> Dictionary:
	return _entry(EQUIPMENT_PATH, id)


static func class_def(id: String) -> Dictionary:
	return _entry(CLASSES_PATH, id)


static func _entry(path: String, id: String) -> Dictionary:
	var all: Dictionary = load_json(path)
	if not all.has(id):
		push_error("GameData: '%s' not found in %s" % [id, path])
		return {}
	return all[id]


static func color_from(entry: Dictionary, fallback: Color = Color.MAGENTA) -> Color:
	var c: Variant = entry.get("color")
	if typeof(c) == TYPE_ARRAY and (c as Array).size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return fallback
