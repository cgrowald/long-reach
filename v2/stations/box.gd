extends "res://v2/stations/station.gd"
## The box: the machine on the desk that HEARTH can't see (it's external). Your gadgets lie on the desk in
## front of it; drag one onto a slot on top (SCAN / CRACK / NET) and its lamp lights. Right-click a slot to
## unplug. Jobs themselves run from the PC (Jobs app). Plugged gadgets: state.os["box"] = {slot: item id}.

const GarageWorld := preload("res://v2/world/garage_world.gd")
const PixelView := preload("res://v2/ui/pixel_view.gd")
const SLOTS := ["scan", "crack", "net"]
## Slot and gadget places on the desk come from data/v2/stations.json (station "rig": slots, gadget_home, gadget_step).
const SLOT_COL := {"scan": Color(0.35, 0.65, 1.0), "crack": Color(1.0, 0.72, 0.25), "net": Color(0.55, 1.0, 0.45)}
const SLOT_TEXT := {"scan": "SCAN: widens pscan's pings", "crack": "CRACK: crosses out wrong guesses", "net": "NET: slows the trace"}
const CUE := Color(1.0, 0.3, 0.85)

var _root: Node3D
var _slot_pos := {}        # slot -> Vector3 (global)
var _lamps := {}           # slot -> MeshInstance3D
var _gadgets: Array = []   # {item, mesh, home}
var _held := -1
var _t := 0.0
var _mats := {}
var _cam: Camera3D


func build() -> void:
	_cam = garage.world.camera
	_root = Node3D.new()
	garage.world.add_child(_root)
	for slot in SLOTS:
		var p := GarageWorld.b2g(def["slots"][slot])
		_slot_pos[slot] = p
		_box(Vector3(0.13, 0.012, 0.08), Color(0.05, 0.05, 0.06), p)
		_box(Vector3(0.13, 0.013, 0.008), (SLOT_COL[slot] as Color).darkened(0.5), p + Vector3(0, 0, 0.044))
		_lamps[slot] = _box(Vector3(0.018, 0.012, 0.018), Color(0.15, 0.08, 0.06), p + Vector3(0.05, 0.004, 0.058))
	var gs: Array = []
	for it in game.state.items:
		if it.get("type", "") == "gadget":
			gs.append(it)
	for i in gs.size():
		var it: Dictionary = gs[i]
		var h0: Array = def["gadget_home"]
		var st: Array = def["gadget_step"]
		var home := GarageWorld.b2g([float(h0[0]) + int(i / 6) * float(st[0]), float(h0[1]) + (i % 6) * float(st[1]), h0[2]])
		var m := _gadget_mesh(it)
		_gadgets.append({"item": it, "mesh": m, "home": home})
		var slot := _slot_of(it)
		m.global_position = (_slot_pos[slot] as Vector3) + Vector3(0, 0.012, 0) if slot != "" else home
	_refresh_lamps()
	var back_b := Kit.button("Back", close, game)
	add_child(back_b)
	back_b.position = Vector2(size.x - 52, size.y - 26)
	game.sfx.play("switch_002", 0.7, -8.0)


func _exit_tree() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()


# ------------------------------------------------------------------ meshes

func _mat(col: Color, glow := false) -> StandardMaterial3D:
	var k := str(col) + str(glow)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.9
		if glow:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 2.0
		_mats[k] = m
	return _mats[k]


func _box(sz: Vector3, col: Color, pos: Vector3, parent: Node3D = null, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = _mat(col, glow)
	(parent if parent else _root).add_child(mi)
	mi.global_position = pos
	return mi


func _gadget_mesh(it: Dictionary) -> MeshInstance3D:
	var slot: String = it.get("box_slot", "scan")
	var m := _box(Vector3(0.07, 0.01, 0.05), Color(0.08, 0.25, 0.14), Vector3.ZERO)
	var chip := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.025, 0.008, 0.02)
	chip.mesh = cb
	chip.material_override = _mat(Color(0.05, 0.05, 0.05))
	m.add_child(chip)
	chip.position = Vector3(-0.01, 0.008, 0)
	var stripe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.07, 0.011, 0.008)
	stripe.mesh = sb
	stripe.material_override = _mat(SLOT_COL.get(slot, Color.WHITE))
	m.add_child(stripe)
	stripe.position = Vector3(0, 0.001, 0.021)
	return m


# ------------------------------------------------------------------ state

func _box_state() -> Dictionary:
	if not game.state.os.has("box"):
		game.state.os["box"] = {}
	return game.state.os["box"]


func _slot_of(it: Dictionary) -> String:
	var b := _box_state()
	for s in b:
		if int(b[s]) == int(it["id"]):
			return s
	return ""


func _gadget_in(slot: String) -> int:
	var b := _box_state()
	if not b.has(slot):
		return -1
	for i in _gadgets.size():
		if int(_gadgets[i]["item"]["id"]) == int(b[slot]):
			return i
	return -1


## Plug gadget i into slot (also used by tests). Returns false if it doesn't fit there.
func plug(i: int, slot: String) -> bool:
	var g: Dictionary = _gadgets[i]
	var want: String = g["item"].get("box_slot", "")
	if want != slot:
		garage.toast("That's a %s gadget. It goes in the %s slot." % [want.to_upper(), want.to_upper()])
		game.deny()
		_send_home(i)
		return false
	var old := _gadget_in(slot)
	if old >= 0 and old != i:
		_send_home(old)
	var b := _box_state()
	for s in b.keys():
		if int(b[s]) == int(g["item"]["id"]):
			b.erase(s)
	b[slot] = int(g["item"]["id"])
	_stop_tween(g)
	(g["mesh"] as Node3D).global_position = (_slot_pos[slot] as Vector3) + Vector3(0, 0.012, 0)
	game.sfx.play("switch_002", 1.2, -6.0)
	game.sfx.play("confirmation_004", 1.0 + SLOTS.find(slot) * 0.1, -10.0)
	_refresh_lamps()
	return true


func unplug(slot: String) -> void:
	var i := _gadget_in(slot)
	_box_state().erase(slot)
	if i >= 0:
		_send_home(i)
	game.sfx.play("switch_002", 0.8, -8.0)
	_refresh_lamps()


func _send_home(i: int) -> void:
	var g: Dictionary = _gadgets[i]
	var m: Node3D = g["mesh"]
	_stop_tween(g)
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", g["home"], 0.18)
	g["tween"] = tw


func _stop_tween(g: Dictionary) -> void:
	var old: Tween = g.get("tween")
	if old and old.is_valid():
		old.kill()


func _refresh_lamps() -> void:
	for slot in SLOTS:
		var on := _gadget_in(slot) >= 0
		(_lamps[slot] as MeshInstance3D).material_override = _mat(SLOT_COL[slot] if on else Color(0.15, 0.08, 0.06), on)


# ------------------------------------------------------------------ input

func _screen(p: Vector3) -> Vector2:
	return PixelView.to_ui(self, _cam, _cam.unproject_position(p))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var best := -1
		var bd := 18.0
		for i in _gadgets.size():
			var d := _screen((_gadgets[i]["mesh"] as Node3D).global_position).distance_to(e.position)
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			_held = best
			game.click()
		accept_event()
	elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _held >= 0:
		var i := _held
		_held = -1
		var slot := _slot_near(e.position)
		if slot != "":
			plug(i, slot)
		else:
			if _slot_of(_gadgets[i]["item"]) != "":
				unplug(_slot_of(_gadgets[i]["item"]))
			_send_home(i)
		accept_event()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		var slot := _slot_near(e.position)
		if slot != "" and _gadget_in(slot) >= 0:
			unplug(slot)
		else:
			close()
		accept_event()
	elif e is InputEventMouseMotion and _held >= 0:
		var p3 := PixelView.to_3d(self, _cam, e.position)
		var o := _cam.project_ray_origin(p3)
		var d := _cam.project_ray_normal(p3)
		var hit = Plane(Vector3.UP, (_slot_pos["scan"] as Vector3).y + 0.03).intersects_ray(o, d)
		if hit != null:
			(_gadgets[_held]["mesh"] as Node3D).global_position = hit


func _slot_near(p: Vector2) -> String:
	var best := ""
	var bd := 26.0
	for slot in SLOTS:
		var d := _screen(_slot_pos[slot]).distance_to(p)
		if d < bd:
			bd = d
			best = slot
	return best


# ------------------------------------------------------------------ labels

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var top := Rect2(Vector2(10, 8), Vector2(size.x - 20, 36))
	draw_rect(top, Color(0.075, 0.058, 0.045, 0.94))
	draw_rect(top, Pal.BRASS, false, 1.0)
	var tg := Pal.tag(self, top.position + Vector2(5, 4), "THE BOX", 10)
	Pal.text(self, Vector2(tg.end.x + 10, top.position.y + 4), "External. HEARTH can't see it. Jobs run from the PC (Jobs app).", 9, Pal.TEXT)
	Pal.text(self, Vector2(tg.end.x + 10, top.position.y + 20), "Drag a gadget onto its slot. Right-click a slot to unplug.", 8, Pal.DIM)
	for slot in SLOTS:
		var sp := _screen(_slot_pos[slot])
		var i := _gadget_in(slot)
		var col: Color = SLOT_COL[slot]
		var lab: String = slot.to_upper()
		Pal.text(self, sp + Vector2(-40, -34), lab, 9, col, HORIZONTAL_ALIGNMENT_CENTER, 80)
		var sub := "empty"
		if i >= 0:
			var it: Dictionary = _gadgets[i]["item"]
			sub = "%s %s" % [str(it["name"]).replace(" (gadget)", ""), "*".repeat(int(it["stars"]))]
		Pal.text(self, sp + Vector2(-50, -24), sub, 8, Pal.TEXT if i >= 0 else Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, 100)
	if _gadgets.is_empty():
		Pal.text(self, Vector2(0, size.y * 0.72), "No gadgets yet. Make one at the hacking bench (the right end of this desk).", 9, Pal.AMBER, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var cue_done := false
	for i in _gadgets.size():
		var g: Dictionary = _gadgets[i]
		var it: Dictionary = g["item"]
		var gp := _screen((g["mesh"] as Node3D).global_position)
		var on_desk := _slot_of(it) == "" and i != _held
		if on_desk:
			Pal.text(self, gp + Vector2(-25, 8), "%s %s" % [str(it.get("box_slot", "?")).to_upper(), "*".repeat(int(it["stars"]))], 8, SLOT_COL.get(it.get("box_slot", ""), Pal.TEXT), HORIZONTAL_ALIGNMENT_CENTER, 50)
			var want: String = it.get("box_slot", "")
			if not cue_done and want != "" and _gadget_in(want) < 0 and _held < 0:
				# the pink "this goes here" cue: from the gadget to its empty slot
				cue_done = true
				var pulse := 1.0 + 0.2 * sin(_t * 7.0)
				draw_arc(gp, 10.0 * pulse, 0, TAU, 16, CUE, 1.0)
				var to := _screen(_slot_pos[want])
				var ph := fmod(_t * 1.2, 1.0)
				draw_line(gp, to, Color(CUE, 0.4), 1.0)
				draw_circle(gp.lerp(to, ph), 1.5, CUE)
				draw_arc(to, 12.0 * pulse, 0, TAU, 16, CUE, 1.0)
				Pal.text(self, to + Vector2(16, -4), "DRAG IT HERE", 8, CUE)
	Pal.text(self, Vector2(10, size.y - 14), "Esc: step back", 8, Pal.DIM)
