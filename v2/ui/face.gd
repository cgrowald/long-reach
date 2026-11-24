extends RefCounted
## Portraits (user 2026-11-23: the GPT face sheets become everyone's faces; docs/refs/catalog/).
## Which tile a person gets: v2/sim/portraits.gd (from their name, so it's the same face everywhere).
## Drawn straight from the sheet (art/faces/*.webp, 5 x 5 tiles), cropped a little inside the grid lines.
## The old procedural pixel faces are gone (they were the placeholder until GPT drew real ones).

const Portraits := preload("res://v2/sim/portraits.gd")

const INSET := 0.018           # of a sheet's width: trims the dark grid lines between tiles
const BANDAGE := Color(0.9, 0.86, 0.76)

static var _tex := {}


static func _sheet(sid: String) -> Texture2D:
	if not _tex.has(sid):
		var f: String = Portraits.data().get("sheets", {}).get(sid, {}).get("file", "")
		_tex[sid] = load(f) if f != "" else null
	return _tex[sid]


## The tile's rect on its sheet (pixels).
static func region(seed_name: String) -> Dictionary:
	var p := Portraits.pick(seed_name)
	var t := _sheet(str(p["sheet"]))
	if t == null:
		return {}
	var cell := Vector2(t.get_width(), t.get_height()) / 5.0
	var i := int(p["i"])
	var ins := t.get_width() * INSET
	return {"tex": t, "rect": Rect2(Vector2(i % 5, i / 5) * cell + Vector2(ins, ins), cell - Vector2(ins, ins) * 2.0)}


## Draw a portrait into r. head: kept for callers (the sheets already show hair; helmets come with the
## 3D rebuild). dead: dark and greyed. hurt: a bandage on their own face.
static func draw(ci: CanvasItem, r: Rect2, seed_name: String, _head := "", dead := false, hurt := false) -> void:
	var reg := region(seed_name)
	if reg.is_empty():
		ci.draw_rect(r, Color(0.2, 0.22, 0.26))
		return
	ci.draw_texture_rect_region(reg["tex"], r, reg["rect"], Color(0.42, 0.42, 0.45) if dead else Color.WHITE)
	if dead:
		ci.draw_rect(r, Color(0.05, 0.05, 0.06, 0.25))
		return
	if hurt:
		# a strip of tape across the cheek, like the bruised sheet
		var c := r.position + Vector2(r.size.x * 0.62, r.size.y * 0.5)
		var w := r.size.x * 0.16
		var pts := PackedVector2Array([c + Vector2(-w, -w * 0.15), c + Vector2(w * 0.7, -w * 0.55), c + Vector2(w, w * 0.1), c + Vector2(-w * 0.7, w * 0.5)])
		ci.draw_colored_polygon(pts, BANDAGE)
		ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.6, 0.55, 0.45, 0.8), 1.0)


## The headwear id for a fighter, from their kit (head slot id). Kept for callers.
static func head_of(kit_head: String) -> String:
	var h := kit_head.to_lower()
	if "helmet" in h:
		return "helmet"
	if "beanie" in h:
		return "beanie"
	if "cap" in h:
		return "cap"
	return ""
