extends "res://v2/stations/station.gd"
## The prisoner in the garage (rules: v2/sim/interrogation.gd). They sit tied to a chair under the bulb (in 3D);
## you play approach cards; their face reacts; then let go, recruit, or kill (off-screen).

const Interro := preload("res://v2/sim/interrogation.gd")
const Face := preload("res://v2/ui/face.gd")
const Soldier := preload("res://v2/combat/soldier.gd")

var _model: Node3D
var hover := Vector2(-1, -1)
var _btns: Array = []
var _shake := 0.0
var _flush := 0.0
var _last := ""
var _t := 0.0
var _done_lines: Array = []


func build() -> void:
	var p := Interro.prisoner(game.state)
	if p.is_empty():
		_done_lines = ["Nobody's tied to the chair tonight."]
		return
	# the prisoner in 3D, tied to a chair under the bulb
	_model = Soldier.new()
	garage.world.add_child(_model)
	var guard: bool = p.get("kind", "") == "guard" or str(p.get("offense", "")) == "Guarded the depot"
	_model.setup({"name": p["name"], "camo": "regime_low" if guard else "street", "rig_mesh": "", "back": "", "head": "cap" if guard else "none"})
	_model.position = garage.world.b2g(def.get("seat", [0.0, 0.0, 0.0]))
	_model.rotation.y = deg_to_rad(float(def.get("seat_yaw", 0.0)))
	_model.pose_mode = "hands_up"
	_model.crouch = 0.85
	if _model.light:
		_model.light.visible = false
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 3.5
	lamp.omni_range = 3.0
	lamp.shadow_enabled = true
	_model.add_child(lamp)
	lamp.position = Vector3(0.0, 2.3, 0.5)            # the bulb over the chair
	_last = "\"%s\"" % ["What do you want from me?", "You're making a mistake.", "...", "I just work there."][(hash(p["name"]) & 0x7fffffff) % 4]
	if not p.get("id_seen", false):
		p["id_seen"] = true          # first look: what was in their pockets
		show_id.call_deferred(p)
	game.sfx.play("drop_002", 0.6, -8.0)


func close() -> void:
	if _model and is_instance_valid(_model):
		_model.queue_free()
	super.close()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		for b in _btns:
			if (b[0] as Rect2).has_point(e.position):
				_press(str(b[1]))
				return


func _press(id: String) -> void:
	game.click()
	if id == "close":
		close()
		return
	if id == "id":
		show_id(Interro.prisoner(game.state))
		return
	if id.begins_with("card:"):
		var r := Interro.play(game.state, id.substr(5))
		_last = "\"%s\"" % r["line"]
		if int(r["break"]) >= 20:
			_shake = 1.0
			_flush = 1.0
			game.sfx.play("tick_004", 0.7, -6.0)
		elif int(r["break"]) < 0:
			game.sfx.play("error_006", 0.9, -10.0)
		return
	var roll := randf()
	_done_lines = Interro.decide(game.state, id, roll)
	if _model and is_instance_valid(_model):
		_model.queue_free()
	game.sfx.play("close_001", 0.7, -6.0)
	garage.refresh()


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flush = maxf(0.0, _flush - delta * 1.2)
	queue_redraw()


func _btn(r: Rect2, label: String, id: String, primary := true, enabled := true) -> void:
	var hov := r.has_point(hover) and enabled
	var c := (Pal.BRASS if primary else Pal.METAL_L) if enabled else Pal.METAL
	draw_rect(r, c.lightened(0.15) if hov else c)
	draw_rect(r, Pal.METAL_D, false, 1.0)
	draw_string(Pal.bold(), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Pal.METAL_D if primary and enabled else Pal.TEXT)
	if enabled:
		_btns.append([r, id])


func _draw() -> void:
	_btns = []
	if not _done_lines.is_empty():
		var rr := Rect2(size.x * 0.5 - 160, size.y * 0.5 - 60, 320, 120)
		draw_rect(rr, Color(Pal.METAL_D, 0.96))
		draw_rect(rr, Pal.BRASS, false, 1.0)
		Pal.tag(self, rr.position + Vector2(10, -8), "THE CHAIR", 8)
		var y := rr.position.y + 22
		for ln in _done_lines:
			draw_multiline_string(Pal.font(), Vector2(rr.position.x + 12, y), str(ln), HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 24, 8, -1, Pal.TEXT)
			y += 26
		_btn(Rect2(rr.end.x - 90, rr.end.y - 26, 80, 18), "DONE", "close")
		return
	var st = game.state
	var p := Interro.prisoner(st)
	var g := Interro.grill(st)
	# left: the cards
	var cl := Rect2(14, 40, 170, size.y - 60)
	draw_rect(cl, Color(Pal.METAL_D, 0.92))
	draw_rect(cl, Pal.BRASS, false, 1.0)
	Pal.tag(self, cl.position + Vector2(8, -8), "APPROACH  %d / %d" % [int(g["rounds"]), Interro.ROUNDS], 8)
	var y0 := cl.position.y + 12
	var i := 0
	for id in Interro.CARDS:
		var c: Dictionary = Interro.CARDS[id]
		var enabled: bool = int(g["rounds"]) < Interro.ROUNDS
		if id == "leverage" and not Interro.has_dirt(st):
			enabled = false
		var r := Rect2(cl.position.x + 8, y0 + i * 40, cl.size.x - 16, 36)
		var hov := r.has_point(hover) and enabled
		draw_rect(r, Color(0.22, 0.17, 0.12) if hov else Color(0.16, 0.12, 0.09))
		draw_rect(r, Pal.BRASS if enabled else Pal.METAL, false, 1.0)
		draw_string(Pal.bold(), r.position + Vector2(6, 12), str(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.BRASS if enabled else Pal.DIM)
		draw_multiline_string(Pal.font(), r.position + Vector2(6, 22), str(c["text"]) if enabled or id != "leverage" else "Needs DIRT on them (a hack).", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 7, 2, Pal.TEXT if enabled else Pal.DIM)
		if enabled:
			_btns.append([r, "card:" + id])
		i += 1
	# right: their face and who they are
	var fr := Rect2(size.x - 200, 40, 186, size.y - 60)
	draw_rect(fr, Color(Pal.METAL_D, 0.92))
	draw_rect(fr, Pal.BRASS, false, 1.0)
	Pal.tag(self, fr.position + Vector2(8, -8), "THE PRISONER", 8)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 3.0
	var face_r := Rect2(fr.position + Vector2(43, 10) + sh, Vector2(100, 112))
	Face.draw(self, face_r, str(p.get("face", p.get("name", "?"))), "cap" if str(p.get("offense", "")) == "Guarded the depot" else "", false)
	if _flush > 0.0:
		draw_rect(face_r, Color(0.9, 0.3, 0.2, _flush * 0.25))
	var ty := face_r.end.y + 14
	draw_string(Pal.bold(), Vector2(fr.position.x + 8, ty), str(p.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 16, 9, Pal.TEXT)
	draw_string(Pal.font(), Vector2(fr.position.x + 8, ty + 12), "%d, %s" % [int(p.get("age", 30)), str(p.get("background", {}).get("name", ""))], HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 16, 8, Pal.DIM)
	draw_string(Pal.font(), Vector2(fr.position.x + 8, ty + 24), "In for: " + str(p.get("offense", "?")), HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 16, 8, Pal.DIM)
	# break and trust
	for k in 2:
		var lbl: String = ["BREAK", "TRUST"][k]
		var v: float = float(g["break"] if k == 0 else g["trust"]) / 100.0
		var br := Rect2(fr.position.x + 8, ty + 38 + k * 16, fr.size.x - 16, 6)
		draw_rect(br, Pal.METAL)
		draw_rect(Rect2(br.position, Vector2(br.size.x * v, br.size.y)), Color(1.0, 0.55, 0.3) if k == 0 else Color(0.55, 0.85, 0.55))
		if k == 0:
			draw_line(Vector2(br.position.x + br.size.x * 0.6, br.position.y - 2), Vector2(br.position.x + br.size.x * 0.6, br.end.y + 2), Pal.TEXT, 1.0)
		draw_string(Pal.font(), Vector2(br.position.x, br.position.y - 2), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.DIM)
	_btn(Rect2(fr.position.x + 8, fr.end.y - 26, fr.size.x - 16, 18), "LOOK AT THEIR ID", "id", false)
	_btns.append([face_r, "id"])
	# middle bottom: what they said, and the endings
	var mr := Rect2(196, size.y - 110, size.x - 196 - 210, 92)
	draw_rect(mr, Color(0, 0, 0, 0.7))
	draw_rect(mr, Pal.BRASS, false, 1.0)
	draw_multiline_string(Pal.font(), mr.position + Vector2(8, 16), _last, HORIZONTAL_ALIGNMENT_LEFT, mr.size.x - 16, 9, 2, Pal.TEXT)
	var said: Array = g["said"]
	if not said.is_empty() and str(said[-1]["card"]) == "":
		draw_multiline_string(Pal.font(), mr.position + Vector2(8, 40), str(said[-1]["line"]), HORIZONTAL_ALIGNMENT_LEFT, mr.size.x - 16, 8, 2, Pal.BRASS)
	var can_end: bool = int(g["rounds"]) >= 1
	var bw := (mr.size.x - 24) / 3.0
	_btn(Rect2(mr.position.x + 6, mr.end.y - 24, bw, 18), "LET GO", "let_go", false, can_end)
	_btn(Rect2(mr.position.x + 12 + bw, mr.end.y - 24, bw, 18), "RECRUIT (%d%%)" % int(Interro.recruit_chance(st) * 100), "recruit", true, can_end)
	_btn(Rect2(mr.position.x + 18 + bw * 2, mr.end.y - 24, bw, 18), "KILL", "kill", false, can_end)
	if not can_end:
		draw_string(Pal.font(), Vector2(mr.position.x + 8, mr.end.y - 30), "Talk to them first.", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.DIM)
