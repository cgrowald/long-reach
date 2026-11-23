extends RefCounted
## A depot raid, rolled fresh every time (roadmap M1, data/v2/depot_runs.json, docs/DEPOT_SLICE.md). No nodes.
## create() rolls: the depot kind (one per bench), the guards (person generator: poor weapons, infinite ammo with
## reloads), the stores you came for, and what's behind the three vault doors (mostly junk, sometimes amazing).
## Hacking before the raid can reveal a door's tier (hints). After a raid the depot locks for reset_days and
## remembers how you won (state.flags.depot.wins), for the enemy that learns (M4).

const Content := preload("res://v2/sim/content.gd")
const People := preload("res://v2/sim/people_gen.gd")
const Materials := preload("res://v2/sim/materials.gd")
const Loadout := preload("res://v2/sim/loadout.gd")
const Crafting := preload("res://v2/sim/crafting.gd")

const FAMILY := {"electronics": ["board", "chips"], "weapons": ["alu", "pins"], "meds": ["shirt", "alcohol", "tape"], "armor": ["bag", "strap", "buckle"]}


static func data() -> Dictionary:
	return Content.get_file("depot_runs")


static func _d(state: RefCounted) -> Dictionary:
	var d: Dictionary = state.flags.get("depot", {})
	for k in ["raids", "locked_until"]:
		if not d.has(k):
			d[k] = 0
	if not d.has("wins"):
		d["wins"] = []
	state.flags["depot"] = d
	return d


## Nights left before the depot can be hit again (0 = open).
static func locked_for(state: RefCounted) -> int:
	return maxi(0, int(_d(state)["locked_until"]) - int(state.day))


static func create(state: RefCounted, p_seed: int) -> Dictionary:
	var D := data()
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var kinds: Array = (D.get("kinds", {}) as Dictionary).keys()
	var kind: String = kinds[rng.randi() % kinds.size()]
	var kd: Dictionary = D["kinds"][kind]
	var run := {"seed": p_seed, "kind": kind, "kind_name": kd.get("name", kind), "bench": kd.get("bench", ""),
		"stores_title": kd.get("stores_title", "Stores"), "guards": [], "doors": [], "opened": -1, "hints": [false, false, false]}
	# guards
	var g: Dictionary = D.get("guards", {})
	var base: Array = g.get("base", [3, 4])
	var n := rng.randi_range(int(base[0]), int(base[1])) + int(float(state.attention) / float(g.get("per_attention", 30)))
	n = mini(n, int(g.get("max", 6)))
	var posts: Array = (D.get("posts", []) as Array).duplicate()
	for i in range(posts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = posts[i]
		posts[i] = posts[j]
		posts[j] = t
	var wmap: Dictionary = g.get("weapons", {})
	for i in mini(n, posts.size()):
		var post: Dictionary = posts[i]
		var p := People.make(hash(str(p_seed) + "guard" + str(i)), "guard")
		var gear_id: String = p.get("weapon", "service_pistol")
		var e := {"id": "g%d" % i, "name": "%s %s" % [str(p.get("rank", "Guard")).to_lower(), p["last"]], "kind": "guard",
			"pos": post["pos"], "yaw": post.get("yaw", 0.0), "state": post.get("state", "idle"), "camo": "regime_low", "head": "cap",
			"gear": {"weapon": wmap.get(gear_id, "pistol"), "round": "fmj", "attach": [], "plate": 0, "mags": 99, "meds": 0},
			"person": p}
		if post.has("patrol"):
			e["patrol"] = post["patrol"]
		if post.get("timid", false):
			e["timid"] = true
		run["guards"].append(e)
	# the stores (what you came for)
	var stores := {}
	var sd: Dictionary = kd.get("stores", {})
	for id in sd:
		var r: Array = sd[id]
		stores[id] = rng.randi_range(int(r[0]), int(r[1]))
	run["stores"] = stores
	# the vault: three doors, rolled now, hidden until opened (or hinted)
	for i in 3:
		run["doors"].append(_roll_door(state, rng, run))
	return run


static func _roll_door(state: RefCounted, rng: RandomNumberGenerator, run: Dictionary) -> Dictionary:
	var V: Dictionary = data().get("vault", {})
	var tiers: Array = V.get("tiers", [])
	var total := 0
	for t in tiers:
		total += int(t["weight"])
	var roll := rng.randi_range(1, maxi(1, total))
	var tier := "junk"
	var label := "Junk"
	for t in tiers:
		roll -= int(t["weight"])
		if roll <= 0:
			tier = t["id"]
			label = t.get("label", tier)
			break
	var pool: Array = V.get(tier, [])
	var e: Dictionary = (pool[rng.randi() % pool.size()] as Dictionary).duplicate(true) if not pool.is_empty() else {"type": "empty"}
	var fam: Array = FAMILY.get(run["bench"], ["shirt"])
	var c := {"tier": tier, "label": label, "type": e.get("type", "empty"), "line": e.get("line", "")}
	match c["type"]:
		"material":
			var cr: Array = e.get("count", [3, 5])
			var gr: Array = e.get("grade", [1, 1])
			c["id"] = fam[rng.randi() % fam.size()]
			c["count"] = rng.randi_range(int(cr[0]), int(cr[1]))
			c["grade"] = rng.randi_range(int(gr[0]), int(gr[1]))
		"supply", "gear":
			var p: Array = e.get("pool", ["picks"])
			c["id"] = p[rng.randi() % p.size()]
			var cr2: Array = e.get("count", [1, 1])
			c["count"] = rng.randi_range(int(cr2[0]), int(cr2[1]))
		"upgrade", "upgrade_clean":
			var ups := []
			for id in Crafting.upgrades_def():
				var u: Dictionary = Crafting.upgrades_def()[id]
				if u.get("bench", "") == run["bench"] and not Crafting.installed(state).has(id):
					if c["type"] == "upgrade" or not u.has("quirk"):
						ups.append(id)
			if ups.is_empty():
				c["type"] = "material"
				c["id"] = fam[0]
				c["count"] = 4
				c["grade"] = 4
			else:
				c["id"] = ups[rng.randi() % ups.size()]
				c["type"] = "upgrade"
		"blueprint":
			var bps: Array = []
			for id in data().get("blueprints", []):
				if not state.unlocked_recipes.has(id):
					bps.append(id)
			if bps.is_empty():
				c["type"] = "upgrade"
				c["id"] = "magnifier_lamp"
			else:
				c["id"] = bps[rng.randi() % bps.size()]
		"empty":
			var lines: Array = e.get("lines", ["Empty."])
			c["line"] = lines[rng.randi() % lines.size()]
	return c


## Intel before the raid: each depot "plan" file you hold reveals one door's tier (up to all three).
static func apply_hints(state: RefCounted, run: Dictionary) -> int:
	var n := 0
	for it in state.items:
		if it.get("type", "") == "intel" and it.get("tag", "") == "plan" and ("Dobrev" in str(it.get("source", "")) or "depot" in str(it.get("source", "")).to_lower()):
			n += 1
	for i in mini(n, 3):
		run["hints"][i] = true
	return mini(n, 3)


## What a door shows on the ops board before it's opened: its tier if hinted, else "?".
static func door_hint(run: Dictionary, i: int) -> String:
	return str(run["doors"][i]["label"]) if run["hints"][i] else "?"


## Words for a door's contents (after it's opened).
static func describe(c: Dictionary) -> String:
	match str(c.get("type", "")):
		"material":
			return "%d x %s %s" % [int(c["count"]), Content.get_file("recipes").get("materials", {}).get(c["id"], {}).get("name", c["id"]), Materials.stars(int(c["grade"]))]
		"supply", "gear":
			return "%d x %s" % [int(c.get("count", 1)), Loadout.gdef(c["id"]).get("name", c["id"])]
		"upgrade":
			var u: Dictionary = Crafting.upgrades_def().get(c["id"], {})
			return "Bench upgrade: %s (%s)%s" % [u.get("name", c["id"]), u.get("text", ""), "  QUIRK: " + str(u["quirk"].get("text", "")) if u.has("quirk") else ""]
		"blueprint":
			return "BLUEPRINT: %s" % Crafting.recipe(c["id"]).get("name", c["id"])
		"intel_junk":
			return "A folder of old filing"
		_:
			return "Nothing"


## Bring a door's contents home (only if the squad escorted it out).
static func grant(state: RefCounted, c: Dictionary) -> String:
	match str(c.get("type", "")):
		"material":
			Materials.add(state, c["id"], int(c["count"]), int(c["grade"]))
		"supply":
			state.supplies[c["id"]] = int(state.supplies.get(c["id"], 0)) + int(c["count"])
		"gear":
			for i in int(c.get("count", 1)):
				Loadout.add_item(state, c["id"], {"source": "depot vault"})
		"upgrade":
			Crafting.install_upgrade(state, c["id"])
		"blueprint":
			if not state.unlocked_recipes.has(c["id"]):
				state.unlocked_recipes.append(c["id"])
		"intel_junk":
			state.items.append({"id": state.next_item_id, "name": "old_filing.txt", "type": "intel", "tag": "names", "worth": "Old staff lists from the depot. Worth a little.", "source": "Dobrev Freight depot", "day": state.day, "stars": 0, "quality": 0.0, "hand": true, "perks": []})
			state.next_item_id += 1
	return describe(c)


## The stores you carry out: limited by what the surviving squad can carry (free rig cells).
static func carry_stores(state: RefCounted, run: Dictionary, cells: int) -> Array:
	var lines: Array = []
	var left := cells
	for id in run["stores"]:
		if left <= 0:
			break
		var n := mini(int(run["stores"][id]), left)
		left -= n
		if Content.get_file("recipes").get("materials", {}).has(id):
			Materials.add(state, id, n, 3)
			lines.append("%d x %s" % [n, Content.get_file("recipes")["materials"][id].get("name", id)])
		else:
			state.supplies[id] = int(state.supplies.get(id, 0)) + n
			lines.append("%d x %s" % [n, Loadout.gdef(id).get("name", id)])
	return lines


## After the raid: lock the depot and remember how you won.
static func close(state: RefCounted, run: Dictionary, how: Dictionary) -> void:
	var d := _d(state)
	d["raids"] = int(d["raids"]) + 1
	d["locked_until"] = int(state.day) + int(data().get("reset_days", 6))
	var w: Array = d["wins"]
	w.append(how)
	if w.size() > 10:
		w.pop_front()
