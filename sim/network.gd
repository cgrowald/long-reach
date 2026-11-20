extends RefCounted
## The enemy network (M7): named people and their cells, linked in a hierarchy.
## One leader (the Emir), four lieutenants (one per branch), cells under each. Every node
## has a size (1-3, how much enemy presence it adds to its region), an intel level
## (0-100: how much we know), and a status. Pure rules + state; saved with the world.
## Data: data/network.json.

const GameData := preload("res://sim/game_data.gd")
const DATA_PATH := "res://data/network.json"
const REGIONS_PATH := "res://data/regions.json"
const MAX_SIZE := 3
const MAX_TANGOS := 10

var nodes: Array = []            # Array[Dictionary], see _new_node()
var next_id: int = 1
var leader_id: int = -1
var couriers_weeks: int = 0      # > 0: they switched to couriers, our intel gains are cut
var used_aliases: Array = []


# ---------------------------------------------------------------- data

static func data() -> Dictionary:
	return GameData.load_json(DATA_PATH)


static func types() -> Dictionary:
	return data().get("types", {})


static func type_def(t: String) -> Dictionary:
	return types().get(t, {})


static func type_name(t: String) -> String:
	return str(type_def(t).get("name", t.capitalize()))


static func rule(key: String, default: Variant = 0.0) -> Variant:
	return data().get("rules", {}).get(key, default)


static func suspected_at() -> float:
	return float(data().get("intel", {}).get("suspected_at", 25))


static func located_at() -> float:
	return float(data().get("intel", {}).get("located_at", 60))


static func org_name() -> String:
	return str(data().get("org_name", "the network"))


static func _regions() -> Dictionary:
	return GameData.load_json(REGIONS_PATH).get("regions", {})


static func _region_name(r: String) -> String:
	return str(_regions().get(r, {}).get("name", r))


# ---------------------------------------------------------------- setup

## start: region id -> starting strength weight. covered: regions the carrier reaches at start.
static func create(rng: RandomNumberGenerator, start: Dictionary, covered: Array):
	var n = load("res://sim/network.gd").new()
	n._generate(rng, start, covered)
	return n


func _generate(rng: RandomNumberGenerator, start: Dictionary, covered: Array) -> void:
	var d: Dictionary = data()
	var leader_regions: Array = d.get("leader_regions", [])
	var lr: String = _weighted_pick(rng, leader_regions, start)
	var leader: Dictionary = _new_node(rng, "leadership", 0, "", lr, -1, 2)
	leader["title"] = str(d.get("leader_title", "The Emir"))
	leader_id = int(leader["id"])

	var active: Array = start.keys().filter(func(r): return int(start[r]) > 0 and r != lr)
	var branches: Dictionary = d.get("branches", {})
	for b in branches:
		var bd: Dictionary = branches[b]
		var br: String = _weighted_pick(rng, active, start)
		var lt: Dictionary = _new_node(rng, str(bd.get("head", "leadership")), 1, b, br, leader_id, 2)
		lt["title"] = str(bd.get("title", "Lieutenant"))
		for t in bd.get("cells", []):
			var region: String = _cell_region(rng, str(t), br, start)
			_new_node(rng, str(t), 2, b, region, int(lt["id"]), rng.randi_range(1, 2))
	# A few lateral contacts between cells of different branches.
	var cells: Array = nodes.filter(func(x): return int(x["tier"]) == 2)
	for i in 6:
		var a: Dictionary = cells[rng.randi() % cells.size()]
		var b2: Dictionary = cells[rng.randi() % cells.size()]
		if a != b2:
			_link(a, b2)

	# Starting intel: a little everywhere, more in the carrier's first reach, and a few
	# cells already located so there is something to hit in week one.
	for x in nodes:
		x["intel"] = float(rng.randi_range(0, 14))
		if int(x["tier"]) == 2 and covered.has(str(x["region"])):
			x["intel"] += float(rng.randi_range(15, 35))
	var near: Array = cells.filter(func(x): return covered.has(str(x["region"])))
	near.shuffle()
	for i in mini(3, near.size()):
		near[i]["intel"] = float(rng.randi_range(62, 75))
	var lts: Array = nodes.filter(func(x): return int(x["tier"]) == 1)
	lts[rng.randi() % lts.size()]["intel"] = float(rng.randi_range(28, 40))
	leader["intel"] = 5.0


## Cells live near their lieutenant (up to two links away); sleepers live in the West.
func _cell_region(rng: RandomNumberGenerator, t: String, home: String, start: Dictionary) -> String:
	if t == "sleeper":
		var sr: Array = data().get("sleeper_regions", [])
		return str(sr[rng.randi() % sr.size()])
	var regs: Dictionary = _regions()
	var pool: Array = [home]
	for nb in regs.get(home, {}).get("neighbors", []):
		if not pool.has(nb):
			pool.append(nb)
		for nb2 in regs.get(nb, {}).get("neighbors", []):
			if not pool.has(nb2) and rng.randf() < 0.5:
				pool.append(nb2)
	var w: Dictionary = {}
	for r in pool:
		w[r] = int(start.get(r, 0)) + (3 if r == home else 1)
	return _weighted_pick(rng, pool, w)


func _weighted_pick(rng: RandomNumberGenerator, pool: Array, weights: Dictionary) -> String:
	var total: float = 0.0
	for r in pool:
		total += maxf(0.5, float(weights.get(r, 0)))
	var roll: float = rng.randf() * total
	for r in pool:
		roll -= maxf(0.5, float(weights.get(r, 0)))
		if roll <= 0.0:
			return str(r)
	return str(pool[pool.size() - 1])


func _new_node(rng: RandomNumberGenerator, t: String, tier: int, branch: String, region: String, parent: int, size: int) -> Dictionary:
	var d: Dictionary = data()
	var firsts: Array = d.get("first_names", ["Unknown"])
	var lasts: Array = d.get("last_names", ["Unknown"])
	var aliases: Array = (d.get("aliases", []) as Array).filter(func(a): return not used_aliases.has(a))
	var alias: String = str(aliases[rng.randi() % aliases.size()]) if not aliases.is_empty() else "Contact %d" % next_id
	used_aliases.append(alias)
	var cities: Array = _regions().get(region, {}).get("cities", ["(unknown)"])
	var x: Dictionary = {
		"id": next_id, "type": t, "tier": tier, "branch": branch, "region": region,
		"city": str(cities[rng.randi() % cities.size()]), "parent": parent, "links": [],
		"size": clampi(size, 1, MAX_SIZE), "intel": 0.0, "status": "active", "dark_weeks": 0,
		"name": "%s %s" % [firsts[rng.randi() % firsts.size()], lasts[rng.randi() % lasts.size()]],
		"alias": alias, "seed": rng.randi(), "title": "", "fate": "",
	}
	next_id += 1
	nodes.append(x)
	if parent >= 0:
		var p: Dictionary = node(parent)
		if not p.is_empty():
			_link(x, p)
	return x


func _link(a: Dictionary, b: Dictionary) -> void:
	if not (a["links"] as Array).has(int(b["id"])):
		a["links"].append(int(b["id"]))
	if not (b["links"] as Array).has(int(a["id"])):
		b["links"].append(int(a["id"]))


# ---------------------------------------------------------------- queries

func node(id: int) -> Dictionary:
	for x in nodes:
		if int(x["id"]) == id:
			return x
	return {}


static func is_alive(x: Dictionary) -> bool:
	return str(x.get("status", "")) in ["active", "dark"]


static func is_suspected(x: Dictionary) -> bool:
	return float(x.get("intel", 0.0)) >= suspected_at() or not is_alive(x)


## Located = we know where he sleeps tonight: he can be targeted.
static func is_located(x: Dictionary) -> bool:
	return str(x.get("status", "")) == "active" and float(x.get("intel", 0.0)) >= located_at()


func alive_nodes() -> Array:
	return nodes.filter(func(x): return is_alive(x))


func nodes_in(region: String) -> Array:
	return nodes.filter(func(x): return is_alive(x) and str(x["region"]) == region)


func region_strength(region: String) -> int:
	var s: int = 0
	for x in nodes_in(region):
		s += int(x["size"])
	return mini(5, s)


func leader() -> Dictionary:
	return node(leader_id)


func leader_down() -> bool:
	return not is_alive(leader())


func lieutenant_of(branch: String) -> Dictionary:
	for x in nodes:
		if int(x["tier"]) == 1 and str(x["branch"]) == branch and is_alive(x):
			return x
	return {}


func _any_lieutenant_alive() -> bool:
	for x in nodes:
		if int(x["tier"]) == 1 and is_alive(x):
			return true
	return false


func leaderless(x: Dictionary) -> bool:
	return int(x["tier"]) == 2 and lieutenant_of(str(x["branch"])).is_empty()


## Short public label: the alias once located, the type while only suspected.
static func label(x: Dictionary) -> String:
	if is_located(x) or not is_alive(x):
		return "'%s'" % x["alias"]
	return "a %s cell" % type_name(str(x["type"])).to_lower() if int(x["tier"]) == 2 else "an unidentified %s" % str(x.get("title", "commander")).to_lower()


func tangos_for(x: Dictionary) -> int:
	var by_size: Array = rule("tangos_by_size", [3, 3, 4, 5])
	var t: int = int(by_size[clampi(int(x["size"]), 0, by_size.size() - 1)])
	if int(x["tier"]) == 1:
		t += int(rule("lieutenant_tangos", 2))
	elif int(x["tier"]) == 0:
		t += int(rule("leader_tangos", 4))
	t += int(type_def(str(x["type"])).get("tangos", 0))
	return clampi(t, 2, MAX_TANGOS)


func branch_title(branch: String) -> String:
	return str(data().get("branches", {}).get(branch, {}).get("title", "Lieutenant"))


# ---------------------------------------------------------------- the network's week

## Growth, new cells, replacements, intel. Returns {"lines": Array[String], "plots": Array}
## where each plot request is {"node": id, "region": String}. busy: node ids already plotting.
func week(rng: RandomNumberGenerator, covered: Array, global_intel: bool, lying_low: Array, busy: Array) -> Dictionary:
	var lines: Array[String] = []
	var requests: Array = []
	var td: Dictionary = types()

	for x in alive_nodes():
		if str(x["status"]) == "dark":
			x["dark_weeks"] = int(x["dark_weeks"]) - 1
			if int(x["dark_weeks"]) <= 0:
				x["status"] = "active"

	# A branch that lost its lieutenant promotes someone from inside.
	for b in data().get("branches", {}):
		if not lieutenant_of(b).is_empty() or leader_down():
			continue
		if rng.randf() >= float(rule("replace_chance", 0.22)):
			continue
		var cands: Array = nodes.filter(func(x): return is_alive(x) and int(x["tier"]) == 2 and str(x["branch"]) == b)
		if cands.is_empty():
			continue
		cands.sort_custom(func(a, c): return int(a["size"]) > int(c["size"]))
		var nl: Dictionary = cands[0]
		nl["tier"] = 1
		nl["title"] = branch_title(b)
		nl["parent"] = leader_id
		_link(nl, leader())
		for c in cands:
			if c != nl:
				c["parent"] = int(nl["id"])
				_link(c, nl)
		if is_suspected(nl):
			var l0: String = label(nl)
			lines.append("%s has been promoted to %s. The branch is reorganizing around him." % [l0[0].to_upper() + l0.substr(1), str(nl["title"]).to_lower()])
		else:
			lines.append("Chatter: someone new is running the network's %s branch." % b)

	var start_nodes: Array = alive_nodes()
	var factor_ll: float = float(rule("leaderless_factor", 0.4))

	# Growth.
	for x in start_nodes:
		if str(x["status"]) != "active" or int(x["size"]) >= MAX_SIZE:
			continue
		if lying_low.has(str(x["region"])) and rng.randf() < 0.6:
			continue
		var chance: float = float(rule("growth_chance", 0.05)) + float(td.get(str(x["type"]), {}).get("growth", 0.0))
		var boss: Dictionary = node(int(x["parent"]))
		if not boss.is_empty() and is_alive(boss) and str(boss["type"]) == "finance":
			chance += float(td.get("finance", {}).get("feeds", 0.04))
		if leaderless(x):
			chance *= factor_ll
		if rng.randf() < chance:
			x["size"] = int(x["size"]) + 1
			if is_suspected(x):
				lines.append("Intel: %s in %s is growing." % [label(x), _region_name(str(x["region"]))])

	# New cells.
	for x in start_nodes:
		if alive_nodes().size() >= int(rule("spawn_cap", 46)):
			break
		if str(x["status"]) != "active":
			continue
		var chance: float = float(td.get(str(x["type"]), {}).get("spawn", 0.0))
		if int(x["size"]) >= MAX_SIZE:
			chance += 0.03
		if leaderless(x):
			chance *= factor_ll
		if chance <= 0.0 or rng.randf() >= chance:
			continue
		var c: Dictionary = _spawn_cell(rng, x)
		if c.is_empty():
			continue
		if covered.has(str(c["region"])):
			c["intel"] = 10.0
		if is_suspected(x):
			lines.append("Intel: %s has set up a new cell in %s." % [label(x), _region_name(str(c["region"]))])
		else:
			lines.append("New cell: the network has appeared in %s." % _region_name(str(c["region"])) if region_strength(str(c["region"])) == int(c["size"]) else "")

	# Attack plots.
	var sleepers: Array = data().get("sleeper_regions", [])
	for x in alive_nodes():
		if str(x["status"]) != "active" or busy.has(int(x["id"])):
			continue
		var p: float = float(td.get(str(x["type"]), {}).get("plot", 0.0))
		if p <= 0.0:
			continue
		var min_size: int = 1 if str(x["type"]) == "sleeper" else int(rule("plot_min_size", 2))
		if int(x["size"]) < min_size:
			continue
		var chance: float = p * float(x["size"])
		if leaderless(x):
			chance *= factor_ll
		if rng.randf() >= chance:
			continue
		var target: String = str(x["region"])
		if str(x["type"]) == "bomb_making" and rng.randf() < float(rule("far_plot_chance", 0.35)):
			target = str(sleepers[rng.randi() % sleepers.size()])
		requests.append({"node": int(x["id"]), "region": target})

	# What we learn this week.
	couriers_weeks = maxi(0, couriers_weeks - 1)
	var cf: float = float(rule("couriers_factor", 0.5)) if couriers_weeks > 0 else 1.0
	for x in alive_nodes():
		var before: float = float(x["intel"])
		var gain: float = 0.0
		# The Emir is found through his lieutenants. With all of them gone he has to show
		# himself more, and coverage starts to pick him up.
		var tier_f: float = float(rule("lieutenant_coverage_factor", 0.35)) if int(x["tier"]) == 1 else 1.0
		if int(x["tier"]) == 0:
			if _any_lieutenant_alive():
				continue
			tier_f = float(rule("lieutenant_coverage_factor", 0.35))
		if str(x["status"]) == "active":
			if covered.has(str(x["region"])):
				gain += float(rng.randi_range(int(rule("coverage_intel_min", 5)), int(rule("coverage_intel_max", 10)))) * (0.7 + 0.15 * float(x["size"])) * tier_f
			if global_intel:
				gain += float(rule("global_intel", 4))
			for lid in x["links"]:
				var l: Dictionary = node(int(lid))
				if not l.is_empty() and (is_located(l) or not is_alive(l)):
					gain += float(rule("link_intel", 2))
					break
		gain *= cf
		if gain <= 0.0:
			x["intel"] = maxf(0.0, before - float(rule("intel_decay", 1)))
		else:
			x["intel"] = minf(100.0, before + gain)
		lines.append_array(_threshold_lines(x, before))

	var out: Array[String] = []
	for l in lines:
		if l != "":
			out.append(l)
	return {"lines": out, "plots": requests}


func _spawn_cell(rng: RandomNumberGenerator, from: Dictionary) -> Dictionary:
	var b: String = str(from["branch"])
	var pool: Array = data().get("branches", {}).get(b, {}).get("cells", ["recruitment"])
	var t: String = str(pool[rng.randi() % pool.size()])
	var region: String = str(from["region"])
	if t == "sleeper":
		var sr: Array = data().get("sleeper_regions", [])
		region = str(sr[rng.randi() % sr.size()])
	elif rng.randf() < 0.6:
		var nb: Array = _regions().get(region, {}).get("neighbors", [])
		if not nb.is_empty():
			region = str(nb[rng.randi() % nb.size()])
	if region_strength(region) >= 5:
		return {}
	var lt: Dictionary = lieutenant_of(b)
	var parent: int = int(lt["id"]) if not lt.is_empty() else int(from["id"])
	var c: Dictionary = _new_node(rng, t, 2, b, region, parent, 1)
	_link(c, from)
	return c


func _threshold_lines(x: Dictionary, before: float) -> Array[String]:
	var out: Array[String] = []
	var now: float = float(x["intel"])
	var r: String = _region_name(str(x["region"]))
	if before < located_at() and now >= located_at() and str(x["status"]) == "active":
		var who: String = "%s %s" % [str(x["title"]), x["name"]] if int(x["tier"]) < 2 else str(x["name"])
		out.append("LOCATED: '%s' (%s), %s in %s. He can be targeted." % [x["alias"], who.strip_edges(), type_name(str(x["type"])).to_lower(), x["city"]])
	elif before < suspected_at() and now >= suspected_at():
		if int(x["tier"]) == 0:
			out.append("NEW LEAD: the network's leader may be hiding in %s." % r)
		elif int(x["tier"]) == 1:
			out.append("NEW LEAD: the network's %s may be in %s." % [str(x["title"]).to_lower(), r])
		else:
			out.append("New lead: a %s cell in %s." % [type_name(str(x["type"])).to_lower(), r])
	return out


# ---------------------------------------------------------------- our operations

## A raid on a located person. mode "kill" or "capture"; hvt: "killed" / "captured" / "escaped".
## Returns {"lines": Array[String], "revenge": String region or ""}.
func resolve_node_op(id: int, success: bool, hvt: String, rng: RandomNumberGenerator, current_week: int) -> Dictionary:
	var lines: Array[String] = []
	var x: Dictionary = node(id)
	var revenge: String = ""
	if x.is_empty() or not is_alive(x):
		return {"lines": lines, "revenge": revenge}
	var who: String = "'%s'" % x["alias"]
	if success and hvt in ["killed", "captured"]:
		var captured: bool = hvt == "captured"
		x["status"] = "captured" if captured else "killed"
		x["fate"] = "%s in week %d" % ["Captured" if captured else "Killed", current_week + 1]
		var gain: float = float(rule("capture_link_intel" if captured else "kill_link_intel", 30))
		if captured:
			lines.append("%s (%s) is in custody. Interrogation is under way." % [who, x["name"]])
		else:
			lines.append("%s (%s) is dead. The team took his phones and papers." % [who, x["name"]])
		for lid in x["links"]:
			var l: Dictionary = node(int(lid))
			if l.is_empty() or not is_alive(l) or int(l["tier"]) == 0:
				continue
			var before: float = float(l["intel"])
			var g: float = gain
			if captured and int(l["id"]) == int(x["parent"]):
				g += float(rule("capture_boss_intel", 25))
			l["intel"] = minf(100.0, before + g)
			lines.append_array(_threshold_lines(l, before))
		if int(x["tier"]) == 2 and captured and not leader_down():
			leader()["intel"] = minf(100.0, float(leader()["intel"]) + 3.0)
		# Only his lieutenants know where the Emir sleeps.
		if int(x["tier"]) == 1 and not leader_down():
			var ld: Dictionary = leader()
			var lb: float = float(ld["intel"])
			ld["intel"] = minf(100.0, lb + float(rule("leader_intel_per_capture" if captured else "leader_intel_per_kill", 10)))
			if captured:
				lines.append("Under interrogation he gives up what he knows about %s (intel on him now %d%%)." % [str(ld.get("title", "the Emir")), int(ld["intel"])])
			lines.append_array(_threshold_lines(ld, lb))
		if captured and str(x["type"]) in ["finance", "logistics"] and couriers_weeks <= 0:
			couriers_weeks = int(rule("couriers_weeks", 5))
			lines.append("The network knows its phones are burned. It has switched to couriers: our intel comes in at half speed for %d weeks." % couriers_weeks)
		# Nearby nodes hear about it and go to ground.
		var dark_chance: float = float(rule("go_dark_after_capture" if captured else "go_dark_after_kill", 0.4))
		var went_dark: int = 0
		for o in nodes_in(str(x["region"])):
			if o == x or str(o["status"]) != "active":
				continue
			if rng.randf() < dark_chance:
				_go_dark(o)
				went_dark += 1
		if went_dark > 0:
			lines.append("%d other cell%s in %s went dark after the raid." % [went_dark, "" if went_dark == 1 else "s", _region_name(str(x["region"]))])
		if int(x["tier"]) == 1:
			lines.append("The %s branch has lost its head. Its cells grow and plot more slowly until someone takes over." % str(x["branch"]))
		if int(x["tier"]) <= 1 and not leader_down():
			var sr: Array = data().get("sleeper_regions", [])
			revenge = str(sr[rng.randi() % sr.size()])
			lines.append("The network has vowed revenge for %s. Chatter points to an attack in %s within %d weeks." % [who, _region_name(revenge), int(rule("revenge_weeks", 3))])
	else:
		x["size"] = mini(MAX_SIZE, int(x["size"]) + 1)
		x["intel"] = maxf(0.0, float(x["intel"]) - float(rule("fail_intel_loss", 20)))
		_go_dark(x)
		if hvt == "escaped":
			lines.append("%s got away. He has gone to ground and the cell is stronger for it." % who)
		else:
			lines.append("The raid on %s failed. He has gone to ground and the cell is stronger for it." % who)
	return {"lines": lines, "revenge": revenge}


## A raid on a region without a named target: hits whatever cell is there and turns up intel.
func resolve_safehouse(region: String, success: bool, rng: RandomNumberGenerator, current_week: int) -> Array[String]:
	var lines: Array[String] = []
	var here: Array = nodes_in(region).filter(func(x): return int(x["tier"]) == 2)
	if here.is_empty():
		here = nodes_in(region)
	if here.is_empty():
		return lines
	var x: Dictionary = here[rng.randi() % here.size()]
	if success:
		x["size"] = int(x["size"]) - 1
		if int(x["size"]) <= 0:
			x["size"] = 1
			x["status"] = "killed"
			x["fate"] = "Cell destroyed in week %d" % (current_week + 1)
			lines.append("The safehouse belonged to %s. The cell is destroyed; '%s' (%s) died in the raid." % [label(x) if is_located(x) else "a %s cell" % type_name(str(x["type"])).to_lower(), x["alias"], x["name"]])
		else:
			lines.append("The safehouse belonged to a %s cell. It is weakened." % type_name(str(x["type"])).to_lower())
		for o in nodes_in(region):
			if int(o["tier"]) == 0:
				continue
			var before: float = float(o["intel"])
			o["intel"] = minf(100.0, before + float(rule("safehouse_intel", 30)))
			lines.append_array(_threshold_lines(o, before))
	else:
		x["size"] = mini(MAX_SIZE, int(x["size"]) + 1)
		lines.append("The failed raid emboldened the network in %s." % _region_name(region))
	return lines


func _go_dark(x: Dictionary) -> void:
	x["status"] = "dark"
	x["dark_weeks"] = int(rule("dark_weeks", 2))
	x["intel"] = maxf(0.0, float(x["intel"]) - float(rule("dark_intel_loss", 15)))


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {"nodes": nodes, "next_id": next_id, "leader_id": leader_id, "couriers_weeks": couriers_weeks, "used_aliases": used_aliases}


static func from_dict(d: Dictionary):
	var n = load("res://sim/network.gd").new()
	for raw in d.get("nodes", []):
		var x: Dictionary = (raw as Dictionary).duplicate(true)
		for k in ["id", "tier", "parent", "size", "dark_weeks", "seed"]:
			x[k] = int(x.get(k, 0))
		x["intel"] = float(x.get("intel", 0.0))
		var links: Array = []
		for l in x.get("links", []):
			links.append(int(l))
		x["links"] = links
		n.nodes.append(x)
	n.next_id = int(d.get("next_id", n.nodes.size() + 1))
	n.leader_id = int(d.get("leader_id", -1))
	n.couriers_weeks = int(d.get("couriers_weeks", 0))
	n.used_aliases = (d.get("used_aliases", []) as Array).duplicate()
	return n
