// Rounds the corners of a panel's stylebox and draws a thin rim along the edge.
// `size` is the panel size in pixels (set from the panel's resized signal).
shader_type canvas_item;

uniform vec2 size = vec2(100.0);
uniform float radius = 16.0;
uniform float rim_width = 2.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.58, 0.3, 0.7);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 q = abs(local - size * 0.5) - (size * 0.5 - radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR.rgb = mix(COLOR.rgb, rim_color.rgb, rim_color.a * clamp(d + rim_width + 0.5, 0.0, 1.0));
	COLOR.a *= clamp(0.5 - d, 0.0, 1.0);
}
