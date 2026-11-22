extends RefCounted
## Everything a campaign remembers. Plain data, no nodes. Serialised with to_dict / from_dict.
## In the debug shell most of these values only feed the screens; the real rules come later.

const Content := preload("res://v2/sim/content.gd")
const VERSION := 1

var world_seed: int = 0
var day: int = 1
var minute: int = 18 * 60          # minutes since midnight of the day's evening (may pass 24:00)
var end_minute: int = 26 * 60      # 02:00
var money: int = 120
var attention: float = 0.0         # how hard the Bureau looks (0..100)
var pool: int = 4120               # the suspect pool
var unlocked: Array = []           # station ids unlocked beyond their default
var flags: Dictionary = {}         # free-form story / debug flags
var rule_index: int = 0
var morning_seen: bool = false
var playtime: float = 0.0          # seconds
var ledger: Array = []                # night ledgers, newest last
var materials: Dictionary = {}         # material id -> count
var tools: Array = []                  # tool ids you own
var items: Array = []                  # the stash: crafted items (dicts, see crafting.gd)
var mastery: Dictionary = {}           # recipe id -> {made, good, sum}
var next_item_id: int = 1
var os: Dictionary = {}               # HEARTH OS: wallpaper, installed programs, edited files (path -> text)
var people: Array = []                # your people and their kit (v2/sim/loadout.gd)
var supplies: Dictionary = {}          # bulk carried things: clips, shells, mags, flashes, charges


static func new_game(p_seed: int) -> RefCounted:
	var s = load("res://v2/sim/game_state.gd").new()
	var w := Content.world()
	s.world_seed = p_seed
	s.money = int(w.get("start_money", 120))
	s.pool = int(w.get("start_pool", 4120))
	s.minute = int(w.get("day_start_hour", 18)) * 60
	s.end_minute = int(w.get("day_end_hour", 26)) * 60
	s.rule_index = _rule_for(p_seed, 1)
	var rec := Content.get_file("recipes")
	s.materials = (rec.get("start_materials", {}) as Dictionary).duplicate()
	s.tools = (rec.get("start_tools", []) as Array).duplicate()
	load("res://v2/sim/loadout.gd").start(s)
	return s


static func _rule_for(p_seed: int, p_day: int) -> int:
	var n: int = Content.world().get("rules", []).size()
	return 0 if n == 0 else abs(hash(str(p_seed) + ":" + str(p_day))) % n


func hours_left() -> float:
	return maxf(0.0, (end_minute - minute) / 60.0)


func clock_text() -> String:
	var m := minute % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


func can_spend(hours: float) -> bool:
	return hours <= hours_left() + 0.001


func spend(hours: float) -> void:
	minute = mini(end_minute, minute + int(round(hours * 60.0)))


func rule() -> Dictionary:
	var rules: Array = Content.world().get("rules", [])
	return rules[rule_index] if rule_index < rules.size() else {}


func is_unlocked(station: Dictionary) -> bool:
	return not station.get("locked", false) or unlocked.has(station["id"])


## Night: the Bureau moves (dummy lines), then a new day starts. Returns tonight's ledger lines.
func end_day() -> Array:
	var lines: Array = []
	var pool_lines: Array = Content.world().get("ledger", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(world_seed) + "night" + str(day))
	for i in 3:
		if not pool_lines.is_empty():
			lines.append(pool_lines[rng.randi() % pool_lines.size()])
	var drop := rng.randi_range(0, 60)
	pool = maxi(1, pool - drop)
	lines.append("Suspect pool: %d (-%d)." % [pool, drop])
	ledger.append({"day": day, "lines": lines})
	if ledger.size() > 30:
		ledger.pop_front()
	day += 1
	minute = int(Content.world().get("day_start_hour", 18)) * 60
	rule_index = _rule_for(world_seed, day)
	morning_seen = false
	return lines


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "seed": world_seed, "day": day, "minute": minute, "end_minute": end_minute,
		"money": money, "attention": attention, "pool": pool, "unlocked": unlocked, "flags": flags,
		"rule_index": rule_index, "morning_seen": morning_seen, "playtime": playtime, "log": ledger,
		"materials": materials, "tools": tools, "items": items, "mastery": mastery, "next_item_id": next_item_id,
		"os": os, "people": people, "supplies": supplies,
	}


static func from_dict(d: Dictionary) -> RefCounted:
	var s = load("res://v2/sim/game_state.gd").new()
	s.world_seed = int(d.get("seed", 0))
	s.day = int(d.get("day", 1))
	s.minute = int(d.get("minute", 18 * 60))
	s.end_minute = int(d.get("end_minute", 26 * 60))
	s.money = int(d.get("money", 0))
	s.attention = float(d.get("attention", 0.0))
	s.pool = int(d.get("pool", 4120))
	s.unlocked = d.get("unlocked", [])
	s.flags = d.get("flags", {})
	s.rule_index = int(d.get("rule_index", 0))
	s.morning_seen = bool(d.get("morning_seen", false))
	s.playtime = float(d.get("playtime", 0.0))
	s.ledger = d.get("log", [])
	var mats: Dictionary = d.get("materials", {})
	for k in mats:
		s.materials[k] = int(mats[k])      # JSON gives floats back
	s.tools = d.get("tools", [])
	s.items = d.get("items", [])
	for it in s.items:
		for k in ["id", "stars", "day", "heal"]:
			if it.has(k):
				it[k] = int(it[k])
	s.mastery = d.get("mastery", {})
	s.next_item_id = int(d.get("next_item_id", 1))
	s.os = d.get("os", {})
	s.people = d.get("people", [])
	if not d.has("people"):
		load("res://v2/sim/loadout.gd").start(s)       # an older save: give it Pavel's three and the start kit
	for p in s.people:
		for k in p.get("kit", {}):
			p["kit"][k] = int(p["kit"][k])
		for e in p.get("grid", []):
			e["x"] = int(e["x"])
			e["y"] = int(e["y"])
			if e.has("item"):
				e["item"] = int(e["item"])
		p["level"] = int(p.get("level", 1))
		p["ops"] = int(p.get("ops", 0))
	var sup: Dictionary = d.get("supplies", {})
	for k in sup:
		s.supplies[k] = int(sup[k])
	if s.os.has("wallpaper"):
		s.os["wallpaper"] = int(s.os["wallpaper"])
	return s
