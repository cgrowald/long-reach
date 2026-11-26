extends Control
## The plan before going in (M4 Q11, user 2026-11-25: pick the way in and the hour). A sheet of paper on the
## van's dashboard: the brief, then WHEN and WAY IN, each a few cards with what that choice means, and a
## pencil sketch of the place with the ways in numbered. GO runs the fight with them (Game meta
## "fight_plan" = {hour, entry}; fight.gd shapes the level from it). Reads the level's "plan" block.
## A generated building (level id "gen:<type>:<seed>", M4 V3) also gets a row of building types and
## ANOTHER ONE (R), to look through what the generator makes.

const PixelView := preload("res://v2/ui/pixel_view.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Content := preload("res://v2/sim/content.gd")
const BuildingGen := preload("res://v2/sim/building_gen.gd")
const Targets := preload("res://v2/sim/targets.gd")
const RED := Color(0.72, 0.12, 0.08)
const PENCIL := Color(0.32, 0.3, 0.28)

var game: Node
var view
var sheet: Control
var lv: Dictionary = {}
var plan: Dictionary = {}
var level_id := ""
var gen_type := ""
var pick := {"hour": "", "entry": ""}
var _hits: Array = []           # [Rect2, kind, id]
var target: Dictionary = {}     # M4 V4: planning a hit on a target from the Targets app (from the garage)


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_id = str(game.get_meta("fight_level", "combat/kessel_road")) if game else "combat/kessel_road"
	if game and game.state != null and game.has_meta("fight_target"):
		target = Targets.find(game.state, str(game.get_meta("fight_target")))
	_load(game.get_meta("fight_plan", {}) if game else {})
	view = PixelView.new()
	add_child(view)
	sheet = Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.ui.add_child(sheet)
	sheet.draw.connect(_draw_sheet)
	sheet.gui_input.connect(_on_input)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP


func _load(had: Dictionary) -> void:
	if not target.is_empty():
		lv = Targets.level_for(game.state, target)
		plan = (lv.get("plan", {}) as Dictionary).duplicate(true)
		if int(target["know"]) == 0:
			plan["entries"] = (plan.get("entries", []) as Array).slice(0, 1)       # you only know the front door
		var brief := "%s\n%s" % [str(target.get("line", "")), Targets.know_line(target)]
		plan["brief"] = brief
		plan["title"] = str(target["name"])
		gen_type = ""
	else:
		lv = BuildingGen.level(level_id)
		plan = lv.get("plan", {})
		gen_type = level_id.split(":")[1] if level_id.begins_with("gen:") else ""
	var hours: Array = plan.get("hours", [])
	var entries: Array = plan.get("entries", [])
	pick["hour"] = str(had.get("hour", hours[0]["id"]))
	pick["entry"] = str(had.get("entry", entries[0]["id"]))
	if not hours.any(func(h: Dictionary) -> bool: return h["id"] == pick["hour"]):
		pick["hour"] = str(hours[0]["id"])
	if not entries.any(func(e: Dictionary) -> bool: return e["id"] == pick["entry"]):
		pick["entry"] = str(entries[0]["id"])


## Another building: this type (or a new one) with a fresh seed.
func reroll(type := "") -> void:
	if type == "":
		type = gen_type
	level_id = "gen:%s:%d" % [type, randi() % 100000]
	if game:
		game.set_meta("fight_level", level_id)
	_load({})


func _process(_d: float) -> void:
	sheet.queue_redraw()


func _on_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var mp: Vector2 = sheet.get_local_mouse_position()
	for h in _hits:
		if (h[0] as Rect2).has_point(mp):
			if game:
				game.click()
			match str(h[1]):
				"hour", "entry":
					pick[h[1]] = h[2]
				"type":
					reroll(str(h[2]))
				"reroll":
					reroll()
				"burn":
					pick["burn"] = not pick.get("burn", false)
				"go":
					go()
				"back":
					if game:
						if not target.is_empty():
							game.remove_meta("fight_target")
							game.goto("res://v2/garage.tscn")
						else:
							game.goto("res://v2/title.tscn")
			return


func go() -> void:
	if game and not target.is_empty():
		var team := Targets.team(game.state, target)
		if team.is_empty():
			game.deny()
			return
		game.set_meta("op_team", team)
		game.set_meta("fight_plan", pick.duplicate())
		game.goto("res://v2/combat/fight.tscn")
		return
	if game:
		game.set_meta("fight_level", level_id)
		game.set_meta("fight_plan", pick.duplicate())
		game.goto("res://v2/combat/fight.tscn")


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.is_pressed():
		return
	match (e as InputEventKey).keycode:
		KEY_ENTER:
			go()
		KEY_R:
			if gen_type != "":
				reroll()


func _draw_sheet() -> void:
	_hits.clear()
	var s := sheet.size
	sheet.draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.05, 0.045))
	var w := minf(s.x - 24.0, 640.0)
	var r := Rect2(Vector2((s.x - w) * 0.5, 10), Vector2(w, s.y - 20))
	# the paper, a little crooked shadow under it
	sheet.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.5))
	sheet.draw_rect(r, Pal.PAPER)
	sheet.draw_rect(r, Pal.INK.lightened(0.3), false, 1.0)
	var x := r.position.x + 12
	var y := r.position.y + 10
	var left_w := w * 0.56 - 18.0
	Pal.text(sheet, Vector2(x, y), "THE PLAN  /  " + str(plan.get("title", "")), 13, Pal.INK, HORIZONTAL_ALIGNMENT_LEFT, w - 140)
	Pal.text(sheet, Vector2(r.end.x - 110, y + 2), "burn after reading", 7, Color(0.5, 0.18, 0.12))
	y += 20
	sheet.draw_line(Vector2(x, y), Vector2(r.end.x - 12, y), Pal.INK, 1.0)
	y += 5
	if gen_type != "":
		y = _type_row(x, y, w - 24)
	Pal.wrap(sheet, Vector2(x, y), str(plan.get("brief", "")), 8, Pal.INK, left_w, 4)
	y += 42
	var y_cards := y
	y = _choices("WHEN", "hour", plan.get("hours", []), x, y, left_w)
	y += 4
	y = _choices("WAY IN", "entry", plan.get("entries", []), x, y, left_w)
	if not target.is_empty():
		_ready_box(Rect2(Vector2(x, y + 2), Vector2(left_w, r.end.y - 34 - (y + 2))))
		var K := Targets.kind(str(target["type"]))
		if K.get("destroy", false):
			var charges := int(game.state.supplies.get("charge", 0))
			var br := Rect2(Vector2(x + 80, r.end.y - 28), Vector2(180, 20))
			var on: bool = pick.get("burn", false)
			sheet.draw_rect(br, Pal.PAPER.darkened(0.12 if br.has_point(sheet.get_local_mouse_position()) else 0.05))
			sheet.draw_rect(br, RED if on else Pal.INK.lightened(0.45), false, 2.0 if on else 1.0)
			Pal.text(sheet, br.position + Vector2(6, 5), ("[X] " if on else "[  ] ") + "BURN IT AFTER" + ("  (%d charge%s)" % [charges, "" if charges == 1 else "s"]), 8,
				Pal.INK if charges > 0 else Pal.INK.lightened(0.5))
			if charges > 0:
				_hits.append([br, "burn", ""])
	# the sketch on the right
	var sk := Rect2(Vector2(x + left_w + 12, y_cards - 44), Vector2(r.end.x - 12 - (x + left_w + 12), r.end.y - 40 - (y_cards - 44)))
	_sketch(sk)
	# GO / back
	var mp: Vector2 = sheet.get_local_mouse_position()
	var go_r := Rect2(Vector2(r.end.x - 112, r.end.y - 28), Vector2(100, 20))
	var back_r := Rect2(Vector2(x, r.end.y - 28), Vector2(70, 20))
	for b in [[go_r, "GO  (Enter)", "go", Color(0.62, 0.22, 0.12)], [back_r, "Not today", "back", Pal.INK.lightened(0.4)]]:
		var br: Rect2 = b[0]
		var on: bool = br.has_point(mp)
		sheet.draw_rect(br, (b[3] as Color).lightened(0.15 if on else 0.0))
		Pal.text(sheet, br.position + Vector2(0, 5), b[1], 9, Pal.PAPER, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
		_hits.append([br, b[2], ""])


## The generator's building types as tabs, and ANOTHER ONE.
func _type_row(x: float, y: float, w: float) -> float:
	var mp: Vector2 = sheet.get_local_mouse_position()
	var T: Dictionary = BuildingGen.data().get("types", {})
	var tx := x
	for t in T:
		var label: String = str(T[t].get("name", t)).to_upper()
		var tw := 8.0 + label.length() * 5.2
		var tr := Rect2(Vector2(tx, y), Vector2(tw, 13))
		var on: bool = t == gen_type
		sheet.draw_rect(tr, Pal.INK.lightened(0.15) if on else Pal.PAPER.darkened(0.1 if tr.has_point(mp) else 0.04))
		Pal.text(sheet, tr.position + Vector2(0, 2), label, 7, Pal.PAPER if on else Pal.INK, HORIZONTAL_ALIGNMENT_CENTER, tw)
		_hits.append([tr, "type", t])
		tx += tw + 4
	var rr := Rect2(Vector2(x + w - 96, y), Vector2(96, 13))
	sheet.draw_rect(rr, RED.lightened(0.15 if rr.has_point(mp) else 0.0))
	Pal.text(sheet, rr.position + Vector2(0, 2), "ANOTHER ONE (R)", 7, Pal.PAPER, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	_hits.append([rr, "reroll", ""])
	return y + 19


## A row of cards; the picked one is ringed in red pencil. Ways in are numbered like the sketch.
func _choices(head: String, kind: String, items: Array, x: float, y: float, w: float) -> float:
	Pal.text(sheet, Vector2(x, y), head, 9, Color(0.5, 0.18, 0.12))
	y += 13
	var n := maxi(1, items.size())
	var cw := (w - (n - 1) * 6.0) / n
	var ch := 70.0
	var mp: Vector2 = sheet.get_local_mouse_position()
	for i in items.size():
		var it: Dictionary = items[i]
		var cr := Rect2(Vector2(x + i * (cw + 6.0), y), Vector2(cw, ch))
		var picked: bool = pick[kind] == str(it["id"])
		sheet.draw_rect(cr, Pal.PAPER.darkened(0.08 if cr.has_point(mp) else 0.03))
		sheet.draw_rect(cr, Pal.INK.lightened(0.45), false, 1.0)
		if picked:
			sheet.draw_rect(cr.grow(2), RED, false, 2.0)
		var title := str(it["title"])
		if kind == "entry":
			title = "%d  %s" % [i + 1, title]
		Pal.text(sheet, cr.position + Vector2(5, 4), title, 8, Pal.INK, HORIZONTAL_ALIGNMENT_LEFT, cw - 10)
		Pal.wrap(sheet, cr.position + Vector2(5, 16), str(it["line"]), 7, Pal.INK.lightened(0.2), cw - 10, 6)
		_hits.append([cr, kind, str(it["id"])])
	return y + ch + 4


## ARE WE READY: what you know against who's going (v2/sim/targets.gd ready_read).
func _ready_box(box: Rect2) -> void:
	var rr := Targets.ready_read(game.state, target, lv, str(pick["hour"]))
	var word := str(rr["word"])
	var col: Color = {"READY": Color(0.25, 0.45, 0.22), "RISKY": Color(0.65, 0.42, 0.1), "NOT READY": RED}.get(word, Pal.INK.lightened(0.3))
	Pal.text(sheet, box.position, "WHAT WE KNOW: %s" % Targets.know_name(target), 8, Color(0.5, 0.18, 0.12))
	Pal.text(sheet, box.position + Vector2(box.size.x - 120, 0), word, 11, col, HORIZONTAL_ALIGNMENT_RIGHT, 120)
	var yy := box.position.y + 13
	for l in rr["lines"]:
		Pal.text(sheet, Vector2(box.position.x, yy), str(l), 7, Pal.INK.lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT, box.size.x)
		yy += 10
	if Targets.kind(str(target["type"])).get("solo", false):
		Pal.text(sheet, Vector2(box.position.x, yy), "A one-person job: only one of you goes.", 7, Pal.INK.lightened(0.15))


## A pencil sketch of the place, north up: rooms, doors, the ways in, what you came for. Guards only as far
## as you've scouted them (M4 V4), and never all of them.
func _sketch(box: Rect2) -> void:
	var rooms: Array = lv.get("rooms", [])
	if rooms.is_empty() or box.size.x < 40 or box.size.y < 40:
		return
	sheet.draw_rect(box, Pal.PAPER.darkened(0.04))
	if not target.is_empty() and int(target["know"]) == 0:
		Pal.text(sheet, box.position + Vector2(0, box.size.y * 0.4), "?", 28, Color(PENCIL, 0.5), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		Pal.text(sheet, box.position + Vector2(0, box.size.y * 0.4 + 36), "WE DON'T KNOW THE INSIDE.", 8, PENCIL, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		Pal.text(sheet, box.position + Vector2(0, box.size.y * 0.4 + 48), "Watch it or hack it first, or go in blind.", 7, PENCIL, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		return
	var b := Rect2()
	var first := true
	for rm in rooms:
		var a: Array = rm["rect"]
		var rc := Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))
		b = rc if first else b.merge(rc)
		first = false
	var sc := minf((box.size.x - 12) / b.size.x, (box.size.y - 12) / b.size.y)
	var o := box.position + (box.size - b.size * sc) * 0.5
	var to := func(px: float, pz: float) -> Vector2: return o + (Vector2(px, pz) - b.position) * sc
	# open ground first, faint; then rooms in pencil with their names
	for rm in rooms:
		if not rm.get("outdoor", false):
			continue
		var a: Array = rm["rect"]
		var p0: Vector2 = to.call(float(a[0]), float(a[1]))
		var p1: Vector2 = to.call(float(a[2]), float(a[3]))
		sheet.draw_rect(Rect2(p0, p1 - p0), Color(PENCIL, 0.07))
	for rm in rooms:
		if rm.get("outdoor", false):
			continue
		var a: Array = rm["rect"]
		var p0: Vector2 = to.call(float(a[0]), float(a[1]))
		var p1: Vector2 = to.call(float(a[2]), float(a[3]))
		var rr := Rect2(p0, p1 - p0)
		sheet.draw_rect(rr, Pal.PAPER.lightened(0.04))
		sheet.draw_rect(rr, PENCIL, false, 1.3)
		if rr.size.x > 24 and rr.size.y > 10:
			Pal.wrap(sheet, rr.position + Vector2(2, 2), str(rm.get("name", "")), 5, Color(PENCIL, 0.85), rr.size.x - 4, 3)
	for d in lv.get("doors", []):
		var p: Vector2 = to.call(float(d["pos"][0]), float(d["pos"][1]))
		var hw := float(d.get("w", 1.0)) * 0.5 * sc
		var along := Vector2(0, 1) if d["axis"] == "x" else Vector2(1, 0)
		sheet.draw_line(p - along * hw, p + along * hw, Pal.PAPER.lightened(0.04), 2.5)
		if d.get("locked", false):
			sheet.draw_line(p - along * hw, p + along * hw, Color(RED, 0.7), 1.0)
	# what you came for
	var ob: Array = lv.get("objective", {}).get("pos", [])
	if ob.size() == 2:
		var op: Vector2 = to.call(float(ob[0]), float(ob[1]))
		sheet.draw_line(op + Vector2(-4, -4), op + Vector2(4, 4), RED, 2.0)
		sheet.draw_line(op + Vector2(-4, 4), op + Vector2(4, -4), RED, 2.0)
	# what scouting showed: guards seen at this hour (pencil dots), the good crate (THE INSIDE)
	if not target.is_empty():
		for e in Targets.known_guards(target, lv, str(pick["hour"])):
			var gp: Vector2 = to.call(float(e["pos"][0]), float(e["pos"][1]))
			sheet.draw_circle(gp, 3.0, Color(0.15, 0.15, 0.2))
			sheet.draw_circle(gp, 1.4, Pal.PAPER)
		if int(target["know"]) >= 3:
			for c in lv.get("loot", []):
				if c.get("good", false):
					var cp: Vector2 = to.call(float(c["pos"][0]), float(c["pos"][1]))
					sheet.draw_rect(Rect2(cp - Vector2(4, 3), Vector2(8, 6)), Color(0.78, 0.45, 0.2))
					Pal.text(sheet, cp + Vector2(6, -5), str(c["label"]), 6, Color(0.6, 0.3, 0.1))
	# the ways in, numbered; the picked one ringed
	var entries: Array = plan.get("entries", [])
	for i in entries.size():
		var e: Dictionary = entries[i]
		var ep: Vector2 = to.call(float(e["pos"][0]), float(e["pos"][1]))
		var on: bool = pick["entry"] == str(e["id"])
		sheet.draw_circle(ep, 6.0, RED if on else Pal.INK.lightened(0.2))
		Pal.text(sheet, ep - Vector2(6, 5), str(i + 1), 7, Pal.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 12)
	Pal.text(sheet, box.position + Vector2(3, box.size.y - 9), "STREET SIDE DOWN.  X = WHAT WE CAME FOR" + ("   o = A GUARD WE SAW" if not target.is_empty() and int(target["know"]) >= 2 else ""), 5, Color(PENCIL, 0.8))
