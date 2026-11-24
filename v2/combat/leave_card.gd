extends Node
## Leaving is a decision you feel good about (docs/CONNECTED_LOOP.md sections 4 and 8, C5): a card with the
## choices the game recognises, what each takes home and what it risks, and where backup stands. The fight
## pauses while it's up. Opened at the vault PC (the depot raid) and by the WITHDRAW order.
##   freight  = OUT WITH THE FREIGHT: skip the vault, carry out the stores you came for
##   vault    = STAY FOR THE VAULT: the stick goes in; one door, then the system locks out
##   everyone = GET EVERYONE OUT NOW: leave the boxes, nobody else gets hurt for them
##   stay     = keep going (only from WITHDRAW)

const Pal := preload("res://v2/ui/pal.gd")

signal chosen(id: String)

var fight: Node
var options: Array = []          # {id, title, line, risk, enabled}
var title := ""
var _rects: Array = []
var _was_paused := false


func setup(p_fight: Node) -> void:
	fight = p_fight


func is_open() -> bool:
	return not options.is_empty()


func open(p_title: String, p_options: Array) -> void:
	title = p_title
	options = p_options
	_was_paused = fight.paused
	fight.paused = true
	if fight.game:
		fight.game.sfx.play("maximize_006", 0.9, -10.0)


func close() -> void:
	options = []
	fight.paused = _was_paused


## Backup in plain words, for the risk lines.
func backup_text() -> String:
	var op = fight.op
	if op == null:
		return "Nobody's called it in."
	if op.reinforced:
		return "BACKUP IS HERE."
	if op.backup > 0.0:
		return "Backup in %d:%02d%s." % [int(op.backup) / 60, int(op.backup) % 60, " (alarm)" if op.alarm else " (neighbours)"]
	return "Quiet so far: nobody's called it in." if not op.loud else "Shots fired: someone will call it in."


## The WITHDRAW order: the card for the moment you're in.
func open_withdraw() -> void:
	var opts: Array = []
	var have: bool = fight.sq.have_objective
	if have:
		var what := "the haul" if fight.op and fight.op.opened >= 0 else "the freight"
		opts.append({"id": "freight", "title": "OUT WITH %s" % what.to_upper(), "line": "Bound back to the van with what you carry.", "risk": backup_text(), "enabled": true})
	opts.append({"id": "everyone", "title": "GET EVERYONE OUT NOW", "line": "Drop the boxes. The hurt get carried. Nobody else gets hit for freight." if have else "Abort. Bound back to the van; the job's not done.", "risk": _hurt_text(), "enabled": true})
	opts.append({"id": "stay", "title": "KEEP GOING", "line": "Never mind. Carry on.", "risk": "", "enabled": true})
	open("LEAVE?", opts)


func _hurt_text() -> String:
	var down := 0
	var hurt := 0
	for a in fight.squad:
		if a.state == "down":
			down += 1
		elif a.state == "ok" and (a.wounds > 0 or a.hp < 55.0):
			hurt += 1
	if down + hurt == 0:
		return "Everyone's on their feet."
	return "%s%s%s." % ["%d down (carried, slow)" % down if down > 0 else "", ", " if down > 0 and hurt > 0 else "", "%d hurt" % hurt if hurt > 0 else ""]


func input(e: InputEvent, mp: Vector2) -> bool:
	if not is_open():
		return false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for r in _rects:
			if (r[0] as Rect2).has_point(mp) and options[r[1]]["enabled"]:
				var id: String = options[r[1]]["id"]
				close()
				chosen.emit(id)
				return true
		return true
	if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_4:
		var i: int = e.keycode - KEY_1
		if i < options.size() and options[i]["enabled"]:
			var id2: String = options[i]["id"]
			close()
			chosen.emit(id2)
		return true
	return e is InputEventMouseButton or e is InputEventKey


func draw(ci: CanvasItem) -> void:
	_rects.clear()
	if not is_open():
		return
	var img: Rect2 = fight._ov_img()
	if img.size.x < 60.0 or img.size.y < 60.0:
		return
	ci.draw_rect(img, Color(0, 0, 0, 0.45))
	var w := minf(470.0, img.size.x - 40.0)
	var row := 50.0
	var h := 30.0 + options.size() * (row + 6.0) + 8.0
	var r := Rect2(img.get_center() - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(r, Color(0.07, 0.075, 0.07, 0.97))
	ci.draw_rect(r, Color(0.95, 0.72, 0.3), false, 2.0)
	Pal.text(ci, r.position + Vector2(10, 7), title, 11, Color(0.95, 0.72, 0.3))
	Pal.text(ci, Vector2(r.position.x, r.end.y + 3), "Paused.  Pick 1-%d or click." % options.size(), 8, Color(0.75, 0.72, 0.65), HORIZONTAL_ALIGNMENT_CENTER, w)
	var mp: Vector2 = fight.hud.get_local_mouse_position()
	for i in options.size():
		var o: Dictionary = options[i]
		var rr := Rect2(r.position + Vector2(8, 28 + i * (row + 6)), Vector2(w - 16, row))
		var on: bool = rr.has_point(mp) and o["enabled"]
		ci.draw_rect(rr, Color(0.95, 0.72, 0.3, 0.16 if on else 0.05))
		ci.draw_rect(rr, Color(0.95, 0.72, 0.3) if o["enabled"] else Color(0.35, 0.33, 0.3), false, 1.0)
		var col := Color(0.95, 0.9, 0.8) if o["enabled"] else Color(0.45, 0.43, 0.4)
		Pal.text(ci, rr.position + Vector2(6, 3), "%d  %s" % [i + 1, o["title"]], 9, Color(0.95, 0.72, 0.3) if o["enabled"] else col)
		Pal.wrap(ci, rr.position + Vector2(18, 14), str(o["line"]), 8, col, rr.size.x - 26, 2)
		if str(o["risk"]) != "":
			Pal.text(ci, rr.position + Vector2(18, 37), str(o["risk"]), 7, Color(1.0, 0.6, 0.45) if o["enabled"] else col, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 24)
		_rects.append([rr, i])
