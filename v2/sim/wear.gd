extends RefCounted
## Wear, tears and mending (docs/BENCH_SEWING.md; data/v2/wear.json). No nodes.
## Clothes and rigs wear a little every op (condition, 0-100) and tear when the fighter is hit: each tear is a
## spot on the item (item.tears = ["sleeve_r", ...]). You mend tears at the sewing table with a scrap patch in a
## colour you pick; the patch stays (item.patches = [{spot, colour}]) and shows on the fighter.
## A rig with 2+ tears loses a pouch column until mended (Loadout.grid_size).

const Content := preload("res://v2/sim/content.gd")


static func data() -> Dictionary:
	return Content.get_file("wear")


## Which base (data key) an item uses on the table: "clothes", "rig_market" or "rig_chest" (carriers too).
static func base_key(item: Dictionary) -> String:
	var gid := str(item.get("gear", ""))
	var g: Dictionary = Content.get_file("gear").get("items", {}).get(gid, {})
	match str(g.get("slot", "")):
		"clothes":
			return "clothes"
		"rig":
			return "rig_market" if gid == "rig_market" else "rig_chest"
	return ""


static func base(item: Dictionary) -> Dictionary:
	return data().get("bases", {}).get(base_key(item), {})


static func spot(item: Dictionary, s: String) -> Dictionary:
	return base(item).get("spots", {}).get(s, {})


static func tears(item: Dictionary) -> Array:
	return item.get("tears", [])


static func is_torn(item: Dictionary) -> bool:
	return not tears(item).is_empty()


## After an op: a little wear on everything worn, and tears from the hits taken. Returns notes for the report.
static func after_op(state: RefCounted, p: Dictionary, hits: int, roll: Callable) -> Array:
	var D := data()
	var notes: Array = []
	var L = load("res://v2/sim/loadout.gd")
	var worn := {}
	for slot in ["clothes", "rig"]:
		var it: Dictionary = L.worn(state, p, slot)
		if not it.is_empty() and not base(it).is_empty():
			worn[slot] = it
			it["condition"] = maxi(0, int(it.get("condition", 100)) - int(D.get("op_wear", 3)))
	if worn.is_empty():
		return notes
	for h in hits:
		if float(roll.call()) > float(D.get("tear_per_hit", 0.7)):
			continue
		var slot := "clothes"
		if worn.has("rig") and (not worn.has("clothes") or float(roll.call()) < float(D.get("rig_share", 0.35))):
			slot = "rig"
		var it: Dictionary = worn.get(slot, worn.values()[0])
		var free: Array = []
		for s in base(it).get("spots", {}):
			if not tears(it).has(s):
				free.append(s)
		if free.is_empty():
			continue
		var s: String = free[int(float(roll.call()) * free.size()) % free.size()]
		var t: Array = tears(it)
		t.append(s)
		it["tears"] = t
		it["condition"] = maxi(0, int(it.get("condition", 100)) - int(D.get("hit_wear", 10)))
		if slot == "rig":
			L._trim_grid(state, p)          # a lost pouch column drops what was in it back on the shelves
		notes.append("%s's %s tore at the %s." % [str(p["name"]).split(" ")[0].capitalize(), str(it.get("name", "kit")).to_lower(), spot(it, s).get("name", s)])
	return notes


## Every torn clothes or rig item you own (worn or on the shelves).
static func torn_items(state: RefCounted) -> Array:
	var out: Array = []
	for it in state.items:
		if is_torn(it) and not base(it).is_empty():
			out.append(it)
	return out


static func scraps_needed(item: Dictionary) -> int:
	return tears(item).size()


static func can_mend(state: RefCounted, item: Dictionary) -> String:
	var mat := str(data().get("scrap_material", "shirt"))
	if int(state.materials.get(mat, 0)) < scraps_needed(item):
		return "Needs %d old shirt%s for scraps." % [scraps_needed(item), "" if scraps_needed(item) == 1 else "s"]
	return ""


## The sewing table job for mending this item (v2/world/sew_table.gd, mend mode).
static func job(item: Dictionary) -> Dictionary:
	var b := base(item)
	var targets: Array = []
	for s in tears(item):
		var sp := spot(item, s)
		targets.append({"spot": s, "name": sp.get("name", s), "at": sp.get("at", [0, 0, 0])})
	var old: Array = []
	for pa in item.get("patches", []):
		var sp2 := spot(item, str(pa["spot"]))
		old.append({"spot": pa["spot"], "colour": pa["colour"], "at": sp2.get("at", [0, 0, 0])})
	return {"name": "Mend: " + str(item.get("name", "")), "hours": float(data().get("hours_per_tear", 0.5)) * tears(item).size(),
		"table": {"base": b.get("model", "Jacket_Field"), "mend": true, "tears": targets, "patches": old,
			"palette": data().get("colours", {})}}


## Mending done: the scraps are used, the tears become patches (in the colours picked), condition comes back.
## patched = [{spot, colour}]; score = 0..1 (how neat the work was).
static func mend(state: RefCounted, item: Dictionary, patched: Array, score: float) -> void:
	var D := data()
	var M = load("res://v2/sim/materials.gd")
	M.take(state, str(D.get("scrap_material", "shirt")), patched.size())
	var t: Array = tears(item)
	var pl: Array = item.get("patches", [])
	for pa in patched:
		t.erase(str(pa["spot"]))
		pl.append({"spot": str(pa["spot"]), "colour": str(pa["colour"])})
	item["tears"] = t
	item["patches"] = pl
	item["condition"] = mini(100, int(item.get("condition", 100)) + int(round(float(D.get("mend_gain", 25)) * patched.size() * (0.5 + 0.5 * score))))


## For the fighter model: [{body, colour}] patches and [{body}] open tears on what they wear.
static func marks(state: RefCounted, p: Dictionary) -> Dictionary:
	var L = load("res://v2/sim/loadout.gd")
	var out := {"patches": [], "tears": []}
	for slot in ["clothes", "rig"]:
		var it: Dictionary = L.worn(state, p, slot)
		if it.is_empty():
			continue
		for pa in it.get("patches", []):
			out["patches"].append({"slot": slot, "body": spot(it, str(pa["spot"])).get("body", "chest"), "colour": pa["colour"], "spot": pa["spot"]})
		for s in tears(it):
			out["tears"].append({"slot": slot, "body": spot(it, s).get("body", "chest"), "spot": s})
	return out
