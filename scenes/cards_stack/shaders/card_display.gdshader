shader_type canvas_item;

uniform vec2 bleed_margin_uv = vec2(0.043478, 0.031915);
uniform vec2 rect_size = vec2(140.0, 200.0);
uniform float corner_radius_px = 16.0;
uniform float content_inset_px = 5.0;
uniform float border_width_px = 1.75;
uniform vec4 border_color: source_color = vec4(0.05, 0.05, 0.07, 0.25);
uniform vec2 shadow_offset_px = vec2(2.0, 3.0);
uniform float shadow_softness_px = 4.0;
uniform float shadow_alpha = 0.26;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - (half_size - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 local = UV * rect_size - (rect_size * 0.5);
	vec2 card_half = (rect_size * 0.5) - vec2(content_inset_px);
	card_half = max(card_half, vec2(1.0));

	float max_radius = min(card_half.x, card_half.y) - 0.5;
	float radius = clamp(corner_radius_px, 0.0, max_radius);
	float sdf = rounded_box_sdf(local, card_half, radius);

	float aa = 1.0;
	float card_mask = 1.0 - smoothstep(0.0, aa, sdf);

	vec2 uv_card = (local + card_half) / (card_half * 2.0);
	vec2 uv = mix(bleed_margin_uv, vec2(1.0) - bleed_margin_uv, uv_card);
	vec4 tex = texture(TEXTURE, uv);

	float inner_mask = 1.0 - smoothstep(0.0, aa, sdf + border_width_px);
	float border_mask = clamp(card_mask - inner_mask, 0.0, 1.0);

	float shadow_sdf = rounded_box_sdf(local - shadow_offset_px, card_half, radius);
	float shadow_mask = 1.0 - smoothstep(0.0, shadow_softness_px, shadow_sdf);
	float visible_shadow = shadow_mask * (1.0 - card_mask) * shadow_alpha;

	vec3 fill_rgb = mix(tex.rgb, border_color.rgb, border_mask * border_color.a);
	float fill_alpha = tex.a * card_mask;

	vec3 rgb = mix(vec3(0.0), fill_rgb, fill_alpha);
	rgb = mix(rgb, vec3(0.0), visible_shadow);
	float alpha = max(fill_alpha, visible_shadow);

	if (alpha <= 0.001) {
		discard;
	}

	COLOR = vec4(rgb, alpha);
}
