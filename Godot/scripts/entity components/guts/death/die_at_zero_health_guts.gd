## DieAtZeroHealthGuts
## Kills the entity when health reaches zero
## Bridges HealthpoolGuts' zero_health signal to entity deactivation

class_name DieAtZeroHealthGuts extends CDEntityComponent

## --- exports ---

## signals that indicate health has reached zero
@export_group("Listen Signals")
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

## signals emitted to request entity deactivation
@export_group("Emit Signals")
@export var death_signals: Array[StringName] = [&"request_deactivate"]

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## on initialize
func _on_initialize() -> void:
	for sig in zero_health_signals:
		entity.bus_connect(sig, _on_zero_health)

## --- signal handlers ---

## on zero health
func _on_zero_health() -> void:
	for sig in death_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in zero_health_signals:
		entity.bus_disconnect(sig, _on_zero_health)