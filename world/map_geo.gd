extends RefCounted
## Campaign map geometry, built once and cached: smoothed coastlines, region shapes
## (rough areas clipped to the coast), city positions, all projected (Miller) into map
## units (~degrees). Presentation only.

const GameData := preload("res://sim/game_data.gd")
const LAND_PATH := "res://data/world_land.json"
const AREAS_PATH := "res://data/region_areas.json"
const SMOOTH_PASSES := 2

static var _built: bool = false
static var land: Array[PackedVector2Array] = []      # projected, smoothed
static var water: Array[PackedVector2Array] = []
static var regions: Dictionary = {}                  # id -> Array[PackedVector2Array] (projected)
static var region_bounds: Dictionary = {}            # id -> Rect2
static var cities: Dictionary = {}                   # name -> Vector2 (projected)
static var view_rect: Rect2                          # projected rect the map is framed on


static func build() -> void:
	if _built:
		return
	_built = true
	var ld: Dictionary = GameData.load_json(LAND_PATH)
	var ad: Dictionary = GameData.load_json(AREAS_PATH)
	var land_ll: Array[PackedVector2Array] = []
	for poly in ld.get("land", []):
		land_ll.append(_smooth(_to_packed(poly), SMOOTH_PASSES))
	for poly in ld.get("water", []):
		water.append(_project(_smooth(_to_packed(poly), SMOOTH_PASSES)))
	for p in land_ll:
		if Geometry2D.triangulate_polygon(p).is_empty():
			push_warning("MapGeo: a land polygon could not be triangulated (%d points near %s)" % [p.size(), p[0]])
		land.append(_project(p))

	# Regions: area ∩ land, minus whatever earlier regions already took.
	var taken: Array[PackedVector2Array] = []
	var areas: Dictionary = ad.get("areas", {})
	for id in ad.get("order", []):
		var pieces: Array[PackedVector2Array] = []
		for area in areas.get(id, []):
			var a: PackedVector2Array = _to_packed(area)
			for l in land_ll:
				for piece in _outers(Geometry2D.intersect_polygons(a, l)):
					pieces.append(piece)
		for prev in taken:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				for rest in _outers(Geometry2D.clip_polygons(piece, prev)):
					next.append(rest)
			pieces = next
		var projected: Array[PackedVector2Array] = []
		var bounds := Rect2()
		for piece in pieces:
			if piece.size() < 3:
				continue
			taken.append(piece)
			var pp: PackedVector2Array = _project(piece)
			projected.append(pp)
			var r: Rect2 = _rect_of(pp)
			bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
		regions[id] = projected
		region_bounds[id] = bounds

	for name in ad.get("cities", {}):
		var c: Array = ad["cities"][name]
		cities[name] = project(Vector2(float(c[0]), float(c[1])))
	var v: Dictionary = ld.get("view", {})
	var a0: Vector2 = project(Vector2(float(v.get("lon_min", -134)), float(v.get("lat_max", 62))))
	var a1: Vector2 = project(Vector2(float(v.get("lon_max", 179)), float(v.get("lat_min", -42))))
	view_rect = Rect2(a0, a1 - a0)


## Miller cylindrical: x = lon, y = -miller(lat), both in degrees.
static func project(lonlat: Vector2) -> Vector2:
	var lat: float = deg_to_rad(clampf(lonlat.y, -85.0, 85.0))
	var y: float = 1.25 * log(tan(PI * 0.25 + 0.4 * lat))
	return Vector2(lonlat.x, -rad_to_deg(y))


static func project_arr(a: Array) -> Vector2:
	return project(Vector2(float(a[0]), float(a[1])))


static func _project(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = project(p[i])
	return out


static func _to_packed(poly: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(Vector2(float(q[0]), float(q[1])))
	return out


## Chaikin corner cutting: rounds the hand-drawn coastline into organic curves.
static func _smooth(p: PackedVector2Array, passes: int) -> PackedVector2Array:
	var cur: PackedVector2Array = p
	for _k in passes:
		var out := PackedVector2Array()
		var n: int = cur.size()
		for i in n:
			var a: Vector2 = cur[i]
			var b: Vector2 = cur[(i + 1) % n]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		cur = out
	return cur


## Drop hole polygons from a clipping result (a hole lies inside another result polygon).
static func _outers(polys: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i in polys.size():
		var p: PackedVector2Array = polys[i]
		var hole: bool = false
		for j in polys.size():
			if i != j and Geometry2D.is_point_in_polygon(p[0], polys[j]) and Geometry2D.is_polygon_clockwise(p) != Geometry2D.is_polygon_clockwise(polys[j]):
				hole = true
				break
		if not hole:
			out.append(p)
	return out


static func _rect_of(p: PackedVector2Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in p:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	return Rect2(lo, hi - lo)


## Region id under a projected point ("" when none). Water bodies count as no region.
static func region_at(p: Vector2) -> String:
	for w in water:
		if Geometry2D.is_point_in_polygon(p, w):
			return ""
	for id in regions:
		if not (region_bounds[id] as Rect2).grow(0.01).has_point(p):
			continue
		for poly in regions[id]:
			if Geometry2D.is_point_in_polygon(p, poly):
				return id
	return ""


## Rough visual center of a region (bounds center of its biggest piece).
static func region_center(id: String) -> Vector2:
	var best: PackedVector2Array
	var best_a: float = -1.0
	for poly in regions.get(id, []):
		var r: Rect2 = _rect_of(poly)
		if r.get_area() > best_a:
			best_a = r.get_area()
			best = poly
	return _rect_of(best).get_center() if best_a >= 0.0 else Vector2.ZERO
