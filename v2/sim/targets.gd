extends RefCounted
## M4 V4: targets and rewards (docs/M4_VARIETY.md section 8; numbers and text in data/v2/targets.json). No nodes.
##
## The pattern: XCOM's mission list + Darkest Dungeon's "scout before you go" + Tarkov's traders.
##   - A target is a place: a building type, a tier, a seed. Its insides are generated (v2/sim/building_gen.gd)
##     from the seed plus how many times it's been hit, so the same place comes back different inside.
##   - Fixed targets are always there (police HQ, the refinery, the radio mast) and hard; you can watch them.
##     Pop-ups come from hacks, the chair, Nod tips, group jobs and street word; only events are one-time,
##     the rest fade quietly after some days (no countdown shown).
##   - Knowing comes in layers (address, layout, guards and hours, the inside) and never gives everything:
##     some guards always stay unseen.
##   - Harder by type, tier and heat; as you get stronger only the enemy's numbers and gear rise.
##   - Loot by type sits in crates inside; your people grab them (it takes seconds) and carry what fits.
##   - After a hit: shut for some nights, back with more guards, gone for good if you burn it. Krall closes in.
##     Hurting people who aren't fighters costs the street's mood.
##   - Five groups buy what you bring, give jobs, open their goods with trust, do favours, and resent rivals.
## State: state.targets = {list, next, groups, mood, wins, nod_last, held}.

const Content := preload("res://v2/sim/content.gd")
const BuildingGen := preload("res://v2/sim/building_gen.gd")
const DepotRun := preload("res://v2/sim/depot_run.gd")
const Loadout := preload("res://v2/sim/loadout.gd")
const Crafting := preload("res://v2/sim/crafting.gd")
const IntelMarket := preload("res://v2/sim/intel_market.gd")
const Town := preload("res://v2/sim/town.gd")

const WEAPON_SCORE := {"": 0.4, "pipe": 0.4, "pistol": 1.0, "pump_shotgun": 1.4, "bolt_rifle": 1.2, "smg": 1.8, "carbine": 2.2, "bench_rifle": 2.2}
const ROSTER_TYPE := {"office": "office", "shop": "gun_shop", "clinic": "clinic", "police": "police"}


static func data() -> Dictionary:
	return Content.get_file("targets")


static func kind(type: String) -> Dictionary:
	return data().get("kinds", {}).get(type, {})


## The targets state, made on first use (the fixed targets and a couple of pop-ups to start with).
static func ts(state: RefCounted) -> Dictionary:
	var t: Dictionary = state.targets
	if t.has("list"):
		return t
	t["list"] = []
	t["next"] = 1
	t["groups"] = {}
	t["mood"] = {}
	t["wins"] = 0
	t["nod_last"] = 0
	t["held"] = []
	state.targets = t
	for f in data().get("fixed", []):
		var nt := _new(state, str(f["type"]), "fixed", {"id": f["id"], "tier": int(f.get("tier", 1)), "know": int(f.get("know", 1)),
			"name": f.get("name", ""), "line": f.get("line", ""), "level": f.get("level", ""), "event": f.get("event", false)})
		nt["fixed"] = true
	var rng := _rng(state, "start")
	for i in int(data().get("popups", {}).get("start", 2)):
		_popup(state, rng, "word")
	_group(state, "fixer")["met"] = true
	return t


static func _rng(state: RefCounted, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [int(state.world_seed), salt, int(state.day)])
	return rng


## Every target you can still hit or watch (not gone), fixed ones first.
static func list(state: RefCounted) -> Array:
	var out: Array = []
	Town.ensure_keys(state)          # M4 V5: every district has its key target, every target a building
	for t in ts(state)["list"]:
		if not t.has("bldg"):
			Town.place_target(state, t)
		if str(t.get("status", "open")) != "gone":
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.get("fixed", false) != b.get("fixed", false):
			return a.get("fixed", false)
		return int(a["n"]) > int(b["n"]))
	return out


static func find(state: RefCounted, id: String) -> Dictionary:
	for t in ts(state)["list"]:
		if t["id"] == id:
			return t
	return {}


# ------------------------------------------------------------------ making targets

static func _new(state: RefCounted, type: String, source: String, opts := {}) -> Dictionary:
	var T: Dictionary = ts(state)
	var n := int(T["next"])
	T["next"] = n + 1
	var K := kind(type)
	var tr: Array = K.get("tier", [1, 1])
	var rng := _rng(state, "new%d" % n)
	var t := {"id": str(opts.get("id", "t%d" % n)), "n": n, "type": type, "source": source, "status": "open",
		"tier": int(opts.get("tier", rng.randi_range(int(tr[0]), int(tr[1])))), "know": int(opts.get("know", 0)),
		"seed": abs(hash("%d:target:%d" % [int(state.world_seed), n])) % 100000, "hits": 0, "reinforce": 0,
		"day": int(state.day), "event": bool(opts.get("event", false)), "watched": []}
	for k in ["level", "line", "group", "job", "hack_id", "pay"]:
		if opts.has(k) and str(opts[k]) != "":
			t[k] = opts[k]
	if source != "fixed" and source != "job":
		var fd: Array = data().get("popups", {}).get("fade_days", [6, 9])
		t["fade"] = int(state.day) + rng.randi_range(int(fd[0]), int(fd[1]))
	# its name and street come from the generated building (or the hand-made level)
	var lv := _base_level(t)
	var nm := str(opts.get("name", ""))
	var full := str(lv.get("name", type.to_upper()))
	var parts := full.split(", ")
	t["name"] = nm if nm != "" else parts[0]
	t["street"] = parts[1] if parts.size() > 1 else ""
	if not t.has("line"):
		t["line"] = _line_for(t)
	T["list"].append(t)
	return t


static func _line_for(t: Dictionary) -> String:
	var B: Dictionary = BuildingGen.data().get("types", {}).get(t["type"], {})
	return "%s on %s. %s" % [str(B.get("name", t["type"])), str(t.get("street", "")), str(B.get("objective", {}).get("text", "")) + "."]


static func _popup(state: RefCounted, rng: RandomNumberGenerator, source: String, know := 0) -> Dictionary:
	var types: Dictionary = data().get("popups", {}).get("types", {"bar": 1})
	var tot := 0.0
	for k in types:
		tot += float(types[k])
	var roll := rng.randf() * tot
	var pick := "bar"
	for k in types:
		roll -= float(types[k])
		if roll <= 0.0:
			pick = k
			break
	return _new(state, pick, source, {"know": know})


## Nights a target is shut for, or 0.
static func shut_for(state: RefCounted, t: Dictionary) -> int:
	if str(t.get("status", "")) != "shut":
		return 0
	return maxi(0, int(t.get("shut_until", 0)) - int(state.day))


static func can_hit(state: RefCounted, t: Dictionary) -> bool:
	return str(t.get("status", "open")) == "open"


# ------------------------------------------------------------------ the level

static func _insides_seed(t: Dictionary) -> int:
	return int(t["seed"]) * 31 + int(t.get("hits", 0)) * 7919


static func _base_level(t: Dictionary) -> Dictionary:
	if str(t.get("level", "")) != "":
		return Content.get_file(str(t["level"])).duplicate(true)
	return BuildingGen.generate(str(t["type"]), _insides_seed(t))


## The building as it is tonight: the generated insides, plus the extra guards (tier, past hits, heat, your
## strength), better guns, and the loot crates.
static func level_for(state: RefCounted, t: Dictionary) -> Dictionary:
	var lv := _base_level(t)
	lv["target"] = t["id"]
	var rng := RandomNumberGenerator.new()
	rng.seed = _insides_seed(t) + 11
	_harden(state, t, lv, rng)
	_crates(state, t, lv, rng)
	return lv


static func extra_guards(state: RefCounted, t: Dictionary) -> int:
	var S: Dictionary = data().get("scale", {})
	var n := (int(t.get("tier", 1)) - 1) * int(S.get("guards_per_tier", 1)) + int(t.get("reinforce", 0)) * int(S.get("guards_per_hit", 1))
	n += int(float(state.attention) / float(S.get("heat_per_guard", 34)))
	n += int(ts(state).get("wins", 0)) / maxi(1, int(S.get("wins_per_guard", 2)))
	return mini(n, int(S.get("max_extra", 5)))


static func _harden(state: RefCounted, t: Dictionary, lv: Dictionary, rng: RandomNumberGenerator) -> void:
	if str(t.get("level", "")) != "":
		return            # hand-made levels (Kessel Road) stay as written
	var S: Dictionary = data().get("scale", {})
	var T: Dictionary = BuildingGen.data().get("types", {}).get(t["type"], {})
	var enemies: Array = lv.get("enemies", [])
	var posts: Array = lv.get("posts", [])
	var wins := int(ts(state).get("wins", 0))
	var tier := int(t.get("tier", 1))
	# more of them: the free posts first, then doubled up
	var extra := extra_guards(state, t)
	if posts.is_empty():
		extra = 0          # nobody guards this place (a library): it stays a quiet job
	for k in extra:
		var i := enemies.size()
		var post: Dictionary = (posts[i] if i < posts.size() else posts[i % posts.size()]).duplicate(true)
		if i >= posts.size():
			post["pos"] = [float(post["pos"][0]) + rng.randf_range(-0.8, 0.8), float(post["pos"][1]) + rng.randf_range(-0.8, 0.8)]
			post["state"] = "idle"
			post.erase("patrol")
		var e := BuildingGen.make_guard(rng, T, post, i, _insides_seed(t), BuildingGen._weighted(rng, T.get("weapons", {"pistol": 1})))
		if e["gear"]["weapon"] == "pump_shotgun":
			e["gear"]["weapon"] = "pistol"
		e["extra"] = true
		enemies.append(e)
	# better kit as the place hardens and as you get stronger (never better aim)
	var up := float(S.get("upgun_per_tier", 0.12)) * (tier - 1) + float(S.get("upgun_per_win", 0.04)) * wins
	var pl := float(S.get("plate_per_tier", 0.1)) * (tier - 1) + float(S.get("plate_per_win", 0.03)) * wins
	for e in enemies:
		var g: Dictionary = e["gear"]
		if rng.randf() < up:
			g["weapon"] = {"pistol": "smg", "smg": "carbine", "bolt_rifle": "carbine"}.get(g["weapon"], g["weapon"])
		if rng.randf() < pl:
			g["plate"] = mini(2, int(g.get("plate", 0)) + 1)
	lv["enemies"] = enemies


## The loot crates: by building type, one maybe rare, the best one in a "good room" (that's what knowing
## THE INSIDE shows you).
static func _crates(state: RefCounted, t: Dictionary, lv: Dictionary, rng: RandomNumberGenerator) -> void:
	var K := kind(t["type"])
	var cr: Array = K.get("crates", [0, 0])
	var n := rng.randi_range(int(cr[0]), int(cr[1]))
	var spots: Dictionary = lv.get("spots", {})
	lv["loot"] = []
	if n <= 0 or spots.is_empty():
		return
	var obj_room := str(lv.get("objective", {}).get("room", ""))
	var good_kinds: Array = K.get("good_rooms", [])
	var good := ""
	var rooms: Array = []
	for r in lv["rooms"]:
		if r.get("outdoor", false) or not spots.has(r["id"]) or str(r.get("kind", "")) in ["wc", "corridor"]:
			continue
		rooms.append(r["id"])
		if good == "" and good_kinds.has(r.get("kind", "")):
			good = r["id"]
	if rooms.is_empty():
		return
	if good == "":
		good = obj_room if spots.has(obj_room) else rooms[0]
	var R: Dictionary = data().get("rare", {})
	var rare := rng.randf() < float(R.get("chance", 0.12)) + float(R.get("per_tier", 0.08)) * (int(t.get("tier", 1)) - 1)
	var used := {}
	for i in n:
		var room: String = good
		if i > 0:
			var free: Array = rooms.filter(func(id: String) -> bool: return not used.has(id))
			room = free[rng.randi() % free.size()] if not free.is_empty() else rooms[rng.randi() % rooms.size()]
		var k := int(used.get(room, 0))
		used[room] = k + 1
		var sp: Array = spots[room]
		var spec: Dictionary = _pick_loot(rng, (R.get("loot", []) if (i == 0 and rare) else K.get("loot", [])) as Array)
		var item := _resolve(state, spec, rng)
		if item.is_empty():
			continue
		lv["loot"].append({"id": "c%d" % i, "room": room, "pos": [float(sp[0]) + k * 0.7, float(sp[1])],
			"label": str(spec.get("label", "a crate")), "items": [item], "cells": _cells(item), "good": i == 0, "rare": i == 0 and rare})


static func _pick_loot(rng: RandomNumberGenerator, table: Array) -> Dictionary:
	var tot := 0.0
	for e in table:
		tot += float(e.get("w", 1))
	var roll := rng.randf() * tot
	for e in table:
		roll -= float(e.get("w", 1))
		if roll <= 0.0:
			return e
	return table[-1] if not table.is_empty() else {}


## A loot line made concrete: counts, grades, which blueprint or upgrade.
static func _resolve(state: RefCounted, spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ty := str(spec.get("type", ""))
	var nr: Array = spec.get("n", [1, 1])
	var cnt := rng.randi_range(int(nr[0]), int(nr[1]))
	match ty:
		"money":
			return {"type": "money", "count": cnt}
		"material":
			var gr: Array = spec.get("grade", [2, 3])
			return {"type": "material", "id": spec["id"], "count": cnt, "grade": rng.randi_range(int(gr[0]), int(gr[1]))}
		"supply":
			return {"type": "supply", "id": spec["id"], "count": cnt}
		"gear":
			return {"type": "gear", "id": spec["id"], "count": 1}
		"intel":
			return {"type": "intel", "tag": spec.get("tag", "files"), "name": str(spec.get("name", "file_%d")) % rng.randi_range(1, 9),
				"worth": spec.get("worth", ""), "scouts": spec.get("scouts", false)}
		"blueprint":
			var id := str(spec.get("id", "any"))
			if id == "any" or state.unlocked_recipes.has(id):
				var locked: Array = []
				for r in Content.get_file("recipes").get("recipes", []):
					if (r.get("locked", false) or r.get("blueprint", false)) and not state.unlocked_recipes.has(r["id"]):
						locked.append(r["id"])
				if locked.is_empty():
					return {"type": "material", "id": "board", "count": 2, "grade": 4}
				id = locked[rng.randi() % locked.size()]
			return {"type": "blueprint", "id": id}
		"upgrade":
			var bench := str(spec.get("bench", "any"))
			var ups: Array = []
			var have: Array = Crafting.installed(state)
			var U: Dictionary = Crafting.upgrades_def()
			for uid in U:
				if not have.has(uid) and (bench == "any" or str(U[uid].get("bench", "")) == bench):
					ups.append(uid)
			if ups.is_empty():
				return {"type": "material", "id": "pins", "count": 3, "grade": 4}
			return {"type": "upgrade", "id": ups[rng.randi() % ups.size()]}
	return {}


static func _cells(item: Dictionary) -> int:
	match str(item.get("type", "")):
		"material":
			return maxi(1, int(ceil(int(item["count"]) / 2.0)))
		"gear":
			var c := Loadout.cells(str(item["id"]))
			return maxi(2, c.x * c.y) if Loadout.gdef(str(item["id"])).get("slot", "") in ["primary", "plate", "back"] else maxi(1, c.x * c.y)
		"upgrade":
			return 2
	return 1


## Bring a grabbed crate's contents home. Returns the line for the report.
static func grant(state: RefCounted, item: Dictionary, from: String) -> String:
	match str(item.get("type", "")):
		"money":
			state.money += int(item["count"])
			return "%d cr" % int(item["count"])
		"intel":
			state.items.append({"id": state.next_item_id, "name": item["name"], "type": "intel", "tag": item["tag"], "worth": item.get("worth", ""),
				"source": from, "day": state.day, "stars": 0, "quality": 0.0, "hand": true, "perks": []})
			state.next_item_id += 1
			var s := "%s [%s]" % [item["name"], str(item["tag"]).to_upper()]
			if item.get("scouts", false):
				var other := _scout_random(state, 2, from)
				if other != "":
					s += " (it tells you about %s)" % other
			return s
	return DepotRun.grant(state, item)


## Raise what you know about some other open target (a duty roster, building plans). Returns its name.
static func _scout_random(state: RefCounted, to: int, not_name: String) -> String:
	var pool: Array = list(state).filter(func(t: Dictionary) -> bool: return int(t["know"]) < to and str(t["name"]) != not_name and str(t.get("level", "")) == "")
	if pool.is_empty():
		return ""
	var t: Dictionary = pool[_rng(state, "scout%d" % pool.size()).randi() % pool.size()]
	t["know"] = to
	return str(t["name"])


# ------------------------------------------------------------------ knowing and the ready read

static func know_name(t: Dictionary) -> String:
	var names: Array = data().get("knowing", {}).get("names", [])
	return str(names[clampi(int(t["know"]), 0, names.size() - 1)])


static func know_line(t: Dictionary) -> String:
	var lines: Array = data().get("knowing", {}).get("lines", [])
	return str(lines[clampi(int(t["know"]), 0, lines.size() - 1)])


## The guards you know about at an hour (some always stay unseen). Each: {pos, weapon, name}.
static func known_guards(t: Dictionary, lv: Dictionary, hour: String) -> Array:
	if int(t["know"]) < 2:
		return []
	var here: Array = []
	for e in lv.get("enemies", []):
		if e.has("hours") and not (e["hours"] as Array).has(hour):
			continue
		if e.get("vip", false):
			continue
		here.append(e)
	var n := here.size()
	var hide := int(round(n * float(data().get("knowing", {}).get("hidden_frac", 0.25))))
	if n >= 2:
		hide = maxi(1, hide)
	var rng := RandomNumberGenerator.new()
	rng.seed = _insides_seed(t) + hour.hash()
	for i in hide:
		here.remove_at(rng.randi() % here.size())
	return here


static func guards_at(lv: Dictionary, hour: String) -> int:
	return (lv.get("enemies", []) as Array).filter(func(e: Dictionary) -> bool: return not e.has("hours") or (e["hours"] as Array).has(hour)).size()


static func team_size(t: Dictionary) -> int:
	return 1 if kind(t["type"]).get("solo", false) else 4


## Who would go: the fittest up to the team size.
static func team(state: RefCounted, t: Dictionary) -> Array:
	var out: Array = []
	for p in state.people:
		if Loadout.fit_for_duty(p) and out.size() < team_size(t):
			out.append(p["id"])
	return out


static func _power(weapon: String, plate: int, acc := 1.0) -> float:
	return float(WEAPON_SCORE.get(weapon, 1.0)) * acc * (1.0 + 0.25 * plate)


## "Ready?" from what you know: {word: READY / RISKY / NOT READY / UNKNOWN, lines: []}.
static func ready_read(state: RefCounted, t: Dictionary, lv: Dictionary, hour: String) -> Dictionary:
	var ids := team(state, t)
	var ours := 0.0
	var kit := {}
	for pid in ids:
		var f := Loadout.to_fighter(state, Loadout.person(state, pid))
		var w := str(f.get("gear", {}).get("weapon", "")) if f.get("armed", true) else ""
		ours += _power(w, int(f.get("gear", {}).get("plate", 0)))
		kit[w] = int(kit.get(w, 0)) + 1
	var us := "You: %d going (%s)." % [ids.size(), _kit_words(kit)]
	if ids.is_empty():
		return {"word": "NOBODY", "lines": ["Nobody is fit to go."]}
	if int(t["know"]) < 2:
		return {"word": "UNKNOWN", "lines": [us, "Them: you don't know. Watch the place or hack it first."]}
	var seen := known_guards(t, lv, hour)
	var theirs := 0.0
	var tk := {}
	for e in seen:
		var g: Dictionary = e["gear"]
		theirs += _power(str(g["weapon"]), int(g.get("plate", 0)), float(e.get("acc_mult", 0.6)))      # each worse than us, but many
		tk[str(g["weapon"])] = int(tk.get(str(g["weapon"]), 0)) + 1
	theirs = theirs * 1.35 + 0.5         # the ones you haven't seen (never everything)
	var r := ours / maxf(0.5, theirs)
	var word := "READY" if r >= 1.5 else ("RISKY" if r >= 0.9 else "NOT READY")
	if seen.is_empty():
		word = "READY"
	return {"word": word, "lines": [us, "Them: %d seen (%s), maybe more." % [seen.size(), _kit_words(tk)] if not seen.is_empty() else "Them: nobody seen."]}


static func _kit_words(k: Dictionary) -> String:
	var words := {"": "no gun", "pipe": "pipe", "pistol": "pistol", "pump_shotgun": "shotgun", "bolt_rifle": "bolt action", "smg": "SMG", "carbine": "carbine", "bench_rifle": "bench rifle"}
	var out: Array = []
	for w in k:
		out.append("%d %s" % [int(k[w]), words.get(w, w)])
	return ", ".join(PackedStringArray(out))


## WATCH: an evening across the street (a night action). Layout, then guards and hours.
static func watch(state: RefCounted, t: Dictionary) -> String:
	if int(state.actions) <= 0:
		return "No time left tonight."
	state.actions = int(state.actions) - 1
	state.minute = mini(state.end_minute, state.minute + 90)
	var lv := level_for(state, t)
	var day_n := guards_at(lv, "day")
	var night_n := guards_at(lv, "night")
	var before := int(t["know"])
	t["know"] = mini(2, before + 1)
	var line := ""
	if int(t["know"]) >= 2:
		line = "You counted about %d on the busy shift, %d at night." % [maxi(0, day_n - 1), maxi(0, night_n - 1)]
	else:
		line = "You worked out the rooms and the ways in."
	(t["watched"] as Array).append({"day": int(state.day), "line": line})
	return (data().get("watch", {}).get("line", "You watch %s.") % t["name"]) + " " + line


# ------------------------------------------------------------------ after a hit

## The fight's result at this target: {outcome, burned, civ_hurt, solo}. Returns lines for the report.
static func after_hit(state: RefCounted, t: Dictionary, res: Dictionary) -> Array:
	var T := ts(state)
	var K := kind(t["type"])
	var lines: Array = []
	var outcome := str(res.get("outcome", ""))
	var Krall = load("res://v2/sim/krall.gd")
	t["hits"] = int(t.get("hits", 0)) + 1
	var heat := float(K.get("heat", 1.0))
	if outcome == "success":
		T["wins"] = int(T.get("wins", 0)) + 1
		var sh: Array = K.get("shut", [2, 3])
		var rng := _rng(state, "shut" + str(t["id"]))
		t["status"] = "shut"
		t["shut_until"] = int(state.day) + 1 + rng.randi_range(int(sh[0]), int(sh[1]))
		t["reinforce"] = mini(int(data().get("scale", {}).get("max_reinforce", 3)), int(t.get("reinforce", 0)) + 1)
		t["know"] = 1 if t.get("fixed", false) else 0         # the insides change; you'll have to look again
		if t.has("fade"):
			t["fade"] = int(t["shut_until"]) + 6
		if t.has("job"):
			lines.append_array(_job_done(state, t))
	else:
		t["reinforce"] = mini(int(data().get("scale", {}).get("max_reinforce", 3)), int(t.get("reinforce", 0)) + 1)
		heat *= 0.6
	if res.get("burned", false) and K.get("destroy", false):
		t["status"] = "gone"
		heat += float(data().get("burn", {}).get("heat", 1.5))
		lines.append("%s burned behind you. It won't open again." % t["name"])
		_mood(state, t, int(data().get("burn", {}).get("mood", -2)))
	if t.get("event", false):
		t["status"] = "gone"
	lines.append_array(Town.on_hit(state, t, outcome))         # M4 V5: a key opens its district
	if heat > 0.0 and outcome != "":
		Krall.bump(state, heat, "the hit on %s" % t["name"])
	var hurt := int(res.get("civ_hurt", 0))
	var M: Dictionary = data().get("mood", {})
	if hurt > 0:
		_mood(state, t, int(M.get("civ_hurt", -6)) * hurt)
		lines.append("%d people who weren't fighting got hurt. %s won't forget it." % [hurt, str(t["street"]) if str(t.get("street", "")) != "" else "The street"])
	elif outcome == "success":
		_mood(state, t, int(M.get("clean_win", 2)))
	return lines


static func _mood(state: RefCounted, t: Dictionary, d: int) -> void:
	var m: Dictionary = ts(state)["mood"]
	var k := str(t.get("district", t.get("street", "town")))          # district mood (V5 map)
	m[k] = clampi(int(m.get(k, 0)) + d, -100, 100)


static func mood(state: RefCounted, street: String) -> int:
	return int(ts(state)["mood"].get(street, 0))


# ------------------------------------------------------------------ the night

## Overnight: shut places reopen, pop-ups fade, Nod tips and Nod-posted hits, groups turn up, the lent man
## goes home. Returns ledger lines.
static func night(state: RefCounted) -> Array:
	var T := ts(state)
	var lines: Array = []
	var tomorrow := int(state.day) + 1
	var rng := _rng(state, "night")
	for t in T["list"]:
		var st := str(t.get("status", "open"))
		if st == "shut" and int(t.get("shut_until", 0)) <= tomorrow:
			t["status"] = "open"
			lines.append("%s is open again. More of them on the door now." % t["name"])
		elif st == "open" and t.has("fade") and int(t["fade"]) <= tomorrow:
			t["status"] = "gone"
		if t.has("nod_hit") and int(t["nod_hit"]) <= tomorrow and str(t.get("status", "")) != "gone":
			t.erase("nod_hit")
			var N: Dictionary = data().get("nod", {})
			if rng.randf() < float(N.get("gone_chance", 0.4)) and kind(t["type"]).get("destroy", false):
				t["status"] = "gone"
				lines.append("Someone did something about %s. It burned in the night. Nod is full of it." % t["name"])
			else:
				t["status"] = "shut"
				t["shut_until"] = tomorrow + 3
				lines.append("Somebody hit %s after your post. It's shut for now." % t["name"])
			var m := IntelMarket._m(state)
			m["followers"] = int(m["followers"]) + int(N.get("post_followers", 12))
			_mood(state, t, int(data().get("mood", {}).get("nod_hit", 3)))
	# Nod tips: every so many followers someone sends an address
	var N2: Dictionary = data().get("nod", {})
	var fol := int(IntelMarket._m(state).get("followers", 0))
	if fol - int(T.get("nod_last", 0)) >= int(N2.get("tip_every", 20)):
		T["nod_last"] = fol
		var nt := _popup(state, rng, "nod", 0)
		var tl: Array = N2.get("tip_lines", ["%s on %s."])
		lines.append(str(tl[rng.randi() % tl.size()]) % [nt["name"], nt["street"]])
	# street word: now and then a place turns up on its own
	var open_pop := list(state).filter(func(t: Dictionary) -> bool: return not t.get("fixed", false)).size()
	if open_pop < int(data().get("popups", {}).get("max", 7)) and rng.randf() < 0.35:
		var wt := _popup(state, rng, "word", 0)
		lines.append("Word on the street: %s, on %s." % [wt["name"], wt["street"]])
	lines.append_array(_meet_groups(state))
	lines.append_array(_lent_home(state, tomorrow))
	lines.append_array(Town.night(state))          # M4 V5: walk-ins, reprisals, counterattacks on what you hold
	return lines


## POST ON NOD (the user's Haiti story): put a place's address out there and someone else hits it in a night
## or two. You get followers, not the loot. Heats the account.
static func post_on_nod(state: RefCounted, t: Dictionary) -> String:
	var N: Dictionary = data().get("nod", {})
	var m := IntelMarket._m(state)
	m["acct_heat"] = float(m.get("acct_heat", 0.0)) + float(N.get("post_heat", 15))
	var hd: Array = N.get("hit_days", [1, 2])
	t["nod_hit"] = int(state.day) + _rng(state, "nod" + str(t["id"])).randi_range(int(hd[0]), int(hd[1]))
	return "Posted %s on Nod: the address and what's inside. Somebody out there will do something about it." % t["name"]


# ------------------------------------------------------------------ where else targets come from

## A hack of a town place (v2/sim/hack.gd): it becomes a raid target; a plan file means guards and hours.
static func on_hack(state: RefCounted, ht: Dictionary, ran: Array, cut: bool) -> Array:
	var type := str(ROSTER_TYPE.get(str(ht.get("kind", "")), ""))
	if type == "" or cut:
		return []
	var t := {}
	for x in ts(state)["list"]:
		if str(x.get("hack_id", "")) == str(ht["id"]):
			t = x
	var know := 1
	if ran.has("grab") and (ht.get("files", []) as Array).any(func(f: Dictionary) -> bool: return f.get("tag", "") == "plan"):
		know = 2
	if t.is_empty():
		t = _new(state, type, "hack", {"hack_id": ht["id"], "know": know, "name": str(ht.get("name", ""))})
		return ["%s is on your Targets list now (%s)." % [t["name"], know_name(t)]]
	if int(t["know"]) < know:
		t["know"] = know
		return ["You know more about %s now (%s)." % [t["name"], know_name(t)]]
	return []


## The chair: a prisoner who talks gives up the inside of their own place, or another place.
static func from_chair(state: RefCounted, p: Dictionary) -> String:
	var C: Dictionary = data().get("chair", {})
	var own := find(state, str(p.get("from_target", "")))
	if not own.is_empty() and str(own.get("status", "")) != "gone" and int(own["know"]) < 3:
		own["know"] = 3
		var lv := level_for(state, own)
		var room := ""
		for c in lv.get("loot", []):
			if c.get("good", false):
				room = str(c["room"])
		var rname := room
		for r in lv["rooms"]:
			if r["id"] == room:
				rname = str(r["name"]).to_lower()
		return str(C.get("inside_line", "%s: %s")) % [own["name"], rname]
	var t := _popup(state, _rng(state, "chair" + str(p.get("name", ""))), "chair", 2)
	return str(C.get("tip_line", "%s on %s.")) % [t["name"], t["street"]]


# ------------------------------------------------------------------ the groups

static func _group(state: RefCounted, gid: String) -> Dictionary:
	var G: Dictionary = ts(state)["groups"]
	if not G.has(gid):
		G[gid] = {"met": false, "pts": 0, "job": "", "favour_day": -99}
	return G[gid]


static func group_def(gid: String) -> Dictionary:
	return data().get("groups", {}).get(gid, {})


static func group_ids() -> Array:
	return data().get("groups", {}).keys()


static func met(state: RefCounted, gid: String) -> bool:
	return bool(_group(state, gid).get("met", false))


static func trust(state: RefCounted, gid: String) -> int:
	var pts := int(_group(state, gid)["pts"])
	var lv := 0
	var th: Array = group_def(gid).get("trust", [0, 3, 7, 12, 18])
	for i in th.size():
		if pts >= int(th[i]):
			lv = i
	return lv


static func _add_pts(state: RefCounted, gid: String, d: int) -> void:
	var g := _group(state, gid)
	g["pts"] = maxi(0, int(g["pts"]) + d)


## Groups turn up as things happen (things pop up, no gates): dirt for the paper, a gun for the Foundry,
## a few hacks for Ninth Lamp, someone hurt for the Sisters.
static func _meet_groups(state: RefCounted) -> Array:
	var lines: Array = []
	var has_tag := func(tag: String) -> bool: return state.items.any(func(it: Dictionary) -> bool: return it.get("type", "") == "intel" and it.get("tag", "") == tag)
	var conds := {
		"reporters": has_tag.call("dirt"),
		"weapons": int(ts(state).get("wins", 0)) >= 1 or state.items.any(func(it: Dictionary) -> bool: return str(it.get("gear", "")) in ["guard_smg", "service_pistol", "bureau_carbine"]),
		"hackers": (state.os.get("jobs_done", []) as Array).size() >= 3,
		"aid": state.people.any(func(p: Dictionary) -> bool: return int(p.get("injury_days", 0)) > 0),
	}
	for gid in conds:
		if conds[gid] and not met(state, gid):
			_group(state, gid)["met"] = true
			var d := group_def(gid)
			lines.append("New contact: %s. %s They want %s. (Contacts, on the PC.)" % [d.get("name", gid), d.get("who", ""), want_words(gid)])
			state.flags["contacts_new"] = true
	return lines


static func want_words(gid: String) -> String:
	var w: Dictionary = group_def(gid).get("wants", {})
	var out: Array = []
	for k in w:
		for id in w[k]:
			var word: String = {"plan": "plans", "papers": "blank papers", "codebook": "codebooks"}.get(str(id), str(id))
			if k == "gear":
				word = "guns" if Loadout.gdef(id).get("slot", "") in ["primary", "sidearm"] else str(Loadout.gdef(id).get("name", id))
			elif k == "supply":
				word = str(Loadout.gdef(id).get("name", id))
			elif k == "material":
				word = str(Content.get_file("recipes").get("materials", {}).get(id, {}).get("name", id))
			if not out.has(word.to_lower()):
				out.append(word.to_lower())
	return ", ".join(PackedStringArray(out.slice(0, 5)))


## What you hold that this group wants, with what they'd pay: [{key, label, price, ref}].
static func offers(state: RefCounted, gid: String) -> Array:
	var w: Dictionary = group_def(gid).get("wants", {})
	var out: Array = []
	var bonus := 1.0 + 0.1 * trust(state, gid)
	for it in state.items:
		if it.has("on"):
			continue
		if it.get("type", "") == "intel" and (w.get("intel", []) as Array).has(it.get("tag", "")):
			out.append({"kind": "item", "ref": it, "label": "%s [%s]" % [it["name"], str(it["tag"]).to_upper()], "price": int(IntelMarket.price(state, it) * bonus)})
		elif it.get("type", "") == "gear" and (w.get("gear", []) as Array).has(it.get("gear", "")):
			var pr := int(Loadout.gdef(it["gear"]).get("price", 0))
			out.append({"kind": "item", "ref": it, "label": str(it["name"]), "price": int(maxf(30.0, pr * 0.6) * bonus)})
	for sid in w.get("supply", []):
		if int(state.supplies.get(sid, 0)) > 0:
			out.append({"kind": "supply", "ref": sid, "label": "%s (1 of %d)" % [Loadout.gdef(sid).get("name", sid), int(state.supplies[sid])], "price": int(8 * bonus)})
	for mid in w.get("material", []):
		if int(state.materials.get(mid, 0)) > 0:
			out.append({"kind": "material", "ref": mid, "label": "%s (1 of %d)" % [Content.get_file("recipes").get("materials", {}).get(mid, {}).get("name", mid), int(state.materials[mid])], "price": int(6 * bonus)})
	return out


## Hand something over: money and trust.
static func sell(state: RefCounted, gid: String, o: Dictionary) -> String:
	match str(o["kind"]):
		"item":
			var it: Dictionary = o["ref"]
			if gid == "fixer" and it.get("type", "") == "intel":
				IntelMarket.sell(state, it)          # the fixer's own trust (opens Lantern)
			else:
				state.items.erase(it)
				state.money += int(o["price"])
		"supply":
			state.supplies[o["ref"]] = int(state.supplies[o["ref"]]) - 1
			state.money += int(o["price"])
		"material":
			load("res://v2/sim/materials.gd").take(state, str(o["ref"]), 1)
			state.money += int(o["price"])
	_add_pts(state, gid, int(data().get("group_job", {}).get("sell_trust", 1)))
	return "%s took %s for %d cr." % [group_def(gid).get("name", gid), o["label"], int(o["price"])]


## Their goods, by trust: [{lvl, type, id, n, price, line, open}].
static func stock(state: RefCounted, gid: String) -> Array:
	var out: Array = []
	var tl := trust(state, gid)
	for s in group_def(gid).get("stock", []):
		var e: Dictionary = (s as Dictionary).duplicate()
		e["open"] = tl >= int(s.get("lvl", 0))
		if not e.has("line"):
			e["line"] = ("BLUEPRINT: %s" % Crafting.recipe(str(s["id"])).get("name", s["id"])) if s["type"] == "blueprint" else \
				"%s%s" % [Loadout.gdef(str(s["id"])).get("name", s["id"]), " x%d" % int(s["n"]) if s.has("n") else ""]
		out.append(e)
	return out


static func buy(state: RefCounted, gid: String, s: Dictionary, target_id := "") -> String:
	if not s.get("open", false):
		return "They don't trust you with that yet."
	if int(state.money) < int(s["price"]):
		return "Not enough money."
	if s["type"] == "blueprint" and state.unlocked_recipes.has(s["id"]):
		return "You already have that one."
	state.money -= int(s["price"])
	match str(s["type"]):
		"supply":
			state.supplies[s["id"]] = int(state.supplies.get(s["id"], 0)) + int(s.get("n", 1))
		"gear":
			Loadout.add_item(state, str(s["id"]), {"source": group_def(gid).get("name", gid)})
		"blueprint":
			state.unlocked_recipes.append(s["id"])
		"intel_scout":
			var t := find(state, target_id)
			if t.is_empty():
				var pool: Array = list(state).filter(func(x: Dictionary) -> bool: return int(x["know"]) < 2 and str(x.get("level", "")) == "")
				if pool.is_empty():
					state.money += int(s["price"])
					return "There's nothing they can tell you right now."
				t = pool[0]
			t["know"] = mini(3, int(t["know"]) + 1)
			return "%s: you know %s about %s now." % [group_def(gid).get("name", gid), know_name(t).to_lower(), t["name"]]
	return "Bought from %s." % group_def(gid).get("name", gid)


## Their current job (a target they want hit), made when you ask.
static func job(state: RefCounted, gid: String) -> Dictionary:
	var jid := str(_group(state, gid).get("job", ""))
	if jid == "":
		return {}
	var t := find(state, jid)
	if t.is_empty() or str(t.get("status", "")) == "gone":
		_group(state, gid)["job"] = ""
		return {}
	return t


static func take_job(state: RefCounted, gid: String) -> String:
	if not job(state, gid).is_empty():
		return "You already have their job."
	var jobs: Array = group_def(gid).get("jobs", [])
	if jobs.is_empty():
		return "They have nothing for you."
	var rng := _rng(state, "job" + gid)
	var j: Dictionary = jobs[rng.randi() % jobs.size()]
	var t := _new(state, str(j["type"]), "job", {"group": gid, "know": 1, "job": gid, "pay": int(j.get("pay", 50)), "line": str(j.get("line", ""))})
	_group(state, gid)["job"] = t["id"]
	return "%s: \"%s\" (%s, on your Targets list)" % [group_def(gid).get("name", gid), j.get("line", ""), t["name"]]


static func _job_done(state: RefCounted, t: Dictionary) -> Array:
	var gid := str(t.get("job", ""))
	var d := group_def(gid)
	var J: Dictionary = data().get("group_job", {})
	state.money += int(t.get("pay", 0))
	_add_pts(state, gid, int(J.get("trust", 3)))
	_group(state, gid)["job"] = ""
	var out := ["%s paid %d cr for the job. They trust you more." % [d.get("name", gid), int(t.get("pay", 0))]]
	var rival := str(d.get("rival", ""))
	if rival != "" and met(state, rival):
		_add_pts(state, rival, int(J.get("rival", -1)))
		out.append("%s heard you worked for %s. They're cooler with you." % [group_def(rival).get("name", rival), d.get("name", gid)])
	return out


static func favour_ready(state: RefCounted, gid: String) -> bool:
	return trust(state, gid) >= 4 and int(state.day) - int(_group(state, gid).get("favour_day", -99)) >= 7


## A favour, once a week at the top trust.
static func favour(state: RefCounted, gid: String, target_id := "") -> String:
	if not favour_ready(state, gid):
		return "Not yet."
	var f: Dictionary = group_def(gid).get("favour", {})
	_group(state, gid)["favour_day"] = int(state.day)
	match str(f.get("id", "")):
		"cool":
			state.attention = maxf(0.0, float(state.attention) + float(f.get("attention", -15)))
		"story":
			var m := IntelMarket._m(state)
			m["followers"] = int(m["followers"]) + int(f.get("followers", 40))
			for k in ts(state)["mood"]:
				ts(state)["mood"][k] = int(ts(state)["mood"][k]) + int(f.get("mood", 6))
		"lend":
			_lend(state, int(f.get("nights", 3)))
		"scout":
			var t := find(state, target_id)
			if t.is_empty() and not list(state).is_empty():
				t = list(state)[0]
			if not t.is_empty():
				t["know"] = 3
		"heal":
			for p in state.people:
				if p.get("alive", true):
					p["injury_days"] = 0
					p["hp"] = 100.0
	return str(f.get("line", "Done."))


## The Foundry lends a man with his own kit; he goes home after some nights (his kit with him).
static func _lend(state: RefCounted, nights: int) -> void:
	var L: Dictionary = data().get("lent", {})
	var pg = load("res://v2/sim/people_gen.gd")
	var who: Dictionary = pg.make(hash("lent%d" % int(state.day)), "guard")
	var p := {"id": "lent%d" % int(state.day), "name": str(who.get("name", "A FOUNDRY MAN")).to_upper(), "role": L.get("role", "point"), "trait": L.get("trait", "steady"),
		"tech": int(L.get("tech", 2)), "motive": {"id": "belief", "name": "Belief", "line": "Lent by the Foundry boys."}, "line": "Lent by the Foundry boys for a few nights.",
		"alive": true, "level": 2, "ops": 0, "loyalty": 80, "kit": {}, "grid": [], "lent_until": int(state.day) + nights}
	state.people.append(p)
	for gid in L.get("kit", []):
		var it := Loadout.add_item(state, str(gid), {"source": "lent", "lent": p["id"]})
		Loadout.equip(state, p, it)
	var sup: Dictionary = L.get("supplies", {})
	for k in sup:
		state.supplies[k] = int(state.supplies.get(k, 0)) + int(sup[k])


static func _lent_home(state: RefCounted, tomorrow: int) -> Array:
	var lines: Array = []
	for p in state.people.duplicate():
		if p.has("lent_until") and int(p["lent_until"]) <= tomorrow:
			state.people.erase(p)
			state.items = state.items.filter(func(it: Dictionary) -> bool: return str(it.get("lent", "")) != str(p["id"]))
			lines.append("%s went back to the Foundry, with his kit." % str(p["name"]).capitalize() if p.get("alive", true) else "")
	return lines.filter(func(s: String) -> bool: return s != "")


# ------------------------------------------------------------------ prisoners

## Cuffed people walked out: the first to the chair (if it's free), the rest held in the back.
static func bring_prisoners(state: RefCounted, people: Array) -> Array:
	var lines: Array = []
	var T := ts(state)
	for p in people:
		if state.flags.get("prisoner", {}).is_empty():
			state.flags["prisoner"] = p
			lines.append("You brought %s back. They're tied to a chair under the bulb." % p["name"])
		else:
			T["held"].append(p)
			lines.append("%s is held in the back until the chair is free." % p["name"])
	return lines


## The chair is free: the next one held sits down.
static func next_prisoner(state: RefCounted) -> void:
	var held: Array = ts(state)["held"]
	if state.flags.get("prisoner", {}).is_empty() and not held.is_empty():
		state.flags["prisoner"] = held.pop_front()
