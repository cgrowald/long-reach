extends "res://v2/os/app.gd"
## Monitor: live CPU / memory / network graphs and the process list. hearthd-telemetry hogs the CPU,
## and the network spikes when it phones home.

const N := 48

var _cpu: Array = []
var _net: Array = []
var _t := 0.0
var _step := 0.0
var _graph: Control
var _procs: Label


func build() -> void:
	for i in N:
		_cpu.append(0.5)
		_net.append(0.1)
	var v := vbox()
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 62)
	_graph.draw.connect(_draw_graphs)
	v.add_child(_graph)
	_procs = P.label("")
	_procs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_procs)
	_refresh_procs()


func _process(delta: float) -> void:
	_t += delta
	_step += delta
	if _step < 0.15:
		return
	_step = 0.0
	var phone_home := fmod(_t, 4.0) < 0.6
	_cpu.pop_front()
	_cpu.append(clampf(0.55 + 0.15 * sin(_t * 1.7) + randf_range(-0.12, 0.12) + (0.2 if phone_home else 0.0), 0.05, 1.0))
	_net.pop_front()
	_net.append(clampf((0.85 if phone_home else 0.08) + randf_range(-0.06, 0.06), 0.0, 1.0))
	_graph.queue_redraw()


func _draw_graphs() -> void:
	var w := _graph.size.x
	var half := (w - 6) * 0.5
	_box(Rect2(0, 0, half, 58), "CPU %d%%" % int(_cpu[N - 1] * 100.0), _cpu, Color(0.4, 1.0, 0.4))
	_box(Rect2(half + 6, 0, half, 58), "NET  outbound: hearth.gov", _net, Color(1.0, 0.6, 0.3))


func _box(r: Rect2, label: String, vals: Array, col: Color) -> void:
	_graph.draw_rect(r, Color(0.03, 0.04, 0.05))
	for gy in 4:
		_graph.draw_line(Vector2(r.position.x, r.position.y + 10 + gy * 12), Vector2(r.end.x, r.position.y + 10 + gy * 12), Color(0.1, 0.3, 0.15))
	var pts := PackedVector2Array()
	for i in vals.size():
		pts.append(Vector2(r.position.x + r.size.x * i / float(N - 1), r.end.y - 2 - float(vals[i]) * (r.size.y - 12)))
	_graph.draw_polyline(pts, col, 1.0)
	P.text(_graph, r.position + Vector2(2, 1), label, col)


func _refresh_procs() -> void:
	var lines: Array = ["%-20s %-8s %4s" % ["PROCESS", "USER", "CPU"]]
	for pr in Fs.data().get("processes", []):
		lines.append("%-20s %-8s %3d%%" % [pr["name"], pr["user"], int(pr["cpu"])])
	_procs.text = "\n".join(PackedStringArray(lines))
