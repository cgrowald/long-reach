extends RefCounted
## What you do with stolen files (docs/HEARTH_OS.md "Build 5"): each intel file is either SOLD to the fixer
## (money now; the price of a kind drops the more of it you sell; trust opens the black market later) or
## POSTED on Nod from an anonymous account (followers; every so many followers = a recruit lead; posting
## heats the account and at 100 it's burned: a new account starts from zero followers).
## State lives in state.os["market"]: {sold: {tag: n}, trust: int, followers: int, acct_heat: float,
## acct: int (account number), burned: int, leads: int}.

const Content := preload("res://v2/sim/content.gd")


static func _m(state: RefCounted) -> Dictionary:
	var m: Dictionary = state.os.get("market", {})
	for k in ["trust", "followers", "acct", "burned", "leads"]:
		if not m.has(k):
			m[k] = 0
	if not m.has("sold"):
		m["sold"] = {}
	if not m.has("acct_heat"):
		m["acct_heat"] = 0.0
	state.os["market"] = m
	return m


static func cfg() -> Dictionary:
	return Content.get_file("hacking")


static func intel(state: RefCounted) -> Array:
	var out: Array = []
	for it in state.items:
		if it.get("type", "") == "intel":
			out.append(it)
	return out


static func price(state: RefCounted, item: Dictionary) -> int:
	var s: Dictionary = cfg().get("sell", {})
	var base := float(s.get(item.get("tag", ""), 10))
	var n := int(_m(state)["sold"].get(item.get("tag", ""), 0))
	var k := maxf(float(s.get("floor", 0.3)), 1.0 - float(s.get("drop", 0.15)) * n)
	return int(round(base * k))


static func followers_for(item: Dictionary) -> int:
	return int(cfg().get("post", {}).get(item.get("tag", ""), 10))


static func heat_for(item: Dictionary) -> float:
	return float(cfg().get("post", {}).get("heat", {}).get(item.get("tag", ""), 10))


static func handle(state: RefCounted) -> String:
	var m := _m(state)
	var names := ["quiet_kettle", "ninth_lamp", "harbour_rain", "old_bridge", "tannery_cat", "ring_road_owl"]
	return "@%s_%d" % [names[int(m["acct"]) % names.size()], 10 + int(m["acct"]) * 7]


static func _remove(state: RefCounted, item: Dictionary) -> void:
	for i in state.items.size():
		if int(state.items[i].get("id", -1)) == int(item.get("id", -2)):
			state.items.remove_at(i)
			return


## Sell to the fixer. Returns the money paid.
static func sell(state: RefCounted, item: Dictionary) -> int:
	var cr := price(state, item)
	var m := _m(state)
	var tag := str(item.get("tag", ""))
	m["sold"][tag] = int(m["sold"].get(tag, 0)) + 1
	m["trust"] = int(m["trust"]) + 1
	state.money += cr
	_remove(state, item)
	return cr


## Post on Nod. Returns {followers, leads, burned}.
static func post(state: RefCounted, item: Dictionary) -> Dictionary:
	var m := _m(state)
	var p: Dictionary = cfg().get("post", {})
	var gain := followers_for(item)
	var before := int(m["followers"])
	m["followers"] = before + gain
	var every := int(p.get("recruit_every", 150))
	var new_leads := int(m["followers"]) / every - before / every
	m["leads"] = int(m["leads"]) + new_leads
	m["acct_heat"] = float(m["acct_heat"]) + heat_for(item)
	state.attention = minf(100.0, state.attention + heat_for(item) * 0.05)
	var burned := false
	if float(m["acct_heat"]) >= float(p.get("burn_at", 100)):
		burned = true
		m["burned"] = int(m["burned"]) + 1
		m["acct"] = int(m["acct"]) + 1
		m["acct_heat"] = 0.0
		m["followers"] = 0
	_remove(state, item)
	return {"followers": gain, "leads": new_leads, "burned": burned}


static func market_open(state: RefCounted) -> bool:
	return int(_m(state)["trust"]) >= int(cfg().get("sell", {}).get("trust_market", 5))


static func summary(state: RefCounted) -> Dictionary:
	return _m(state)
