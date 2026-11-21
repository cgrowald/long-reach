extends RefCounted
## Loot drops: rarity tiers, rolled traits, the Archivist's one-liner. Data in data/loot.json.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/loot.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else {}
		_data = d if d is Dictionary else {}
	return _data


static func tier(stars: int) -> Dictionary:
	return data().get("tiers", {}).get(str(stars), {"name": "?", "color": "#ffffff"})


static func trait_def(id: String) -> Dictionary:
	return data().get("traits", {}).get(id, {"name": id, "desc": ""})


## Generate a drop, put its file into the laptop, remember it. perf: {"trace": float, "wiped": bool}
static func generate(state, id: String, perf: Dictionary) -> Dictionary:
	var d: Dictionary = data().get("drops", {}).get(id, {})
	if d.is_empty():
		push_error("no loot " + id)
		return {}
	var stars: int = int(d.get("stars", 1))
	var name: String = str(d.get("name", id))
	var traits: Array = []
	for t in d.get("traits", {}):
		if randf() < float(d["traits"][t]):
			traits.append(t)
	var up: Dictionary = d.get("upgrade", {})
	if not up.is_empty() and float(perf.get("trace", 100.0)) <= float(up.get("if_quiet", 0)) \
			and (not up.get("if_wiped", false) or perf.get("wiped", false)) and randf() < float(up.get("chance", 0.0)):
		stars = mini(5, stars + 1)
		name = str(up.get("name", name))
		if up.has("trait") and not traits.has(up["trait"]):
			traits.append(up["trait"])
	var lines: Array = data().get("archivist", {}).get(str(stars), [""])
	var meta: Dictionary = {}
	for k in d.get("meta", {}):
		meta[k] = str(d["meta"][k]).replace("{TIME}", state.datetime_text())
	var path: String = str(d.get("file", "/Documents/loot/%s.txt" % id))
	var f := {"path": path, "type": "text", "text": str(d.get("text", "")), "meta": meta,
		"loot": id, "stars": stars, "traits": traits}
	if not traits.has("traceable"):
		f["meta"] = {}
	state.files[path] = f
	var drop := {"id": id, "name": name, "type": str(d.get("type", "")), "stars": stars, "traits": traits,
		"file": path, "archivist": str(lines[randi() % lines.size()]), "day": state.day}
	state.loot.append(drop)
	state.log_lines.append("Loot: %s (%d stars)." % [name, stars])
	return drop
