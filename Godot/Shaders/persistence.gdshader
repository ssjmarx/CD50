// Persistence buffer shader — accumulates previous frames with exponential decay.
// Runs inside a SubViewport with CLEAR_MODE_NEVER so previous content is retained.
// SCREEN_TEXTURE = previous accumulated frame, game_frame = main viewport output.
// Uses max(prev * decay, game) for physically-motivated phosphor decay.
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D game_frame;
uniform float decay : hint_range(0.0, 1.0) = 0.85;
uniform float enabled : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (enabled < 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Previous accumulated content (SubViewport retains between frames)
		vec3 prev = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
		// Game frame from main viewport
		vec3 game = texture(game_frame, SCREEN_UV).rgb;
		
		// Phosphor decay: keep brightest of faded previous or current
		COLOR = vec4(max(prev * decay, game), 1.0);
	}
}
