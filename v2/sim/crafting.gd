extends RefCounted
## Bench crafting rules (docs/DRIVE.md section 3). Pure functions over GameState + data/v2/recipes.json.
## quality = average step score x tool multiplier x material multiplier, then stars, perks, rig grid.

const Content := preload("res://v2/sim/content.gd")
const Materials := preload("res://v2/sim/materials.gd")
const GOOD_STARS := 3          # a craft this good counts toward mastery
const BATCH_AFTER := 3         # good crafts needed before batching


static func data() -> Dictionary:
	return Content.get_file("recipes")


static func recipe(id: String) -> Dictionary:
	for r in data().get("recipes", []):
		if r["id"] == id:
			return r
	return {}


static func recipes_for(bench: String) -> Array:
	var out: Array = []
	for r in data().get("recipes", []):
		if r["bench"] == bench:
			out.append(r)
	return out


static func material_name(id: String) -> String:
	return data().get("materials", {}).get(id, {}).get("name", id)


static func tool_def(id: String) -> Dictionary:
	return data().get("tools", {}).get(id, {"name": id, "mult": 1.0})


## Unlocked = no "after", or the earlier recipe has been made well at least once.
static func unlocked(state, r: Dictionary) -> bool:
	var after: String = r.get("after", "")
	return after == "" or int(mastery(state, after).get("good", 0)) >= 1 or state.unlocked_recipes.has(r["id"])


static func mastery(state, id: String) -> Dictionary:
	return state.mastery.get(id, {"made": 0, "good": 0, "sum": 0.0})


## What's missing to make it: too few units, or none good enough (recipe "min_grade": {material: stars}).
static func missing(state, r: Dictionary) -> Array:
	var out: Array = []
	var needs: Dictionary = r.get("needs", {})
	var mins: Dictionary = r.get("min_grade", {})
	for m in needs:
		var need := int(needs[m])
		var g := int(mins.get(m, 1))
		var have := Materials.at_least(state, m, g)
		if have < need:
			if g > 1:
				out.append("%s %d/%d (needs %s+)" % [material_name(m), have, need, Materials.stars(g)])
			else:
				out.append("%s %d/%d" % [material_name(m), have, need])
	return out


static func can_batch(state, r: Dictionary) -> bool:
	return int(mastery(state, r["id"]).get("good", 0)) >= BATCH_AFTER


## Use up the materials, best grades first. Returns the average grade used (it sets the material multiplier).
static func consume(state, r: Dictionary) -> float:
	var needs: Dictionary = r.get("needs", {})
	var sum := 0.0
	var n := 0
	for m in needs:
		var g := Materials.take(state, m, int(needs[m]))
		sum += g * int(needs[m])
		n += int(needs[m])
	return sum / n if n > 0 else 3.0


## The best grade you could make it from right now (for the recipe list).
static func best_grade(state, r: Dictionary) -> float:
	var needs: Dictionary = r.get("needs", {})
	var sum := 0.0
	var n := 0
	for m in needs:
		sum += Materials.best(state, m) * int(needs[m])
		n += int(needs[m])
	return sum / n if n > 0 else 3.0


static func tool_mult(state, r: Dictionary) -> float:
	var t: String = r.get("tool", "hands")
	return float(tool_def(t).get("mult", 1.0)) if state.tools.has(t) else 0.7


## The formula, for the result screen: {steps, tool, material, quality}.
static func formula(state, r: Dictionary, step_scores: Array, grade := -1.0) -> Dictionary:
	var avg := 0.0
	for s in step_scores:
		avg += float(s)
	avg = avg / maxf(1.0, step_scores.size())
	var tm := tool_mult(state, r)
	var mm := float(r.get("material_mult", 1.0)) if grade < 0.0 else Materials.grade_mult(grade)
	return {"steps": avg, "tool": tm, "material": mm, "quality": clampf(avg * tm * mm, 0.0, 1.0)}


static func stars_for(q: float) -> int:
	if q >= 0.92: return 5
	if q >= 0.78: return 4
	if q >= 0.6: return 3
	if q >= 0.4: return 2
	return 1


## Turns a quality into an item, records mastery and puts it in the stash. Returns the item.
static func finish(state, r: Dictionary, quality: float, by_hand: bool, grade := -1.0) -> Dictionary:
	var makes: Dictionary = r.get("makes", {})
	var item := {
		"id": state.next_item_id, "recipe": r["id"], "name": r["name"], "type": makes.get("type", "item"),
		"quality": snappedf(quality, 0.01), "stars": stars_for(quality), "hand": by_hand, "perks": [],
		"day": state.day, "mat_grade": int(round(grade)) if grade > 0.0 else 0,
	}
	state.next_item_id += 1
	for k in makes:
		if k != "type":
			item[k] = makes[k]
	for p in r.get("perks", []):
		if quality >= float(p["min"]):
			item["perks"].append(p["text"])
	if makes.has("grid"):
		var g: Array = (makes["grid"] as Array).duplicate()
		# the material grade sets the base grid: cheap cloth, fewer cells (docs/ECONOMY.md section 2)
		var gbg: Dictionary = r.get("grid_by_grade", {})
		if grade > 0.0 and not gbg.is_empty():
			var key := str(clampi(int(round(grade)), 1, 5))
			if gbg.has(key):
				g = (gbg[key] as Array).duplicate()
		for b in r.get("grid_bonus", []):
			if quality >= float(b["min"]):
				g[0] = int(g[0]) + int(b["add"][0])
				g[1] = int(g[1]) + int(b["add"][1])
		item["grid"] = g
	if by_hand:
		var m := mastery(state, r["id"]).duplicate()
		m["made"] = int(m["made"]) + 1
		m["sum"] = float(m["sum"]) + quality
		if item["stars"] >= GOOD_STARS:
			m["good"] = int(m["good"]) + 1
		state.mastery[r["id"]] = m
	state.items.append(item)
	return item


## Batch: no minigame, your average hand-made quality, never more than 4 stars.
static func batch(state, r: Dictionary, grade := -1.0) -> Dictionary:
	var m := mastery(state, r["id"])
	var q := minf(float(m["sum"]) / maxf(1.0, float(m["made"])), 0.91)
	return finish(state, r, q, false, grade)
