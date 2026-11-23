extends RefCounted
## Graded materials (docs/ECONOMY.md section 2). state.materials keeps the plain totals (id -> count) that
## the rest of the game reads; state.mat_grades keeps how many of each star grade (id -> [g1..g5]).
## Always add and take through here so the two agree. Crafting takes the best grades first.

const MAX := 5


static func _g(state: RefCounted, id: String) -> Array:
	if not state.mat_grades.has(id):
		state.mat_grades[id] = [0, 0, 0, 0, 0]
	return state.mat_grades[id]


## Make the grades match the totals (older saves, debug edits): extra units count as grade 2.
static func reconcile(state: RefCounted) -> void:
	for id in state.materials:
		var g := _g(state, id)
		var total := int(state.materials[id])
		var sum := 0
		for v in g:
			sum += int(v)
		if sum < total:
			g[1] = int(g[1]) + total - sum
		elif sum > total:
			var extra := sum - total
			for i in MAX:
				var take := mini(extra, int(g[i]))
				g[i] = int(g[i]) - take
				extra -= take


static func add(state: RefCounted, id: String, n: int, grade: int) -> void:
	if n <= 0:
		return
	var g := _g(state, id)
	var gi := clampi(grade, 1, MAX) - 1
	g[gi] = int(g[gi]) + n
	state.materials[id] = int(state.materials.get(id, 0)) + n


static func total(state: RefCounted, id: String) -> int:
	return int(state.materials.get(id, 0))


static func best(state: RefCounted, id: String) -> int:
	var g := _g(state, id)
	for i in range(MAX - 1, -1, -1):
		if int(g[i]) > 0:
			return i + 1
	return 0


## How many units at or above a grade.
static func at_least(state: RefCounted, id: String, grade: int) -> int:
	var g := _g(state, id)
	var n := 0
	for i in range(clampi(grade, 1, MAX) - 1, MAX):
		n += int(g[i])
	return n


## Take n units, best first. Returns the average grade used (0 if none).
static func take(state: RefCounted, id: String, n: int) -> float:
	var g := _g(state, id)
	var left := n
	var sum := 0.0
	for i in range(MAX - 1, -1, -1):
		var t := mini(left, int(g[i]))
		g[i] = int(g[i]) - t
		sum += t * (i + 1)
		left -= t
	var used := n - left
	state.materials[id] = maxi(0, int(state.materials.get(id, 0)) - used)
	return sum / used if used > 0 else 0.0


## What a grade does to a craft's quality: 1 star x0.8, 3 stars x1.0, 5 stars x1.2.
static func grade_mult(g: float) -> float:
	return 0.7 + 0.1 * g


static func stars(g: int) -> String:
	return "*".repeat(clampi(g, 0, MAX))
