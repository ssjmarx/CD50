## data bag for common enums across the codebase
class_name CDEnums

## CDComponent2D and CDStageComponent2D priority categories
enum ComponentCategory {
	INTENT,       # brains/controllers
	STEERING,     # legs
	ENTITY,       # CDEntity
	INTERACTION,  # arms
	STATE,        # guts
	VISUAL,       # faces/projections
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
