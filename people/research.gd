extends RefCounted
## Research rules: project status, starting, progress over days, and the combined
## effects of finished tech. Works on the roster's org state (funding, research fields).

const GameData := preload("res://sim/game_data.gd")

## How each effect key combines across finished projects.
const MULTIPLY: Array[String] = ["accuracy", "hp", "recovery", "permanent_injury", "breach_radius"]
const ADD: Array[String] = ["breach_charges"]
const MAX: Array[String] = ["heartbeat_range", "heartbeat_all"]
const MIN: Array[String] = ["shot_noise"]


static func data() -> Dictionary:
	return GameData.load_json("res://data/research.json")


static func projects() -> Dictionary:
	return data().get("projects", {})


static func funding_rule(key: String) -> int:
	return int(data().get("funding", {}).get(key, 0))


## done | active | available | locked (missing prerequisite) | planned (needs a later milestone)
static func status(ro, id: String) -> String:
	if ro.research_done.has(id):
		return "done"
	if ro.research_current == id:
		return "active"
	var p: Dictionary = projects().get(id, {})
	if p.has("needs_milestone"):
		return "planned"
	for req in p.get("requires", []):
		if not ro.research_done.has(req):
			return "locked"
	return "available"


static func can_start(ro, id: String) -> bool:
	return status(ro, id) == "available" and ro.research_current == "" \
		and ro.funding >= int(projects()[id].get("cost", 0))


static func start(ro, id: String) -> bool:
	if not can_start(ro, id):
		return false
	var p: Dictionary = projects()[id]
	ro.funding -= int(p.get("cost", 0))
	ro.research_current = id
	ro.research_days_left = int(p.get("days", 7))
	return true


## Moves research forward. Returns names of projects finished.
static func advance(ro, days: int) -> Array[String]:
	var finished: Array[String] = []
	if ro.research_current == "":
		return finished
	ro.research_days_left -= days
	if ro.research_days_left <= 0:
		finished.append(str(projects().get(ro.research_current, {}).get("name", ro.research_current)))
		ro.research_done.append(ro.research_current)
		ro.research_current = ""
		ro.research_days_left = 0
	return finished


## Combined effects of everything researched so far.
static func effects(ro) -> Dictionary:
	var out: Dictionary = {}
	var all: Dictionary = projects()
	for id in ro.research_done:
		var fx: Dictionary = all.get(id, {}).get("effects", {})
		for k in fx:
			var v: float = float(fx[k])
			if not out.has(k):
				out[k] = v
			elif k in MULTIPLY:
				out[k] = float(out[k]) * v
			elif k in ADD:
				out[k] = float(out[k]) + v
			elif k in MAX:
				out[k] = maxf(float(out[k]), v)
			elif k in MIN:
				out[k] = minf(float(out[k]), v)
	return out
