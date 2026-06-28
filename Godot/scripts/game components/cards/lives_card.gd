## LivesCard
## Tracks player lives and displays the count
## Emits zero-arg changed/depleted signals, publishes current_lives to game blackboard

class_name LivesCard extends CDCueCard

## --- exports ---

## number of lives at game start
@export var starting_lives: int = 3

@export_group("Blackboard Keys")
## key for publishing current lives to game blackboard
@export var lives_key: StringName = &"current_lives"

## game bus signals that decrement lives
@export_group("Listen Signals")
@export var on_life_lost: Array[StringName] = [&"life_lost"]
## game bus signals that increment lives
@export var on_life_gained: Array[StringName] = [&"life_gained"]

## game bus signals emitted when lives change or deplete
@export_group("Emit Signals")
@export var on_lives_changed: Array[StringName] = [&"lives_changed"]
@export var on_lives_depleted: Array[StringName] = [&"lives_depleted"]

## --- state ---

## current number of lives remaining
var current_lives: int

## --- lifecycle ---

## initialize lives count, display, and blackboard
func _ready() -> void:
	super._ready()
	current_lives = starting_lives
	_update_label(str(current_lives))

## connect listen signals to the game bus
func _on_initialize() -> void:
	super._on_initialize()
	_publish_tracked(lives_key, current_lives)
	connect_all(on_life_lost, _on_life_lost)
	connect_all(on_life_gained, _on_life_gained)

## --- signal handlers ---

## decrement lives, update display, emit changed/depleted
func _on_life_lost() -> void:
	current_lives -= 1
	_update_label(str(current_lives))
	_publish_tracked(lives_key, current_lives)
	for sig in on_lives_changed:
		game.bus_emit(sig)
	if current_lives <= 0:
		for sig in on_lives_depleted:
			game.bus_emit(sig)

## increment lives, update display, emit changed
func _on_life_gained() -> void:
	current_lives += 1
	_update_label(str(current_lives))
	_publish_tracked(lives_key, current_lives)
	for sig in on_lives_changed:
		game.bus_emit(sig)
