extends RefCounted
## The campaign map: the carrier, the enemy network (sim/network.gd) spread over the
## regions, attack plots, the threat level, and the weekly enemy phase. Region strength is
## the sum of the network's nodes there. Pure rules + state (no nodes). Saved in the
## campaign file. Data: data/regions.json, data/network.json.

const GameData := preload("res://sim/game_data.gd")
const Network := preload("res://sim/network.gd")
const DATA_PATH := "res://data/regions.json"
const MAX_STRENGTH := 5
const INTEL_WEEKS := 4        # after an operation in a region you keep intel on it this long
const HISTORY_CAP := 300

var network = null                # Network
var strength: Dictionary = {}     # region id -> int 0..5 (derived from the network)
var plots: Array = []             # {"region", "city", "weeks", "node" (-1 = revenge), "announced"}
var carrier_zone: String = ""
var carrier_moved: bool = false   # already moved this week
var lying_low: Array[String] = [] # regions that saw the carrier arrive this week: no growth
var last_op_week: Dictionary = {} # region id -> week of our last operation there
var threat: float = 0.0           # 0..100
var attack_score: float = 0.0     # threat from attacks that landed (decays)
var week: int = 0
var attacks_landed: int = 0
var plots_foiled: int = 0
var severe_weeks: int = 0         # consecutive weeks at or above the defeat threshold
var outcome: String = ""          # "" while the war goes on, "victory" or "defeat"
var news: Array[String] = []      # the latest weekly briefing
var history: Array[String] = []   # every briefing line, oldest first


# ---------------------------------------------------------------- data

static func data() -> Dictionary:
	return GameData.load_json(DATA_PATH)


static func regions() -> Dictionary:
	return data().get("regions", {})


static func zones() -> Dictionary:
	return data().get("sea_zones", {})


static func theaters() -> Dictionary:
	return data().get("theaters", {})


static func rule(key: String, default: Variant = 0.0) -> Variant:
	return data().get("rules", {}).get(key, default)


static func region(id: String) -> Dictionary:
	return regions().get(id, {})


static func region_name(id: String) -> String:
	return str(region(id).get("name", id))


static func theater_of(id: String) -> Dictionary:
	return theaters().get(str(region(id).get("theater", "contested")), {})


# ---------------------------------------------------------------- setup

static func create(rng: RandomNumberGenerator):
	var w = load("res://sim/world_sim.gd").new()
	w.carrier_zone = str(rule("starting_zone", "mediterranean"))
	var start: Dictionary = {}
	for id in regions():
		start[id] = int(region(id).get("start", 0))
	w.network = Network.create(rng, start, w.covered())
	w._sync()
	# One plot already in motion, so the first briefing has teeth.
	var plotters: Array = w.network.alive_nodes().filter(func(x): return str(x["type"]) == "bomb_making")
	if not plotters.is_empty():
		var x: Dictionary = plotters[rng.randi() % plotters.size()]
		w._add_plot(str(x["region"]), rng, 5, int(x["id"]))
	w._recompute_threat()
	w.news.assign([
		"Intelligence confirms a global network calling itself %s, active in %d regions." % [Network.org_name(), w.active_regions().size()],
		"Its leader, known only as %s, has never been photographed. Work your way up to him." % str(w.network.leader().get("title", "the Emir")),
		"The carrier is on station in the %s." % w.zone_name(w.carrier_zone),
	])
	w.history.append_array(w.news)
	return w


func _sync() -> void:
	for id in regions():
		strength[id] = network.region_strength(id)


# ---------------------------------------------------------------- queries

func zone_name(z: String) -> String:
	return str(zones().get(z, {}).get("name", z))


func covered() -> Array:
	return zones().get(carrier_zone, {}).get("covers", [])


func in_range(region_id: String) -> bool:
	return covered().has(region_id)


func active_regions() -> Array:
	return strength.keys().filter(func(r): return int(strength[r]) > 0)


func total_strength() -> int:
	var t: int = 0
	for r in strength:
		t += int(strength[r])
	return t


## Do we know what is going on in this region (plot countdowns)?
func has_intel(region_id: String, global_intel: bool = false) -> bool:
	if global_intel or in_range(region_id):
		return true
	return last_op_week.has(region_id) and week - int(last_op_week[region_id]) < INTEL_WEEKS


func plot_known(p: Dictionary, global_intel: bool = false) -> bool:
	if bool(p.get("announced", false)) or has_intel(str(p["region"]), global_intel):
		return true
	var x: Dictionary = network.node(int(p.get("node", -1)))
	return not x.is_empty() and Network.is_suspected(x)


func plot_in(region_id: String) -> Dictionary:
	for p in plots:
		if str(p["region"]) == region_id:
			return p
	return {}


## Who is behind a plot, as far as we know ("" = unknown).
func plot_source(p: Dictionary) -> String:
	var x: Dictionary = network.node(int(p.get("node", -1)))
	if x.is_empty():
		return "a revenge cell" if int(p.get("node", -1)) < 0 else ""
	return Network.label(x) if Network.is_suspected(x) else ""


func can_move_to(zone: String) -> bool:
	return not carrier_moved and zones().get(carrier_zone, {}).get("neighbors", []).has(zone)


## Every operation possible in a region this week (empty when there is no enemy there):
## named targets that are located, known attack plots, and a blind safehouse raid.
func operations_for(region_id: String, global_intel: bool = false) -> Array:
	var out: Array = []
	var reg: Dictionary = region(region_id)
	var theater: String = str(reg.get("theater", "contested"))
	for x in network.nodes_in(region_id):
		if not Network.is_located(x):
			continue
		var td: Dictionary = Network.type_def(str(x["type"]))
		out.append({
			"kind": "node", "region": region_id, "city": str(x["city"]), "node": int(x["id"]),
			"title": str(td.get("kill", "Raid")), "kill_title": str(td.get("kill", "Raid")),
			"capture_title": str(td.get("capture", "Capture")), "theater": theater,
			"tangos": network.tangos_for(x), "tier": int(x["tier"]),
			"hvt": {"name": str(x["name"]), "alias": str(x["alias"]), "seed": int(x["seed"])},
			"strength": int(strength.get(region_id, 0)), "plot": false,
		})
	for p in plots:
		if str(p["region"]) == region_id and plot_known(p, global_intel):
			out.append({
				"kind": "plot", "region": region_id, "city": str(p["city"]), "node": -1,
				"title": "Stop the attack: raid the attack team", "theater": theater, "tangos": 4,
				"strength": int(strength.get(region_id, 0)), "plot": true, "weeks": int(p["weeks"]),
			})
	var s: int = int(strength.get(region_id, 0))
	if s > 0:
		var cities: Array = reg.get("cities", ["(unknown)"])
		var tangos: Array = rule("tangos_by_strength", [3, 3, 3, 4, 5, 5])
		out.append({
			"kind": "safehouse", "region": region_id, "node": -1, "theater": theater,
			"city": str(cities[absi(hash(region_id + str(week))) % cities.size()]),
			"title": "Raid a suspected safehouse", "strength": s, "plot": false,
			"tangos": int(tangos[clampi(s, 0, tangos.size() - 1)]),
		})
	return out


func operations_in_range(global_intel: bool = false) -> Array:
	var out: Array = []
	for r in covered():
		out.append_array(operations_for(r, global_intel))
	return out


# ---------------------------------------------------------------- player moves

func move_carrier(zone: String) -> bool:
	if not can_move_to(zone):
		return false
	carrier_zone = zone
	carrier_moved = true
	# The network sees the carrier coming: cells in its new reach tend to lie low this week.
	lying_low.clear()
	for r in covered():
		lying_low.append(r)
	_log("The carrier moved to the %s." % zone_name(zone))
	return true


## Apply an operation's outcome to the map. hvt: "killed" / "captured" / "escaped" / "".
## Returns briefing lines for the after-action report.
func resolve_operation(op: Dictionary, success: bool, hvt: String, rng: RandomNumberGenerator) -> Array[String]:
	var lines: Array[String] = []
	var r: String = str(op.get("region", ""))
	if r == "" or not strength.has(r):
		return lines
	last_op_week[r] = week
	match str(op.get("kind", "safehouse")):
		"node":
			var id: int = int(op.get("node", -1))
			var res: Dictionary = network.resolve_node_op(id, success, hvt, rng, week)
			lines.append_array(res["lines"])
			if not Network.is_alive(network.node(id)):
				for p in plots.duplicate():
					if int(p.get("node", -1)) == id:
						plots.erase(p)
						plots_foiled += 1
						attack_score = maxf(0.0, attack_score - 6.0)
						lines.append("The attack he was planning against %s will not happen." % p["city"])
			if str(res["revenge"]) != "":
				_add_plot(str(res["revenge"]), rng, int(Network.rule("revenge_weeks", 3)), -1, true)
		"plot":
			var p: Dictionary = plot_in(r)
			if success and not p.is_empty():
				plots.erase(p)
				plots_foiled += 1
				attack_score = maxf(0.0, attack_score - 6.0)
				lines.append("The attack planned for %s was stopped." % p["city"])
				var x: Dictionary = network.node(int(p.get("node", -1)))
				if not x.is_empty() and Network.is_alive(x):
					var before: float = float(x["intel"])
					x["intel"] = minf(100.0, before + 25.0)
					lines.append("The attack team's phones point back to whoever sent them.")
					lines.append_array(network._threshold_lines(x, before))
			elif not p.is_empty():
				lines.append("The attack team got away. The plot against %s goes on." % p["city"])
		_:
			lines.append_array(network.resolve_safehouse(r, success, rng, week))
	_sync()
	if int(strength.get(r, 0)) == 0 and success:
		lines.append("The network has been driven out of %s." % region_name(r))
	if network.leader_down():
		outcome = "victory"
	_recompute_threat()
	for l in lines:
		_log(l)
	return lines


# ---------------------------------------------------------------- enemy phase

## The network's week: growth, new cells, plots ticking down, attacks. Returns
## {"news": Array[String], "funding_lost": int}.
func enemy_phase(rng: RandomNumberGenerator, global_intel: bool = false) -> Dictionary:
	var lines: Array[String] = []
	var funding_lost: int = 0
	var busy: Array = plots.map(func(p): return int(p.get("node", -1)))
	var net: Dictionary = network.week(rng, covered(), global_intel, lying_low, busy)
	lines.append_array(net["lines"])
	_sync()

	# Plots tick down; the ones that reach zero are attacks.
	for p in plots.duplicate():
		p["weeks"] = int(p["weeks"]) - 1
		if int(p["weeks"]) > 0:
			continue
		plots.erase(p)
		var th: Dictionary = theater_of(str(p["region"]))
		var cost: int = int(float(rule("attack_funding_cost", 120000)) * float(th.get("attack_cost", 1.0)))
		funding_lost += cost
		attack_score += float(rule("attack_threat", 12))
		attacks_landed += 1
		var src: String = plot_source(p)
		lines.append("ATTACK in %s (%s)%s. Oversight cuts $%dk from the budget." % [p["city"], region_name(str(p["region"])), (", the work of " + src) if src != "" else "", int(cost / 1000.0)])

	# New plots.
	for req in net["plots"]:
		var p: Dictionary = _add_plot(str(req["region"]), rng, -1, int(req["node"]))
		if plot_known(p, global_intel):
			var src: String = plot_source(p)
			lines.append("Intel: %s is preparing an attack in %s. Estimated %d weeks." % [src if src != "" else "the network", p["city"], p["weeks"]])

	attack_score = maxf(0.0, attack_score - float(rule("threat_decay", 1)))
	_recompute_threat()
	week += 1
	carrier_moved = false
	lying_low.clear()
	if threat >= float(Network.rule("defeat_threat", 90)):
		severe_weeks += 1
		var left: int = int(Network.rule("defeat_weeks", 4)) - severe_weeks
		if left > 0:
			lines.append("WASHINGTON IS LOSING PATIENCE: the threat is critical. %d more week%s like this and the program is shut down." % [left, "" if left == 1 else "s"])
		else:
			outcome = "defeat"
	else:
		severe_weeks = 0
	if network.leader_down():
		outcome = "victory"
	if lines.is_empty():
		lines.append("A quiet week. No new intelligence.")
	news.assign(lines)
	for l in lines:
		_log(l)
	return {"news": lines, "funding_lost": funding_lost}


func _add_plot(r: String, rng: RandomNumberGenerator, weeks: int = -1, node_id: int = -1, announced: bool = false) -> Dictionary:
	var cities: Array = region(r).get("cities", ["(unknown)"])
	if weeks < 0:
		weeks = rng.randi_range(int(rule("plot_weeks_min", 3)), int(rule("plot_weeks_max", 5)))
	var p: Dictionary = {"region": r, "city": str(cities[rng.randi() % cities.size()]), "weeks": weeks, "node": node_id, "announced": announced}
	plots.append(p)
	return p


func _recompute_threat() -> void:
	threat = clampf(total_strength() * float(rule("threat_per_strength", 1.6)) + attack_score, 0.0, 100.0)


func threat_label() -> String:
	if threat < 25.0:
		return "LOW"
	if threat < 50.0:
		return "ELEVATED"
	if threat < 75.0:
		return "HIGH"
	return "SEVERE"


func _log(line: String) -> void:
	history.append("Week %d: %s" % [week + 1, line])
	if history.size() > HISTORY_CAP:
		history = history.slice(history.size() - HISTORY_CAP)


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {
		"network": network.to_dict(), "plots": plots, "carrier_zone": carrier_zone,
		"carrier_moved": carrier_moved, "lying_low": lying_low, "last_op_week": last_op_week,
		"threat": threat, "attack_score": attack_score, "week": week,
		"attacks_landed": attacks_landed, "plots_foiled": plots_foiled,
		"severe_weeks": severe_weeks, "outcome": outcome,
		"news": news, "history": history,
	}


## Saves from before the network existed have no "network": those return null (start fresh).
static func from_dict(d: Dictionary):
	if typeof(d.get("network", null)) != TYPE_DICTIONARY:
		return null
	var w = load("res://sim/world_sim.gd").new()
	w.network = Network.from_dict(d["network"])
	w._sync()
	for p in d.get("plots", []):
		w.plots.append({"region": str(p["region"]), "city": str(p["city"]), "weeks": int(p["weeks"]),
			"node": int(p.get("node", -1)), "announced": bool(p.get("announced", false))})
	w.carrier_zone = str(d.get("carrier_zone", rule("starting_zone", "mediterranean")))
	w.carrier_moved = bool(d.get("carrier_moved", false))
	w.lying_low.assign(d.get("lying_low", []))
	for k in d.get("last_op_week", {}):
		w.last_op_week[k] = int(d["last_op_week"][k])
	w.attack_score = float(d.get("attack_score", 0.0))
	w.week = int(d.get("week", 0))
	w.attacks_landed = int(d.get("attacks_landed", 0))
	w.plots_foiled = int(d.get("plots_foiled", 0))
	w.severe_weeks = int(d.get("severe_weeks", 0))
	w.outcome = str(d.get("outcome", ""))
	w.news.assign(d.get("news", []))
	w.history.assign(d.get("history", []))
	w._recompute_threat()
	return w
