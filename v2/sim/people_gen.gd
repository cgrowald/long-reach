extends RefCounted
## The person generator (roadmap M1 piece 1, data/v2/people.json). No nodes.
## make(seed, kind) gives one person: guard, prisoner or recruit. Same seed -> same person.
## Everyone has: name, first, last, age, kind, background {id, name, skill}, tech (0-5), motive {id, name, line},
## traits, line, face (the seed for v2/ui/face.gd). Guards add tier, rank, weapon, years. Prisoners add offense.
## Recruits add hook and are shaped like state.people entries (v2/sim/loadout.gd) so they can join directly.

const Content := preload("res://v2/sim/content.gd")
const Portraits := preload("res://v2/sim/portraits.gd")


static func data() -> Dictionary:
	return Content.get_file("people")


static func _pick(rng: RandomNumberGenerator, a: Array):
	return a[rng.randi() % a.size()] if not a.is_empty() else null


static func make(p_seed: int, kind: String) -> Dictionary:
	var D := data()
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var first: String = _pick(rng, D.get("first_names", ["Ana"]))
	var last: String = _pick(rng, D.get("last_names", ["Novak"]))
	var bg: Dictionary = _pick(rng, D.get("backgrounds", [{}]))
	var tr: Array = bg.get("tech", [1, 2])
	var mot: Dictionary = _pick(rng, D.get("motives", [{}]))
	var traits: Array = []
	var pool: Array = (D.get("traits", ["steady"]) as Array).duplicate()
	for i in 1 + int(rng.randf() < 0.4):
		var t = _pick(rng, pool)
		pool.erase(t)
		for pair in D.get("opposites", []):
			if (pair as Array).has(t):
				for o in pair:
					pool.erase(o)
		traits.append(t)
	var p := {
		"name": ("%s %s" % [first, last]).to_upper(), "first": first, "last": last, "kind": kind,
		"age": rng.randi_range(19, 58),
		"background": {"id": bg.get("id", ""), "name": bg.get("name", ""), "skill": bg.get("skill", "")},
		"tech": rng.randi_range(int(tr[0]), int(tr[1])),
		"motive": {"id": mot.get("id", ""), "name": mot.get("name", ""), "line": mot.get("line", "")},
		"traits": traits, "trait": traits[0], "line": bg.get("line", ""),
		"face": "%s %s %d" % [first, last, p_seed % 1000],
	}
	# the face (GPT sheets): prisoners look roughed up; the age fits the face, so the ID card matches the photo
	if kind == "prisoner":
		p["face"] = "%s %s #held" % [first, last]
	var arng := RandomNumberGenerator.new()
	arng.seed = p_seed ^ 0x2a6e
	p["age"] = Portraits.age_for(str(p["face"]), arng)
	match kind:
		"guard":
			var g: Dictionary = D.get("guards", {}).get("low", {})
			p["tier"] = "low"
			p["rank"] = _pick(rng, g.get("ranks", ["Guard"]))
			p["weapon"] = _pick(rng, g.get("weapons", ["service_pistol"]))
			var yr: Array = g.get("years", [1, 19])
			p["years"] = rng.randi_range(int(yr[0]), int(yr[1]))
			p["line"] = _pick(rng, g.get("lines", [""]))
			p["head"] = "cap"
		"prisoner":
			p["offense"] = _pick(rng, D.get("offenses", ["No reason given"]))
			p["days_held"] = rng.randi_range(1, 40)
		"recruit":
			p["hook"] = _pick(rng, D.get("recruit_hooks", [""]))
			p["role"] = {"medic": "medic", "shoot": "point", "tech": "rear", "carry": "breacher"}.get(p["background"]["skill"], "rear")
			p["loyalty"] = int(Content.get_file("economy").get("loyalty_start", 70))
	return p


static func roster(p_seed: int, kind: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(make(hash(str(p_seed) + kind + str(i)), kind))
	return out
