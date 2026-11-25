extends Node
## Orders on the overview (docs/CONNECTED_LOOP.md section 9, C2; user 2026-11-24):
## - Right-click the overview: a menu for what's under the mouse, in four groups: MOVE, HOLD, INTERACT, WITHDRAW.
##   (A door: open / kick / flash & clear, breach-flash-wait, blow it, stack up. A room: move here, clear through to
##   here, watch it. One of yours: hold, medic. Anywhere: hold, withdraw.) 1-4 still pick who it's for.
## - Paused, or holding Shift: the order is queued instead, a numbered marker on the overview; queued orders run one
##   after another, each when the squad has finished the last (stacked, holding or idle).
## - HOLD sticks: "HOLDING" beside their name until another order includes them. If something makes a holding
##   fighter leave the spot, they say why.
## - Pushback is two buttons: their way, or do it anyway.

const Pal := preload("res://v2/ui/pal.gd")

var fight: Node
var menu: Array = []             # {label, section, call, enabled}
var menu_at := Vector2.ZERO      # UI units
var menu_title := ""
var menu_hover := -1
var queue: Array = []            # {id, label, line, target, who, pos: Vector3}
var holding := {}                # fighter -> {pos, told}
var _since := 0.0                # time since the last order went out
var _btn_theirs := Rect2()
var _btn_anyway := Rect2()

const ROW_H := 13.0
const MENU_W := 150.0


func setup(p_fight: Node) -> void:
	fight = p_fight


# ------------------------------------------------------------------ the menu

func open_menu(mp: Vector2) -> void:
	var ov = fight.overview
	var img: Rect2 = fight._ov_img()
	var px: Vector2 = (mp - img.position) * Vector2(ov.vp.size) / img.size
	var g: Vector3 = ov.ground_at(px)
	if g == Vector3.INF:
		return
	menu.clear()
	menu_at = mp
	var lv = fight.level
	var sq = fight.sq
	# one of yours?
	var who_hit = null
	for a in fight.squad:
		if a.alive() and Vector2(a.global_position.x, a.global_position.z).distance_to(Vector2(g.x, g.z)) < 0.6:
			who_hit = a
	# a door?
	var door := {}
	var bd := 1.1
	for d in lv.doors:
		var dw: Vector3 = lv.door_world(d)
		var dd := Vector2(dw.x, dw.z).distance_to(Vector2(g.x, g.z))
		if dd < bd:
			bd = dd
			door = d
	var rid: String = lv.room_at(g)
	if who_hit != null:
		var n: String = fight._first(who_hit)
		menu_title = n.to_upper()
		_add("HOLD", "Hold there, %s" % n, func() -> void: _give("hold", "HOLD", "%s, hold there." % n, null, [who_hit]))
		_add("INTERACT", "Medic to %s" % n, func() -> void: _give("medic", "MEDIC", "Medic! Get to %s!" % n, who_hit),
			who_hit.wounds > 0 or who_hit.state == "down")
	elif not door.is_empty():
		menu_title = str(door.get("name", "DOOR")).to_upper()
		if door["state"] == "closed":
			var flashes: bool = sq.alive_fighters().any(func(f) -> bool: return f.flashes > 0)
			var charges: bool = sq.alive_fighters().any(func(f) -> bool: return f.charges > 0)
			_add("INTERACT", "Open & clear", func() -> void: _give("open", "OPEN & CLEAR", "Open it quiet and clear.", door))
			_add("INTERACT", "Kick & clear", func() -> void: _give("breach", "KICK & CLEAR", "Kick it in and clear.", door))
			_add("INTERACT", "Flash & clear", func() -> void: _give("bang", "FLASH & CLEAR", "Bang it and clear.", door), flashes)
			_add("INTERACT", "Breach, flash & wait", func() -> void: _give("bang_wait", "FLASH & WAIT", "Pop the door, flash it, and hold.", door), flashes)
			_add("INTERACT", "Blow it", func() -> void: _give("charge", "BLOW IT", "Blow the door.", door), charges)
			_add("MOVE", "Stack up here", func() -> void: _give("stack", "STACK", "Stack up on that door.", door))
		else:
			var beyond: String = door["b"] if rid == door["a"] else door["a"]
			_add("MOVE", "Clear through", func() -> void: _give("push", "PUSH", "Push through there.", beyond))
	elif rid != "":
		menu_title = str(lv.room(rid).get("name", rid)).to_upper()
		var outside: bool = lv.room(rid).get("outdoor", false)
		var mv = Vector3(g.x, 0, g.z) if outside else rid      # outside: to that spot, bounding cover to cover under fire
		_add("MOVE", "Move here", func() -> void: _give("move", "MOVE", "Move up to there.", mv))
		_add("MOVE", "Clear through to here", func() -> void: _give("push", "PUSH", "Push through to there.", rid))
		_add("INTERACT", "Watch this spot", func() -> void: _give("cover", "WATCH", "Eyes on that.", g + Vector3(0, 1.2, 0)))
	else:
		menu_title = "OUTSIDE"
	_add("HOLD", "Hold" if fight.recipients.is_empty() else "Hold (%s)" % _who_text(fight.recipients), func() -> void: _give("hold", "HOLD", "Hold! Hold there.", null))
	_add("WITHDRAW", "Leave...", func() -> void: fight.leave.open_withdraw())     # the leave card (C5)
	menu_hover = -1
	if fight.game:
		fight.game.sfx.play("tick_004", 1.2, -12.0)


func _add(section: String, label: String, call: Callable, enabled := true) -> void:
	menu.append({"section": section, "label": label, "call": call, "enabled": enabled})


func _who_text(who: Array) -> String:
	return ", ".join(PackedStringArray(who.map(func(a) -> String: return fight._first(a))))


func _menu_rect() -> Rect2:
	var sections := 0
	var last := ""
	for it in menu:
		if it["section"] != last:
			sections += 1
			last = it["section"]
	var h := 16.0 + menu.size() * ROW_H + sections * 10.0 + 4.0
	var r := Rect2(menu_at + Vector2(6, -4), Vector2(MENU_W, h))
	var hs: Vector2 = fight.hud.size
	r.position = r.position.clamp(Vector2(2, 2), hs - r.size - Vector2(2, 2))
	return r


## Row rects in order, matching menu.
func _rows() -> Array:
	var r := _menu_rect()
	var out: Array = []
	var y := r.position.y + 16.0
	var last := ""
	for it in menu:
		if it["section"] != last:
			y += 10.0
			last = it["section"]
		out.append(Rect2(r.position.x + 3, y, r.size.x - 6, ROW_H - 1))
		y += ROW_H
	return out


## Order chosen from the menu: now, or queued (paused, or Shift held).
func _give(id: String, label: String, line: String, target, who = null) -> void:
	var w: Array = fight.recipients.duplicate() if who == null else who
	var entry := {"id": id, "label": label, "line": line, "target": target, "who": w, "pos": _pos_of(target)}
	if fight.paused or Input.is_key_pressed(KEY_SHIFT):
		queue.append(entry)
		fight._event("Queued %d: %s" % [queue.size(), label])
		return
	_send(entry)


func _send(e: Dictionary) -> void:
	_since = 0.0
	var who: Array = e["who"]
	# a new order frees whoever it includes from HOLD; HOLD marks them
	for a in fight.squad:
		if who.is_empty() or who.has(a):
			holding.erase(a)
	if e["id"] == "hold":
		for a in fight.squad:
			if a.alive() and (who.is_empty() or who.has(a)):
				holding[a] = {"pos": a.global_position, "told": false}
	fight.issue(e["id"], e["label"], e["line"], e["target"], who)


func _pos_of(target) -> Vector3:
	var lv = fight.level
	if target is Dictionary:
		return lv.door_world(target)
	if target is String:
		var c: Vector2 = (lv.room(target)["rect"] as Rect2).get_center()
		return Vector3(c.x, 0, c.y)
	if target is Vector3:
		return target
	if target != null and target is Node3D:
		return (target as Node3D).global_position
	return Vector3.INF


# ------------------------------------------------------------------ input

## True if it used the event.
func input(e: InputEvent, mp: Vector2) -> bool:
	if e is InputEventMouseMotion and not menu.is_empty():
		menu_hover = -1
		var rows := _rows()
		for i in rows.size():
			if (rows[i] as Rect2).has_point(mp):
				menu_hover = i
		return false
	if not (e is InputEventMouseButton and e.pressed):
		return false
	if not menu.is_empty():
		if e.button_index == MOUSE_BUTTON_LEFT:
			var rows := _rows()
			for i in rows.size():
				if (rows[i] as Rect2).has_point(mp) and menu[i]["enabled"]:
					var c: Callable = menu[i]["call"]
					menu.clear()
					c.call()
					return true
		menu.clear()
		return true
	if e.button_index == MOUSE_BUTTON_LEFT and not fight.sq.objection.is_empty():
		if _btn_theirs.has_point(mp):
			their_way()
			return true
		if _btn_anyway.has_point(mp):
			anyway()
			return true
	return false


func their_way() -> void:
	var by = fight.sq.objection["by"]
	fight.shout_log.append({"t": fight.t_op, "text": "YOU > OK, %s's way: %s" % [fight._first(by).to_upper(), fight.sq.objection["suggest_label"]]})
	fight.sq.accept_suggestion()


func anyway() -> void:
	var o: Dictionary = fight.sq.objection
	_send({"id": o["kind"], "label": str(o["kind"]).to_upper(), "line": "I said do it. Go!", "target": o["target"], "who": o["who"]})


# ------------------------------------------------------------------ every frame

func tick(delta: float) -> void:
	if fight.paused:
		return
	_since += delta
	# queued orders: the next one when the squad has finished the last
	if not queue.is_empty() and _since > 1.2 and _settled():
		_send(queue.pop_front())
	# HOLD: if something moves a holding fighter, they say why (once per move)
	for a in holding.keys():
		if not is_instance_valid(a) or not a.alive():
			holding.erase(a)
			continue
		var h: Dictionary = holding[a]
		if (a.global_position - (h["pos"] as Vector3)).length() > 1.3 and not h["told"]:
			h["told"] = true
			a.say(_why_moved(a), true)
		elif (a.global_position - (h["pos"] as Vector3)).length() < 0.4:
			h["told"] = false


func _settled() -> bool:
	var sq = fight.sq
	if not sq.objection.is_empty() or sq.in_contact:
		return false
	if not (str(sq.task.get("type", "idle")) in ["hold", "idle", "stacked", "done"]):
		return false
	return sq.alive_fighters().all(func(f) -> bool: return not f.moving())


func _why_moved(a) -> String:
	if fight.sq.task.get("medic_for") != null and a == fight.sq.by_role("medic"):
		return "Moving! Someone's hit, I'm going to them."
	if a.target != null:
		return "Contact! Moving to get an angle on him."
	if a.mag_rounds == 0 and a.mags == 0:
		return "I'm dry, boss. Getting a gun."
	return "Had to move, boss. I was in the open."


func is_holding(a) -> bool:
	return holding.has(a)


# ------------------------------------------------------------------ drawing

func draw(ci: CanvasItem) -> void:
	var img: Rect2 = fight._ov_img()
	var ov = fight.overview
	if img.size.x > 0 and img.size.y > 0:
		var sc := img.size / Vector2(ov.vp.size)
		for i in queue.size():
			var q: Dictionary = queue[i]
			if q["pos"] == Vector3.INF:
				continue
			var px: Vector2 = ov.to_px((q["pos"] as Vector3) + Vector3(0, 0.2, 0))
			if px.x < 0:
				continue
			var p: Vector2 = img.position + px * sc
			ci.draw_circle(p, 7.0, Color(0.05, 0.05, 0.05, 0.85))
			ci.draw_arc(p, 7.0, 0.0, TAU, 20, Color(0.95, 0.72, 0.3), 1.5)
			Pal.text(ci, p - Vector2(7, 6), str(i + 1), 9, Color(0.95, 0.72, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 14)
			Pal.text(ci, p + Vector2(10, -6), str(q["label"]), 8, Color(0.95, 0.85, 0.6))
		if not queue.is_empty():
			Pal.text(ci, img.position + Vector2(6, 4), "QUEUED: %d   (they run in order; Space to go)" % queue.size(), 8, Color(0.95, 0.72, 0.3))
	_draw_objection(ci)
	if menu.is_empty():
		return
	var r := _menu_rect()
	ci.draw_rect(r, Color(0.06, 0.07, 0.07, 0.96))
	ci.draw_rect(r, Color(0.72, 0.68, 0.56), false, 1.0)
	Pal.text(ci, r.position + Vector2(5, 2), menu_title, 9, Color(0.95, 0.72, 0.3))
	var rows := _rows()
	var last := ""
	for i in menu.size():
		var it: Dictionary = menu[i]
		var rr: Rect2 = rows[i]
		if it["section"] != last:
			last = it["section"]
			Pal.text(ci, Vector2(rr.position.x + 2, rr.position.y - 10), last, 7, Color(0.45, 0.72, 0.7))
		if i == menu_hover and it["enabled"]:
			ci.draw_rect(rr, Color(0.95, 0.72, 0.3, 0.18))
		var col := Color(0.9, 0.87, 0.78) if it["enabled"] else Color(0.45, 0.43, 0.4)
		Pal.text(ci, rr.position + Vector2(8, 1), str(it["label"]), 8, col)
	Pal.text(ci, Vector2(r.position.x + 5, r.position.y + 2), "Shift: queue", 7, Color(0.6, 0.58, 0.52), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10)


## Pushback: the reason, then two buttons.
func _draw_objection(ci: CanvasItem) -> void:
	var o: Dictionary = fight.sq.objection
	_btn_theirs = Rect2()
	_btn_anyway = Rect2()
	if o.is_empty() or fight.sq._t - float(o["t"]) > 12.0:
		return
	var img: Rect2 = fight._ov_img()
	var by = o["by"]
	var t1 := "%s OBJECTS: %s" % [fight._first(by).to_upper(), o["reason"]]
	var w := maxf(t1.length() * 5.2 + 16.0, 260.0)
	var r := Rect2(Vector2(img.get_center().x - w * 0.5, img.position.y + 18), Vector2(w, 40))
	ci.draw_rect(r, Color(0.1, 0.05, 0.03, 0.92))
	ci.draw_rect(r, Color(0.95, 0.55, 0.3), false, 1.0)
	Pal.text(ci, r.position + Vector2(6, 3), t1, 8, Color(1.0, 0.7, 0.5))
	_btn_theirs = Rect2(r.position + Vector2(6, 18), Vector2(w * 0.5 - 9, 17))
	_btn_anyway = Rect2(Vector2(r.get_center().x + 3, r.position.y + 18), Vector2(w * 0.5 - 9, 17))
	var mp: Vector2 = fight.hud.get_local_mouse_position()
	for b in [[_btn_theirs, "THEIR WAY: %s  [B]" % o["suggest_label"]], [_btn_anyway, "DO IT ANYWAY"]]:
		var br: Rect2 = b[0]
		ci.draw_rect(br, Color(0.95, 0.72, 0.3, 0.3 if br.has_point(mp) else 0.12))
		ci.draw_rect(br, Color(0.95, 0.72, 0.3), false, 1.0)
		Pal.text(ci, br.position + Vector2(0, 3), str(b[1]), 8, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
