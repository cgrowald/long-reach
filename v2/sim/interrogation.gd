extends RefCounted
## The prisoner in the garage (roadmap M1 piece 12, user 2026-11-23). No nodes.
## Pressure, bluffing, bargaining and leverage only: no violence on screen, and a death is a ledger line
## ("we don't need to glorify killing people that can't fight back").
## Each card moves BREAK (they talk at 60) and TRUST (your chance to recruit them), depending on their motive
## and traits. Four cards, then you decide:
##   LET GO  - costs nothing now, but they talk: Krall comes closer
##   KILL    - off-screen; your people whose motive can't stomach it lose loyalty, revenge types don't mind
##   RECRUIT - a chance by trust; they join with low loyalty (they're likelier to dislike your calls), and a
##             low-trust recruit can be an informant
## State: state.flags.prisoner (the person) + .grill {break, trust, rounds, said: []}.

const Krall := preload("res://v2/sim/krall.gd")
const Loadout := preload("res://v2/sim/loadout.gd")

const ROUNDS := 4
const CARDS := {
	"reason": {"name": "REASON", "text": "Talk about what the regime did to people like them."},
	"threaten": {"name": "THREATEN", "text": "Lean in. Let them imagine the worst. (Words only.)"},
	"bargain": {"name": "BARGAIN", "text": "Offer money and a way out of town."},
	"kindness": {"name": "KINDNESS", "text": "Untie a hand. Water, a cigarette, their family's names."},
	"bluff": {"name": "BLUFF", "text": "Pretend you already know everything."},
	"leverage": {"name": "LEVERAGE", "text": "Show them the dirt you hacked on them."},
}
# how a motive takes each card: [break, trust]
const MOTIVE := {
	"grief": {"reason": [25, 15], "threaten": [5, -10], "bargain": [5, 0], "kindness": [15, 20]},
	"money": {"reason": [5, 0], "threaten": [15, -10], "bargain": [35, 15], "kindness": [10, 5]},
	"pride": {"reason": [10, 5], "threaten": [-5, -15], "bargain": [10, 5], "kindness": [5, 10]},
	"family": {"reason": [15, 10], "threaten": [30, -20], "bargain": [15, 10], "kindness": [25, 25]},
	"belief": {"reason": [30, 20], "threaten": [0, -10], "bargain": [0, -5], "kindness": [10, 10]},
	"friendship": {"reason": [15, 10], "threaten": [10, -10], "bargain": [10, 5], "kindness": [20, 20]},
	"revenge": {"reason": [20, 10], "threaten": [5, -5], "bargain": [10, 0], "kindness": [5, 5]},
	"thrill": {"reason": [10, 10], "threaten": [5, 5], "bargain": [15, 5], "kindness": [5, 5]},
}
const TRAIT := {"stubborn": -10, "cold": -8, "jumpy": 10, "kind": 5, "careful": -5, "loud": 5}


static func prisoner(state: RefCounted) -> Dictionary:
	return state.flags.get("prisoner", {})


static func grill(state: RefCounted) -> Dictionary:
	var p := prisoner(state)
	if not p.has("grill"):
		p["grill"] = {"break": 0, "trust": 10, "rounds": 0, "said": [], "talked": false}
	return p["grill"]


static func has_dirt(state: RefCounted) -> bool:
	var p := prisoner(state)
	for it in state.items:
		if it.get("type", "") == "intel" and it.get("tag", "") == "dirt" and str(p.get("last", "")).to_lower() in str(it.get("name", "") + it.get("person", "")).to_lower():
			return true
	return false


static func has_plan(state: RefCounted) -> bool:
	for it in state.items:
		if it.get("type", "") == "intel" and it.get("tag", "") == "plan":
			return true
	return false


## Play a card. Returns {line: what they say, break: delta, trust: delta}.
static func play(state: RefCounted, card: String) -> Dictionary:
	var p := prisoner(state)
	var g := grill(state)
	if int(g["rounds"]) >= ROUNDS:
		return {"line": "They've stopped listening.", "break": 0, "trust": 0}
	var mot: String = str(p.get("motive", {}).get("id", "money"))
	var bt: Array = MOTIVE.get(mot, MOTIVE["money"]).get(card, [10, 0])
	var b := int(bt[0])
	var tr := int(bt[1])
	for t in p.get("traits", []):
		b += int(TRAIT.get(t, 0))
	var line := ""
	match card:
		"leverage":
			if has_dirt(state):
				b = 55
				tr = -5
				line = "...where did you get that? Fine. FINE. What do you want?"
			else:
				b = -10
				line = "You've got nothing on me. Nothing."
		"bluff":
			if has_plan(state):
				b = 25
				line = "If you know all that, why am I here?"
			else:
				b = -15
				tr -= 10
				line = "You're lying. I can see it."
		_:
			if b >= 25:
				line = ["...", "They never told us anything either.", "My kids. Leave my kids out of it.", "How much? How much exactly?"][(hash(card + mot) & 0x7fffffff) % 4]
			elif b >= 10:
				line = ["I don't know anything. I check boxes.", "Maybe. Maybe not.", "Keep talking."][(hash(card) & 0x7fffffff) % 3]
			else:
				line = ["Go to hell.", "You'll hang for this.", "Nice try."][(hash(card + str(g["rounds"])) & 0x7fffffff) % 3]
	g["break"] = clampi(int(g["break"]) + b, 0, 100)
	g["trust"] = clampi(int(g["trust"]) + tr, 0, 100)
	g["rounds"] = int(g["rounds"]) + 1
	(g["said"] as Array).append({"card": card, "line": line})
	if int(g["break"]) >= 60 and not g["talked"]:
		g["talked"] = true
		var told := _talk(state)
		(g["said"] as Array).append({"card": "", "line": told})
	return {"line": line, "break": b, "trust": tr}


## They break: what they give up (depends on who they are).
static func _talk(state: RefCounted) -> String:
	var p := prisoner(state)
	if p.get("kind", "") == "prisoner":
		state.os["market"] = state.os.get("market", {})
		var leads := int(state.os["market"].get("leads", 0)) + 1
		state.os["market"]["leads"] = leads
		return "\"There are others in those cells. Names. People who'd help you.\" (+1 recruit lead)"
	Krall.push_back(state, 2.0, "the prisoner told you Krall's patrol schedule")
	return "\"Krall's men change shifts at four. He's watching the depots.\" (Krall pushed back 2 nights)"


static func recruit_chance(state: RefCounted) -> float:
	var g := grill(state)
	var base := 0.25 if prisoner(state).get("kind", "") == "prisoner" else 0.05
	return clampf(base + float(g["trust"]) / 100.0, 0.05, 0.9)


## The end. choice = "let_go", "kill", "recruit". Returns lines for the ledger.
static func decide(state: RefCounted, choice: String, roll: float) -> Array:
	var p := prisoner(state)
	var lines: Array = []
	match choice:
		"let_go":
			Krall.bump(state, 1.5, "a released prisoner talked")
			lines.append("You cut the ropes and walked %s to the end of the street. They'll talk; you knew that." % p.get("first", "them"))
			_mood(state, "let_go", lines)
		"kill":
			lines.append("%s didn't leave the garage. Nobody says anything about it." % p.get("first", "They"))
			state.attention = minf(100.0, state.attention + 5.0)
			_mood(state, "kill_prisoner", lines)
		"recruit":
			if roll < recruit_chance(state):
				var np := p.duplicate(true)
				np.erase("grill")
				np["id"] = "p%d" % (state.people.size() + 10 + state.day)
				np["alive"] = true
				np["level"] = 1
				np["ops"] = 0
				np["loyalty"] = 50
				np["kit"] = {}
				np["grid"] = []
				np["role"] = np.get("role", "rear")
				if roll > recruit_chance(state) * 0.75 and int(grill(state)["trust"]) < 35:
					np["informant"] = true            # hidden: a low-trust turn can be Krall's
				state.people.append(np)
				lines.append("%s is with you now. Loyalty is thin." % np["name"])
				_mood(state, "recruit", lines)
			else:
				lines.append("%s laughed at the offer. You let them go; it was that or worse." % p.get("first", "They"))
				Krall.bump(state, 1.5, "a refused recruit talked")
	state.flags.erase("prisoner")
	return lines


## How your people take it (their motives like or dislike what you did).
static func _mood(state: RefCounted, act: String, lines: Array) -> void:
	var motives: Dictionary = {}
	for m in load("res://v2/sim/content.gd").get_file("people").get("motives", []):
		motives[m["id"]] = m
	for q in state.people:
		if not q.get("alive", true):
			continue
		var mid: String = str(q.get("motive", {}).get("id", "")) if q.get("motive") is Dictionary else str(q.get("motive", ""))
		var m: Dictionary = motives.get(mid, {})
		if (m.get("dislikes", []) as Array).has(act):
			q["loyalty"] = int(q.get("loyalty", 70)) - 12
			lines.append("%s won't look at you." % str(q["name"]).split(" ")[0].capitalize())
		elif (m.get("likes", []) as Array).has(act):
			q["loyalty"] = mini(100, int(q.get("loyalty", 70)) + 6)
			lines.append("%s nods." % str(q["name"]).split(" ")[0].capitalize())
