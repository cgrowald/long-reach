extends RefCounted
## Spending money (data/v2/markets.json, docs/LITERATURE.md section 4). No nodes.
##   shopnet - legal, online, basic, grades 1-2, arrives overnight; "logged" buys raise Bureau attention.
##   lantern - black, on the PC, few items, pricey, delivered to a dead drop overnight, sometimes a scam.
##   curfew  - in person (the sneak dash), most stock, best grades, barter, prices swing, maybe a sting.
## State: state.os["shop"] = {day, offers: {market: [offer]}, orders: [{market, offer, day}], carry: [offer]}.
## An offer: {cat (catalog id), kind, name, qty, grade, price, sold, sting, tell, stall}.

const Content := preload("res://v2/sim/content.gd")
const Materials := preload("res://v2/sim/materials.gd")
const Loadout := preload("res://v2/sim/loadout.gd")


static func data() -> Dictionary:
	return Content.get_file("markets")


static func mdef(market: String) -> Dictionary:
	return data().get("markets", {}).get(market, {})


static func _s(state: RefCounted) -> Dictionary:
	var s: Dictionary = state.os.get("shop", {})
	for k in ["orders", "carry"]:
		if not s.has(k):
			s[k] = []
	if not s.has("offers"):
		s["offers"] = {}
	state.os["shop"] = s
	return s


static func unlocked(state: RefCounted, market: String) -> bool:
	if state.flags.get("markets_open", false):
		return true
	var need := int(mdef(market).get("unlock_trust", 0))
	return need <= 0 or int(state.os.get("market", {}).get("trust", 0)) >= need


static func item_name(kind: String, id: String) -> String:
	match kind:
		"material":
			return str(Content.get_file("recipes").get("materials", {}).get(id, {}).get("name", id))
		"tool":
			return str(Content.get_file("recipes").get("tools", {}).get(id, {}).get("name", id))
		_:
			return str(Loadout.gdef(id).get("name", id))


## Today's stock (rolled once per day, then remembered so "sold" sticks).
static func offers(state: RefCounted, market: String) -> Array:
	var s := _s(state)
	if int(s.get("day", -1)) != int(state.day):
		s["day"] = int(state.day)
		s["offers"] = {}
	var all: Dictionary = s["offers"]
	if not all.has(market):
		all[market] = _roll(state, market)
	return all[market]


static func _roll(state: RefCounted, market: String) -> Array:
	var md := mdef(market)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.world_seed) + market + str(state.day))
	var pool: Array = []
	for c in data().get("catalog", []):
		if (c.get("in", []) as Array).has(market):
			pool.append(c)
	for i in range(pool.size() - 1, 0, -1):          # shuffle, then take today's stock
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	pool = pool.slice(0, mini(pool.size(), int(md.get("stock", 99))))
	var grades: Array = md.get("grades", [1, 2])
	var heat := float(md.get("heat_mult", 0.0)) * float(state.attention) * 100.0
	var out: Array = []
	for c in pool:
		var wob := 1.0 + rng.randf_range(-1.0, 1.0) * float(md.get("wobble", 0.1))
		var price := int(round(float(c["price"]) * float(md.get("price_mult", 1.0)) * wob * (1.0 + heat / 100.0)))
		var o := {"cat": c["id"], "kind": c["kind"], "name": item_name(c["kind"], c["id"]), "qty": int(c.get("qty", 1)),
			"grade": rng.randi_range(int(grades[0]), int(grades[1])) if c["kind"] == "material" else 0,
			"price": maxi(1, price), "sold": false, "sting": false, "tell": "", "logged": int(c.get("logged", 0)) if market == "shopnet" else 0}
		out.append(o)
	if market == "curfew":
		var names: Array = data().get("stall_names", ["A stall"])
		for i in out.size():
			out[i]["stall"] = names[(i + rng.randi()) % names.size()]
		# maybe one stall is the Bureau: cheap, and it shows a tell
		if not out.is_empty() and rng.randf() < float(md.get("sting", 0.0)):
			var o: Dictionary = out[rng.randi() % out.size()]
			o["sting"] = true
			o["price"] = maxi(1, int(round(o["price"] * float(md.get("sting_cut", 0.55)))))
			var tells: Array = data().get("tells", ["Too cheap."])
			o["tell"] = tells[rng.randi() % tells.size()]
	return out


## Buy one offer. Returns {ok: bool, msg: String}.
static func buy(state: RefCounted, market: String, idx: int) -> Dictionary:
	var list := offers(state, market)
	if idx < 0 or idx >= list.size():
		return {"ok": false, "msg": "Gone."}
	var o: Dictionary = list[idx]
	if o["sold"]:
		return {"ok": false, "msg": "Already sold."}
	if o["kind"] == "tool" and state.tools.has(o["cat"]):
		return {"ok": false, "msg": "You already have one."}
	if state.money < int(o["price"]):
		return {"ok": false, "msg": "Not enough money (%d cr)." % int(o["price"])}
	state.money -= int(o["price"])
	o["sold"] = true
	var s := _s(state)
	var md := mdef(market)
	match str(md.get("delivery", "overnight")):
		"carry":
			if o["sting"]:
				return _stung(state, o)
			(s["carry"] as Array).append(o.duplicate())
			return {"ok": true, "msg": "In your bag: %s. Get it home." % o["name"]}
		_:
			(s["orders"] as Array).append({"market": market, "offer": o.duplicate(), "day": int(state.day)})
			var msg := "Ordered %s. It comes tomorrow%s." % [o["name"], " (to the dead drop)" if market == "lantern" else ""]
			if int(o.get("logged", 0)) > 0:
				state.attention = minf(100.0, state.attention + float(o["logged"]))
				state.flags["registered_buys"] = int(state.flags.get("registered_buys", 0)) + 1
				msg += " LOGGED: the purchase is tied to your ID."
			return {"ok": true, "msg": msg}


## A Bureau stall: you lose the money and half of what's in your pockets, and they know a face.
static func _stung(state: RefCounted, o: Dictionary) -> Dictionary:
	var md := mdef("curfew")
	var lose := int(state.money * float(md.get("sting_money", 0.5)))
	state.money -= lose
	state.attention = minf(100.0, state.attention + float(md.get("sting_attention", 20)))
	_s(state)["carry"] = []
	state.flags["stung"] = int(state.flags.get("stung", 0)) + 1
	load("res://v2/sim/krall.gd").bump(state, 2.0, "a Bureau sting at the Tram Yard")
	return {"ok": false, "sting": true, "msg": "STING. Two men from the shed. You ran, and dropped your bag and %d cr. The Bureau has your face now." % lose}


## What the curfew market pays for a unit of your material (barter). 0 = they don't want it.
static func barter_value(state: RefCounted, mat: String) -> int:
	var md := mdef("curfew")
	var base := 0.0
	for c in data().get("catalog", []):
		if c["id"] == mat and c["kind"] == "material":
			base = float(c["price"]) / float(c.get("qty", 1))
	if base <= 0.0:
		base = 5.0
	var bonus := float(md.get("barter_bonus", {}).get(mat, 1.0))
	var g := float(Materials.best(state, mat))
	return maxi(1, int(round(base * float(md.get("barter", 0.5)) * bonus * Materials.grade_mult(g))))


## Trade one unit (your best grade) at the curfew market for credits.
static func barter(state: RefCounted, mat: String) -> int:
	if Materials.total(state, mat) <= 0:
		return 0
	var v := barter_value(state, mat)
	Materials.take(state, mat, 1)
	state.money += v
	return v


static func _grant(state: RefCounted, o: Dictionary, source: String) -> void:
	match str(o["kind"]):
		"material":
			Materials.add(state, o["cat"], int(o["qty"]), int(o.get("grade", 2)))
		"supply":
			state.supplies[o["cat"]] = int(state.supplies.get(o["cat"], 0)) + int(o["qty"])
		"gear":
			for i in int(o["qty"]):
				Loadout.add_item(state, o["cat"], {"source": source})
		"tool":
			if not state.tools.has(o["cat"]):
				state.tools.append(o["cat"])


static func carrying(state: RefCounted) -> Array:
	return _s(state)["carry"]


## Home safe from the curfew market: the bag goes on the shelves. Returns lines.
static func bring_home(state: RefCounted) -> Array:
	var lines: Array = []
	for o in carrying(state):
		_grant(state, o, "The Tram Yard")
		lines.append("%s x%d" % [o["name"], int(o["qty"])])
	_s(state)["carry"] = []
	return lines


## Caught on the way home: the bag is gone.
static func lose_carry(state: RefCounted) -> int:
	var n := carrying(state).size()
	_s(state)["carry"] = []
	return n


## Overnight: ShopNet parcels and Lantern drops arrive (a Lantern order can be a scam). Returns ledger lines.
static func deliver(state: RefCounted) -> Array:
	var lines: Array = []
	var s := _s(state)
	var keep: Array = []
	for od in s["orders"]:
		if int(od["day"]) > int(state.day):
			keep.append(od)
			continue
		var o: Dictionary = od["offer"]
		if load("res://v2/sim/krall.gd").seize_delivery(state):
			lines.append("SEIZED: %s never came. Krall's people took it." % o["name"])
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(state.world_seed) + str(od))
		if od["market"] == "lantern" and rng.randf() < float(mdef("lantern").get("scam", 0.0)):
			lines.append("The Lantern drop for %s was empty. Scammed." % o["name"])
			continue
		_grant(state, o, mdef(od["market"]).get("name", "a shop"))
		lines.append("%s arrived: %s x%d." % ["Parcel" if od["market"] == "shopnet" else "At the dead drop", o["name"], int(o["qty"])])
	s["orders"] = keep
	return lines
