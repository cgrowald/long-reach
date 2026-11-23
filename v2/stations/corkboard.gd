extends "res://v2/stations/station.gd"
## The corkboard: the hunt (docs/HUNT.md). Inspector, suspect pool, pinned facts on strings.
## Placeholder: shows the debug view. In the real game you only see this once you've earned Bureau access.

var _t := 0.0
var _notes: Array = []     # {rect, text, pinned}


func build() -> void:
	var w: Dictionary = Content.world().get("inspector", {})
	var facts: Array = w.get("facts", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := [Vector2(150, 60), Vector2(300, 50), Vector2(390, 120), Vector2(250, 150), Vector2(140, 170), Vector2(380, 200)]
	for i in facts.size():
		var p: Vector2 = spots[i % spots.size()] + Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6))
		_notes.append({"rect": Rect2(p, Vector2(92, 34)), "text": facts[i]["fact"], "pinned": facts[i]["pinned"]})
	# clues from your own blown jobs (hack.gd), pinned by the inspector
	var clues: Array = game.state.flags.get("clues", [])
	for k in clues.size():
		var cp := Vector2(300 + k * 10, 108 + k * 7)
		_notes.append({"rect": Rect2(cp, Vector2(92, 34)), "text": "NEW: " + str(clues[k]), "pinned": true})
	var K = load("res://v2/sim/krall.gd")
	if K.k(game.state)["search_due"] and not K.k(game.state)["hidden"]:
		var hb := Kit.button("Hide the stash (1 night action)", func() -> void:
			if garage.spend(1.5):
				K.hide(game.state)
				garage.toast("The stash is under the floor and behind the boards. Let them look.")
				close(), game)
		hb.position = Vector2(150, size.y - 26)
		add_child(hb)
	var close_b := Kit.button("Back", close, game)
	close_b.position = Vector2(size.x - 52, size.y - 26)
	add_child(close_b)
	game.sfx.play("drop_002", 0.8, -10.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var st = game.state
	var w: Dictionary = Content.world().get("inspector", {})
	var board := Rect2(Vector2(16, 12), size - Vector2(32, 24))
	draw_rect(board, Color(0.42, 0.3, 0.19))
	for i in 140:
		var x := fposmod(i * 37.3, board.size.x)
		var y := fposmod(i * 23.7 + i * i * 0.3, board.size.y)
		draw_rect(Rect2(board.position + Vector2(x, y), Vector2(2, 1)), Color(0.33, 0.22, 0.13))
	draw_rect(board, Color(0.2, 0.13, 0.08), false, 3.0)
	# Inspector card.
	var ic := Rect2(board.position + Vector2(12, 12), Vector2(96, 120))
	draw_rect(ic, Pal.PAPER)
	draw_rect(Rect2(ic.position + Vector2(8, 8), Vector2(80, 64)), Color(0.24, 0.22, 0.24))
	draw_circle(ic.position + Vector2(48, 32), 14, Color(0.4, 0.36, 0.38))
	draw_rect(Rect2(ic.position + Vector2(28, 48), Vector2(40, 24)), Color(0.4, 0.36, 0.38))
	Pal.text(self, ic.position + Vector2(6, 76), str(w.get("name", "?")), 8, Pal.INK)
	Pal.text(self, ic.position + Vector2(6, 87), str(w.get("rank", "")), 8, Pal.INK.lightened(0.3))
	Pal.text(self, ic.position + Vector2(6, 100), ", ".join(PackedStringArray(w.get("traits", []))), 8, Color(0.5, 0.08, 0.06))
	var pin_c := ic.position + Vector2(48, 2)
	# Strings from the inspector to each pinned fact.
	for n in _notes:
		var r: Rect2 = n["rect"]
		if n["pinned"]:
			draw_line(pin_c, board.position + r.position + Vector2(r.size.x * 0.5, 2), Color(0.75, 0.1, 0.1), 1.0)
	for n in _notes:
		var r: Rect2 = n["rect"]
		r.position += board.position
		draw_rect(r, Pal.PAPER if n["pinned"] else Pal.PAPER.darkened(0.35))
		Pal.wrap(self, r.position + Vector2(4, 4), str(n["text"]), 8, Pal.INK, r.size.x - 6, 2)
		if not n["pinned"]:
			Pal.text(self, r.position + Vector2(4, 23), "? not proven", 8, Color(0.5, 0.08, 0.06))
		draw_circle(r.position + Vector2(r.size.x * 0.5, 2), 2.5, Color(0.85, 0.15, 0.1))
	draw_circle(pin_c, 3.0, Color(0.85, 0.15, 0.1))
	# Krall's next move (v2/sim/krall.gd)
	var K = load("res://v2/sim/krall.gd")
	var kr := Rect2(Vector2(board.position.x + 12, board.end.y - 92), Vector2(200, 78))
	draw_rect(kr, Color(0.1, 0.08, 0.08))
	draw_rect(kr, Color(0.75, 0.15, 0.1) if K.k(st)["search_due"] else Pal.DIM, false, 1.0)
	Pal.text(self, kr.position + Vector2(6, 4), K.summary(st), 8, Color(1.0, 0.5, 0.35) if K.k(st)["search_due"] else Pal.TEXT)
	var ly := kr.position.y + 18
	var log: Array = K.k(st)["log"]
	for e in log.slice(maxi(0, log.size() - 4)):
		Pal.text(self, Vector2(kr.position.x + 6, ly), "day %d: %s" % [int(e["day"]), e["text"]], 8, Pal.DIM)
		ly += 13
	# Pool.
	var pr := Rect2(Vector2(board.end.x - 128, board.end.y - 70), Vector2(116, 44))
	draw_rect(pr, Color(0.1, 0.08, 0.08))
	Pal.text(self, pr.position + Vector2(6, 4), "SUSPECT POOL", 8, Pal.DIM)
	Pal.text(self, pr.position + Vector2(6, 16), str(st.pool), 20, Pal.PHOS)
	var banner := "DEBUG VIEW: in the real game you earn this board"
	Pal.text(self, Vector2(0, board.end.y - 14), banner, 8, Color(1, 0.9, 0.6, 0.6 + 0.3 * sin(_t * 3.0)), HORIZONTAL_ALIGNMENT_CENTER, size.x)
