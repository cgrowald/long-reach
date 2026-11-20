extends RefCounted
## The organization's people and the campaign calendar. Saved to / loaded from JSON.

const OperatorRecord := preload("res://people/operator_record.gd")
const Recruiter := preload("res://people/recruiter.gd")
const Research := preload("res://people/research.gd")

const START := {"year": 2031, "month": 1, "day": 6, "hour": 12, "minute": 0, "second": 0}
const MAX_ROSTER := 16

var operators: Array = []   # OperatorRecord, including the fallen
var day: int = 0            # days since START
var next_id: int = 1
var missions_run: int = 0
var rng_seed: int = 0
# Organization state.
var funding: int = 0
var research_done: Array[String] = []
var research_current: String = ""
var research_days_left: int = 0
var events: Array[String] = []   # org log: research finished, money, recruits (oldest first)


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


func add_event(text: String) -> void:
	events.append("%s: %s" % [date_string(), text])


## Time passes: the wounded heal, the weekly budget arrives, research moves on.
## Returns research projects finished during this time.
func advance_days(n: int) -> Array[String]:
	day += n
	var budget: int = int(Research.funding_rule("weekly_budget") * n / 7.0)
	funding += budget
	var finished: Array[String] = Research.advance(self, n)
	for name in finished:
		add_event("Research complete: %s." % name)
	for r in operators:
		if r.status == "recovering":
			r.recovery_days -= n
			if r.recovery_days <= 0:
				r.recovery_days = 0
				r.status = "active"
				r.add_log(date_string(), "Cleared to return to duty.")
	return finished


func to_dict() -> Dictionary:
	return {
		"day": day, "next_id": next_id, "missions_run": missions_run, "rng_seed": rng_seed,
		"funding": funding, "research_done": research_done, "research_current": research_current,
		"research_days_left": research_days_left, "events": events,
		"operators": operators.map(func(r): return r.to_dict()),
	}


static func from_dict(d: Dictionary):
	var ro = load("res://people/roster.gd").new()
	ro.day = int(d.get("day", 0))
	ro.next_id = int(d.get("next_id", 1))
	ro.missions_run = int(d.get("missions_run", 0))
	ro.rng_seed = int(d.get("rng_seed", 0))
	ro.funding = int(d.get("funding", Research.funding_rule("starting")))
	ro.research_done.assign(d.get("research_done", []))
	ro.research_current = str(d.get("research_current", ""))
	ro.research_days_left = int(d.get("research_days_left", 0))
	ro.events.assign(d.get("events", []))
	for od in d.get("operators", []):
		ro.operators.append(OperatorRecord.from_dict(od))
	return ro
