## data bag for common enums across the codebase
class_name CDEnums

## CDComponent2D and CDStageComponent2D priority categories
enum ComponentCategory {
	INTENT,       # brains/controllers
	STEERING,     # legs
	ENTITY,       # CDEntity
	INTERACTION,  # arms
	STATE,        # guts
	VISUAL,       # faces/projectors
	AUDIO,        # voices/speakers
	RULES,        # goals, cuecards, trapdoors
}

# func to assign category to a priority inside of a component
static func category_to_priority(category: ComponentCategory) -> int:
	match category:
		ComponentCategory.INTENT:       return 10
		ComponentCategory.STEERING:     return 20
		ComponentCategory.ENTITY:       return 30
		ComponentCategory.INTERACTION:  return 40
		ComponentCategory.STATE:        return 50
		ComponentCategory.VISUAL:       return 60
		ComponentCategory.AUDIO:        return 65
		ComponentCategory.RULES:        return 70
		_: return 70

## CDEntity lifecycle states
enum EntityState {
	ACTIVE,
	DEACTIVATING,
	INACTIVE,
}

## CDGame state machine values
enum GameState {
	ATTRACT,
	PLAYING,
	PAUSED,
	GAME_OVER,
}

## game bus game_over argument
enum GameResult {
	VICTORY,
	DEFEAT,
	DRAW,
}

## CDEntity physics processing type
enum CollisionResponse {
	STOP,
	BOUNCE,
	SLIDE,
}

## comparison operators, used by GroupCountGoal, PointsGoal, others
enum CountComparison {
	LESS_THAN,
	EQUAL_TO,
	GREATER_THAN,
	LESS_OR_EQUAL,
	GREATER_OR_EQUAL,
}

## screen edges for spawners
enum Edge {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

## CDInputRouter input action types
enum InputAction {
	MOVE,
	AIM,
	ACTION_PRESSED,
	ACTION_RELEASED,
}

## patterns for "patrol" AI brains
enum PatrolMode {
	LOOP,
	RETRACE,
	ONCE,
}

## comparison modes for entity comparisons (ie OnJoust arms)
enum EntityCompare {
	VELOCITY,
	Y_POSITION,
	CUSTOM, # define any attribute located on a component
}

## tiebreaker behavior for entity comparisons
enum EntityCompareTiebreaker {
	DONT_FIRE,
	FIRE,
}

## invalid comparison handling for entity comparisons
enum EntityCompareInvalidAction {
	DONT_FIRE,
	FIRE,
}

## CDSoundDef wave shapes
enum WaveShape {
	SINE,
	SQUARE,
	SAWTOOTH,
	TRIANGLE,
	NOISE,
}

## CDSoundDef frequency/amplitude effects
enum Effect {
	NONE,
	WARBLE,
	TREMOLO,
	SWEEP_DOWN,
	DECAY,
}

## MIDI note numbers for sound generation
enum Semitone {
	# Octave 3 (48-59)
	C3 = 48, CS3 = 49, D3 = 50, DS3 = 51, E3 = 52,
	F3 = 53, FS3 = 54, G3 = 55, GS3 = 56, A3 = 57, AS3 = 58, B3 = 59,
	# Octave 4 (60-71)
	C4 = 60, CS4 = 61, D4 = 62, DS4 = 63, E4 = 64,
	F4 = 65, FS4 = 66, G4 = 67, GS4 = 68, A4 = 69, AS4 = 70, B4 = 71,
	# Octave 5 (72-83)
	C5 = 72, CS5 = 73, D5 = 74, DS5 = 75, E5 = 76,
	F5 = 77, FS5 = 78, G5 = 79, GS5 = 80, A5 = 81, AS5 = 82, B5 = 83,
}
