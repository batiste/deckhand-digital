// The title logo: it rides gently as if afloat, and every few seconds a gleam
// runs across the gold lettering, striking little stars of light as it goes.
shader_type canvas_item;

uniform float period = 5.5;
uniform float bob_px = 3.0;
// Where the stars twinkle (UV on the logo); width / height of the logo.
uniform vec2 star_a = vec2(0.125, 0.2); // the D's top serif
uniform vec2 star_b = vec2(0.508, 0.19); // the top of the tall H
uniform vec2 star_c = vec2(0.745, 0.6); // the Y of INFAMY
uniform float aspect = 2.118;
uniform float phase_override = -1.0; // for tests: a fixed point of the cycle

// A four-pointed star of light centred on `at`, `size` in logo heights.
float star(vec2 uv, vec2 at, float size, float spin) {
	vec2 d = (uv - at) * vec2(aspect, 1.0) / size;
	float c = cos(spin), s = sin(spin);
	d = vec2(c * d.x - s * d.y, s * d.x + c * d.y);
	float rays = exp(-abs(d.x) * 2.2) * exp(-abs(d.y) * 38.0) + exp(-abs(d.y) * 2.2) * exp(-abs(d.x) * 38.0);
	// Thinner diagonal rays and a soft core.
	vec2 e = vec2(d.x + d.y, d.y - d.x) * 0.7071;
	rays += 0.35 * (exp(-abs(e.x) * 4.0) * exp(-abs(e.y) * 50.0) + exp(-abs(e.y) * 4.0) * exp(-abs(e.x) * 50.0));
	return rays + exp(-dot(d, d) * 18.0) * 0.8;
}

void vertex() {
	// A slow swell, slightly different on each side so the sign rocks.
	VERTEX.y += sin(TIME * 1.1) * bob_px + sin(TIME * 0.7 + VERTEX.x * 0.006) * bob_px * 0.8;
}

void fragment() {
	// COLOR already holds the texture (times the node's modulate).
	vec4 tex = COLOR;
	float phase = phase_override >= 0.0 ? phase_override : fract(TIME / period);
	// The gleam crosses during the first third of each period, then rests.
	float pos = phase * 3.0 - 0.4;
	float along = UV.x * 0.75 + UV.y * 0.25;
	float band = exp(-pow((along - pos) / 0.05, 2.0)) + 0.4 * exp(-pow((along - pos + 0.09) / 0.02, 2.0));
	// Mostly on the gold: bright, warm pixels.
	float gold = smoothstep(0.45, 0.85, max(tex.r, tex.g)) * step(tex.b + 0.08, tex.r);
	vec3 rgb = tex.rgb + vec3(1.0, 0.9, 0.65) * band * (0.15 + 0.7 * gold);
	// Each star flares as the gleam reaches its point, turning a little.
	float sparkle = 0.0;
	vec2 spots[3] = vec2[3](star_a, star_b, star_c);
	for (int i = 0; i < 3; i++) {
		float reach = exp(-pow((spots[i].x * 0.75 + spots[i].y * 0.25 - pos) / 0.035, 2.0));
		if (reach > 0.01) {
			sparkle += star(UV, spots[i], 0.2 + 0.08 * reach, pos * 2.0 + float(i)) * reach;
		}
	}
	sparkle = clamp(sparkle, 0.0, 1.5);
	rgb = mix(rgb, vec3(1.0, 0.97, 0.88), clamp(sparkle, 0.0, 1.0) * (1.0 - tex.a * 0.3));
	COLOR = vec4(rgb, max(tex.a, clamp(sparkle, 0.0, 1.0)));
}
