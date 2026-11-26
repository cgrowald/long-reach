extends Control
## M4 V5: the town map (docs/M4_VARIETY.md section 10; layout from v2/sim/town.gd). One map for planning
## and for going out at night (user 2026-11-26): painted-looking streets seen steeply from above, buildings
## standing up, you and the patrols as flat cut-outs under real lamplight (Paper Mario / HD-2D in Godot:
## Sprite3D cut-outs in a lit 3D scene). Walk with WASD (the user: click-to-move is old and clunky).
## Game meta "map_mode": "walk" (out after curfew: patrols, getting caught) or "plan" (from the garage:
## nobody out, look around). E at a place: plan the hit, meet a group, the Tram Yard, home.
## Stand-in art (V5-8): blocks with lit windows, until GPT's painted kit.

const PixelView := preload("res://v2/ui/pixel_view.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Town := preload("res://v2/sim/town.gd")
const Targets := preload("res://v2/sim/targets.gd")
const Markets := preload("res://v2/sim/markets.gd")

const SPEED := 6.5
const RUN := 10.0
const CAM_OFF := Vector3(0, 60, 38)      # steeply from above, from the street side (orthographic)
const PATROL_SPEED := 2.2
const SEE := 8.5
const CONE := 0.5

var game: Node
var state: RefCounted
var mode := "walk"
var L: Dictionary
var view
var world: Node3D
var cam: Camera3D
var me: CharacterBody3D
var me_sprite: Sprite3D
var hud: Control
var pins: Array = []              # {kind, ref, rect: Rect2 (building), label: Label3D, text}
var patrols: Array = []           # {node, sprite, light, path: [Vector3], seg, pos: Vector3, dir: Vector3, meter}
var near: Dictionary = {}
var overview := false
var phase := "map"                # map, yard, caught
var caught_meter := 0.0
var _msg := ""
var _msg_t := 0.0
var _t := 0.0
var _btns: Array = []
var _zoom := 1.0


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state = game.state
	mode = str(game.get_meta("map_mode", "walk"))
	L = Town.layout(state)
	Targets.list(state)              # every target placed in the town
	view = PixelView.new()
	add_child(view)
	world = Node3D.new()
	view.vp.add_child(world)
	_environment()
	_ground()
	_buildings()
	_lamps()
	_player()
	_pins()
	if mode == "walk":
		_patrols()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 34.0
	world.add_child(cam)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	view.ui.add_child(hud)
	hud.draw.connect(_draw_hud)
	hud.gui_input.connect(_hud_input)
	_say("Out the side door. WASD to walk, Shift to run. Stay out of the torches." if mode == "walk" else "The town. WASD to look around, E at a place, Tab for the whole map.", 6.0)
	_place_camera(1.0)


# ------------------------------------------------------------------ building the town

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.55)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 25, 0)
	world.add_child(moon)


func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(parent if parent else world).add_child(mi)
	return mi


func _ground() -> void:
	var sz: Rect2 = L["size"]
	_box(Vector3(sz.size.x + 40, 0.2, sz.size.y + 40), Vector3(sz.get_center().x, -0.1, sz.get_center().y), _mat(Color(0.09, 0.09, 0.1)))
	for d in L["districts"]:
		var rc: Rect2 = d["rect"]
		var tint := Color.html(str(d["colours"][0])).darkened(0.45)
		if Town.held(state, d["id"]):
			tint = tint.lerp(Color(0.6, 0.12, 0.1), 0.25)
		_box(Vector3(rc.size.x, 0.05, rc.size.y), Vector3(rc.get_center().x, 0.0, rc.get_center().y), _mat(tint))
	var asphalt := _mat(Color(0.16, 0.16, 0.18))
	for s in L["streets"]:
		var r: Rect2 = s
		_box(Vector3(r.size.x, 0.06, r.size.y), Vector3(r.get_center().x, 0.03, r.get_center().y), asphalt)
	# the town's edge
	var body := StaticBody3D.new()
	world.add_child(body)
	for e in [Rect2(sz.position.x - 2, sz.position.y - 2, sz.size.x + 4, 2), Rect2(sz.position.x - 2, sz.end.y, sz.size.x + 4, 2),
			Rect2(sz.position.x - 2, sz.position.y, 2, sz.size.y), Rect2(sz.end.x, sz.position.y, 2, sz.size.y)]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(e.size.x, 6, e.size.y)
		cs.shape = bs
		cs.position = Vector3(e.get_center().x, 3, e.get_center().y)
		body.add_child(cs)


func _buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.world_seed) + 5
	var lit := _mat(Color(1.0, 0.72, 0.38), 2.2)
	var dark := _mat(Color(0.08, 0.08, 0.1))
	var body := StaticBody3D.new()
	world.add_child(body)
	for b in L["buildings"]:
		var r: Rect2 = b["rect"]
		var d := Town.district(L, b["district"])
		var wall := Color.html(str(d["colours"][1])).darkened(0.25)
		var roof := Color.html(str(d["colours"][0])).darkened(0.35)
		var h := float(b["h"])
		if b["kind"] == "citadel":
			wall = Color(0.32, 0.31, 0.33)
			roof = Color(0.2, 0.2, 0.22)
		_box(Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, h * 0.5, r.get_center().y), _mat(wall))
		_box(Vector3(r.size.x + 0.4, 0.4, r.size.y + 0.4), Vector3(r.get_center().x, h + 0.2, r.get_center().y), _mat(roof))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(r.size.x, h, r.size.y)
		cs.shape = bs
		cs.position = Vector3(r.get_center().x, h * 0.5, r.get_center().y)
		body.add_child(cs)
		# windows on the street side (south, toward the camera), some lit
		var floors := int(h / 3.0)
		var cols := int(r.size.x / 2.2)
		for fl in floors:
			for c in cols:
				var on := rng.randf() < (0.35 if b["kind"] == "house" else 0.6)
				var wx := r.position.x + (c + 0.5) * r.size.x / cols
				_box(Vector3(0.9, 1.2, 0.05), Vector3(wx, 1.6 + fl * 3.0, r.end.y + 0.03), lit if on else dark)
		if b["kind"] == "citadel":
			# granite columns along its front, and red tapestries
			var red := _mat(Color(0.55, 0.08, 0.08), 0.4)
			var col_m := _mat(Color(0.45, 0.44, 0.46))
			for k in 9:
				var cx := r.position.x + 3 + k * (r.size.x - 6) / 8.0
				_box(Vector3(1.2, h - 2, 1.2), Vector3(cx, (h - 2) * 0.5, r.end.y + 1.2), col_m)
				if k % 2 == 1:
					_box(Vector3(2.2, 6, 0.1), Vector3(cx + (r.size.x - 6) / 16.0, h - 6, r.end.y + 0.08), red)


func _lamps() -> void:
	# a lamp at every few crossings (warm pools on blue-black, art bible)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.world_seed) + 9
	var n := 0
	var pole := _mat(Color(0.1, 0.1, 0.1))
	var bulb := _mat(Color(1.0, 0.75, 0.4), 4.0)
	for s in L["streets"]:
		var r: Rect2 = s
		var along_x := r.size.x > r.size.y
		var length := r.size.x if along_x else r.size.y
		var k := 6.0
		while k < length - 3.0:
			if rng.randf() < 0.45 and n < 70:
				var p := Vector3(r.position.x + k, 0, r.get_center().y + r.size.y * 0.45) if along_x else Vector3(r.get_center().x + r.size.x * 0.45, 0, r.position.y + k)
				_box(Vector3(0.15, 3.4, 0.15), p + Vector3(0, 1.7, 0), pole)
				_box(Vector3(0.4, 0.2, 0.4), p + Vector3(0, 3.4, 0), bulb)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.7, 0.38)
				l.light_energy = 2.4
				l.omni_range = 7.5
				l.position = p + Vector3(0, 3.2, 0)
				world.add_child(l)
				n += 1
			k += rng.randf_range(10.0, 16.0)


## A paper cut-out person: drawn into a small image (coat, head, the two red stripes on the shoulder).
func _cutout(coat: Color, stripes: bool, hat := false) -> ImageTexture:
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(0.82, 0.62, 0.48)
	var dark := coat.darkened(0.45)
	img.fill_rect(Rect2i(5, 1, 6, 6), skin)                 # head
	img.fill_rect(Rect2i(5, 1, 6, 2), Color(0.2, 0.14, 0.1) if not hat else dark)
	img.fill_rect(Rect2i(3, 8, 10, 13), coat)                # coat
	img.fill_rect(Rect2i(2, 9, 2, 9), coat.darkened(0.15))   # arms
	img.fill_rect(Rect2i(12, 9, 2, 9), coat.darkened(0.15))
	img.fill_rect(Rect2i(5, 21, 2, 9), dark)                 # legs
	img.fill_rect(Rect2i(9, 21, 2, 9), dark)
	img.fill_rect(Rect2i(4, 30, 3, 2), Color(0.1, 0.08, 0.07))
	img.fill_rect(Rect2i(9, 30, 3, 2), Color(0.1, 0.08, 0.07))
	if stripes:
		img.fill_rect(Rect2i(11, 9, 1, 3), Color(0.8, 0.15, 0.12))
		img.fill_rect(Rect2i(13, 9, 1, 3), Color(0.8, 0.15, 0.12))
	# a dark outline round everything (paper edge)
	var out := img.duplicate()
	for y in 32:
		for x in 16:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < 16 and q.y < 32 and img.get_pixelv(q).a > 0.0:
					out.set_pixel(x, y, Color(0.96, 0.92, 0.84))
					break
	return ImageTexture.create_from_image(out)


func _sprite(tex: Texture2D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 0.075
	s.offset = Vector2(0, 16)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s.rotation_degrees = Vector3(-20, 0, 0)        # leaning back a little toward the camera, like a stand-up
	return s


func _player() -> void:
	me = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	me.add_child(cs)
	world.add_child(me)
	me_sprite = _sprite(_cutout(Color(0.28, 0.36, 0.3), true))
	me.add_child(me_sprite)
	var gi: int = int(L.get("garage", 0))
	var gr: Rect2 = L["buildings"][gi]["rect"]
	me.position = Vector3(gr.get_center().x, 0, gr.end.y + 2.2)
	var lamp := OmniLight3D.new()           # a faint glow so you can always find yourself
	lamp.light_color = Color(0.9, 0.8, 0.7)
	lamp.light_energy = 0.5
	lamp.omni_range = 3.0
	lamp.position = Vector3(0, 1.5, 0.6)
	me.add_child(lamp)


# ------------------------------------------------------------------ places

func _pins() -> void:
	pins.clear()
	var gi: int = int(L.get("garage", -1))
	if gi >= 0:
		_pin("home", null, L["buildings"][gi]["rect"], "HOME", Color(0.5, 1.0, 0.42))
	var yi: int = int(L.get("yard", -1))
	for gid in L.get("haunts", {}):
		var bi: int = int(L["haunts"][gid])
		var g := Targets.group_def(gid)
		var txt := "THE TRAM YARD\n" if bi == yi else ""
		txt += str(g.get("name", gid)) if Targets.met(state, gid) else "???"
		_pin("haunt", gid, L["buildings"][bi]["rect"], txt, Color(0.55, 0.8, 1.0))
	for t in Targets.list(state):
		if not t.has("bldg"):
			continue
		var col := Color(0.95, 0.9, 0.78)
		if t.has("key"):
			col = Color(1.0, 0.55, 0.25)
		elif t.has("job"):
			col = Color(0.9, 0.6, 0.3)
		if not Targets.can_hit(state, t) or not Town.reachable(state, t):
			col = col.darkened(0.45)
		var stars := "*".repeat(int(t["know"])) + ".".repeat(3 - mini(3, int(t["know"])))
		var txt := "%s\n%s%s" % [t["name"], stars, "  KEY" if t.has("key") else ""]
		_pin("target", t, L["buildings"][int(t["bldg"])]["rect"], txt, col)
	for b in L["buildings"]:
		if b["kind"] == "citadel":
			_pin("citadel", null, b["rect"], "THE CITADEL", Color(1.0, 0.3, 0.25))
		elif str(b["place"]).begins_with("key:") and Town.held(state, str(b["district"])):
			var did := str(b["district"])
			_pin("post", did, b["rect"], "OUR POST\n%d holding, %d armed" % [Town.garrison(state, did), mini(Town.garrison(state, did), Town.arms(state, did))], Color(1.0, 0.45, 0.4))


# ------------------------------------------------------------------ garrisons (V5 part 2)

var _gar_rows: Array = []


func _garrison_button(id: String) -> void:
	if id == "close":
		phase = "map"
		_pins()
		return
	var parts := id.split(":")
	var did := parts[1]
	match parts[0]:
		"add":
			if Town.post(state, did, int(parts[2])) == 0:
				_say("No free militia. Held districts send walk-ins each night.", 4.0)
				game.deny()
		"take":
			Town.post(state, did, -int(parts[2]))
		"arm":
			var r := Town.arm(state, did)
			_say(r, 4.0)
			if r.begins_with("No"):
				game.deny()


func _draw_garrisons(s: Vector2) -> void:
	hud.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.045, 0.88))
	var r := Rect2(30, 40, s.x - 60, s.y - 90)
	Pal.plate(hud, r)
	Pal.tag(hud, r.position + Vector2(12, -8), "GARRISONS", 9)
	Pal.text(hud, r.position + Vector2(14, 10), "Free militia: %d        Spare guns on the shelves: %d" % [Town.militia(state), Town.spare_guns(state).size()], 9, Pal.TEXT)
	Pal.wrap(hud, r.position + Vector2(14, 24), "Every held district needs people or it slips back, and they may come for it any night (an auto battle against its garrison). An armed militiaman counts twice an unarmed one. Don't spread yourself thin.", 7, Pal.DIM, r.size.x - 28, 3)
	var y := r.position.y + 52
	var any := false
	for d in L["districts"]:
		var did: String = d["id"]
		if not Town.held(state, did):
			continue
		any = true
		var row := Rect2(r.position.x + 10, y, r.size.x - 20, 26)
		hud.draw_rect(row, Color(0.12, 0.1, 0.09))
		var bar := int(Town.dstate(state, did)["bar"])
		Pal.text(hud, row.position + Vector2(8, 3), str(d["name"]), 9, Color.html(str(d["colours"][1])).lightened(0.3))
		Pal.text(hud, row.position + Vector2(8, 14), "%d holding (%d armed)   strength %.1f   hold %d%%" % [Town.garrison(state, did), mini(Town.garrison(state, did), Town.arms(state, did)), Town.strength(state, did), bar], 7, Pal.TEXT)
		var bx := row.end.x - 250
		_btn(Rect2(bx, row.position.y + 5, 44, 16), "-1", "take:%s:1" % did, Town.garrison(state, did) > 0)
		_btn(Rect2(bx + 48, row.position.y + 5, 44, 16), "+1", "add:%s:1" % did, Town.militia(state) > 0)
		_btn(Rect2(bx + 96, row.position.y + 5, 44, 16), "+5", "add:%s:5" % did, Town.militia(state) > 0)
		_btn(Rect2(bx + 144, row.position.y + 5, 100, 16), "GIVE A GUN", "arm:%s" % did, not Town.spare_guns(state).is_empty())
		y += 30
	if not any:
		Pal.wrap(hud, Vector2(r.position.x + 14, y), "You hold nothing yet. Take a district's KEY (its police post) on the front and it's yours to defend.", 8, Pal.TEXT, r.size.x - 28, 3)
	_btn(Rect2(r.end.x - 110, r.end.y - 28, 98, 20), "DONE (G)", "close")


func _pin(kind: String, ref, r: Rect2, text: String, col: Color) -> void:
	var h := 10.0
	for b in L["buildings"]:
		if b["rect"] == r:
			h = float(b["h"])
	pins.append({"kind": kind, "ref": ref, "rect": r, "pos": Vector3(r.get_center().x, h + 0.5, r.get_center().y), "text": text, "col": col})


func _nearest_place() -> Dictionary:
	var p := Vector2(me.position.x, me.position.z)
	var best := {}
	var bd := 3.2
	for pin in pins:
		var r: Rect2 = pin["rect"]
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var d := p.distance_to(q)
		if d < bd:
			bd = d
			best = pin
	return best


func _use(pin: Dictionary) -> void:
	match str(pin["kind"]):
		"home":
			_go_home()
		"post":
			phase = "garrison"
			game.click()
		"citadel":
			_say("The citadel. Granite and red cloth. Not yet: you'll need everyone.", 5.0)
			game.deny()
		"haunt":
			var gid := str(pin["ref"])
			if int(L.get("yard", -1)) >= 0 and L["haunts"].get(gid, -2) == L["yard"] and mode == "walk":
				phase = "yard"
				game.click()
				return
			if not Targets.met(state, gid):
				Targets._group(state, gid)["met"] = true
				state.flags["contacts_new"] = true
				var g := Targets.group_def(gid)
				_say("You met %s. %s Deal with them on the PC (Contacts)." % [g.get("name", gid), g.get("who", "")], 7.0)
				_pins()
			else:
				_say("%s: \"Message us on the PC.\"" % Targets.group_def(gid).get("name", gid), 4.0)
		"target":
			var t: Dictionary = pin["ref"]
			if not Town.reachable(state, t):
				_say("Behind their lines. Take the district next to it first.", 5.0)
				game.deny()
			elif not Targets.can_hit(state, t):
				_say("Shut. %d more night%s." % [Targets.shut_for(state, t), "" if Targets.shut_for(state, t) == 1 else "s"], 4.0)
				game.deny()
			elif Targets.team(state, t).is_empty():
				_say("Nobody fit to go.", 4.0)
				game.deny()
			else:
				game.click()
				game.set_meta("fight_target", t["id"])
				game.set_meta("fight_plan", {})
				game.goto("res://v2/combat/plan_screen.tscn")


func _go_home() -> void:
	var lines: Array = []
	if mode == "walk":
		var got: Array = Markets.bring_home(state)
		lines.append("Home. The roller door, quietly.")
		if not got.is_empty():
			lines.append("On the shelves now: " + ", ".join(PackedStringArray(got)) + ".")
	game.set_meta("op_notes", lines)
	game.goto("res://v2/garage.tscn")


# ------------------------------------------------------------------ patrols

func _patrols() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:patrol:%d" % [int(state.world_seed), int(state.day)])
	var tex := _cutout(Color(0.3, 0.32, 0.36), false, true)
	var gr: Rect2 = L["buildings"][int(L.get("garage", 0))]["rect"]
	for d in L["districts"]:
		if d["role"] == "citadel":
			continue
		var n := 1 + int(float(state.attention) / 40.0) + (1 if d["role"] == "ministry" else 0)
		if Town.held(state, d["id"]):
			n = maxi(0, n / 2)                     # held: fewer patrols (V5-5)
		var blocks: Array = L["buildings"].filter(func(b: Dictionary) -> bool: return b["district"] == d["id"])
		for k in n:
			if blocks.is_empty():
				break
			var b: Dictionary = blocks[rng.randi() % blocks.size()]
			var r: Rect2 = (b["rect"] as Rect2).grow(2.2)
			if r.grow(6.0).has_point(gr.get_center()):
				continue                           # never on your doorstep
			var path := [Vector3(r.position.x, 0, r.end.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.position.x, 0, r.position.y)]
			if rng.randf() < 0.5:
				path.reverse()
			var node := Node3D.new()
			world.add_child(node)
			var spr := _sprite(tex)
			node.add_child(spr)
			var torch := SpotLight3D.new()
			torch.light_color = Color(1.0, 0.95, 0.8)
			torch.light_energy = 4.0
			torch.spot_range = SEE + 1.0
			torch.spot_angle = rad_to_deg(CONE) + 4.0
			torch.position = Vector3(0, 1.3, 0)
			node.add_child(torch)
			var seg := rng.randi() % 4
			var t0 := rng.randf()
			var pos: Vector3 = (path[seg] as Vector3).lerp(path[(seg + 1) % 4], t0)
			node.position = pos
			patrols.append({"node": node, "torch": torch, "path": path, "seg": seg, "dir": Vector3.FORWARD, "meter": 0.0})


func _tick_patrols(delta: float) -> void:
	var seen := false
	for p in patrols:
		var node: Node3D = p["node"]
		var target: Vector3 = p["path"][(int(p["seg"]) + 1) % 4]
		var to := target - node.position
		if to.length() < 0.2:
			p["seg"] = (int(p["seg"]) + 1) % 4
		else:
			var dir := to.normalized()
			p["dir"] = (p["dir"] as Vector3).lerp(dir, minf(1.0, delta * 4.0)).normalized()
			node.position += dir * PATROL_SPEED * delta
		var dv: Vector3 = p["dir"]
		var torch: SpotLight3D = p["torch"]
		torch.look_at(node.position + Vector3(0, 0.6, 0) + dv * 4.0 + Vector3(0, 0, 0.001), Vector3.UP)
		# do they see you: in the torch cone, in range, nothing in between
		var rel := me.position - node.position
		rel.y = 0
		var d := rel.length()
		if d < SEE and d > 0.01 and dv.dot(rel / d) > cos(CONE):
			var q := PhysicsRayQueryParameters3D.create(node.position + Vector3(0, 1.2, 0), me.position + Vector3(0, 1.2, 0))
			q.exclude = [me.get_rid()]
			if world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				seen = true
				p["meter"] = minf(1.0, float(p["meter"]) + delta * (1.6 if d < 4.0 else 0.8) * (1.6 if Input.is_key_pressed(KEY_SHIFT) else 1.0))
				if float(p["meter"]) >= 1.0:
					_caught()
				continue
		p["meter"] = maxf(0.0, float(p["meter"]) - delta * 0.35)
	caught_meter = 0.0
	for p in patrols:
		caught_meter = maxf(caught_meter, float(p["meter"]))
	if seen and _t > 0.0 and int(_t * 2.0) % 2 == 0:
		pass


func _caught() -> void:
	if phase == "caught":
		return
	phase = "caught"
	game.sfx.play("error_004", 0.7, -2.0)


func _caught_choice(id: String) -> void:
	match id:
		"bribe":
			var cost := 20 + int(float(state.attention) * 0.5)
			if int(state.money) >= cost:
				state.money -= cost
				_say("%d cr changed hands. \"Get home. Now.\"" % cost, 5.0)
				for p in patrols:
					p["meter"] = 0.0
				phase = "map"
				return
			_say("Not enough money. They search you.", 4.0)
			_searched()
		"search":
			_searched()


func _searched() -> void:
	var lost: int = Markets.lose_carry(state)
	state.attention = minf(100.0, float(state.attention) + 6.0)
	game.set_meta("op_notes", ["Caught after curfew. They searched you%s and walked you home. The Bureau wrote your name down." % (" and kept the bag (%d things)" % lost if lost > 0 else "")])
	game.goto("res://v2/garage.tscn")


# ------------------------------------------------------------------ the loop

func _physics_process(delta: float) -> void:
	_t += delta
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
	if phase == "map":
		var v := Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v.z -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v.z += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v.x += 1
		var sp := RUN if Input.is_key_pressed(KEY_SHIFT) else SPEED
		if overview:
			sp *= 2.5
		me.velocity = v.normalized() * sp
		me.move_and_slide()
		me.position.y = 0.0
		if v.x != 0.0:
			me_sprite.flip_h = v.x < 0.0
		# a little bob when walking (paper cut-outs hop)
		me_sprite.position.y = absf(sin(_t * 12.0)) * 0.12 if v != Vector3.ZERO else 0.0
		if mode == "walk":
			_tick_patrols(delta)
		near = _nearest_place()
	_place_camera(delta)
	hud.queue_redraw()

func _place_camera(delta: float) -> void:
	var want := 215.0 if overview else 34.0
	cam.size = lerpf(cam.size, want, minf(1.0, delta * 5.0))
	var focus := me.position
	if overview:
		focus = Vector3((L["size"] as Rect2).get_center().x, 0, (L["size"] as Rect2).get_center().y)
	var target := focus + CAM_OFF
	cam.position = cam.position.lerp(target, minf(1.0, delta * 6.0)) if delta < 1.0 else target
	cam.look_at(cam.position - CAM_OFF, Vector3.UP)
	cam.far = 400.0
	cam.far = 400.0


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo():
		return
	match (e as InputEventKey).keycode:
		KEY_E, KEY_ENTER:
			if phase == "map" and not near.is_empty():
				_use(near)
		KEY_G:
			if phase == "map":
				phase = "garrison"
			elif phase == "garrison":
				phase = "map"
		KEY_TAB, KEY_M:
			overview = not overview
		KEY_ESCAPE:
			if phase in ["yard", "garrison"]:
				phase = "map"
			elif mode == "plan":
				_go_home()
			else:
				_say("You're out after curfew. Walk home (HOME, bottom left), or press Esc again to cut through the back alleys (an hour).", 4.0)
				if _msg_t > 3.8 and get_meta("esc_once", false):
					_go_home()
				set_meta("esc_once", true)


# ------------------------------------------------------------------ the HUD

func _say(m: String, t := 4.0) -> void:
	_msg = m
	_msg_t = t


func _hud_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = hud.get_local_mouse_position()
		for b in _btns:
			if (b[0] as Rect2).has_point(mp):
				game.click()
				_button(str(b[1]))
				return


func _button(id: String) -> void:
	if phase == "garrison":
		_garrison_button(id)
		return
	if phase == "caught":
		_caught_choice(id)
		return
	if id == "leave_yard":
		phase = "map"
	elif id.begins_with("buy:"):
		var r := Markets.buy(state, "curfew", int(id.substr(4)))
		_say(r["msg"], 5.0)
		if r.get("sting", false):
			game.sfx.play("error_004", 0.7, -2.0)
			phase = "map"
			for p in patrols:
				p["meter"] = 0.7
		elif r["ok"]:
			game.sfx.play("drop_002", 1.0, -6.0)
		else:
			game.deny()


func _btn(r: Rect2, label: String, id: String, on := true) -> void:
	var mp: Vector2 = hud.get_local_mouse_position()
	hud.draw_rect(r, (Pal.BRASS if on else Pal.METAL).lightened(0.12 if on and r.has_point(mp) else 0.0))
	Pal.text(hud, r.position + Vector2(0, 3), label, 8, Pal.INK if on else Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if on:
		_btns.append([r, id])


func _draw_hud() -> void:
	_btns.clear()
	var s := hud.size
	_draw_labels(s)
	# top left: the night, where you are
	var d := Town.district_at(L, Vector2(me.position.x, me.position.z))
	var top := Rect2(6, 6, 250, 34)
	hud.draw_rect(top, Color(0.05, 0.04, 0.05, 0.85))
	Pal.text(hud, top.position + Vector2(8, 4), "DAY %d   %s   %s" % [int(state.day), state.clock_text(), "OUT AFTER CURFEW" if mode == "walk" else "PLANNING"], 8, Pal.TEXT)
	if not d.is_empty():
		var st := "OURS  %d%%  -  %d holding it" % [int(Town.dstate(state, d["id"])["bar"]), Town.garrison(state, d["id"])] if Town.held(state, d["id"]) else ("HOME" if d["role"] == "home" else ("ON THE FRONT" if Town.on_front(state, d["id"]) else "THEIR GROUND"))
		Pal.text(hud, top.position + Vector2(8, 18), "%s  -  %s" % [d["name"], st], 8, Color.html(str(d["colours"][1])).lightened(0.3))
	Pal.text(hud, Vector2(s.x - 140, 10), "%d cr" % int(state.money), 10, Pal.BRASS, HORIZONTAL_ALIGNMENT_RIGHT, 130)
	# being seen
	if caught_meter > 0.02 and phase == "map":
		var br := Rect2(s.x * 0.5 - 80, 12, 160, 8)
		hud.draw_rect(br, Color(0, 0, 0, 0.6))
		hud.draw_rect(Rect2(br.position, Vector2(br.size.x * caught_meter, br.size.y)), Color(1.0, 0.35, 0.2))
		Pal.text(hud, br.position + Vector2(0, 10), "THEY'VE SEEN SOMETHING", 7, Color(1.0, 0.5, 0.35), HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	# what's here
	if phase == "map" and not near.is_empty():
		var label := ""
		match str(near["kind"]):
			"home":
				label = "E: go home"
			"haunt":
				label = "E: %s" % ("the Tram Yard" if L["haunts"].get(str(near["ref"]), -2) == L.get("yard", -1) and mode == "walk" else "meet them")
			"target":
				var t: Dictionary = near["ref"]
				label = "E: plan the hit on %s" % t["name"]
				if not Town.reachable(state, t):
					label = "%s: behind their lines" % t["name"]
			"citadel":
				label = "The citadel"
			"post":
				label = "E: the garrisons"
		var pr := Rect2(s.x * 0.5 - 150, s.y - 58, 300, 18)
		hud.draw_rect(pr, Color(0.05, 0.04, 0.05, 0.85))
		Pal.text(hud, pr.position + Vector2(0, 4), label, 9, Pal.AMBER, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t)
		var mr := Rect2(s.x * 0.5 - 230, s.y - 92, 460, 28)
		hud.draw_rect(mr, Color(0.05, 0.04, 0.05, 0.85 * a))
		Pal.wrap(hud, mr.position + Vector2(8, 4), _msg, 8, Color(Pal.TEXT, a), mr.size.x - 16, 2)
	Pal.text(hud, Vector2(0, s.y - 16), "WASD walk    Shift run    E use    G garrisons    Tab whole map    Esc %s" % ("home" if mode == "plan" else "cut home"), 7, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if phase == "caught":
		_draw_caught(s)
	elif phase == "garrison":
		_draw_garrisons(s)
	elif phase == "yard":
		_draw_yard(s)


## Names on the map, drawn sharp on the UI layer over the pixel world: districts faint on the ground, places
## in small dark tags above their roofs (the nearest one brighter).
func _draw_labels(s: Vector2) -> void:
	var small := overview
	for d in L["districts"]:
		var rc: Rect2 = d["rect"]
		var p := PixelView.to_ui(hud, cam, cam.unproject_position(Vector3(rc.get_center().x, 0, rc.get_center().y)))
		if p.x < -100 or p.y < -40 or p.x > s.x + 100 or p.y > s.y + 40:
			continue
		var sub := "OURS" if Town.held(state, d["id"]) else ("YOUR HOME" if d["role"] == "home" else ("ON THE FRONT" if Town.on_front(state, d["id"]) else "THEIR GROUND"))
		var col := Color(Color.html(str(d["colours"][1])).lightened(0.35), 0.55)
		Pal.text(hud, p - Vector2(150, 10), str(d["name"]), 16 if small else 22, col, HORIZONTAL_ALIGNMENT_CENTER, 300)
		Pal.text(hud, p + Vector2(-150, 12 if small else 16), sub, 8, col, HORIZONTAL_ALIGNMENT_CENTER, 300)
	for pin in pins:
		if small and pin["kind"] == "target" and not (pin["ref"] as Dictionary).has("key"):
			continue                 # the whole map: only keys, groups, home and the citadel
		var p := PixelView.to_ui(hud, cam, cam.unproject_position(pin["pos"]))
		if p.x < -60 or p.y < -20 or p.x > s.x + 60 or p.y > s.y + 20:
			continue
		var lines: PackedStringArray = str(pin["text"]).split("\n")
		var fs := 7 if small else 8
		var w := 0.0
		for l in lines:
			w = maxf(w, l.length() * fs * 0.62)
		var r := Rect2(p.x - w * 0.5 - 4, p.y - lines.size() * (fs + 2) - 4, w + 8, lines.size() * (fs + 2) + 4)
		var hot: bool = not near.is_empty() and near["pos"] == pin["pos"]
		hud.draw_rect(r, Color(0.04, 0.03, 0.04, 0.92 if hot else 0.75))
		hud.draw_line(Vector2(p.x, r.end.y), p + Vector2(0, 6), Color(pin["col"], 0.6), 1.0)
		for i in lines.size():
			Pal.text(hud, Vector2(r.position.x, r.position.y + 2 + i * (fs + 2)), lines[i], fs, (pin["col"] as Color).lightened(0.2 if hot else 0.0), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_caught(s: Vector2) -> void:
	hud.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
	var r := Rect2(s.x * 0.5 - 170, s.y * 0.5 - 60, 340, 120)
	Pal.plate(hud, r)
	Pal.text(hud, r.position + Vector2(12, 10), "A TORCH IN YOUR FACE", 11, Pal.MULT)
	Pal.wrap(hud, r.position + Vector2(12, 30), "\"Papers. What are you doing out after curfew?\"", 8, Pal.TEXT, r.size.x - 24, 3)
	var cost := 20 + int(float(state.attention) * 0.5)
	_btn(Rect2(r.position.x + 12, r.end.y - 30, 150, 20), "BRIBE  %d cr" % cost, "bribe", int(state.money) >= cost)
	_btn(Rect2(r.end.x - 162, r.end.y - 30, 150, 20), "LET THEM SEARCH", "search")


func _draw_yard(s: Vector2) -> void:
	hud.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.045, 0.9))
	var r := Rect2(20, 50, s.x - 40, s.y - 110)
	Pal.plate(hud, r)
	Pal.tag(hud, r.position + Vector2(12, -8), "THE TRAM YARD", 9)
	var list := Markets.offers(state, "curfew")
	var cw := (r.size.x - 24) / 3.0
	for i in list.size():
		var o: Dictionary = list[i]
		var cr := Rect2(r.position.x + 10 + (i % 3) * (cw + 2), r.position.y + 20 + (i / 3) * 52, cw - 4, 48)
		var sold: bool = o["sold"]
		hud.draw_rect(cr, Color(0.2, 0.15, 0.11) if not sold else Color(0.13, 0.1, 0.08))
		Pal.text(hud, cr.position + Vector2(6, 4), str(o.get("stall", "")), 7, Pal.DIM)
		Pal.text(hud, cr.position + Vector2(6, 15), "%s  x%d" % [o["name"], int(o["qty"])], 8, Pal.TEXT)
		if str(o.get("tell", "")) != "":
			Pal.text(hud, cr.position + Vector2(6, 28), str(o["tell"]), 7, Color(1.0, 0.55, 0.4))
		_btn(Rect2(cr.end.x - 58, cr.end.y - 18, 52, 15), "SOLD" if sold else "%d cr" % int(o["price"]), "buy:%d" % i, not sold and int(state.money) >= int(o["price"]))
	var bag: Array = Markets.carrying(state)
	Pal.text(hud, Vector2(r.position.x + 12, r.end.y - 24), "BAG: " + (", ".join(PackedStringArray(bag.map(func(o) -> String: return "%s x%d" % [o["name"], int(o["qty"])]))) if not bag.is_empty() else "empty"), 8, Pal.TEXT)
	_btn(Rect2(r.end.x - 130, r.end.y - 28, 118, 20), "BACK TO THE STREET", "leave_yard")
