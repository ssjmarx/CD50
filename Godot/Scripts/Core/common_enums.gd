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

# Score types for Goal and PointsMonitor components
enum ScoreType {
	P1_SCORE,
	P2_SCORE,
	GENERIC_SCORE
}

# WaveDirector trigger types
enum Trigger {
	GROUP_CLEARED,
	TIMER_EXPIRED,
	LIVES_DEPLETED
}

# WaveSpawner spawn patterns
enum SpawnPattern {
	SCREEN_EDGES,
	SCREEN_CENTER,
	GRID
}

# VariableTuner adjustment modes
enum AdjustmentMode {
	ADD,
	MULTIPLY,
	SET
}

# PointsMonitor comparison conditions
enum Condition {
	GREATER_OR_EQUAL,
	LESS_OR_EQUAL
}

# PointsMonitor result types
enum Result {
	VICTORY,
	DEFEAT
}

# swap between UIs
enum DisplayMode {
	P1_P2_SCORE,
	POINTS_MULTIPLIER
}
