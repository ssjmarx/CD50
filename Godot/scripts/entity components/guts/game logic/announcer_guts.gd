# AnnouncerGuts
# Listens for entity bus signals and rebroadcasts them on the game bus
# Acts as a bridge between entity-level events and game-level reactions

class_name AnnouncerGuts extends CDEntityComponent

# --- exports ---

# only fire if entity is in one of these groups; empty = always fire
@export var qualifying_groups: Array[StringName] = [&"diving"]
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
		entity.ensure_signal(sig_name)
		entity.connect(sig_name, _on_any_input)

# --- signal handlers ---

# called when any listen_signal fires; rebroadcasts on game bus if qualified
func _on_any_input(_arg1: Variant = null, _arg2: Variant = null) -> void:
	if not _qualifies():
		return
	
	# relay to game bus with or without entity reference
	for rebroadcast: StringName in rebroadcast_signals:
		if include_self:
			game.bus_emit(rebroadcast, [entity])
		else:
			game.bus_emit(rebroadcast)

# --- helpers ---

# check if entity belongs to at least one qualifying group
func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false

# --- cleanup ---

# disconnect all listen signals for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig_name: StringName in listen_signals:
		if entity.has_signal(sig_name) and entity.is_connected(sig_name, _on_any_input):
			entity.disconnect(sig_name, _on_any_input)
