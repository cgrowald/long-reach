// Grimy building surfaces for the combat look (reference 03): peeling two-tone paint on plaster,
// water streaks, dirt toward the floor; wet patches on concrete floors. Colours are screen (sRGB) values.
shader_type spatial;

uniform int kind = 0;                       // 0 = painted wall, 1 = concrete floor, 2 = ceiling
uniform vec3 paint = vec3(0.44, 0.43, 0.35);
uniform vec3 band = vec3(0.22, 0.26, 0.24);   // the darker lower band
uniform vec3 under = vec3(0.25, 0.24, 0.22);  // bare plaster / concrete under the paint
uniform float band_h = 1.05;
uniform float peel = 0.53;                  // higher = less peeling

varying vec3 wp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c;
	float rough = 0.92;
	if (kind == 0) {
		float n = fbm(wp * 1.4);
		float pl = smoothstep(peel, peel + 0.03, n);
		vec3 top = mix(paint, under, pl);
		vec3 low = mix(band, under * 0.75, pl * 0.8);
		c = wp.y < band_h ? low : top;
		// a thin dark line where the two paints meet
		c *= 1.0 - (1.0 - smoothstep(0.0, 0.03, abs(wp.y - band_h))) * 0.4;
		// water streaks running down from the ceiling
		float st = fbm(vec3((wp.x + wp.z) * 7.0, wp.y * 0.35, 3.0));
		c *= 1.0 - smoothstep(0.55, 0.75, st) * 0.4 * smoothstep(0.3, 2.6, wp.y);
		// grime toward the floor
		c *= mix(0.55, 1.0, smoothstep(0.0, 0.6, wp.y));
		c *= 0.85 + 0.3 * vnoise(wp * 9.0);
	} else if (kind == 1) {
		float n = fbm(wp * 0.9);
		c = mix(vec3(0.2, 0.2, 0.19), vec3(0.13, 0.13, 0.12), n);
		float wet = smoothstep(0.58, 0.62, fbm(wp * 0.6 + vec3(7.0)));
		c *= 1.0 - wet * 0.35;
		rough = mix(0.9, 0.12, wet);
		c *= 0.85 + 0.3 * vnoise(wp * 12.0);
	} else {
		c = mix(vec3(0.16, 0.16, 0.15), vec3(0.1, 0.1, 0.1), fbm(wp * 1.1));
	}
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = rough;
}
