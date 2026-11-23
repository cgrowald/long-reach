extends RefCounted
## Procedural pixel faces (user 2026-11-22, option a: 2D layered portraits). Every fighter gets a face
## seeded from their name, so it's the same in the gear cage, the fight and the report, and nothing extra
## needs saving. Parts: skin, face shape, hair (style + colour), brows, eyes, nose, mouth, beard, a scar,
## plus headwear from their kit (helmet, cap, beanie) drawn on top.
## Drawn on a 16 x 18 grid of cells, scaled to the rect, so it stays pixel art at any size.
## GPT may later draw real part sheets; this is the placeholder generator.

const GW := 16
const GH := 18
const SKIN := [Color(0.96, 0.8, 0.66), Color(0.89, 0.7, 0.55), Color(0.78, 0.58, 0.42), Color(0.64, 0.45, 0.31), Color(0.5, 0.34, 0.23), Color(0.38, 0.26, 0.18)]
const HAIR := [Color(0.1, 0.08, 0.07), Color(0.24, 0.16, 0.1), Color(0.42, 0.28, 0.16), Color(0.62, 0.46, 0.26), Color(0.55, 0.52, 0.5), Color(0.5, 0.22, 0.12)]
const BG := Color(0.22, 0.32, 0.33)
const OLIVE := Color(0.36, 0.38, 0.27)


## The face parts for a name (deterministic).
static func parts(seed_name: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("face:" + seed_name)
	return {
		"skin": rng.randi() % SKIN.size(),
		"hair": rng.randi() % HAIR.size(),
		"style": rng.randi() % 6,          # 0 bald, 1 buzz, 2 short, 3 side part, 4 long tied back, 5 curly
		"width": rng.randi() % 3,          # narrow, mid, wide
		"jaw": rng.randi() % 2,            # soft, square
		"eyes": rng.randi() % 3,           # close, mid, wide
		"nose": rng.randi() % 3,
		"mouth": rng.randi() % 3,
		"beard": rng.randi() % 5 if rng.randf() < 0.6 else 0,   # 0 none, 1 stubble, 2 moustache, 3 full, 4 goatee
		"scar": rng.randi() % 4 if rng.randf() < 0.25 else -1,
		"brow": rng.randi() % 2,
		"age": rng.randf(),                # > 0.75: grey streaks and lines
	}


## Draw a portrait into r. head: "" | "helmet" | "cap" | "beanie". dead: greyed out.
static func draw(ci: CanvasItem, r: Rect2, seed_name: String, head := "", dead := false) -> void:
	var p := parts(seed_name)
	var cw := r.size.x / GW
	var ch := r.size.y / GH
	var px := func(x: int, y: int, c: Color) -> void:
		var col := c
		if dead:
			var g := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			col = Color(g, g, g).darkened(0.1)
		ci.draw_rect(Rect2(r.position + Vector2(x * cw, y * ch), Vector2(cw + 0.5, ch + 0.5)), col)
	var row := func(x0: int, x1: int, y: int, c: Color) -> void:
		for x in range(x0, x1 + 1):
			px.call(x, y, c)
	# background, shoulders
	for y in GH:
		row.call(0, GW - 1, y, BG.lightened(0.04 * (1.0 - float(y) / GH)))
	var skin: Color = SKIN[p["skin"]]
	var shade := skin.darkened(0.18)
	var hair: Color = HAIR[p["hair"]]
	if float(p["age"]) > 0.75:
		hair = hair.lerp(Color(0.7, 0.7, 0.68), 0.5)
	var shirt := Color(0.3, 0.33, 0.26) if head == "helmet" else Color(0.28, 0.3, 0.34)
	for y in range(15, GH):
		row.call(2, 13, y, shirt)
	row.call(6, 9, 14, shade)                    # neck
	row.call(5, 10, 15, shirt.lightened(0.08))   # collar
	# head shape
	var half := 4 + int(p["width"])              # half-width-ish: 4..6 cells
	var x0 := 8 - half
	var x1 := 7 + half
	for y in range(3, 14):
		var a := x0
		var b := x1
		if y == 3:
			a += 2
			b -= 2
		elif y >= 12:
			var cut := (y - 11) * (1 if p["jaw"] == 1 else 2)
			a += cut
			b -= cut
		row.call(a, b, y, skin)
		px.call(a, y, shade)                     # the shadow side
	# ears
	px.call(x0 - 1, 8, shade)
	px.call(x1 + 1, 8, shade)
	# hair
	match int(p["style"]):
		1:
			row.call(x0 + 1, x1 - 1, 3, hair.darkened(0.2))
		2:
			row.call(x0 + 1, x1 - 1, 2, hair)
			row.call(x0, x1, 3, hair)
			px.call(x0, 4, hair)
			px.call(x1, 4, hair)
		3:
			row.call(x0 + 1, x1 - 1, 2, hair)
			row.call(x0, x1, 3, hair)
			row.call(x0, x0 + 3, 4, hair)
			px.call(x1, 4, hair)
		4:
			row.call(x0 + 1, x1 - 1, 2, hair)
			row.call(x0, x1, 3, hair)
			for y in range(4, 9):
				px.call(x0, y, hair)
				px.call(x1, y, hair)
			px.call(x1 + 1, 6, hair)
			px.call(x1 + 2, 7, hair)
		5:
			row.call(x0, x1, 1, hair)
			row.call(x0 - 1, x1 + 1, 2, hair)
			row.call(x0 - 1, x1 + 1, 3, hair)
			for y in range(4, 7):
				px.call(x0 - 1, y, hair)
				px.call(x1 + 1, y, hair)
	# brows and eyes
	var gap := 1 + int(p["eyes"])
	var el := 7 - gap
	var er := 8 + gap
	var brow := hair.darkened(0.25)
	if int(p["brow"]) == 1:
		row.call(el - 1, el, 6, brow)
		row.call(er, er + 1, 6, brow)
	else:
		px.call(el, 6, brow)
		px.call(er, 6, brow)
	px.call(el, 7, Color(0.08, 0.07, 0.07))
	px.call(er, 7, Color(0.08, 0.07, 0.07))
	px.call(el - 1, 7, Color(0.92, 0.9, 0.86))
	px.call(er + 1, 7, Color(0.92, 0.9, 0.86))
	if float(p["age"]) > 0.75:
		px.call(el - 1, 8, shade)
		px.call(er + 1, 8, shade)
	# nose
	match int(p["nose"]):
		0:
			px.call(8, 9, shade)
		1:
			px.call(7, 9, shade)
			px.call(8, 9, shade)
		2:
			px.call(8, 8, shade)
			px.call(8, 9, shade)
			px.call(7, 10, shade)
	# beard (under the mouth)
	var bc := hair.darkened(0.1)
	match int(p["beard"]):
		1:
			for y in range(10, 13):
				for x in range(x0 + 1, x1):
					if (x + y) % 2 == 0:
						px.call(x, y, skin.lerp(bc, 0.45))
		2:
			row.call(6, 9, 10, bc)
		3:
			row.call(x0 + 1, x1 - 1, 11, bc)
			row.call(x0 + 2, x1 - 2, 12, bc)
			row.call(6, 9, 10, bc)
			row.call(6, 9, 13, bc)
		4:
			row.call(7, 8, 12, bc)
			row.call(7, 8, 13, bc)
			row.call(6, 9, 10, bc)
	# mouth
	var mc := skin.darkened(0.38)
	match int(p["mouth"]):
		0:
			row.call(7, 8, 11, mc)
		1:
			row.call(6, 9, 11, mc)
		2:
			row.call(7, 9, 11, mc)
			px.call(6, 10, mc)
	# a scar
	if int(p["scar"]) >= 0:
		var sx: int = [x0 + 1, x1 - 1, el, er][int(p["scar"])]
		px.call(sx, 8, Color(0.85, 0.55, 0.5))
		px.call(sx, 9, Color(0.85, 0.55, 0.5))
	# headwear from their kit
	match head:
		"helmet":
			row.call(x0, x1, 1, OLIVE)
			row.call(x0 - 1, x1 + 1, 2, OLIVE)
			row.call(x0 - 1, x1 + 1, 3, OLIVE.darkened(0.1))
			row.call(x0 - 1, x1 + 1, 4, OLIVE.darkened(0.25))
			row.call(x0 + 2, x1 - 2, 0, OLIVE.lightened(0.08))
			px.call(x1 - 1, 2, Color(0.2, 0.2, 0.2))       # the cam mount
			px.call(x1, 2, Color(0.2, 0.2, 0.2))
		"cap":
			row.call(x0, x1, 2, Color(0.25, 0.28, 0.3))
			row.call(x0, x1 + 2, 3, Color(0.2, 0.22, 0.24))
		"beanie":
			row.call(x0 + 1, x1 - 1, 1, Color(0.25, 0.2, 0.18))
			row.call(x0, x1, 2, Color(0.3, 0.24, 0.2))
			row.call(x0, x1, 3, Color(0.22, 0.18, 0.15))
	if dead:
		ci.draw_rect(r, Color(0, 0, 0, 0.12))


## The headwear to draw for a fighter, from their kit (head slot id).
static func head_of(kit_head: String) -> String:
	var h := kit_head.to_lower()
	if "helmet" in h:
		return "helmet"
	if "beanie" in h:
		return "beanie"
	if "cap" in h:
		return "cap"
	return ""
