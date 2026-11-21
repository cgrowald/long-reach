extends Control
## The intel you came away with: a clipped paper sheet. Tiers you earned are typed; the rest are redacted.

signal again
signal menu

const Pal := preload("res://v2/ui/pal.gd")

var title := ""
var tiers: Array = []   # {score, label, text}
var score := 0
var heat := 0
var traced := false


func setup(t: String, tr: Array, sc: int, h: int, was_traced: bool) -> void:
	title = t
	tiers = tr
	score = sc
	heat = h
	traced = was_traced
	size = Vector2(260, 212)
	var a := Button.new()
	a.text = "AGAIN"
	a.position = Vector2(150, 186)
	a.size = Vector2(48, 18)
	a.pressed.connect(func() -> void: again.emit())
	add_child(a)
	var m := Button.new()
	m.text = "MENU"
	m.position = Vector2(204, 186)
	m.size = Vector2(48, 18)
	m.pressed.connect(func() -> void: menu.emit())
	add_child(m)


func _draw() -> void:
	draw_rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(Vector2.ZERO, size), Pal.PAPER)
	for y in range(30, int(size.y) - 30, 12):
		draw_line(Vector2(8, y + 10), Vector2(size.x - 8, y + 10), Color(0.6, 0.55, 0.45, 0.35))
	# clip
	draw_rect(Rect2(size.x * 0.5 - 26, -6, 52, 12), Pal.METAL_L)
	draw_rect(Rect2(size.x * 0.5 - 20, -3, 40, 5), Pal.METAL_D)
	Pal.text(self, Vector2(8, 10), "INTEL: " + title, 10, Pal.INK)
	Pal.text(self, Vector2(8, 22), "score %d" % score, 9, Color(0.35, 0.3, 0.25))
	var got := 0
	for i in tiers.size():
		var y := 38.0 + i * 28.0
		var ok := score >= int(tiers[i]["score"])
		Pal.text(self, Vector2(8, y), "%d. %s" % [i + 1, tiers[i]["label"]], 8, Color(0.35, 0.3, 0.25))
		if ok:
			got += 1
			Pal.text(self, Vector2(14, y + 10), str(tiers[i]["text"]), 9, Pal.INK)
		else:
			var w: float = Pal.font().get_string_size(str(tiers[i]["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_rect(Rect2(14, y + 11, minf(w, size.x - 24), 9), Pal.INK)
	Pal.text(self, Vector2(8, 190), "Heat +%d" % heat, 10, Color(0.6, 0.1, 0.08))
	# stamp
	var stamp := "TRACED" if traced else ("CLEAN" if got > 0 else "NOTHING")
	var col := Color(0.75, 0.1, 0.08, 0.85) if traced or got == 0 else Color(0.15, 0.45, 0.15, 0.85)
	draw_set_transform(Vector2(size.x - 70, 22), -0.25, Vector2.ONE)
	draw_rect(Rect2(-4, -2, 66, 20), col, false, 2.0)
	Pal.text(self, Vector2(0, 0), stamp, 14, col, HORIZONTAL_ALIGNMENT_CENTER, 58)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
