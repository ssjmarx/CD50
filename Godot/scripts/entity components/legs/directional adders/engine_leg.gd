# EngineLeg
# Adds forward velocity based on entity facing direction (Asteroids-style)
# Reads thrust state from entity blackboard each frame

class_name EngineLeg extends CDEntityComponent

# --- exports ---

# force added per second while thrusting
@export var thrust_power: float = 400.0

@export_group("Blackboard Keys")
# key to read thrust state from (bool)
@export var thrust_key: StringName = &"thrust_active"

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	pass

# --- processing ---

# add forward thrust force each frame while blackboard key is true
func _physics_process(delta: float) -> void:
	var is_thrusting: bool = entity.blackboard.get(thrust_key, false)
	if not is_thrusting:
		return
	var forward := Vector2(cos(entity.rotation), sin(entity.rotation))
	entity.request_velocity_add(forward * thrust_power * delta)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()