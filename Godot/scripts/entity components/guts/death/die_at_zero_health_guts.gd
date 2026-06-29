## die_at_zero_health_guts.gd
## Produces: a death request when health hits zero.
## Consumes: zero_health_signals (entity bus).

class_name DieAtZeroHealthGuts extends CDEntityComponent

## --- exports ---

## signals that indicate health has reached zero
@export_group("Listen Signals")
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

## signals emitted to request entity deactivation
@export_group("Emit Signals")
@export var death_signals: Array[StringName] = [&"request_deactivate"]

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Connect each zero-health signal to the death handler.
func _on_initialize() -> void:
	for sig in zero_health_signals:
		self.bus_connect(sig, _on_zero_health)

## --- signal handlers ---

## Emit each configured death signal to request entity deactivation.
func _on_zero_health() -> void:
	for sig in death_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## Disconnect zero-health signal handlers on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in zero_health_signals:
		self.bus_disconnect(sig, _on_zero_health)