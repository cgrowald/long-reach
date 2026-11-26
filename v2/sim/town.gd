extends RefCounted
## M4 V5: the town (docs/M4_VARIETY.md section 10; districts in data/v2/districts.json). No nodes.
## The pattern: a Gates of Hell Conquest / Total War campaign map. The town is rows of districts from your
## home (bottom) up to the citadel (top); you open a district by taking its key target and keep it with a
## tug-of-war bar. Small jobs can be anywhere; big ops (the ones that take the night) and keys only on the
## front: districts next to one you hold (or next to home).
## The layout is generated from the world seed (same every load, never saved); what you hold is saved in
## state.targets["map"] = {districts: {id: {held, bar}}}.
## Coordinates: metres, x right, z negative = north (up the screen). The street side of the town is +z.

const Content := preload("res://v2/sim/content.gd")

const ROW_H := 46.0
const WIDTH := 150.0
const AVENUE := 7.0
const STREET := 4.5

static var _cache := {}


static func data() -> Dictionary:
	return Content.get_file("districts")


## The town for this run. {districts: [...], streets: [Rect2], buildings: [...], garage: Vector2, size: Rect2}
static func layout(state: RefCounted) -> Dictionary:
	var key := int(state.world_seed)
	if _cache.has(key):
		return _cache[key]
	var D := data()
	var defs: Dictionary = D.get("districts", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:town" % key)
	var mids: Array = []
	for id in defs:
		if defs[id].get("role", "") == "mid":
			mids.append(id)
	for i in range(mids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = mids[i]
		mids[i] = mids[j]
		mids[j] = tmp
	var rows: Array = D.get("rows", [])
	var out := {"districts": [], "streets": [], "buildings": [], "places": {}}
	var mi := 0
	for r in rows.size():
		var row: Array = rows[r]
		var w := WIDTH / row.size()
		for c in row.size():
			var role := str(row[c])
			var id := ""
			match role:
				"home":
					id = str(D.get("home", "canal"))
				"mid":
					id = mids[mi % mids.size()]
					mi += 1
				_:
					for k in defs:
						if defs[k].get("role", "") == role:
							id = k
			var rc := Rect2(c * w, -(r + 1) * ROW_H, w, ROW_H)
			var dd: Dictionary = defs.get(id, {})
			out["districts"].append({"id": id, "name": dd.get("name", id), "role": dd.get("role", role), "row": r, "col": c,
				"rect": rc, "colours": dd.get("colours", ["#555555", "#888888"]), "key": dd.get("key", "police"), "vibe": dd.get("vibe", "")})
	# avenues on every district border; inner streets inside each district
	var size := Rect2(0, -rows.size() * ROW_H, WIDTH, rows.size() * ROW_H)
	out["size"] = size
	for r in rows.size() + 1:
		out["streets"].append(Rect2(0, -r * ROW_H - AVENUE * 0.5, WIDTH, AVENUE))
	for dist in out["districts"]:
		var rc: Rect2 = dist["rect"]
		if rc.position.x > 0.1:
			out["streets"].append(Rect2(rc.position.x - AVENUE * 0.5, rc.position.y, AVENUE, rc.size.y))
	out["streets"].append(Rect2(-AVENUE * 0.5, size.position.y, AVENUE, size.size.y))
	out["streets"].append(Rect2(WIDTH - AVENUE * 0.5, size.position.y, AVENUE, size.size.y))
	for dist in out["districts"]:
		_district(rng, dist, out)
	# your garage: the bottom-left building of home
	var home := district(out, str(D.get("home", "canal")))
	var best := -1
	var bs := -1e9
	for i in out["buildings"].size():
		var b: Dictionary = out["buildings"][i]
		if b["district"] == home["id"] and b["kind"] == "house":
			var score: float = (b["rect"] as Rect2).end.y * 2.0 - (b["rect"] as Rect2).position.x
			if score > bs:
				bs = score
				best = i
	if best >= 0:
		out["buildings"][best]["kind"] = "garage"
		out["garage"] = best
	_places(rng, out)
	_cache[key] = out
	return out


## Inner streets cut the district into blocks; blocks hold 1-3 buildings.
static func _district(rng: RandomNumberGenerator, dist: Dictionary, out: Dictionary) -> void:
	var rc: Rect2 = (dist["rect"] as Rect2).grow(-AVENUE * 0.5)
	if dist["role"] == "citadel":
		var c := rc.get_center()
		out["buildings"].append({"rect": Rect2(c.x - 26, rc.position.y + 6, 52, rc.size.y - 14), "h": 16.0, "district": dist["id"], "kind": "citadel", "place": "citadel"})
		return
	var xs: Array = [rc.position.x]
	var x := rc.position.x
	while true:
		x += rng.randf_range(13.0, 19.0)
		if x > rc.end.x - 11.0:
			break
		xs.append(x)
	xs.append(rc.end.x)
	var zs: Array = [rc.position.y]
	var z := rc.position.y
	while true:
		z += rng.randf_range(14.0, 20.0)
		if z > rc.end.y - 11.0:
			break
		zs.append(z)
	zs.append(rc.end.y)
	for i in range(1, xs.size() - 1):
		out["streets"].append(Rect2(float(xs[i]) - STREET * 0.5, rc.position.y, STREET, rc.size.y))
	for j in range(1, zs.size() - 1):
		out["streets"].append(Rect2(rc.position.x, float(zs[j]) - STREET * 0.5, rc.size.x, STREET))
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var x0: float = float(xs[i]) + (STREET * 0.5 if i > 0 else 0.0)
			var x1: float = float(xs[i + 1]) - (STREET * 0.5 if i < xs.size() - 2 else 0.0)
			var z0: float = float(zs[j]) + (STREET * 0.5 if j > 0 else 0.0)
			var z1: float = float(zs[j + 1]) - (STREET * 0.5 if j < zs.size() - 2 else 0.0)
			var blk := Rect2(x0, z0, x1 - x0, z1 - z0).grow(-0.8)
			if blk.size.x < 5 or blk.size.y < 5:
				continue
			# 1-3 buildings side by side; the odd yard left empty
			var n := rng.randi_range(1, 3) if blk.size.x > 11 else 1
			var bx := blk.position.x
			for k in n:
				var bw := blk.size.x / n
				var deep := blk.size.y * rng.randf_range(0.55, 1.0)
				var r := Rect2(bx + 0.4, blk.end.y - deep, bw - 0.8, deep)       # fronts on the street side (south)
				bx += bw
				if rng.randf() < 0.12:
					continue
				var h := rng.randf_range(4.5, 9.5) + (4.0 if dist["role"] == "ministry" else 0.0)
				out["buildings"].append({"rect": r, "h": h, "district": dist["id"], "kind": "house", "place": ""})


## Which buildings are places: per district, its key (the biggest building) and its kinds of targets, plus
## the groups' haunts.
static func _places(rng: RandomNumberGenerator, out: Dictionary) -> void:
	var defs: Dictionary = data().get("districts", {})
	for dist in out["districts"]:
		if dist["role"] == "citadel":
			continue
		var idx: Array = []
		for i in out["buildings"].size():
			var b: Dictionary = out["buildings"][i]
			if b["district"] == dist["id"] and b["kind"] == "house":
				idx.append(i)
		idx.sort_custom(func(a: int, b: int) -> bool: return (out["buildings"][a]["rect"] as Rect2).get_area() > (out["buildings"][b]["rect"] as Rect2).get_area())
		if idx.is_empty():
			continue
		var k: int = idx.pop_front()
		out["buildings"][k]["kind"] = "place"
		out["buildings"][k]["place"] = "key:" + str(dist["key"])
		for i in range(idx.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = idx[i]
			idx[i] = idx[j]
			idx[j] = tmp
		var places: Dictionary = defs.get(dist["id"], {}).get("places", {})
		for type in places:
			for n in int(places[type]):
				if idx.is_empty():
					break
				var bi: int = idx.pop_back()
				out["buildings"][bi]["kind"] = "place"
				out["buildings"][bi]["place"] = type
	# the groups' haunts (V4 contacts), in the district they belong to when it's there
	var haunts := {"fixer": ["tram", "canal"], "reporters": ["hill", "mill"], "weapons": ["foundry", "rail"], "hackers": ["rail", "mill"], "aid": ["canal"]}
	out["haunts"] = {}
	for gid in haunts:
		(haunts[gid] as Array).append(str(data().get("home", "canal")))      # nowhere of their own: they meet you near home
		for did in haunts[gid]:
			if district(out, did).is_empty():
				continue
			for i in out["buildings"].size():
				var b: Dictionary = out["buildings"][i]
				if b["district"] == did and b["kind"] == "house":
					b["kind"] = "haunt"
					b["place"] = gid
					out["haunts"][gid] = i
					break
			break
	# the Tram Yard market is the fixer's haunt
	out["yard"] = out["haunts"].get("fixer", -1)


static func district(L: Dictionary, id: String) -> Dictionary:
	for d in L["districts"]:
		if d["id"] == id:
			return d
	return {}


static func district_at(L: Dictionary, p: Vector2) -> Dictionary:
	for d in L["districts"]:
		if (d["rect"] as Rect2).has_point(p):
			return d
	return {}


# ------------------------------------------------------------------ what you hold

static func ms(state: RefCounted) -> Dictionary:
	var T: Dictionary = load("res://v2/sim/targets.gd").ts(state)
	if not T.has("map"):
		T["map"] = {"districts": {}}
	return T["map"]


static func dstate(state: RefCounted, id: String) -> Dictionary:
	var M: Dictionary = ms(state)["districts"]
	if not M.has(id):
		M[id] = {"held": false, "bar": 0}
	return M[id]


static func held(state: RefCounted, id: String) -> bool:
	return bool(dstate(state, id).get("held", false))


static func adjacent(L: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	var ra: Rect2 = a["rect"]
	var rb: Rect2 = b["rect"]
	return ra.grow(AVENUE).intersects(rb) and a["id"] != b["id"]


## On the front: home, any district you hold, and any district touching one of those.
static func on_front(state: RefCounted, id: String) -> bool:
	var L := layout(state)
	var home := str(data().get("home", "canal"))
	if id == home or held(state, id):
		return true
	var d := district(L, id)
	for o in L["districts"]:
		if (o["id"] == home or held(state, o["id"])) and adjacent(L, o, d):
			return true
	return false


## Big ops (the ones that take the night) and district keys need the front; small jobs go anywhere.
static func reachable(state: RefCounted, t: Dictionary) -> bool:
	var did := str(t.get("district", ""))
	if did == "":
		return true
	var big: bool = str(load("res://v2/sim/targets.gd").kind(str(t["type"])).get("time", "night")) == "night" or t.has("key")
	return not big or on_front(state, did)


## A win at a target: a key opens its district; any win in a held district pushes its bar up.
static func on_hit(state: RefCounted, t: Dictionary, outcome: String) -> Array:
	var did := str(t.get("district", ""))
	if did != "" and outcome != "":
		ms(state)["recent"] = ms(state).get("recent", {})
		ms(state)["recent"][did] = int(state.day)          # they answer hits with reprisals
	if did == "" or outcome != "success":
		return []
	var ds := dstate(state, did)
	var L := layout(state)
	var nm := str(district(L, did).get("name", did))
	if t.has("key") and not ds["held"]:
		ds["held"] = true
		ds["bar"] = 60
		ds["garrison"] = int(H().get("start_garrison", 2))          # a few locals stand up straight away
		t["status"] = "gone"           # the post is ours now
		return ["%s is ours. %d locals stand up to hold it. Post more there (the map, at the post) or it slips back." % [nm, garrison(state, did)]]
	if ds["held"]:
		ds["bar"] = mini(100, int(ds["bar"]) + 10)
	return []


# ------------------------------------------------------------------ targets on the map

## Put a target in the town: its district and building. Fixed ones go where they belong; keys to their
## district; the rest to a building of their kind (or any free one) in a fitting district.
static func place_target(state: RefCounted, t: Dictionary) -> void:
	if t.has("bldg"):
		return
	var L := layout(state)
	var want := str(t["type"])
	var did := str(t.get("district", ""))
	var home := str(data().get("home", "canal"))
	match str(t["id"]):
		"fix_police":
			did = "ministry"
		"fix_refinery":
			did = "foundry" if not district(L, "foundry").is_empty() else ""
		"fix_radio":
			did = "hill" if not district(L, "hill").is_empty() else ""
		"kessel":
			did = home
	var taken := {}
	for o in load("res://v2/sim/targets.gd").ts(state)["list"]:
		if o.has("bldg"):
			taken[int(o["bldg"])] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:place:%s" % [int(state.world_seed), str(t["id"])])
	var cands: Array = []
	for i in L["buildings"].size():
		var b: Dictionary = L["buildings"][i]
		if taken.has(i) or b["kind"] in ["garage", "citadel", "haunt"]:
			continue
		if did != "" and b["district"] != did:
			continue
		if district(L, b["district"]).get("role", "") == "citadel":
			continue
		var p := str(b["place"])
		if t.has("key") or str(t["id"]).begins_with("fix_"):
			if p.begins_with("key:"):
				cands.append(i)
		elif p == want:
			cands.append(i)
	if cands.is_empty():
		for i in L["buildings"].size():
			var b: Dictionary = L["buildings"][i]
			if not taken.has(i) and b["kind"] == "house" and (did == "" or b["district"] == did) and district(L, b["district"]).get("role", "") not in ["citadel"]:
				cands.append(i)
	if cands.is_empty():
		return
	var bi: int = cands[rng.randi() % cands.size()]
	t["bldg"] = bi
	t["district"] = L["buildings"][bi]["district"]
	var dn := str(district(L, t["district"]).get("name", ""))
	t["street"] = dn.capitalize() if str(t.get("street", "")) == "" else t["street"]


## Every district (but the citadel and home) gets its key target: the building you take to open it.
## Ministry Row's key is the Central Police HQ; Hill Steps' the radio mast; the Foundry's the refinery.
static func ensure_keys(state: RefCounted) -> void:
	var Targets = load("res://v2/sim/targets.gd")
	var L := layout(state)
	var M := ms(state)
	if M.get("keys_made", false):
		return
	M["keys_made"] = true
	for d in L["districts"]:
		if d["role"] in ["citadel", "home"]:
			continue
		var fixed_id: String = {"ministry": "fix_police", "hill": "fix_radio", "foundry": "fix_refinery"}.get(d["id"], "")
		var t: Dictionary = Targets.find(state, fixed_id) if fixed_id != "" else {}
		if t.is_empty():
			var type := str(d["key"]) if str(d["key"]) in ["police", "radio", "refinery"] else "police"
			t = Targets._new(state, type, "fixed", {"id": "key_" + str(d["id"]), "tier": clampi(int(d["row"]), 1, 3), "know": 1, "name": "%s %s" % [str(d["name"]), "POLICE POST" if type == "police" else type.to_upper()],
				"line": "The %s post that keeps %s down. Take it and the district can be ours." % [type.replace("_", " "), str(d["name"]).capitalize()]})
			t["fixed"] = true
		t["key"] = d["id"]
		t["district"] = d["id"]
	for t in Targets.ts(state)["list"]:
		place_target(state, t)


# ------------------------------------------------------------------ holding (V5 part 2)
## User 2026-11-26: "you have to leave troops to defend, but it's an auto battle; this is where thinking
## strategically matters so you don't stretch yourself thin." Held districts send walk-in MILITIA (a free
## pool, ms.militia); you post them as a garrison in a district and give them spare guns from the stash
## (an armed militiaman counts fully, an unarmed one a third). Every night the regime may counterattack a
## held district: their strength against your garrison, settled as an auto battle (rounds of losses). Hits
## bring reprisals on the street. A district's bar slips without a garrison; at 0 it's theirs again.

static func H() -> Dictionary:
	return data().get("holding", {})


static func militia(state: RefCounted) -> int:
	return int(ms(state).get("militia", 0))


static func garrison(state: RefCounted, did: String) -> int:
	return int(dstate(state, did).get("garrison", 0))


static func arms(state: RefCounted, did: String) -> int:
	return int(dstate(state, did).get("arms", 0))


static func strength(state: RefCounted, did: String) -> float:
	var g := garrison(state, did)
	var a := mini(g, arms(state, did))
	return a * 1.0 + (g - a) * float(H().get("unarmed", 0.34))


## Move militia between the free pool and a district (n < 0 takes them back).
static func post(state: RefCounted, did: String, n: int) -> int:
	if not held(state, did) and n > 0:
		return 0
	var M := ms(state)
	var ds := dstate(state, did)
	if n > 0:
		n = mini(n, militia(state))
	else:
		n = -mini(-n, garrison(state, did))
	M["militia"] = militia(state) - n
	ds["garrison"] = garrison(state, did) + n
	return n


## Spare guns in the stash (not worn by anyone): what you can hand to a garrison.
static func spare_guns(state: RefCounted) -> Array:
	var out: Array = []
	var Loadout = load("res://v2/sim/loadout.gd")
	for it in state.items:
		if it.get("type", "") == "gear" and not it.has("on") and str(Loadout.gdef(str(it.get("gear", ""))).get("slot", "")) in ["primary", "sidearm"] and str(it.get("gear", "")) != "pipe":
			out.append(it)
	return out


## Hand one spare gun to a district's garrison (it leaves the stash for good).
static func arm(state: RefCounted, did: String) -> String:
	var guns := spare_guns(state)
	if guns.is_empty():
		return "No spare guns on the shelves."
	var it: Dictionary = guns[0]
	state.items.erase(it)
	dstate(state, did)["arms"] = arms(state, did) + 1
	return "%s went to the garrison." % it.get("name", "A gun")


## Their attack on a district tonight: how strong (the deeper toward the citadel and the hotter you are, the
## stronger), or 0 if they don't come. More of their districts next door = likelier.
static func attack_for(state: RefCounted, did: String, rng: RandomNumberGenerator) -> float:
	var L := layout(state)
	var d := district(L, did)
	var theirs := 0
	for o in L["districts"]:
		if not held(state, o["id"]) and o["role"] != "home" and adjacent(L, o, d):
			theirs += 1
	var chance := float(H().get("attack_base", 0.1)) + float(state.attention) / 300.0 + 0.05 * theirs
	if rng.randf() > chance:
		return 0.0
	return float(H().get("attack_min", 3.0)) + int(d.get("row", 1)) * float(H().get("attack_per_row", 2.5)) + float(state.attention) / 12.0 + rng.randf_range(0.0, 4.0)


## The auto battle: both sides lose people round by round until one breaks. Returns {held, lost}.
static func battle(state: RefCounted, did: String, attack: float, rng: RandomNumberGenerator) -> Dictionary:
	var start := strength(state, did)
	var ours := start
	var them := attack * float(H().get("enemy_per_head", 0.6))      # worse than us, but many
	var rounds := 0
	while ours > 0.5 and them > 0.5 and rounds < 12:
		rounds += 1
		var hit_us := them * rng.randf_range(0.08, 0.2)
		var hit_them := ours * rng.randf_range(0.12, 0.26)       # they're worse than us, but many
		them -= hit_them
		ours -= hit_us
		if them < attack * float(H().get("enemy_per_head", 0.6)) * 0.4:
			break                    # they pull back when it goes badly
		if ours < start * 0.35:
			break                    # we fall back
	var frac := clampf(1.0 - ours / maxf(0.01, start), 0.0, 1.0)
	var lost := mini(garrison(state, did), int(round(garrison(state, did) * frac)))
	var won := ours > 0.5 and (them < attack * float(H().get("enemy_per_head", 0.6)) * 0.4 or ours >= them)
	return {"held": won, "lost": lost}


## Overnight on the map: walk-ins, the bar, reprisals, their counterattacks. Returns ledger lines.
static func night(state: RefCounted) -> Array:
	var lines: Array = []
	var L := layout(state)
	var M := ms(state)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:townnight:%d" % [int(state.world_seed), int(state.day)])
	var T = load("res://v2/sim/targets.gd")
	var recent: Dictionary = M.get("recent", {})
	for d in L["districts"]:
		var did: String = d["id"]
		var nm := str(d["name"]).capitalize()
		# reprisals: the night after a hit they come down on the street
		if recent.has(did) and int(recent[did]) >= int(state.day) - 1 and rng.randf() < float(H().get("reprisal", 0.6)):
			T._mood(state, {"district": did}, -int(H().get("reprisal_mood", 4)))
			if held(state, did):
				var took := mini(garrison(state, did), rng.randi_range(0, 2))
				dstate(state, did)["garrison"] = garrison(state, did) - took
				dstate(state, did)["bar"] = maxi(0, int(dstate(state, did)["bar"]) - 6)
				lines.append("Reprisals in %s: doors kicked in, %d of ours taken." % [nm, took])
			else:
				lines.append("Reprisals in %s after the hit. People are angry; at whom depends on you." % nm)
		if not held(state, did):
			continue
		var ds := dstate(state, did)
		# walk-ins: people who want in, from a district that's ours
		var mood := int(T.ts(state)["mood"].get(did, 0))
		var walk := maxi(0, int(round(float(H().get("walk_ins", 1.5)) + mood / 15.0 + int(ds["bar"]) / 50.0 + rng.randf_range(-0.6, 0.6))))
		if walk > 0:
			M["militia"] = militia(state) + walk
			lines.append("%d walked in from %s wanting to fight (militia: %d free)." % [walk, nm, militia(state)])
		# the bar: a garrison holds it, an empty district slips
		var g := garrison(state, did)
		ds["bar"] = clampi(int(ds["bar"]) + (2 if g >= int(H().get("enough", 4)) else (-3 if g > 0 else -9)), 0, 100)
		# their counterattack: an auto battle against the garrison
		var atk := attack_for(state, did, rng)
		if atk > 0.0:
			var r := battle(state, did, atk, rng)
			ds["garrison"] = garrison(state, did) - int(r["lost"])
			if r["held"]:
				ds["bar"] = mini(100, int(ds["bar"]) + 5)
				lines.append("They came for %s in the night (about %d). The garrison held, %d lost." % [nm, int(atk), int(r["lost"])])
			else:
				lines.append("They took %s back in the night (about %d of them). %d of ours lost, the rest scattered home." % [nm, int(atk), int(r["lost"])])
				_lose(state, did)
				continue
		if int(ds["bar"]) <= 0:
			lines.append("%s slipped away: nobody was there to hold it." % nm)
			_lose(state, did)
	return lines


## A district is theirs again: half the survivors come back to the pool, the guns are gone, its key reopens.
static func _lose(state: RefCounted, did: String) -> void:
	var ds := dstate(state, did)
	ms(state)["militia"] = militia(state) + int(garrison(state, did) / 2)
	ds["held"] = false
	ds["garrison"] = 0
	ds["arms"] = 0
	ds["bar"] = 0
	var T = load("res://v2/sim/targets.gd")
	for t in T.ts(state)["list"]:
		if str(t.get("key", "")) == did:
			t["status"] = "open"
			t["reinforce"] = mini(3, int(t.get("reinforce", 0)) + 1)
			t["know"] = mini(int(t["know"]), 1)
