class_name PlayerActionBrain extends CDEntityComponent

@export var player_id: int = 1
@export var action_mappings: Array[StringName] = [&"fire"]

@export_group("Emit Signals")
@export var action_signals: Array[StringName] = [&"action"]
@export var action_end_signals: Array[StringName] = [&"action_end"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	# ensure each action name exists as a signal on the entity
	for action in action_mappings:
		entity.ensure_signal(action)
	for sig in action_signals:
		entity.ensure_signal(sig)
	for sig in action_end_signals:
		entity.ensure_signal(sig)
	game.input_router.input_action_pressed.connect(_on_action_pressed)
	game.input_router.input_action_released.connect(_on_action_released)

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

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if game.input_router.input_action_pressed.is_connected(_on_action_pressed):
		game.input_router.input_action_pressed.disconnect(_on_action_pressed)
	if game.input_router.input_action_released.is_connected(_on_action_released):
		game.input_router.input_action_released.disconnect(_on_action_released)
