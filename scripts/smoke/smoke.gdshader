shader_type canvas_item;
// Draws a room's smoke: a tileable, animated texture repeated in world space, shown only where
// the room's density grid (this sprite's TEXTURE, one texel per cell) says there is smoke.
// Thin smoke keeps only the texture's thickest parts, so clouds get ragged edges without
// needing dedicated edge tiles.

uniform sampler2D frame_a : source_color, repeat_enable, filter_linear;
uniform sampler2D frame_b : source_color, repeat_enable, filter_linear;
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
	float thickness = luminance_as_alpha ? dot(smoke.rgb, vec3(0.299, 0.587, 0.114)) : smoke.a;

	// Even fade vs. ragged edge: as density drops, only the texture's thicker areas survive.
	// The threshold runs from above the thickest possible value (density 0: nothing shows)
	// to below the thinnest (density 1: the whole texture shows).
	float fade = thickness * density;
	float threshold = mix(1.0 + edge_softness, -edge_softness, density);
	float ragged = thickness * smoothstep(threshold - edge_softness, threshold + edge_softness, thickness);
	float alpha = mix(fade, ragged, edge_breakup) * opacity * tint.a;

	vec3 color = luminance_as_alpha ? vec3(1.0) : smoke.rgb;
	COLOR = vec4(color * tint.rgb, alpha);
}
