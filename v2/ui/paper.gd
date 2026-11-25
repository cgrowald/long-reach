extends Control
## Paper you look at (art bible 13, docs/DEPOT_SLICE.md section 8): laid over the screen, tilted a little,
## click anywhere (or Esc through the station's back()) to put it down.
##   show_plan(sheet)   the Bureau SERVICE FORM: floor plan + guard rotation (sheet = DepotRun.plan_sheet)
##   show_id(person)    the prisoner's ID: a laminated people's card, or a captured guard's black Bureau card
## Usage: var p := Paper.new(); parent.add_child(p); p.show_plan(...). Emits `closed` and frees itself.

signal closed

const Pal := preload("res://v2/ui/pal.gd")
const Face := preload("res://v2/ui/face.gd")

const CREAM := Color(0.89, 0.86, 0.78)
const FORM_INK := Color(0.2, 0.2, 0.22)
const NAVY := Color(0.14, 0.2, 0.33)
const STAMP := Color(0.72, 0.12, 0.1, 0.85)
const PEN := Color(0.16, 0.22, 0.6, 0.9)
const PENCIL := Color(0.3, 0.28, 0.26, 0.85)

const GRAY_SHADER := "shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.12, 0.11, 0.1, 1.0);
uniform vec4 paper : source_color = vec4(0.86, 0.83, 0.75, 1.0);
void fragment() {
	float l = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	l = smoothstep(0.12, 0.8, l);
	COLOR = vec4(mix(ink.rgb, paper.rgb, l), COLOR.a);
}"

var kind := ""
var data: Dictionary = {}
var sheet: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func show_plan(p_sheet: Dictionary) -> void:
	kind = "plan"
	data = p_sheet
	_make_sheet(Vector2(258, 344), -0.025)


func show_id(person: Dictionary) -> void:
	data = person
	var guard: bool = person.get("kind", "") == "guard" or str(person.get("offense", "")) == "Guarded the depot"
	kind = "bureau_id" if guard else "people_id"
	_make_sheet(Vector2(300, 188), 0.035)
	var photo := Control.new()
	photo.position = Vector2(20, 34) if not guard else Vector2(22, 44)
	photo.size = Vector2(78, 92)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	mat.shader = sh
	if guard:
		mat.set_shader_parameter("ink", Color(0.08, 0.09, 0.1))
		mat.set_shader_parameter("paper", Color(0.62, 0.64, 0.66))
	photo.material = mat
	var seed_name := str(person.get("face", person.get("name", "?")))
	photo.draw.connect(func() -> void: Face.draw(photo, Rect2(Vector2.ZERO, photo.size), seed_name, "cap" if guard else "", false))
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(photo)


func _make_sheet(sz: Vector2, tilt: float) -> void:
	sheet = Control.new()
	sheet.size = sz
	sheet.pivot_offset = sz * 0.5
	sheet.rotation = tilt
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	sheet.draw.connect(_draw_sheet)
	_place()
	var g := get_node_or_null("/root/Game")
	if g:
		g.sfx.play("drop_002", 1.4, -8.0)


func _place() -> void:
	if sheet:
		sheet.position = (size - sheet.size) * 0.5 + Vector2(0, -6)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func put_down() -> void:
	closed.emit()
	queue_free()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		accept_event()
		put_down()


func _process(delta: float) -> void:
	_t += delta
	if sheet:
		sheet.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.01, 0.72))
	Pal.text(self, Vector2(0, size.y - 16), "click anywhere to put it down", 8, Color(Pal.DIM, 0.8), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_sheet() -> void:
	match kind:
		"plan":
			_draw_plan(sheet)
		"people_id":
			_draw_people_id(sheet)
		"bureau_id":
			_draw_bureau_id(sheet)


# ------------------------------------------------------------------ helpers

static func _hash(s: String) -> int:
	return hash(s) & 0x7fffffff


## Paper grain and a few soft creases, from a seed (same sheet, same marks).
func _grain(c: Control, r: Rect2, seed_s: String, col := Color(0.4, 0.32, 0.2)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(seed_s)
	for i in 160:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		c.draw_rect(Rect2(p, Vector2(1, 1)), Color(col, rng.randf_range(0.04, 0.12)))
	for i in 3:
		var a := r.position + Vector2(rng.randf() * r.size.x, 0)
		var b := r.position + Vector2(rng.randf() * r.size.x, r.size.y)
		if rng.randf() < 0.5:
			a = r.position + Vector2(0, rng.randf() * r.size.y)
			b = r.position + Vector2(r.size.x, rng.randf() * r.size.y)
		c.draw_line(a, b, Color(1, 1, 1, 0.18), 1.0)
		c.draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(col, 0.08), 1.0)


## A pen scrawl (signature) from a seed.
func _scrawl(c: Control, at: Vector2, w: float, seed_s: String, col := PEN) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(seed_s)
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(at + Vector2(x, rng.randf_range(-5, 4)))
		x += rng.randf_range(2.5, 6.0)
	c.draw_polyline(pts, col, 1.2, true)
	c.draw_line(at + Vector2(-2, 6), at + Vector2(w * 0.8, 4), col, 1.0, true)


## A rubber stamp: a box and a word, rotated, a bit patchy.
func _stamp(c: Control, center: Vector2, word: String, fsize: int, ang: float, col := STAMP) -> void:
	var f := Pal.bold()
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 12
	var h := fsize + 10.0
	c.draw_set_transform(center, ang, Vector2.ONE)
	c.draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), col, false, 2.0)
	c.draw_rect(Rect2(-w * 0.5 + 3, -h * 0.5 + 3, w - 6, h - 6), Color(col, col.a * 0.5), false, 1.0)
	c.draw_string(f, Vector2(-w * 0.5 + 6, fsize * 0.38), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
	# ink gaps
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(word)
	for i in 14:
		c.draw_rect(Rect2(Vector2(rng.randf_range(-w * 0.5, w * 0.5), rng.randf_range(-h * 0.5, h * 0.5)), Vector2(2, 1)), Color(CREAM, 0.7))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _field(c: Control, r: Rect2, label: String, value: String, vcol := FORM_INK, vsize := 8) -> void:
	c.draw_rect(r, FORM_INK, false, 1.0)
	Pal.text(c, r.position + Vector2(3, 1), label, 5, Color(FORM_INK, 0.7))
	Pal.text(c, r.position + Vector2(3, r.size.y - vsize - 3), value, vsize, vcol, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6)


# ------------------------------------------------------------------ the service form (plan file)

func _draw_plan(c: Control) -> void:
	var sz := c.size
	var seed_s := str(data.get("form_no", "")) + str(data.get("day", 0))
	c.draw_rect(Rect2(Vector2(5, 7), sz), Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(Vector2.ZERO, sz), CREAM)
	_grain(c, Rect2(Vector2.ZERO, sz), seed_s)
	# dog-eared corner
	var k := 14.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x - k, 0), Vector2(sz.x, 0), Vector2(sz.x, k)]), Color(0.08, 0.06, 0.05))
	c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x - k, 0), Vector2(sz.x, k), Vector2(sz.x - k, k)]), CREAM.darkened(0.12))
	# header: the Bureau's slash logo
	for i in 2:
		var x0 := 12.0 + i * 9.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0, 32), Vector2(x0 + 6, 32), Vector2(x0 + 6, 12 - i * 4), Vector2(x0, 18 - i * 4)]), NAVY)
	c.draw_string(Pal.bold(), Vector2(40, 28), "SERVICE FORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, FORM_INK)
	Pal.text(c, Vector2(40, 31), "BUREAU OF ORDER  /  SITE SECURITY", 5, Color(FORM_INK, 0.75))
	c.draw_line(Vector2(10, 40), Vector2(sz.x - 10, 40), FORM_INK, 1.5)
	# fields
	var fy := 44.0
	_field(c, Rect2(10, fy, 112, 22), "SITE", "%s" % data.get("site", ""))
	_field(c, Rect2(122, fy, 70, 22), "FORM NO.", str(data.get("form_no", "")))
	_field(c, Rect2(192, fy, sz.x - 202, 22), "DAY", str(data.get("day", "")))
	_field(c, Rect2(10, fy + 22, sz.x - 20, 18), "FACILITY TYPE", str(data.get("kind", "")), FORM_INK, 7)
	# the floor plan
	var py := fy + 46
	Pal.text(c, Vector2(10, py), "1. FLOOR PLAN, LEVEL B2 (ENTRY LEFT)", 6, FORM_INK)
	var box := Rect2(10, py + 9, sz.x - 20, 84)
	c.draw_rect(box, FORM_INK, false, 1.0)
	_plan_drawing(c, box)
	# guard rotation
	var gy := box.end.y + 8
	Pal.text(c, Vector2(10, gy), "2. GUARD ROTATION (TONIGHT)", 6, FORM_INK)
	var cols := [10.0, 22.0, 86.0, 142.0, 180.0]
	var heads := ["#", "NAME", "POST", "DUTY", "SHIFT"]
	var ty := gy + 9
	c.draw_rect(Rect2(10, ty, sz.x - 20, 10), Color(FORM_INK, 0.12))
	for i in heads.size():
		Pal.text(c, Vector2(cols[i] + 2, ty + 1), heads[i], 6, FORM_INK)
	var guards: Array = data.get("guards", [])
	for gi in guards.size():
		var g: Dictionary = guards[gi]
		var ry := ty + 10 + gi * 10
		c.draw_line(Vector2(10, ry + 10), Vector2(sz.x - 10, ry + 10), Color(FORM_INK, 0.35), 1.0)
		var vals := [str(gi + 1), str(g["name"]), _short_room(str(g["post"])), str(g["duty"]), str(g["shift"])]
		for i in vals.size():
			Pal.text(c, Vector2(cols[i] + 2, ry + 1), vals[i], 6, FORM_INK, HORIZONTAL_ALIGNMENT_LEFT, (cols[i + 1] if i + 1 < cols.size() else sz.x - 10) - cols[i] - 3)
	c.draw_rect(Rect2(10, ty, sz.x - 20, 10 + guards.size() * 10), FORM_INK, false, 1.0)
	# the vault
	var vy := ty + 14 + guards.size() * 10
	Pal.text(c, Vector2(10, vy), "3. SECURE STORE, DOORS 01-03 (CONTENTS)", 6, FORM_INK)
	var vault: Array = data.get("vault", ["?", "?", "?"])
	for i in 3:
		var r := Rect2(10 + i * ((sz.x - 20) / 3.0), vy + 9, (sz.x - 20) / 3.0, 20)
		var v := str(vault[i])
		_field(c, r, "DOOR 0%d" % (i + 1), "" if v == "?" else v.to_upper(), FORM_INK, 7)
		if v == "?":
			c.draw_rect(Rect2(r.position + Vector2(4, 10), Vector2(r.size.x - 10, 6)), FORM_INK)   # redacted
	# pencil: where the copy came from
	Pal.wrap(c, Vector2(12, sz.y - 40), str(data.get("note", "")), 7, PENCIL, sz.x - 24, 2)
	var src := "copy: %s, day %d" % [data.get("source", "?"), int(data.get("got_day", 0))]
	Pal.text(c, Vector2(12, sz.y - 14), src, 7, PENCIL, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 24)
	_stamp(c, Vector2(sz.x - 62, 30), "RESTRICTED", 11, -0.12)
	if int(data.get("locked", 0)) > 0:
		_stamp(c, Vector2(sz.x * 0.5, box.get_center().y), "LOCKDOWN %d NIGHTS" % int(data["locked"]), 12, 0.08)


func _short_room(n: String) -> String:
	return {"B2 CORRIDOR": "CORRIDOR", "DISPATCH OFFICE": "OFFICE", "SECURE STORE": "SECURE"}.get(n, n)


## The level drawn side-on: entry (z = +2.5) on the left, the secure store on the right.
func _plan_drawing(c: Control, box: Rect2) -> void:
	var rooms: Array = data.get("rooms", [])
	if rooms.is_empty():
		return
	var zmin := 1e9
	var zmax := -1e9
	var xmin := 1e9
	var xmax := -1e9
	for r in rooms:
		var rc: Array = r["rect"]
		xmin = minf(xmin, float(rc[0]))
		xmax = maxf(xmax, float(rc[2]))
		zmin = minf(zmin, float(rc[1]))
		zmax = maxf(zmax, float(rc[3]))
	var s := minf((box.size.x - 16) / (zmax - zmin), (box.size.y - 30) / (xmax - xmin))
	var o := box.position + Vector2((box.size.x - (zmax - zmin) * s) * 0.5, 12 + (box.size.y - 24 - (xmax - xmin) * s) * 0.5)
	var to := func(x: float, z: float) -> Vector2: return o + Vector2((zmax - z) * s, (x - xmin) * s)
	for r in rooms:
		var rc: Array = r["rect"]
		var a: Vector2 = to.call(float(rc[0]), float(rc[3]))
		var b: Vector2 = to.call(float(rc[2]), float(rc[1]))
		var rr := Rect2(a, b - a).abs()
		if r["id"] == str(data.get("vault_room", "office")):
			c.draw_rect(rr, Color(NAVY, 0.1))
		c.draw_rect(rr, FORM_INK, false, 1.5)
		var nm := _short_room(str(r["name"]))
		if not r["id"] in ["hall", str(data.get("vault_room", "office"))]:
			Pal.text(c, rr.position + Vector2(2, 1), nm, 5, Color(FORM_INK, 0.8), HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 3)
		else:
			Pal.text(c, Vector2(rr.position.x + 3, rr.end.y - 7), nm, 5, Color(FORM_INK, 0.8))
	for d in data.get("doors", []):
		var p: Vector2 = to.call(float(d["pos"][0]), float(d["pos"][1]))
		var along := Vector2(1, 0) if d["axis"] == "x" else Vector2(0, 1)    # axis x = wall across x: runs along z (screen x)
		c.draw_line(p - along * 0.5 * s, p + along * 0.5 * s, CREAM, 3.0)
		if d.get("locked", false):
			c.draw_line(p - along * 0.5 * s, p + along * 0.5 * s, STAMP, 1.5)
	# entry arrow
	var ep: Array = data.get("entry", [0.0, zmax])
	var ent: Vector2 = to.call(float(ep[0]), float(ep[1]))
	c.draw_line(ent - Vector2(12, 0), ent, FORM_INK, 1.0)
	c.draw_colored_polygon(PackedVector2Array([ent, ent + Vector2(-4, -2.5), ent + Vector2(-4, 2.5)]), FORM_INK)
	Pal.text(c, ent + Vector2(-14, 3), "IN", 5, FORM_INK)
	# vault doors 01-03 along the far wall, the PC, the alarm box
	for rm in rooms:
		if rm["id"] == str(data.get("vault_room", "office")):
			var rc: Array = rm["rect"]
			for i in 3:
				var x := lerpf(float(rc[0]) + 0.8, float(rc[2]) - 0.8, i / 2.0)
				var p: Vector2 = to.call(x, float(rc[1]))
				c.draw_rect(Rect2(p + Vector2(-4, -3), Vector2(4, 6)), NAVY)
				Pal.text(c, p + Vector2(-16, -4), "0%d" % (i + 1), 5, NAVY)
	var pc: Array = data.get("pc", [])
	if pc.size() == 2:
		var pp: Vector2 = to.call(float(pc[0]), float(pc[1]))
		c.draw_rect(Rect2(pp - Vector2(3, 2), Vector2(6, 4)), FORM_INK, false, 1.0)
		Pal.text(c, pp + Vector2(4, -3), "PC", 5, FORM_INK)
	var al: Array = data.get("alarm", [])
	if al.size() == 2:
		var ap: Vector2 = to.call(float(al[0]), float(al[1]))
		c.draw_colored_polygon(PackedVector2Array([ap + Vector2(0, -4), ap + Vector2(4, 3), ap + Vector2(-4, 3)]), STAMP)
		Pal.text(c, ap + Vector2(5, -3), "ALARM", 5, STAMP)
	# guards: circled numbers, patrols dashed (blue pen: someone marked this copy up)
	var guards: Array = data.get("guards", [])
	for gi in guards.size():
		var g: Dictionary = guards[gi]
		var pat: Array = g.get("patrol", [])
		if pat.size() >= 2:
			var a: Vector2 = to.call(float(pat[0][0]), float(pat[0][1]))
			var b: Vector2 = to.call(float(pat[1][0]), float(pat[1][1]))
			c.draw_dashed_line(a, b, PEN, 1.0, 3.0)
			c.draw_line(a + Vector2(0, -2), a + Vector2(0, 2), PEN, 1.0)
			c.draw_line(b + Vector2(0, -2), b + Vector2(0, 2), PEN, 1.0)
		var gp: Vector2 = to.call(float(g["pos"][0]), float(g["pos"][1]))
		c.draw_arc(gp, 4.0, 0, TAU, 14, PEN, 1.0)
		Pal.text(c, gp + Vector2(-4, -4), str(gi + 1), 6, PEN, HORIZONTAL_ALIGNMENT_CENTER, 8)
	# legend
	var ly := box.end.y - 8
	c.draw_arc(Vector2(box.position.x + 7, ly + 3), 3.0, 0, TAU, 10, PEN, 1.0)
	Pal.text(c, Vector2(box.position.x + 12, ly), "guard post", 5, PEN)
	c.draw_dashed_line(Vector2(box.position.x + 52, ly + 3), Vector2(box.position.x + 62, ly + 3), PEN, 1.0, 2.0)
	Pal.text(c, Vector2(box.position.x + 65, ly), "patrol", 5, PEN)
	c.draw_line(Vector2(box.position.x + 92, ly + 3), Vector2(box.position.x + 100, ly + 3), STAMP, 1.5)
	Pal.text(c, Vector2(box.position.x + 103, ly), "locked door", 5, STAMP)


# ------------------------------------------------------------------ the people's ID (laminated paper)

func _draw_people_id(c: Control) -> void:
	var p := data
	var sz := c.size
	var seed_s := str(p.get("name", ""))
	c.draw_rect(Rect2(Vector2(5, 7), sz), Color(0, 0, 0, 0.45))
	# the laminate pouch, then the paper inside it
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.78, 0.78, 0.74))
	c.draw_rect(Rect2(Vector2(3, 3), sz - Vector2(6, 6)), Color(0.62, 0.62, 0.58), false, 1.0)
	var pr := Rect2(Vector2(9, 9), sz - Vector2(18, 18))
	c.draw_rect(pr, Color(0.87, 0.84, 0.74))
	_grain(c, pr, seed_s)
	Pal.text(c, pr.position + Vector2(4, 3), "CITIZEN CARD  /  DISTRICT %d" % (1 + _hash(seed_s) % 9), 7, FORM_INK)
	c.draw_line(pr.position + Vector2(4, 13), Vector2(pr.end.x - 4, pr.position.y + 13), Color(FORM_INK, 0.5), 1.0)
	# photo frame (the photo itself is a child node, in grey)
	c.draw_rect(Rect2(Vector2(18, 32), Vector2(82, 96)), Color(FORM_INK, 0.6), false, 1.0)
	var x := 112.0
	var fields := [["SURNAME", str(p.get("last", "")).to_upper()], ["GIVEN NAME", str(p.get("first", ""))],
		["AGE", str(p.get("age", ""))], ["WORK", str(p.get("background", {}).get("name", ""))]]
	for i in fields.size():
		var y := 32.0 + i * 20.0
		Pal.text(c, Vector2(x, y), fields[i][0], 5, Color(FORM_INK, 0.65))
		Pal.text(c, Vector2(x, y + 6), fields[i][1], 9, FORM_INK, HORIZONTAL_ALIGNMENT_LEFT, sz.x - x - 18)
	# what they're in for, in pen, and signatures
	Pal.text(c, Vector2(18, 134), "HELD FOR:", 5, Color(FORM_INK, 0.65))
	Pal.wrap(c, Vector2(18, 140), str(p.get("offense", "No reason given")), 8, PEN, sz.x - 120, 2)
	_scrawl(c, Vector2(186, 136), 70, seed_s + "a")
	_scrawl(c, Vector2(196, 152), 52, seed_s + "b")
	# tally of days held
	var days := int(p.get("days_held", 0))
	var tx := 190.0
	for i in mini(days, 25):
		var grp := i / 5
		var j := i % 5
		var bx := tx + grp * 14.0
		if j < 4:
			c.draw_line(Vector2(bx + j * 2.5, 160), Vector2(bx + j * 2.5 + 1, 170), PEN, 1.0)
		else:
			c.draw_line(Vector2(bx - 1, 168), Vector2(bx + 10, 161), PEN, 1.0)
	if days > 25:
		Pal.text(c, Vector2(tx + 72, 162), "+", 8, PEN)
	_stamp(c, Vector2(sz.x - 66, 40), "DETAINED", 13, -0.14)
	# laminate gloss and a corner lifting
	c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x * 0.55, 0), Vector2(sz.x * 0.72, 0), Vector2(sz.x * 0.4, sz.y), Vector2(sz.x * 0.23, sz.y)]), Color(1, 1, 1, 0.07))
	c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x - 16, sz.y), Vector2(sz.x, sz.y - 16), Vector2(sz.x, sz.y)]), Color(0.1, 0.08, 0.06))
	# their queue ticket, tucked under the corner
	var tr := Rect2(sz.x - 74, sz.y - 42, 62, 36)
	c.draw_set_transform(tr.get_center(), 0.12, Vector2.ONE)
	var lr := Rect2(-tr.size * 0.5, tr.size)
	c.draw_rect(lr, Color(0.93, 0.78, 0.32))
	Pal.text(c, lr.position + Vector2(0, 3), "PLEASE WAIT", 6, FORM_INK, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
	c.draw_string(Pal.bold(), lr.position + Vector2(0, 30), str(10 + _hash(seed_s + "q") % 80), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 16, FORM_INK)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ the Bureau's card (a captured guard)

func _draw_bureau_id(c: Control) -> void:
	var p := data
	var sz := c.size
	var seed_s := str(p.get("name", ""))
	var k := 12.0
	var outline := PackedVector2Array([Vector2(k, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y - k), Vector2(sz.x - k, sz.y), Vector2(0, sz.y), Vector2(0, k)])
	var sh := PackedVector2Array()
	for v in outline:
		sh.append(v + Vector2(5, 7))
	c.draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
	c.draw_colored_polygon(outline, Color(0.17, 0.18, 0.2))
	var loop := outline.duplicate()
	loop.append(outline[0])
	c.draw_polyline(loop, Color(0.36, 0.38, 0.42), 1.5)
	# header band
	c.draw_colored_polygon(PackedVector2Array([Vector2(k, 6), Vector2(sz.x * 0.5, 6), Vector2(sz.x * 0.5 - 14, 30), Vector2(6, 30), Vector2(6, k + 6)]), Color(0.25, 0.27, 0.3))
	c.draw_string(Pal.bold(), Vector2(18, 25), "BUREAU", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.78, 0.8, 0.82))
	Pal.text(c, Vector2(sz.x * 0.5, 12), "SERVICE IDENTITY / SITE GUARD", 6, Color(0.6, 0.62, 0.66))
	c.draw_rect(Rect2(Vector2(20, 42), Vector2(82, 96)), Color(0.45, 0.47, 0.5), false, 1.0)
	var x := 116.0
	var fields := [["NAME", str(p.get("name", ""))], ["RANK", str(p.get("rank", "Guard"))],
		["SERVICE", "%d yrs" % int(p.get("years", 1))], ["NO.", "B-%06d" % (_hash(seed_s) % 1000000)]]
	for i in fields.size():
		var y := 40.0 + i * 20.0
		Pal.text(c, Vector2(x, y), fields[i][0], 5, Color(0.55, 0.57, 0.6))
		Pal.text(c, Vector2(x, y + 6), fields[i][1], 9, Color(0.86, 0.87, 0.88), HORIZONTAL_ALIGNMENT_LEFT, 110)
	# chip and hologram
	var chip := Rect2(sz.x - 54, 44, 32, 26)
	c.draw_rect(chip, Color(0.62, 0.6, 0.55))
	c.draw_line(chip.position + Vector2(0, 13), chip.end - Vector2(0, 13), Color(0.4, 0.38, 0.34), 1.0)
	c.draw_line(chip.position + Vector2(16, 0), chip.position + Vector2(16, 26), Color(0.4, 0.38, 0.34), 1.0)
	c.draw_rect(chip, Color(0.3, 0.3, 0.28), false, 1.0)
	var hol := Rect2(sz.x - 66, 116, 46, 22)
	for i in 12:
		var hue := fmod(i / 12.0 + _t * 0.08, 1.0)
		c.draw_rect(Rect2(hol.position + Vector2(i * hol.size.x / 12.0, 0), Vector2(hol.size.x / 12.0 + 0.5, hol.size.y)), Color.from_hsv(hue, 0.35, 0.85, 0.85))
	# the uniform's orange double stripe, and the card's line
	for i in 2:
		c.draw_line(Vector2(20 + i * 5, sz.y - 14), Vector2(32 + i * 5, sz.y - 30), Color(0.9, 0.45, 0.15), 2.0)
	Pal.text(c, Vector2(48, sz.y - 22), "Property of the Bureau. Return if found.", 6, Color(0.55, 0.57, 0.6))
	_stamp(c, Vector2(sz.x - 70, sz.y - 30), "TAKEN", 12, -0.1, Color(0.85, 0.2, 0.15, 0.8))
