## defines when and how entities move between groups.
class_name CDTransition extends Resource

@export var from_group: StringName = &""
@export var to_group: StringName = &""
@export var trigger: CDTrigger
@export var selector: CDSelector
@export var cooldown: float = 0.0
@export var emit_signal_name: StringName = &""
@export var exit_signal_name: StringName = &""
@export var signal_args: Dictionary = {}

var _cooldown_timer: float = 0.0

func initialize(game: CDGame) -> void:
	_cooldown_timer = 0.0
	if trigger:
		trigger.initialize(game)
	if selector:
		selector.initialize(game)
	else:
		push_error("CDTransition (%s → %s): no selector assigned." % [from_group, to_group])

func advance_cooldown(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0

func start_cooldown() -> void:
	if cooldown > 0.0:
		_cooldown_timer = cooldown

func reset() -> void:
	_cooldown_timer = 0.0
	if trigger:
		trigger.reset()
	if selector:
		selector.reset()

func is_valid() -> bool:
	return from_group != &"" and to_group != &""
