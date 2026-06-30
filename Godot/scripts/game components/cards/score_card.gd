## ScoreCard
## Produces: current_score on game.blackboard + changed game bus signals.
## Consumes: game bus add_score/set_score signals.
@tool

class_name ScoreCard extends CDCueCard

## --- exports ---

## score at game start
@export var starting_score: int = 0:
	set(value):
		starting_score = value
		_update_preview()
## multiplier at game start
@export var starting_multiplier: float = 1.0

@export_group("Blackboard Keys")
## key for pending score add delta (int, consumed on trigger)
@export var pending_add_key: StringName = &"pending_score_add"
## key for pending score set value (int, consumed on trigger)
@export var pending_set_key: StringName = &"pending_score_set"
## key for publishing current score to game blackboard
@export var score_key: StringName = &"current_score"
## key for pending multiplier add delta (float, consumed on trigger)
@export var pending_mult_add_key: StringName = &"pending_mult_add"
## key for pending multiplier set value (float, consumed on trigger)
@export var pending_mult_set_key: StringName = &"pending_mult_set"
## key for publishing current multiplier to game blackboard
@export var multiplier_key: StringName = &"current_multiplier"

## game bus signals for score changes
@export_group("Listen Signals")
@export var on_add_score: Array[StringName] = [&"add_score"]
@export var on_set_score: Array[StringName] = [&"set_score"]
## game bus signals for multiplier changes (leave empty to disable)
@export var on_add_multiplier: Array[StringName] = []
@export var on_set_multiplier: Array[StringName] = []

## game bus signals emitted when values change
@export_group("Emit Signals")
@export var on_score_changed: Array[StringName] = [&"score_changed"]
@export var on_multiplier_changed: Array[StringName] = [&"multiplier_changed"]

## --- state ---

## current score value
var current_score: int
## current multiplier applied to add_score
var current_multiplier: float = 1.0

## --- lifecycle ---

## initialize score, multiplier, and display
func _ready() -> void:
	super._ready()
	current_score = starting_score
	current_multiplier = starting_multiplier
	_update_preview()
	_update_label(str(current_score))

## connect all listen signals to the game bus
func _on_initialize() -> void:
	super._on_initialize()
	_publish_tracked(score_key, current_score)
	_publish_tracked(multiplier_key, current_multiplier)
	
	connect_all(on_add_score, _on_add_score)
	connect_all(on_set_score, _on_set_score)
	connect_all(on_add_multiplier, _on_add_multiplier)
	connect_all(on_set_multiplier, _on_set_multiplier)

## --- score handlers ---

## read pending add delta from blackboard, apply multiplier, publish new score
func _on_add_score() -> void:
	var delta: int = _consume_pending(pending_add_key, 1)
	if delta == 0:
		return
	current_score += int(delta * current_multiplier)
	_update_label(str(current_score))
	_publish_tracked(score_key, current_score)
	for sig in on_score_changed:
		game.bus_emit(sig)

## read pending set value from blackboard, set directly (ignores multiplier)
func _on_set_score() -> void:
	var new_score: int = _consume_pending(pending_set_key, current_score)
	current_score = new_score
	_update_label(str(current_score))
	_publish_tracked(score_key, current_score)
	for sig in on_score_changed:
		game.bus_emit(sig)

## --- multiplier handlers ---

## read pending multiplier add delta from blackboard
func _on_add_multiplier() -> void:
	var delta: float = _consume_pending(pending_mult_add_key, 1.0)
	if delta == 0.0:
		return
	current_multiplier += delta
	_publish_tracked(multiplier_key, current_multiplier)
	for sig in on_multiplier_changed:
		game.bus_emit(sig)

## read pending multiplier set value from blackboard
func _on_set_multiplier() -> void:
	var new_mult: float = _consume_pending(pending_mult_set_key, current_multiplier)
	current_multiplier = new_mult
	_publish_tracked(multiplier_key, current_multiplier)
	for sig in on_multiplier_changed:
		game.bus_emit(sig)

## updates the editor preview text based on starting score
func _update_preview() -> void:
	_preview_value = str(starting_score)
	_update_interface()
