## listens for entity bus signals and rebroadcasts on the game bus.
class_name AnnouncerGuts extends CDEntityComponent

## Only fire if entity is in one of these groups. Empty = always fire.
@export var qualifying_groups: Array[StringName] = [&"diving"]

## Pass entity as first argument to each game bus emission.
@export var include_self: bool = true

@export_group("Listen Signals")
@export var listen_signals: Array[StringName] = [&"path_finished"]

@export_group("Emit Signals")
@export var rebroadcast_signals: Array[StringName] = [&"dive_complete"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig_name: StringName in listen_signals:
		entity.ensure_signal(sig_name)
		entity.connect(sig_name, _on_any_input)

## Called when ANY listen_signal fires
func _on_any_input(_arg1: Variant = null, _arg2: Variant = null) -> void:
	if not _qualifies():
		return
	
	for rebroadcast: StringName in rebroadcast_signals:
		if include_self:
			game.bus_emit(rebroadcast, [entity])
		else:
			game.bus_emit(rebroadcast)

func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig_name: StringName in listen_signals:
		if entity.has_signal(sig_name) and entity.is_connected(sig_name, _on_any_input):
			entity.disconnect(sig_name, _on_any_input)
