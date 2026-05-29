# CDTransition
# Defines when and how entities move between groups
# Used by Directors to orchestrate entity state changes via trigger → selector → group swap

class_name CDTransition extends Resource

# --- Exports ---

# source group — entities will be removed from here
@export var from_group: StringName = &""

# destination group — entities will be added here
@export var to_group: StringName = &""

# what activates this transition (timer, signal, group count, etc.)
@export var trigger: CDTrigger

# how to pick entities from source group
@export var selector: CDSelector

# seconds between activations (0 = no cooldown)
@export var cooldown: float = 0.0

# signal emitted on entities entering the target group
@export var emit_signal_name: StringName = &""

# signal emitted on entities leaving the source group
@export var exit_signal_name: StringName = &""

# args passed with emit/exit signals
@export var signal_args: Dictionary = {}

# --- Internal State ---

# tracks cooldown progress
var _cooldown_timer: float = 0.0

# --- Lifecycle ---

# reset timer and initialize trigger + selector with game refs
func initialize(game: CDGame) -> void:
	_cooldown_timer = 0.0
	if trigger:
		trigger.initialize(game)
	if selector:
		selector.initialize(game)
	else:
		push_error("CDTransition (%s → %s): no selector assigned." % [from_group, to_group])

# full reset for game restart
func reset() -> void:
	_cooldown_timer = 0.0
	if trigger:
		trigger.reset()
	if selector:
		selector.reset()

# --- Cooldown ---

# tick down the cooldown timer each frame
func advance_cooldown(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

# check if this transition is currently locked
func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0

# begin cooldown after a successful activation
func start_cooldown() -> void:
	if cooldown > 0.0:
		_cooldown_timer = cooldown

# --- Validation ---

# both groups must be set for this transition to be usable
func is_valid() -> bool:
	return from_group != &"" and to_group != &""