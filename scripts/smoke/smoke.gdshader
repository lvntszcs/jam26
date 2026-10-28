shader_type canvas_item;
// Draws a room's smoke: a tileable, animated texture repeated in world space, shown only where
// the room's density grid (this sprite's TEXTURE, one texel per cell) says there is smoke.
// Thin smoke keeps only the texture's thickest parts, so clouds get ragged edges without
// needing dedicated edge tiles.

uniform sampler2D frame_a : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D frame_b : source_color, repeat_enable, filter_linear_mipmap;
// Optional: where thinning smoke breaks up (its alpha). The frames' own most opaque parts
// (e.g. outlines) still survive at least as long as the mask's thickest areas.
uniform sampler2D edge_mask : repeat_enable, filter_linear_mipmap;
uniform bool use_edge_mask = false;
uniform float edge_mask_size = 300.0;
// 0 shows frame_a, 1 shows frame_b.
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform float tile_size = 360.0;
uniform vec2 drift = vec2(0.0);
uniform bool luminance_as_alpha = false;
uniform float edge_breakup : hint_range(0.0, 1.0) = 0.7;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.25;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float density = texture(TEXTURE, UV).r;
	vec2 smoke_uv = (world_position - drift * TIME) / tile_size;
	vec4 smoke = mix(texture(frame_a, smoke_uv), texture(frame_b, smoke_uv), blend);
	float body = luminance_as_alpha ? dot(smoke.rgb, vec3(0.299, 0.587, 0.114)) : smoke.a;
	float coverage = body;
	if (use_edge_mask) {
		coverage = max(body, texture(edge_mask, (world_position - drift * TIME) / edge_mask_size).a);
	}

	// Even fade vs. ragged edge: as density drops, only the areas with the most coverage
	// survive. The threshold runs from above the highest possible coverage (density 0:
	// nothing shows) to below the lowest (density 1: the whole texture shows).
	float threshold = mix(1.0 + edge_softness, -edge_softness, density);
	float ragged = smoothstep(threshold - edge_softness, threshold + edge_softness, coverage);
	float alpha = body * mix(density, ragged, edge_breakup) * opacity * tint.a;

	vec3 color = luminance_as_alpha ? vec3(1.0) : smoke.rgb;
	COLOR = vec4(color * tint.rgb, alpha);
}
