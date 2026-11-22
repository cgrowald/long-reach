extends Control
## Placeholder pixel hands at the bottom of the view. They sway, and the right hand reaches toward clicks.
## Hidden (slid down) while you're leaned in to a station.

const SKIN := Color(0.78, 0.55, 0.42)
const SKIN_D := Color(0.55, 0.36, 0.28)
const SLEEVE := Color(0.18, 0.2, 0.17)
const SLEEVE_D := Color(0.1, 0.11, 0.1)

var track := false        # working at a bench: the right hand follows the cursor
var cursor := Vector2.ZERO
var _track_pos := Vector2.ZERO
var _t := 0.0
var _reach := 0.0
var _reach_to := Vector2.ZERO
var _down := 0.0          # 0 = shown, 1 = hidden
var _down_target := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func reach(at: Vector2) -> void:
	_reach_to = at
	_reach = 1.0


func set_shown(on: bool) -> void:
	_down_target = 0.0 if on else 1.0


func _process(delta: float) -> void:
	_t += delta
	_reach = maxf(0.0, _reach - delta * 3.2)
	_down = lerpf(_down, _down_target, 1.0 - exp(-10.0 * delta))
	queue_redraw()


func _draw() -> void:
	var drop := _down * 90.0
	var sway := Vector2(sin(_t * 1.1) * 1.5, sin(_t * 2.2) * 1.0 + drop)
	var lb := Vector2(size.x * 0.22, size.y + 24) + sway
	_hand(lb, -1.0, Vector2.ZERO)
	var rb := Vector2(size.x * 0.78, size.y + 24) + Vector2(-sway.x, sway.y)
	if track:
		# Hold the tool: the hand trails the cursor, its fingertips just below it.
		var want := cursor + Vector2(18, 70)
		_track_pos = _track_pos.lerp(want, 0.25) if _track_pos != Vector2.ZERO else want
		var tilt := (cursor - _track_pos) * 0.3
		_hand(_track_pos, 1.0, tilt)
		return
	_track_pos = Vector2.ZERO
	var k := sin(_reach * PI * 0.5)
	var to := (_reach_to - rb) * 0.18 * k
	_hand(rb + to, 1.0, to)


## A blocky forearm and hand, mirrored for the left (side = -1).
func _hand(base: Vector2, side: float, tilt: Vector2) -> void:
	var up := Vector2(-0.35 * side, -1).normalized()
	if tilt.length() > 1.0:
		up = (up + tilt.normalized() * 0.4).normalized()
	var right := Vector2(-up.y, up.x)
	var p := func(u: float, r: float) -> Vector2: return (base + up * u + right * r * side).round()
	draw_colored_polygon(PackedVector2Array([p.call(0, -14), p.call(0, 14), p.call(40, 12), p.call(40, -11)]), SLEEVE)
	draw_colored_polygon(PackedVector2Array([p.call(0, 8), p.call(0, 14), p.call(40, 12), p.call(40, 7)]), SLEEVE_D)
	draw_colored_polygon(PackedVector2Array([p.call(38, -11), p.call(38, 12), p.call(44, 12), p.call(44, -11)]), SLEEVE_D)
	# Palm and fingers.
	draw_colored_polygon(PackedVector2Array([p.call(43, -10), p.call(43, 11), p.call(60, 12), p.call(62, -8)]), SKIN)
	for i in 4:
		var x := -8.0 + i * 5.0
		draw_colored_polygon(PackedVector2Array([p.call(59, x), p.call(59, x + 4), p.call(70 - absf(i - 1.5) * 2.0, x + 4), p.call(70 - absf(i - 1.5) * 2.0, x)]), SKIN if i % 2 == 0 else SKIN_D.lerp(SKIN, 0.5))
	draw_colored_polygon(PackedVector2Array([p.call(46, 10), p.call(46, 15), p.call(56, 18), p.call(57, 13)]), SKIN_D)
