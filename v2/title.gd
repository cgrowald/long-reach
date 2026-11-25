extends Control
## Title screen: the garage drifting behind a chunky pixel menu.

const Kit := preload("res://v2/ui/kit.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Menus := preload("res://v2/ui/menus.gd")
const PixelView := preload("res://v2/ui/pixel_view.gd")
const GarageWorld := preload("res://v2/world/garage_world.gd")
const SaveStore := preload("res://v2/sim/save_store.gd")
const BuildingGenT := preload("res://v2/sim/building_gen.gd")

var game: Node
var view
var world
var _menu: Control
var _foot: Label
var _t := 0.0


func _ready() -> void:
	game = get_node("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = PixelView.new()
	add_child(view)
	world = GarageWorld.new()
	view.vp.add_child(world)
	world.setup()
	world.title_mode = true
	world.base_fov = 62.0
	_build()


func _build() -> void:
	var ui: Control = view.ui
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.03, 0.72)
	shade.position = Vector2(0, 0)
	shade.size = Vector2(190, 2000)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(22, 40)
	v.custom_minimum_size = Vector2(150, 0)
	_menu.add_child(v)
	var title := Kit.label("UPRISING", Pal.PHOS, 30)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.02, 0.02))
	title.add_theme_constant_override("outline_size", 2)
	v.add_child(title)
	v.add_child(Kit.label("a garage. a laptop.\na country to take back.", Pal.DIM, 9))
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	v.add_child(gap)
	var has_save := SaveStore.latest() != ""
	var cont := Kit.button("Continue", func() -> void: game.continue_game(), game)
	cont.disabled = not has_save
	v.add_child(cont)
	v.add_child(Kit.button("New game", _new_game, game))
	var load_b := Kit.button("Load game", func() -> void: Menus.slots(ui, game, false), game)
	load_b.disabled = not has_save
	v.add_child(load_b)
	v.add_child(Kit.button("Settings", func() -> void: Menus.settings(ui, game), game))
	v.add_child(Kit.button("Combat: depot raid", func() -> void:
		game.set_meta("fight_level", "combat/depot")
		game.goto("res://v2/combat/fight.tscn"), game))
	v.add_child(Kit.button("Combat: Kessel Road (first mission)", func() -> void:
		game.set_meta("fight_level", "combat/kessel_road")
		game.goto("res://v2/combat/plan_screen.tscn"), game))
	v.add_child(Kit.button("Combat: generated building", func() -> void:
		var ts := BuildingGenT.types()
		game.set_meta("fight_level", "gen:%s:%d" % [ts[randi() % ts.size()], randi() % 100000])
		if game.has_meta("fight_plan"):
			game.remove_meta("fight_plan")
		game.goto("res://v2/combat/plan_screen.tscn"), game))
	v.add_child(Kit.button("Combat: roadblock (cover test)", func() -> void:
		game.set_meta("fight_level", "combat/roadblock_test")
		game.goto("res://v2/combat/fight.tscn"), game))
	v.add_child(Kit.button("Combat look test", func() -> void: game.goto("res://v2/combat/look_test.tscn"), game))
	v.add_child(Kit.button("Lockpick toy", func() -> void: _lock_toy(0), game))
	v.add_child(Kit.button("Quit", func() -> void: game.quit_game(), game))
	for b in v.get_children():
		if b is Button:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_foot = Kit.label("debug shell, build 1. placeholder everything.\nF1 in game opens the debug panel.", Pal.DIM.darkened(0.2), 8)
	_menu.add_child(_foot)
	game.ambience.volume_db = -18.0


func _new_game() -> void:
	if SaveStore.exists("auto"):
		Menus.confirm(view.ui, game, "Start a new game? Your autosave will be replaced tonight. Slots 1-3 are kept.",
			func() -> void: game.new_game())
	else:
		game.new_game()


func _process(delta: float) -> void:
	_t += delta
	_foot.position = Vector2(22, view.ui.size.y - 30)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("v2_pause"):
		Menus.back_top(view.ui)


## The lockpicking minigame on its own: four locks, easiest first. Esc / right-click backs out.
func _lock_toy(i: int) -> void:
	var ids := ["padlock", "yard_gate", "shed_door", "office"]
	var lv: Control = load("res://v2/ui/lockpick_view.gd").new()
	lv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.ui.add_child(lv)
	lv.start(ids[i % ids.size()], null, randi())
	lv.grab_focus()
	lv.finished.connect(func(r: String) -> void:
		lv.queue_free()
		if r == "open":
			_lock_toy(i + 1))
