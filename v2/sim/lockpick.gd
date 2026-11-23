extends RefCounted
## Lockpicking rules (user 2026-11-23: Skyrim's turn-and-feel, pin by pin). Stylised, not a real procedure. No nodes.
##
## A lock has 3-6 pins. You hold some TENSION on the plug (mouse wheel) and lift one pin at a time with the pick.
## Only one pin BINDS at a time (a hidden order). Lift the binding pin into its sweet spot while the tension is
## right and it SETS (click, the plug turns a hair). Then the next pin binds.
##   - tension too low: set pins slowly drop back
##   - tension too high while you push a binding pin: the pick bends, and at full bend it snaps
##   - push the binding pin past its sweet spot: it OVERSETS and jams. Let the tension off to reset
##   - SPOOL pins (harder locks) false-set: they only set if you ease the tension off a little while lifting
## Feel: the pick shakes more the closer the binding pin is to its sweet spot (lock.feel), like Skyrim.

const Content := preload("res://v2/sim/content.gd")

var def: Dictionary = {}
var pins: Array = []          # {shear, w, spool, set, h, over}
var order: Array = []         # binding order (pin indexes)
var t_lo := 0.3
var t_hi := 0.6
var tension := 0.0
var lift := 0.0               # where the pick tip is (0..1)
var at := 0                   # which pin the pick is under
var bend := 0.0               # 0..1, snaps at 1
var plug := 0.0               # how far the plug has turned (0..1), for the drawing
var counter := 0.0            # spool counter-rotation, for the drawing
var feel := 0.0               # 0..1 shake of the pick (closeness to the sweet spot)
var opened := false
var snapped := 0              # picks broken this attempt
var events: Array = []        # "set", "false", "over", "drop", "snap", "open" - the view plays sounds and clears
var _drop_t := 0.0


static func locks() -> Dictionary:
	return Content.get_file("locks").get("locks", {})


static func create(lock_id: String, p_seed: int) -> RefCounted:
	var s = load("res://v2/sim/lockpick.gd").new()
	s._setup(locks().get(lock_id, {}), p_seed)
	return s


func _setup(d: Dictionary, p_seed: int) -> void:
	def = d
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var n := int(d.get("pins", 4))
	var w := float(d.get("window", 0.05))
	var spools := int(d.get("spools", 0))
	var band: Array = d.get("band", [0.3, 0.6])
	t_lo = float(band[0])
	t_hi = float(band[1])
	pins = []
	for i in n:
		pins.append({"shear": rng.randf_range(0.35, 0.8), "w": w, "spool": false, "set": false, "h": 0.0, "over": false})
	order = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	for k in mini(spools, n):
		pins[order[n - 1 - k]]["spool"] = true     # the last pins to bind are the tricky ones


## The pin that binds now, or -1 when all are set.
func binding() -> int:
	for i in order:
		if not pins[i]["set"]:
			return i
	return -1


func set_count() -> int:
	var n := 0
	for p in pins:
		if p["set"]:
			n += 1
	return n


func jammed() -> bool:
	for p in pins:
		if p["over"]:
			return true
	return false


func set_tension(v: float) -> void:
	tension = clampf(v, 0.0, 1.0)


func tick(delta: float) -> void:
	if opened:
		plug = minf(1.0, plug + delta * 1.5)
		return
	var b := binding()
	var heavy := tension > t_hi
	var good := tension >= t_lo and tension <= t_hi
	feel = 0.0
	counter = maxf(0.0, counter - delta * 2.0)
	# released: everything drops, a jam clears
	if tension < 0.05:
		var any := false
		for p in pins:
			if p["set"] or p["over"]:
				any = true
			p["set"] = false
			p["over"] = false
		if any:
			events.append("drop")
	# too light: set pins slip back one at a time
	elif tension < t_lo and set_count() > 0:
		_drop_t += delta
		if _drop_t > 0.7:
			_drop_t = 0.0
			for k in range(order.size() - 1, -1, -1):
				var i: int = order[k]
				if pins[i]["set"]:
					pins[i]["set"] = false
					events.append("drop")
					break
	else:
		_drop_t = 0.0
	for i in pins.size():
		var p: Dictionary = pins[i]
		if p["set"]:
			p["h"] = lerpf(p["h"], p["shear"], 1.0 - exp(-delta * 20.0))
			continue
		if p["over"]:
			p["h"] = lerpf(p["h"], minf(1.0, p["shear"] + p["w"] * 2.5), 1.0 - exp(-delta * 10.0))
			continue
		var target := lift if i == at else 0.0
		var stiff := i == b and tension > 0.05
		var rate := 4.0 if stiff else 22.0
		if stiff and heavy:
			rate = 2.0
		p["h"] = lerpf(p["h"], target, 1.0 - exp(-delta * rate))
		if i != b or tension < 0.05:
			continue
		# the binding pin under the pick: feel, set, overset, bend
		if i == at:
			feel = clampf(1.0 - absf(p["h"] - p["shear"]) / 0.28, 0.0, 1.0)
			if heavy and lift > p["h"] + 0.03:
				bend += delta * (0.5 + (tension - t_hi) * 2.5)
		var inside: bool = absf(p["h"] - p["shear"]) <= p["w"]
		if inside and tension >= t_lo:
			if p["spool"] and tension > (t_lo + t_hi) * 0.5:
				if counter <= 0.0:
					events.append("false")
				counter = 1.0           # it pushes back: ease off
			elif good or (heavy and not p["spool"]):
				p["set"] = true
				plug = float(set_count()) / float(pins.size()) * 0.12
				events.append("set")
		elif p["h"] > p["shear"] + p["w"] and tension >= t_lo:
			p["over"] = true
			events.append("over")
	if not heavy:
		bend = maxf(0.0, bend - delta * 0.35)
	if bend >= 1.0:
		bend = 0.0
		snapped += 1
		events.append("snap")
		for p in pins:
			p["set"] = false
			p["over"] = false
			p["h"] = 0.0
	if binding() == -1:
		opened = true
		events.append("open")
