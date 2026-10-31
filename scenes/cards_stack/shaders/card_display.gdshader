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
// Burning away (discards): 0 = intact, 1 = gone. Edges char first.
uniform float burn = 0.0;
uniform float burn_seed = 0.0;
// 3D tilt: maps a point of the drawn rect (pixels from its centre, z = 1)
// back onto the card plane. Identity = flat.
uniform mat3 tilt_inverse = mat3(1.0);
// A glint across the card: band position along the diagonal (0..1 crosses
// the card; outside = off) and its strength.
uniform float sheen = -1.0;
uniform float sheen_alpha = 0.0;
// Claimable: a gold light running round the card edge.
uniform float shimmer = 0.0;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - (half_size - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return value_noise(p) * 0.55 + value_noise(p * 2.1) * 0.3 + value_noise(p * 4.3) * 0.15;
}

void fragment() {
	vec2 local = UV * rect_size - (rect_size * 0.5);
	vec3 projected = tilt_inverse * vec3(local, 1.0);
	local = projected.xy / projected.z;
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

	if (sheen_alpha > 0.0) {
		float along = (uv_card.x * 0.8 + (1.0 - uv_card.y)) / 1.8;
		float band = exp(-pow((along - sheen) / 0.09, 2.0)) + 0.35 * exp(-pow((along - sheen + 0.16) / 0.04, 2.0));
		rgb += vec3(1.0, 0.93, 0.78) * band * sheen_alpha * fill_alpha;
	}

	if (shimmer > 0.0) {
		// A rim a few pixels wide, lit by a bright spot travelling round it.
		float rim = smoothstep(-7.0, -2.5, sdf) * card_mask;
		float angle = atan(local.y * card_half.x / card_half.y, local.x);
		float spot = pow(0.5 + 0.5 * cos(angle - TIME * 1.6), 14.0) + 0.6 * pow(0.5 + 0.5 * cos(angle - TIME * 1.6 + 3.14159), 20.0);
		vec3 gold = vec3(1.0, 0.78, 0.32);
		rgb = mix(rgb, gold * (0.75 + 1.1 * spot), rim * shimmer * (0.55 + 0.45 * spot));
	}

	if (burn > 0.0) {
		// 0 on the card edge, 1 in the middle, roughened by noise.
		float depth = clamp(-sdf / min(card_half.x, card_half.y), 0.0, 1.0);
		float field = depth * 0.55 + fbm(uv_card * vec2(5.0, 7.0) + burn_seed) * 0.45;
		float front = burn * 1.15 - 0.05;
		float edge = (field - front) / 0.07;
		if (edge < 0.0) {
			discard;
		}
		// A glowing ember line, then a band of char, then the card.
		vec3 ember = mix(vec3(1.0, 0.85, 0.4), vec3(0.95, 0.35, 0.05), clamp(edge * 2.0, 0.0, 1.0));
		vec3 charred = vec3(0.12, 0.06, 0.03);
		rgb = mix(ember * 1.4, charred, smoothstep(0.0, 0.6, edge));
		rgb = mix(rgb, fill_rgb * fill_alpha, smoothstep(0.6, 1.8, edge));
		alpha = fill_alpha;
	}

	if (alpha <= 0.001) {
		discard;
	}

	COLOR = vec4(rgb, alpha);
}
