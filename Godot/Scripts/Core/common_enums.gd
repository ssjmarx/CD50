# Shared enumerations for type safety across the codebase

class_name CommonEnums extends RefCounted

# UI element identifiers for Interface component show/hide methods
enum Element {
	WIN_TEXT,       # Victory message display
	LOSE_TEXT,      # Defeat message display
	CONTINUE_TEXT,  # "Press Enter to continue" prompt
	P1_SCORE,       # Player 1 score display
	P2_SCORE,       # Player 2 score display
	ATTRACT_TEXT,   # Game title and instructions
	LIVES,          # Lives counter display
	POINTS,         # Current score display
	MULTIPLIER,     # Score multiplier display
	CONTROL_TEXT     # Control scheme instructions
}

# Game state machine values for UniversalGameScript
enum State {
	ATTRACT,    # Attract mode, waiting for player to start
	PLAYING,    # Active gameplay
	PAUSED,     # Game paused
	GAME_OVER   # Game ended, waiting for restart
}
