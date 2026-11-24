extends Control
## In-game HUD on the pixel layer: day and clock with hour pips, money, suspect pool and attention lamp,
## the facing name, the hover tag next to the object, and toasts.

const Pal := preload("res://v2/ui/pal.gd")

var game: Node
var facing_text := ""
var hover_sign: Array = []      # the station's status sign (v2/sim/tonight.gd signs): rows {text, tag, ok}
var left_text := ""
var right_text := ""
var hover_title := ""
var hover_hint := ""
var hover_cost := ""
var hover_pos := Vector2(-100, -100)
var hint_line := ""
var show_hints := true
var compact := false          # a station screen is open: only toasts
var _toast := ""
var _toast_t := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func toast(s: String, dur := 2.2) -> void:
	_toast = s
	_toast_t = dur


func _process(delta: float) -> void:
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	queue_redraw()


func _draw() -> void:
	var st = game.state
	if st == null:
		return
	var w := size.x
	if compact:
		_draw_toast(w)
		return
	# Day and clock.
	var r := Rect2(4, 4, 112, 30)
	Pal.plate(self, r, Pal.METAL_D)
	Pal.text(self, r.position + Vector2(5, 3), "DAY %d" % st.day, 10, Pal.AMBER)
	Pal.text(self, r.position + Vector2(60, 3), st.clock_text(), 10, Pal.PHOS)
	# night actions: only big things cost one (docs/ECONOMY.md section 7)
	Pal.text(self, r.position + Vector2(5, 17), "NIGHT", 8, Pal.DIM)
	for i in int(st.actions_max):
		Pal.lamp(self, Vector2(r.position.x + 40 + i * 13, r.position.y + 21), 3.5, i < int(st.actions), Pal.AMBER if int(st.actions) > 1 else Pal.MULT)
	if st.flags.get("night_shift", false):
		Pal.text(self, r.position + Vector2(70, 17), "shift", 8, Pal.DIM)
	# Money, suspects, attention.
	var r2 := Rect2(w - 164, 4, 160, 42)
	Pal.plate(self, r2, Pal.METAL_D)
	Pal.text(self, r2.position + Vector2(5, 3), "%d cr" % st.money, 10, Pal.TEXT)
	Pal.text(self, r2.position + Vector2(5, 16), "SUSPECTS %d" % st.pool, 8, Pal.DIM)
	if st.flags.has("prisoner"):
		Pal.text(self, Vector2(0, 22), "PRISONER IN THE CHAIR  (P)", 8, Color(1.0, 0.6, 0.3), HORIZONTAL_ALIGNMENT_CENTER, w)
	var ks: String = load("res://v2/sim/krall.gd").summary(st)
	Pal.text(self, r2.position + Vector2(5, 27), ks, 8, Color(1.0, 0.5, 0.35) if "SEARCH" in ks else Pal.DIM)
	var att: float = st.attention
	var blink := att > 60.0 and fmod(_t, 0.8) < 0.4
	Pal.lamp(self, Vector2(r2.end.x - 12, r2.position.y + 11), 5.0, att > 5.0 and not blink, Pal.MULT if att > 50.0 else Pal.AMBER)
	# Facing.
	if facing_text != "":
		Pal.text(self, Vector2(0, 6), facing_text.to_upper(), 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
		if show_hints:
			Pal.text(self, Vector2(0, 18), "< %s   A / D   %s >" % [left_text, right_text], 8, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, w)
	# Hover tag beside the object.
	if hover_title != "":
		var f := Pal.font()
		var tw := maxf(f.get_string_size(hover_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x,
			f.get_string_size(hover_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 10
		var p := (hover_pos + Vector2(10, -24)).clamp(Vector2(2, 40), size - Vector2(tw + 2, 34))
		var tr := Rect2(p, Vector2(tw, 26))
		draw_rect(tr, Color(0.04, 0.03, 0.04, 0.9))
		draw_rect(tr, Pal.AMBER, false, 1.0)
		draw_line(hover_pos, p + Vector2(0, 13), Color(Pal.AMBER, 0.6))
		Pal.text(self, p + Vector2(5, 2), hover_title, 10, Pal.AMBER)
		Pal.text(self, p + Vector2(5, 14), hover_hint, 8, Pal.TEXT)
		if hover_cost != "":
			var cw := f.get_string_size(hover_cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			Pal.text(self, Vector2(tr.end.x - cw - 4, p.y + 3), hover_cost, 8, Pal.DIM)
		# its status sign (concept 03): what it can do now, plainly
		if not hover_sign.is_empty():
			var rows: Array = hover_sign.slice(0, 6)
			var sw := 0.0
			for row in rows:
				sw = maxf(sw, f.get_string_size(str(row["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + f.get_string_size(str(row["tag"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 30)
			var sr := Rect2(Vector2(p.x, p.y + 30), Vector2(maxf(sw, tw), 8 + rows.size() * 13))
			sr.position = sr.position.clamp(Vector2(2, 40), size - sr.size - Vector2(2, 2))
			draw_rect(sr, Color(0.09, 0.07, 0.05, 0.95))
			draw_rect(sr, Pal.BRASS, false, 1.0)
			for k in rows.size():
				var row: Dictionary = rows[k]
				var y := sr.position.y + 4 + k * 13
				Pal.text(self, Vector2(sr.position.x + 5, y + 1), str(row["text"]), 8, Pal.TEXT if row["ok"] else Pal.DIM)
				var tg := str(row["tag"])
				var tgw := f.get_string_size(tg, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8
				var tgr := Rect2(Vector2(sr.end.x - tgw - 4, y), Vector2(tgw, 11))
				draw_rect(tgr, Pal.BRASS if row["ok"] else Color(0.25, 0.2, 0.15))
				Pal.text(self, tgr.position + Vector2(0, 1), tg, 7, Pal.METAL_D if row["ok"] else Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER, tgw)
	# Bottom hint line.
	if show_hints and hint_line != "":
		Pal.text(self, Vector2(0, size.y - 12), hint_line, 8, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, w)
	_draw_toast(w)


func _draw_toast(w: float) -> void:
	if _toast_t > 0.0:
		var a := clampf(_toast_t / 0.4, 0.0, 1.0)
		var f := Pal.font()
		var tw2 := f.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16
		var tr2 := Rect2(Vector2((w - tw2) * 0.5, 44), Vector2(tw2, 16))
		draw_rect(tr2, Color(0.05, 0.03, 0.04, 0.9 * a))
		draw_rect(tr2, Color(Pal.PHOS, a), false, 1.0)
		Pal.text(self, tr2.position + Vector2(0, 3), _toast, 10, Color(Pal.TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, tw2)
