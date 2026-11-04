// Rays of golden light turning slowly behind the winner's seal, fading out
// towards the edges of the rect.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float count = 14.0;
uniform float speed = 0.12;
uniform float strength = 0.55;

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float a = atan(d.y, d.x);
	// Two sets of rays turning at different speeds, so they shimmer.
	float rays = pow(abs(sin(a * count * 0.5 + TIME * speed)), 6.0);
	rays += 0.6 * pow(abs(sin(a * count * 0.5 * 1.5 - TIME * speed * 1.7)), 10.0);
	float fade = smoothstep(1.0, 0.25, r);
	float core = exp(-r * r * 6.0) * 0.6;
	COLOR = vec4(tint.rgb, clamp((rays * 0.5 * fade + core) * strength, 0.0, 1.0));
}
