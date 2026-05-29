# CDUpdater
# Defers group transitions to end of frame via priority queue
# Prevents mid-frame group inconsistencies when entities change state

class_name CDUpdater extends Node

# queued transition operations
var _pending: Array[Dictionary] = []

# runs at UPDATE priority — after all gameplay components finish
func _ready() -> void:
	process_physics_priority = CDEnums.category_to_priority(CDEnums.ComponentCategory.UPDATE)

# flush all pending transitions each frame
func _physics_process(_delta: float) -> void:
	_flush()

# --- Public API ---

# queue a group transition: swap groups, emit exit/enter signals, mark dirty
func queue_transition(entity: CDEntity, from_group: StringName, to_group: StringName, exit_signal: StringName = &"", enter_signal: StringName = &"") -> void:
	_pending.append({
		"entity": entity,
		"from": from_group,
		"to": to_group,
		"exit_signal": exit_signal,
		"enter_signal": enter_signal,
	})

# --- Internal ---

# execute all pending transitions in FIFO order
func _flush() -> void:
	for op in _pending:
		var entity: CDEntity = op["entity"]
		if not is_instance_valid(entity):
			continue

		var from_group: StringName = op["from"]
		var to_group: StringName = op["to"]

		# swap groups
		if from_group != &"" and entity.is_in_group(from_group):
			entity.remove_from_group(from_group)
		if to_group != &"" and not entity.is_in_group(to_group):
			entity.add_to_group(to_group)

		# mark both groups dirty in the registry
		if entity.game and entity.game.group_registry:
			if from_group != &"":
				entity.game.group_registry.mark_dirty(from_group)
			if to_group != &"" and to_group != from_group:
				entity.game.group_registry.mark_dirty(to_group)

		# emit exit/enter signals on the entity
		if op["exit_signal"] != &"":
			entity.emit_signal(op["exit_signal"])
		if op["enter_signal"] != &"":
			entity.emit_signal(op["enter_signal"])

	_pending.clear()