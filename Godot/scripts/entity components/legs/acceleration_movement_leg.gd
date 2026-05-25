## accelerates toward an input direction
class_name AccelerationLeg extends CDEntityComponent

@export var acceleration: float = 800.0

@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]

var _direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)

func _on_move(direction: Vector2) -> void:
	_direction = direction.normalized()

func _physics_process(delta: float) -> void:
	if _direction != Vector2.ZERO:
		entity.request_velocity_add(_direction * acceleration * delta)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_direction = Vector2.ZERO
	for sig in move_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
