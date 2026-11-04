shader_type canvas_item;
// A warm pool of lamplight over the table, breathing and flickering slowly,
// with the edges falling into shadow. Drawn over the wood, under the UI.

uniform vec2 center = vec2(0.42, 0.4);
uniform float radius = 0.85;
uniform float darkness = 0.72;
uniform vec4 warmth : source_color = vec4(1.0, 0.62, 0.28, 0.16);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// The flame: a slow breath, a gentle flutter, and a slight sway. Only
	// slow terms: the clock ticks 10 times a second (see effects.gd),
	// so a faster flutter would step visibly.
	float flicker = 0.94 + 0.04 * sin(TIME * 0.9) + 0.035 * (noise(TIME * 2.0) - 0.5);
	vec2 sway = vec2(noise(TIME * 0.7) - 0.5, noise(TIME * 0.5 + 7.0) - 0.5) * 0.015;
	vec2 p = (UV - center - sway) * vec2(aspect, 1.0);
	float d = length(p) / (radius * flicker);
	float light = 1.0 - smoothstep(0.0, 1.0, d);
	float shadow = smoothstep(0.25, 1.1, d) * darkness;
	// Shadow towards the edges, a warm wash in the pool.
	vec3 rgb = mix(vec3(0.0), warmth.rgb, light);
	float a = max(shadow, warmth.a * light * light * flicker);
	COLOR = vec4(rgb, a);
}
