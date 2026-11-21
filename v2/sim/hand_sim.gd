extends RefCounted
## BREACH HAND rules (Balatro-style hack). A deck of packet cards: four ports (suits) x values 2-10.
## Play 1-5 cards as a "protocol" (poker hand). Score = (base chips + card values) x mult.
## Each play costs 2 trace, each reroute (discard) 1. Fill the trace and you're TRACED (score halved).

const SUITS := ["SSH", "MAIL", "CAM", "BADGE"]
## key: [name, chips, mult, rank]
const HANDS := {
	"zero": ["ZERO-DAY", 100, 8, 8],
	"root": ["ROOT ACCESS", 60, 7, 7],
	"cred": ["CREDENTIAL STUFFING", 40, 4, 6],
	"tunnel": ["TUNNEL", 35, 4, 5],
	"scan": ["PORT SCAN", 30, 4, 4],
	"brute": ["BRUTE FORCE", 30, 3, 3],
	"dbl": ["DOUBLE HANDSHAKE", 20, 2, 2],
	"hand": ["HANDSHAKE", 10, 2, 1],
	"ping": ["PING", 5, 1, 0],
}
const HAND_SIZE := 7
const TRACE_MAX := 10
const PLAY_COST := 2
const REROUTE_COST := 1

var rng := RandomNumberGenerator.new()
var deck: Array = []
var hand: Array = []
var mods := {}
var trace := 0
var score := 0
var plays := 0
var quiet_left := 2
var traced := false
## Today's rule: MAIL packets score 0 chips.
var mail_rule := true


func setup(seed: int, m: Dictionary) -> void:
	rng.seed = seed
	mods = m
	deck.clear()
	hand.clear()
	for s in SUITS:
		for r in range(2, 11):
			deck.append({"r": r, "s": s})
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	draw()


func draw() -> Array:
	var drawn: Array = []
	while hand.size() < HAND_SIZE and not deck.is_empty():
		var c = deck.pop_back()
		hand.append(c)
		drawn.append(c)
	sort_hand()
	return drawn


func sort_hand() -> void:
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["r"]) != int(b["r"]):
			return int(a["r"]) > int(b["r"])
		return str(a["s"]) < str(b["s"]))


func final_score() -> int:
	return score / 2 if traced else score


static func evaluate(cards: Array) -> Dictionary:
	var by_rank := {}
	for i in cards.size():
		var r: int = cards[i]["r"]
		if not by_rank.has(r):
			by_rank[r] = []
		by_rank[r].append(i)
	var groups: Array = by_rank.values()
	groups.sort_custom(func(a: Array, b: Array) -> bool:
		if a.size() != b.size():
			return a.size() > b.size()
		return int(cards[a[0]]["r"]) > int(cards[b[0]]["r"]))
	var all: Array = range(cards.size())
	var flush := cards.size() == 5
	for c in cards:
		if c["s"] != cards[0]["s"]:
			flush = false
	var straight := false
	if cards.size() == 5 and by_rank.size() == 5:
		var ranks: Array = by_rank.keys()
		straight = int(ranks.max()) - int(ranks.min()) == 4
	if straight and flush:
		return {"key": "zero", "scoring": all}
	if groups[0].size() == 4:
		return {"key": "root", "scoring": groups[0]}
	if groups[0].size() == 3 and groups.size() > 1 and groups[1].size() >= 2:
		return {"key": "cred", "scoring": all}
	if flush:
		return {"key": "tunnel", "scoring": all}
	if straight:
		return {"key": "scan", "scoring": all}
	if groups[0].size() == 3:
		return {"key": "brute", "scoring": groups[0]}
	if groups[0].size() == 2 and groups.size() > 1 and groups[1].size() == 2:
		return {"key": "dbl", "scoring": groups[0] + groups[1]}
	if groups[0].size() == 2:
		return {"key": "hand", "scoring": groups[0]}
	return {"key": "ping", "scoring": [groups[0][0]]}


## The full scoring breakdown of a play, step by step (for the animation).
func score_play(cards: Array) -> Dictionary:
	var ev := evaluate(cards)
	var info: Array = HANDS[ev["key"]]
	var chips: int = info[1]
	var mult: float = info[2]
	var steps: Array = []
	for i in ev["scoring"]:
		var c: Dictionary = cards[i]
		var blocked: bool = mail_rule and c["s"] == "MAIL"
		var v: int = 0 if blocked else int(c["r"])
		chips += v
		steps.append({"k": "card", "i": i, "chips": v, "blocked": blocked})
		if mods.get("camloop", false) and c["s"] == "CAM":
			chips += 15
			steps.append({"k": "cart", "id": "camloop", "chips": 15, "text": "+15 CHIPS"})
	if mods.get("sticky", false) and cards.any(func(c: Dictionary) -> bool: return c["s"] == "MAIL"):
		mult += 4.0
		steps.append({"k": "cart", "id": "sticky", "mult": 4.0, "text": "+4 MULT"})
	if mods.get("brute", false) and int(info[3]) >= 3:
		mult *= 2.0
		steps.append({"k": "cart", "id": "brute", "xmult": 2.0, "text": "x2 MULT"})
	return {"key": ev["key"], "name": info[0], "base_chips": info[1], "base_mult": float(info[2]),
		"steps": steps, "chips": chips, "mult": mult, "total": int(chips * mult)}


func play(idxs: Array) -> Dictionary:
	var sorted := idxs.duplicate()
	sorted.sort()
	var cards: Array = sorted.map(func(i: int) -> Dictionary: return hand[i])
	var res := score_play(cards)
	res["cards"] = cards
	score += int(res["total"])
	trace += PLAY_COST
	plays += 1
	_remove(sorted)
	res["drawn"] = draw()
	if trace >= TRACE_MAX:
		traced = true
	return res


func reroute(idxs: Array) -> Dictionary:
	var cost := REROUTE_COST
	if mods.get("quiet", false) and quiet_left > 0:
		quiet_left -= 1
		cost = 0
	trace += cost
	var sorted := idxs.duplicate()
	sorted.sort()
	var gone: Array = sorted.map(func(i: int) -> Dictionary: return hand[i])
	_remove(sorted)
	var drawn := draw()
	if trace >= TRACE_MAX:
		traced = true
	return {"cost": cost, "gone": gone, "drawn": drawn}


func _remove(sorted_idxs: Array) -> void:
	for k in range(sorted_idxs.size() - 1, -1, -1):
		hand.remove_at(int(sorted_idxs[k]))
