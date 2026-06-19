## AIEscortBrain
## Blackboard-target variant of AIFormationBrain.
## Calculates vector toward a target entity (read from blackboard) + offset.
## Emits "move" direction intent for Legs to consume.

class_name AIEscortBrain extends CDEntityComponent

enum BlackboardSource {
	ENTITY,
	GAME
}

## whether to read the target from the entity blackboard or game blackboard
@export var blackboard_source: BlackboardSource = BlackboardSource.ENTITY

## key to read the target CDEntity from
@export var target_entity_key: StringName = &"captured_by"

## spatial offset from the target entity (e.g., floating above the captor)
@export var offset: Vector2 = Vector2.ZERO

## if true, stops emitting "move" when close enough to target
@export var stop_when_close: bool = true
@export var close_distance: float = 5.0

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move"]
@export var arrived_signals: Array[StringName] = [&"escort_achieved"]

var _target_entity: CDEntity

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## physics process
func _physics_process(_delta: float) -> void:
	_update_target()
	if is_instance_valid(_target_entity):
		var target_pos = _target_entity.global_position + offset
		var distance = entity.global_position.distance_to(target_pos)
		
		if stop_when_close and distance <= close_distance:
			entity.request_velocity_set(Vector2.ZERO)
			for sig in arrived_signals:
				entity.bus_emit(sig)
			return
			
		var direction = (target_pos - entity.global_position).normalized()
		
		## write direction to blackboard and emit move signal
		entity.blackboard["move_direction"] = direction
		for sig in move_signals:
			entity.bus_emit(sig)

## check blackboard for target entity reference
func _update_target() -> void:
	var bb: Dictionary
	if blackboard_source == BlackboardSource.ENTITY:
		bb = entity.blackboard
	else:
		bb = game.blackboard
		
	var new_target = bb.get(target_entity_key)
	if new_target != _target_entity:
		_target_entity = new_target
