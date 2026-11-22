// The feed look: what a helmet cam or a hacked CCTV camera sees. Barrel (fisheye) distortion, a round
// vignette, grain, a cold tint, then the game's ordered dither and banding. A quad in front of the camera.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float barrel = 0.22;
uniform float round_vignette = 1.0;       // how hard the round black edge is
uniform float grain = 0.06;
uniform vec3 tint = vec3(0.92, 1.0, 1.0);
uniform float mono = 0.0;                 // 1 = CCTV green monochrome
uniform float levels = 16.0;
uniform float dither_amount = 1.0;
uniform float time_s = 0.0;
uniform float hit_flash = 0.0;
uniform float lost = 0.0;                 // 1 = NO SIGNAL (the wearer is dead or the feed was cut)

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 q = vec2(uv.x * aspect, uv.y);
	float r2 = dot(q, q);
	vec2 duv = uv * (1.0 - barrel * 0.5 + barrel * r2);
	vec3 c = texture(screen_tex, duv + 0.5).rgb;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c * tint, vec3(lum) * vec3(0.55, 1.0, 0.6), mono);
	c = mix(vec3(lum), c, 0.86);                                   // a bit washed out, like a cheap sensor
	c += (rnd(FRAGCOORD.xy + time_s * 61.0) - 0.5) * grain;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c = floor(c * levels + 0.5 + b * dither_amount) / levels;
	// round vignette: dark corners like a lens that doesn't cover the sensor
	float rv = smoothstep(0.5, 0.78, length(vec2(uv.x * aspect * 0.62, uv.y)));
	c *= 1.0 - rv * round_vignette;
	c *= 1.0 - r2 * 0.35;
	c = mix(c, vec3(0.9, 0.1, 0.05), hit_flash * 0.4);
	c = mix(c, vec3(rnd(floor(FRAGCOORD.xy / 2.0) + time_s * 13.0) * 0.5), lost);
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
