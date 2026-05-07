// Lightweight CRT shader — barrel distortion, chromatic aberration (3 samples),
// real bloom spread (4 samples), vignette, rolling hum bar, flicker.
// Optional persistence input for vector mode phosphor trails.
// ~7 texture samples per pixel (3 chroma + 4 bloom). Scanlines/noise via PNG overlays.
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// Optional persistence buffer (SubViewport with phosphor decay, vector mode only)
uniform sampler2D persistence_tex;
uniform float persistence_blend : hint_range(0.0, 1.0) = 0.0;

// Base resolution for pixel-grid calculations
uniform vec2 resolution = vec2(640.0, 360.0);

// --- Effect controls ---

// Barrel distortion
uniform float warp_amount : hint_range(0.0, 0.3) = 0.03;

// Chromatic aberration (pixels of offset per channel)
uniform float aberration_amount : hint_range(0.0, 10.0) = 1.5;

// Vignette (exponent — higher = tighter falloff)
uniform float vignette_intensity : hint_range(0.0, 4.0) = 0.8;

// Bloom (4-sample cross spread on bright pixels)
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.8;
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.2;

// Rolling hum bar
uniform float roll_y : hint_range(0.0, 1.0) = 0.0;
uniform float roll_brightness : hint_range(0.0, 0.5) = 0.04;

// Global flicker (brightness oscillation)
uniform float flicker_amount : hint_range(0.0, 0.1) = 0.005;

// Master controls
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 3.0) = 1.1;

// Barrel distortion — UV warp, zero extra samples
vec2 warp(vec2 uv) {
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta, delta);
	float delta4 = delta2 * delta2;
	return uv + delta * delta4 * warp_amount;
}

void fragment() {
	vec2 uv = warp(SCREEN_UV);

	// Clamp to prevent sampling outside screen
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
	// Chromatic aberration — exactly 3 samples (one per channel)
	vec2 chroma_offset = aberration_amount / resolution;
	float r = texture(SCREEN_TEXTURE, uv - chroma_offset).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv + chroma_offset).b;
	vec3 clr = vec3(r, g, b);

	// Blend with persistence buffer (vector mode phosphor trails)
	if (persistence_blend > 0.0) {
		vec3 pers = texture(persistence_tex, uv).rgb;
		clr = mix(clr, pers, persistence_blend);
	}

	// Real bloom — 4-sample cross pattern, spread bright pixels into neighbors
	if (bloom_amount > 0.0) {
		vec2 bloom_px = vec2(2.0) / resolution;
		vec3 bloom = vec3(0.0);
		vec3 s;
		s = texture(SCREEN_TEXTURE, uv + vec2(bloom_px.x, 0.0)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		s = texture(SCREEN_TEXTURE, uv - vec2(bloom_px.x, 0.0)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		s = texture(SCREEN_TEXTURE, uv + vec2(0.0, bloom_px.y)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		s = texture(SCREEN_TEXTURE, uv - vec2(0.0, bloom_px.y)).rgb;
		bloom += max(vec3(0.0), s - bloom_threshold);
		clr += bloom * bloom_amount * 0.25;
	}

	// Vignette — math falloff, follows barrel distortion naturally
	vec2 vuv = uv * (1.0 - uv);
	float vig = vuv.x * vuv.y * 15.0;
	vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);
	clr *= vig;

	// Rolling hum bar — scrolling bright band
	float hum_dist = abs(uv.y - roll_y);
	float hum = smoothstep(0.05, 0.0, hum_dist) * roll_brightness;
	clr += vec3(hum);

	// Global flicker — subtle brightness oscillation
	if (flicker_amount > 0.0) {
		clr *= 1.0 - flicker_amount * sin(TIME * 13.7);
	}

	// Master brightness
	clr *= brightness;

	// Master contrast (S-curve: x^gamma where gamma > 1 increases contrast)
	if (contrast != 1.0) {
		clr = clamp(clr, 0.0, 1.0);
		clr = pow(clr, vec3(1.0 / contrast));
	}

	COLOR = vec4(clr, 1.0);
	} // end else (valid UV)
}