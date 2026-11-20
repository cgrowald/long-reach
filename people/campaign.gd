extends Node
## Autoload "Campaign": owns the saved roster, sends a squad on a mission and writes the
## results back into everyone's record (deaths, wounds, injuries, growth, traits, log).

const Roster := preload("res://people/roster.gd")
const GameData := preload("res://sim/game_data.gd")
const Research := preload("res://people/research.gd")
const WorldSim := preload("res://sim/world_sim.gd")

const STARTING_OPERATORS := 10
const SQUAD_SIZE := 4
const DAYS_PER_MISSION := 7
const HQ_SCENE := "res://hq/hq.tscn"
const MAP_SCENE := "res://world/campaign_map.tscn"
const AAR_SCENE := "res://hq/aar.tscn"
const MISSION_SCENE := "res://tactical/main.tscn"
const END_SCENE := "res://world/campaign_end.tscn"
const NETWORK_SCENE := "res://world/network_board.tscn"

const OP_WORDS_A: Array[String] = ["Iron", "Silent", "Broken", "Hollow", "Northern", "Quiet", "Red", "Long", "Cold", "Black", "Steel", "Distant"]
const OP_WORDS_B: Array[String] = ["Ledger", "Harbor", "Lantern", "Anvil", "Orchard", "Compass", "Bastion", "Meridian", "Thicket", "Gate", "Ember", "Tide"]

var save_path: String = "user://campaign.json"
var roster = null
var world = null                 # WorldSim: the campaign map
var current_op: Dictionary = {}  # operation picked on the map, waiting for a squad
var map_focus: String = ""      # region the map should open on (set by the network board)
var deployment: Array[int] = []
var operation_name: String = ""
var last_report: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_campaign()


func new_campaign() -> void:
	roster = Roster.new()
	roster.rng_seed = rng.randi()
	roster.funding = Research.funding_rule("starting")
	for i in STARTING_OPERATORS:
		roster.recruit(rng)
	roster.add_event("The program is stood up with %d operators." % STARTING_OPERATORS)
	world = WorldSim.create(rng)
	current_op = {}
	deployment.clear()
	last_report = {}
	save_game()


func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Campaign: cannot write %s" % save_path)
		return
	var d: Dictionary = roster.to_dict()
	d["world"] = world.to_dict()
	d["current_op"] = current_op
	f.store_string(JSON.stringify(d, "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	roster = Roster.from_dict(parsed)
	var wd: Variant = parsed.get("world", null)
	world = WorldSim.from_dict(wd) if typeof(wd) == TYPE_DICTIONARY else null
	if world == null:  # older saves (before the network): fresh map, roster kept
		world = WorldSim.create(rng)
		parsed["current_op"] = {}
	current_op = (parsed.get("current_op", {}) as Dictionary).duplicate()
	return true


func recruit_cost() -> int:
	return Research.funding_rule("recruit_cost")


func recruit():
	if roster.funding < recruit_cost():
		return null
	var r = roster.recruit(rng)
	if r != null:
		roster.funding -= recruit_cost()
		roster.add_event("Recruited %s from %s." % [r.full_name(), r.agency_name()])
		save_game()
	return r


func start_research(id: String) -> bool:
	var ok: bool = Research.start(roster, id)
	if ok:
		roster.add_event("Research started: %s." % Research.projects()[id].get("name", id))
		save_game()
	return ok


## End the week without an operation: the enemy moves, the wounded heal, money comes in,
## research moves on. Returns {"news", "funding_lost", "research_finished"}.
func end_week() -> Dictionary:
	current_op = {}
	var out: Dictionary = _week_passes()
	roster.add_event("Week ended without an operation.")
	save_game()
	return out


func stand_down() -> Array[String]:
	var finished: Array[String] = []
	finished.assign(end_week()["research_finished"])
	return finished


## The enemy's turn plus a week on the calendar.
func _week_passes() -> Dictionary:
	var phase: Dictionary = world.enemy_phase(rng, has_global_intel())
	var lost: int = int(phase["funding_lost"])
	if lost > 0:
		roster.funding = maxi(0, roster.funding - lost)
		roster.add_event("Attack landed: budget cut by $%dk." % int(lost / 1000.0))
	var finished: Array[String] = roster.advance_days(DAYS_PER_MISSION)
	return {"news": phase["news"], "funding_lost": lost, "research_finished": finished}


func has_global_intel() -> bool:
	return float(tech_effects().get("global_intel", 0.0)) > 0.0


func move_carrier(zone: String) -> bool:
	var ok: bool = world.move_carrier(zone)
	if ok:
		if not current_op.is_empty() and not world.in_range(str(current_op["region"])):
			current_op = {}
		save_game()
	return ok


## Pick this week's operation on the map (one entry from world.operations_for); the squad
## is chosen at HQ. mode: "kill" or "capture" for a named target, "" otherwise.
func plan_operation(op_in: Dictionary, mode: String = "") -> bool:
	if op_in.is_empty() or not world.in_range(str(op_in.get("region", ""))):
		return false
	var op: Dictionary = op_in.duplicate(true)
	if str(op.get("kind", "")) == "node":
		op["mode"] = "capture" if mode == "capture" else "kill"
		op["title"] = str(op["capture_title"] if op["mode"] == "capture" else op["kill_title"])
	op["name"] = "Operation %s %s" % [OP_WORDS_A[rng.randi() % OP_WORDS_A.size()], OP_WORDS_B[rng.randi() % OP_WORDS_B.size()]]
	current_op = op
	save_game()
	return true


## Where to go after the after-action report: the map, or the end screen if the war is over.
func after_report_scene() -> String:
	return END_SCENE if world.outcome != "" else MAP_SCENE


func cancel_operation() -> void:
	current_op = {}
	save_game()


func tech_effects() -> Dictionary:
	return Research.effects(roster)


func is_deployed() -> bool:
	return not deployment.is_empty()


func deployed_records() -> Array:
	var out: Array = []
	for id in deployment:
		var r = roster.get_by_id(id)
		if r != null:
			out.append(r)
	return out


func deploy(ids: Array) -> void:
	deployment.assign(ids)
	if current_op.has("name"):
		operation_name = str(current_op["name"])
	else:
		operation_name = "Operation %s %s" % [OP_WORDS_A[rng.randi() % OP_WORDS_A.size()], OP_WORDS_B[rng.randi() % OP_WORDS_B.size()]]
	get_tree().paused = false
	get_tree().change_scene_to_file(MISSION_SCENE)


## results: [{"id", "alive", "hp", "max_hp", "kills"}]. Applies everything, saves, shows the AAR.
func finish_mission(results: Array, success: bool, hvt: String = "") -> void:
	last_report = apply_results(results, success, hvt)
	deployment.clear()
	current_op = {}
	save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(AAR_SCENE)


func apply_results(results: Array, success: bool, hvt: String = "") -> Dictionary:
	var date: String = roster.date_string()
	var inj: Dictionary = GameData.injuries()
	var any_dead: bool = results.any(func(x): return not bool(x["alive"]))
	var report: Dictionary = {"operation": operation_name, "date": date, "success": success, "entries": []}
	if not current_op.is_empty():
		report["where"] = "%s, %s  ·  %s" % [current_op.get("city", ""), WorldSim.region_name(str(current_op.get("region", ""))), current_op.get("title", "")]
	roster.missions_run += 1
	var tech: Dictionary = tech_effects()
	var funding_before: int = roster.funding
	if success:
		var reward: float = float(WorldSim.theater_of(str(current_op.get("region", ""))).get("reward", 1.0)) if not current_op.is_empty() else 1.0
		roster.funding += int(Research.funding_rule("success_bonus") * reward)
	roster.add_event("%s: %s." % [operation_name, "objective complete" if success else "objective not completed"])

	for res in results:
		var r = roster.get_by_id(int(res["id"]))
		if r == null:
			continue
		var notes: Array[String] = []
		var kills: int = int(res.get("kills", 0))
		r.missions += 1
		r.kills += kills
		r.xp += 10 + kills * 5
		var outcome: String = "OK"
		var kill_text: String = "" if kills == 0 else (" %d kill%s." % [kills, "" if kills == 1 else "s"])

		if not bool(res["alive"]):
			outcome = "KIA"
			r.status = "kia"
			r.died_on = date
			r.died_in = operation_name
			r.add_log(date, "Killed in action during %s.%s" % [operation_name, kill_text])
		else:
			var max_hp: float = float(res.get("max_hp", 100.0))
			var hp: float = float(res.get("hp", max_hp))
			if hp < max_hp - 0.5:
				var place: String = str(inj["wound_places"][rng.randi() % inj["wound_places"].size()])
				var days: int = maxi(3, ceili((max_hp - hp) * float(inj.get("recovery_days_per_damage", 0.35)) * float(tech.get("recovery", 1.0))))
				r.status = "recovering"
				r.recovery_days = days
				outcome = "WOUNDED"
				notes.append("Wounded (%s), out %d days" % [place, days])
				r.add_log(date, "%s.%s Wounded (%s), out %d days." % [operation_name, kill_text, place, days])
				if hp / max_hp < float(inj.get("critical_fraction", 0.3)) \
						and rng.randf() < float(inj.get("permanent_chance_when_critical", 0.4)) * float(tech.get("permanent_injury", 1.0)):
					var options: Array = (inj["permanent"] as Dictionary).keys().filter(func(k): return not r.injuries.has(k))
					if not options.is_empty():
						var p: String = options[rng.randi() % options.size()]
						r.injuries.append(p)
						var pname: String = str(inj["permanent"][p]["name"])
						notes.append("Permanent injury: " + pname)
						r.add_log(date, "Permanent injury: %s." % pname)
					if not r.traits.has("iron") and rng.randf() < 0.4:
						_earn(r, "iron", date, notes)
			else:
				r.add_log(date, "%s.%s Came home unhurt." % [operation_name, kill_text])
			# Growth from experience.
			if kills > 0:
				_grow(r, "marksmanship", rng.randi_range(1, 2) + mini(kills, 2), notes)
			_grow(r, "composure", rng.randi_range(0, 2), notes)
			_grow(r, "cqb", rng.randi_range(0, 2), notes)
			# Traits.
			if kills >= 2 and not r.traits.has("dead_eye") and rng.randf() < 0.35:
				_earn(r, "dead_eye", date, notes)
			if any_dead:
				if not r.traits.has("shaken") and rng.randf() < 0.35:
					_earn(r, "shaken", date, notes)
				elif not r.traits.has("steady") and rng.randf() < 0.25:
					_earn(r, "steady", date, notes)
			elif r.traits.has("shaken"):
				r.traits.erase("shaken")
				notes.append("No longer shaken")
				r.add_log(date, "Steadied after a clean operation; no longer shaken.")
		report["entries"].append({"id": r.id, "name": r.full_name(), "outcome": outcome, "kills": kills, "notes": notes})

	if hvt != "" and current_op.has("hvt"):
		report["hvt"] = {"outcome": hvt, "alias": str(current_op["hvt"].get("alias", "")), "name": str(current_op["hvt"].get("name", "")), "seed": int(current_op["hvt"].get("seed", 0))}
	report["map_result"] = world.resolve_operation(current_op, success, hvt, rng) if not current_op.is_empty() else []
	var week: Dictionary = _week_passes()
	report["research_finished"] = week["research_finished"]
	report["news"] = week["news"]
	report["funding_lost"] = week["funding_lost"]
	report["funding_gained"] = roster.funding - funding_before
	report["next_date"] = roster.date_string()
	return report


func _grow(r, key: String, amount: int, notes: Array[String]) -> void:
	if amount <= 0:
		return
	var before: int = r.stat(key)
	r.raise_stat(key, amount)
	if r.stat(key) > before:
		notes.append("%s +%d" % [key.capitalize(), r.stat(key) - before])


func _earn(r, trait_id: String, date: String, notes: Array[String]) -> void:
	r.traits.append(trait_id)
	var t: Dictionary = GameData.traits().get(trait_id, {})
	notes.append("New trait: %s" % t.get("name", trait_id))
	r.add_log(date, "Earned trait: %s." % t.get("name", trait_id))
