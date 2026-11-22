extends SubViewportContainer
## The pixel look: everything (3D world + UI) renders into a low-res SubViewport, scaled up with nearest filtering.
## Add the 3D world to `vp` and UI to `ui`. The pixel size follows the "pixel" setting.

const Kit := preload("res://v2/ui/kit.gd")

var vp: SubViewport
var ui: Control


func _init() -> void:
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.handle_input_locally = true
	add_child(vp)
	ui = Control.new()
	ui.theme = Kit.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(ui)
	vp.size_changed.connect(_fit)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply()
	var g := get_node_or_null("/root/Game")
	if g:
		g.settings_changed.connect(_apply)


func _apply() -> void:
	var g := get_node_or_null("/root/Game")
	stretch_shrink = int(g.settings.get_v("pixel")) if g else 3
	_fit()


func _fit() -> void:
	ui.position = Vector2.ZERO
	ui.size = Vector2(vp.size)
