# PlayerAimBrain
# Converts player aim input into entity aim signals via the input router
# Filters by player_id for multiplayer support

class_name PlayerAimBrain extends CDEntityComponent

# which player this brain listens to (matches input router player_id)
@export var player_id: int = 1

@export_group("Emit Signals")
@export var aim_signals: Array[StringName] = [&"aim"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure aim signals exist and connect to input router
func _on_initialize() -> void:
	for sig in aim_signals:
		entity.ensure_signal(sig)
	game.input_router.input_aim.connect(_on_input_aim)

# emit aim direction when input router broadcasts for this player
func _on_input_aim(pid: int, direction: Vector2) -> void:
	if pid != player_id:
		return
	for sig in aim_signals:
		entity.emit_signal(sig, direction)

# disconnect from the input router
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if game.input_router.input_aim.is_connected(_on_input_aim):
		game.input_router.input_aim.disconnect(_on_input_aim)