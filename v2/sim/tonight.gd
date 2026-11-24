extends RefCounted
## What's next, in plain words (docs/CONNECTED_LOOP.md section 2; user 2026-11-24: "never feel lost").
## No nodes. Reads the systems that exist and writes:
##   board(state)          the TONIGHT board: a few cards {title, line, go, ok} (go = the station to turn to)
##   signs(state, station) the status sign beside a station: rows {text, tag, ok}
## ok = true: something you can do now (amber READY); false: something blocking (dim, says what's missing).

const Crafting := preload("res://v2/sim/crafting.gd")
const Materials := preload("res://v2/sim/materials.gd")
const Wear := preload("res://v2/sim/wear.gd")
const Loadout := preload("res://v2/sim/loadout.gd")
const DepotRun := preload("res://v2/sim/depot_run.gd")
const Content := preload("res://v2/sim/content.gd")

const BENCHES := {"bench_sew": "armor", "bench_med": "meds", "bench_gun": "weapons", "bench_hack": "electronics"}


static func _first(p: Dictionary) -> String:
	return str(p.get("name", "")).split(" ")[0].capitalize()


static func _short(name: String) -> String:
	return name.replace(" (gadget)", "").replace(" (blueprint)", "").replace(" (part)", "")


## "NEEDS 1 STRAP": the first thing short for a recipe, in plain words.
static func _need(state, r: Dictionary) -> String:
	var needs: Dictionary = r.get("needs", {})
	var mins: Dictionary = r.get("min_grade", {})
	for m in needs:
		var have := Materials.at_least(state, m, int(mins.get(m, 1)))
		var short := int(needs[m]) - have
		if short > 0:
			var nm := Crafting.material_name(m).to_lower().split(" ")
			var word := nm[nm.size() - 1]
			if short > 1 and not word.ends_with("s"):
				word += "s"
			return "NEEDS %d %s" % [short, word.to_upper()]
	return ""


## Rows for a bench: what you can make now, then what's short; mending on the sewing table.
static func _bench_rows(state, bench: String) -> Array:
	var rows: Array = []
	for r in Crafting.recipes_for(bench):
		if not Crafting.unlocked(state, r):
			continue
		var need := _need(state, r)
		rows.append({"text": _short(str(r["name"])).to_upper(), "name": _short(str(r["name"])), "tag": "READY" if need == "" else need, "ok": need == ""})
	if bench == "armor":
		for it in Wear.torn_items(state):
			var why := Wear.can_mend(state, it)
			var n := Wear.scraps_needed(it)
			rows.append({"text": "REPAIR " + str(it.get("name", "")).to_upper(), "name": "Repair: " + str(it.get("name", "")).to_lower(), "tag": "READY" if why == "" else "NEEDS %d SHIRT%s" % [n, "" if n == 1 else "S"], "ok": why == ""})
	return rows


static func _crew(state) -> Dictionary:
	var fit: Array = []
	var resting: Array = []
	var carrier := Loadout.stick_carrier(state)
	var has_med := false
	for p in state.people:
		if not p.get("alive", true):
			continue
		if Loadout.fit_for_duty(p):
			fit.append(p)
			for e in p.get("grid", []):
				if Loadout.gdef(str(e["gear"])).has("med"):
					has_med = true
		elif int(p.get("injury_days", 0)) > 0:
			resting.append(p)
	return {"fit": fit, "resting": resting, "carrier": carrier, "has_med": has_med}


static func signs(state, station: String) -> Array:
	if BENCHES.has(station):
		return _bench_rows(state, BENCHES[station])
	var rows: Array = []
	match station:
		"cage":
			var c := _crew(state)
			rows.append({"text": "FIT FOR DUTY", "tag": "%d" % (c["fit"] as Array).size(), "ok": not (c["fit"] as Array).is_empty()})
			for p in c["resting"]:
				rows.append({"text": _first(p).to_upper() + " RESTING", "tag": "%d NIGHT%s" % [int(p["injury_days"]), "" if int(p["injury_days"]) == 1 else "S"], "ok": false})
			if (c["carrier"] as Dictionary).is_empty():
				rows.append({"text": "DROP STICK", "tag": "NOBODY CARRIES ONE", "ok": false})
			else:
				rows.append({"text": "DROP STICK", "tag": _first(c["carrier"]).to_upper(), "ok": true})
			if not c["has_med"]:
				rows.append({"text": "DRESSINGS", "tag": "NOBODY HAS ONE", "ok": false})
		"roller_door":
			var lock := DepotRun.locked_for(state)
			rows.append({"text": "DEPOT RAID", "tag": "OPEN" if lock == 0 else "LOCKED %d NIGHT%s" % [lock, "" if lock == 1 else "S"], "ok": lock == 0})
			rows.append({"text": "PLAN FILE", "tag": "FOUND" if not DepotRun.plan_files(state).is_empty() else "NONE YET", "ok": not DepotRun.plan_files(state).is_empty()})
			for a in arrivals(state):
				rows.append({"text": str(a).to_upper(), "tag": "TOMORROW", "ok": true})
		"prisoner":
			if state.flags.has("prisoner"):
				rows.append({"text": "SOMEONE IN THE CHAIR", "tag": "TALK", "ok": true})
	return rows


## Things ordered that arrive next morning (markets).
static func arrivals(state) -> Array:
	var out: Array = []
	var s: Dictionary = state.os.get("shop", {})
	for od in s.get("orders", []):
		out.append(str(od["offer"].get("name", "an order")))
	return out


## The TONIGHT board: the few things worth knowing when the evening starts.
static func board(state) -> Array:
	var cards: Array = []
	# BENCH: the best thing you can make or mend right now, else the nearest miss
	var ready: Array = []
	var short: Array = []
	for st in BENCHES:
		for row in _bench_rows(state, BENCHES[st]):
			(ready if row["ok"] else short).append([row, st])
	if not ready.is_empty():
		var more := "" if ready.size() == 1 else " (+%d)" % (ready.size() - 1)
		cards.append({"title": "BENCH", "line": str(ready[0][0]["name"]) + " ready" + more, "go": ready[0][1], "ok": true})
	elif not short.is_empty():
		cards.append({"title": "BENCH", "line": "%s: %s" % [str(short[0][0]["name"]), str(short[0][0]["tag"]).to_lower()], "go": short[0][1], "ok": false})
	# CREW
	var c := _crew(state)
	if not (c["resting"] as Array).is_empty():
		var p: Dictionary = c["resting"][0]
		cards.append({"title": "CREW", "line": "%s resting (%d night%s)" % [_first(p), int(p["injury_days"]), "" if int(p["injury_days"]) == 1 else "s"], "go": "cage", "ok": false})
	elif not c["has_med"]:
		cards.append({"title": "CREW", "line": "Nobody carries a dressing", "go": "cage", "ok": false})
	else:
		cards.append({"title": "CREW", "line": "%d fit for duty" % (c["fit"] as Array).size(), "go": "cage", "ok": true})
	# DEPOT
	var lock := DepotRun.locked_for(state)
	if lock > 0:
		cards.append({"title": "DEPOT", "line": "Locked down, %d night%s" % [lock, "" if lock == 1 else "s"], "go": "roller_door", "ok": false})
	elif not DepotRun.plan_files(state).is_empty():
		cards.append({"title": "DEPOT", "line": "Plan file found", "go": "roller_door", "ok": true})
	else:
		cards.append({"title": "DEPOT", "line": "No plan file: hack it on the PC", "go": "pc", "ok": true})
	# ARRIVING, PRISONER
	var arr := arrivals(state)
	if not arr.is_empty():
		cards.append({"title": "ARRIVING", "line": "%s tomorrow" % arr[0] + ("" if arr.size() == 1 else " (+%d)" % (arr.size() - 1)), "go": "roller_door", "ok": true})
	if state.flags.has("prisoner"):
		cards.append({"title": "THE CHAIR", "line": "%s is waiting" % str(state.flags["prisoner"].get("first", "Someone")), "go": "prisoner", "ok": true})
	return cards
