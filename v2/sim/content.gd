extends RefCounted
## Loads data/v2/*.json once and caches it.

static var _cache := {}


static func get_file(name: String) -> Dictionary:
	if not _cache.has(name):
		var d = null
		var f := FileAccess.open("res://data/v2/%s.json" % name, FileAccess.READ)
		if f != null:
			d = JSON.parse_string(f.get_as_text())
		if not d is Dictionary:
			push_error("content: bad or missing data/v2/%s.json" % name)
			d = {}
		_cache[name] = d
	return _cache[name]


static func world() -> Dictionary:
	return get_file("world")


static func stations() -> Dictionary:
	return get_file("stations")


static func station(id: String) -> Dictionary:
	for s in stations().get("stations", []):
		if s["id"] == id:
			return s
	return {}
