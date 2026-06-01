# PlayerAimBrain
# Converts player aim input into a blackboard aim direction
# Filters by player_id for multiplayer support

class_name PlayerAimBrain extends CDEntityComponent

# which player this brain listens to (matches input router player_id)
@export var player_id: int = 1

@export var aim_key: StringName = &"aim_direction"

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# update mouse position on the entity blackboard
func _physics_process(_delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos == Vector2.ZERO:
		return  # hold last output
	var direction = (mouse_pos - entity.global_position).normalized()
	entity.blackboard[aim_key] = direction

# disconnect from the input router
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
