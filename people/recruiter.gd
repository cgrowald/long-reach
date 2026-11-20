extends RefCounted
## Generates new operators pulled from a source agency (data/agencies.json).

const GameData := preload("res://sim/game_data.gd")
const OperatorRecord := preload("res://people/operator_record.gd")

const TRAIT_CHANCE := 0.3


static func generate(rng: RandomNumberGenerator, id: int, year: int, taken_callsigns: Array, taken_first: Array = []) -> OperatorRecord:
	var n: Dictionary = GameData.names()
	var agencies: Dictionary = GameData.agencies()
	var agency_ids: Array = agencies.keys()
	var agency_id: String = agency_ids[rng.randi() % agency_ids.size()]
	var agency: Dictionary = agencies[agency_id]

	var r := OperatorRecord.new()
	r.id = id
	r.agency = agency_id
	r.first_name = _unique(rng, n["first"], taken_first)
	r.last_name = _pick(rng, n["last"])
	r.hometown = _pick(rng, n["hometowns"])
	r.callsign = _unique(rng, n["callsigns"], taken_callsigns)
	r.birth_year = year - rng.randi_range(26, 41)
	var classes: Array = agency.get("classes", ["assaulter"])
	r.class_id = str(classes[rng.randi() % classes.size()])
	for key in OperatorRecord.STAT_KEYS:
		var base: int = int(agency.get("stats", {}).get(key, 50))
		r.stats[key] = clampi(base + rng.randi_range(-8, 8), 30, OperatorRecord.STAT_CAP)
	if rng.randf() < TRAIT_CHANCE:
		var positive: Array = GameData.traits().keys().filter(
			func(t): return not bool(GameData.traits()[t].get("negative", false)))
		r.traits.append(str(positive[rng.randi() % positive.size()]))
	r.portrait_seed = rng.randi()
	return r


static func _pick(rng: RandomNumberGenerator, list: Array) -> String:
	return str(list[rng.randi() % list.size()])


static func _unique(rng: RandomNumberGenerator, pool: Array, taken: Array) -> String:
	for i in 30:
		var c: String = _pick(rng, pool)
		if not taken.has(c):
			return c
	return "%s-%d" % [_pick(rng, pool), rng.randi_range(2, 9)]
