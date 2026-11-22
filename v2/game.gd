extends Node
## Autoload "Game": the running campaign, settings, saves, sound and scene changes with a fade.

const GameState := preload("res://v2/sim/game_state.gd")
const SaveStore := preload("res://v2/sim/save_store.gd")
const Settings := preload("res://v2/sim/settings.gd")
const Sfx := preload("res://v2/ui/sfx.gd")
const Ambience := preload("res://v2/ui/ambience.gd")

const TITLE := "res://v2/title.tscn"
const GARAGE := "res://v2/garage.tscn"

signal settings_changed

var state                      # GameState or null
var settings
var sfx
var ambience
var in_external := false       # true while an old prototype scene is running (F10 comes back)

var _fade: ColorRect
var _layer: CanvasLayer
var _back_label: Label
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = Settings.new()
	settings.load_file()
	settings.apply()
	sfx = Sfx.new()
	add_child(sfx)
	for p in sfx.get_children():
		(p as AudioStreamPlayer).bus = "SFX"
	ambience = Ambience.new()
	add_child(ambience)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_back_label = Label.new()
	_back_label.text = "F10: back to the garage"
	_back_label.position = Vector2(12, 8)
	_back_label.visible = false
	_layer.add_child(_back_label)
	_add_actions()


func _add_actions() -> void:
	var keys := {
		"v2_pause": [KEY_ESCAPE], "v2_debug": [KEY_F1], "v2_state": [KEY_F3],
		"v2_left": [KEY_A, KEY_LEFT, KEY_Q], "v2_right": [KEY_D, KEY_RIGHT, KEY_E],
		"v2_back": [KEY_S, KEY_DOWN, KEY_BACKSPACE], "v2_quicksave": [KEY_F5],
	}
	for a in keys:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)


func _process(delta: float) -> void:
	_fade.size = get_viewport().get_visible_rect().size
	if state != null and not get_tree().paused:
		state.playtime += delta


func _unhandled_input(event: InputEvent) -> void:
	if in_external and event is InputEventKey and event.pressed and event.physical_keycode == KEY_F10:
		get_tree().paused = false
		Engine.time_scale = 1.0
		goto(GARAGE)


# ------------------------------------------------------------------ campaign

func new_game() -> void:
	state = GameState.new_game(randi())
	goto(GARAGE)


func continue_game() -> bool:
	var slot := SaveStore.latest()
	return slot != "" and load_slot(slot)


func load_slot(slot: String) -> bool:
	var d := SaveStore.read_state(slot)
	if d.is_empty():
		return false
	state = GameState.from_dict(d)
	goto(GARAGE)
	return true


func save_slot(slot: String) -> bool:
	if state == null:
		return false
	return SaveStore.write(slot, state.to_dict())


func autosave() -> bool:
	return save_slot("auto")


## How many hours a whole evening has (for the HUD pips).
func day_hours() -> float:
	var w: Dictionary = load("res://v2/sim/content.gd").world()
	return float(w.get("day_end_hour", 26)) - float(w.get("day_start_hour", 18))


func quit_to_title() -> void:
	state = null
	goto(TITLE)


func quit_game() -> void:
	settings.save_file()
	get_tree().quit()


## Runs an old prototype scene (toys, combat) with an F10 way back.
func run_external(scene: String) -> void:
	goto(scene, true)


# ------------------------------------------------------------------ scenes

func goto(scene: String, external := false) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)
	in_external = external
	_back_label.visible = external
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## A quick fade out and in around a callback (sleeping, waking).
func blink(cb: Callable, hold := 0.3) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	await tw.finished
	cb.call()
	await get_tree().create_timer(hold).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.5)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_settings() -> void:
	settings.apply()
	settings.save_file()
	settings_changed.emit()


# ------------------------------------------------------------------ sound shortcuts

func click() -> void:
	sfx.play("click_001", randf_range(0.95, 1.05), -6.0)


func hover() -> void:
	sfx.play("tick_002", randf_range(1.2, 1.35), -16.0, 0.03)


func clunk() -> void:
	sfx.play("switch_002", randf_range(0.75, 0.85), -3.0)


func deny() -> void:
	sfx.play("error_004", 1.0, -8.0)
