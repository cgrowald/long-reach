extends "res://v2/os/app.gd"
## Jobs: the targets you can hit tonight. Shows what a job needs (the three programs), what's in the box,
## and its cost in hours. Start = pay the hours, open the job window.

const Job := preload("res://v2/sim/hack_job.gd")
const NEEDS := ["pscan", "crack", "siphon"]

var _list: VBoxContainer


func build() -> void:
	var v := vbox()
	v.add_child(P.label("Jobs run through the box on the desk. HEARTH can't see it.", P.INK_DIM))
	var box_l := P.label(_box_text(), P.INK)
	v.add_child(box_l)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill()


func _box_text() -> String:
	var parts: Array = []
	for slot in ["scan", "crack", "net"]:
		var g := Job.plugged(state(), slot)
		parts.append("%s: %s" % [slot.to_upper(), ("%s %s" % [g["name"].replace(" (gadget)", ""), "*".repeat(int(g["stars"]))]) if not g.is_empty() else "empty"])
	return "The box   " + "   ".join(PackedStringArray(parts))


func missing_programs() -> Array:
	var inst: Array = state().os.get("installed", [])
	var out: Array = []
	for id in NEEDS:
		if not inst.has(id):
			out.append({"pscan": "pscan", "crack": "crackle", "siphon": "siphon"}[id])
	return out


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var done: Array = state().os.get("jobs_done", [])
	var miss := missing_programs()
	for t in Job.targets():
		var td: Dictionary = t
		var locked: bool = td.has("after") and not done.has(td["after"])
		var row := HBoxContainer.new()
		_list.add_child(row)
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.draw.connect(func() -> void: P.icon(ic, "lock" if locked else "target", Vector2(1, 1)))
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		col.add_child(P.label("%s - %s" % [td["name"], td["what"]], P.INK))
		var sub := "Costs %sh.  %d machines.  Password owner: %s" % [str(td["hours"]), int(td["nodes"]), td["owner"]]
		if locked:
			sub = "Locked: do the %s job first." % Job.target_def(td["after"]).get("name", "?")
		elif done.has(td["id"]):
			sub = "Done before. You can hit it again. " + sub
		col.add_child(P.label(sub, P.INK_DIM, maxf(80.0, size.x - 90.0)))
		var b := button("Start", func() -> void: start(td["id"]))
		b.disabled = locked
		row.add_child(b)
		_list.add_child(HSeparator.new())
	if not miss.is_empty():
		_list.add_child(P.label("You need these programs first: %s." % ", ".join(PackedStringArray(miss)), P.BAD))
		_list.add_child(button("Open Software", func() -> void: os.launch("software")))


## Start a job: check the programs, pay the hours, open the job window (also used by tests).
func start(id: String) -> Control:
	var miss := missing_programs()
	if not miss.is_empty():
		os.alert("Jobs", "Missing programs: %s.\nInstall them in Software (or type pkg install NAME in the Terminal)." % ", ".join(PackedStringArray(miss)), "warn")
		return null
	var td := Job.target_def(id)
	if os.spend_hours.is_valid() and not os.spend_hours.call(float(td.get("hours", 2.0))):
		os.alert("Jobs", "Not enough night left for this job (%sh)." % str(td.get("hours", 2.0)), "warn")
		return null
	var w: Control = os.launch("job", id)
	if w and not w.maximized:
		w.toggle_max()
	return w
