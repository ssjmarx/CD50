# Shared enumerations for type safety across the codebase

class_name CommonEnums extends RefCounted

# UI element identifiers for Interface component show/hide methods
enum Element {
	WIN_TEXT,
	LOSE_TEXT,
	CONTINUE_TEXT,
	P1_SCORE,
	P2_SCORE,
	ATTRACT_TEXT,
	LIVES,
	POINTS,
	MULTIPLIER,
	CONTROL_TEXT
}

# Game state machine values for UniversalGameScript
enum State {
	ATTRACT,
	PLAYING,
	PAUSED,
	GAME_OVER
}
