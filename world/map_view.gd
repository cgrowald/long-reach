extends Control
## The campaign map: a pixel-art world (1 pixel = 1 degree, scaled up) with regions tinted by
## enemy strength, the carrier and its reach, sea zones, and plot warnings. Presentation only;
## reads the WorldSim and emits clicks.

signal region_clicked(id: String)
signal zone_clicked(id: String)

const GameData := preload("res://sim/game_data.gd")
const WorldSim := preload("res://sim/world_sim.gd")
const LAND_PATH := "res://data/world_land.json"
const REGION_RADIUS := 15.0      # degrees: land farther than this from any region center stays neutral
const ZONE_PICK := 16.0          # px

const OCEAN := Color(0.035, 0.07, 0.12)
const OCEAN_B := Color(0.042, 0.078, 0.13)
const SHALLOW := Color(0.13, 0.27, 0.36)
const GRID := Color(0.06, 0.1, 0.16)
const LAND_NEUTRAL := Color(0.3, 0.32, 0.26)
const LAND := Color(0.42, 0.5, 0.34)
const ENEMY := Color(0.7, 0.17, 0.12)
const GOLD := Color(1.0, 0.82, 0.3)
const PLOT_RED := Color(1.0, 0.3, 0.25)
const ZONE_BLUE := Color(0.45, 0.7, 1.0)

static var _mask_w: int = 0
static var _mask_h: int = 0
static var _land: PackedByteArray        # 1 = land
static var _region_idx: PackedInt32Array # index into _region_ids, -1 = none
static var _region_ids: Array[String] = []

var world = null
var global_intel: bool = false
var selected_region: String = ""
var selected_zone: String = ""
var planned_region: String = ""
var _tex: ImageTexture
var _view: Dictionary
var _hover: String = ""
var _time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	_view = GameData.load_json(LAND_PATH).get("view", {})
	_build_masks()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ---------------------------------------------------------------- geometry

func _lon_span() -> float:
	return float(_view["lon_max"]) - float(_view["lon_min"])


func _lat_span() -> float:
	return float(_view["lat_max"]) - float(_view["lat_min"])


func to_screen(lonlat: Array) -> Vector2:
	var u: float = (float(lonlat[0]) - float(_view["lon_min"])) / _lon_span()
	var v: float = (float(_view["lat_max"]) - float(lonlat[1])) / _lat_span()
	return Vector2(u * size.x, v * size.y)


func _pixel_at(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / size.x * _mask_w), int(p.y / size.y * _mask_h))


func _build_masks() -> void:
	if _mask_w > 0:
		return
	var land_data: Dictionary = GameData.load_json(LAND_PATH)
	_mask_w = int(_lon_span())
	_mask_h = int(_lat_span())
	var lands: Array = _polys(land_data.get("land", []))
	var waters: Array = _polys(land_data.get("water", []))
	_land.resize(_mask_w * _mask_h)
	_region_idx.resize(_mask_w * _mask_h)
	_region_ids.clear()
	var centers: Array[Vector2] = []
	var regs: Dictionary = WorldSim.regions()
	for id in regs:
		_region_ids.append(id)
		centers.append(Vector2(float(regs[id]["lonlat"][0]), float(regs[id]["lonlat"][1])))
	for y in _mask_h:
		for x in _mask_w:
			var p := Vector2(float(_view["lon_min"]) + x + 0.5, float(_view["lat_max"]) - y - 0.5)
			var is_land: bool = _inside_any(p, lands) and not _inside_any(p, waters)
			var i: int = y * _mask_w + x
			_land[i] = 1 if is_land else 0
			_region_idx[i] = -1
			if is_land:
				var best: float = REGION_RADIUS
				for k in centers.size():
					var d: float = p.distance_to(centers[k])
					if d < best:
						best = d
						_region_idx[i] = k


func _polys(raw: Array) -> Array:
	var out: Array = []
	for poly in raw:
		var pts := PackedVector2Array()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in poly:
			var v := Vector2(float(q[0]), float(q[1]))
			pts.append(v)
			lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
			hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
		out.append({"pts": pts, "lo": lo, "hi": hi})
	return out


func _inside_any(p: Vector2, polys: Array) -> bool:
	for poly in polys:
		if p.x < poly["lo"].x or p.y < poly["lo"].y or p.x > poly["hi"].x or p.y > poly["hi"].y:
			continue
		if Geometry2D.is_point_in_polygon(p, poly["pts"]):
			return true
	return false


# ---------------------------------------------------------------- texture

## Repaint the map from the current world state. Call after anything changes.
func refresh() -> void:
	if world == null:
		return
	var img := Image.create(_mask_w, _mask_h, false, Image.FORMAT_RGB8)
	var covered: Array = world.covered()
	var region_colors: Array[Color] = []
	for id in _region_ids:
		var s: int = int(world.strength.get(id, 0))
		var c: Color = LAND.lerp(ENEMY, clampf(s / 5.0, 0.0, 1.0) * 0.9)
		if not covered.has(id):
			c = c.darkened(0.35)
		if id == selected_region:
			c = c.lightened(0.25)
		region_colors.append(c)
	for y in _mask_h:
		for x in _mask_w:
			var i: int = y * _mask_w + x
			var c: Color
			if _land[i] == 1:
				var k: int = _region_idx[i]
				c = LAND_NEUTRAL if k < 0 else region_colors[k]
				if k >= 0 and _is_border(x, y, k):
					c = c.darkened(0.45)
			else:
				c = OCEAN if (x + y) % 2 == 0 else OCEAN_B
				if x % 15 == 10 or y % 15 == 4:
					c = GRID
				if _near_land(x, y):
					c = SHALLOW
			img.set_pixel(x, y, c)
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	queue_redraw()


func _is_border(x: int, y: int, k: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= _mask_w or ny >= _mask_h:
			continue
		var j: int = ny * _mask_w + nx
		if _land[j] == 1 and _region_idx[j] != k:
			return true
	return false


func _near_land(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= _mask_w or ny >= _mask_h:
			continue
		if _land[ny * _mask_w + nx] == 1:
			return true
	return false


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if _tex == null or world == null:
		return
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	var font: Font = get_theme_default_font()
	var zones: Dictionary = WorldSim.zones()
	var regs: Dictionary = WorldSim.regions()
	var carrier: Vector2 = to_screen(zones[world.carrier_zone]["lonlat"])
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)

	# Carrier reach: dotted lines to every region it covers.
	for r in world.covered():
		_dotted(carrier, to_screen(regs[r]["lonlat"]), Color(GOLD, 0.45), 6.0)

	# Sea zones (where the carrier could go next is highlighted).
	for z in zones:
		var p: Vector2 = to_screen(zones[z]["lonlat"])
		if z == world.carrier_zone:
			continue
		var movable: bool = world.can_move_to(z)
		var col: Color = Color(ZONE_BLUE, 0.9 if movable else 0.35)
		if movable:
			_dotted(carrier, p, Color(ZONE_BLUE, 0.35 + 0.3 * pulse), 4.0)
		draw_arc(p, 7.0, 0.0, TAU, 16, col, 2.0)
		if z == selected_zone:
			draw_arc(p, 11.0, 0.0, TAU, 16, Color.WHITE, 2.0)
		_text(font, p + Vector2(0, 20), str(zones[z]["name"]), 11, col)

	# Regions: strength pips, plot warnings, names.
	for r in regs:
		var p: Vector2 = to_screen(regs[r]["lonlat"])
		var s: int = int(world.strength.get(r, 0))
		var in_range: bool = world.in_range(r)
		if s > 0:
			var w: float = 5 * 6.0 + 2.0
			draw_rect(Rect2(p + Vector2(-w * 0.5, -4), Vector2(w, 9)), Color(0, 0, 0, 0.75))
			for k in 5:
				var pip := Rect2(p + Vector2(-w * 0.5 + 2.0 + k * 6.0, -2), Vector2(4, 5))
				draw_rect(pip, PLOT_RED if k < s else Color(0.3, 0.3, 0.3))
		else:
			draw_circle(p, 3.0, Color(0.6, 0.75, 0.6, 0.8))
		var plot: Dictionary = world.plot_in(r)
		if not plot.is_empty() and world.has_intel(r, global_intel):
			var bp := p + Vector2(24, -8)
			draw_rect(Rect2(bp, Vector2(30, 16)), Color(PLOT_RED, 0.6 + 0.4 * pulse))
			_text(font, bp + Vector2(15, 13), "!%dw" % int(plot["weeks"]), 12, Color.WHITE)
		if r == planned_region:
			draw_arc(p, 16.0 + 2.0 * pulse, 0.0, TAU, 24, GOLD, 2.5)
		if r == selected_region:
			draw_arc(p, 22.0, 0.0, TAU, 24, Color.WHITE, 1.5)
		if in_range or r == selected_region or r == _hover:
			_text(font, p + Vector2(0, -10), str(regs[r]["name"]), 12, Color.WHITE if in_range else Color(0.75, 0.75, 0.75))

	# The carrier.
	var hull := PackedVector2Array([carrier + Vector2(-14, -4), carrier + Vector2(12, -4), carrier + Vector2(16, 0), carrier + Vector2(12, 4), carrier + Vector2(-14, 4)])
	draw_colored_polygon(hull, GOLD)
	draw_rect(Rect2(carrier + Vector2(2, -9), Vector2(5, 5)), GOLD)
	draw_arc(carrier, 20.0 + 3.0 * pulse, 0.0, TAU, 24, Color(GOLD, 0.6), 1.5)
	_text(font, carrier + Vector2(0, 26), "CARRIER · " + str(zones[world.carrier_zone]["name"]), 12, GOLD)


func _text(font: Font, center_bottom: Vector2, text: String, fs: int, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(center_bottom.x - w * 0.5, center_bottom.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _dotted(a: Vector2, b: Vector2, col: Color, dash: float) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	var dir: Vector2 = (b - a) / length
	var t: float = 0.0
	while t < length:
		draw_line(a + dir * t, a + dir * minf(t + dash, length), col, 2.0)
		t += dash * 2.0


# ---------------------------------------------------------------- input

func region_at(pos: Vector2) -> String:
	# Markers first (they can sit over water), then the land pixel's region.
	var regs: Dictionary = WorldSim.regions()
	for r in regs:
		if to_screen(regs[r]["lonlat"]).distance_to(pos) < 18.0:
			return r
	var px: Vector2i = _pixel_at(pos)
	if px.x < 0 or px.y < 0 or px.x >= _mask_w or px.y >= _mask_h:
		return ""
	var k: int = _region_idx[px.y * _mask_w + px.x]
	return _region_ids[k] if k >= 0 else ""


func zone_at(pos: Vector2) -> String:
	var zones: Dictionary = WorldSim.zones()
	for z in zones:
		if to_screen(zones[z]["lonlat"]).distance_to(pos) < ZONE_PICK:
			return z
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h: String = region_at((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			tooltip_text = WorldSim.region_name(h) if h != "" else ""
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var z: String = zone_at(mb.position)
			if z != "":
				zone_clicked.emit(z)
				return
			var r: String = region_at(mb.position)
			if r != "":
				region_clicked.emit(r)
