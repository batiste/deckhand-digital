// Rounds the corners of a panel's stylebox and draws a thin rim along the edge.
// `size` is the panel size in pixels (set from the panel's resized signal).
// With `lantern` > 0, a warm light drifts slowly over the wood and the rim
// breathes, as if lit by a swinging lantern (the title menu).
shader_type canvas_item;

uniform vec2 size = vec2(100.0);
uniform float radius = 16.0;
uniform float rim_width = 2.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.58, 0.3, 0.7);
uniform float lantern = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 q = abs(local - size * 0.5) - (size * 0.5 - radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	vec4 rim = rim_color;
	if (lantern > 0.0) {
		// The light swings in a slow loop over the panel, with a faint flicker.
		vec2 spot = size * (vec2(0.5, 0.42) + vec2(0.28 * sin(TIME * 0.31), 0.18 * sin(TIME * 0.47 + 1.3)));
		float reach = max(size.x, size.y) * 0.55;
		float light = exp(-pow(length(local - spot) / reach, 2.0));
		float flicker = 0.93 + 0.05 * sin(TIME * 2.3) + 0.03 * sin(TIME * 7.1 + 0.7);
		COLOR.rgb *= mix(1.0 - 0.22 * lantern, 1.0 + 0.4 * lantern * flicker, light);
		COLOR.rgb += vec3(0.09, 0.05, 0.01) * light * lantern * flicker;
		// The rim brightens where the light falls and breathes slowly.
		rim.rgb *= 1.0 + light * 0.6 * lantern;
		rim.a = min(1.0, rim.a * (0.85 + 0.25 * sin(TIME * 1.1)) + light * 0.3 * lantern);
	}
	COLOR.rgb = mix(COLOR.rgb, rim.rgb, rim.a * clamp(d + rim_width + 0.5, 0.0, 1.0));
	COLOR.a *= clamp(0.5 - d, 0.0, 1.0);
}
