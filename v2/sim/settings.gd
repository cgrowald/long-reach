extends RefCounted
## Player settings, stored in user://settings_v2.cfg. apply() pushes them into the engine.

const DEFAULTS := {
	"master": 0.8, "music": 0.6, "sfx": 0.8,
	"fullscreen": false, "vsync": true,
	"pixel": 3,               # how chunky the pixels are (2 = fine, 4 = very chunky)
	"sensitivity": 1.0, "fov": 70.0,
	"shake": true, "hints": true,
}

static var path := "user://settings_v2.cfg"
var values := DEFAULTS.duplicate()


func get_v(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_v(key: String, v) -> void:
	values[key] = v


func load_file() -> void:
	var c := ConfigFile.new()
	if c.load(path) != OK:
		return
	for k in DEFAULTS:
		values[k] = c.get_value("settings", k, DEFAULTS[k])


func save_file() -> void:
	var c := ConfigFile.new()
	for k in values:
		c.set_value("settings", k, values[k])
	c.save(path)


func apply() -> void:
	_bus("Master", get_v("master"))
	_bus("Music", get_v("music"))
	_bus("SFX", get_v("sfx"))
	if DisplayServer.get_name() != "headless":
		var fs: bool = get_v("fullscreen")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_v("vsync") else DisplayServer.VSYNC_DISABLED)


static func _bus(name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)
