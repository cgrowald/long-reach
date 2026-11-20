extends RefCounted
## The organization's people and the campaign calendar. Saved to / loaded from JSON.

const OperatorRecord := preload("res://people/operator_record.gd")
const Recruiter := preload("res://people/recruiter.gd")

const START := {"year": 2031, "month": 1, "day": 6, "hour": 12, "minute": 0, "second": 0}
const MAX_ROSTER := 16

var operators: Array = []   # OperatorRecord, including the fallen
var day: int = 0            # days since START
var next_id: int = 1
var missions_run: int = 0
var rng_seed: int = 0


func date_string() -> String:
	var unix: int = Time.get_unix_time_from_datetime_dict(START) + day * 86400
	return Time.get_date_string_from_unix_time(unix)


func year() -> int:
	return int(date_string().substr(0, 4))


func living() -> Array:
	return operators.filter(func(r): return r.status != "kia")


func fallen() -> Array:
	return operators.filter(func(r): return r.status == "kia")


func get_by_id(id: int):
	for r in operators:
		if r.id == id:
			return r
	return null


func recruit(rng: RandomNumberGenerator):
	if living().size() >= MAX_ROSTER:
		return null
	var taken: Array = operators.map(func(r): return r.callsign)
	var taken_first: Array = living().map(func(r): return r.first_name)
	var r = Recruiter.generate(rng, next_id, year(), taken, taken_first)
	next_id += 1
	r.add_log(date_string(), "Joined from %s." % r.agency_name())
	operators.append(r)
	return r


## Time passes: the wounded heal.
func advance_days(n: int) -> void:
	day += n
	for r in operators:
		if r.status == "recovering":
			r.recovery_days -= n
			if r.recovery_days <= 0:
				r.recovery_days = 0
				r.status = "active"
				r.add_log(date_string(), "Cleared to return to duty.")


func to_dict() -> Dictionary:
	return {
		"day": day, "next_id": next_id, "missions_run": missions_run, "rng_seed": rng_seed,
		"operators": operators.map(func(r): return r.to_dict()),
	}


static func from_dict(d: Dictionary):
	var ro = load("res://people/roster.gd").new()
	ro.day = int(d.get("day", 0))
	ro.next_id = int(d.get("next_id", 1))
	ro.missions_run = int(d.get("missions_run", 0))
	ro.rng_seed = int(d.get("rng_seed", 0))
	for od in d.get("operators", []):
		ro.operators.append(OperatorRecord.from_dict(od))
	return ro
