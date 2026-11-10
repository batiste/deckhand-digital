shader_type canvas_item;
// A warm pool of lamplight over the table, with the edges falling into
// shadow. Drawn over the wood, under the UI. Static: no TIME, so it costs
// nothing while the table is idle.

uniform vec2 center = vec2(0.42, 0.4);
uniform float radius = 0.85;
uniform float darkness = 0.72;
uniform vec4 warmth : source_color = vec4(1.0, 0.62, 0.28, 0.16);

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float d = length(p) / radius;
	float light = 1.0 - smoothstep(0.0, 1.0, d);
	float shadow = smoothstep(0.25, 1.1, d) * darkness;
	// Shadow towards the edges, a warm wash in the pool.
	vec3 rgb = mix(vec3(0.0), warmth.rgb, light);
	float a = max(shadow, warmth.a * light * light);
	COLOR = vec4(rgb, a);
}
