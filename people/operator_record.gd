extends RefCounted
## One person in your organization. Pure data: saved to disk, never touches the scene.
## The tactical layer reads modifiers() to turn stats/traits/injuries into gameplay.

const GameData := preload("res://sim/game_data.gd")

const STAT_KEYS: Array[String] = ["marksmanship", "cqb", "composure", "endurance", "tradecraft"]
const STAT_CAP := 95

var id: int = 0
var first_name: String = ""
var last_name: String = ""
var callsign: String = ""
var birth_year: int = 2000
var hometown: String = ""
var agency: String = ""
var class_id: String = "assaulter"
var stats: Dictionary = {}
var traits: Array[String] = []
var injuries: Array[String] = []     # permanent injury ids
var status: String = "active"       # active | recovering | kia
var recovery_days: int = 0
var missions: int = 0
var kills: int = 0
var xp: int = 0
var service_log: Array[String] = []  # oldest first: "2031-01-12: ..."
var died_on: String = ""
var died_in: String = ""
var portrait_seed: int = 0


func full_name() -> String:
	return "%s \"%s\" %s" % [first_name, callsign, last_name]


func age(year: int) -> int:
	return year - birth_year


func is_available() -> bool:
	return status == "active"


func class_name_label() -> String:
	return str(GameData.class_def(class_id).get("name", class_id))


func agency_name() -> String:
	return str(GameData.agencies().get(agency, {}).get("name", agency))


func add_log(date: String, text: String) -> void:
	service_log.append("%s: %s" % [date, text])


func stat(key: String) -> int:
	return int(stats.get(key, 50))


func raise_stat(key: String, amount: int) -> void:
	stats[key] = mini(stat(key) + amount, STAT_CAP)


## Multipliers the tactical unit applies: accuracy, reaction (lower = faster), speed, hp.
func modifiers() -> Dictionary:
	var m: Dictionary = {
		"accuracy": 0.7 + stat("marksmanship") * 0.006,   # 50 -> 1.0, 70 -> 1.12
		"reaction": 1.3 - stat("composure") * 0.006,      # 50 -> 1.0, 70 -> 0.88
		"speed": 0.85 + stat("endurance") * 0.003,        # 50 -> 1.0, 70 -> 1.06
		"hp": 0.85 + stat("endurance") * 0.003,
	}
	var all_traits: Dictionary = GameData.traits()
	for t in traits:
		_apply_effects(m, all_traits.get(t, {}).get("effects", {}))
	var perm: Dictionary = GameData.injuries().get("permanent", {})
	for inj in injuries:
		_apply_effects(m, perm.get(inj, {}).get("effects", {}))
	return m


static func _apply_effects(m: Dictionary, effects: Dictionary) -> void:
	for k in effects:
		m[k] = float(m.get(k, 1.0)) * float(effects[k])


func to_dict() -> Dictionary:
	return {
		"id": id, "first_name": first_name, "last_name": last_name, "callsign": callsign,
		"birth_year": birth_year, "hometown": hometown, "agency": agency, "class_id": class_id,
		"stats": stats, "traits": traits, "injuries": injuries, "status": status,
		"recovery_days": recovery_days, "missions": missions, "kills": kills, "xp": xp,
		"service_log": service_log, "died_on": died_on, "died_in": died_in,
		"portrait_seed": portrait_seed,
	}


static func from_dict(d: Dictionary):
	var r = load("res://people/operator_record.gd").new()
	r.id = int(d.get("id", 0))
	r.first_name = str(d.get("first_name", ""))
	r.last_name = str(d.get("last_name", ""))
	r.callsign = str(d.get("callsign", ""))
	r.birth_year = int(d.get("birth_year", 2000))
	r.hometown = str(d.get("hometown", ""))
	r.agency = str(d.get("agency", ""))
	r.class_id = str(d.get("class_id", "assaulter"))
	r.stats = (d.get("stats", {}) as Dictionary).duplicate()
	for k in r.stats:
		r.stats[k] = int(r.stats[k])
	r.traits.assign(d.get("traits", []))
	r.injuries.assign(d.get("injuries", []))
	r.status = str(d.get("status", "active"))
	r.recovery_days = int(d.get("recovery_days", 0))
	r.missions = int(d.get("missions", 0))
	r.kills = int(d.get("kills", 0))
	r.xp = int(d.get("xp", 0))
	r.service_log.assign(d.get("service_log", []))
	r.died_on = str(d.get("died_on", ""))
	r.died_in = str(d.get("died_in", ""))
	r.portrait_seed = int(d.get("portrait_seed", 0))
	return r
