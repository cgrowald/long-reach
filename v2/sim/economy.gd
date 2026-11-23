extends RefCounted
## The economy rules (docs/ECONOMY.md), no nodes: your day job (three random offers, grades rolled per game),
## stealing from work (a morning choice with suspicion), night actions (only big things cost one),
## wages, upkeep and loyalty. Numbers live in data/v2/economy.json.

const Content := preload("res://v2/sim/content.gd")
const Materials := preload("res://v2/sim/materials.gd")


static func data() -> Dictionary:
	return Content.get_file("economy")


static func job_def(id: String) -> Dictionary:
	return data().get("jobs", {}).get(id, {})


# ------------------------------------------------------------------ the job

## Three offers for a new game: every job, in a random order, each with this run's grade range.
static func roll_offers(state: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.world_seed) + "jobs")
	var ids: Array = data().get("jobs", {}).keys()
	ids.shuffle()
	var rolls: Array = data().get("grade_roll", [[2, 3]])
	state.job_offers = []
	for id in ids.slice(0, 3):
		var r: Array = rolls[rng.randi() % rolls.size()]
		state.job_offers.append({"id": id, "lo": int(r[0]), "hi": int(r[1])})


static func take_job(state: RefCounted, offer: Dictionary) -> void:
	state.job = offer["id"]
	state.job_grades = [int(offer["lo"]), int(offer["hi"])]
	state.suspicion = 0.0
	var perk: Dictionary = job_def(state.job).get("perk", {})
	if perk.has("tool") and not state.tools.has(perk["tool"]):
		state.tools.append(perk["tool"])
	if perk.has("unlock") and not state.unlocked_recipes.has(perk["unlock"]):
		state.unlocked_recipes.append(perk["unlock"])
	state.steal_done = true            # day one: you only just got hired


## This morning's choice: "nothing", "little" or "lot". Returns lines for the card.
static func steal(state: RefCounted, choice: String) -> Array:
	var lines: Array = []
	var job := job_def(state.job)
	if job.is_empty():
		return lines
	var sd: Dictionary = data().get("steal", {}).get(choice, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.world_seed) + "steal" + str(state.day))
	var mult := float(sd.get("mult", 0.0))
	var got: Array = []
	var taken := {}                    # id -> [count, grade] (an audit takes it back)
	if mult > 0.0:
		var yields: Dictionary = job.get("yields", {})
		for id in yields:
			var rr: Array = yields[id]
			var n := int(round(rng.randi_range(int(rr[0]), int(rr[1])) * mult))
			if n <= 0:
				continue
			var g := clampi(rng.randi_range(int(state.job_grades[0]), int(state.job_grades[1])) + int(sd.get("grade_bonus", 0)), 1, 5)
			Materials.add(state, id, n, g)
			taken[id] = [n, g]
			got.append("%d %s %s" % [n, Content.get_file("recipes").get("materials", {}).get(id, {}).get("name", id), Materials.stars(g)])
	var sus := float(sd.get("suspicion", 0.0))
	if sus > 0.0:
		sus *= float(job.get("suspicion_mult", 1.0))
	state.suspicion = clampf(state.suspicion + sus, 0.0, 120.0)
	state.steal_done = true
	if not got.is_empty():
		lines.append("You came home with: " + ", ".join(PackedStringArray(got)) + ".")
	else:
		lines.append("You came home with nothing but your pay slip.")
	var th: Dictionary = data().get("suspicion", {})
	var txt: Dictionary = data().get("lines", {})
	if state.suspicion >= float(th.get("fired", 100)):
		lines.append(str(txt.get("fired", "Fired.")))
		state.job = ""
		state.attention = minf(100.0, state.attention + 15.0)
	elif state.suspicion >= float(th.get("audit", 70)) and rng.randf() < 0.5:
		lines.append(str(txt.get("audit", "Audit.")))
		for id in taken:
			Materials.take(state, id, int(taken[id][0]))
		state.attention = minf(100.0, state.attention + 5.0)
	elif state.suspicion >= float(th.get("warn", 40)):
		lines.append(str(txt.get("warn", "")))
	return lines


# ------------------------------------------------------------------ the night

## How many night actions something costs (only big things cost: docs/ECONOMY.md section 7).
static func action_cost(hours: float) -> int:
	return 1 if hours >= float(data().get("action_hours", 1.5)) else 0


static func night_start(state: RefCounted) -> void:
	var n := int(data().get("actions_per_night", 2))
	var job := job_def(state.job)
	if job.has("night_shift_chance"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(state.world_seed) + "shift" + str(state.day))
		if rng.randf() < float(job["night_shift_chance"]):
			n -= 1
			state.flags["night_shift"] = true
		else:
			state.flags.erase("night_shift")
	state.actions = n
	state.actions_max = n


## Overnight: pay, feed your people, loyalty. Returns lines for the night ledger.
static func end_of_day(state: RefCounted) -> Array:
	var lines: Array = []
	var job := job_def(state.job)
	if not job.is_empty():
		state.money += int(job.get("wage", 0))
		lines.append("Pay from %s: +%d cr." % [job.get("place", "work"), int(job.get("wage", 0))])
	var per := int(data().get("upkeep_per_person", 8))
	var people: Array = state.people.filter(func(p) -> bool: return p.get("alive", true) and not p.get("left", false))
	var owed := per * people.size()
	if owed > 0:
		if state.money >= owed:
			state.money -= owed
			lines.append("Fed and paid your %d people: -%d cr." % [people.size(), owed])
			for p in people:
				p["loyalty"] = mini(100, int(p.get("loyalty", 70)) + 2)
		else:
			lines.append("You couldn't pay your people (%d cr owed). They noticed." % owed)
			for p in people:
				p["loyalty"] = int(p.get("loyalty", 70)) - 15
				if int(p["loyalty"]) <= 0:
					p["left"] = true
					lines.append("%s walked out. They know where you live." % p["name"])
					state.attention = minf(100.0, state.attention + 8.0)
	state.suspicion = maxf(0.0, state.suspicion - float(data().get("suspicion", {}).get("decay", 2)))
	state.steal_done = false
	return lines
