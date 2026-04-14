# list of interface elements

class_name CommonEnums extends RefCounted

enum Element {
	WIN_TEXT,
	LOSE_TEXT,
	CONTINUE_TEXT,
	P1_SCORE,
	P2_SCORE,
	ATTRACT_TEXT,
	LIVES,
	POINTS,
	MULTIPLIER
}

enum State {
		ATTRACT,
		PLAYING,
		PAUSED,
		GAME_OVER
}
