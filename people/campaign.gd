extends Node
## Autoload "Campaign": owns the saved roster, sends a squad on a mission and writes the
## results back into everyone's record (deaths, wounds, injuries, growth, traits, log).

const Roster := preload("res://people/roster.gd")
const GameData := preload("res://sim/game_data.gd")

const STARTING_OPERATORS := 10
const SQUAD_SIZE := 4
const DAYS_PER_MISSION := 7
const HQ_SCENE := "res://hq/hq.tscn"
const AAR_SCENE := "res://hq/aar.tscn"
const MISSION_SCENE := "res://tactical/main.tscn"

const OP_WORDS_A: Array[String] = ["Iron", "Silent", "Broken", "Hollow", "Northern", "Quiet", "Red", "Long", "Cold", "Black", "Steel", "Distant"]
const OP_WORDS_B: Array[String] = ["Ledger", "Harbor", "Lantern", "Anvil", "Orchard", "Compass", "Bastion", "Meridian", "Thicket", "Gate", "Ember", "Tide"]

var save_path: String = "user://campaign.json"
var roster = null
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
	for i in STARTING_OPERATORS:
		roster.recruit(rng)
	deployment.clear()
	last_report = {}
	save_game()


func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Campaign: cannot write %s" % save_path)
		return
	f.store_string(JSON.stringify(roster.to_dict(), "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	roster = Roster.from_dict(parsed)
	return true


func recruit():
	var r = roster.recruit(rng)
	if r != null:
		save_game()
	return r


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
	operation_name = "Operation %s %s" % [OP_WORDS_A[rng.randi() % OP_WORDS_A.size()], OP_WORDS_B[rng.randi() % OP_WORDS_B.size()]]
	get_tree().paused = false
	get_tree().change_scene_to_file(MISSION_SCENE)


## results: [{"id", "alive", "hp", "max_hp", "kills"}]. Applies everything, saves, shows the AAR.
func finish_mission(results: Array, success: bool) -> void:
	last_report = apply_results(results, success)
	deployment.clear()
	save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(AAR_SCENE)


func apply_results(results: Array, success: bool) -> Dictionary:
	var date: String = roster.date_string()
	var inj: Dictionary = GameData.injuries()
	var any_dead: bool = results.any(func(x): return not bool(x["alive"]))
	var report: Dictionary = {"operation": operation_name, "date": date, "success": success, "entries": []}
	roster.missions_run += 1

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
				var days: int = maxi(3, ceili((max_hp - hp) * float(inj.get("recovery_days_per_damage", 0.35))))
				r.status = "recovering"
				r.recovery_days = days
				outcome = "WOUNDED"
				notes.append("Wounded (%s), out %d days" % [place, days])
				r.add_log(date, "%s.%s Wounded (%s), out %d days." % [operation_name, kill_text, place, days])
				if hp / max_hp < float(inj.get("critical_fraction", 0.3)) \
						and rng.randf() < float(inj.get("permanent_chance_when_critical", 0.4)):
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

	roster.advance_days(DAYS_PER_MISSION)
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
