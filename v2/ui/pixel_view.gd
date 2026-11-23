extends Control
## The pixel look, split in two layers:
## - `vp`: the 3D world, rendered low-res and scaled up with nearest filtering (the "pixel" setting).
## - `ui`: every screen and all text, laid out in the same small units as before (window / UI_SCALE)
##   but rendered at full window resolution, so text is sharp and readable (user, 2026-11-22).
## Add the 3D world to `vp` and UI to `ui`. All input goes to `ui`; 3D picking is done from UI events.

const Kit := preload("res://v2/ui/kit.gd")

const UI_SCALE := 2.5     # one UI unit = 2.5 window pixels (text about 22 px tall at the usual size 9)

var vp: SubViewport
var ui: Control
var ui_vp: SubViewport
var _world_box: SubViewportContainer
var _ui_box: SubViewportContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_box = SubViewportContainer.new()
	_world_box.stretch = true
	_world_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world_box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	_world_box.add_child(vp)

	_ui_box = SubViewportContainer.new()
	_ui_box.stretch = true
	_ui_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ui_box)
	ui_vp = SubViewport.new()
	ui_vp.transparent_bg = true
	ui_vp.handle_input_locally = true
	ui_vp.size_2d_override_stretch = true
	# pixel-art icons and textures stay chunky; glyphs are drawn at full size so this doesn't blur them
	ui_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	ui_vp.oversampling = true
	_ui_box.add_child(ui_vp)
	ui = Control.new()
	ui.theme = Kit.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_vp.add_child(ui)
	ui_vp.size_changed.connect(_fit)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	_apply()
	var g := get_node_or_null("/root/Game")
	if g:
		g.settings_changed.connect(_apply)


func _apply() -> void:
	var g := get_node_or_null("/root/Game")
	_world_box.stretch_shrink = int(g.settings.get_v("pixel")) if g else 3
	_fit()


## UI and 3D use different units now (UI_SCALE vs the pixel setting). Convert a point on a UI node
## (full-rect at the origin) to the 3D camera's viewport, for project_ray_*.
static func to_3d(ui_node: CanvasItem, cam: Camera3D, p: Vector2) -> Vector2:
	return p * cam.get_viewport().get_visible_rect().size / ui_node.get_viewport().get_visible_rect().size


## And back: a camera's unproject_position result to UI units on `ui_node`.
static func to_ui(ui_node: CanvasItem, cam: Camera3D, p: Vector2) -> Vector2:
	return p * ui_node.get_viewport().get_visible_rect().size / cam.get_viewport().get_visible_rect().size


func _fit() -> void:
	var logical := (Vector2(ui_vp.size) / UI_SCALE).floor()
	ui_vp.size_2d_override = Vector2i(logical)
	ui.position = Vector2.ZERO
	ui.size = logical
