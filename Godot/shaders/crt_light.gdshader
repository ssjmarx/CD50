// CRT post-processing shader for CD50 arcade games
// Applies barrel warp, chromatic aberration, persistence, vignette, bloom, hum bar, flicker
// ~7 texture samples per pixel (3 chroma + 1 persistence + 4 bloom). Scanlines/noise via PNG overlays.

shader_type canvas_item;

// --- inputs ---

// screen capture texture from BackBufferCopy
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// --- persistence (phosphor trails) ---

// SubViewport texture with accumulated phosphor decay
uniform sampler2D persistence_tex;
// blend factor between live image and persistence buffer
uniform float persistence_blend : hint_range(0.0, 1.0) = 0.0;

// --- base resolution ---

// reference resolution for pixel-grid calculations
uniform vec2 resolution = vec2(640.0, 360.0);

// --- barrel distortion ---

// strength of the curved glass UV warp
uniform float warp_amount : hint_range(0.0, 0.3) = 0.03;

// --- chromatic aberration ---

// pixel offset per RGB channel for color fringing
uniform float aberration_amount : hint_range(0.0, 10.0) = 1.5;

// --- vignette ---

// edge darkening exponent (higher = tighter falloff)
uniform float vignette_intensity : hint_range(0.0, 4.0) = 0.8;

// --- bloom ---

// brightness threshold for bloom activation
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.8;
// bloom spread intensity
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.2;

// --- rolling hum bar ---

// vertical position of the bright band (0.0–1.0, animated externally)
uniform float roll_y : hint_range(0.0, 1.0) = 0.0;
// brightness of the scrolling hum band
uniform float roll_brightness : hint_range(0.0, 0.5) = 0.04;

// --- flicker ---

// amplitude of the global brightness oscillation
uniform float flicker_amount : hint_range(0.0, 0.1) = 0.005;

// --- master controls ---

// overall brightness multiplier
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
// CRT phosphor power-curve response (>1.0 brightens midtones)
uniform float gamma : hint_range(0.5, 3.0) = 1.1;

// --- helper functions ---

// barrel distortion: warp UVs outward from center
vec2 warp(vec2 uv) {
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta, delta);
	float delta4 = delta2 * delta2;
	return uv + delta * delta4 * warp_amount;
}

// --- fragment pipeline ---

void fragment() {
	// apply barrel distortion to screen UVs
	vec2 uv = warp(SCREEN_UV);

	// clamp to prevent sampling outside screen bounds
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {

	// --- chromatic aberration (3 texture samples) ---

	// offset each RGB channel slightly apart
	vec2 chroma_offset = aberration_amount / resolution;
	float r = texture(SCREEN_TEXTURE, uv - chroma_offset).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv + chroma_offset).b;
	vec3 clr = vec3(r, g, b);

	// --- persistence blend (1 texture sample) ---

	// overlay phosphor trails from accumulation buffer
	if (persistence_blend > 0.0) {
		vec3 pers = texture(persistence_tex, uv).rgb;
		clr = mix(clr, pers, persistence_blend);
	}

	// --- vignette (computed, no samples) ---

	// parabolic falloff from center, stronger at edges
	vec2 vuv = uv * (1.0 - uv);
	float vig = vuv.x * vuv.y * 15.0;
	vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);

	// --- bloom (4 texture samples, cross pattern) ---

	// asymmetric cross spread on pixels above threshold
	if (bloom_amount > 0.0) {
		vec2 bloom_px = vec2(3.0, 2.0) / resolution;
		vec3 bloom = vec3(0.0);
		vec3 s;
		// right sample
		s = texture(SCREEN_TEXTURE, uv + vec2(bloom_px.x, 0.0)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		// left sample
		s = texture(SCREEN_TEXTURE, uv - vec2(bloom_px.x, 0.0)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		// down sample
		s = texture(SCREEN_TEXTURE, uv + vec2(0.0, bloom_px.y)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		// up sample
		s = texture(SCREEN_TEXTURE, uv - vec2(0.0, bloom_px.y)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		// center-weight bloom by vignette
		clr += bloom * bloom_amount * 0.25 * (0.7 + 0.3 * vig);
	}

	// apply vignette falloff to final color
	clr *= vig;

	// --- rolling hum bar (no samples) ---

	// scrolling bright band across the screen
	float hum_dist = abs(uv.y - roll_y);
	float hum = smoothstep(0.05, 0.0, hum_dist) * roll_brightness;
	clr += vec3(hum);

	// --- global flicker (no samples) ---

	// subtle time-based brightness oscillation
	if (flicker_amount > 0.0) {
		clr *= 1.0 - flicker_amount * sin(TIME * 13.7);
	}

	// --- master controls ---

	// apply brightness multiplier
	clr *= brightness;

	// apply gamma curve (>1.0 lifts midtones for CRT look)
	if (gamma != 1.0) {
		clr = clamp(clr, 0.0, 1.0);
		clr = pow(clr, vec3(1.0 / gamma));
	}

	COLOR = vec4(clr, 1.0);
	} // end else (valid UV)
}