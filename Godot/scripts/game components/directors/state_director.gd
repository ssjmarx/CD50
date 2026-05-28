## updates entity groups for group-as-state management
class_name StateDirector extends CDGameComponent

@export var transitions: Array[CDTransition] = []

var _transitioned: Dictionary = {}  # {CDEntity: bool} per-frame guard
var _update: CDUpdater

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	if game:
		_update = game.update

func initialize() -> void:
	for t in transitions:
		if t.is_valid():
			t.initialize(game)
		else:
			push_warning("StateDirector: skipping invalid transition (empty group names).")

func _physics_process(delta: float) -> void:
	_transitioned.clear()

	# advance cooldowns
	for t in transitions:
		t.advance_cooldown(delta)

	# evaluate and queue
	for t in transitions:
		if not t.is_valid() or t.is_on_cooldown():
			continue

		if t.trigger and t.trigger.evaluate(delta):
			_process_trigger(t)

func _process_trigger(t: CDTransition) -> void:
	# build candidates
	var candidates: Array[CDEntity]

	if t.trigger is CDSignalTrigger:
		candidates = t.trigger.consume_pending()
	else:
		candidates = game.group_registry.get_group(t.from_group)

	# filter: valid, active, not already transitioned, still in from_group
	var filtered: Array[CDEntity] = []
	for entity in candidates:
		if not is_instance_valid(entity):
			continue
		if entity.state != CDEnums.EntityState.ACTIVE:
			continue
		if _transitioned.has(entity):
			continue
		if not entity.is_in_group(t.from_group):
			continue
		filtered.append(entity)

	# selector narrows the pool
	var selected: Array[CDEntity]
	if t.selector:
		selected = t.selector.select(filtered)
	else:
		selected = filtered

	# queue transitions via CDUpdate
	for entity in selected:
		_transitioned[entity] = true
		_update.queue_transition(entity, t.from_group, t.to_group, t.exit_signal_name, t.emit_signal_name)
		t.start_cooldown()

func reset() -> void:
	_transitioned.clear()
	for t in transitions:
		t.reset()
