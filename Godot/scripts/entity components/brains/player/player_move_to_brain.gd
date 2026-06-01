# PlayerMoveToBrain
# Writes the mouse global position to the blackboard
# Uses direction + distance paradigm (eliminates need for conversion)

class_name PlayerMoveToBrain extends CDEntityComponent

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
	entity.blackboard[move_direction_key] = to_target.normalized()
	entity.blackboard[move_distance_key] = to_target.length()

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	set_physics_process(false)
