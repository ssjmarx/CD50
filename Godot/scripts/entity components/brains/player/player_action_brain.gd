# PlayerActionBrain
# Converts player input actions into entity signals via the input router
# Emits both named signals (e.g., "fire") and generic action/end signals

class_name PlayerActionBrain extends CDEntityComponent

# which player this brain listens to (matches input router player_id)
@export var player_id: int = 1

# input action names to listen for (e.g., "fire", "bomb")
@export var action_mappings: Array[StringName] = [&"fire"]

@export_group("Emit Signals")
@export var action_signals: Array[StringName] = [&"action"]
@export var action_end_signals: Array[StringName] = [&"action_end"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure all action and end signals exist on the entity
func _on_initialize() -> void:
	for action in action_mappings:
		entity.ensure_signal(action)
	for sig in action_signals:
		entity.ensure_signal(sig)
	for sig in action_end_signals:
		entity.ensure_signal(sig)
	game.input_router.input_action_pressed.connect(_on_action_pressed)
	game.input_router.input_action_released.connect(_on_action_released)

# emit named signal and generic action signal on press
func _on_action_pressed(pid: int, action: StringName) -> void:
	if pid != player_id:
		return
	if action not in action_mappings:
		return
	# emit named signal (e.g., "fire") for specific arms like GunArm
	entity.emit_signal(action)
	# emit generic signal for catch-all listeners
	for sig in action_signals:
		entity.emit_signal(sig, action)

# emit named end signal and generic action_end signal on release
func _on_action_released(pid: int, action: StringName) -> void:
	if pid != player_id:
		return
	if action not in action_mappings:
		return
	# emit named end signal (e.g., "fire_end") 
	var end_signal := StringName(action + &"_end")
	if entity.has_signal(end_signal):
		entity.emit_signal(end_signal)
	for sig in action_end_signals:
		entity.emit_signal(sig, action)

# disconnect from the input router
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if game.input_router.input_action_pressed.is_connected(_on_action_pressed):
		game.input_router.input_action_pressed.disconnect(_on_action_pressed)
	if game.input_router.input_action_released.is_connected(_on_action_released):
		game.input_router.input_action_released.disconnect(_on_action_released)