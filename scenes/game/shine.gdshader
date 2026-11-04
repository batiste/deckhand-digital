// Polished gold: the bright parts of a node (a label's letters, a texture's
// highlights) take a gold gradient, and every few seconds a gleam sweeps
// across them. Works on text too: positions come from the node, not the UV.
shader_type canvas_item;

uniform vec2 size = vec2(100.0); // the node's size, in pixels
uniform float period = 2.4;
uniform float strength = 1.0;
// 1: recolour the bright parts with the gold gradient (text); 0: keep them.
uniform float gild = 1.0;
uniform float phase_override = -1.0; // for tests: a fixed point of the cycle

varying vec2 local;

void vertex() {
	local = VERTEX / size;
}

void fragment() {
	vec4 c = COLOR;
	// The fill, not the dark outline or shadow.
	float bright = smoothstep(0.25, 0.6, max(c.r, c.g));
	// Cream at the top, rich gold through the middle, amber at the foot.
	float y = clamp(local.y, 0.0, 1.0);
	vec3 gold = mix(vec3(1.0, 0.96, 0.74), vec3(1.0, 0.76, 0.26), smoothstep(0.1, 0.55, y));
	gold = mix(gold, vec3(0.78, 0.42, 0.1), smoothstep(0.6, 1.0, y));
	vec3 rgb = mix(c.rgb, gold, bright * gild);
	// The gleam: a thin slanted band, crossing quickly early in each period.
	float phase = phase_override >= 0.0 ? phase_override : fract(TIME / period);
	float pos = phase * 5.0 - 0.4;
	float along = local.x * 0.8 + local.y * 0.35;
	float band = exp(-pow((along - pos) / 0.035, 2.0)) + 0.5 * exp(-pow((along - pos + 0.08) / 0.012, 2.0));
	rgb += vec3(1.0, 0.95, 0.8) * band * (0.2 + 0.8 * bright) * strength;
	COLOR = vec4(rgb, c.a);
}
