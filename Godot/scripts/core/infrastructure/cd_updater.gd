## CDUpdater
## Defers group transitions and sleep/wake operations to end of frame
## Prevents mid-frame group inconsistencies when entities change state

class_name CDUpdater extends Node

## queued group transition operations
var _pending: Array[Dictionary] = []

## queued sleep/wake operations (CDStage or CDBody instances)
var _pending_sleep: Array = []
var _pending_wake: Array = []

@onready var game = CDGame.find_ancestor(self)

## runs at UPDATE priority — after all gameplay components finish
func _ready() -> void:
	process_physics_priority = CDEnums.category_to_priority(CDEnums.ComponentCategory.UPDATE)

## flush all pending transitions each frame, then clear emitter registries
func _physics_process(_delta: float) -> void:
	_flush()
	game._signal_emitters.clear()

## --- Public API ---

## queue a group transition: remove from groups, add to groups, emit exit/enter signals
func queue_transition(entity: CDEntity, remove_groups: Array[StringName], add_groups: Array[StringName], entity_signals: Array[StringName] = [], game_signals: Array[StringName] = []) -> void:
	_pending.append({
		"entity": entity,
		"remove": remove_groups,
		"add": add_groups,
		"entity_signals": entity_signals,
		"game_signals": game_signals,
	})

## queue a CDStage or CDBody to sleep at end of frame (processed before wake)
func queue_sleep(container) -> void:
	if container not in _pending_sleep:
		_pending_sleep.append(container)

## queue a CDStage or CDBody to wake at end of frame (processed after sleep)
func queue_wake(container) -> void:
	if container not in _pending_wake:
		_pending_wake.append(container)

## --- Internal ---

## execute all pending transitions in FIFO order
func _flush() -> void:
	for op in _pending:
		var entity: CDEntity = op["entity"]
		if not is_instance_valid(entity):
			continue

		var remove_groups: Array = op["remove"]
		var add_groups: Array = op["add"]
		var entity_signals: Array = op["entity_signals"]
		var game_signals: Array = op["game_signals"]

		for group in remove_groups:
			if group != &"" and entity.is_in_group(group):
				entity.remove_from_group(group)

		for group in add_groups:
			if group != &"" and not entity.is_in_group(group):
				entity.add_to_group(group)

		## mark dirty groups in the registry
		if entity.game and entity.game.group_registry:
			for group in remove_groups:
				if group != &"":
					entity.game.group_registry.mark_dirty(group)
			for group in add_groups:
				if group != &"" and group not in remove_groups:
					entity.game.group_registry.mark_dirty(group)

		## reconfigure collision layers based on new groups
		if entity.game and entity.game.collision_matrix:
			entity.game.collision_matrix.configure(entity)

		## emit exit signals on the entity (ensure first — idempotent)
		for sig in entity_signals:
			if sig != &"":
				entity.bus_emit(sig)
		for sig in game_signals:
			if sig != &"":
				game.bus_emit(sig)

	_pending.clear()

	## process sleep queue before wake (so same-frame sleep→wake resolves to wake)
	for container in _pending_sleep:
		if is_instance_valid(container):
			container._flush_sleep()
	_pending_sleep.clear()

	for container in _pending_wake:
		if is_instance_valid(container):
			container._flush_wake()
	_pending_wake.clear()
