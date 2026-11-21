extends RefCounted
## Renders a scene at a low resolution (window / 3) and scales it up with nearest filtering: the pixel look.

const Pal := preload("res://v2/ui/pal.gd")
const SHRINK := 3


## Builds the pixel viewport under host and returns the Control to build the game in.
static func make(host: Control) -> Control:
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var c := SubViewportContainer.new()
	c.stretch = true
	c.stretch_shrink = SHRINK
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(c)
	var vp := SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	c.add_child(vp)
	var g := Control.new()
	g.theme = Pal.theme()
	g.size = Vector2(533, 300)
	vp.add_child(g)
	vp.size_changed.connect(func() -> void: g.size = Vector2(vp.size))
	return g
