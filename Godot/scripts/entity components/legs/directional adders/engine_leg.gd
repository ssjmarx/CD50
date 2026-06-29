## EngineLeg
## Produces: a forward acceleration velocity request along the entity's facing direction.
## Consumes: entity bus thrust/end_thrust signals; entity rotation.

class_name EngineLeg extends CDEntityComponent

## --- exports ---

## force added per second while thrusting
@export var thrust_power: float = 400.0

@export_group("Listen Signals")
@export var thrust_signal: StringName = &"thrust"
@export var end_thrust_signal: StringName = &"thrust_end"

## --- state ---

var _is_thrusting: bool = false

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## on initialize
func _on_initialize() -> void:
	self.bus_connect(thrust_signal, _on_thrust)
	self.bus_connect(end_thrust_signal, _on_end_thrust)
	set_physics_process(false)

## --- signal handlers ---

## on thrust
func _on_thrust() -> void:
	_is_thrusting = true
	set_physics_process(true)

## on end thrust
func _on_end_thrust() -> void:
	_is_thrusting = false
	set_physics_process(false)

## --- processing ---

## add forward thrust force each frame while active
func _physics_process(delta: float) -> void:
	var forward := Vector2(cos(entity.rotation), sin(entity.rotation))
	entity.request_velocity_add(forward * thrust_power * delta)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	self.bus_disconnect(thrust_signal, _on_thrust)
	self.bus_disconnect(end_thrust_signal, _on_end_thrust)
	_is_thrusting = false
	set_physics_process(false)
