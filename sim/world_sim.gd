extends RefCounted
## The campaign map: enemy strength per region, cell types, attack plots, the carrier, the
## threat level, and the weekly enemy phase. Pure rules + state (no nodes). Saved in the
## campaign file. Data: data/regions.json.

const GameData := preload("res://sim/game_data.gd")
const DATA_PATH := "res://data/regions.json"
const MAX_STRENGTH := 5
const INTEL_WEEKS := 4        # after an operation in a region you keep intel on it this long
const HISTORY_CAP := 300

var strength: Dictionary = {}     # region id -> int 0..5
var cells: Dictionary = {}        # region id -> cell type id ("" = unknown / none)
var plots: Array = []             # {"region", "city", "weeks"}
var carrier_zone: String = ""
var carrier_moved: bool = false   # already moved this week
var lying_low: Array[String] = [] # regions that saw the carrier arrive this week: no growth
var last_op_week: Dictionary = {} # region id -> week of our last operation there
var threat: float = 0.0           # 0..100
var attack_score: float = 0.0     # threat from attacks that landed (decays)
var week: int = 0
var attacks_landed: int = 0
var plots_foiled: int = 0
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


static func cell_types() -> Dictionary:
	return data().get("cell_types", {})


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
	var types: Array = cell_types().keys()
	for id in regions():
		var s: int = int(region(id).get("start", 0))
		if s > 0:
			s = clampi(s + rng.randi_range(-1, 1), 0, 4)
		w.strength[id] = s
		w.cells[id] = types[rng.randi() % types.size()] if s > 0 else ""
	w.carrier_zone = str(rule("starting_zone", "mediterranean"))
	# One plot already in motion somewhere strong, so the first briefing has teeth.
	var strong: Array = w.strength.keys().filter(func(r): return int(w.strength[r]) >= 3)
	if not strong.is_empty():
		var r: String = strong[rng.randi() % strong.size()]
		w._add_plot(r, rng, 5)
	w._recompute_threat()
	w.news.assign(["The network is active in %d regions. The carrier is on station in the %s." % [w.active_regions().size(), w.zone_name(w.carrier_zone)]])
	w.history.append_array(w.news)
	return w


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


## Do we know what is going on in this region (plot countdowns, cell type)?
func has_intel(region_id: String, global_intel: bool = false) -> bool:
	if global_intel or in_range(region_id):
		return true
	return last_op_week.has(region_id) and week - int(last_op_week[region_id]) < INTEL_WEEKS


func plot_in(region_id: String) -> Dictionary:
	for p in plots:
		if str(p["region"]) == region_id:
			return p
	return {}


func can_move_to(zone: String) -> bool:
	return not carrier_moved and zones().get(carrier_zone, {}).get("neighbors", []).has(zone)


## The operation available against a region this week ({} when there is no enemy there).
func operation_for(region_id: String) -> Dictionary:
	var s: int = int(strength.get(region_id, 0))
	if s <= 0:
		return {}
	var reg: Dictionary = region(region_id)
	var plot: Dictionary = plot_in(region_id)
	var cities: Array = reg.get("cities", ["(unknown)"])
	var city: String = str(plot["city"]) if not plot.is_empty() else str(cities[absi(hash(region_id + str(week))) % cities.size()])
	var cell: String = str(cells.get(region_id, ""))
	var title: String = "Raid a network safehouse"
	if not plot.is_empty():
		title = "Stop the attack: raid the attack cell"
	elif cell != "":
		title = str(cell_types().get(cell, {}).get("op", title))
	var tangos: Array = rule("tangos_by_strength", [3, 3, 3, 4, 5, 5])
	return {
		"region": region_id, "city": city, "title": title, "cell": cell,
		"strength": s, "theater": str(reg.get("theater", "contested")),
		"tangos": int(tangos[clampi(s, 0, tangos.size() - 1)]), "plot": not plot.is_empty(),
	}


func operations_in_range() -> Array:
	var out: Array = []
	for r in covered():
		var op: Dictionary = operation_for(r)
		if not op.is_empty():
			out.append(op)
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


## Apply an operation's outcome to the map. Returns briefing lines for the after-action report.
func resolve_operation(op: Dictionary, success: bool) -> Array[String]:
	var lines: Array[String] = []
	var r: String = str(op.get("region", ""))
	if r == "" or not strength.has(r):
		return lines
	last_op_week[r] = week
	var name: String = region_name(r)
	if success:
		var drop: int = int(rule("success_strength_drop", 2))
		strength[r] = maxi(0, int(strength[r]) - drop)
		var plot: Dictionary = plot_in(r)
		if not plot.is_empty():
			plots.erase(plot)
			plots_foiled += 1
			attack_score = maxf(0.0, attack_score - 6.0)
			lines.append("The attack planned for %s was stopped." % plot["city"])
		if int(strength[r]) == 0:
			cells[r] = ""
			lines.append("The network has been driven out of %s." % name)
		else:
			lines.append("Enemy strength in %s down to %d." % [name, strength[r]])
	else:
		strength[r] = mini(MAX_STRENGTH, int(strength[r]) + int(rule("failure_strength_gain", 1)))
		lines.append("The failed raid emboldened the network in %s (strength %d)." % [name, strength[r]])
	_recompute_threat()
	for l in lines:
		_log(l)
	return lines


# ---------------------------------------------------------------- enemy phase

## The network's week: growth, spread, plots ticking down, attacks. Returns
## {"news": Array[String], "funding_lost": int}.
func enemy_phase(rng: RandomNumberGenerator, global_intel: bool = false) -> Dictionary:
	var lines: Array[String] = []
	var funding_lost: int = 0
	var ct: Dictionary = cell_types()
	var start: Dictionary = strength.duplicate()

	# Growth.
	for r in start:
		var s: int = int(start[r])
		if s <= 0 or s >= MAX_STRENGTH:
			continue
		if lying_low.has(r) and rng.randf() < float(rule("lie_low_chance", 0.6)):
			continue
		var chance: float = float(rule("growth_chance", 0.22)) + float(ct.get(cells.get(r, ""), {}).get("growth", 0.0))
		if rng.randf() < chance:
			strength[r] = s + 1
			if has_intel(r, global_intel):
				lines.append("Intel: the network is growing in %s (strength %d)." % [region_name(r), strength[r]])

	# Spread along links.
	for r in start:
		var s: int = int(start[r])
		if s < int(rule("spread_min_strength", 3)):
			continue
		var chance: float = float(rule("spread_chance", 0.18)) + float(ct.get(cells.get(r, ""), {}).get("spread", 0.0))
		if rng.randf() >= chance:
			continue
		var links: Array = region(r).get("neighbors", [])
		if links.is_empty():
			continue
		var to: String = links[rng.randi() % links.size()]
		var before: int = int(strength.get(to, 0))
		if before >= MAX_STRENGTH:
			continue
		strength[to] = before + 1
		if before == 0:
			var types: Array = ct.keys()
			cells[to] = types[rng.randi() % types.size()]
			lines.append("New cell: the network has spread from %s into %s." % [region_name(r), region_name(to)])

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
		lines.append("ATTACK in %s (%s). The network struck before we could stop it. Oversight cuts $%dk from the budget." % [p["city"], region_name(str(p["region"])), int(cost / 1000.0)])

	# New plots.
	for r in strength:
		var s: int = int(strength[r])
		if s < int(rule("plot_min_strength", 3)) or not plot_in(r).is_empty():
			continue
		var chance: float = float(rule("plot_chance_per_strength", 0.06)) * s + float(ct.get(cells.get(r, ""), {}).get("plot", 0.0))
		if rng.randf() < chance:
			var p: Dictionary = _add_plot(r, rng)
			if has_intel(r, global_intel):
				lines.append("Intel: an attack is being prepared in %s. Estimated %d weeks." % [p["city"], p["weeks"]])

	attack_score = maxf(0.0, attack_score - float(rule("threat_decay", 1)))
	_recompute_threat()
	week += 1
	carrier_moved = false
	lying_low.clear()
	if lines.is_empty():
		lines.append("A quiet week. No new intelligence.")
	news.assign(lines)
	for l in lines:
		_log(l)
	return {"news": lines, "funding_lost": funding_lost}


func _add_plot(r: String, rng: RandomNumberGenerator, weeks: int = -1) -> Dictionary:
	var cities: Array = region(r).get("cities", ["(unknown)"])
	if weeks < 0:
		weeks = rng.randi_range(int(rule("plot_weeks_min", 3)), int(rule("plot_weeks_max", 5)))
	var p: Dictionary = {"region": r, "city": str(cities[rng.randi() % cities.size()]), "weeks": weeks}
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
		"strength": strength, "cells": cells, "plots": plots, "carrier_zone": carrier_zone,
		"carrier_moved": carrier_moved, "lying_low": lying_low, "last_op_week": last_op_week,
		"threat": threat, "attack_score": attack_score, "week": week,
		"attacks_landed": attacks_landed, "plots_foiled": plots_foiled,
		"news": news, "history": history,
	}


static func from_dict(d: Dictionary):
	var w = load("res://sim/world_sim.gd").new()
	for k in d.get("strength", {}):
		w.strength[k] = int(d["strength"][k])
	for id in regions():   # regions added to the data later start empty
		if not w.strength.has(id):
			w.strength[id] = 0
	w.cells = (d.get("cells", {}) as Dictionary).duplicate()
	for p in d.get("plots", []):
		w.plots.append({"region": str(p["region"]), "city": str(p["city"]), "weeks": int(p["weeks"])})
	w.carrier_zone = str(d.get("carrier_zone", rule("starting_zone", "mediterranean")))
	w.carrier_moved = bool(d.get("carrier_moved", false))
	w.lying_low.assign(d.get("lying_low", []))
	for k in d.get("last_op_week", {}):
		w.last_op_week[k] = int(d["last_op_week"][k])
	w.threat = float(d.get("threat", 0.0))
	w.attack_score = float(d.get("attack_score", 0.0))
	w.week = int(d.get("week", 0))
	w.attacks_landed = int(d.get("attacks_landed", 0))
	w.plots_foiled = int(d.get("plots_foiled", 0))
	w.news.assign(d.get("news", []))
	w.history.assign(d.get("history", []))
	w._recompute_threat()
	return w
