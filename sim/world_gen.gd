extends RefCounted
## Generates a run's town from data/os/world.json: businesses (with staff), residents with
## weak spots, the day's rule and news. Pure data, saved inside the laptop state.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/os/world.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else {}
		_data = d if d is Dictionary else {}
	return _data


static func generate(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var d := data()
	var streets: Array = d["streets"]
	var used_names: Dictionary = {}
	var people: Array = []
	var businesses: Array = []
	var trait_keys: Array = d["traits"].keys()
	for kind in d["town_layout"]:
		var k: Dictionary = d["business_kinds"][kind]
		var names: Array = k["names"].duplicate()
		for i in int(d["town_layout"][kind]):
			var nm: String = str(names[rng.randi() % names.size()])
			names.erase(nm)
			if names.is_empty():
				names = k["names"].duplicate()
			var b := {"id": "%s_%d" % [kind, i], "kind": kind, "name": nm, "street": str(streets[rng.randi() % streets.size()]),
				"number": rng.randi_range(2, 88), "staff": [], "flavor": str(k["flavor"][rng.randi() % k["flavor"].size()]),
				"weakness": _weakness(kind, rng)}
			businesses.append(b)
			for s in rng.randi_range(1, 3):
				var p := _person(d, rng, used_names, trait_keys, streets)
				p["employer"] = b["id"]
				p["job"] = "%s at %s" % [_job_title(kind, rng), nm]
				people.append(p)
				b["staff"].append(p["id"])
	# Residents without a listed employer (neighbours, pensioners).
	for i in 10:
		var p := _person(d, rng, used_names, trait_keys, streets)
		p["employer"] = ""
		p["job"] = ["pensioner", "unemployed (registered)", "night watchman", "student", "seamstress"][rng.randi() % 5]
		people.append(p)
	return {"seed": seed, "town": str(d["towns"][0]), "businesses": businesses, "people": people}


static func _person(d: Dictionary, rng: RandomNumberGenerator, used: Dictionary, traits: Array, streets: Array) -> Dictionary:
	var first := ""
	var last := ""
	for tries in 30:
		first = str(d["first_names"][rng.randi() % d["first_names"].size()])
		last = str(d["last_names"][rng.randi() % d["last_names"].size()])
		if not used.has(first + last):
			break
	used[first + last] = true
	return {"id": "p_%s_%s" % [first.to_lower(), last.to_lower()], "first": first, "last": last,
		"age": rng.randi_range(19, 74), "street": str(streets[rng.randi() % streets.size()]),
		"trait": str(traits[rng.randi() % traits.size()]), "seed": rng.randi()}


static func _job_title(kind: String, rng: RandomNumberGenerator) -> String:
	var t := {"electronics": ["repairman", "counter clerk"], "hardware": ["shop assistant", "stock clerk"], "pharmacy": ["pharmacist", "assistant"],
		"gun_store": ["range officer", "clerk"], "cafe": ["barista", "owner"], "lounge": ["night attendant", "cashier"],
		"hospital": ["nurse", "orderly", "records clerk"], "police": ["sergeant", "desk officer", "constable"],
		"ministry": ["records clerk", "deputy registrar", "archivist"], "refinery": ["furnace operator", "shift supervisor", "loader"],
		"market": ["stallholder", "porter"], "plant": ["mechanic", "line worker", "shift boss"]}
	var opts: Array = t.get(kind, ["worker"])
	return str(opts[rng.randi() % opts.size()])


## What's sloppy about this place (the angle you can learn). Shown when you scout or get a lead.
static func _weakness(kind: String, rng: RandomNumberGenerator) -> String:
	var w := {
		"ministry": ["public kiosk on factory settings", "clerks write passwords under keyboards", "archive server never patched"],
		"police": ["dispatch radio not encrypted", "evidence room badge reader is ten years old", "night desk sleeps at 3"],
		"gun_store": ["back door alarm on a timer", "stock list on an unpatched office PC", "owner gambles"],
		"refinery": ["shift change leaves the yard gate open", "truck manifests on a shared password", "guard post camera loops itself"],
		"hospital": ["drug cabinet keypad worn on three keys", "staff badges cloneable", "records PC in an unlocked office"],
		"electronics": ["sells flagged parts off the books", "owner hates the new registration rule"],
		"hardware": ["registration book kept on paper, at the till", "clerk doesn't check citizen numbers"],
		"cafe": ["public PCs never wiped", "router admin page on default password"],
		"lounge": ["machines share one admin account", "keystroke logger crashes after midnight"],
		"pharmacy": ["prescription system offline half the day"],
		"market": ["ration lists posted on the wall"],
		"plant": ["vehicle keys on a board by the gate"],
	}
	var opts: Array = w.get(kind, ["nothing obvious"])
	return str(opts[rng.randi() % opts.size()])


static func find(world: Dictionary, list: String, id: String) -> Dictionary:
	for x in world.get(list, []):
		if str(x["id"]) == id:
			return x
	return {}


static func business_label(kind: String) -> String:
	return str(data()["business_kinds"].get(kind, {}).get("label", kind))


## Today's rule and three headlines, from the day number (stable for the day).
static func day_news(world: Dictionary, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.get("seed", 1)) * 1000 + day
	var d := data()
	var rule: String = str(d["rules"][(day + int(world.get("seed", 0))) % d["rules"].size()])
	var news: Array = ["NEW RULE: " + rule]
	var people: Array = world.get("people", [])
	var biz: Array = world.get("businesses", [])
	for i in 3:
		var t: String = str(d["news"][rng.randi() % d["news"].size()])
		var p: Dictionary = people[rng.randi() % people.size()] if not people.is_empty() else {"first": "A", "last": "Citizen", "job": "citizen"}
		var b: Dictionary = biz[rng.randi() % biz.size()] if not biz.is_empty() else {"name": "a plant", "street": "a street"}
		t = t.replace("{person}", "%s %s" % [p["first"], p["last"]]).replace("{job}", str(p.get("job", ""))).replace("{business}", str(b["name"]))
		t = t.replace("{street}", str(b["street"])).replace("{n}", str(rng.randi_range(12, 90)))
		if not news.has(t):
			news.append(t)
	return {"rule": rule, "news": news}
