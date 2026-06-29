## move_adapter_guts.gd
## Produces: move signal; writes move_direction_key (entity blackboard).
## Consumes: move_to signal carrying a target position (Vector2).

class_name MoveAdapterGuts extends CDEntityComponent

## --- exports ---

## signals providing a target position (Vector2)
@export_group("Listen Signals")
@export var target_signals: Array[StringName] = [&"move_to"]

## emitted with direction vector from entity to target (Vector2)
@export_group("Emit Signals")
@export var direction_signals: Array[StringName] = [&"move"]

@export_group("Blackboard Keys")
@export var move_direction_key: StringName = &"move_direction"

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Connect the target listener during initialization.
func _on_initialize() -> void:
	for sig in target_signals:
		self.bus_connect(sig, _on_target)

## --- signal handlers ---

## Convert the target position into a direction vector and emit move.
func _on_target(target: Vector2) -> void:
	var direction := entity.global_position.direction_to(target)
	
	entity.blackboard[move_direction_key] = direction
	for sig in direction_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## Disconnect the target listener on deactivation for pool reuse.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in target_signals:
		if entity.is_connected(sig, _on_target):
			entity.disconnect(sig, _on_target)
