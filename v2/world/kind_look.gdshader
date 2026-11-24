shader_type spatial;
// Surface looks by material kind (v2/world/kind_look.gd): procedural, so no textures are needed.
// kind: 0 plain, 1 wood (grain and plank streaks), 2 fabric (weave and mottling), 3 metal (wear, rust specks),
// 4 paint (chips showing darker under-layer, grime). Pattern runs in the object's own space, so it moves with it.

uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform int kind = 0;
uniform float scale = 1.0;
uniform float seed = 0.0;

varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX * scale + vec3(seed * 13.1, seed * 7.7, seed * 3.3);
	lnrm = NORMAL;
}

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// the face's 2D coordinates: project along the dominant normal axis
vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.x > a.y && a.x > a.z) return p.yz;
	if (a.y > a.z) return p.xz;
	return p.xy;
}

void fragment() {
	vec2 uv = face_uv(lpos, lnrm);
	vec3 col = albedo.rgb;
	float rough = 0.9;
	if (kind == 1) {
		// wood: long grain along the face's first axis, darker streaks and knots
		float g = fbm(vec2(uv.x * 3.0, uv.y * 42.0));
		float streak = smoothstep(0.55, 0.75, fbm(vec2(uv.x * 1.2, uv.y * 9.0)));
		col *= 0.82 + 0.3 * g - 0.18 * streak;
		col = mix(col, col * vec3(0.75, 0.68, 0.6), smoothstep(0.62, 0.8, fbm(uv * 5.0)) * 0.6);
	} else if (kind == 2) {
		// fabric: a fine weave and soft blotches
		vec2 w = uv * 260.0;
		float weave = 0.5 + 0.5 * sin(w.x) * sin(w.y);
		float blot = fbm(uv * 7.0);
		col *= 0.86 + 0.1 * weave + 0.16 * (blot - 0.5);
		rough = 1.0;
	} else if (kind == 3) {
		// metal: brushed wear and rust specks
		float wear = fbm(uv * 14.0);
		float rust = smoothstep(0.62, 0.78, fbm(uv * 22.0 + 4.0));
		col *= 0.8 + 0.35 * wear;
		col = mix(col, vec3(0.15, 0.035, 0.01), rust * 0.55);
		rough = 0.55 + 0.3 * rust;
	} else if (kind == 4) {
		// paint: chips to a darker layer near noise peaks, grime in the low places
		float chip = smoothstep(0.7, 0.74, fbm(uv * 14.0 + 2.0));
		float grime = fbm(uv * 4.0);
		col *= 0.88 + 0.2 * (grime - 0.5);
		col = mix(col, col * 0.62 + vec3(0.06, 0.04, 0.02), chip * 0.8);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = kind == 3 ? 0.35 : 0.0;
}
