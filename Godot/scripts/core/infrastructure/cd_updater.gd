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

# queue a group transition: remove from groups, add to groups, emit exit/enter signals
func queue_transition(entity: CDEntity, remove_groups: Array[StringName], add_groups: Array[StringName], exit_signals: Array[StringName] = [], emit_signals: Array[StringName] = []) -> void:
	_pending.append({
		"entity": entity,
		"remove": remove_groups,
		"add": add_groups,
		"exit_signals": exit_signals,
		"emit_signals": emit_signals,
	})

# --- Internal ---

# execute all pending transitions in FIFO order
func _flush() -> void:
	for op in _pending:
		var entity: CDEntity = op["entity"]
		if not is_instance_valid(entity):
			continue

		var remove_groups: Array = op["remove"]
		var add_groups: Array = op["add"]
		var exit_signals: Array = op["exit_signals"]
		var emit_signals: Array = op["emit_signals"]

		# remove from all specified groups
		for group in remove_groups:
			if group != &"" and entity.is_in_group(group):
				entity.remove_from_group(group)

		# add to all specified groups
		for group in add_groups:
			if group != &"" and not entity.is_in_group(group):
				entity.add_to_group(group)

		# mark dirty groups in the registry
		if entity.game and entity.game.group_registry:
			for group in remove_groups:
				if group != &"":
					entity.game.group_registry.mark_dirty(group)
			for group in add_groups:
				if group != &"" and group not in remove_groups:
					entity.game.group_registry.mark_dirty(group)

		# emit exit signals on the entity
		for sig in exit_signals:
			if sig != &"":
				entity.emit_signal(sig)

		# emit enter signals on the entity
		for sig in emit_signals:
			if sig != &"":
				entity.emit_signal(sig)

	_pending.clear()