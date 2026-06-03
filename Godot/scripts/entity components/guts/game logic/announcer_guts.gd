# AnnouncerGuts
# Listens for entity bus signals and rebroadcasts them on the game bus
# Acts as a bridge between entity-level events and game-level reactions

class_name AnnouncerGuts extends CDEntityComponent

# --- exports ---

# pass the entity as first argument to each game bus emission
@export var include_self: bool = true

# entity signals to listen for (any arguments are ignored)
@export_group("Listen Signals")
@export var listen_signals: Array[StringName] = [&"path_finished"]

# game bus signals to rebroadcast on
@export_group("Emit Signals")
@export var rebroadcast_signals: Array[StringName] = [&"dive_complete"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect all listen signals to the unified handler
func _on_initialize() -> void:
	for sig_name: StringName in listen_signals:
		entity.bus_connect(sig_name, _on_any_input)

# --- signal handlers ---

# called when any listen_signal fires; rebroadcasts on game bus if qualified
func _on_any_input() -> void:
	# relay to game bus with or without entity reference
	for rebroadcast: StringName in rebroadcast_signals:
		game.bus_emit(rebroadcast)

# --- cleanup ---

# disconnect all listen signals for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig_name: StringName in listen_signals:
		if entity.has_signal(sig_name) and entity.is_connected(sig_name, _on_any_input):
			entity.disconnect(sig_name, _on_any_input)
