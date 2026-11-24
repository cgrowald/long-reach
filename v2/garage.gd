extends Control
## The main game scene: the garage hub. Sit in the chair, turn between the four walls (A / D),
## hover and click a station to lean in, Esc to lean back or pause. The day runs on hours.

const Kit := preload("res://v2/ui/kit.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Menus := preload("res://v2/ui/menus.gd")
const Overlays := preload("res://v2/ui/overlays.gd")
const PixelView := preload("res://v2/ui/pixel_view.gd")
const GarageWorld := preload("res://v2/world/garage_world.gd")
const Hud := preload("res://v2/ui/hud.gd")
const Hands := preload("res://v2/ui/hands.gd")
const DebugPanel := preload("res://v2/ui/debug_panel.gd")
const TonightBoard := preload("res://v2/ui/tonight_board.gd")
const Tonight := preload("res://v2/sim/tonight.gd")
const GameState := preload("res://v2/sim/game_state.gd")
const Content := preload("res://v2/sim/content.gd")

const SCREENS := {
	"pc": preload("res://v2/stations/pc.gd"), "box": preload("res://v2/stations/box.gd"),
	"phone": preload("res://v2/stations/phone.gd"), "bench": preload("res://v2/stations/bench.gd"),
	"corkboard": preload("res://v2/stations/corkboard.gd"), "clipboard": preload("res://v2/stations/clipboard.gd"),
	"warroom": preload("res://v2/stations/warroom.gd"), "outside": preload("res://v2/stations/outside.gd"),
	"sleep": preload("res://v2/stations/sleep.gd"), "stash": preload("res://v2/stations/stash.gd"),
	"cage": preload("res://v2/stations/cage.gd"),
	"interrogation": preload("res://v2/stations/interrogation.gd"),
}

var game: Node
var view
var world
var hud
var hands
var debug_panel
var board                        # the TONIGHT board (v2/ui/tonight_board.gd): what's next, click to go
var screen: Control            # the open station screen, or null
var _catcher: Control
var _stations_layer: Control
var _overlay_layer: Control
var _pending := ""             # station id waiting for the lean to finish
var _alarm := false
var _t := 0.0


func _ready() -> void:
	game = get_node("/root/Game")
	if game.state == null:     # running this scene directly from the editor
		game.state = GameState.new_game(randi())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = PixelView.new()
	add_child(view)
	world = GarageWorld.new()
	view.vp.add_child(world)
	world.setup()
	world.lean_finished.connect(_on_lean_finished)
	world.set_prefix_visible("Bench_Gun_Tarp", false)    # the gun bench is open now
	world.set_prefix_visible("Rig_Slot", false)          # the box gets its own slots (v2/stations/box.gd)
	world.set_prefix_visible("Rig_Cartridge", false)
	var ui: Control = view.ui
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	ui.add_child(_catcher)
	hands = Hands.new()
	ui.add_child(hands)
	hud = Hud.new()
	hud.game = game
	ui.add_child(hud)
	board = TonightBoard.new()
	board.game = game
	ui.add_child(board)
	board.position = Vector2(4, 40)
	board.go.connect(func(id: String) -> void:
		if screen == null:
			open_station(id))
	_stations_layer = Control.new()
	_stations_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stations_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_stations_layer)
	debug_panel = DebugPanel.new()
	ui.add_child(debug_panel)
	debug_panel.setup(self)
	debug_panel.visible = false
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_overlay_layer)
	game.settings_changed.connect(_apply_settings)
	_apply_settings()
	game.ambience.volume_db = -12.0
	if game.has_meta("op_notes"):
		var notes: Array = game.get_meta("op_notes")
		game.remove_meta("op_notes")
		var txt := "You're back. The night is gone.
" + "
".join(PackedStringArray(notes))
		var after := func() -> void:
			if game.state.flags.has("prisoner"):
				open_station("prisoner")
		Menus.message.call_deferred(_overlay_layer, game, txt, after, "AFTER THE OP")
	refresh()
	if not game.state.morning_seen:
		Overlays.day_card(_overlay_layer, game, func() -> void: game.state.morning_seen = true)


func _apply_settings() -> void:
	world.base_fov = float(game.settings.get_v("fov"))
	world.look_sensitivity = float(game.settings.get_v("sensitivity"))
	hud.show_hints = bool(game.settings.get_v("hints"))


# ------------------------------------------------------------------ state shortcuts

func refresh() -> void:
	if board:
		board.refresh()
		board.visible = screen == null
	var n: int = world.facing_count()
	hud.compact = screen != null
	hud.facing_text = "" if screen else world.facing_name()
	hud.left_text = world.facing_name(world.facing - 1)
	hud.right_text = world.facing_name(world.facing + 1)
	if screen:
		hud.hint_line = "Esc or right-click: lean back"
	elif game.state.hours_left() <= 0.01:
		hud.hint_line = "It's late. Go inside and sleep (house door)."
	else:
		hud.hint_line = "Click things. Esc: pause. F1: debug."


func toast(s: String) -> void:
	hud.toast(s)


func shake(amount: float) -> void:
	if game.settings.get_v("shake"):
		world.shake(amount)


## Spend hours on an action. Says no (and why) if there isn't enough night left.
func spend(hours: float) -> bool:
	if hours <= 0.0:
		return true
	if not game.state.can_spend(hours):
		game.deny()
		toast("No night actions left. Small things are still free; go to bed when you're done.")
		return false
	game.state.spend(hours)
	refresh()
	return true


func _overlay_open() -> bool:
	for c in _overlay_layer.get_children():
		if not c.is_queued_for_deletion():
			return true
	return false


# ------------------------------------------------------------------ input

func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		world.set_cursor(event.position, _catcher.size)
		if screen == null and not world.is_moving():
			_hover(world.pick(PixelView.to_3d(_catcher, world.camera, event.position)))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and screen == null and world.hovered != "":
			hands.reach(event.position)
			open_station(world.hovered)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_back()


func _hover(id: String) -> void:
	if id != world.hovered and id != "":
		game.hover()
	world.set_hover(id)
	if id == "":
		hud.hover_title = ""
		return
	var s := Content.station(id)
	hud.hover_title = s.get("name", id)
	hud.hover_hint = s.get("hint", "")
	hud.hover_sign = Tonight.signs(game.state, id)
	if not game.state.is_unlocked(s):
		hud.hover_cost = "LOCKED"
	elif float(s.get("hours", 0.0)) > 0.0:
		hud.hover_cost = "%sh" % str(s["hours"])
	else:
		hud.hover_cost = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("v2_debug"):
		debug_panel.visible = not debug_panel.visible
		game.click()
	elif event.is_action_pressed("v2_quicksave"):
		quicksave()
	elif event.is_action_pressed("v2_pause"):
		_back(true)
	elif _overlay_open():
		return
	elif event.is_action_pressed("v2_back") and screen:
		_back()
	elif screen == null and not world.is_moving():
		if event.is_action_pressed("v2_left"):
			_turn(-1)
		elif event.is_action_pressed("v2_right"):
			_turn(1)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_P and game.state.flags.has("prisoner"):
			open_station("prisoner")


func _turn(dir: int) -> void:
	world.turn(dir)
	_hover("")
	game.sfx.play("tick_004", 0.6, -14.0)
	refresh()


## Esc / right-click: close the top overlay, then the station's inner window, then the station, then pause.
func _back(from_esc := false) -> void:
	if Menus.back_top(_overlay_layer):
		return
	if screen:
		if screen.has_method("back") and screen.back():
			return
		close_station()
		return
	if from_esc:
		Overlays.pause(_overlay_layer, game, self)


# ------------------------------------------------------------------ stations

func open_station(id: String) -> void:
	var s := Content.station(id)
	if s.is_empty():
		return
	var f: int = world.station_facing(id)
	if f != world.facing:
		world.set_facing(f)
	_hover("")
	hands.set_shown(false)
	world.lean(id)
	_pending = id
	game.sfx.play("tick_004", 0.5, -10.0)
	hud.facing_text = ""


func _on_lean_finished() -> void:
	if _pending == "":
		return
	var id := _pending
	_pending = ""
	_show_screen(Content.station(id))


func _show_screen(s: Dictionary) -> void:
	if screen:
		screen.queue_free()
	var script: Script = SCREENS.get(s.get("screen", ""))
	if script == null:
		return
	screen = script.new()
	_stations_layer.add_child(screen)
	screen.size = _stations_layer.size
	screen.setup(self, s)
	refresh()


## Open a screen without leaning (e.g. the war room from the PC).
func open_screen(screen_id: String) -> void:
	for s in Content.stations().get("stations", []):
		if s.get("screen", "") == screen_id:
			_show_screen(s)
			return


func close_station() -> void:
	if screen:
		screen.queue_free()
		screen = null
	_pending = ""
	world.unlean()
	hands.set_shown(true)
	game.sfx.play("close_001", 0.8, -12.0)
	refresh()


# ------------------------------------------------------------------ the day

func sleep() -> void:
	if screen:
		screen.queue_free()
		screen = null
	world.unlean()
	hands.set_shown(true)
	var lines: Array = []
	var saved := [false]
	game.blink(func() -> void:
		lines.append_array(game.state.end_day())
		saved[0] = game.autosave()
		refresh(), 0.4)
	await get_tree().create_timer(0.45).timeout
	game.sfx.play("close_001", 0.5, -6.0)
	Overlays.ledger(_overlay_layer, game, lines, saved[0], func() -> void:
		Overlays.day_card(_overlay_layer, game, func() -> void: game.state.morning_seen = true))


func quicksave() -> void:
	var ok: bool = game.save_slot("auto")
	toast("Quicksaved." if ok else "Quicksave failed.")
	game.sfx.play("confirmation_002" if ok else "error_004", 1.0, -8.0)


func raid() -> void:
	if screen:
		close_station()
	Overlays.raid(_overlay_layer, game, self)


func arrest(reason: String) -> void:
	if screen:
		close_station()
	set_alarm(false)
	Overlays.game_over(_overlay_layer, game, reason)


func set_alarm(on: bool) -> void:
	_alarm = on
	if not on:
		world.set_flash(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _alarm:
		world.set_flash(0.5 + 0.5 * sin(_t * 9.0))
	world.set_darken(0.35 if _overlay_open() else 0.0)
	hud.visible = not _overlay_open() or debug_panel.visible
	if world.hovered != "":
		hud.hover_pos = PixelView.to_ui(hud, world.camera, world.station_screen_pos(world.hovered))
