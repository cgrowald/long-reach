extends RefCounted
## Which portrait a person gets (data/v2/faces.json: GPT's face sheets). No nodes.
## The pick depends only on the name, so a person has the same face in the cage, the fight, the chair and on
## their ID: "Oskar Moravec 77", "OSKAR MORAVEC" and "oskar moravec" are the same person.
## A seed containing "#held" picks from the bruised sheet (prisoners). Women's names get f tiles.

const Content := preload("res://v2/sim/content.gd")

static var _pools := {}        # "m" / "f" / "held_m" / "held_f" -> [{sheet, i, tags}]


static func data() -> Dictionary:
	return Content.get_file("faces")


static func _build() -> void:
	_pools = {"m": [], "f": [], "held_m": [], "held_f": []}
	var sheets: Dictionary = data().get("sheets", {})
	for sid in sheets:
		var s: Dictionary = sheets[sid]
		var tiles: Array = s.get("tiles", [])
		for i in tiles.size():
			var tags := str(tiles[i]).split(" ")
			if tags.has("regime"):
				continue                      # Bureau collars: kept for officers later
			var g := "f" if tags.has("f") else "m"
			var key := ("held_" + g) if s.get("pool", "") == "held" else g
			_pools[key].append({"sheet": sid, "i": i, "tags": tags})


## "Oskar Moravec 77" -> "OSKAR MORAVEC" (first two words, upper case).
static func norm(seed_name: String) -> String:
	var words := seed_name.replace("#held", "").strip_edges().split(" ", false)
	if words.size() >= 2:
		return (words[0] + " " + words[1]).to_upper()
	return seed_name.strip_edges().to_upper()


static func is_female(seed_name: String) -> bool:
	var first := norm(seed_name).split(" ")[0].capitalize()
	return (data().get("female_names", []) as Array).has(first)


## {sheet, i, tags} for this person.
static func pick(seed_name: String) -> Dictionary:
	if _pools.is_empty():
		_build()
	var g := "f" if is_female(seed_name) else "m"
	var key := ("held_" + g) if "#held" in seed_name else g
	var pool: Array = _pools.get(key, [])
	if pool.is_empty():
		pool = _pools[g]
	return pool[(hash("portrait:" + norm(seed_name)) & 0x7fffffff) % pool.size()]


## An age that fits their face (the person generator uses it, so the ID card matches the photo).
static func age_for(seed_name: String, rng: RandomNumberGenerator) -> int:
	var tags: PackedStringArray = pick(seed_name)["tags"]
	var band := "old" if tags.has("old") else ("young" if tags.has("young") else "mid")
	var r: Array = data().get("ages", {}).get(band, [28, 49])
	return rng.randi_range(int(r[0]), int(r[1]))
