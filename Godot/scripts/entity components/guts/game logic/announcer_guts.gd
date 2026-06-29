## announcer_guts.gd
## Produces: game-bus rebroadcast of configured entity-bus signals.
## Consumes: listen_signals (entity bus).

class_name AnnouncerGuts extends CDEntityComponent

## --- exports ---

## pass the entity as first argument to each game bus emission
@export var include_self: bool = true

## entity signals to listen for (any arguments are ignored)
@export_group("Listen Signals")
@export var listen_signals: Array[StringName] = [&"path_finished"]

## game bus signals to rebroadcast on
@export_group("Emit Signals")
@export var rebroadcast_signals: Array[StringName] = [&"dive_complete"]

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Connect every listen signal to the unified rebroadcast handler.
func _on_initialize() -> void:
	for sig_name: StringName in listen_signals:
		self.bus_connect(sig_name, _on_any_input)

## --- signal handlers ---

## Rebroadcast the triggering event on the game bus with the entity as emitter.
func _on_any_input() -> void:
	for rebroadcast: StringName in rebroadcast_signals:
		game.bus_emit_from(rebroadcast, entity)

## --- cleanup ---

## Disconnect all listen signals on deactivation for pool reuse.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig_name: StringName in listen_signals:
		if entity.has_signal(sig_name) and entity.is_connected(sig_name, _on_any_input):
			entity.disconnect(sig_name, _on_any_input)
