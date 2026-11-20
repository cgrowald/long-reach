extends Control
## The campaign map, drawn as crisp vectors: glowing coastlines, regions shaded by enemy
## strength, the carrier and its reach, sea lanes, plot warnings, cities. Scroll to zoom,
## drag to pan, click to select. Presentation only: reads the WorldSim, emits clicks.

signal region_clicked(id: String)
signal zone_clicked(id: String)

const MapGeo := preload("res://world/map_geo.gd")
const WorldSim := preload("res://sim/world_sim.gd")

const ZOOM_MIN := 1.0
const ZOOM_MAX := 5.0
const DRAG_START := 6.0
const ZONE_PICK := 30.0
const MARKER_PICK := 16.0

const LAND_NEUTRAL := Color(0.115, 0.14, 0.16)
const WATER_FILL := Color(0.03, 0.075, 0.12)
const COAST := Color(0.45, 0.72, 0.86, 0.8)
const COAST_GLOW := Color(0.3, 0.62, 0.9, 0.13)
const GRATICULE := Color(0.35, 0.55, 0.75, 0.07)
const REGION_CALM := Color(0.17, 0.24, 0.25)
const REGION_LOW := Color(0.36, 0.27, 0.19)
const REGION_HIGH := Color(0.64, 0.14, 0.11)
const BORDER := Color(0.04, 0.06, 0.07, 0.95)
const GOLD := Color(1.0, 0.8, 0.32)
const RED := Color(1.0, 0.3, 0.24)
const SEA_TEXT := Color(0.45, 0.65, 0.82, 0.65)
const ZONE_BLUE := Color(0.45, 0.75, 1.0)

const OCEAN_SHADER := """
shader_type canvas_item;
uniform vec4 deep : source_color = vec4(0.012, 0.035, 0.065, 1.0);
uniform vec4 light : source_color = vec4(0.045, 0.1, 0.155, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float d = distance(UV * vec2(1.6, 1.0), vec2(0.8, 0.48));
	vec3 c = mix(light.rgb, deep.rgb, smoothstep(0.1, 0.95, d));
	c += (hash(FRAGCOORD.xy) - 0.5) / 255.0 * 2.0;
	COLOR = vec4(c, 1.0);
}
"""

var world = null
var global_intel: bool = false
var selected_region: String = ""
var selected_zone: String = ""
var planned_region: String = ""
var planned_city: String = ""

var _zoom: float = 1.0
var _k: float = 1.0                 # screen px per map unit
var _origin: Vector2 = Vector2.ZERO # screen position of map unit (0, 0)
var _layer: Node2D
var _fx: Control
var _hover: String = ""
var _hover_zone: String = ""
var _time: float = 0.0
var _press_pos: Vector2
var _pressing: int = 0              # mouse button held (0 = none)
var _dragging: bool = false
var _framed: bool = false


func _ready() -> void:
	MapGeo.build()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ocean := ColorRect.new()
	ocean.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = OCEAN_SHADER
	mat.shader = sh
	ocean.material = mat
	add_child(ocean)
	_layer = Node2D.new()
	_layer.draw.connect(_draw_layer)
	add_child(_layer)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	resized.connect(_on_resized)


func _process(delta: float) -> void:
	_time += delta
	_fx.queue_redraw()


## Repaint after the world or selection changes.
func refresh() -> void:
	_layer.queue_redraw()


# ---------------------------------------------------------------- view transform

func _base_k() -> float:
	var vr: Rect2 = MapGeo.view_rect
	return maxf(size.x / vr.size.x, size.y / vr.size.y)


func _on_resized() -> void:
	if not _framed and size.x > 0.0:
		_framed = true
		_zoom = 1.0
		_k = _base_k()
		_origin = size * 0.5 - MapGeo.view_rect.get_center() * _k
	_apply_view()


func _apply_view() -> void:
	# Keep the framed area covering the whole control.
	var vr: Rect2 = MapGeo.view_rect
	var lo: Vector2 = _origin + vr.position * _k
	var hi: Vector2 = _origin + vr.end * _k
	if lo.x > 0.0:
		_origin.x -= lo.x
	elif hi.x < size.x:
		_origin.x += size.x - hi.x
	if lo.y > 0.0:
		_origin.y -= lo.y
	elif hi.y < size.y:
		_origin.y += size.y - hi.y
	_layer.transform = Transform2D(0.0, Vector2(_k, _k), 0.0, _origin)
	_layer.queue_redraw()


func to_screen(map_p: Vector2) -> Vector2:
	return _origin + map_p * _k


func to_map(screen_p: Vector2) -> Vector2:
	return (screen_p - _origin) / _k


func lonlat_to_screen(lonlat: Array) -> Vector2:
	return to_screen(MapGeo.project_arr(lonlat))


func _zoom_at(screen_p: Vector2, factor: float) -> void:
	var before: Vector2 = to_map(screen_p)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_k = _base_k() * _zoom
	_origin = screen_p - before * _k
	_apply_view()


## Bring a region into view if it is off screen.
func focus_region(id: String) -> void:
	var c: Vector2 = lonlat_to_screen(WorldSim.region(id).get("lonlat", [0, 0]))
	if c.x < 60.0 or c.y < 60.0 or c.x > size.x - 60.0 or c.y > size.y - 60.0:
		_origin += size * 0.5 - c
		_apply_view()


# ---------------------------------------------------------------- static layer (map units)

func _px(w: float) -> float:
	return w / _k


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c: PackedVector2Array = p.duplicate()
	c.append(p[0])
	return c


func _region_color(id: String) -> Color:
	var s: int = int(world.strength.get(id, 0))
	var c: Color = REGION_CALM if s == 0 else REGION_LOW.lerp(REGION_HIGH, (s - 1) / 4.0)
	if not world.in_range(id):
		c = c.lerp(LAND_NEUTRAL, 0.45)
	if id == selected_region:
		c = c.lightened(0.22)
	elif id == _hover:
		c = c.lightened(0.1)
	return c


func _draw_layer() -> void:
	if world == null:
		return
	var L := _layer
	# Graticule every 15 degrees.
	var vr: Rect2 = MapGeo.view_rect
	for lon in range(-180, 181, 15):
		L.draw_line(Vector2(lon, vr.position.y - 20), Vector2(lon, vr.end.y + 20), GRATICULE, _px(1.0))
	for lat in range(-75, 76, 15):
		var y: float = MapGeo.project(Vector2(0, lat)).y
		L.draw_line(Vector2(-200, y), Vector2(200, y), GRATICULE, _px(1.0))
	var eq: float = MapGeo.project(Vector2(0, 0)).y
	L.draw_line(Vector2(-200, eq), Vector2(200, eq), Color(GRATICULE, 0.14), _px(1.0))

	# Land, coast glow underneath.
	for p in MapGeo.land:
		L.draw_polyline(_closed(p), COAST_GLOW, _px(7.0), true)
	for p in MapGeo.land:
		L.draw_colored_polygon(p, LAND_NEUTRAL)

	# Regions.
	for id in MapGeo.regions:
		var col: Color = _region_color(id)
		for p in MapGeo.regions[id]:
			L.draw_colored_polygon(p, col)
	for id in MapGeo.regions:
		for p in MapGeo.regions[id]:
			L.draw_polyline(_closed(p), BORDER, _px(1.4), true)
	# Carrier reach: gold outline on every region it covers.
	for id in world.covered():
		for p in MapGeo.regions.get(id, []):
			L.draw_polyline(_closed(p), Color(GOLD, 0.55), _px(1.6), true)
	if selected_region != "":
		for p in MapGeo.regions.get(selected_region, []):
			L.draw_polyline(_closed(p), Color(1, 1, 1, 0.95), _px(2.4), true)

	# Coastline on top, then inland seas.
	for p in MapGeo.land:
		L.draw_polyline(_closed(p), COAST, _px(1.1), true)
	for p in MapGeo.water:
		L.draw_colored_polygon(p, WATER_FILL)
		L.draw_polyline(_closed(p), COAST, _px(1.1), true)


# ---------------------------------------------------------------- dynamic overlay (screen space)

func _draw_fx() -> void:
	if world == null:
		return
	var F := _fx
	var font: Font = get_theme_default_font()
	var zones: Dictionary = WorldSim.zones()
	var regs: Dictionary = WorldSim.regions()
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.5)
	var carrier: Vector2 = lonlat_to_screen(zones[world.carrier_zone]["lonlat"])

	# Sea zone names, written on the water like a chart.
	for z in zones:
		if z == world.carrier_zone:
			continue
		var p: Vector2 = lonlat_to_screen(zones[z]["lonlat"])
		var movable: bool = world.can_move_to(z)
		var col: Color = SEA_TEXT
		var label: String = str(zones[z]["name"]).to_upper()
		var half: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5 + label.length() + 10.0
		if movable:
			col = Color(ZONE_BLUE, 0.8 + 0.2 * pulse)
			_flow_arc(F, carrier, p, Color(ZONE_BLUE, 0.55), 0.18, 1.6)
			var box := Rect2(p + Vector2(-half, -12), Vector2(half * 2.0, 34))
			F.draw_rect(box, Color(0.04, 0.12, 0.2, 0.55 + 0.2 * pulse))
			F.draw_rect(box, Color(ZONE_BLUE, 0.5 + 0.4 * pulse), false, 1.0)
		if z == selected_zone or z == _hover_zone:
			F.draw_rect(Rect2(p + Vector2(-half - 3, -15), Vector2(half * 2.0 + 6, 40)), Color.WHITE, false, 1.5)
		_spaced(F, font, p + Vector2(0, 4), label, 12, col, 2.0)
		if movable:
			_spaced(F, font, p + Vector2(0, 18), "SAIL HERE  >", 10, Color(ZONE_BLUE, 0.95), 1.5)

	# Carrier reach: flowing arcs to each covered region.
	for r in world.covered():
		_flow_arc(F, carrier, lonlat_to_screen(regs[r]["lonlat"]), Color(GOLD, 0.6), 0.22, 1.4)

	# Cities (when zoomed in, or the planned target).
	var show_cities: bool = _zoom >= 1.9
	for r in regs:
		for c in regs[r].get("cities", []):
			if not MapGeo.cities.has(c):
				continue
			var is_target: bool = r == planned_region and c == planned_city
			if not show_cities and not is_target:
				continue
			var cp: Vector2 = to_screen(MapGeo.cities[c])
			if is_target:
				_reticle(F, cp, 9.0, GOLD, _time)
			else:
				F.draw_circle(cp, 2.5, Color(0.9, 0.93, 0.95, 0.85))
			if show_cities:
				_text(F, font, cp + Vector2(6, 4), c, 11, Color(0.85, 0.88, 0.9, 0.9), false)

	# Region badges.
	for r in regs:
		var p: Vector2 = lonlat_to_screen(regs[r]["lonlat"])
		var s: int = int(world.strength.get(r, 0))
		var in_range: bool = world.in_range(r)
		_badge(F, font, p, s, in_range)
		var plot: Dictionary = world.plot_in(r)
		if not plot.is_empty() and world.has_intel(r, global_intel):
			F.draw_arc(p, 17.0 + 7.0 * pulse, 0.0, TAU, 40, Color(RED, 0.9 - 0.6 * pulse), 2.0, true)
			var tag: String = "ATTACK  %d WK" % int(plot["weeks"])
			var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
			var tp: Vector2 = p + Vector2(18, -26)
			F.draw_rect(Rect2(tp, Vector2(tw, 17)), Color(0.55, 0.06, 0.05, 0.92))
			F.draw_rect(Rect2(tp, Vector2(tw, 17)), Color(RED, 0.9), false, 1.0)
			F.draw_string(font, tp + Vector2(6, 13), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if r == planned_region:
			_reticle(F, p, 22.0, GOLD, _time * 0.6)
		var show_name: bool = in_range or r == selected_region or r == _hover or _zoom >= 1.5
		if show_name:
			var ncol: Color = Color(0.95, 0.96, 0.97) if in_range else Color(0.7, 0.74, 0.78, 0.85)
			if r == selected_region:
				ncol = Color.WHITE
			_spaced(F, font, p + Vector2(0, -19), str(regs[r]["name"]).to_upper(), 12, ncol, 1.2)

	_draw_carrier(F, font, carrier, pulse)

	F.draw_string(font, Vector2(12, size.y - 12), "SCROLL  zoom      DRAG  pan      CLICK  select", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.7, 0.8, 0.55))


func _badge(F: Control, font: Font, p: Vector2, s: int, in_range: bool) -> void:
	var a: float = 1.0 if in_range else 0.6
	if s <= 0:
		F.draw_circle(p, 4.0, Color(0.05, 0.07, 0.08, 0.8 * a))
		F.draw_arc(p, 4.0, 0.0, TAU, 16, Color(0.5, 0.85, 0.7, 0.8 * a), 1.2, true)
		return
	F.draw_circle(p, 12.0, Color(0.03, 0.04, 0.05, 0.9 * a))
	var seg: float = TAU / 5.0
	for k in 5:
		var a0: float = -PI * 0.5 + k * seg + 0.09
		var a1: float = -PI * 0.5 + (k + 1) * seg - 0.09
		var col: Color = Color(RED, a) if k < s else Color(0.35, 0.38, 0.4, 0.6 * a)
		F.draw_arc(p, 11.0, a0, a1, 8, col, 3.0, true)
	var t: String = str(s)
	var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	F.draw_string(font, p + Vector2(-w * 0.5, 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))


func _draw_carrier(F: Control, font: Font, c: Vector2, pulse: float) -> void:
	for i in 6:
		var x: float = -22.0 - i * 7.0
		var wake: Color = Color(0.8, 0.9, 1.0, 0.35 - i * 0.05)
		F.draw_line(c + Vector2(x, -3 - i), c + Vector2(x - 6, -4 - i), wake, 1.0, true)
		F.draw_line(c + Vector2(x, 3 + i), c + Vector2(x - 6, 4 + i), wake, 1.0, true)
	F.draw_circle(c, 26.0, Color(GOLD, 0.06 + 0.05 * pulse))
	F.draw_arc(c, 24.0 + 3.0 * pulse, 0.0, TAU, 40, Color(GOLD, 0.45), 1.2, true)
	# Top-down hull with angled flight deck and island.
	var hull := PackedVector2Array([
		c + Vector2(-20, -4), c + Vector2(10, -6), c + Vector2(20, -2), c + Vector2(22, 0),
		c + Vector2(20, 2), c + Vector2(10, 5), c + Vector2(-20, 5)])
	F.draw_colored_polygon(hull, Color(0.62, 0.66, 0.7))
	F.draw_polyline(_closed(hull), GOLD, 1.3, true)
	F.draw_line(c + Vector2(-16, 3), c + Vector2(4, -5), Color(1, 1, 1, 0.7), 1.0, true)
	F.draw_line(c + Vector2(-2, 1), c + Vector2(18, 0), Color(1, 1, 1, 0.5), 1.0, true)
	F.draw_rect(Rect2(c + Vector2(4, 2), Vector2(5, 3)), Color(0.25, 0.27, 0.3))
	_spaced(F, font, c + Vector2(0, 38), "CARRIER GROUP", 11, GOLD, 2.0)


## Gold crosshair that slowly turns.
func _reticle(F: Control, p: Vector2, r: float, col: Color, t: float) -> void:
	F.draw_arc(p, r, 0.0, TAU, 40, Color(col, 0.9), 1.5, true)
	for k in 4:
		var a: float = t + k * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		F.draw_line(p + d * (r - 4.0), p + d * (r + 6.0), col, 2.0, true)


## A curved dashed line whose dashes flow from a to b.
func _flow_arc(F: Control, a: Vector2, b: Vector2, col: Color, bend: float, width: float) -> void:
	var mid: Vector2 = (a + b) * 0.5
	var n: Vector2 = (b - a).orthogonal().normalized()
	if n.y > 0.0:
		n = -n
	var ctrl: Vector2 = mid + n * a.distance_to(b) * bend
	var steps: int = 40
	var phase: float = fmod(_time * 0.8, 1.0)
	var prev: Vector2 = a
	for i in range(1, steps + 1):
		var t: float = float(i) / steps
		var q: Vector2 = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		if fmod(t * 10.0 - phase + 1.0, 1.0) < 0.55:
			F.draw_line(prev, q, col, width, true)
		prev = q


func _text(F: Control, font: Font, pos: Vector2, text: String, fs: int, col: Color, centered: bool = true) -> void:
	var p: Vector2 = pos
	if centered:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	F.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	F.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Letter-spaced caps, centered on pos.x (chart-style labels).
func _spaced(F: Control, font: Font, pos: Vector2, text: String, fs: int, col: Color, spacing: float) -> void:
	var widths: Array[float] = []
	var total: float = 0.0
	for ch in text:
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w + spacing
	total -= spacing
	var x0: float = pos.x - total * 0.5
	var x: float = x0
	for i in text.length():
		F.draw_string_outline(font, Vector2(x, pos.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
		x += widths[i] + spacing
	x = x0
	for i in text.length():
		F.draw_string(font, Vector2(x, pos.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += widths[i] + spacing


# ---------------------------------------------------------------- input

func zone_at(pos: Vector2) -> String:
	var zones: Dictionary = WorldSim.zones()
	for z in zones:
		if lonlat_to_screen(zones[z]["lonlat"]).distance_to(pos) < ZONE_PICK:
			return z
	return ""


func region_at(pos: Vector2) -> String:
	var regs: Dictionary = WorldSim.regions()
	for r in regs:
		if lonlat_to_screen(regs[r]["lonlat"]).distance_to(pos) < MARKER_PICK:
			return r
	return MapGeo.region_at(to_map(pos))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
			accept_event()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_pressing = mb.button_index
				_press_pos = mb.position
				_dragging = false
			elif mb.button_index == _pressing:
				if not _dragging and mb.button_index == MOUSE_BUTTON_LEFT:
					_click(mb.position)
				_pressing = 0
				_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing != 0:
			if not _dragging and mm.position.distance_to(_press_pos) > DRAG_START:
				_dragging = true
			if _dragging:
				_origin += mm.relative
				_apply_view()
				return
		var hz: String = zone_at(mm.position)
		var h: String = "" if hz != "" else region_at(mm.position)
		if h != _hover or hz != _hover_zone:
			_hover = h
			_hover_zone = hz
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (h != "" or hz != "") else Control.CURSOR_ARROW
			_layer.queue_redraw()


func _click(pos: Vector2) -> void:
	var z: String = zone_at(pos)
	if z != "":
		zone_clicked.emit(z)
		return
	var r: String = region_at(pos)
	if r != "":
		region_clicked.emit(r)
