shader_type canvas_item;
// Draws a gas zone procedurally: layered, slowly swirling noise in world space, so neighbouring
// zones line up seamlessly and no texture art is needed. This sprite's TEXTURE is the zone's
// density mask (red channel, 0 to 1). Thin gas keeps only the noise's thickest parts, so it
// breaks into ragged wisps instead of fading evenly.

// Dark body of the gas, and the colour of its brightest wisps.
uniform vec4 color : source_color = vec4(0.59, 0.15, 0.99, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.83, 1.0, 0.16, 1.0);
// How much of the gas is tinted with the highlight colour (0 = none).
uniform float highlight_amount : hint_range(0.0, 1.0) = 0.25;
// Opacity of the thickest gas.
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
// World pixels covered by one large billow.
uniform float noise_scale = 420.0;
// The whole gas slides this way, in world pixels per second.
uniform vec2 drift = vec2(14.0, -8.0);
// How fast the billows change shape.
uniform float swirl_speed = 0.08;
// How strongly the billows curl into each other.
uniform float warp : hint_range(0.0, 3.0) = 1.2;
// 0 = thin gas fades evenly, 1 = it breaks up into ragged wisps.
uniform float edge_breakup : hint_range(0.0, 1.0) = 0.5;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.25;
// Multiplies the mask's density: 1 = full gas, 0 = cleared by a vent.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_position;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal noise, roughly 0 to 1.
float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		total += weight * value_noise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		weight *= 0.5;
	}
	return total / 0.97;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float density = texture(TEXTURE, UV).r * amount;
	vec2 p = (world_position - drift * TIME) / noise_scale;
	float t = TIME * swirl_speed;
	// Domain warping: the noise is sampled at positions pushed around by more noise, which
	// curls the billows into each other.
	vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3) - t));
	float n = fbm(p + warp * q + vec2(1.7, 9.2) + 0.5 * t);
	float coverage = smoothstep(0.2, 0.8, n);

	// As density drops, only the areas with the most coverage survive. The threshold runs from
	// above the highest coverage (density 0: nothing shows) to below the lowest (density 1:
	// everything shows).
	float threshold = mix(1.0 + edge_softness, -edge_softness, density);
	float ragged = smoothstep(threshold - edge_softness, threshold + edge_softness, coverage);
	float body = mix(0.65, 1.0, coverage);
	float alpha = body * mix(density, ragged, edge_breakup) * opacity * color.a;

	float wisp = smoothstep(0.55, 0.9, coverage) * highlight_amount;
	COLOR = vec4(mix(color.rgb, highlight_color.rgb, wisp), alpha);
}
