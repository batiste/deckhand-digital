shader_type canvas_item;
// A soft border that follows the texture's shape (its alpha), outside it.
// The texture is drawn inset by `inset` (of the rect, each side) to leave
// room for the border inside the rect.

uniform vec4 glow_color : source_color = vec4(1.0, 0.1, 0.05, 1.0);
uniform float inset = 0.1;
uniform float radius = 0.096; // the border's width, in texture UV
uniform float icon_alpha = 1.0; // the texture itself (the border stays)

varying vec4 tint; // the node's modulate

void vertex() {
	tint = COLOR;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return textureLod(tex, uv, 0.0).a;
}

void fragment() {
	vec2 uv = (UV - 0.5) / (1.0 - 2.0 * inset) + 0.5;
	vec4 tex = vec4(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		tex = textureLod(TEXTURE, uv, 0.0);
	}
	// Strong close to the shape, fading out towards `radius`.
	float glow = 0.0;
	for (int i = 0; i < 24; i++) {
		float angle = 6.2831853 * float(i) / 24.0;
		vec2 d = vec2(cos(angle), sin(angle)) * radius;
		glow = max(glow, alpha_at(TEXTURE, uv + d * 0.35));
		glow = max(glow, alpha_at(TEXTURE, uv + d * 0.7) * 0.9);
		glow = max(glow, alpha_at(TEXTURE, uv + d) * 0.42);
	}
	// Outside the shape only (a faded icon shows the table, not red, through it).
	float glow_a = glow_color.a * glow * (1.0 - tex.a);
	tex.a *= icon_alpha;
	vec3 rgb = mix(glow_color.rgb, tex.rgb, tex.a);
	float a = tex.a + glow_a * (1.0 - tex.a);
	COLOR = vec4(rgb, a) * tint;
}
