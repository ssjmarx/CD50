## StateDirector
## Transitions entities between groups (group-as-state) using CDTransition resources
## Queues transitions via CDUpdater to avoid group mutation during iteration

class_name StateDirector extends CDGameComponent

## --- exports ---

## transition rules defining from/to groups, triggers, selectors, and cooldowns
@export var transitions: Array[CDTransition] = []

## --- state ---

## per-frame guard: each entity can only transition once per frame
var _transitioned: Dictionary = {}
## reference to the game's CDUpdater for deferred transitions
var _update: CDUpdater

## --- lifecycle ---

## ready
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES

## cache updater reference and initialize all transitions
func _on_initialize() -> void:
	_update = game.update
	initialize()

## initialize all valid transitions
func initialize() -> void:
	for t in transitions:
		if t.is_valid():
			t.initialize(game)
		else:
			push_warning("StateDirector: skipping invalid transition (empty group names).")

## --- processing ---

## evaluate transitions each frame, advance cooldowns, queue matching transitions
func _physics_process(delta: float) -> void:
	_transitioned.clear()
	
	for t in transitions:
		t.advance_cooldown(delta)
	
	## evaluate triggers and queue transitions
	for t in transitions:
		if not t.is_valid() or t.is_on_cooldown():
			continue
		if t.trigger and t.trigger.evaluate(delta):
			_process_trigger(t)

## --- transition logic ---

## gather candidates, filter, select, and queue transitions via CDUpdater
func _process_trigger(t: CDTransition) -> void:
	## build candidates from trigger type
	var candidates: Array[CDEntity]
	if t.trigger is CDSignalTrigger:
		candidates = t.trigger.consume_pending()
	elif t.trigger is CDCompositeTrigger:
		candidates = t.trigger.consume_pending()
		## also gather from target_groups if set
		if not t.target_groups.is_empty():
			var group_candidates := _gather_from_groups(t)
			for entity in group_candidates:
				if not candidates.has(entity):
					candidates.append(entity)
	else:
		candidates = _gather_from_groups(t)
	
	## filter: valid, active, not already transitioned, in all target groups
	var filtered: Array[CDEntity] = []
	for entity in candidates:
		if not is_instance_valid(entity):
			continue
		if entity.state != CDEnums.EntityState.ACTIVE:
			continue
		if _transitioned.has(entity):
			continue
		if not _is_in_all_groups(entity, t.target_groups):
			continue
		filtered.append(entity)
	
	## selector narrows the pool
	var selected: Array[CDEntity]
	if t.selector:
		selected = t.selector.select(filtered)
	else:
		selected = filtered
	
	## queue transitions via CDUpdater (deferred to avoid mutation during iteration)
	for entity in selected:
		_transitioned[entity] = true
		_update.queue_transition(entity, t.remove_groups, t.add_groups, t.entity_signals, t.game_signals)
		t.start_cooldown()

## gather candidates from all target groups (deduplicated)
func _gather_from_groups(t: CDTransition) -> Array[CDEntity]:
	if t.target_groups.is_empty():
		if t.remove_groups.is_empty():
			return []
		return game.group_registry.get_group(t.remove_groups[0])
	
	var seen: Dictionary = {}
	var result: Array[CDEntity] = []
	for group_name in t.target_groups:
		for entity in game.group_registry.get_group(group_name):
			if not seen.has(entity):
				seen[entity] = true
				result.append(entity)
	return result

## check if entity is a member of all specified groups
func _is_in_all_groups(entity: CDEntity, groups: Array[StringName]) -> bool:
	## if no target groups specified, check first remove group for backward compat
	if groups.is_empty():
		return true
	for group_name in groups:
		if not entity.is_in_group(group_name):
			return false
	return true

## --- reset ---

## clear all transition state for game restart
func reset() -> void:
	_transitioned.clear()
	for t in transitions:
		t.reset()
