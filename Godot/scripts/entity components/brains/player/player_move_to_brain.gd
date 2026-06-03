# PlayerMoveToBrain
# Writes the mouse global position to the blackboard
# Uses direction + distance paradigm (eliminates need for conversion)

class_name PlayerMoveToBrain extends CDEntityComponent

@export var dead_zone: float = 4.0

@export_group("Blackboard Keys")
@export var move_direction_key: StringName = &"move_direction"
@export var move_distance_key: StringName = &"move_distance"

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := entity.get_global_mouse_position()
	var to_target := target - entity.global_position
	var distance := to_target.length()
	
	if distance <= dead_zone:
		entity.blackboard[move_direction_key] = Vector2.ZERO
		entity.blackboard[move_distance_key] = 0.0
		return
	
	entity.blackboard[move_direction_key] = to_target.normalized()
	entity.blackboard[move_distance_key] = distance

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	set_physics_process(false)
