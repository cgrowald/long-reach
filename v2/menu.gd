extends Control
## v2 toy picker. Two hacking minigame toys to compare by playing.

const Pal := preload("res://v2/ui/pal.gd")
const PixelRoot := preload("res://v2/ui/pixel_root.gd")
const Sfx := preload("res://v2/ui/sfx.gd")

const TOYS := [
	{"scene": "res://v2/pit_toy.tscn", "title": "PACKET PIT", "like": "like Ball x Pit",
		"lines": ["Aim at the network. Pull SEND.", "Packets bounce, break nodes,", "build chips x mult."]},
	{"scene": "res://v2/hand_toy.tscn", "title": "BREACH HAND", "like": "like Balatro",
		"lines": ["Pick packet cards. Pull SEND.", "Play protocols (poker hands),", "build chips x mult."]},
]

var g: Control
var sfx
var _hover := -1
var _t := 0.0


func _ready() -> void:
	g = PixelRoot.make(self)
	sfx = Sfx.new()
	add_child(sfx)
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	g.draw.connect(_draw_menu)
	g.gui_input.connect(_on_input)


func _rect(i: int) -> Rect2:
	return Rect2(40 + i * 236, 96, 216, 150)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := -1
		for i in TOYS.size():
			if _rect(i).has_point(event.position):
				h = i
		if h != _hover and h >= 0:
			sfx.play("tick_002", 1.3, -14.0)
		_hover = h
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		sfx.play("switch_002", 1.0, -4.0)
		get_tree().change_scene_to_file(TOYS[_hover]["scene"])


func _process(delta: float) -> void:
	_t += delta
	g.queue_redraw()


func _draw_menu() -> void:
	g.draw_rect(Rect2(Vector2.ZERO, g.size), Pal.BG)
	for y in range(1, int(g.size.y), 2):
		g.draw_line(Vector2(0, y), Vector2(g.size.x, y), Color(0, 0, 0, 0.25))
	Pal.text(g, Vector2(0, 26), "UPRISING", 28, Pal.PHOS, HORIZONTAL_ALIGNMENT_CENTER, g.size.x)
	Pal.text(g, Vector2(0, 60), "v2 toys: two ways to hack. Play both, pick one.", 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, g.size.x)
	for i in TOYS.size():
		var r := _rect(i)
		var hov := i == _hover
		Pal.plate(g, r, Pal.METAL if not hov else Pal.METAL_L)
		Pal.screw(g, r.position + Vector2(4, 4))
		Pal.screw(g, Vector2(r.end.x - 4, r.position.y + 4))
		Pal.screw(g, Vector2(r.position.x + 4, r.end.y - 4))
		Pal.screw(g, r.end - Vector2(4, 4))
		var sr := Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 24, 86))
		Pal.well(g, sr, Pal.SCREEN)
		Pal.text(g, sr.position + Vector2(0, 8), TOYS[i]["title"], 18, Pal.PHOS, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
		Pal.text(g, sr.position + Vector2(0, 30), TOYS[i]["like"], 9, Pal.AMBER, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
		for j in TOYS[i]["lines"].size():
			Pal.text(g, sr.position + Vector2(0, 46 + j * 11), TOYS[i]["lines"][j], 9, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
		var on := hov and fmod(_t, 0.6) < 0.4
		Pal.lamp(g, Vector2(r.get_center().x, r.end.y - 26), 6.0, on or not hov, Pal.GREEN if hov else Pal.AMBER)
		Pal.text(g, Vector2(r.position.x, r.end.y - 16), "PLAY" if hov else "", 9, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	Pal.text(g, Vector2(0, 268), "Score sets how good the intel is. Fill the trace lamps and you're TRACED.", 9, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, g.size.x)
	Pal.text(g, Vector2(0, 282), "Placeholder art. Esc in a toy comes back here.", 8, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, g.size.x)
