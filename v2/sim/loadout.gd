extends RefCounted
## Your people and what they carry (docs/RUNDOWN.md section 9). No nodes.
## state.people:   [{id, name, role, trait, line, alive, level, ops, kit: {slot: item id}, grid: [{gear, x, y, item}]}]
## state.supplies: {gear id: count} for bulk things (clips, shells, mags, flashes, charges)
## state.items:    the stash; wearable items carry "gear" (a key in data/v2/gear.json) and "on" (a person id)
## A grid entry with "item" points at a stash item (a crafted bandage); without it, it came from supplies.

const Content := preload("res://v2/sim/content.gd")


static func gear() -> Dictionary:
	return Content.get_file("gear").get("items", {})


static func gdef(id: String) -> Dictionary:
	return gear().get(id, {})


static func item_by_id(state: RefCounted, id: int) -> Dictionary:
	for it in state.items:
		if int(it.get("id", -1)) == id:
			return it
	return {}


static func person(state: RefCounted, pid: String) -> Dictionary:
	for p in state.people:
		if p["id"] == pid:
			return p
	return {}


# ------------------------------------------------------------------ new game

static func start(state: RefCounted) -> void:
	var g := Content.get_file("gear")
	state.people = []
	var i := 0
	for p in g.get("start_people", []):
		var pd: Dictionary = (p as Dictionary).duplicate()
		pd["id"] = "p%d" % i
		pd["alive"] = true
		pd["level"] = 1
		pd["ops"] = 0
		pd["loyalty"] = int(Content.get_file("economy").get("loyalty_start", 70))
		pd["kit"] = {}
		pd["grid"] = []
		state.people.append(pd)
		i += 1
	for gid in g.get("start_stash", []):
		add_item(state, gid, {"source": "start"})
	state.supplies = (g.get("start_supplies", {}) as Dictionary).duplicate()
	# put the street clothes on, hand out the two guns and the pipes
	for p in state.people:
		var clothes := _free_item(state, "street")
		if not clothes.is_empty():
			equip(state, p, clothes)


static func add_item(state: RefCounted, gid: String, extra := {}) -> Dictionary:
	var d := gdef(gid)
	var it := {"id": state.next_item_id, "name": d.get("name", gid), "type": "gear", "gear": gid, "stars": 0, "quality": 0.0,
		"hand": true, "perks": [], "day": state.day}
	for k in extra:
		it[k] = extra[k]
	state.next_item_id += 1
	state.items.append(it)
	return it


static func _free_item(state: RefCounted, gid: String) -> Dictionary:
	for it in state.items:
		if it.get("gear", "") == gid and str(it.get("on", "")) == "":
			return it
	return {}


## Items in the stash that could go in a slot (and aren't worn by someone else).
static func options(state: RefCounted, slot: String) -> Array:
	var out: Array = []
	for it in state.items:
		var d := gdef(str(it.get("gear", "")))
		if d.get("slot", "") == slot and str(it.get("on", "")) == "":
			out.append(it)
	return out


# ------------------------------------------------------------------ wearing

static func equip(state: RefCounted, p: Dictionary, it: Dictionary) -> String:
	var d := gdef(str(it.get("gear", "")))
	var slot: String = d.get("slot", "")
	if slot == "":
		return "That doesn't go on a slot."
	if slot == "plate":
		var rig := worn(state, p, "rig")
		if rig.is_empty() or not gdef(rig["gear"]).get("plates", false):
			return "Plates need a plate carrier."
	unequip(state, p, slot)
	p["kit"][slot] = int(it["id"])
	it["on"] = p["id"]
	if slot == "rig":
		_trim_grid(state, p)
	return ""


static func unequip(state: RefCounted, p: Dictionary, slot: String) -> void:
	if not p["kit"].has(slot):
		return
	var it := item_by_id(state, int(p["kit"][slot]))
	if not it.is_empty():
		it.erase("on")
	p["kit"].erase(slot)
	if slot == "rig":
		unequip(state, p, "plate")      # no carrier, no plate
		_trim_grid(state, p)


static func worn(state: RefCounted, p: Dictionary, slot: String) -> Dictionary:
	if not p["kit"].has(slot):
		return {}
	return item_by_id(state, int(p["kit"][slot]))


# ------------------------------------------------------------------ the rig grid

## [w, h] of this person's rig (a crafted rig's own grid, which quality can enlarge), or [0, 0].
static func grid_size(state: RefCounted, p: Dictionary) -> Vector2i:
	var rig := worn(state, p, "rig")
	if rig.is_empty():
		return Vector2i(0, 0)
	var g: Array = rig.get("grid", gdef(rig["gear"]).get("grid", [0, 0]))
	return Vector2i(int(g[0]), int(g[1]))


static func cells(gid: String) -> Vector2i:
	var c: Array = gdef(gid).get("cells", [1, 1])
	return Vector2i(int(c[0]), int(c[1]))


static func fits(state: RefCounted, p: Dictionary, gid: String, x: int, y: int, ignore := -1) -> bool:
	var gs := grid_size(state, p)
	var c := cells(gid)
	if x < 0 or y < 0 or x + c.x > gs.x or y + c.y > gs.y:
		return false
	var r := Rect2i(x, y, c.x, c.y)
	for i in p["grid"].size():
		if i == ignore:
			continue
		var e: Dictionary = p["grid"][i]
		var ec := cells(e["gear"])
		if r.intersects(Rect2i(int(e["x"]), int(e["y"]), ec.x, ec.y)):
			return false
	return true


## The first free spot for something, or (-1, -1).
static func free_spot(state: RefCounted, p: Dictionary, gid: String) -> Vector2i:
	var gs := grid_size(state, p)
	for y in gs.y:
		for x in gs.x:
			if fits(state, p, gid, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Put a supply (gear id) or a stash item into the grid at x, y. Returns "" or why not.
static func pack(state: RefCounted, p: Dictionary, gid: String, x: int, y: int, item_id := -1) -> String:
	if not fits(state, p, gid, x, y):
		return "Doesn't fit there."
	if item_id >= 0:
		var it := item_by_id(state, item_id)
		if it.is_empty() or str(it.get("on", "")) != "":
			return "Already carried."
		it["on"] = p["id"]
		p["grid"].append({"gear": gid, "x": x, "y": y, "item": item_id})
	else:
		if int(state.supplies.get(gid, 0)) <= 0:
			return "None left."
		state.supplies[gid] = int(state.supplies[gid]) - 1
		p["grid"].append({"gear": gid, "x": x, "y": y})
	return ""


static func unpack(state: RefCounted, p: Dictionary, index: int) -> void:
	var e: Dictionary = p["grid"][index]
	if e.has("item"):
		var it := item_by_id(state, int(e["item"]))
		if not it.is_empty():
			it.erase("on")
	else:
		state.supplies[e["gear"]] = int(state.supplies.get(e["gear"], 0)) + 1
	p["grid"].remove_at(index)


static func _trim_grid(state: RefCounted, p: Dictionary) -> void:
	var gs := grid_size(state, p)
	for i in range(p["grid"].size() - 1, -1, -1):
		var e: Dictionary = p["grid"][i]
		var c := cells(e["gear"])
		if int(e["x"]) + c.x > gs.x or int(e["y"]) + c.y > gs.y:
			unpack(state, p, i)


## Stash items that can go in a rig grid (crafted meds), not already carried.
static func packable_items(state: RefCounted) -> Array:
	var out: Array = []
	for it in state.items:
		var d := gdef(str(it.get("gear", "")))
		if d.has("cells") and str(it.get("on", "")) == "":
			out.append(it)
	return out


# ------------------------------------------------------------------ into the fight

## A fighter definition for the fight (actor.setup_actor + soldier.setup) from what they wear and carry.
static func to_fighter(state: RefCounted, p: Dictionary) -> Dictionary:
	var prim := worn(state, p, "primary")
	var side := worn(state, p, "sidearm")
	var wid := ""
	var weapon_item := prim if not prim.is_empty() and gdef(prim["gear"]).get("weapon", "") != "" else side
	if not weapon_item.is_empty():
		wid = gdef(weapon_item["gear"]).get("weapon", "")
	var ammo_gid: String = gdef(weapon_item.get("gear", "")).get("ammo", "") if not weapon_item.is_empty() else ""
	var mags := 0
	var meds := 0
	var flash := 0
	var charges := 0
	for e in p["grid"]:
		var d := gdef(e["gear"])
		if e["gear"] == ammo_gid:
			mags += 1
		meds += int(d.get("med", 0))
		flash += int(d.get("flash", 0))
		charges += int(d.get("charge", 0))
	var plate := worn(state, p, "plate")
	var head := worn(state, p, "head")
	var face := worn(state, p, "face")
	var back := worn(state, p, "back")
	var rig := worn(state, p, "rig")
	var clothes := worn(state, p, "clothes")
	return {
		"id": p["id"], "name": p["name"], "role": p.get("role", "rear"), "trait": p.get("trait", ""), "line": p.get("line", ""),
		"camo": gdef(clothes.get("gear", "street")).get("camo", "street") if not clothes.is_empty() else "street",
		"head": {"Gear_Helmet": "helmet", "Gear_Cap": "cap", "Gear_Beanie": "beanie"}.get(gdef(head.get("gear", "")).get("mesh", ""), "none"),
		"mask": not face.is_empty(),
		"back": {"Gear_Pack": "pack", "Gear_MedBag": "medbag"}.get(gdef(back.get("gear", "")).get("mesh", ""), ""),
		"rig_mesh": gdef(rig.get("gear", "")).get("mesh", ""),
		"weapon_mesh": gdef(weapon_item.get("gear", "")).get("mesh", "") if not weapon_item.is_empty() else "",
		"knees": false,
		"armed": wid != "",
		"gear": {"weapon": wid if wid != "" else "pistol", "round": "fmj", "attach": [],
			"plate": int(gdef(plate.get("gear", "")).get("plate", 0)) if not plate.is_empty() else 0,
			"mags": maxi(1, mags) if wid != "" else 0, "meds": meds, "flash": flash, "charges": charges},
	}


## After an op: the dead stay dead (their kit is lost with them), what was used is gone, loot comes home.
## used: {person id: {"mags": n, "meds": n, "flash": n, "charges": n}}  (how many of each they spent)
static func apply_op(state: RefCounted, results: Array, loot: Array) -> Array:
	var notes: Array = []
	for r in results:
		var p := person(state, r["id"])
		if p.is_empty():
			continue
		if r["state"] == "dead":
			p["alive"] = false
			for slot in p["kit"].keys():
				var it := item_by_id(state, int(p["kit"][slot]))
				state.items.erase(it)
			p["kit"] = {}
			p["grid"] = []
			notes.append("%s didn't come home. Their kit is gone." % p["name"])
			continue
		p["ops"] = int(p.get("ops", 0)) + 1
		var used: Dictionary = r.get("used", {})
		_spend(state, p, "ammo", int(used.get("mags", 0)))
		_spend(state, p, "med", int(used.get("meds", 0)))
		_spend(state, p, "flash", int(used.get("flash", 0)))
		_spend(state, p, "charge", int(used.get("charges", 0)))
	for gid in loot:
		add_item(state, gid, {"source": "loot"})
		notes.append("Looted: %s" % gdef(gid).get("name", gid))
	return notes


static func _spend(state: RefCounted, p: Dictionary, what: String, n: int) -> void:
	for k in n:
		for i in range(p["grid"].size() - 1, -1, -1):
			var e: Dictionary = p["grid"][i]
			var d := gdef(e["gear"])
			var hit := false
			match what:
				"ammo":
					hit = d.has("rounds")
				"med":
					hit = d.has("med")
				"flash":
					hit = d.has("flash")
				"charge":
					hit = d.has("charge")
			if hit:
				if e.has("item"):
					state.items.erase(item_by_id(state, int(e["item"])))
				p["grid"].remove_at(i)
				break
