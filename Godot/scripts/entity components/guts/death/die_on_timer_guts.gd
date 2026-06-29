## die_on_timer_guts.gd
## Produces: a timed death (lifespan expiry) emitting timer_expired then deactivating.
## Consumes: nothing (self-driven lifespan counter).

class_name DieOnTimerGuts extends CDEntityComponent

## --- exports ---

## seconds before the entity is destroyed
@export var lifespan: float = 3.0

## emitted when the timer expires (before deactivation)
@export_group("Emit Signals")
@export var timer_expired_signals: Array[StringName] = [&"timer_expired"]
## emitted to request entity deactivation
@export var death_signals: Array[StringName] = [&"request_deactivate"]

## --- state ---

var _time_remaining: float = 0.0

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Reset the lifespan countdown at initialization.
func _on_initialize() -> void:
	_time_remaining = lifespan

## --- processing ---

## Count down lifespan; on expiry emit timer signals and deactivate.
func _physics_process(delta: float) -> void:
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		for sig in timer_expired_signals:
			entity.bus_emit(sig)
		entity.deactivate()
		set_physics_process(false)

## --- cleanup ---

## Reset countdown and stop processing for pool reuse.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_time_remaining = lifespan
	set_physics_process(false)

## Restart the lifespan countdown on reactivation.
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_time_remaining = lifespan
	set_physics_process(true)