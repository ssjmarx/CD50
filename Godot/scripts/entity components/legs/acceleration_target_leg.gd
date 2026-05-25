## accelerates toward a world-space target position based on distance
class_name AccelerationTargetLeg extends CDEntityComponent

@export var acceleration: float = 800.0
@export var slow_distance: float = 100.0   # begins tapering within this range
@export var stop_distance: float = 5.0     # acceleration reaches zero at this range

@export_group("Listen Signals")
@export var target_signals: Array[StringName] = [&"move_to"]

var _target: Vector2 = Vector2.ZERO
var _has_target: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in target_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_target)

func _on_target(target: Vector2) -> void:
	_target = target
	_has_target = true

func _physics_process(delta: float) -> void:
	if not entity or not _has_target:
		return
	
	var to_target := _target - entity.global_position
	var distance := to_target.length()
	
	if distance <= stop_distance:
		_has_target = false
		return
	
	var direction := to_target.normalized()
	
	var accel_factor := clampf(
		(distance - stop_distance) / (slow_distance - stop_distance),
		0.0, 1.0
	)
	
	entity.request_velocity_add(direction * acceleration * accel_factor * delta)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_target = Vector2.ZERO
	_has_target = false
	for sig in target_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_target):
			entity.disconnect(sig, _on_target)
