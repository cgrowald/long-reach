extends "res://v2/os/app.gd"
## Image viewer. The "pictures" are drawn placeholders, with the caption from the file.

var _kind := ""
var _caption := ""


func build() -> void:
	var body := Fs.read(state(), arg)
	var parts := body.split("|", true, 1)
	_kind = parts[0].trim_prefix("img:") if parts.size() > 0 else ""
	_caption = parts[1] if parts.size() > 1 else ""
	win.title = "Viewer - " + arg.get_file()
	win.icon = "image"
	win.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.11))
	var r := Rect2(Vector2(8, 6), Vector2(size.x - 16, size.y - 26))
	match _kind:
		"family":
			P.grad_v(self, r, Color(0.55, 0.7, 0.85), Color(0.95, 0.85, 0.6), 10)
			draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.3, r.size.x, r.size.y * 0.3), Color(0.4, 0.55, 0.3))
			var base := Vector2(r.get_center().x - 30, r.end.y - r.size.y * 0.3)
			var hs := [[0, 34, Color(0.6, 0.3, 0.3)], [22, 26, Color(0.3, 0.4, 0.6)], [40, 22, Color(0.8, 0.7, 0.3)], [58, 30, Color(0.4, 0.4, 0.4)]]
			for h in hs:
				var x: float = base.x + float(h[0])
				var hh: float = h[1]
				draw_rect(Rect2(x, base.y - hh, 12, hh), h[2])
				draw_circle(Vector2(x + 6, base.y - hh - 5), 5, Color(0.9, 0.75, 0.6))
		"marshal":
			draw_rect(r, Color(0.35, 0.1, 0.1))
			var c := r.get_center()
			draw_rect(Rect2(c.x - 22, c.y - 6, 44, r.end.y - c.y + 6), Color(0.15, 0.18, 0.15))
			draw_circle(c - Vector2(0, 14), 15, Color(0.85, 0.7, 0.55))
			draw_rect(Rect2(c.x - 15, c.y - 32, 30, 8), Color(0.15, 0.18, 0.15))
			draw_rect(Rect2(c.x - 8, c.y - 6, 16, 3), Color(0.2, 0.15, 0.1))
			draw_rect(r, Color(0.8, 0.65, 0.3), false, 2.0)
		_:
			draw_rect(r, Color(0.3, 0.3, 0.3))
			P.text(self, r.position + Vector2(4, 4), "(can't display this file)", Color.WHITE)
	P.text(self, Vector2(8, size.y - 16), _caption, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16)
