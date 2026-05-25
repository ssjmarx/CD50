## hard-sets velocity from a directional input signal
class_name DirectMovementLeg extends CDEntityComponent

@export var speed: float = 200.0

@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]

var _direction: Vector2 = Vector2.ZERO
var _received_input: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)

func _on_move(direction: Vector2) -> void:
	_direction = direction.normalized()
	_received_input = true

func _physics_process(_delta: float) -> void:
	if _received_input:
		entity.request_velocity_set(_direction * speed)
		_received_input = false
	else:
		entity.request_velocity_set(Vector2.ZERO)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_direction = Vector2.ZERO
	_received_input = false
	for sig in move_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
