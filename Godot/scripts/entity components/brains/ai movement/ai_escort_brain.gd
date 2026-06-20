## AIEscortBrain
## Blackboard-target or group-target variant of AIFormationBrain.
## Calculates vector toward a target entity (read from blackboard or nearest from group) + offset.

class_name AIEscortBrain extends CDEntityComponent

enum BlackboardSource {
	ENTITY,
	GAME
}

## whether to read the target from the entity blackboard or game blackboard
@export var blackboard_source: BlackboardSource = BlackboardSource.ENTITY

## key to read the target CDEntity from
@export var target_entity_key: StringName = &"captured_by"

## target groups to find the nearest entity from (overrides blackboard target)
@export var target_groups: Array[StringName] = []

## spatial offset from the target entity (e.g., floating above the captor)
@export var offset: Vector2 = Vector2.ZERO

## if true, stops emitting "move" when close enough to target
@export var stop_when_close: bool = true
@export var close_distance: float = 5.0

@export_group("Blackboard Keys")
@export var move_direction_key: StringName = &"move_direction"
@export var move_distance_key: StringName = &"move_distance"

@export_group("Emit Signals")
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
			entity.blackboard.erase(move_direction_key)                   
			entity.blackboard.erase(move_distance_key)                    
			for sig in arrived_signals:                                   
				entity.bus_emit(sig)                                      
			return 
			
		var direction = (target_pos - entity.global_position).normalized()
		
		## write direction and distance to blackboard and emit move signal
		entity.blackboard[move_direction_key] = direction
		entity.blackboard[move_distance_key] = distance
	else:
		entity.blackboard[move_direction_key] = Vector2.ZERO
		entity.blackboard[move_distance_key] = 0.0

## check blackboard or groups for target entity reference
func _update_target() -> void:
	var new_target: CDEntity = null
	
	if not target_groups.is_empty():                                      
		var closest_dist = INF                                            
		for group_name in target_groups:                                  
			var entities = game.group_registry.get_group(group_name)      
			for ent in entities:                                          
				if not is_instance_valid(ent):                            
					continue                                              
				var dist = entity.global_position.distance_squared_to(ent.global_position)           
				if dist < closest_dist:                                   
					closest_dist = dist                                   
					new_target = ent  
	else:
		var bb: Dictionary
		if blackboard_source == BlackboardSource.ENTITY:
			bb = entity.blackboard
		else:
			bb = game.blackboard
		if target_entity_key != &"":                                      
			var potential_target = bb.get(target_entity_key)              
			if is_instance_valid(potential_target):                       
				new_target = potential_target                             
			else:                                                         
				bb.erase(target_entity_key)
		
	if new_target != _target_entity:
		_target_entity = new_target
