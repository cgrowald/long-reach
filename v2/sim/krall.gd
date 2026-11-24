extends RefCounted
## Inspector Krall's ladder (roadmap M1 piece 13, user 2026-11-23). No nodes.
## A clock counts nights to his next step. When it runs out he climbs a step:
##   1 someone you've been near is questioned (a coworker, a neighbour, a stall keeper, family, one of your people)
##   2 your next delivery is intercepted
##   3 the garage is searched (announced the night before: hide the stash for a night action, or lose part of it)
## then he starts again from 1, faster. Ops and slips (bump) speed the clock up; destroying evidence (push_back) slows it.
## At first the steps are far away, then they close in on your ops. State: state.flags.krall.

const People := preload("res://v2/sim/people_gen.gd")

const BASE_NIGHTS := 7
const STEP_NAMES := ["", "QUESTIONING", "INTERCEPT", "SEARCH"]


static func k(state: RefCounted) -> Dictionary:
	var d: Dictionary = state.flags.get("krall", {})
	if not d.has("step"):
		d["step"] = 0                 # the last step taken (0 = nothing yet)
		d["clock"] = float(BASE_NIGHTS)
		d["rounds"] = 0               # times he's been all the way up the ladder
		d["log"] = []
		d["search_due"] = false
		d["hidden"] = false
		d["intercept"] = false
	state.flags["krall"] = d
	return d


static func next_step(state: RefCounted) -> int:
	return int(k(state)["step"]) % 3 + 1


static func nights_left(state: RefCounted) -> int:
	return maxi(0, int(ceil(float(k(state)["clock"]))))


## For the HUD and the corkboard: "KRALL: QUESTIONING in 3 nights".
static func summary(state: RefCounted) -> String:
	var d := k(state)
	if d["search_due"]:
		return "KRALL: SEARCH TOMORROW"
	return "KRALL: %s in %d night%s" % [STEP_NAMES[next_step(state)], nights_left(state), "" if nights_left(state) == 1 else "s"]


## Something he can use: an op, a cut-out hack, a sting. nights = how much closer it brings him.
static func bump(state: RefCounted, nights: float, why: String) -> void:
	var d := k(state)
	d["clock"] = maxf(0.0, float(d["clock"]) - nights)
	(d["log"] as Array).append({"day": state.day, "text": why})


## Destroying evidence (a WIPE, an op that burns records): his clock goes back.
static func push_back(state: RefCounted, nights: float, why: String) -> void:
	var d := k(state)
	d["clock"] = float(d["clock"]) + nights
	(d["log"] as Array).append({"day": state.day, "text": why})


## Someone you've been near (for the questioning).
static func _witness(state: RefCounted, rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	var econ: Dictionary = load("res://v2/sim/economy.gd").job_def(state.job)
	if not econ.is_empty():
		var c := People.make(hash(str(state.world_seed) + "coworker"), "recruit")
		pool.append("%s, who works next to you at %s" % [c["first"], econ.get("place", "work")])
	var nb := People.make(hash(str(state.world_seed) + "neighbour"), "recruit")
	pool.append("%s, your neighbour across the street" % nb["first"])
	pool.append("Hana's sister")
	if state.flags.get("markets_open", false) or int(state.os.get("market", {}).get("trust", 0)) >= 5:
		pool.append("a stall keeper at the Tram Yard")
	for p in state.people:
		if p.get("alive", true):
			pool.append("%s's mother" % str(p["name"]).split(" ")[0].capitalize())
	return pool[rng.randi() % pool.size()]


## Overnight. Returns ledger lines.
static func night(state: RefCounted) -> Array:
	var d := k(state)
	var lines: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.world_seed) + "krall" + str(state.day))
	# a search that was announced last night happens now
	if d["search_due"]:
		d["search_due"] = false
		if d["hidden"]:
			lines.append("KRALL'S MEN SEARCHED THE GARAGE. They found nothing. The stash was hidden.")
		else:
			lines.append_array(_search(state))
		d["hidden"] = false
		d["step"] = 0
		d["rounds"] = int(d["rounds"]) + 1
		d["clock"] = maxf(3.0, float(BASE_NIGHTS) - 1.5 * int(d["rounds"]))
		return lines
	d["clock"] = float(d["clock"]) - 1.0
	if float(d["clock"]) > 0.0:
		return lines
	var step := next_step(state)
	d["step"] = step
	match step:
		1:
			lines.append("Krall's people questioned %s. They asked about you, and about the lights in your garage." % _witness(state, rng))
			state.pool = maxi(1, int(state.pool * 0.85))
		2:
			d["intercept"] = true
			lines.append("Krall flagged your deliveries. The next parcel or crate meant for you will be seized.")
		3:
			d["search_due"] = true
			lines.append("WARNING: Krall has a warrant. They search the garage TOMORROW NIGHT. Hide the stash (the corkboard) or lose part of it.")
	if step != 3:
		d["clock"] = maxf(2.0, float(BASE_NIGHTS) - 1.5 * int(d["rounds"]) - step)
	return lines


## Hide the stash before a search (costs a night action, spent by the caller).
static func hide(state: RefCounted) -> void:
	k(state)["hidden"] = true


## The search: half your materials, every intel file, and weapons nobody is carrying.
static func _search(state: RefCounted) -> Array:
	var lines: Array = ["KRALL'S MEN SEARCHED THE GARAGE."]
	var lost_mats := 0
	for id in state.materials.keys():
		var n := int(state.materials[id]) / 2
		if n > 0:
			load("res://v2/sim/materials.gd").take(state, id, n)
			lost_mats += n
	var gone: Array = []
	for it in state.items.duplicate():
		if it.get("type", "") == "intel" or (it.has("gear") and not it.has("on") and str(load("res://v2/sim/loadout.gd").gdef(it["gear"]).get("weapon", "")) != ""):
			state.items.erase(it)
			gone.append(it.get("name", "?"))
	lines.append("They took %d materials and %d things: %s." % [lost_mats, gone.size(), ", ".join(PackedStringArray(gone.slice(0, 5))) if not gone.is_empty() else "nothing else"])
	state.attention = minf(100.0, state.attention + 10.0)
	return lines


## Deliveries check this before they land: true = seized (and the flag clears).
static func seize_delivery(state: RefCounted) -> bool:
	var d := k(state)
	if d["intercept"]:
		d["intercept"] = false
		return true
	return false


# ------------------------------------------------------------------ Bureau notes (D, coming home)
# One cause, one visible follow-up (GPT notes, CONNECTED_LOOP section 8): something you did, in the Bureau's words,
# and what it does to Krall's clock. Shown in the Bureau corner of the TONIGHT board and on the next morning card.

## Log what the Bureau learned and bring Krall that much closer.
static func note(state: RefCounted, text: String, nights: float, why: String) -> void:
	bump(state, nights, why)
	var notes: Array = state.flags.get("bureau_notes", [])
	notes.append({"day": state.day, "text": text, "nights": nights, "seen": false})
	state.flags["bureau_notes"] = notes.slice(-8)


## The newest note, or {} (only recent ones: a week).
static func latest_note(state: RefCounted) -> Dictionary:
	var notes: Array = state.flags.get("bureau_notes", [])
	if notes.is_empty():
		return {}
	var n: Dictionary = notes[-1]
	return n if int(state.day) - int(n["day"]) <= 7 else {}


## Notes the morning card hasn't shown yet (marks them shown).
static func unseen_notes(state: RefCounted) -> Array:
	var out: Array = []
	for n in state.flags.get("bureau_notes", []):
		if not n.get("seen", false):
			n["seen"] = true
			out.append(n)
	return out
