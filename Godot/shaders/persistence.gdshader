// Persistence buffer shader for CD50 CRT phosphor trails
// Accumulates previous frames with exponential decay in a CLEAR_MODE_NEVER SubViewport
// Uses max(prev * decay, game) for physically-motivated phosphor persistence

shader_type canvas_item;

// --- inputs ---

// previous accumulated frame (SubViewport retains between frames)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
// current game frame from main viewport
uniform sampler2D game_frame;
// phosphor fade rate per frame (higher = longer trails)
uniform float decay : hint_range(0.0, 1.0) = 0.85;

// --- fragment ---

void fragment() {
	// read previous accumulated content (retained by SubViewport)
	vec3 prev = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	// read current game render from main viewport
	vec3 game = texture(game_frame, SCREEN_UV).rgb;
	
	// phosphor decay: keep brightest of faded previous or current frame
	// ensures current frame always shows through at full brightness
	COLOR = vec4(max(prev * decay, game), 1.0);
}