extends Node3D
## The vault (art bible 18): three numbered steel doors on the secure store's back wall, a navy wall band,
## cables along the wall from each door to the control PC. Each door is a steel cabinet set against the
## wall; the slab swings out when you open it, and a lamp inside lights what was behind it.
## Built from the level's helpers (box, flat) so it matches the rest of the building.

const LOOT_COL := {"junk": Color(0.35, 0.34, 0.32), "decent": Color(0.5, 0.38, 0.22), "good": Color(0.32, 0.38, 0.22), "jackpot": Color(0.95, 0.7, 0.25)}
const DEPTH := 0.7
const W := 1.15
const HGT := 2.25

var level: Node3D
var wall_z := 0.0                # the back wall (the doors face +z)
var xs: Array = [-1.55, 0.0, 1.55]
var pivots: Array = []
var lamps: Array = []
var readers: Array = []
var loot_nodes: Array = []
var _swing := {}                 # door index -> t


## rc: the secure store (doors on its back wall, z min, centred); pc: where the control PC sits (on its left wall).
func build(p_level: Node3D, rc: Rect2, pc: Vector3, contents: Array) -> void:
	level = p_level
	wall_z = rc.position.y
	var cx := rc.get_center().x
	xs = [cx - 1.55, cx, cx + 1.55]
	var steel: Material = level.flat(Color(0.2, 0.21, 0.22))
	var steel_d: Material = level.flat(Color(0.12, 0.12, 0.13))
	var navy: Material = level.flat(Color(0.1, 0.14, 0.28))
	var cable: Material = level.flat(Color(0.08, 0.08, 0.08))
	var inside: Material = level.flat(Color(0.05, 0.05, 0.05))
	var span := rc.size.x
	# the navy band along the bottom of the wall (Dobrev Freight's colours)
	level.box(Vector3(span, 0.85, 0.02), Vector3(cx, 0.43, wall_z + 0.012), navy, Vector3.ZERO, false, self)
	for i in 3:
		var x: float = xs[i]
		var front := wall_z + DEPTH
		# the cabinet: back, sides, top, floor (hollow, so the inside shows when it's open)
		level.box(Vector3(W, HGT, 0.06), Vector3(x, HGT * 0.5, wall_z + 0.03), inside, Vector3.ZERO, false, self)
		for sx in [-1, 1]:
			level.box(Vector3(0.1, HGT, DEPTH), Vector3(x + sx * (W * 0.5 - 0.05), HGT * 0.5, wall_z + DEPTH * 0.5), steel, Vector3.ZERO, true, self)
		level.box(Vector3(W, 0.12, DEPTH), Vector3(x, HGT - 0.06, wall_z + DEPTH * 0.5), steel, Vector3.ZERO, true, self)
		level.box(Vector3(W, 0.08, DEPTH), Vector3(x, 0.04, wall_z + DEPTH * 0.5), steel_d, Vector3.ZERO, false, self)
		# what's inside, by tier (you only see it once the door swings)
		var c: Dictionary = contents[i] if i < contents.size() else {}
		var lc: Color = LOOT_COL.get(str(c.get("tier", "junk")), LOOT_COL["junk"])
		var loot := Node3D.new()
		add_child(loot)
		var lm: Material = level.flat(lc, 0.6 if c.get("tier", "") == "jackpot" else 0.0)
		level.box(Vector3(0.6, 0.45, 0.4), Vector3(x - 0.1, 0.3, wall_z + 0.3), lm, Vector3(0, 0.2, 0), false, loot)
		level.box(Vector3(0.4, 0.3, 0.3), Vector3(x + 0.25, 0.68, wall_z + 0.28), lm, Vector3(0, -0.3, 0), false, loot)
		loot_nodes.append(loot)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, HGT - 0.35, wall_z + 0.35)
		lamp.light_color = Color(1.0, 0.8, 0.5)
		lamp.light_energy = 0.0
		lamp.omni_range = 1.8
		add_child(lamp)
		lamps.append(lamp)
		# the slab on its hinge (left edge), with its number
		var pv := Node3D.new()
		pv.position = Vector3(x - W * 0.5 + 0.1, 0, front)
		add_child(pv)
		var slab_w := W - 0.2
		level.box(Vector3(slab_w, HGT - 0.2, 0.08), Vector3(slab_w * 0.5, (HGT - 0.2) * 0.5 + 0.08, 0.0), steel, Vector3.ZERO, false, pv)
		level.box(Vector3(slab_w - 0.2, 0.7, 0.02), Vector3(slab_w * 0.5, 0.55, 0.05), steel_d, Vector3.ZERO, false, pv)
		for hy in [0.45, 1.65]:
			level.box(Vector3(0.06, 0.18, 0.06), Vector3(0.0, hy, 0.05), steel_d, Vector3.ZERO, false, pv)
		var num := Label3D.new()
		num.text = "%02d" % (i + 1)
		num.font_size = 64
		num.pixel_size = 0.004
		num.modulate = Color(0.82, 0.8, 0.74)
		num.outline_size = 0
		num.position = Vector3(slab_w * 0.5, 1.7, 0.05)
		pv.add_child(num)
		pivots.append(pv)
		# the card reader: red until the system grants a door, then green
		var rd: MeshInstance3D = level.box(Vector3(0.07, 0.14, 0.05), Vector3(x + W * 0.5 + 0.08, 1.15, front - 0.02), level.flat(Color(0.9, 0.15, 0.1), 2.5), Vector3.ZERO, false, self)
		readers.append(rd)
		# the cable from the door's top down from the run along the wall
		level.box(Vector3(0.05, 2.62 - HGT, 0.05), Vector3(x, (2.62 + HGT) * 0.5, wall_z + 0.2), cable, Vector3.ZERO, false, self)
		level.box(Vector3(0.12, 0.08, 0.1), Vector3(x, 2.62, wall_z + 0.2), steel_d, Vector3.ZERO, false, self)
	# the cable run: along the back wall, along the left wall to the PC, down to the desk
	var lx := rc.position.x + 0.06
	level.box(Vector3(xs[2] - lx + 0.1, 0.06, 0.06), Vector3((xs[2] + lx) * 0.5, 2.62, wall_z + 0.2), cable, Vector3.ZERO, false, self)
	level.box(Vector3(0.06, 0.06, pc.z - wall_z - 0.2), Vector3(lx, 2.62, (pc.z + wall_z + 0.2) * 0.5), cable, Vector3.ZERO, false, self)
	level.box(Vector3(0.06, 2.62 - 0.85, 0.06), Vector3(lx, (2.62 + 0.85) * 0.5, pc.z), cable, Vector3.ZERO, false, self)
	# the control PC: a beige box and a CRT on the desk
	var beige: Material = level.flat(Color(0.55, 0.52, 0.44))
	level.box(Vector3(0.42, 0.34, 0.4), pc + Vector3(0.1, 0.96, 0), beige, Vector3(0, PI * 0.5, 0), false, self)
	level.box(Vector3(0.32, 0.22, 0.02), pc + Vector3(0.31, 0.98, 0), level.flat(Color(0.3, 0.85, 0.5), 1.6), Vector3(0, PI * 0.5, 0), false, self)


## Where a door's face is (for picking it on the camera feed).
func door_point(i: int) -> Vector3:
	return Vector3(xs[i], 1.15, wall_z + DEPTH + 0.05)


func grant() -> void:
	for rd in readers:
		(rd as MeshInstance3D).material_override = level.flat(Color(0.95, 0.65, 0.15), 2.5)


func open(i: int) -> void:
	_swing[i] = 0.0
	(readers[i] as MeshInstance3D).material_override = level.flat(Color(0.2, 0.95, 0.35), 2.5)
	for k in readers.size():
		if k != i:
			(readers[k] as MeshInstance3D).material_override = level.flat(Color(0.9, 0.15, 0.1), 2.5)


func _process(delta: float) -> void:
	for i in _swing:
		var t: float = minf(1.0, float(_swing[i]) + delta / 1.6)
		_swing[i] = t
		var e := 1.0 - pow(1.0 - t, 3.0)
		(pivots[i] as Node3D).rotation.y = -1.75 * e
		(lamps[i] as OmniLight3D).light_energy = 1.4 * e
