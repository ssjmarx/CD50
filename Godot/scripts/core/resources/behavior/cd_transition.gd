# CDTransition
# Defines when and how entities move between groups
# Used by Directors to orchestrate entity state changes via trigger → selector → group swap
# remove_groups: entities are removed from each group listed
# add_groups: entities are added to each group listed
# target_groups: used for filtering candidates (entity must be in ALL target groups)

class_name CDTransition extends Resource

# --- Exports ---

# groups to remove entities from
@export var remove_groups: Array[StringName] = []

# groups to add entities to
@export var add_groups: Array[StringName] = []

# groups used for filtering candidates (entity must be in ALL of these)
@export var target_groups: Array[StringName] = []

# what activates this transition (timer, signal, group count, etc.)
@export var trigger: CDTrigger

# how to pick entities from source group
@export var selector: CDSelector

# seconds between activations (0 = no cooldown)
@export var cooldown: float = 0.0

# entity signals emitted when entering new groups
@export var emit_signals: Array[StringName] = []

# entity signals emitted when leaving old groups
@export var exit_signals: Array[StringName] = []

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
		push_warning("CDTransition: no selector assigned.")

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

# at least one remove or add group must be set
func is_valid() -> bool:
	return not remove_groups.is_empty() or not add_groups.is_empty()