// Full-screen post pass for the 3D view: ordered (Bayer) dithering and colour banding, a bruise-purple
// lift in the shadows, and a vignette. Drawn on a quad in front of the camera, before the UI.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 14.0;
uniform float dither_amount = 1.0;
uniform vec3 shadow_tint = vec3(0.10, 0.05, 0.12);
uniform float vignette = 0.55;
uniform float flash = 0.0;          // red flash for alarms
uniform float darken = 0.0;         // dims the world behind menus

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	vec3 c = pow(max(texture(screen_tex, SCREEN_UV).rgb, vec3(0.0)), vec3(1.0 / 2.2));  // band in screen space
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c += shadow_tint * (1.0 - smoothstep(0.0, 0.35, lum)) * 0.6;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c = floor(c * levels + 0.5 + b * dither_amount) / levels;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 2.0;
	c = mix(c, vec3(0.9, 0.05, 0.03), flash * 0.35);
	c *= 1.0 - darken;
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
