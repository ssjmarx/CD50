# PlayerMoveBrain
# Converts player directional input into entity move signals via the input router
# Filters by player_id for multiplayer support

class_name PlayerMoveBrain extends CDEntityComponent

# which player this brain listens to (matches input router player_id)
@export var player_id: int = 1

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure move signals exist and connect to input router
func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	game.input_router.input_move.connect(_on_input_move)

# emit move direction when input router broadcasts for this player
func _on_input_move(pid: int, direction: Vector2) -> void:
	if pid != player_id:
		return
	for sig in move_signals:
		entity.emit_signal(sig, direction)

# disconnect from the input router with validity guards
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if is_instance_valid(game) and game.input_router:
		if game.input_router.input_move.is_connected(_on_input_move):
			game.input_router.input_move.disconnect(_on_input_move)