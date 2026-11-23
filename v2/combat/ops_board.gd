extends Control
## The ops board (docs/COMBAT_SLICE.md section 9): a paper floor plan beside the feeds. You point here,
## you watch through the cams. Your people are tracker dots; enemies are marks only where someone saw
## them, fading to "last seen". The plan comes from intel: with the blueprint every room is drawn;
## without it, rooms are sketched as your people walk them.
## Left-click a dot: watch that fighter and talk to them. Right-click a door, a room or a dot: orders.

const Pal := preload("res://v2/ui/pal.gd")
const PAPER := Color(0.78, 0.74, 0.62)
const INK := Color(0.16, 0.14, 0.12)
const FADE := 12.0

var fight: Control
var blueprint := true
var known := {}               # room id -> true
var menu: Array = []          # [[label, Callable], ...] while open
var menu_pos := Vector2.ZERO
var menu_hover := -1
var _scale := 1.0
var _origin := Vector2.ZERO
var _bounds := Rect2()
var zoom := 1.0                # 1 = the whole plan fits; wheel zooms around the cursor
var pan := Vector2.ZERO        # board pixels, added to the fitted origin
var _dragging := false
var _drag_moved := 0.0
const ZOOM_MAX := 6.0


func setup(p_fight: Control, p_blueprint: bool) -> void:
	fight = p_fight
	blueprint = p_blueprint
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var lv = fight.level
	_bounds = lv.rooms[0]["rect"]
	for r in lv.rooms:
		_bounds = _bounds.merge(r["rect"])
		if blueprint:
			known[r["id"]] = true


func _fit() -> void:
	var o0 := _fit_origin()
	_scale = _fit_scale() * zoom
	# keep the middle of the board over the plan, so you can't lose it off the edge
	var c := size * 0.5
	var span := _bounds.size * _scale
	var o := o0 + pan
	if zoom <= 1.0:
		o = o0
	else:
		o.x = clampf(o.x, c.x - span.x, c.x)
		o.y = clampf(o.y, c.y - span.y, c.y)
	pan = o - o0
	_origin = o


func _inner() -> Rect2:
	return Rect2(Vector2(6, 14), size - Vector2(12, 20))


func _fit_scale() -> float:
	var inner := _inner()
	return minf(inner.size.x / _bounds.size.x, inner.size.y / _bounds.size.y)


## Where the plan's corner sits at zoom 1 (and the anchor `pan` is measured from at every zoom).
func _fit_origin() -> Vector2:
	var inner := _inner()
	var s := _fit_scale() * zoom
	return inner.position + (inner.size - _bounds.size * s) * 0.5


## Zoom by `f` keeping the plan point under `at` (board pixels) where it is.
func zoom_at(at: Vector2, f: float) -> void:
	_fit()
	var w := (at - _origin) / _scale              # plan units from the corner
	zoom = clampf(zoom * f, 1.0, ZOOM_MAX)
	var s := _fit_scale() * zoom
	pan = (at - w * s) - _fit_origin()
	_fit()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO


func to_board(p: Vector3) -> Vector2:
	return _origin + (Vector2(p.x, p.z) - _bounds.position) * _scale


func to_world(b: Vector2) -> Vector3:
	var q := (b - _origin) / _scale + _bounds.position
	return Vector3(q.x, 0, q.y)


func _process(_d: float) -> void:
	if not blueprint:
		for a in fight.squad:
			if a.state == "ok":
				var r: String = fight.level.room_at(a.global_position)
				if r != "":
					known[r] = true
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_fit()
	var lv = fight.level
	draw_rect(Rect2(Vector2.ZERO, size), Color(PAPER, 0.93))
	for r in lv.rooms:
		var rc: Rect2 = r["rect"]
		var br := Rect2(to_board(Vector3(rc.position.x, 0, rc.position.y)), rc.size * _scale)
		if known.get(r["id"], false):
			var cleared: bool = fight.sq.cleared.get(r["id"], false)
			draw_rect(br, Color(0.55, 0.7, 0.5, 0.25) if cleared and r["id"] != "hall" else Color(1, 1, 1, 0.12))
			draw_rect(br, INK, false, 1.0)
			if br.size.x > 26:
				Pal.text(self, br.position + Vector2(2, 1), _short(r["name"]), 8, Color(INK, 0.7), HORIZONTAL_ALIGNMENT_LEFT, br.size.x - 3)
		else:
			_dotted(br)
	for d in lv.doors:
		var a_known: bool = known.get(d["a"], false) or known.get(d["b"], false)
		if not a_known:
			continue
		var c := to_board(lv.door_world(d))
		var along := Vector2(0, 1) if d["axis"] == "x" else Vector2(1, 0)
		var half := along * 0.5 * _scale
		var col := Color(0.85, 0.2, 0.15) if d["locked"] and d["state"] == "closed" else (INK if d["state"] == "closed" else Color(PAPER, 1.0))
		draw_line(c - half, c + half, col, 3.0)
	# the objective
	var ob: Vector3 = lv.objective_pos
	if ob != Vector3.ZERO and known.get(lv.data.get("objective", {}).get("room", ""), false):
		var oc := to_board(ob)
		draw_colored_polygon(PackedVector2Array([oc + Vector2(0, -4), oc + Vector2(3, 3), oc + Vector2(-3, 3)]), Color(0.9, 0.6, 0.1) if not fight.sq.have_objective else Color(0.3, 0.6, 0.3))
	# enemies, only as seen
	var now := float(fight.t_op)
	for e in fight.enemies:
		if not e.has_meta("seen_t"):
			continue
		var age := now - float(e.get_meta("seen_t"))
		var p := to_board(e.get_meta("seen_pos"))
		if e.state in ["dead", "down", "cuffed"]:
			_x(p, Color(0.4, 0.4, 0.4), 2.0)
		elif e.state == "surrendered":
			draw_circle(p, 2.5, Color(0.9, 0.7, 0.2))
		elif age < FADE:
			_x(p, Color(0.8, 0.1, 0.05, 1.0 - age / FADE * 0.7), 3.0)
		else:
			Pal.text(self, p - Vector2(2, 4), "?", 8, Color(0.6, 0.1, 0.05, 0.6))
	# ours
	for i in fight.squad.size():
		var a = fight.squad[i]
		var p := to_board(a.global_position)
		var col: Color = fight.NAME_COL[i % 4]
		if a.state == "dead":
			_x(p, Color(0.2, 0.2, 0.2), 3.0)
			continue
		draw_circle(p, 3.5, Color(0.1, 0.1, 0.1))
		draw_circle(p, 2.5, col if a.state == "ok" else Color(1, 0.3, 0.2))
		var fwd := Vector2(-sin(a.face_yaw), -cos(a.face_yaw))
		draw_line(p, p + fwd * 6.0, Color(0.1, 0.1, 0.1), 1.0)
		Pal.text(self, p + Vector2(4, -6), str(i + 1), 8, INK)
		if fight.recipients.has(a):
			draw_arc(p, 6.0, 0, TAU, 12, Color(0.9, 0.5, 0.1), 1.0)
	# the title strip and frame on top, so a zoomed plan slides under them
	draw_rect(Rect2(0, 0, size.x, 12), Color(PAPER, 0.97))
	Pal.text(self, Vector2(4, 2), "OPS BOARD  " + ("BLUEPRINT" if blueprint else "SKETCH"), 8, INK)
	var zt := "x%.1f" % zoom if zoom > 1.0 else "wheel: zoom"
	Pal.text(self, Vector2(size.x - 64, 2), zt, 8, Color(INK, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, 60)
	draw_rect(Rect2(Vector2.ZERO, size), INK, false, 1.0)
	if not menu.is_empty():
		_draw_menu()


func _short(n: String) -> String:
	return n.split(" ")[0] if n.length() > 10 else n


func _x(p: Vector2, c: Color, r: float) -> void:
	draw_line(p - Vector2(r, r), p + Vector2(r, r), c, 1.5)
	draw_line(p + Vector2(-r, r), p + Vector2(r, -r), c, 1.5)


func _dotted(r: Rect2) -> void:
	var c := Color(INK, 0.3)
	for k in range(0, int(r.size.x), 4):
		draw_line(r.position + Vector2(k, 0), r.position + Vector2(k + 2, 0), c)
		draw_line(Vector2(r.position.x + k, r.end.y), Vector2(r.position.x + k + 2, r.end.y), c)
	for k in range(0, int(r.size.y), 4):
		draw_line(r.position + Vector2(0, k), r.position + Vector2(0, k + 2), c)
		draw_line(Vector2(r.end.x, r.position.y + k), Vector2(r.end.x, r.position.y + k + 2), c)


func _menu_rect() -> Rect2:
	var w := 10.0
	for m in menu:
		w = maxf(w, str(m[0]).length() * 5.0 + 8.0)
	var r := Rect2(menu_pos, Vector2(w, menu.size() * 10 + 4))
	r.position.x = minf(r.position.x, size.x - r.size.x - 1)
	r.position.y = minf(r.position.y, size.y - r.size.y - 1)
	return r


func _draw_menu() -> void:
	var r := _menu_rect()
	draw_rect(r, Color(0.08, 0.07, 0.07, 0.96))
	draw_rect(r, Color(0.9, 0.6, 0.2), false, 1.0)
	for i in menu.size():
		var y := r.position.y + 2 + i * 10
		if i == menu_hover:
			draw_rect(Rect2(r.position.x + 1, y, r.size.x - 2, 10), Color(0.9, 0.5, 0.1, 0.5))
		Pal.text(self, Vector2(r.position.x + 4, y), menu[i][0], 8, Color(1, 0.95, 0.85))


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and not menu.is_empty():
		var r := _menu_rect()
		menu_hover = int((e.position.y - r.position.y - 2) / 10) if r.has_point(e.position) else -1
	# pan: drag with the left (on empty paper) or middle button
	if e is InputEventMouseMotion and _dragging:
		pan += e.relative
		_drag_moved += e.relative.length()
		accept_event()
		return
	if e is InputEventMouseButton and not e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_MIDDLE):
		_dragging = false
		return
	if not (e is InputEventMouseButton and e.pressed):
		return
	accept_event()
	var p: Vector2 = e.position
	if menu.is_empty():
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(p, 1.25)
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(p, 0.8)
			return
		if e.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = true
			return
		if e.button_index == MOUSE_BUTTON_LEFT and e.double_click:
			reset_view()
			return
	if not menu.is_empty():
		var r := _menu_rect()
		if e.button_index == MOUSE_BUTTON_LEFT and r.has_point(p):
			var i := int((p.y - r.position.y - 2) / 10)
			if i >= 0 and i < menu.size():
				var cb: Callable = menu[i][1]
				menu.clear()
				cb.call()
				return
		menu.clear()
		return
	var hit := _hit(p, e.button_index == MOUSE_BUTTON_RIGHT)
	if e.button_index == MOUSE_BUTTON_LEFT:
		if hit.has("fighter"):
			var a = hit["fighter"]
			fight.main_i = fight.squad.find(a)
			fight.recipients = [a]
		else:
			_dragging = true          # empty paper: drag to pan
			_drag_moved = 0.0
		return
	if e.button_index != MOUSE_BUTTON_RIGHT:
		return
	menu_pos = p
	menu_hover = -1
	if hit.has("fighter"):
		var a = hit["fighter"]
		menu = [
			["Medic to " + fight._first(a), func() -> void: fight.issue("medic", "MEDIC", "Medic! Get to them!", a)],
			["Watch their cam", func() -> void: fight.main_i = fight.squad.find(a)],
		]
	elif hit.has("door"):
		var d: Dictionary = hit["door"]
		menu = [
			["Stack up", func() -> void: fight.issue("stack", "STACK", "Stack up on that door.", d)],
			["Open & clear", func() -> void: fight.issue("open", "OPEN & CLEAR", "Open it quiet and clear.", d)],
			["Kick & clear", func() -> void: fight.issue("breach", "KICK & CLEAR", "Kick it in and clear.", d)],
			["Flash & clear", func() -> void: fight.issue("bang", "FLASH & CLEAR", "Bang it and clear.", d)],
			["Breach, flash & wait", func() -> void: fight.issue("bang_wait", "FLASH & WAIT", "Pop the door, flash it, and hold.", d)],
			["Blow it (charge)", func() -> void: fight.issue("charge", "BLOW IT", "Blow the door.", d)],
		]
	elif hit.has("room"):
		var rid: String = hit["room"]
		var pt := to_world(p)
		menu = [
			["Move here", func() -> void: fight.issue("move", "MOVE", "Move up to there.", rid)],
			["Clear through to here", func() -> void: fight.issue("push", "PUSH", "Push through to there.", rid)],
			["Watch this spot", func() -> void: fight.issue("cover", "WATCH", "Eyes on that.", pt)],
			["Hold", func() -> void: fight.issue("hold", "HOLD", "Hold! Hold there.", null)],
		]


## What's under the cursor. Right-click (orders) prefers a door over a fighter standing next to it;
## left-click (pick who to watch) prefers the fighter. Doors get a generous target.
func _hit(p: Vector2, prefer_door := false) -> Dictionary:
	var lv = fight.level
	var door := {}
	var dd := 9.0
	for d in lv.doors:
		if known.get(d["a"], false) or known.get(d["b"], false):
			var dist := to_board(lv.door_world(d)).distance_to(p)
			if dist < dd:
				dd = dist
				door = d
	var who = null
	var fd := 6.0
	for a in fight.squad:
		if a.state != "dead":
			var dist := to_board(a.global_position).distance_to(p)
			if dist < fd:
				fd = dist
				who = a
	if prefer_door and not door.is_empty():
		return {"door": door}
	if who != null:
		return {"fighter": who}
	if not door.is_empty():
		return {"door": door}
	var w := to_world(p)
	var r: String = lv.room_at(w)
	if r != "" and known.get(r, false):
		return {"room": r}
	return {}
