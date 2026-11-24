extends Node3D
## The boards in the garage (docs/CONNECTED_LOOP.md section 7, B3; concepts docs/refs/Garage/05 and 03):
## - the TONIGHT board: the cards from v2/sim/tonight.gd board(), pinned on the real cork board by the roller door.
##   Aim the centre dot at a card and press E: the view turns to that station.
## - a status sign beside each station (Tonight.signs): a dark plaque with brass tags, READY or what's missing.
## Each face is drawn by a Control in its own SubViewport and shown on a quad; redrawn only on refresh().
## Places come from data/v2/stations.json: a station's "sign" {at, face} (Blender coords; face = the direction the
## sign looks, in Blender X/Y; at = the sign's top centre) and the board's "board_face" {at, face, size}.

const Pal := preload("res://v2/ui/pal.gd")
const Tonight := preload("res://v2/sim/tonight.gd")

const BOARD_PX := Vector2i(680, 500)
const SIGN_W_PX := 440
const SIGN_W_M := 0.7

var board_cards: Array = []
var _board_face: BoardFace
var _board_vp: SubViewport
var _board_quad: MeshInstance3D
var _board_size := Vector2(1.13, 0.83)
var _signs := {}       # station id -> {vp, face, quad, mat}


static func _b2g(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[2]), -float(a[1]))


func setup(stations: Dictionary) -> void:
	for id in stations:
		var s: Dictionary = stations[id]
		if s.has("board_face"):
			_make_board(s["board_face"])
		if s.has("sign"):
			_make_sign(id, s)


func _quad(at: Dictionary, size: Vector2, tex: Texture2D) -> Array:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	q.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# unshaded: lamp light blew the colours out to grey; readable first (user: nobody should feel lost)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.82, 0.78, 0.72)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	var f: Array = at["face"]
	var n := Vector3(float(f[0]), 0.0, -float(f[1])).normalized()
	q.position = _b2g(at["at"])
	q.rotation.y = atan2(n.x, n.z)
	return [q, m]


func _viewport(px: Vector2i, face: Control) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.gui_disable_input = true
	add_child(vp)
	face.size = Vector2(px)
	vp.add_child(face)
	return vp


func _make_board(at: Dictionary) -> void:
	_board_face = BoardFace.new()
	_board_vp = _viewport(BOARD_PX, _board_face)
	var sz: Array = at.get("size", [1.13, 0.83])
	_board_size = Vector2(float(sz[0]), float(sz[1]))
	_board_quad = _quad(at, _board_size, _board_vp.get_texture())[0]


func _make_sign(id: String, s: Dictionary) -> void:
	var face := SignFace.new()
	face.title = str(s.get("name", id)).to_upper()
	var vp := _viewport(Vector2i(SIGN_W_PX, 200), face)
	var parts := _quad(s["sign"], Vector2(SIGN_W_M, SIGN_W_M * 200.0 / SIGN_W_PX), vp.get_texture())
	(parts[0] as Node3D).visible = false     # until refresh() knows its rows
	_signs[id] = {"vp": vp, "face": face, "quad": parts[0], "top": _b2g(s["sign"]["at"])}


## Redraw everything from the game state.
func refresh(state) -> void:
	if state == null:
		return
	board_cards = Tonight.board(state)
	if _board_face:
		_board_face.cards = board_cards
		_board_face.bureau = Tonight.bureau(state)
		_board_face.queue_redraw()
		_board_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for id in _signs:
		var S: Dictionary = _signs[id]
		var rows: Array = Tonight.signs(state, id).slice(0, 4)
		var face: SignFace = S["face"]
		var q: MeshInstance3D = S["quad"]
		q.visible = not rows.is_empty()
		if rows.is_empty():
			continue
		face.rows = rows
		var h := face.height()
		var vp: SubViewport = S["vp"]
		vp.size = Vector2i(SIGN_W_PX, h)
		face.size = Vector2(SIGN_W_PX, h)
		var hm := SIGN_W_M * float(h) / SIGN_W_PX
		(q.mesh as QuadMesh).size = Vector2(SIGN_W_M, hm)
		q.position = (S["top"] as Vector3) - Vector3(0, hm * 0.5, 0)      # hangs from its top edge
		face.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Which TONIGHT card (index) is at a world point on the board, or -1.
func card_at(p: Vector3) -> int:
	if _board_quad == null:
		return -1
	var l := _board_quad.to_local(p)
	var uv := Vector2(l.x / _board_size.x + 0.5, 0.5 - l.y / _board_size.y)
	return _board_face.card_at(uv * Vector2(BOARD_PX))


func set_board_hover(i: int) -> void:
	if _board_face == null or _board_face.hover == i:
		return
	_board_face.hover = i
	_board_face.queue_redraw()
	_board_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func sign_visible(id: String) -> bool:
	return _signs.has(id) and (_signs[id]["quad"] as Node3D).visible


# ------------------------------------------------------------------ the faces

## The TONIGHT board (concept 05): a torn paper title, pinned cards, the heading in bold, the line in pencil.
class BoardFace extends Control:
	const CORK := Color(0.55, 0.36, 0.21)
	const CORK_D := Color(0.4, 0.26, 0.15)
	const PAPER := Color(0.93, 0.88, 0.77)
	const INK := Color(0.15, 0.12, 0.1)
	const PENCIL := Color(0.34, 0.29, 0.25)
	const GOOD := Color(0.18, 0.36, 0.16)

	var cards: Array = []
	var hover := -1
	var bureau: Dictionary = {}      # {clock, note}: the Bureau corner (D)
	var bureau_rect := Rect2()
	var _rects: Array = []

	func card_at(p: Vector2) -> int:
		if bureau_rect.has_point(p) and not bureau.is_empty():
			return -2          # the Bureau memo
		for i in _rects.size():
			if (_rects[i] as Rect2).grow(4).has_point(p):
				return i
		return -1

	func _draw() -> void:
		_rects.clear()
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, CORK)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 900:
			draw_rect(Rect2(Vector2(rng.randf() * size.x, rng.randf() * size.y), Vector2(2, 2)), CORK_D)
		# the title strip
		var tr := Rect2(Vector2(40, 18), Vector2(270, 72))
		draw_rect(Rect2(tr.position + Vector2(4, 5), tr.size), Color(0, 0, 0, 0.3))
		draw_rect(tr, PAPER)
		draw_string(Pal.bold(), Vector2(tr.position.x, tr.position.y + 56), "TONIGHT", HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 52, INK)
		_draw_bureau(Rect2(Vector2(330, 12), Vector2(size.x - 344, 88)))
		var n := maxi(cards.size(), 1)
		var top := 110.0
		var gap := 12.0
		var ch := minf(96.0, (size.y - top - 16.0 - gap * (n - 1)) / n)
		for i in cards.size():
			var c: Dictionary = cards[i]
			var cr := Rect2(Vector2(54, top + i * (ch + gap)), Vector2(size.x - 108, ch))
			var hov := hover == i
			var tilt := (float((i * 37) % 7) - 3.0) * 0.004
			draw_set_transform(cr.get_center(), tilt, Vector2.ONE * (1.03 if hov else 1.0))
			var lr := Rect2(-cr.size * 0.5, cr.size)
			draw_rect(Rect2(lr.position + Vector2(4, 6), lr.size), Color(0, 0, 0, 0.35))
			draw_rect(lr, PAPER.lightened(0.08) if hov else PAPER)
			if hov:
				draw_rect(lr.grow(3), Pal.AMBER, false, 5.0)
			draw_circle(lr.position + Vector2(20, 16), 7, Pal.BRASS)
			draw_circle(lr.position + Vector2(lr.size.x - 20, 16), 7, Pal.BRASS)
			var title_sz := int(clampf(ch * 0.36, 18, 36))
			var line_sz := int(clampf(ch * 0.28, 15, 28))
			draw_string(Pal.bold(), lr.position + Vector2(40, 12 + title_sz), str(c["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, title_sz, INK)
			var col: Color = GOOD if c["ok"] else PENCIL
			draw_string(Pal.font(), lr.position + Vector2(40, 20 + title_sz + line_sz), str(c["line"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 56, line_sz, col)
			if hov:
				draw_string(Pal.bold(), lr.position + Vector2(lr.size.x - 40, 12 + title_sz), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, title_sz, Pal.BRASS)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_rects.append(cr)


	## The Bureau corner (D): a pinned navy memo with Krall's clock and the newest note about you.
	func _draw_bureau(r: Rect2) -> void:
		bureau_rect = r
		if bureau.is_empty():
			return
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.3))
		draw_rect(r, Color(0.84, 0.85, 0.82))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 22)), Color(0.16, 0.2, 0.3))
		draw_string(Pal.bold(), r.position + Vector2(8, 17), "BUREAU", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.85))
		draw_string(Pal.bold(), r.position + Vector2(90, 17), str(bureau.get("clock", "")).replace("KRALL: ", "KRALL  "), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 96, 15, Color(1.0, 0.55, 0.45))
		var note := str(bureau.get("note", ""))
		if note == "":
			note = "Nothing on you. Yet."
		draw_multiline_string(Pal.font(), r.position + Vector2(8, 40), note, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 14, 4, INK)
		draw_circle(r.position + Vector2(r.size.x * 0.5, 4), 6, Color(0.7, 0.15, 0.12))


## A station's status sign (concept 03): the station's name, then one row per thing with a tag on the right.
class SignFace extends Control:
	const PLATE := Color(0.1, 0.075, 0.055)
	const RULE := Color(0.5, 0.36, 0.18)
	const TITLE_H := 64
	const ROW_H := 50

	var title := ""
	var rows: Array = []

	func height() -> int:
		return TITLE_H + rows.size() * ROW_H + 14

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, PLATE)
		draw_rect(r.grow(-4), Pal.BRASS, false, 3.0)
		for c in [Vector2(14, 14), Vector2(size.x - 14, 14), Vector2(14, size.y - 14), Vector2(size.x - 14, size.y - 14)]:
			draw_circle(c, 4, Color(0.55, 0.42, 0.25))
		draw_string(Pal.bold(), Vector2(24, 46), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 32, Pal.AMBER)
		draw_line(Vector2(20, TITLE_H - 4), Vector2(size.x - 20, TITLE_H - 4), RULE, 2.0)
		var f := Pal.bold()
		for k in rows.size():
			var row: Dictionary = rows[k]
			var y := float(TITLE_H + k * ROW_H)
			var tg := str(row["tag"])
			var tsz := 20
			var tw := f.get_string_size(tg, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x + 18
			var tgr := Rect2(Vector2(size.x - 24 - tw, y + 10), Vector2(tw, 30))
			var ok: bool = row["ok"]
			draw_string(Pal.font(), Vector2(24, y + 34), str(row["text"]), HORIZONTAL_ALIGNMENT_LEFT, tgr.position.x - 34, 22, Pal.TEXT if ok else Pal.DIM)
			draw_rect(tgr, Pal.AMBER if ok else Color(0.27, 0.21, 0.15))
			draw_string(f, Vector2(tgr.position.x, y + 32), tg, HORIZONTAL_ALIGNMENT_CENTER, tw, tsz, Pal.METAL_D if ok else Pal.TEXT)
			if k < rows.size() - 1:
				draw_line(Vector2(20, y + ROW_H), Vector2(size.x - 20, y + ROW_H), Color(RULE, 0.5), 1.0)
