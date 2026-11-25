extends RefCounted
## M4 V3: the building generator (docs/M4_VARIETY.md section 7; programs in data/v2/buildings.json).
## A seed and a type (bar, office, clinic, gun shop, police post, depot) -> a level in the same shape as the
## hand-made ones (data/v2/combat/*.json): rooms, doors, dressing, guards, people, cover, a plan sheet.
##
## The pattern: the standard procedural floor-plan recipe (Marson & Musse 2010, "squarified treemap" floor
## plans): split the footprint into zones (the rooms on the street, the rooms behind, maybe a wing out the
## back), split each zone into rooms by floor-area weight with an ordered treemap, put in a hall only where
## the program wants one, then join the rooms with a spanning tree of doors that follows which rooms lead to
## which (kitchen off the bar, records off the office), plus a loop or two so there's more than one way.
## Open rooms meet through wide openings. A street in front, a side passage, an alley, sometimes a yard.
## Single floor (user 2026-11-25). Coordinates: x right, z forward is -z; the street is at +z.

const Content := preload("res://v2/sim/content.gd")
const People := preload("res://v2/sim/people_gen.gd")
const Level := preload("res://v2/combat/level.gd")     # KIT_DEPTH / KIT_WIDTH only

const GRID := 0.5
const MIN := 3.0            # smallest room side (doors, stack spots, furniture)
const EPS := 0.01
const WALL_IN := 0.07       # level.gd stands pieces this far off the wall
const TRIES := 40


static func data() -> Dictionary:
	return Content.get_file("buildings")


static func types() -> Array:
	return (data().get("types", {}) as Dictionary).keys()


## Any level by id: "gen:<type>:<seed>" builds one, anything else is a data file.
static func level(id: String) -> Dictionary:
	if id.begins_with("gen:"):
		var parts := id.split(":")
		return generate(parts[1], int(parts[2]) if parts.size() > 2 else 1)
	return Content.get_file(id)


## A building that passes check(), or the last try with its problems in ["generated"]["problems"].
static func generate(type: String, p_seed: int) -> Dictionary:
	var last := {}
	for attempt in TRIES:
		var lv := _try(type, p_seed, attempt)
		if lv.is_empty():
			continue
		var probs := check(lv)
		lv["generated"]["attempt"] = attempt
		lv["generated"]["problems"] = probs
		if probs.is_empty():
			return lv
		last = lv
	push_warning("building_gen: %s %d never came out clean: %s" % [type, p_seed, last.get("generated", {}).get("problems", [])])
	return last


# ------------------------------------------------------------------ one try

static func _try(type: String, p_seed: int, attempt: int) -> Dictionary:
	var D := data()
	var T: Dictionary = D.get("types", {}).get(type, {})
	if T.is_empty():
		return {}
	var K: Dictionary = D.get("rooms", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [type, p_seed, attempt])
	var W := _range_i(rng, T["w"])
	var Dp := _range_i(rng, T["d"])
	var x0 := -W * 0.5
	var fr: Array = T.get("front", [0.3, 0.4])
	var fd := clampf(_snap(Dp * rng.randf_range(float(fr[0]), float(fr[1]))), MIN, Dp - MIN)
	var plan: Array = []          # [{kind, rect}]
	# --- the rooms on the street
	_treemap(Rect2(x0, -fd, W, fd), _pick(rng, T.get("front_rooms", []), K), rng, plan)
	# --- behind them: a hall?, a pinned room (the depot's secure store), the rest by treemap
	var mode := _weighted(rng, T.get("corridor", {"none": 1.0}))
	var cw := 2.0 if rng.randf() < 0.6 else 2.5
	var back_d := Dp - fd
	var areas: Array = [Rect2(x0, -Dp, W, back_d)]
	var pinned: Dictionary = T.get("pinned", {})
	if mode == "spine" and pinned.is_empty() and W >= MIN * 2.0 + cw:
		var cx := _snap(rng.randf_range(x0 + MIN, x0 + W - MIN - cw))
		plan.append({"kind": "corridor", "rect": Rect2(cx, -Dp, cw, back_d)})
		areas = [Rect2(x0, -Dp, cx - x0, back_d), Rect2(cx + cw, -Dp, x0 + W - cx - cw, back_d)]
	elif mode == "cross" and back_d >= MIN + cw:
		plan.append({"kind": "corridor", "rect": Rect2(x0, -fd - cw, W, cw)})
		areas = [Rect2(x0, -Dp, W, back_d - cw)]
	if not pinned.is_empty():
		var pw := float(_range_i(rng, pinned["w"]))
		var pd := float(_range_i(rng, pinned["d"]))
		var cut := _carve(rng, areas[0], pw, pd)
		if cut.is_empty():
			return {}
		plan.append({"kind": pinned["kind"], "rect": cut["pin"]})
		areas = cut["rest"]
	var items := _pick(rng, T.get("back_rooms", []), K)
	for group in _share(rng, areas, items, str(T.get("filler", "storeroom"))):
		_treemap(group[0], group[1], rng, plan)
	# --- a wing out the back (an L) and the outside
	var wing := Rect2()
	if rng.randf() < float(T.get("wing", 0.0)):
		var ww := maxf(MIN, _snap(W * rng.randf_range(0.4, 0.6)))
		var wd := _snap(rng.randf_range(MIN + 1.0, 7.0))
		var left := rng.randf() < 0.5
		wing = Rect2(x0 if left else x0 + W - ww, -Dp - wd, ww, wd)
		var wi := _pick(rng, T.get("wing_rooms", []), K)
		if wi.is_empty():
			wi = [{"kind": str(T.get("filler", "storeroom")), "w": 1.0}]
		_treemap(wing, wi, rng, plan)
	var outs := _outside(rng, T, x0, W, Dp, wing)
	# --- name them
	var rooms: Array = []
	var count := {}
	for p in plan:
		count[p["kind"]] = int(count.get(p["kind"], 0)) + 1
	var seen := {}
	for p in plan:
		var k: String = p["kind"]
		seen[k] = int(seen.get(k, 0)) + 1
		var kd: Dictionary = K.get(k, {})
		var id := k if seen[k] == 1 else "%s%d" % [k, seen[k]]
		var nm: String = kd.get("name", k.to_upper())
		if int(count[k]) > 1:
			nm += " " + "ABCDEFGH".substr(int(seen[k]) - 1, 1)
		rooms.append({"id": id, "kind": k, "name": nm, "rect": p["rect"], "outdoor": false})
	for o in outs:
		rooms.append(o)
	# --- doors
	var doors := _doors(rng, T, K, rooms)
	if doors.is_empty():
		return {}
	# --- the level
	var street_name: String = _one(rng, D.get("streets", ["THE STREET"]))
	var bname: String = _one(rng, T.get("names", [str(T.get("name", type)).to_upper()]))
	var lv := {
		"name": "%s, %s" % [bname, street_name.capitalize()],
		"generated": {"type": type, "seed": p_seed, "mode": mode, "wing": wing.has_area()},
		"doctrine": true, "daylight": false,
		"rooms": [], "doors": doors, "lights": [], "cctv": [], "cover": [],
		"squad": Content.get_file("combat/depot").get("squad", []),
	}
	var occ := {}                 # room id -> [Rect2 footprints in world x,z]
	for r in rooms:
		var rc: Rect2 = r["rect"]
		var out := {"id": r["id"], "name": r["name"], "kind": r.get("kind", ""), "rect": [rc.position.x, rc.position.y, rc.end.x, rc.end.y]}
		if r["outdoor"]:
			out["outdoor"] = true
			out["lamps"] = 0
		else:
			var kd: Dictionary = K.get(r["kind"], {})
			out["lamp_energy"] = float(kd.get("lamp_energy", 2.0))
			occ[r["id"]] = []
			out["dress"] = _dress(rng, kd, rc, doors, occ[r["id"]])
		lv["rooms"].append(out)
	_objective(lv, T, K, rooms, occ)
	_cctv(rng, lv, T, rooms)
	_outside_dress(rng, lv, rooms, doors)
	_people(rng, lv, T, K, rooms, doors, occ, p_seed)
	_plan(lv, T, rooms, doors, bname, street_name)
	return lv


# ------------------------------------------------------------------ zones and the treemap

## Optional rooms by chance, weights as floor area.
static func _pick(rng: RandomNumberGenerator, list: Array, _K: Dictionary) -> Array:
	var out: Array = []
	for it in list:
		if rng.randf() < float(it.get("chance", 1.0)):
			out.append({"kind": it["kind"], "w": float(it.get("w", 1.0)) * rng.randf_range(0.85, 1.15),
				"must": it.get("must", false), "entry": it.get("entry", false)})
	# shuffle (the treemap keeps order, so order = where things end up)
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Ordered treemap: split the items into two groups of about equal weight, cut the rect across its long side
## in that ratio, recurse. A rect too small for two rooms goes whole to its most important item.
static func _treemap(rect: Rect2, items: Array, rng: RandomNumberGenerator, out: Array) -> void:
	if items.is_empty():
		return
	if items.size() == 1:
		out.append({"kind": items[0]["kind"], "rect": rect})
		return
	var horiz := rect.size.x >= rect.size.y
	var long := rect.size.x if horiz else rect.size.y
	if long < MIN * 2.0 - EPS:
		var best: Dictionary = items[0]
		for it in items:
			if (it["must"] and not best["must"]) or (it["must"] == best["must"] and float(it["w"]) > float(best["w"])):
				best = it
		out.append({"kind": best["kind"], "rect": rect})
		for it in items:
			if it != best and it["must"]:
				out.append({"kind": it["kind"], "rect": Rect2(), "lost": true})     # check() will reject this try
		return
	var total := 0.0
	for it in items:
		total += float(it["w"])
	var k := 1
	var bd := 1e9
	var acc := 0.0
	for i in range(1, items.size()):
		acc += float(items[i - 1]["w"])
		var dd := absf(acc / total - 0.5)
		if dd < bd:
			bd = dd
			k = i
	var a_items := items.slice(0, k)
	var b_items := items.slice(k)
	var aw := 0.0
	for it in a_items:
		aw += float(it["w"])
	var cut := clampf(_snap(long * aw / total + rng.randf_range(-0.5, 0.5)), MIN, long - MIN)
	var ra: Rect2
	var rb: Rect2
	if horiz:
		ra = Rect2(rect.position, Vector2(cut, rect.size.y))
		rb = Rect2(rect.position.x + cut, rect.position.y, rect.size.x - cut, rect.size.y)
	else:
		ra = Rect2(rect.position, Vector2(rect.size.x, cut))
		rb = Rect2(rect.position.x, rect.position.y + cut, rect.size.x, rect.size.y - cut)
	_treemap(ra, a_items, rng, out)
	_treemap(rb, b_items, rng, out)


## Hand the back rooms out over several areas by size; an area nobody got becomes the filler room.
static func _share(rng: RandomNumberGenerator, areas: Array, items: Array, filler: String) -> Array:
	var total_a := 0.0
	for a in areas:
		total_a += (a as Rect2).get_area()
	var total_w := 0.0
	for it in items:
		total_w += float(it["w"])
	var groups: Array = []
	var room_left: Array = []
	for a in areas:
		groups.append([a, []])
		room_left.append((a as Rect2).get_area() / maxf(total_a, 1.0) * total_w)
	var sorted := items.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["w"]) > float(q["w"]))
	for it in sorted:
		var bi := 0
		for i in groups.size():
			if float(room_left[i]) > float(room_left[bi]):
				bi = i
		groups[bi][1].append(it)
		room_left[bi] = float(room_left[bi]) - float(it["w"])
	for g in groups:
		if (g[1] as Array).is_empty():
			g[1].append({"kind": filler, "w": 1.0, "must": false, "entry": false})
		else:
			var arr: Array = g[1]
			for i in range(arr.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t = arr[i]
				arr[i] = arr[j]
				arr[j] = t
	return groups


## Cut a w x d room out of an area's back edge, leaving strips either empty or a full room wide.
static func _carve(rng: RandomNumberGenerator, area: Rect2, pw: float, pd: float) -> Dictionary:
	if area.size.x < pw - EPS:
		return {}
	var opts: Array = [area.position.x, area.end.x - pw]
	var lo := area.position.x + MIN
	var hi := area.end.x - pw - MIN
	if hi >= lo:
		opts.append(_snap(rng.randf_range(lo, hi)))
	var px: float = opts[rng.randi() % opts.size()]
	var dep := pd if area.size.y - pd >= MIN else area.size.y
	var rest: Array = []
	if px - area.position.x > EPS:
		rest.append(Rect2(area.position.x, area.position.y, px - area.position.x, area.size.y))
	if area.end.x - (px + pw) > EPS:
		rest.append(Rect2(px + pw, area.position.y, area.end.x - px - pw, area.size.y))
	if area.size.y - dep > EPS:
		rest.append(Rect2(px, area.position.y + dep, pw, area.size.y - dep))
	for r in rest:
		if (r as Rect2).size.x < MIN - EPS or (r as Rect2).size.y < MIN - EPS:
			return {}
	if rest.is_empty():
		return {}
	return {"pin": Rect2(px, area.position.y, pw, dep), "rest": rest}


## The street in front, a side passage, an alley behind, a yard in the L or behind.
static func _outside(rng: RandomNumberGenerator, T: Dictionary, x0: float, W: float, Dp: float, wing: Rect2) -> Array:
	var depth := Dp
	var yard := Rect2()
	if wing.has_area():
		depth = Dp + wing.size.y
		if rng.randf() < float(T.get("yard", 0.5)) + 0.3:
			var yx := x0 + wing.size.x if is_equal_approx(wing.position.x, x0) else x0
			yard = Rect2(yx, -depth, W - wing.size.x, wing.size.y)
	elif rng.randf() < float(T.get("yard", 0.5)):
		var yd := _snap(rng.randf_range(5.0, 8.0))
		yard = Rect2(x0, -Dp - yd, W, yd)
		depth = Dp + yd
	var left := rng.randf() < 0.5
	var pw := 2.5
	var out: Array = []
	out.append({"id": "street", "name": "THE STREET", "rect": Rect2(x0 - 8.0, 0.0, W + 16.0, 9.0), "outdoor": true})
	var px := x0 - pw if left else x0 + W
	out.append({"id": "passage", "name": "SIDE PASSAGE", "rect": Rect2(px, -depth, pw, depth), "outdoor": true})
	out.append({"id": "alley", "name": "THE ALLEY", "rect": Rect2(x0 if not left else x0 - pw, -depth - 3.0, W + (pw if left else 0.0), 3.0), "outdoor": true})
	if yard.has_area():
		out.append({"id": "yard", "name": "THE YARD", "rect": yard, "outdoor": true})
	return out


# ------------------------------------------------------------------ doors

## The shared wall between two rects: {axis: "x" (a wall at constant x) | "z", at, lo, hi}.
static func _shared(a: Rect2, b: Rect2) -> Dictionary:
	for pair in [[a.end.x, b.position.x], [b.end.x, a.position.x]]:
		if absf(float(pair[0]) - float(pair[1])) < EPS:
			var lo := maxf(a.position.y, b.position.y)
			var hi := minf(a.end.y, b.end.y)
			if hi - lo > EPS:
				return {"axis": "x", "at": float(pair[0]), "lo": lo, "hi": hi}
	for pair in [[a.end.y, b.position.y], [b.end.y, a.position.y]]:
		if absf(float(pair[0]) - float(pair[1])) < EPS:
			var lo2 := maxf(a.position.x, b.position.x)
			var hi2 := minf(a.end.x, b.end.x)
			if hi2 - lo2 > EPS:
				return {"axis": "z", "at": float(pair[0]), "lo": lo2, "hi": hi2}
	return {}


## Which wall of a room a shared line is: n (z min), s (z max), w (x min), e (x max).
static func _wall_of(rc: Rect2, s: Dictionary) -> String:
	if s["axis"] == "x":
		return "w" if absf(float(s["at"]) - rc.position.x) < EPS else "e"
	return "n" if absf(float(s["at"]) - rc.position.y) < EPS else "s"


static func _wall_ok(K: Dictionary, r: Dictionary, s: Dictionary) -> bool:
	if r["outdoor"]:
		return true
	var allowed: Array = K.get(r["kind"], {}).get("door_walls", [])
	return allowed.is_empty() or allowed.has(_wall_of(r["rect"], s))


## A spot on a shared wall for a door w wide, clear of the corners and of other doors on that line.
static func _door_spot(rng: RandomNumberGenerator, s: Dictionary, w: float, doors: Array, keep_lo := 0.0) -> float:
	var lo := float(s["lo"]) + 0.7 + w * 0.5 + keep_lo
	var hi := float(s["hi"]) - 0.7 - w * 0.5
	if hi < lo - EPS:
		return NAN
	for _i in 8:
		var c := _snap(lerpf(lo, hi, rng.randf_range(0.25, 0.75))) if hi - lo > 1.0 else (lo + hi) * 0.5
		c = clampf(c, lo, hi)
		var ok := true
		for d in doors:
			if d["axis"] != s["axis"]:
				continue
			var dp: Array = d["pos"]
			var at := float(dp[0]) if s["axis"] == "x" else float(dp[1])
			var along := float(dp[1]) if s["axis"] == "x" else float(dp[0])
			if absf(at - float(s["at"])) < EPS and absf(along - c) < (w + float(d.get("w", 1.0))) * 0.5 + 0.9:
				ok = false
				break
		if ok:
			return c
	return NAN


static func _make_door(id: String, nm: String, s: Dictionary, c: float, a: String, b: String, w := 1.0, arch := false, locked := false) -> Dictionary:
	var pos := [float(s["at"]), c] if s["axis"] == "x" else [c, float(s["at"])]
	var d := {"id": id, "name": nm, "pos": pos, "axis": s["axis"], "a": a, "b": b, "locked": locked}
	if arch:
		d["arch"] = true
		d["w"] = w
	return d


## The front door, a spanning tree of inside doors by each room's links, a loop or two, a back door and
## sometimes a side door. [] if the rooms can't all be joined.
static func _doors(rng: RandomNumberGenerator, T: Dictionary, K: Dictionary, rooms: Array) -> Array:
	var doors: Array = []
	var by_id := {}
	var indoor: Array = []
	for r in rooms:
		by_id[r["id"]] = r
		if not r["outdoor"]:
			if (r["rect"] as Rect2).has_area():
				indoor.append(r)
	# the front door: into the entry room, off the street
	var entry: Dictionary = {}
	for r in indoor:
		if _is_entry(T, r) and (entry.is_empty() or (r["rect"] as Rect2).get_area() > (entry["rect"] as Rect2).get_area()):
			entry = r
	if entry.is_empty():
		return []
	var fs := _shared(by_id["street"]["rect"], entry["rect"])
	if fs.is_empty():
		return []
	var fc := _door_spot(rng, fs, 1.0, doors)
	if is_nan(fc):
		return []
	var front := _make_door("front", "FRONT DOOR", fs, fc, "street", entry["id"])
	front["at"] = {"night": {"locked": true}}
	doors.append(front)
	# inside: grow from the entry room
	var joined := {entry["id"]: true}
	var links := {}           # "a|b" -> true
	var guard := 0
	while joined.size() < indoor.size() and guard < 200:
		guard += 1
		var best := {}
		var bs := -1e9
		for relaxed in [false, true]:
			for c in indoor:
				if not joined.has(c["id"]):
					continue
				var ck: Dictionary = K.get(c["kind"], {})
				if ck.get("deadend", false) and not relaxed:
					continue
				for u in indoor:
					if joined.has(u["id"]):
						continue
					var s := _shared(c["rect"], u["rect"])
					if s.is_empty() or float(s["hi"]) - float(s["lo"]) < 2.4:
						continue
					if not _wall_ok(K, c, s) or not _wall_ok(K, u, s):
						continue
					var uk: Dictionary = K.get(u["kind"], {})
					var sc := rng.randf() * 0.8
					if ck.get("circulation", false):
						sc += 2.5
					if (uk.get("links", []) as Array).has(c["kind"]) or (ck.get("links", []) as Array).has(u["kind"]):
						sc += 3.0
					if uk.get("circulation", false):
						sc += 1.0
					if sc > bs:
						bs = sc
						best = {"c": c, "u": u, "s": s}
			if not best.is_empty():
				break
		if best.is_empty():
			return []
		var c2: Dictionary = best["c"]
		var u2: Dictionary = best["u"]
		if not _join(rng, K, doors, c2, u2, best["s"]):
			return []
		joined[u2["id"]] = true
		links[c2["id"] + "|" + u2["id"]] = true
		links[u2["id"] + "|" + c2["id"]] = true
	if joined.size() < indoor.size():
		return []
	# loops: a second way round
	var lr: Array = T.get("loops", [0, 1])
	var n_loops := rng.randi_range(int(lr[0]), int(lr[1]))
	var cands: Array = []
	for i in indoor.size():
		for j in range(i + 1, indoor.size()):
			var a: Dictionary = indoor[i]
			var b: Dictionary = indoor[j]
			if links.has(a["id"] + "|" + b["id"]):
				continue
			if K.get(a["kind"], {}).get("deadend", false) or K.get(b["kind"], {}).get("deadend", false):
				continue
			var s := _shared(a["rect"], b["rect"])
			if s.is_empty() or float(s["hi"]) - float(s["lo"]) < 2.4 or not _wall_ok(K, a, s) or not _wall_ok(K, b, s):
				continue
			cands.append([a, b, s])
	for _i in n_loops:
		if cands.is_empty():
			break
		var pick: Array = cands.pop_at(rng.randi() % cands.size())
		_join(rng, K, doors, pick[0], pick[1], pick[2])
	# the back door (and a roller door on a loading bay), maybe a side door
	var backs: Array = []
	for r in indoor:
		for o in rooms:
			if not o["outdoor"] or o["id"] == "street":
				continue
			var s := _shared(r["rect"], o["rect"])
			if s.is_empty() or float(s["hi"]) - float(s["lo"]) < 2.4 or not _wall_ok(K, r, s):
				continue
			var rk: Dictionary = K.get(r["kind"], {})
			if rk.get("deadend", false):
				continue
			var sc := rng.randf()
			if rk.get("back_door", false):
				sc += 2.0
			if rk.get("circulation", false):
				sc += 1.5
			if o["id"] == "passage":
				sc -= 1.0
			backs.append([sc, r, o, s])
	backs.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var used := {}
	var n_ext := 0
	for bk in backs:
		var r: Dictionary = bk[1]
		var o: Dictionary = bk[2]
		if used.has(r["id"]) or (n_ext >= 1 and rng.randf() > 0.4) or n_ext >= 2:
			continue
		var roller: bool = K.get(r["kind"], {}).get("roller", false)
		var w := 3.0 if roller else 1.0
		var c := _door_spot(rng, bk[3], w, doors)
		if is_nan(c):
			continue
		var nm := "ROLLER DOOR" if roller else ("SIDE DOOR" if o["id"] == "passage" else "BACK DOOR")
		var d := _make_door("ext%d" % n_ext, nm, bk[3], c, o["id"], r["id"], w, roller, not roller and rng.randf() < float(T.get("back_locked", 0.55)))
		doors.append(d)
		used[r["id"]] = true
		n_ext += 1
	if n_ext == 0:
		return []
	return doors


static func _is_entry(T: Dictionary, r: Dictionary) -> bool:
	for it in T.get("front_rooms", []):
		if it["kind"] == r["kind"] and it.get("entry", false):
			return true
	return false


## A door (or a wide opening between two open rooms) on the wall between c and u, swinging into u.
static func _join(rng: RandomNumberGenerator, K: Dictionary, doors: Array, c: Dictionary, u: Dictionary, s: Dictionary) -> bool:
	var ck: Dictionary = K.get(c["kind"], {})
	var uk: Dictionary = K.get(u["kind"], {})
	var arch: bool = ck.get("open", false) and uk.get("open", false)
	var span := float(s["hi"]) - float(s["lo"])
	var w := 1.0
	if arch:
		w = clampf(_snap(rng.randf_range(2.0, 3.5)), 1.5, span - 1.6)
	var keep := 0.0
	if u["kind"] == "vault" and _wall_of(u["rect"], s) == "s":
		keep = maxf(0.0, (u["rect"] as Rect2).position.x + 2.0 - float(s["lo"]))     # clear of the PC desk on its left wall
	var at := _door_spot(rng, s, w, doors, keep)
	if is_nan(at):
		return false
	var locked: bool = not arch and rng.randf() < float(uk.get("locked", 0.0))
	var nm: String = "%s DOOR" % str(u["name"]) if not arch else "OPENING TO %s" % str(u["name"])
	doors.append(_make_door("d%d" % doors.size(), nm, s, at, c["id"], u["id"], w, arch, locked))
	return true


# ------------------------------------------------------------------ dressing

## Furniture against the walls (and free-standing), never in front of a door, never on top of each other.
static func _dress(rng: RandomNumberGenerator, kd: Dictionary, rc: Rect2, doors: Array, occ: Array) -> Array:
	var out: Array = []
	# keep door mouths clear
	for d in doors:
		var dp: Array = d["pos"]
		var p := Vector2(float(dp[0]), float(dp[1]))
		var w := float(d.get("w", 1.0))
		if d["axis"] == "x" and absf(p.x - rc.position.x) > EPS and absf(p.x - rc.end.x) > EPS:
			continue
		if d["axis"] == "z" and absf(p.y - rc.position.y) > EPS and absf(p.y - rc.end.y) > EPS:
			continue
		if d["axis"] == "x":
			if p.y < rc.position.y - EPS or p.y > rc.end.y + EPS:
				continue
			occ.append(Rect2(p.x - 1.3, p.y - w * 0.5 - 0.45, 2.6, w + 0.9))
		else:
			if p.x < rc.position.x - EPS or p.x > rc.end.x + EPS:
				continue
			occ.append(Rect2(p.x - w * 0.5 - 0.45, p.y - 1.3, w + 0.9, 2.6))
	var walls := ["n", "s", "w", "e"]
	for spec in kd.get("dress", []):
		var nr: Array = spec.get("n", [1, 1])
		var n := rng.randi_range(int(nr[0]), int(nr[1]))
		var kit: String = spec["kit"]
		var depth: float = Level.KIT_DEPTH.get(kit, 0.6)
		var width: float = Level.KIT_WIDTH.get(kit, 0.6)
		for _k in n:
			for _try_i in 14:
				if spec.get("center", false):
					var fc := Rect2(rc.get_center() - Vector2(width, depth) * 0.5, Vector2(width, depth))
					if _free(fc, occ):
						occ.append(fc.grow(0.3))
						out.append({"kit": kit, "center": true, "turn": 90 if rc.size.y > rc.size.x else 0})
					break
				if spec.get("spot", false):
					var mx := rc.size.x - width - 2.4
					var mz := rc.size.y - depth - 2.4
					if mx <= 0.0 or mz <= 0.0:
						break
					var cx := rc.position.x + 1.2 + width * 0.5 + rng.randf() * mx
					var cz := rc.position.y + 1.2 + depth * 0.5 + rng.randf() * mz
					var f := Rect2(cx - width * 0.5, cz - depth * 0.5, width, depth)
					if _free(f.grow(0.5), occ):
						occ.append(f.grow(0.45))
						out.append({"kit": kit, "spot": [(cx - rc.position.x) / rc.size.x, (cz - rc.position.y) / rc.size.y], "turn": [0, 90, 180, 270][rng.randi() % 4] if kit != "cafe_table" else [0, 90][rng.randi() % 2]})
						break
					continue
				var wall: String = walls[rng.randi() % 4]
				var along_len := rc.size.x if wall in ["n", "s"] else rc.size.y
				if along_len < width + 0.4:
					continue
				var along := width * 0.5 + 0.1 + rng.randf() * (along_len - width - 0.2)
				var f2 := _foot(rc, wall, along, width, depth)
				if _free(f2, occ):
					occ.append(f2.grow(0.15))
					out.append({"kit": kit, "wall": wall, "at": along / along_len})
					break
	return out


static func _foot(rc: Rect2, wall: String, along: float, width: float, depth: float) -> Rect2:
	match wall:
		"n":
			return Rect2(rc.position.x + along - width * 0.5, rc.position.y + WALL_IN, width, depth)
		"s":
			return Rect2(rc.position.x + along - width * 0.5, rc.end.y - WALL_IN - depth, width, depth)
		"w":
			return Rect2(rc.position.x + WALL_IN, rc.position.y + along - width * 0.5, depth, width)
	return Rect2(rc.end.x - WALL_IN - depth, rc.position.y + along - width * 0.5, depth, width)


static func _free(f: Rect2, occ: Array) -> bool:
	for o in occ:
		if f.intersects(o):
			return false
	return true


## A free spot in a room (off the furniture, off the doors), or the centre if there isn't one.
static func _spot(rng: RandomNumberGenerator, rc: Rect2, occ: Array, margin := 0.8) -> Vector2:
	var inner := rc.grow(-margin)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return rc.get_center()
	for _i in 30:
		var p := Vector2(inner.position.x + rng.randf() * inner.size.x, inner.position.y + rng.randf() * inner.size.y)
		if _free(Rect2(p - Vector2(0.45, 0.45), Vector2(0.9, 0.9)), occ):
			occ.append(Rect2(p - Vector2(0.5, 0.5), Vector2(1.0, 1.0)))
			return p
	return rc.get_center()


# ------------------------------------------------------------------ what you came for, the outside, the people

static func _objective(lv: Dictionary, T: Dictionary, _K: Dictionary, rooms: Array, occ: Dictionary) -> void:
	var ob: Dictionary = T.get("objective", {})
	var want: Array = ob.get("kinds", [])
	for r in rooms:
		if r["outdoor"] or not want.has(r["kind"]):
			continue
		var rc: Rect2 = r["rect"]
		var p := rc.get_center()
		if r["kind"] == "vault":
			p = Vector2(rc.position.x + 0.6, rc.position.y + 3.2)          # the control PC on its left wall (v2/combat/vault_room.gd)
			lv["marks"] = {"vault": r["id"], "pc": [p.x, p.y]}
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(r["id"])
			p = _spot(rng, rc, occ[r["id"]], 1.0)
		lv["objective"] = {"text": ob.get("text", "Get what we came for"), "room": r["id"], "pos": [p.x, p.y]}
		return


## Cameras high in a corner of the biggest watched rooms (halls, floors, front desks), looking across.
static func _cctv(rng: RandomNumberGenerator, lv: Dictionary, T: Dictionary, rooms: Array) -> void:
	var n := int(T.get("cctv", 0))
	if n <= 0:
		return
	var watched := ["corridor", "warehouse", "loading", "reception", "front_desk", "shopfloor", "squad_room", "open_office", "barroom"]
	var cands: Array = rooms.filter(func(r: Dictionary) -> bool: return not r["outdoor"] and watched.has(r["kind"]))
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["rect"] as Rect2).get_area() > (b["rect"] as Rect2).get_area())
	for i in mini(n, cands.size()):
		var rc: Rect2 = (cands[i]["rect"] as Rect2).grow(-0.3)
		var corners := [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]
		var k := rng.randi() % 4
		var c: Vector2 = corners[k]
		var far: Vector2 = corners[(k + 2) % 4]
		var look := c.lerp(far, 0.7)
		lv["cctv"].append({"id": "CCTV-%02d" % (rng.randi_range(1, 30) + i * 31), "label": str(cands[i]["name"]),
			"pos": [snappedf(c.x, 0.01), 2.5, snappedf(c.y, 0.01)], "look": [snappedf(look.x, 0.01), 0.8, snappedf(look.y, 0.01)]})


## Street lamps over the doors, a parked car, junk in the yard and the alley to hide behind.
static func _outside_dress(rng: RandomNumberGenerator, lv: Dictionary, rooms: Array, doors: Array) -> void:
	var ext: Array = []
	for d in doors:
		var a: String = d["a"]
		for r in rooms:
			if r["id"] == a and r["outdoor"]:
				var p := Vector2(float(d["pos"][0]), float(d["pos"][1]))
				ext.append(p)
				var lp := p + _out_normal(d, r["rect"]) * 0.9
				lv["lights"].append({"pos": [lp.x, lp.y], "energy": 0.9, "flicker": rng.randf() < 0.3, "color": [1.0, 0.82, 0.55]})
	var taken: Array = []
	for e in ext:
		taken.append(Rect2(e - Vector2(2.6, 2.6), Vector2(5.2, 5.2)))
	for r in rooms:
		if not r["outdoor"]:
			continue
		var rc: Rect2 = r["rect"]
		var tries: Array = []
		match r["id"]:
			"street":
				tries = [["car", 0.7], ["car", 0.35], ["barrel", 0.5], ["crate", 0.4], ["low_wall", 0.3]]
			"yard":
				tries = [["crate", 0.9], ["crate", 0.6], ["barrel", 0.7], ["barrel", 0.4], ["low_wall", 0.5], ["car", 0.25]]
			"alley":
				tries = [["barrel", 0.6], ["crate", 0.5]]
			_:
				tries = [["barrel", 0.4]]
		for t in tries:
			if rng.randf() > float(t[1]):
				continue
			var kind: String = t[0]
			var sz := Vector2(4.4, 2.0) if kind == "car" else Vector2(3.0, 0.4) if kind == "low_wall" else Vector2(1.0, 1.0)
			var turn := 0.0
			var inner := rc.grow(-1.2)
			if rc.size.y > rc.size.x:
				turn = 90.0
				sz = Vector2(sz.y, sz.x)
			if r["id"] == "street":
				inner = Rect2(rc.position.x + 1.0, rc.position.y + 4.0, rc.size.x - 2.0, 3.6)    # across the road from the door
			for _i in 12:
				var p := Vector2(inner.position.x + rng.randf() * maxf(0.0, inner.size.x), inner.position.y + rng.randf() * maxf(0.0, inner.size.y))
				var f := Rect2(p - sz * 0.5, sz).grow(0.6)
				if _free(f, taken):
					taken.append(f)
					lv["cover"].append({"kind": kind, "pos": [snappedf(p.x, 0.1), snappedf(p.y, 0.1)], "turn": turn + rng.randf_range(-8.0, 8.0)})
					break


## Guard posts per room (more than you'll ever have guards, the depot raid rolls its own), the guards, the people.
static func _people(rng: RandomNumberGenerator, lv: Dictionary, T: Dictionary, K: Dictionary, rooms: Array, doors: Array, occ: Dictionary, p_seed: int) -> void:
	var posts: Array = []
	var civ_spots: Array = []
	for r in rooms:
		if r["outdoor"]:
			continue
		var kd: Dictionary = K.get(r["kind"], {})
		var rc: Rect2 = r["rect"]
		var into := _door_into(r, doors)
		var gw := float(kd.get("guard", 0.0))
		if kd.get("patrol", false) and gw > 0.0:
			var a := rc.grow(-0.9)
			var p0 := Vector2(a.position.x, a.get_center().y) if rc.size.x >= rc.size.y else Vector2(a.get_center().x, a.position.y)
			var p1 := Vector2(a.end.x, a.get_center().y) if rc.size.x >= rc.size.y else Vector2(a.get_center().x, a.end.y)
			posts.append({"pos": [p0.x, p0.y], "yaw": _yaw(p0, p1), "state": "patrol", "patrol": [[p0.x, p0.y], [p1.x, p1.y]], "room": r["id"], "w": gw})
		var n_posts := int(ceil(gw)) + (1 if rc.get_area() > 30.0 and gw >= 1.0 else 0)
		for _i in n_posts:
			var p := _spot(rng, rc, occ[r["id"]])
			var post := {"pos": [p.x, p.y], "yaw": _yaw(p, into), "state": "idle", "room": r["id"], "w": gw}
			if kd.get("timid", false):
				post["timid"] = true
			posts.append(post)
		var cw := float(kd.get("civ", 0.0))
		for _i in int(ceil(cw)):
			var p2 := _spot(rng, rc, occ[r["id"]], 0.7)
			var names: Array = kd.get("civ_name", ["someone"])
			civ_spots.append({"pos": [p2.x, p2.y], "yaw": rng.randf_range(-PI, PI), "room": r["id"], "name": names[rng.randi() % names.size()],
				"always": kd.get("civ_always", false), "w": cw})
		if kd.get("alarm", false):
			# the alarm box: on the wall furthest from the room's door
			var c := rc.get_center()
			var far := Vector2(rc.position.x + 0.35 if into.x > c.x else rc.end.x - 0.35, c.y)
			lv["marks"] = lv.get("marks", {})
			lv["marks"]["alarm"] = [far.x, far.y]
	# weighted order: the busiest posts first
	for p in posts:
		p["key"] = float(p["w"]) + rng.randf() * 1.5
	posts.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["key"]) > float(q["key"]))
	for p in posts:
		p.erase("key")
	lv["posts"] = posts
	# guards for a standalone raid: the busy hour has them all, the quiet hour fewer
	var gr: Array = T.get("guards", [2, 3])
	var ng := mini(rng.randi_range(int(gr[0]), int(gr[1])), posts.size())
	var nr: Array = T.get("night_guards", [1, 2])
	var n_night := mini(rng.randi_range(int(nr[0]), int(nr[1])), ng)
	var ar: Array = T.get("acc", [0.6, 0.8])
	var titles: Array = T.get("guard_title", ["guard"])
	var hours: Array = T.get("hours", [])
	var has_day := hours.any(func(h: Dictionary) -> bool: return h["id"] == "day")
	var shotguns := 0
	for i in ng:
		var post: Dictionary = posts[i]
		var wpn := _weighted(rng, T.get("weapons", {"pistol": 1}))
		if wpn == "pump_shotgun":
			shotguns += 1
			if shotguns > 1:
				wpn = "pistol"      # one shotgun a building: a room of them is a wipe through the only door

		var person := People.make(hash("%d:%s:g%d" % [p_seed, str(T.get("name", "")), i]), "guard")
		var e := {"id": "g%d" % i, "name": "%s %s" % [titles[rng.randi() % titles.size()], person["last"]], "kind": "guard",
			"pos": post["pos"], "yaw": post["yaw"], "state": post["state"], "camo": _one(rng, T.get("camo", ["black"])), "head": _one(rng, T.get("head", ["cap"])),
			"acc_mult": snappedf(rng.randf_range(float(ar[0]), float(ar[1])), 0.01),
			"gear": {"weapon": wpn, "round": "fmj", "attach": [], "plate": 1 if rng.randf() < 0.25 else 0, "mags": 4, "meds": 0}}
		if post.has("patrol"):
			e["patrol"] = post["patrol"]
		if post.get("timid", false):
			e["timid"] = true
		if has_day and i >= n_night:
			e["hours"] = ["day"]
		lv["enemies"] = lv.get("enemies", [])
		lv["enemies"].append(e)
	if not lv.has("enemies"):
		lv["enemies"] = []
	# people who aren't fighters: the busy hour only, except the ones locked up
	var cr: Array = T.get("civilians", [0, 0])
	var nc := mini(rng.randi_range(int(cr[0]), int(cr[1])), civ_spots.size())
	for s in civ_spots:
		s["key"] = float(s["w"]) + rng.randf() * 2.0
	civ_spots.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["key"]) > float(q["key"]))
	var civs: Array = []
	for i in nc:
		var s: Dictionary = civ_spots[i]
		var c := {"id": "p%d" % i, "name": s["name"], "pos": s["pos"], "yaw": s["yaw"], "camo": _one(rng, ["street", "denim", "navy", "regime_low", "street"])}
		if has_day and not s["always"]:
			c["hours"] = ["day"]
		civs.append(c)
	lv["civilians"] = civs


## The point where a room's first door is (guards face the way in).
static func _door_into(r: Dictionary, doors: Array) -> Vector2:
	for d in doors:
		if d["b"] == r["id"] or d["a"] == r["id"]:
			return Vector2(float(d["pos"][0]), float(d["pos"][1]))
	return (r["rect"] as Rect2).get_center() + Vector2(0, 1)


## Unit vector from a door out into the open ground `rc` it opens onto.
static func _out_normal(d: Dictionary, rc: Rect2) -> Vector2:
	var p := Vector2(float(d["pos"][0]), float(d["pos"][1]))
	if d["axis"] == "x":
		return Vector2(1, 0) if rc.get_center().x > p.x else Vector2(-1, 0)
	return Vector2(0, 1) if rc.get_center().y > p.y else Vector2(0, -1)


## Actor yaw that faces from p toward q (yaw PI faces +z).
static func _yaw(p: Vector2, q: Vector2) -> float:
	var d := q - p
	if d.length() < 0.01:
		return PI
	return snappedf(atan2(-d.x, -d.y), 0.01)


## The plan sheet: the hours, a way in per outside door (3.5 m out from it), the brief.
static func _plan(lv: Dictionary, T: Dictionary, rooms: Array, doors: Array, bname: String, street: String) -> void:
	var entries: Array = []
	var by_id := {}
	for r in rooms:
		by_id[r["id"]] = r
	for d in doors:
		var o: Dictionary = by_id.get(d["a"], {})
		if o.is_empty() or not o["outdoor"]:
			continue
		var p := Vector2(float(d["pos"][0]), float(d["pos"][1]))
		var sp := p + _out_normal(d, o["rect"]) * 3.5
		var inside: String = by_id[d["b"]]["name"]
		var title := "THE FRONT DOOR" if d["id"] == "front" else str(d["name"])
		var line := "Straight in off the street, into the %s." % inside.to_lower() if d["id"] == "front" else \
			"Round the %s to the %s, into the %s.%s" % [str(o["name"]).to_lower().replace("the ", ""), str(d["name"]).to_lower(), inside.to_lower(), " Locked." if d.get("locked", false) else ""]
		entries.append({"id": str(d["id"]), "title": title, "line": line, "pos": [snappedf(sp.x, 0.1), snappedf(sp.y, 0.1)]})
	lv["start"] = {"pos": entries[0]["pos"] if not entries.is_empty() else [0.0, 4.0], "facing": 0.0}
	lv["plan"] = {"title": bname, "brief": str(T.get("brief", "")).format({"name": bname, "street": street.capitalize()}),
		"hours": T.get("hours", []), "entries": entries}


# ------------------------------------------------------------------ the check

## What's wrong with a level (empty = fine): overlapping or tiny rooms, doors off their walls, rooms you
## can't reach from the street, the thing you came for missing.
static func check(lv: Dictionary) -> Array:
	var probs: Array = []
	var K: Dictionary = data().get("rooms", {})
	var rects := {}
	var out := {}
	for r in lv.get("rooms", []):
		var a: Array = r["rect"]
		var rc := Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))
		rects[r["id"]] = rc
		out[r["id"]] = r.get("outdoor", false)
		if r.get("outdoor", false):
			continue
		var kd: Dictionary = K.get(r.get("kind", ""), {})
		var mn := 1.9 if kd.get("circulation", false) else MIN - EPS
		if minf(rc.size.x, rc.size.y) < mn:
			probs.append("%s too small %s" % [r["id"], rc.size])
		var asp := maxf(rc.size.x, rc.size.y) / maxf(0.1, minf(rc.size.x, rc.size.y))
		if not kd.get("circulation", false) and not kd.get("long_ok", false) and asp > 3.4:
			probs.append("%s too long %.1f" % [r["id"], asp])
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a2: Rect2 = rects[ids[i]]
			var b2: Rect2 = rects[ids[j]]
			if a2.intersection(b2).get_area() > 0.05:
				probs.append("overlap %s %s" % [ids[i], ids[j]])
	var adj := {}
	for id in ids:
		adj[id] = []
	for d in lv.get("doors", []):
		if not rects.has(d["a"]) or not rects.has(d["b"]):
			probs.append("door %s to nowhere" % d["id"])
			continue
		var s := _shared(rects[d["a"]], rects[d["b"]])
		var dp: Array = d["pos"]
		var along := float(dp[1]) if d["axis"] == "x" else float(dp[0])
		var at := float(dp[0]) if d["axis"] == "x" else float(dp[1])
		if s.is_empty() or s["axis"] != d["axis"] or absf(float(s["at"]) - at) > EPS or along < float(s["lo"]) + 0.5 or along > float(s["hi"]) - 0.5:
			probs.append("door %s off its wall" % d["id"])
		adj[d["a"]].append(d["b"])
		adj[d["b"]].append(d["a"])
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if out[ids[i]] and out[ids[j]] and (rects[ids[i]] as Rect2).grow(0.05).intersects(rects[ids[j]]):
				adj[ids[i]].append(ids[j])
				adj[ids[j]].append(ids[i])
	var seen := {"street": true}
	var q: Array = ["street"]
	while not q.is_empty():
		var c: String = q.pop_front()
		for n in adj.get(c, []):
			if not seen.has(n):
				seen[n] = true
				q.append(n)
	for id in ids:
		if not seen.has(id):
			probs.append("%s can't be reached" % id)
	var ob: Dictionary = lv.get("objective", {})
	if ob.is_empty() or not rects.has(ob.get("room", "")):
		probs.append("no objective room")
	if (lv.get("plan", {}).get("entries", []) as Array).size() < 2:
		probs.append("only one way in")
	return probs


# ------------------------------------------------------------------ small helpers

static func _snap(v: float) -> float:
	return snappedf(v, GRID)


static func _range_i(rng: RandomNumberGenerator, r: Array) -> int:
	return rng.randi_range(int(r[0]), int(r[1]))


static func _one(rng: RandomNumberGenerator, a: Array):
	return a[rng.randi() % a.size()]


static func _weighted(rng: RandomNumberGenerator, w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	var roll := rng.randf() * total
	for k in w:
		roll -= float(w[k])
		if roll <= 0.0:
			return str(k)
	return str(w.keys()[0])
