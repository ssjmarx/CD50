## CDEnums
## Shared enumerations for the entire V2 codebase
## All component priorities, lifecycle states, and comparison types live here

class_name CDEnums

## --- Component Processing Priority ---

## CDComponent2D and CDStageComponent2D priority categories
enum ComponentCategory {
	REGISTRATION,   # 5  — group cache flush
	INPUT,          # 8  — input routing
	INTENT,         # 10 — brains/controllers
	STEERING,       # 20 — legs
	ENTITY,         # 30 — CDEntity
	COLLISION,      # 35 — collision buffer flush
	INTERACTION,    # 40 — arms
	STATE,          # 50 — guts (internal entity state)
	VISUAL,         # 60 — faces/projectors
	AUDIO,          # 65 — voices/speakers
	RULES,          # 70 — directors, goals, cards, trapdoors
	MANAGER,        # 75 — state, signal, and stage managers
	UPDATE,         # 90 — state mutation flush, component lifecycle
}

## convert a category enum to its numeric priority value
static func category_to_priority(category: ComponentCategory) -> int:
	match category:
		ComponentCategory.REGISTRATION: return 5
		ComponentCategory.INPUT: 		return 8
		ComponentCategory.INTENT:       return 10
		ComponentCategory.STEERING:     return 20
		ComponentCategory.ENTITY:       return 30
		ComponentCategory.COLLISION:	return 35
		ComponentCategory.INTERACTION:  return 40
		ComponentCategory.STATE:        return 50
		ComponentCategory.VISUAL:       return 60
		ComponentCategory.AUDIO:        return 65
		ComponentCategory.RULES:        return 70
		ComponentCategory.MANAGER:      return 75
		ComponentCategory.UPDATE:		return 90
		_: return 95

## --- Entity & Game Lifecycle ---

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

## --- Physics & Collision ---

## CDEntity physics processing type
enum CollisionResponse {
	STOP,
	BOUNCE,
	SLIDE,
}

## screen edges for spawners
enum Edge {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

## --- Logic & Comparison ---

## comparison operators, used by GroupCountGoal, PointsGoal, others
enum CountComparison {
	LESS_THAN,
	EQUAL_TO,
	GREATER_THAN,
	LESS_OR_EQUAL,
	GREATER_OR_EQUAL,
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

## --- Audio / Sound ---

## CDSoundDef wave shapes
enum WaveShape {
	SINE,
	SQUARE,
	SAWTOOTH,
	TRIANGLE,
	NOISE,
	PULSE_25,
	PULSE_12,
	PURE_NOISE,
}

## CDSoundDef frequency/amplitude effects
enum Effect {
	NONE,
	WARBLE,
	TREMOLO,
	SWEEP_DOWN,
	DECAY,
	SWEEP_UP,
	FAST_DECAY,
	WARBLE_WIDE,
	RIPPLE,
	REVERB,
}

## MIDI note numbers for sound generation
enum Semitone {
	## Octave 2 (36-47)
	C2 = 36, CS2 = 37, D2 = 38, DS2 = 39, E2 = 40,
	F2 = 41, FS2 = 42, G2 = 43, GS2 = 44, A2 = 45, AS2 = 46, B2 = 47,
	## Octave 3 (48-59)
	C3 = 48, CS3 = 49, D3 = 50, DS3 = 51, E3 = 52,
	F3 = 53, FS3 = 54, G3 = 55, GS3 = 56, A3 = 57, AS3 = 58, B3 = 59,
	## Octave 4 (60-71)
	C4 = 60, CS4 = 61, D4 = 62, DS4 = 63, E4 = 64,
	F4 = 65, FS4 = 66, G4 = 67, GS4 = 68, A4 = 69, AS4 = 70, B4 = 71,
	## Octave 5 (72-83)
	C5 = 72, CS5 = 73, D5 = 74, DS5 = 75, E5 = 76,
	F5 = 77, FS5 = 78, G5 = 79, GS5 = 80, A5 = 81, AS5 = 82, B5 = 83,
	## Octave 6 (84-95)
	C6 = 84, CS6 = 85, D6 = 86, DS6 = 87, E6 = 88,
	F6 = 89, FS6 = 90, G6 = 91, GS6 = 92, A6 = 93, AS6 = 94, B6 = 95,
}
