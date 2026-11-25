extends Control
## The plan before going in (M4 Q11, user 2026-11-25: pick the way in and the hour). A sheet of paper on the
## van's dashboard: the brief, then WHEN and WAY IN, each a few cards with what that choice means. GO runs
## the fight with them (Game meta "fight_plan" = {hour, entry}; fight.gd shapes the level from it).
## Reads the level's "plan" block (data/v2/combat/*.json).

const PixelView := preload("res://v2/ui/pixel_view.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Content := preload("res://v2/sim/content.gd")

var game: Node
var view
var sheet: Control
var plan: Dictionary = {}
var level_id := ""
var pick := {"hour": "", "entry": ""}
var _hits: Array = []           # [Rect2, kind, id]


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_id = str(game.get_meta("fight_level", "combat/kessel_road")) if game else "combat/kessel_road"
	plan = Content.get_file(level_id).get("plan", {})
	var had: Dictionary = game.get_meta("fight_plan", {}) if game else {}
	pick["hour"] = str(had.get("hour", plan["hours"][0]["id"]))
	pick["entry"] = str(had.get("entry", plan["entries"][0]["id"]))
	view = PixelView.new()
	add_child(view)
	sheet = Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.ui.add_child(sheet)
	sheet.draw.connect(_draw_sheet)
	sheet.gui_input.connect(_on_input)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP


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
				"go":
					go()
				"back":
					if game:
						game.goto("res://v2/title.tscn")
			return


func go() -> void:
	if game:
		game.set_meta("fight_plan", pick.duplicate())
		game.goto("res://v2/combat/fight.tscn")


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and (e as InputEventKey).keycode == KEY_ENTER:
		go()


func _draw_sheet() -> void:
	_hits.clear()
	var s := sheet.size
	sheet.draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.05, 0.045))
	var w := minf(s.x - 24.0, 520.0)
	var r := Rect2(Vector2((s.x - w) * 0.5, 10), Vector2(w, s.y - 20))
	# the paper, a little crooked shadow under it
	sheet.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.5))
	sheet.draw_rect(r, Pal.PAPER)
	sheet.draw_rect(r, Pal.INK.lightened(0.3), false, 1.0)
	var x := r.position.x + 12
	var y := r.position.y + 10
	Pal.text(sheet, Vector2(x, y), "THE PLAN  /  " + str(plan.get("title", "")), 13, Pal.INK)
	Pal.text(sheet, Vector2(r.end.x - 110, y + 2), "burn after reading", 7, Color(0.5, 0.18, 0.12))
	y += 20
	sheet.draw_line(Vector2(x, y), Vector2(r.end.x - 12, y), Pal.INK, 1.0)
	y += 6
	Pal.wrap(sheet, Vector2(x, y), str(plan.get("brief", "")), 8, Pal.INK, w - 24, 4)
	y += 44
	y = _choices("WHEN", "hour", plan.get("hours", []), x, y, w - 24)
	y += 6
	y = _choices("WAY IN", "entry", plan.get("entries", []), x, y, w - 24)
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


## A row of cards; the picked one is ringed in red pencil.
func _choices(head: String, kind: String, items: Array, x: float, y: float, w: float) -> float:
	Pal.text(sheet, Vector2(x, y), head, 9, Color(0.5, 0.18, 0.12))
	y += 13
	var n := maxi(1, items.size())
	var cw := (w - (n - 1) * 6.0) / n
	var ch := 74.0
	var mp: Vector2 = sheet.get_local_mouse_position()
	for i in items.size():
		var it: Dictionary = items[i]
		var cr := Rect2(Vector2(x + i * (cw + 6.0), y), Vector2(cw, ch))
		var picked: bool = pick[kind] == str(it["id"])
		sheet.draw_rect(cr, Pal.PAPER.darkened(0.08 if cr.has_point(mp) else 0.03))
		sheet.draw_rect(cr, Pal.INK.lightened(0.45), false, 1.0)
		if picked:
			sheet.draw_rect(cr.grow(2), Color(0.72, 0.12, 0.08), false, 2.0)
		Pal.text(sheet, cr.position + Vector2(5, 4), str(it["title"]), 8, Pal.INK, HORIZONTAL_ALIGNMENT_LEFT, cw - 10)
		Pal.wrap(sheet, cr.position + Vector2(5, 16), str(it["line"]), 7, Pal.INK.lightened(0.2), cw - 10, 6)
		_hits.append([cr, kind, str(it["id"])])
	return y + ch + 4
