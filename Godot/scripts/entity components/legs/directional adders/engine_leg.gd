# EngineLeg
# Adds forward velocity based on entity facing direction (Asteroids-style)
# Listens for thrust/end_thrust signals on the entity bus

class_name EngineLeg extends CDEntityComponent

# --- exports ---

# force added per second while thrusting
@export var thrust_power: float = 400.0

@export_group("Listen Signals")
@export var thrust_signal: StringName = &"thrust"
@export var end_thrust_signal: StringName = &"thrust_end"

# --- state ---

var _is_thrusting: bool = false

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	entity.bus_connect(thrust_signal, _on_thrust)
	entity.bus_connect(end_thrust_signal, _on_end_thrust)
	set_physics_process(false)

# --- signal handlers ---

func _on_thrust() -> void:
	_is_thrusting = true
	set_physics_process(true)

func _on_end_thrust() -> void:
	_is_thrusting = false
	set_physics_process(false)

# --- processing ---

# add forward thrust force each frame while active
func _physics_process(delta: float) -> void:
	var forward := Vector2(cos(entity.rotation), sin(entity.rotation))
	entity.request_velocity_add(forward * thrust_power * delta)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	entity.bus_disconnect(thrust_signal, _on_thrust)
	entity.bus_disconnect(end_thrust_signal, _on_end_thrust)
	_is_thrusting = false
	set_physics_process(false)
