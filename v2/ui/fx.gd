extends RefCounted
## Juice helpers: floating numbers.

const Pal := preload("res://v2/ui/pal.gd")


static func float_text(parent: Control, pos: Vector2, s: String, col: Color, size := 10, rise := 16.0, dur := 0.75) -> void:
	var l := Label.new()
	l.text = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Pal.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.z_index = 60
	parent.add_child(l)
	var w := Pal.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	l.position = (pos - Vector2(w * 0.5, size * 0.6)).round()
	l.scale = Vector2(1.4, 1.4)
	l.pivot_offset = Vector2(w * 0.5, size * 0.5)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_property(l, "position:y", l.position.y - rise, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	tw.chain().tween_callback(l.queue_free)
