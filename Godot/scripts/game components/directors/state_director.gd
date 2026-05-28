## manages group transitions for a swarm
class_name StateDirector extends CDGameComponent

@export var transitions: Array[CDTransition] = []

var _transitioned: Dictionary = {}  # {CDEntity.rid: bool}
var _snapshots: Dictionary = {}  # {StringName: Array[CDEntity]}
var _dirty_groups: Dictionary = {}  # {StringName: bool}

# group as state must be set before other directors run
func _ready() -> void:
	super._ready()
	process_physics_priority = 65

# duplicate all transitions to prevent shared-reference bugs
func _on_initialize() -> void:
	var duplicated: Array[CDTransition] = []
	for t in transitions:
		duplicated.append(t.duplicate())
	transitions = duplicated

	for t in transitions:
		if not t.is_valid():
			push_error("SwarmStateDirector: transition '%s → %s' has empty from_group or to_group." % [t.from_group, t.to_group])
		if t.trigger == null:
			push_error("SwarmStateDirector: transition '%s → %s' has no trigger." % [t.from_group, t.to_group])
		t.initialize(game)

func _physics_process(delta: float) -> void:
	_transitioned.clear()
	_snapshots.clear()
	_dirty_groups.clear()

	for t in transitions:
		if t.is_valid() and not _snapshots.has(t.from_group):
			_snapshots[t.from_group] = game.group_registry.get_group(t.from_group)

	for t in transitions:
		_evaluate_transition(t, delta)

	for group_name in _dirty_groups:
		game.group_registry.mark_dirty(group_name)

func _evaluate_transition(t: CDTransition, delta: float) -> void:
	t.advance_cooldown(delta)
	if t.is_on_cooldown():
		return

	if t.trigger == null:
		return
	if not t.trigger.evaluate(delta):
		return

	var candidates: Array[CDEntity] = _build_candidates(t)

	candidates = _filter_candidates(candidates, t)

	if candidates.is_empty():
		return

	if t.selector:
		candidates = t.selector.select(candidates)

	var any_transitioned: bool = false
	for entity in candidates:
		if _transitioned.has(entity.get_rid()):
			continue
		_execute_transition(entity, t)
		_transitioned[entity.get_rid()] = true
		any_transitioned = true

	if any_transitioned:
		t.start_cooldown()

func _build_candidates(t: CDTransition) -> Array[CDEntity]:
	var signal_entities := _consume_signal_entities(t.trigger)
	if not signal_entities.is_empty():
		return signal_entities

	var snapshot: Array[CDEntity] = _snapshots.get(t.from_group, [])
	var result: Array[CDEntity] = []
	result.assign(snapshot)
	return result

func _filter_candidates(candidates: Array[CDEntity], t: CDTransition) -> Array[CDEntity]:
	var snapshot: Array[CDEntity] = _snapshots.get(t.from_group, [])
	var filtered: Array[CDEntity] = []
	for entity in candidates:
		if not is_instance_valid(entity):
			continue
		if _transitioned.has(entity.get_rid()):
			continue
		if entity not in snapshot:
			continue
		filtered.append(entity)
	return filtered

func _execute_transition(entity: CDEntity, t: CDTransition) -> void:
	if t.exit_signal_name != &"" and entity.has_signal(t.exit_signal_name):
		entity.emit_signal(t.exit_signal_name)

	entity.remove_from_group(t.from_group)
	entity.add_to_group(t.to_group)
	_dirty_groups[t.from_group] = true
	_dirty_groups[t.to_group] = true

	if t.emit_signal_name != &"" and entity.has_signal(t.emit_signal_name):
		entity.emit_signal(t.emit_signal_name)

func _consume_signal_entities(trigger: CDTrigger) -> Array[CDEntity]:
	if trigger is CDSignalTrigger:
		return trigger.consume_pending()
	if trigger is CDCompositeTrigger:
		return trigger.consume_pending()
	return []
