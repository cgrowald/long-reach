extends RefCounted
## Combat rules, no nodes (docs/COMBAT_SLICE.md section 2, Tarkov-lite): gear -> stats, hit chance,
## where a round lands, what the plate does, bleeding. Tables live in data/v2/combat/depot.json "gear".

const Content := preload("res://v2/sim/content.gd")

const HP := 100.0
const BLEED_RATE := 1.6           # hp per second per open wound
const BLEED_OUT := 40.0           # seconds a downed fighter lasts without a medic
const DOWN_AT := 0.0


static func gear_tables() -> Dictionary:
	return Content.get_file("combat/depot").get("gear", {})


## Everything a fighter carries, rolled into the numbers the fight uses.
static func stats(gear: Dictionary, trait_id := "") -> Dictionary:
	var t := gear_tables()
	var w: Dictionary = (t.get("weapons", {}) as Dictionary).get(gear.get("weapon", "pistol"), {})
	var r: Dictionary = (t.get("rounds", {}) as Dictionary).get(gear.get("round", "fmj"), {})
	var s := {
		"weapon": w.get("name", "?"), "round": r.get("name", "?"),
		"acc": float(w.get("acc", 0.5)), "dmg": float(w.get("dmg", 25)) * float(r.get("dmg", 1.0)),
		"pen": float(r.get("pen", 1.0)), "armor_dmg": float(r.get("armor", 1.0)),
		"burst": int(w.get("burst", 3)), "rate": float(w.get("rate", 0.12)), "recoil": float(w.get("recoil", 0.2)),
		"mag": int(w.get("mag", 30)), "reload": float(w.get("reload", 2.5)), "ads": float(w.get("ads", 0.45)),
		"jam": float(w.get("jam", 0.01)), "spot": false, "falloff": float(w.get("falloff", 0.0)),
		"plate": int(gear.get("plate", 0)), "mags": int(gear.get("mags", 3)), "meds": int(gear.get("meds", 1)),
		"flash": int(gear.get("flash", 0)), "charges": int(gear.get("charges", 0)),
	}
	for a in gear.get("attach", []):
		var at: Dictionary = (t.get("attachments", {}) as Dictionary).get(a, {})
		s["acc"] = float(s["acc"]) + float(at.get("acc", 0.0))
		s["recoil"] = maxf(0.02, float(s["recoil"]) + float(at.get("recoil", 0.0)))
		s["ads"] = maxf(0.15, float(s["ads"]) + float(at.get("ads", 0.0)))
		if at.get("spot", false):
			s["spot"] = true
	var p: Dictionary = (t.get("plates", {}) as Dictionary).get(str(s["plate"]), {})
	s["plate_name"] = p.get("name", "none")
	s["plate_dur"] = float(p.get("durability", 0))
	# the person under the gear
	match trait_id:
		"steady":
			s["acc"] = float(s["acc"]) + 0.05
			s["react"] = 0.35
		"jumpy":
			s["acc"] = float(s["acc"]) - 0.05
			s["react"] = 0.25
		"careful":
			s["react"] = 0.55
		"cocky":
			s["react"] = 0.3
		_:
			s["react"] = 0.6
	return s


## Chance one round hits. Distance, movement, cover and recoil build-up all count.
static func hit_chance(st: Dictionary, dist: float, shooter_moving: bool, target_moving: bool, cover: float, shot_in_burst: int) -> float:
	var c := float(st["acc"])
	c *= clampf(1.15 - dist / 30.0, 0.35, 1.1)
	if float(st.get("falloff", 0.0)) > 0.0:
		c *= clampf(1.5 - dist / float(st["falloff"]) * 0.7, 0.15, 1.3)      # a shotgun: brutal close, useless far
	if shooter_moving:
		c *= 0.6
	if target_moving:
		c *= 0.8
	c *= 1.0 - cover
	c -= float(st["recoil"]) * shot_in_burst * 0.5
	return clampf(c, 0.03, 0.95)


## Where a hit lands and what it does. target: {plate, plate_dur}. Returns
## {zone, dmg, blocked, bleed, plate_dur}.
static func resolve_hit(rng: RandomNumberGenerator, st: Dictionary, target: Dictionary) -> Dictionary:
	var roll := rng.randf()
	var zone := "limb"
	if roll < 0.07:
		zone = "head"
	elif roll < 0.57:
		zone = "thorax"
	var dmg := float(st["dmg"]) * rng.randf_range(0.85, 1.15)
	var blocked := false
	var plate := int(target.get("plate", 0))
	var dur := float(target.get("plate_dur", 0.0))
	if zone == "thorax" and plate > 0 and dur > 0.0:
		dur = maxf(0.0, dur - float(st["armor_dmg"]) * 10.0)
		var pen := float(st["pen"])
		if pen < float(plate):
			# stopped: a bruise, not a wound. Worn plates let more through.
			blocked = true
			dmg *= 0.12 + (0.25 if dur <= 0.0 else 0.0)
		else:
			dmg *= clampf(0.55 + (pen - plate) * 0.25, 0.55, 0.95)
	match zone:
		"head":
			dmg *= 3.0
		"limb":
			dmg *= 0.7
	var bleed := not blocked and zone != "head" and rng.randf() < (0.55 if zone == "thorax" else 0.4)
	return {"zone": zone, "dmg": dmg, "blocked": blocked, "bleed": bleed, "plate_dur": dur}
