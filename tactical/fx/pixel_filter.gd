extends CanvasLayer
## Pixel-art look: re-draws the rendered 3D scene in chunky pixels with a reduced
## color palette. Sits between the 3D world and the HUD, so UI text stays crisp.
## Toggle with P.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;
uniform float color_steps = 20.0;
void fragment() {
	vec2 cell = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 uv = (floor(SCREEN_UV / cell) + 0.5) * cell;
	vec3 c = texture(screen_tex, uv).rgb;
	c = floor(c * color_steps + 0.5) / color_steps;
	COLOR = vec4(c, 1.0);
}
"""

@export var pixel_size: float = 3.0
@export var color_steps: float = 20.0

var _rect: ColorRect


func _ready() -> void:
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("pixel_size", pixel_size)
	mat.set_shader_parameter("color_steps", color_steps)
	_rect = ColorRect.new()
	_rect.material = mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_P:
		visible = not visible
