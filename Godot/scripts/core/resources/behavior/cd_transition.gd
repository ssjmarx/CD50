## cd_transition.gd
## Produces: a group-swap transition rule (trigger → selector → group add/remove).
## Consumes: nothing — pure data resource consumed by Directors/StateManager.
class_name CDTransition extends Resource

## groups to remove entities from
@export var remove_groups: Array[StringName] = []

## groups to add entities to
@export var add_groups: Array[StringName] = []

## groups used for filtering candidates (entity must be in ALL of these)
@export var target_groups: Array[StringName] = []

## what activates this transition (timer, signal, group count, etc.)
@export var trigger: CDTrigger

## how to pick entities from source group
@export var selector: CDSelector

## seconds between activations (0 = no cooldown)
@export var cooldown: float = 0.0

## optional wave scaler — overrides cooldown when assigned
@export var wave_scaler: CDWaveScaler

## signals on transition
@export var entity_signals: Array[StringName] = []
@export var game_signals: Array[StringName] = []

## tracks cooldown progress
var _cooldown_timer: float = 0.0

## Reset timer and initialize trigger + selector with game refs.
func initialize(game: CDGame) -> void:
	_cooldown_timer = 0.0
	if wave_scaler:
		wave_scaler.initialize(game)
	if trigger:
		trigger.initialize(game)
	if selector:
		selector.initialize(game)
	else:
		push_warning("CDTransition: no selector assigned.")

## Full reset for game restart.
func reset() -> void:
	_cooldown_timer = 0.0
	if wave_scaler:
		wave_scaler.reset()
	if trigger:
		trigger.reset()
	if selector:
		selector.reset()

## --- Cooldown ---

## Tick down the cooldown timer each frame.
func advance_cooldown(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

## Check if this transition is currently locked.
func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0

## Begin cooldown after a successful activation.
func start_cooldown() -> void:
	var effective_cooldown := cooldown
	if wave_scaler:
		effective_cooldown = wave_scaler.evaluate()
	if effective_cooldown > 0.0:
		_cooldown_timer = effective_cooldown

## At least one remove or add group must be set.
func is_valid() -> bool:
	return not remove_groups.is_empty() or not add_groups.is_empty()